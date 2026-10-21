"""Exercise release checkpoints with local tool doubles; no Apple uploads occur."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
TOOLS = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
root = pathlib.Path(os.environ["RELEASE_TEST_ROOT"])
config = json.loads((root / "config.json").read_text())
with (root / "calls.jsonl").open("a") as calls:
    calls.write(json.dumps([name, *args]) + "\n")
if name == "security":
    print('  1) ABCDEF "Developer ID Application: Release Test (TESTTEAM)"')
elif name == "python":
    pathlib.Path(args[-1]).write_bytes(b"signed disk image")
elif name == "xcrun" and args[0] == "notarytool":
    operation = args[1]
    if operation == "history":
        print(json.dumps({"history": []}))
    elif operation == "submit":
        if config.get("upload_error"):
            sys.exit(2)
        kind = "app" if args[2].endswith(".zip") else "dmg"
        print(json.dumps({"id": kind, "status": "In Progress"}))
    elif operation == "info":
        print(json.dumps({"id": args[2], "status": config[args[2]]}))
    elif operation == "log":
        pathlib.Path(args[-1]).write_text('{"issues": ["test rejection"]}')
elif name == "xcrun" and args[:2] == ["stapler", "staple"]:
    target = pathlib.Path(args[2])
    if target.is_file() and not target.read_bytes().endswith(b"ticket"):
        target.write_bytes(target.read_bytes() + b"ticket")
elif name == "syspolicy_check" and config.get("distribution_error"):
    print("test distribution failure")
    sys.exit(1)
elif name == "spctl" and config.get("assessment_error"):
    sys.exit(1)
elif name == "hdiutil" and args[0] == "attach":
    mount = pathlib.Path(args[args.index("-mountpoint") + 1])
    (mount / "ColdKey.app").mkdir(exist_ok=True)
'''


class NotarizationWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for name in ("scripts", "Sources", "Assets", "dist", "bin", ".build/dmg-tools/bin"):
            (self.root / name).mkdir(parents=True)
        for name in ("build-dmg.sh", "ColdKey.entitlements", "dmg-settings.py", "requirements-dmg.txt", "update-public-key.txt"):
            shutil.copy2(ROOT / "scripts" / name, self.root / "scripts" / name)
        (self.root / "Package.swift").write_text("// test input\n")
        (self.root / "Package.resolved").write_text('{"pins": []}\n')
        (self.root / "Sources/main.swift").write_text("// test app\n")
        (self.root / "Assets/hotkey-original.png").write_bytes(b"test icon")
        build = self.root / "scripts/build-app.sh"
        build.write_text('#!/bin/bash\nmkdir -p "$1/Contents/MacOS"\nprintf app > "$1/Contents/MacOS/Coldkey"\n')
        build.chmod(0o755)
        helper = self.root / "bin/tool-double"
        helper.write_text(TOOLS)
        helper.chmod(0o755)
        for name in ("security", "xcrun", "lipo", "codesign", "hdiutil", "spctl", "syspolicy_check"):
            (self.root / "bin" / name).symlink_to(helper)
        (self.root / ".build/dmg-tools/bin/python").symlink_to(helper)
        shutil.copyfile(self.root / "scripts/requirements-dmg.txt", self.root / ".build/dmg-tools/requirements.txt")
        self.output = self.root / "dist/ColdKey.dmg"
        self.output.write_bytes(b"previous installer")
        self.state = self.root / ".build/ColdKey-notarization-state.json"
        self.config = {"app": "In Progress", "dmg": "In Progress"}
        self.environment = dict(os.environ, PATH=str(self.root / "bin") + ":" + os.environ["PATH"],
                                RELEASE_TEST_ROOT=str(self.root), COLDKEY_NOTARY_PROFILE="TestProfile")
        self.environment.pop("COLDKEY_SIGNING_IDENTITY", None)

    def run_release(self, option):
        (self.root / "config.json").write_text(json.dumps(self.config))
        return subprocess.run(["bash", "scripts/build-dmg.sh", option], cwd=self.root,
                              env=self.environment, capture_output=True, text=True, timeout=30)

    def uploads(self):
        return [call for call in self.calls() if call[:3] == ["xcrun", "notarytool", "submit"]]

    def calls(self):
        path = self.root / "calls.jsonl"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def assert_pending(self, result):
        self.assertEqual(result.returncode, 75, result.stdout + result.stderr)
        self.assertTrue(self.state.exists())
        self.assertFalse(Path(str(self.state) + ".lock").exists())
        self.assertEqual(self.output.read_bytes(), b"previous installer")

    def test_pending_checks_reuse_submission_and_block_duplicate_start(self):
        self.assert_pending(self.run_release("--notarize"))
        self.assert_pending(self.run_release("--resume"))
        self.assertEqual(self.run_release("--notarize").returncode, 2)
        self.assertEqual(len(self.uploads()), 1)

    def test_accepted_app_and_dmg_publish_only_after_both_tickets(self):
        self.assert_pending(self.run_release("--notarize"))
        self.config["app"] = "Accepted"
        self.assert_pending(self.run_release("--resume"))
        self.assertEqual(len(self.uploads()), 2)
        self.config["dmg"] = "Accepted"
        self.config["assessment_error"] = True
        self.assertEqual(self.run_release("--resume").returncode, 1)
        self.assertTrue(self.state.exists())
        self.assertEqual(self.output.read_bytes(), b"previous installer")
        self.config["assessment_error"] = False
        result = self.run_release("--resume")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(self.uploads()), 2)
        self.assertFalse(self.state.exists())
        self.assertEqual(self.output.read_bytes(), b"signed disk imageticket")
        for suffix in (".app-notarization.json", ".notarization.json"):
            self.assertEqual(json.loads(Path(str(self.output) + suffix).read_text())["status"], "Accepted")
        checksum = subprocess.run(["shasum", "-a", "256", "-c", "ColdKey.dmg.sha256"],
                                  cwd=self.output.parent, capture_output=True)
        self.assertEqual(checksum.returncode, 0)
        builders = [call for call in self.calls() if call[0] == "python"]
        self.assertEqual(len(builders), 1, "Resuming must retain the submitted DMG")

    def test_rejection_keeps_old_installer_and_diagnostic_log(self):
        self.assert_pending(self.run_release("--notarize"))
        self.config["app"] = "Invalid"
        result = self.run_release("--resume")
        self.assertEqual(result.returncode, 1)
        stage = Path(json.loads(self.state.read_text())["staging"])
        self.assertTrue((stage / "app-notarization.json.log.json").exists())
        self.assertEqual(self.output.read_bytes(), b"previous installer")
        self.assertEqual(len(self.uploads()), 1)

    def test_source_changes_and_distribution_failure_stop_publication(self):
        self.assert_pending(self.run_release("--notarize"))
        source = self.root / "Sources/main.swift"
        original = source.read_bytes()
        source.write_text("// newer app\n")
        result = self.run_release("--resume")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Release inputs changed", result.stderr)
        source.write_bytes(original)
        self.config.update(app="Accepted", distribution_error=True)
        self.assertEqual(self.run_release("--resume").returncode, 1)
        self.assertEqual(len(self.uploads()), 1)
        self.assertEqual(self.output.read_bytes(), b"previous installer")

    def test_uncertain_upload_is_never_repeated_automatically(self):
        self.config["upload_error"] = True
        self.assertEqual(self.run_release("--notarize").returncode, 1)
        self.assertEqual(self.run_release("--resume").returncode, 1)
        self.assertEqual(self.run_release("--notarize").returncode, 2)
        self.assertEqual(len(self.uploads()), 1)
        self.assertTrue(self.state.exists())
        self.assertEqual(self.output.read_bytes(), b"previous installer")


if __name__ == "__main__":
    unittest.main()
