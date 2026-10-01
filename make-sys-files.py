#!/usr/bin/env python3
"""Build FM-11 /SYS text files with OS-9 CR line endings."""
from __future__ import annotations
import argparse
from pathlib import Path


def cr_text(data: bytes) -> bytes:
    text = data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    return text.replace(b"\n", b"\r")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--sysdir", required=True)
    p.add_argument("--outdir", required=True)
    p.add_argument("commands", nargs="+")
    ns = p.parse_args()

    sysdir = Path(ns.sysdir)
    outdir = Path(ns.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    help_parts: list[bytes] = []
    for cmd in ns.commands:
        hp = sysdir / f"{cmd.lower()}.hp"
        if not hp.is_file():
            # Some upstream commands have no .hp source. They remain usable,
            # but are omitted from /SYS/helpmsg rather than aborting image creation.
            continue
        part = cr_text(hp.read_bytes())
        if part and not part.endswith(b"\r"):
            part += b"\r"
        help_parts.append(part)
    (outdir / "helpmsg").write_bytes(b"".join(help_parts))

    for name in ("errmsg", "password", "motd", "modem.conf"):
        src = sysdir / name
        if not src.is_file():
            raise SystemExit(f"missing SYS source: {src}")
        (outdir / name).write_bytes(cr_text(src.read_bytes()))

    return 0

if __name__ == "__main__":
    raise SystemExit(main())
