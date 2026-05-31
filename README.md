# CLI Approval Float

macOS desktop floating panel for three-option authorization prompts from CLI tools such
as Codex CLI and Claude Code. It stays above normal windows and follows every desktop
Space.

## Start

Build and start the floating panel:

```bash
cd /Users/samuel/cli-approval-float
swift run ApprovalFloat
```

In another terminal, run a CLI through the PTY proxy:

```bash
/Users/samuel/cli-approval-float/bin/cli-approval-run codex
/Users/samuel/cli-approval-float/bin/cli-approval-run claude
```

The proxy leaves each terminal fully interactive. Start every CLI session through the
proxy. When one or more sessions show authorization prompts containing exactly three
numbered choices, the panel displays the pending queue and sends each selected number
back to the matching CLI session.

Already-running CLI sessions cannot be attached reliably because their PTYs belong to
their existing terminal processes. Restart those sessions through `cli-approval-run`.

## Optional shell alias

```bash
alias codex-float='/Users/samuel/cli-approval-float/bin/cli-approval-run codex'
alias claude-float='/Users/samuel/cli-approval-float/bin/cli-approval-run claude'
```

## Verify

```bash
python3 -m unittest discover -s tests/unit -v
swift test
swift build
```
