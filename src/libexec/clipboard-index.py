#!/usr/bin/env python3

import argparse
import json
import os
import re
import subprocess
import tempfile

MAX_DECODE_BYTES = 16 * 1024 * 1024


def decode_bounded(entry_id: str, limit: int = MAX_DECODE_BYTES) -> bytes:
    proc = subprocess.Popen(
        ["cliphist", "decode", entry_id],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    chunks = []
    total = 0
    try:
        assert proc.stdout is not None
        while True:
            block = proc.stdout.read(min(65536, limit + 1 - total))
            if not block:
                break
            total += len(block)
            if total > limit:
                proc.kill()
                return b""
            chunks.append(block)
        proc.wait(timeout=8)
        return b"".join(chunks) if proc.returncode == 0 else b""
    except (OSError, subprocess.SubprocessError):
        if proc.poll() is None:
            proc.kill()
        proc.wait()
        return b""
    finally:
        if proc.stdout is not None:
            proc.stdout.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Index cliphist entries for Tonantzintla")
    parser.add_argument(
        "cache_dir",
        nargs="?",
        default=os.path.expanduser("~/.cache/tonantzintla/clipboard"),
    )
    cache_dir = parser.parse_args().cache_dir
    if os.path.islink(cache_dir):
        raise SystemExit(1)
    os.makedirs(cache_dir, mode=0o700, exist_ok=True)
    os.chmod(cache_dir, 0o700)
    sizes_path = os.path.join(cache_dir, "sizes.json")
    try:
        with open(sizes_path, encoding="utf-8") as size_file:
            known_sizes = json.load(size_file)
    except (OSError, ValueError, TypeError):
        known_sizes = {}

    result = subprocess.run(
        ["cliphist", "list"], capture_output=True, text=True, check=False, timeout=8
    )
    entries = []
    current_ids = set()
    decode_budget = 12

    for line in result.stdout.splitlines()[:120]:
        if "\t" not in line:
            continue
        entry_id, preview = line.split("\t", 1)
        if not re.fullmatch(r"[0-9]{1,20}", entry_id):
            continue
        current_ids.add(entry_id)
        is_image = "[[ binary data" in preview
        content = preview.strip()
        content_size = 1800 if is_image else known_sizes.get(entry_id)

        if is_image:
            image_path = os.path.join(cache_dir, f"{entry_id}.png")
            if not os.path.exists(image_path):
                payload = decode_bounded(entry_id)
                if payload:
                    tmp_path = None
                    try:
                        with tempfile.NamedTemporaryFile(
                            dir=cache_dir, suffix=".png.tmp", delete=False
                        ) as image_file:
                            tmp_path = image_file.name
                            image_file.write(payload)
                        os.chmod(tmp_path, 0o600)
                        os.replace(tmp_path, image_path)
                        tmp_path = None
                    except OSError:
                        pass
                    finally:
                        if tmp_path is not None:
                            try:
                                os.unlink(tmp_path)
                            except OSError:
                                pass
            content = image_path
        elif content_size is None and decode_budget > 0:
            decoded = decode_bounded(entry_id)
            content_size = len(decoded.decode("utf-8", errors="replace"))
            known_sizes[entry_id] = content_size
            decode_budget -= 1

        if content_size is None:
            content_size = len(content)

        entries.append(
            {
                "id": entry_id,
                "type": "image" if is_image else "text",
                "content": content,
                "size": content_size,
                "search": "image" if is_image else content.lower(),
            }
        )

    # Cache files belong only to currently indexed entries; old images are not retained forever.
    for name in os.listdir(cache_dir):
        if re.fullmatch(r"[0-9]+\.png", name) and name[:-4] not in current_ids:
            try:
                os.unlink(os.path.join(cache_dir, name))
            except OSError:
                pass

    known_sizes = {
        entry_id: size for entry_id, size in known_sizes.items()
        if entry_id in current_ids
    }
    temporary_sizes = None
    try:
        with tempfile.NamedTemporaryFile(
            "w", dir=cache_dir, suffix=".tmp", delete=False, encoding="utf-8"
        ) as size_file:
            temporary_sizes = size_file.name
            json.dump(known_sizes, size_file, separators=(",", ":"))
        os.chmod(temporary_sizes, 0o600)
        os.replace(temporary_sizes, sizes_path)
        temporary_sizes = None
    except OSError:
        pass
    finally:
        if temporary_sizes is not None:
            try:
                os.unlink(temporary_sizes)
            except OSError:
                pass

    print(json.dumps(entries, ensure_ascii=False))


if __name__ == "__main__":
    main()
