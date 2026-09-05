#!/usr/bin/env python3
"""Compare installed runtime files with their recorded source checkout."""
from pathlib import Path
import sys


def differences(source, installed):
    for name in ("VERSION", "bin/blackhole", "src", "config", "compositors"):
        left, right = source / name, installed / name
        files = {Path(".")} if left.is_file() or right.is_file() else {
            path.relative_to(base) for base in (left, right) if base.is_dir()
            for path in base.rglob("*") if path.is_file() and "__pycache__" not in path.parts
        }
        for relative in sorted(files):
            a, b = left / relative, right / relative
            try:
                same = a.read_bytes() == b.read_bytes()
            except OSError:
                same = False
            if not same:
                yield str(Path(name) / relative)


if __name__ == "__main__":
    installed = Path(__file__).resolve().parents[2]
    receipt = installed / ".tonantzintla-install/source"
    if receipt.is_file():
        source = Path(receipt.read_text().strip())
        if not source.is_dir():
            print("Source checkout unavailable; build comparison skipped.")
        elif source.resolve() != installed:
            changed = list(differences(source, installed))
            if changed:
                print(f"Update pending: {len(changed)} runtime files differ from {source}")
            else:
                print("Installed runtime matches the source checkout.")
