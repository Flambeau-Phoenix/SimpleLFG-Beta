"""Regression checks for the hardened local fixture invocation boundary."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import relay_wire_fixture as fixture


class FixtureCommandTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=fixture.root / 'build', prefix='fixture-args-')
        self.addCleanup(self.tmp.cleanup)
        self.native = Path(self.tmp.name) / 'RelayWireProbe.hl'
        self.native.write_bytes(b'fixture')
        self.script = Path(self.tmp.name) / 'fixture.py'
        self.script.write_text('')
        self.fixture_patch = patch.object(fixture, 'FIXTURE', self.native)
        self.fixture_patch.start()
        self.addCleanup(self.fixture_patch.stop)
        self.runner_patch = patch.object(fixture.shutil, 'which', return_value='trusted-hl')
        self.runner_patch.start()
        self.addCleanup(self.runner_patch.stop)

    def test_absolute_and_relative_paths(self):
        for target in (self.native, self.native.relative_to(fixture.root)):
            self.assertEqual(fixture.fixture_command('hl', str(target)), ['trusted-hl', str(self.native.resolve())])

    def test_allowlisted_native_runner(self):
        for runner in ('hl', 'hl.exe'):
            self.assertEqual(fixture.fixture_command(runner, str(self.native)), ['trusted-hl', str(self.native.resolve())])

    def test_outside_build_is_rejected(self):
        for target in (fixture.root / 'tools/relay_wire_fixture.py', 'build/../tools/relay_wire_fixture.py'):
            with self.assertRaises(ValueError):
                fixture.fixture_command('hl', str(target))

    def test_missing_and_wrong_kind_are_rejected(self):
        other = self.native.with_name('other.hl')
        other.write_bytes(b'other')
        for target in (self.script.with_name('missing.hl'), self.script, other):
            with self.assertRaises(ValueError):
                fixture.fixture_command('hl', str(target))

    def test_unknown_runner_is_rejected(self):
        for runner in ('cmd', 'evil/hl', sys.executable, 'python'):
            with self.assertRaises(ValueError):
                fixture.fixture_command(runner, str(self.script))

    def test_missing_runner_is_rejected(self):
        with patch.object(fixture.shutil, 'which', return_value=None):
            with self.assertRaises(ValueError):
                fixture.fixture_command('hl', str(self.native))


if __name__ == '__main__':
    unittest.main(testRunner=unittest.TextTestRunner(stream=sys.stdout))
