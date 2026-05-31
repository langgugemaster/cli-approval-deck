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

The proxy leaves the terminal fully interactive. When it detects an authorization
prompt containing exactly three numbered choices, the panel displays the choices and
sends the selected number back to that CLI session.

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
