#!/usr/bin/env python3
"""Temporary BlueZ agent for one explicitly selected device, never the default agent."""
import json
import re
import signal
import sys


def emit(**event):
    print(json.dumps(event), flush=True)


def response_value(kind, value):
    if kind == 'passkey':
        if not re.fullmatch(r'[0-9]{1,6}', value):
            raise ValueError('Enter a number from 0 to 999999.')
        return int(value)
    if kind == 'pin':
        if not 1 <= len(value) <= 16:
            raise ValueError('PIN must contain 1 to 16 characters.')
        return value
    if value != 'yes':
        raise ValueError('Pairing rejected.')
    return None


def main():
    try:
        request = json.loads(sys.stdin.readline(4096))
        address = request.get('address', '')
        if not re.fullmatch(r'(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}', address):
            raise ValueError()
        import dbus
        import dbus.service
        from dbus.mainloop.glib import DBusGMainLoop
        from gi.repository import GLib
    except (ImportError, ValueError, TypeError):
        emit(ok=False, message='Pairing requires Python D-Bus and GObject support.')
        return 1
    DBusGMainLoop(set_as_default=True)
    loop = GLib.MainLoop()
    bus = dbus.SystemBus()
    objects = dbus.Interface(bus.get_object('org.bluez', '/'), 'org.freedesktop.DBus.ObjectManager').GetManagedObjects()
    target = next((str(path) for path, interfaces in objects.items()
                   if str(interfaces.get('org.bluez.Device1', {}).get('Address', '')).lower() == address.lower()), None)
    if not target:
        emit(ok=False, message='Device is no longer available. Scan again.')
        return 1
    device = dbus.Interface(bus.get_object('org.bluez', target), 'org.bluez.Device1')
    manager = dbus.Interface(bus.get_object('org.bluez', '/org/bluez'), 'org.bluez.AgentManager1')
    path = '/org/tonantzintla/Pairing'
    success = False
    ended = False

    class Rejected(dbus.DBusException):
        _dbus_error_name = 'org.bluez.Error.Rejected'

    class Agent(dbus.service.Object):
        pending = None

        def prompt(self, device_path, kind, message, reply, error):
            if str(device_path) != target or self.pending:
                error(Rejected('Unrequested device'))
                return
            self.pending = (kind, reply, error)
            emit(prompt=kind, message=message)

        @dbus.service.method('org.bluez.Agent1', in_signature='o', out_signature='s', async_callbacks=('reply', 'error'))
        def RequestPinCode(self, device, reply, error):
            self.prompt(device, 'pin', 'Enter the PIN shown on your device.', reply, error)

        @dbus.service.method('org.bluez.Agent1', in_signature='o', out_signature='u', async_callbacks=('reply', 'error'))
        def RequestPasskey(self, device, reply, error):
            self.prompt(device, 'passkey', 'Enter the passkey shown on your device.', reply, error)

        @dbus.service.method('org.bluez.Agent1', in_signature='ou', out_signature='', async_callbacks=('reply', 'error'))
        def RequestConfirmation(self, device, passkey, reply, error):
            self.prompt(device, 'confirm', f'Does your device show {int(passkey):06d}?', reply, error)

        @dbus.service.method('org.bluez.Agent1', in_signature='o', out_signature='', async_callbacks=('reply', 'error'))
        def RequestAuthorization(self, device, reply, error):
            self.prompt(device, 'confirm', 'Allow pairing with this device?', reply, error)

        @dbus.service.method('org.bluez.Agent1', in_signature='os', out_signature='', async_callbacks=('reply', 'error'))
        def AuthorizeService(self, device, service, reply, error):
            self.prompt(device, 'confirm', 'Allow this device to connect?', reply, error)

        @dbus.service.method('org.bluez.Agent1', in_signature='os', out_signature='')
        def DisplayPinCode(self, device, pin):
            if str(device) != target:
                raise Rejected()
            emit(prompt='display', message=f'Type {pin} on your device, then press Enter.')

        @dbus.service.method('org.bluez.Agent1', in_signature='ouq', out_signature='')
        def DisplayPasskey(self, device, passkey, entered):
            if str(device) != target:
                raise Rejected()
            emit(prompt='display', message=f'Type {int(passkey):06d} on your device ({int(entered)}/6), then press Enter.')

        @dbus.service.method('org.bluez.Agent1', in_signature='', out_signature='')
        def Cancel(self):
            self.reject()
            emit(prompt='', message='Pairing request cancelled by the device.')

        @dbus.service.method('org.bluez.Agent1', in_signature='', out_signature='')
        def Release(self):
            finish(False, 'Pairing agent was released.')

        def reject(self):
            if self.pending:
                _, _, error = self.pending
                self.pending = None
                error(Rejected('Cancelled'))

    agent = Agent(bus, path)

    def finish(ok, message):
        nonlocal success, ended
        if ended:
            return False
        ended, success = True, ok
        agent.reject()
        emit(ok=ok, message=message)
        loop.quit()
        return False

    def cancel(*_):
        agent.reject()
        device.CancelPairing(reply_handler=lambda: finish(False, 'Pairing cancelled.'),
                             error_handler=lambda error: finish(False, 'Pairing cancelled.'))
        return False

    def read_input(fd, condition):
        line = sys.stdin.readline()
        if not line:
            cancel()
            return False
        try:
            data = json.loads(line)
            if data.get('cancel'):
                cancel()
            elif agent.pending:
                kind, reply, error = agent.pending
                value = response_value(kind, str(data.get('response', '')))
                agent.pending = None
                if kind == 'passkey': reply(dbus.UInt32(value))
                elif kind == 'pin': reply(value)
                else: reply()
                emit(prompt='', message='Completing pairing…')
        except ValueError as error:
            emit(prompt=agent.pending[0] if agent.pending else '', message=str(error))
        return True

    try:
        manager.RegisterAgent(path, 'KeyboardDisplay')
        GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, read_input)
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, cancel)
        GLib.timeout_add_seconds(90, cancel)
        GLib.timeout_add_seconds(95, lambda: finish(False, 'Pairing timed out.'))
        device.Pair(reply_handler=lambda: finish(True, 'Paired. Select Connect to use the device.'),
                    error_handler=lambda error: finish(False, 'Pairing failed or was cancelled. Put the device in pairing mode and retry.'), timeout=90)
        loop.run()
    except dbus.DBusException:
        finish(False, 'Bluetooth pairing is unavailable. Check that Bluetooth is enabled.')
    finally:
        try: manager.UnregisterAgent(path)
        except dbus.DBusException: pass
    return 0 if success else 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception:
        emit(ok=False, message='Bluetooth service is unavailable.')
        raise SystemExit(1)
