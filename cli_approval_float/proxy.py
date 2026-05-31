from __future__ import annotations

import argparse
import json
import os
import pty
import re
import select
import shutil
import signal
import struct
import sys
import termios
import time
import tty
import uuid
from dataclasses import dataclass
from pathlib import Path

ANSI_RE = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))")
OPTION_RE = re.compile(r"^\s*(?:[❯>]\s*)?([1-9])[\.)]\s+(.+?)\s*$")
AUTH_RE = re.compile(
    r"(?i)(allow|approve|authori[sz]e|permission|proceed|run (?:this |the )?command|"
    r"execute|授权|允许|确认|是否执行|would you like)"
)


@dataclass(frozen=True)
class Option:
    key: str
    label: str


def strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text).replace("\r", "")


def detect_prompt(text: str) -> tuple[str, list[Option]] | None:
    clean = strip_ansi(text)[-8000:]
    lines = clean.splitlines()
    options: list[Option] = []
    for line in lines[-30:]:
        match = OPTION_RE.match(line)
        if match:
            option = Option(match.group(1), match.group(2))
            options = [item for item in options if item.key != option.key]
            options.append(option)
    options = sorted(options, key=lambda item: item.key)
    if len(options) != 3 or not AUTH_RE.search(clean):
        return None
    prompt_lines = [line.strip() for line in lines[-12:] if line.strip()]
    return "\n".join(prompt_lines), options


def copy_terminal_size(source_fd: int, target_fd: int) -> None:
    if not os.isatty(source_fd):
        return
    size = termios.tcgetwinsize(source_fd)
    termios.tcsetwinsize(target_fd, size)


class ApprovalFiles:
    def __init__(self, directory: Path) -> None:
        self.directory = directory
        self.pending_directory = directory / "pending"

    def publish(self, command: list[str], prompt: str, options: list[Option]) -> str:
        self.pending_directory.mkdir(parents=True, exist_ok=True)
        request_id = uuid.uuid4().hex
        payload = {
            "requestId": request_id,
            "command": " ".join(command),
            "prompt": prompt,
            "options": [{"key": item.key, "label": item.label} for item in options],
            "createdAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }
        pending_path = self.pending_directory / f"{request_id}.json"
        temporary = pending_path.with_suffix(".tmp")
        temporary.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
        temporary.replace(pending_path)
        return request_id

    def consume_response(self, request_id: str) -> str | None:
        response = self.directory / f"response-{request_id}.txt"
        if not response.exists():
            return None
        key = response.read_text(encoding="utf-8").strip()
        response.unlink()
        self.clear(request_id)
        return key

    def clear(self, request_id: str | None) -> None:
        if request_id is not None:
            (self.pending_directory / f"{request_id}.json").unlink(missing_ok=True)


def run(command: list[str], state_dir: Path) -> int:
    if not command:
        raise ValueError("missing command")
    executable = shutil.which(command[0])
    if executable is None:
        raise FileNotFoundError(f"command not found: {command[0]}")

    files = ApprovalFiles(state_dir)
    pid, fd = pty.fork()
    if pid == 0:
        os.execvp(executable, command)

    buffer = ""
    request_id: str | None = None
    last_signature: tuple[Option, ...] | None = None
    stdin_fd = sys.stdin.fileno()
    stdin_is_tty = os.isatty(stdin_fd)
    original_terminal_attributes = termios.tcgetattr(stdin_fd) if stdin_is_tty else None

    def forward_window_size(_signum: int, _frame: object) -> None:
        copy_terminal_size(stdin_fd, fd)

    previous_window_handler = signal.getsignal(signal.SIGWINCH)
    try:
        copy_terminal_size(stdin_fd, fd)
        signal.signal(signal.SIGWINCH, forward_window_size)
        if stdin_is_tty:
            tty.setraw(stdin_fd)
        while True:
            ready, _, _ = select.select([fd, stdin_fd], [], [], 0.2)
            if fd in ready:
                try:
                    data = os.read(fd, 4096)
                except OSError:
                    break
                if not data:
                    break
                os.write(sys.stdout.fileno(), data)
                buffer = (buffer + data.decode(errors="replace"))[-12000:]
                detected = detect_prompt(buffer)
                if detected:
                    prompt, options = detected
                    signature = tuple(options)
                    if request_id is None or signature != last_signature:
                        request_id = files.publish(command, prompt, options)
                        last_signature = signature
            if stdin_fd in ready:
                data = os.read(stdin_fd, 4096)
                if data:
                    os.write(fd, data)
            if request_id:
                key = files.consume_response(request_id)
                if key:
                    os.write(fd, f"{key}\n".encode())
                    request_id = None
                    last_signature = None
                    buffer = ""
    finally:
        signal.signal(signal.SIGWINCH, previous_window_handler)
        if original_terminal_attributes is not None:
            termios.tcsetattr(stdin_fd, termios.TCSAFLUSH, original_terminal_attributes)
        files.clear(request_id)
    _, status = os.waitpid(pid, 0)
    return os.waitstatus_to_exitcode(status)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run a CLI through a PTY and expose three-option approval prompts."
    )
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    state_dir = Path(
        os.environ.get("CLI_APPROVAL_FLOAT_DIR", "~/.cli-approval-float")
    ).expanduser()
    try:
        return run(args.command, state_dir)
    except (FileNotFoundError, ValueError) as error:
        print(f"cli-approval-run: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
