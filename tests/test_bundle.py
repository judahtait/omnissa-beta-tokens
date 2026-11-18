import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class BundleTests(unittest.TestCase):
    def test_bundle_builds_and_runs(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "omnissa-beta-tokens.py"
            r = subprocess.run([sys.executable, str(ROOT / "tools" / "bundle.py"), str(out)],
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            v = subprocess.run([sys.executable, str(out), "--version"], capture_output=True, text=True)
            self.assertEqual(v.returncode, 0, v.stderr)
            self.assertRegex(v.stdout.strip(), r"^\d+\.\d+\.\d+$")
            text = out.read_text()
            self.assertNotIn("from .", text)  # no relative imports left


if __name__ == "__main__":
    unittest.main()
