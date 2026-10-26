"""Actual relay + native worker integration on ephemeral loopback; no production writes."""
from pathlib import Path
import argparse
import os
import json
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request

root=Path(__file__).resolve().parents[1]
FIXTURE = root / 'build/RelayWireProbe.hl'


def fixture_command(runner, bytecode):
    """Only the dedicated native probe may execute; CLI paths never enter argv."""
    if runner.lower() not in ('hl', 'hl.exe'):
        raise ValueError('This fixture only runs HashLink')
    target = FIXTURE.resolve()
    requested = Path(bytecode)
    requested = (requested if requested.is_absolute() else root / requested).resolve()
    if requested != target:
        raise ValueError('Only build/RelayWireProbe.hl may execute')
    if not target.is_relative_to((root / 'build').resolve()) or not target.is_file():
        raise ValueError('Build the dedicated probe inside build/ first')
    native = shutil.which('hl') or shutil.which('hl.exe')
    if not native:
        raise ValueError('HashLink must be installed on PATH')
    return [native, str(target)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('runner', choices=['hl', 'hl.exe'])
    parser.add_argument('bytecode', help='The fixed build/RelayWireProbe.hl probe, relative or absolute')
    args = parser.parse_args()
    command = fixture_command(args.runner, args.bytecode)
    with socket.socket() as s:
        s.bind(('127.0.0.1', 0)); port = s.getsockname()[1]
    with tempfile.TemporaryDirectory(prefix='native-wire-', dir=root / 'build') as tmp:
        (Path(tmp) / 'test-entry.json').write_text(json.dumps({'expires_at': time.time() + 120}))
        env = dict(os.environ, LFG_TEST_ENTRY_FILE=str(Path(tmp) / 'test-entry.json'),
                   LFG_MODERATION_DB=str(Path(tmp) / 'moderation.sqlite'), LFG_RESTORE_FILE=str(Path(tmp) / 'none.json'))
        env.pop('LFG_HMAC_SECRET', None)
        server = subprocess.Popen([sys.executable, '-m', 'uvicorn', 'main:app', '--app-dir', str(root / 'server'),
                                   '--host', '127.0.0.1', '--port', str(port), '--no-access-log'],
                                  env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        try:
            for _ in range(100):
                try:
                    with urllib.request.urlopen('http://127.0.0.1:' + str(port) + '/health', timeout=.2): break
                except OSError: time.sleep(.05)
            else: raise RuntimeError('Loopback fixture did not start.')
            return subprocess.run([*command, str(port)], timeout=30).returncode
        finally:
            server.terminate()
            try: server.wait(timeout=5)
            except subprocess.TimeoutExpired: server.kill(); server.wait()
            if server.returncode not in (0, 1, -15):
                print(server.stderr.read().decode()[-1000:], file=sys.stderr)


if __name__ == '__main__':
    raise SystemExit(main())
