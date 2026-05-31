import plistlib
import unittest

from scripts.package_app import BUNDLE_ID, draw_icon, hook_script, info_plist, wrapper_script


class PackageAppTests(unittest.TestCase):
    def test_icon_is_png(self) -> None:
        icon = draw_icon(1024)
        self.assertTrue(icon.startswith(b"\x89PNG\r\n\x1a\n"))

    def test_plist_describes_dock_app(self) -> None:
        plist = info_plist()
        self.assertEqual(plist["CFBundleIdentifier"], BUNDLE_ID)
        self.assertFalse(plist["LSUIElement"])
        self.assertEqual(
            plistlib.loads(plistlib.dumps(plist))["CFBundleExecutable"],
            "ApprovalDeck",
        )

    def test_packaged_scripts_use_embedded_proxy(self) -> None:
        self.assertIn("cli_approval_float.proxy", wrapper_script())
        self.assertIn("/Applications/CLI Approval Deck.app", hook_script())


if __name__ == "__main__":
    unittest.main()
