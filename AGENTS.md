# CLI Approval Float

## Test commands
- Python unit tests: `python3 -m unittest discover -s tests/unit -v`
- Swift unit tests: `swift test`
- Build the desktop panel: `swift build`

## Scope
- Keep CLI prompt parsing in `cli_approval_float/proxy.py`.
- Keep the macOS panel focused on displaying pending prompts and submitting one of three choices.
