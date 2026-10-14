"""Pairing and Wi-Fi checks that never activate a device or change host settings."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]


def helper(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'src/libexec' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


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


if __name__ == "__main__":
    unittest.main()
