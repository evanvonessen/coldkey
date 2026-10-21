"""Test real signed updates against disposable copies; never touches installed apps.

Usage: python3 Tests/Updater/validate_update.py /path/to/extracted/ColdKey.app
Requires the ColdKey update signing key and Developer ID certificate in Keychain.
"""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import threading
import uuid
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '.build/update-validation'
SOURCE = Path(sys.argv[1]).resolve()
TOOLS = ROOT / '.build/artifacts/sparkle/Sparkle/bin'
FRAMEWORKS = SOURCE / 'Contents/Frameworks'
SDK_FRAMEWORKS = ROOT / '.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64'
ACCOUNT = 'com.evanvonessen.coldkey'
IDENTITY = 'Developer ID Application: Evan Von Essen (3N83BX5M9G)'


def run(*args, **kwargs):
    return subprocess.run([str(a) for a in args], check=True, text=True, **kwargs)


WORK.mkdir(parents=True, exist_ok=True)
runner = WORK / 'Driver.app/Contents'
(runner / 'MacOS').mkdir(parents=True, exist_ok=True)
(runner / 'Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'com.evanvonessen.coldkey.update-validation-driver',
    'CFBundleExecutable': 'Driver', 'CFBundlePackageType': 'APPL', 'LSUIElement': True,
    'NSAppTransportSecurity': {'NSAllowsLocalNetworking': True},
}))
run('clang', '-fobjc-arc', '-fblocks', '-framework', 'Cocoa', '-framework', 'Sparkle',
    '-F', SDK_FRAMEWORKS, '-Wl,-rpath,' + str(FRAMEWORKS),
    ROOT / 'Tests/Updater/UpdateDriver.m', '-o', runner / 'MacOS/Driver')
run('codesign', '--force', '--sign', IDENTITY, '--options', 'runtime', '--timestamp', runner.parent)
archive = WORK / 'ColdKey-update.zip'
run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', SOURCE, archive)
signature = run(TOOLS / 'sign_update', '--account', ACCOUNT, '-p', archive, capture_output=True).stdout.strip()
installer = WORK / 'ColdKey-update.dmg'
shutil.copyfile(ROOT / 'dist/ColdKey.dmg', installer)
installer_signature = run(TOOLS / 'sign_update', '--account', ACCOUNT, '-p', installer, capture_output=True).stdout.strip()
metadata = plistlib.loads((SOURCE / 'Contents/Info.plist').read_bytes())
requests = []


class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        requests.append(self.path)
        super().do_GET()

    def log_message(self, *args):
        pass


server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(WORK)))
threading.Thread(target=server.serve_forever, daemon=True).start()
base = f'http://127.0.0.1:{server.server_port}'
sparkle = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', sparkle)

try:
    for mode in ('cancel', 'install', 'invalid-feed', 'invalid-archive', 'current'):
        host = WORK / mode / 'ColdKey.app'
        host.parent.mkdir(exist_ok=True)
        if host.exists():
            shutil.rmtree(host)
        run('ditto', SOURCE, host)
        plist = dict(metadata, CFBundleVersion=metadata['CFBundleVersion'] if mode == 'current' else '1',
                     CFBundleShortVersionString=metadata['CFBundleShortVersionString'] if mode == 'current' else '0.0.1',
                     SUDefaultsDomain='com.evanvonessen.coldkey.validation.' + uuid.uuid4().hex)
        (host / 'Contents/Info.plist').write_bytes(plistlib.dumps(plist))
        run('codesign', '--force', '--sign', IDENTITY, '--options', 'runtime', '--timestamp',
            '--entitlements', ROOT / 'scripts/ColdKey.entitlements', host)
        root = ET.Element('rss', version='2.0')
        channel = ET.SubElement(root, 'channel')
        ET.SubElement(channel, 'title').text = 'ColdKey local update test'
        item = ET.SubElement(channel, 'item')
        ET.SubElement(item, 'title').text = 'ColdKey update validation'
        ET.SubElement(item, f'{{{sparkle}}}version').text = metadata['CFBundleVersion']
        ET.SubElement(item, f'{{{sparkle}}}shortVersionString').text = metadata['CFBundleShortVersionString']
        ET.SubElement(item, f'{{{sparkle}}}minimumSystemVersion').text = '13.0.0'
        payload = archive if mode == 'invalid-archive' else installer
        ET.SubElement(item, 'enclosure', url=base + '/' + payload.name,
                      length=str(payload.stat().st_size), type='application/octet-stream',
                      **{f'{{{sparkle}}}edSignature': ('A' * 86 + '==') if mode == 'invalid-archive' else installer_signature})
        feed = WORK / (mode + '.xml')
        ET.ElementTree(root).write(feed, encoding='utf-8', xml_declaration=True)
        run(TOOLS / 'sign_update', '--account', ACCOUNT, feed)
        if mode == 'invalid-feed':
            feed.write_bytes(feed.read_bytes().replace(b'ColdKey local update test', b'Tampered local update test'))
        requests.clear()
        result = subprocess.run([str(runner / 'MacOS/Driver'), str(host), base + '/' + feed.name, mode],
                                capture_output=True, text=True, timeout=90)
        print(mode, result.stdout, result.stderr, sep='\n', flush=True)
        assert result.returncode == 0, f'{mode}: driver failed'
        updated = plistlib.loads((host / 'Contents/Info.plist').read_bytes())
        downloads = requests.count('/' + payload.name)
        if mode == 'install':
            assert updated['CFBundleVersion'] == metadata['CFBundleVersion']
            assert downloads >= 1 and 'INSTALLED' in result.stdout
            assert result.stdout.index('APPROVED') < result.stdout.index('DOWNLOAD_STARTED')
            run('codesign', '--verify', '--deep', '--strict', host)
        elif mode == 'current':
            assert updated['CFBundleVersion'] == metadata['CFBundleVersion']
            assert downloads == 0 and 'ALREADY_CURRENT' in result.stdout
        else:
            assert updated['CFBundleVersion'] == '1', 'Unapproved/invalid update changed the app'
            if mode in ('cancel', 'invalid-feed'):
                assert downloads == 0, 'Downloaded without approval or after an invalid feed'
            if mode.startswith('invalid'):
                assert 'REJECTED_INVALID_UPDATE' in result.stdout
        print(f'PASS: {mode}', flush=True)
finally:
    server.shutdown()
