#!/usr/bin/env python3
"""One bounded NetworkManager transaction; credentials enter through stdin only."""
import json
import signal
import sys
import uuid


def validate(request):
    if request.get('action') not in ('wifi-connect', 'disconnect', 'vpn-connect'):
        raise ValueError('Unsupported network action')
    if request['action'] == 'wifi-connect':
        ssid = request.get('ssid', '')
        if not isinstance(ssid, str) or not 1 <= len(ssid.encode()) <= 32:
            raise ValueError('Invalid Wi-Fi network name')
        if not isinstance(request.get('password', ''), str):
            raise ValueError('Invalid password')
    elif not request.get('uuid'):
        raise ValueError('Select a saved connection first')
    return request


def emit(ok, message):
    print(json.dumps({'ok': ok, 'message': message}), flush=True)


def wifi_connection(NM, GLib, request, ap):
    """Build a profile without a subprocess, temporary file, or secret in argv."""
    SecurityFlags = getattr(NM, "80211ApSecurityFlags")
    ApFlags = getattr(NM, "80211ApFlags")
    flags = ap.get_rsn_flags() | ap.get_wpa_flags()
    password = request.pop('password', '')
    if flags & SecurityFlags.KEY_MGMT_802_1X:
        raise ValueError('Enterprise Wi-Fi requires a profile in Advanced settings.')
    secured = bool(ap.get_flags() & ApFlags.PRIVACY)
    if secured and not (flags & (SecurityFlags.KEY_MGMT_PSK | SecurityFlags.KEY_MGMT_SAE)):
        raise ValueError('This security type requires a profile in Advanced settings.')
    if secured and not password:
        raise ValueError('This network requires a password or a saved profile.')
    connection = NM.SimpleConnection.new()
    general = NM.SettingConnection.new()
    general.props.id, general.props.uuid = request['ssid'], str(uuid.uuid4())
    general.props.type = '802-11-wireless'
    import getpass
    general.add_permission('user', getpass.getuser(), None)
    connection.add_setting(general)
    wireless = NM.SettingWireless.new()
    wireless.props.ssid = GLib.Bytes.new(request['ssid'].encode())
    connection.add_setting(wireless)
    if secured:
        sae = bool(flags & SecurityFlags.KEY_MGMT_SAE)
        import re
        if not ((1 if sae else 8) <= len(password) <= 63 or
                (not sae and re.fullmatch(r'[0-9a-fA-F]{64}', password))):
            raise ValueError('Invalid Wi-Fi password length.')
        security = NM.SettingWirelessSecurity.new()
        security.props.key_mgmt = 'sae' if sae else 'wpa-psk'
        security.props.psk = password
        connection.add_setting(security)
    return connection


def main():
    try:
        request = validate(json.loads(sys.stdin.readline(16384)))
        import gi
        gi.require_version('NM', '1.0')
        from gi.repository import NM, GLib
    except (ImportError, ValueError, TypeError):
        emit(False, 'Network control requires NetworkManager and Python GObject support.')
        return 1
    loop = GLib.MainLoop()
    try:
        client = NM.Client.new(None)
    except GLib.Error:
        emit(False, "NetworkManager is unavailable.")
        return 1
    active = None
    finished = False
    cancelled = False
    success = False

    def finish(ok, message):
        nonlocal finished, success
        if finished:
            return
        finished, success = True, ok
        emit(ok, message)
        loop.quit()

    def deactivated(source, result, _):
        try:
            source.deactivate_connection_finish(result)
            finish(True, 'Cancelled.' if cancelled else 'Disconnected.')
        except GLib.Error:
            finish(False, 'Could not disconnect. Refresh to check the connection.')

    def cancel(*_):
        nonlocal cancelled
        if cancelled or finished:
            return False
        cancelled = True
        if active:
            client.deactivate_connection_async(active, None, deactivated, None)
        # An activation callback can still arrive; it will deactivate only its own connection.
        return False

    def state_changed(connection, *_):
        if cancelled or finished:
            return
        state = connection.get_state()
        if state == NM.ActiveConnectionState.ACTIVATED:
            finish(True, 'Connected.')
        elif state == NM.ActiveConnectionState.DEACTIVATED:
            finish(False, 'Connection failed. Check credentials or open Advanced settings.')

    def activated(source, result, adding):
        nonlocal active
        try:
            active = (source.add_and_activate_connection_finish(result) if adding
                      else source.activate_connection_finish(result))
            if cancelled:
                source.deactivate_connection_async(active, None, deactivated, None)
                return
            active.connect('state-changed', state_changed)
            state_changed(active)
        except GLib.Error:
            finish(False, 'Connection failed. Check credentials, permissions, or Advanced settings.')

    def input_ready(fd, condition):
        line = sys.stdin.readline()
        if not line:
            cancel()
            return False
        try:
            if json.loads(line).get('cancel'):
                cancel()
        except ValueError:
            pass
        return True

    GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, input_ready)
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, cancel)
    GLib.timeout_add_seconds(55, cancel)
    GLib.timeout_add_seconds(65, lambda: finish(False, 'Request timed out. Refresh to check network state.'))
    try:
        if not client.get_nm_running():
            raise ValueError('NetworkManager is unavailable.')
        action = request['action']
        saved = client.get_connection_by_uuid(request.get('uuid', '')) if request.get('uuid') else None
        if action == 'disconnect':
            active = next((a for a in client.get_active_connections() if a.get_uuid() == request['uuid']), None)
            if active is None:
                raise ValueError('This connection is no longer active.')
            client.deactivate_connection_async(active, None, deactivated, None)
        elif action == 'vpn-connect':
            if not saved or saved.get_connection_type() not in ('vpn', 'wireguard'):
                raise ValueError('Saved VPN profile is unavailable. Open Advanced settings.')
            client.activate_connection_async(saved, None, None, None, activated, False)
        else:
            ssid = request['ssid'].encode()
            candidates = [(d, ap) for d in client.get_devices() if isinstance(d, NM.DeviceWifi)
                          for ap in d.get_access_points() if ap.get_ssid() and ap.get_ssid().get_data() == ssid]
            if not candidates:
                raise ValueError('Network is no longer visible. Scan again.')
            device, ap = max(candidates, key=lambda pair: pair[1].get_strength())
            if saved:
                wireless = saved.get_setting_wireless()
                if not wireless or not wireless.get_ssid() or wireless.get_ssid().get_data() != ssid:
                    raise ValueError('Saved profile does not match the selected network. Refresh and retry.')
                client.activate_connection_async(saved, device, ap.get_path(), None, activated, False)
            else:
                connection = wifi_connection(NM, GLib, request, ap)
                client.add_and_activate_connection_async(connection, device, ap.get_path(), None, activated, True)
        request.clear()
        loop.run()
    except ValueError as error:
        finish(False, str(error))
    except (GLib.Error, AttributeError, TypeError):
        finish(False, 'Network control is unavailable. Open Advanced settings.')
    return 0 if success else 1


if __name__ == '__main__':
    raise SystemExit(main())
