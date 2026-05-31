import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from cli_approval_float.proxy import ApprovalFiles, Option, detect_prompt, strip_ansi


class DetectPromptTests(unittest.TestCase):
    def test_detects_three_option_authorization_prompt(self) -> None:
        result = detect_prompt(
            "\x1b[32mWould you like to run this command?\x1b[0m\r\n"
            "1. Allow once\r\n"
            "2. Allow for this session\r\n"
            "3. Reject\r\n"
        )
        self.assertEqual(
            result,
            (
                "Would you like to run this command?\n"
                "1. Allow once\n2. Allow for this session\n3. Reject",
                [
                    Option("1", "Allow once"),
                    Option("2", "Allow for this session"),
                    Option("3", "Reject"),
                ],
            ),
        )

    def test_ignores_non_authorization_menu(self) -> None:
        self.assertIsNone(detect_prompt("Choose a file:\n1. A\n2. B\n3. C\n"))

    def test_strip_ansi(self) -> None:
        self.assertEqual(strip_ansi("\x1b[31mAllow?\x1b[0m\r\n"), "Allow?\n")


class ApprovalFilesTests(unittest.TestCase):
    def test_publish_and_consume_response(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            files = ApprovalFiles(Path(temporary))
            with patch("cli_approval_float.proxy.uuid.uuid4") as uuid4:
                uuid4.return_value.hex = "request-id"
                request_id = files.publish(
                    ["codex", "--help"],
                    "Allow?",
                    [Option("1", "Allow"), Option("2", "Always"), Option("3", "Reject")],
                )
            payload = json.loads(
                (files.pending_directory / "request-id.json").read_text(encoding="utf-8")
            )
            self.assertEqual(request_id, "request-id")
            self.assertEqual(payload["command"], "codex --help")

            (Path(temporary) / "response-request-id.txt").write_text("2", encoding="utf-8")
            self.assertEqual(files.consume_response(request_id), "2")
            self.assertFalse((files.pending_directory / "request-id.json").exists())

    def test_multiple_requests_do_not_overwrite_each_other(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            files = ApprovalFiles(Path(temporary))
            with patch("cli_approval_float.proxy.uuid.uuid4") as uuid4:
                uuid4.return_value.hex = "first"
                files.publish(["codex"], "Allow?", [Option("1", "Allow")])
                uuid4.return_value.hex = "second"
                files.publish(["claude"], "Proceed?", [Option("1", "Yes")])

            pending = sorted(path.name for path in files.pending_directory.glob("*.json"))
            self.assertEqual(pending, ["first.json", "second.json"])
            files.clear("first")
            self.assertFalse((files.pending_directory / "first.json").exists())
            self.assertTrue((files.pending_directory / "second.json").exists())


if __name__ == "__main__":
    unittest.main()
