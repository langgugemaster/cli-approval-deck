# CLI Approval Deck

![macOS](https://img.shields.io/badge/macOS-13%2B-111827?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-AppKit-f97316?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-22c55e?style=flat-square)

A tiny pixel-art command center for people who start an AI coding agent and then
walk away to make coffee.

CLI Approval Deck keeps a floating panel above your macOS desktop. A pixel duck
watches proxied Codex CLI and Claude Code sessions. When a command needs approval,
the duck raises a green checkmark sign and the panel exposes one large approval bar.

## Features

- Always-on-top pixel-art panel with a duck mascot.
- Dock icon and menu bar `[A]` menu.
- Hide the panel completely and restore it from the menu bar.
- Concurrent Codex CLI and Claude Code session monitoring.
- One-click approval for the first safe menu action: `Yes, proceed` or
  `Yes, allow once`.
- No network service, database, or third-party Python dependency.

## Install

Build the app and DMG:

```bash
python3 scripts/package_app.py
```

Artifacts are written to:

```text
dist/CLI Approval Deck.app
dist/CLI-Approval-Deck.dmg
```

Drag `CLI Approval Deck.app` into `/Applications`, launch it, then install the
terminal hooks:

```bash
"/Applications/CLI Approval Deck.app/Contents/Resources/install-shell-hooks"
source ~/.zshrc
```

After that, use the normal commands:

```bash
codex
claude
```

The hooks route new sessions through a local PTY proxy. Existing terminal sessions
cannot be attached after launch because their PTYs already belong to another process.

## Run From Source

```bash
swift run ApprovalFloat
./bin/cli-approval-run codex
./bin/cli-approval-run claude
```

## Verify

```bash
python3 -m unittest discover -s tests/unit -v
swift test
swift build
python3 scripts/package_app.py
```

## How It Works

The wrapper launches the requested CLI inside a pseudo-terminal, preserving raw-mode
input, terminal resizing, and full-screen TUI behavior. It recognizes Codex and Claude
permission prompts, publishes local JSON requests under `~/.cli-approval-float`, and
sends the selected response back to the matching PTY.

## License

MIT. Let the duck work.
