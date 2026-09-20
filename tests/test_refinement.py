"""Behavior checks without activating devices, authenticating, or changing host settings."""
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]

def helper(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'src/libexec' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

class NotificationTests(unittest.TestCase):
    def test_group_members_actions_retention_and_individual_dismissal(self):
        source = (ROOT / 'src/quickshell/services/NotificationModel.js').read_text().replace('.pragma library', '')
        script = source + '''
const assert = require('node:assert/strict');
const first = {uid:1, groupKey:'chat.desktop', summary:'first', body:'one', actions:[{identifier:'reply-1'}]};
const second = {uid:2, groupKey:'chat.desktop', summary:'second', body:'two', actions:[{identifier:'reply-2'}]};
let records = append(append([], first, 100), second, 100);
let group = groups(records)[0];
assert.equal(group.count, 2);
for (const groupKey of ['__proto__','constructor','toString']) {
    assert.equal(groups([{...first,groupKey}])[0].count,1);
}
assert.deepEqual(JSON.parse(group.membersJson).map(r=>r.body), ['two','one']);
assert.equal(JSON.parse(group.membersJson)[1].actions[0].identifier, 'reply-1');
records = remove(records, [2]);
assert.equal(groups(records)[0].summary, 'first');
assert.equal(groups(append(records,{...second,critical:true},100)).length,2);
assert.equal(groups(append(records,{...second,groupKey:'other.desktop'},100)).length,2);
for (let uid=3; uid<140; uid++) records=append(records,{...first,uid},100);
assert.equal(records.length,100);
assert.equal(records[99].uid,40);
assert.equal(remove(records,records.map(r=>r.uid)).length,0);
'''
        subprocess.run(['node', '-e', script], check=True, capture_output=True, text=True)

class PairingTests(unittest.TestCase):
    def test_invalid_codes_and_rejection_never_authorize(self):
        module = helper('bluetooth-pair')
        for kind, value in [('passkey','1000000'),('passkey','-1'),('passkey','hello'),('pin',''),('pin','x'*17),('confirm','no')]:
            with self.subTest(kind=kind, value=value), self.assertRaises(ValueError):
                module.response_value(kind, value)
        self.assertEqual(module.response_value('passkey','000017'),17)
        self.assertEqual(module.response_value('pin','aB09'), 'aB09')
        self.assertIsNone(module.response_value('confirm','yes'))

class WifiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        try:
            import gi
            gi.require_version('NM','1.0')
            from gi.repository import NM, GLib
        except (ImportError, ValueError):
            raise unittest.SkipTest('Optional libnm Python binding unavailable')
        cls.NM, cls.GLib = NM, GLib
        cls.module = helper('network-action')

    def ap(self, flags, privacy=True):
        ap=Mock()
        ap.get_rsn_flags.return_value=flags
        ap.get_wpa_flags.return_value=0
        ap.get_flags.return_value=1 if privacy else 0
        return ap

    def test_password_goes_into_libnm_and_no_process_is_spawned(self):
        flags=getattr(self.NM,'80211ApSecurityFlags')
        request={'ssid':'Research: west', 'password':'test passphrase'}
        with patch('subprocess.run', side_effect=AssertionError('No subprocess for credentials')):
            profile=self.module.wifi_connection(self.NM,self.GLib,request,self.ap(flags.KEY_MGMT_PSK))
        self.assertEqual(profile.get_setting_wireless().get_ssid().get_data(), b'Research: west')
        self.assertEqual(profile.get_setting_wireless_security().props.psk,'test passphrase')
        self.assertNotIn('password',request)
        self.assertEqual(profile.get_setting_connection().get_num_permissions(),1)

    def test_enterprise_wep_and_missing_password_do_not_downgrade(self):
        flags=getattr(self.NM,'80211ApSecurityFlags')
        for security, password in [(flags.KEY_MGMT_802_1X,'test passphrase'),(0,'test passphrase'),(flags.KEY_MGMT_PSK,'')]:
            with self.assertRaises(ValueError):
                self.module.wifi_connection(self.NM,self.GLib,{'ssid':'test','password':password},self.ap(security))
        profile=self.module.wifi_connection(self.NM,self.GLib,{'ssid':'open','password':''},self.ap(0,False))
        self.assertIsNone(profile.get_setting_wireless_security())

    def test_ssid_length_and_connection_identity_validation(self):
        for request in [{'action':'disconnect','uuid':''},{'action':'wifi-connect','ssid':'é'*17}, {'action':'shell','command':'arbitrary'}]:
            with self.assertRaises(ValueError):self.module.validate(request)

    def test_renamed_saved_profile_resolves_by_ssid_and_uuid(self):
        state=helper('network-state')
        profile=Mock()
        profile.get_connection_type.return_value='802-11-wireless'
        profile.get_uuid.return_value='stable-uuid'
        profile.get_id.return_value='Renamed office profile'
        profile.get_setting_wireless.return_value.get_ssid.return_value.get_data.return_value=b'Office'
        active=Mock();active.get_uuid.return_value='stable-uuid'
        client=Mock();client.get_connections.return_value=[profile];client.get_active_connections.return_value=[active]
        rows=[{'ssid':'Office','saved':False}]
        with patch.object(self.NM.Client,'new',return_value=client):
            available,_=state.connection_profiles(rows)
        self.assertTrue(available)
        self.assertEqual(rows[0]['uuid'],'stable-uuid')
        self.assertTrue(rows[0]['saved'])

class AuthenticationOwnershipTests(unittest.TestCase):
    def test_only_verified_native_registration_suppresses_fallback(self):
        module=helper('auth-agent-bootstrap')
        instances=json.dumps([{'config_path':'/payload/tonantzintla/src/quickshell/shell.qml','pid':42}])
        with patch('subprocess.run', side_effect=[Mock(stdout=instances,returncode=0),Mock(stdout='ready\n',returncode=0)]):
            self.assertTrue(module.native_ready())
        with patch('subprocess.run', side_effect=[Mock(stdout=instances,returncode=0),Mock(stdout='unavailable\n',returncode=0)]):
            self.assertFalse(module.native_ready())
        with patch('subprocess.run', side_effect=[Mock(stdout=instances,returncode=0),Mock(stdout='ready\n',returncode=1)]):
            self.assertFalse(module.native_ready())
