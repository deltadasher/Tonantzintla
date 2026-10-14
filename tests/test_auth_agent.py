"""Authentication-agent ownership checks that never authenticate."""
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]


def helper(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'src/libexec' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


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


if __name__ == "__main__":
    unittest.main()
