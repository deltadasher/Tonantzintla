#!/usr/bin/env python3

import argparse
import json
import os
import subprocess


def main() -> None:
    parser = argparse.ArgumentParser(description="Index cliphist entries for Tonantzintla")
    parser.add_argument(
        "cache_dir",
        nargs="?",
        default=os.path.expanduser("~/.cache/tonantzintla/clipboard"),
    )
    cache_dir = parser.parse_args().cache_dir
    os.makedirs(cache_dir, exist_ok=True)
    sizes_path = os.path.join(cache_dir, "sizes.json")
    try:
        with open(sizes_path, encoding="utf-8") as size_file:
            known_sizes = json.load(size_file)
    except (OSError, ValueError, TypeError):
        known_sizes = {}

    result = subprocess.run(
        ["cliphist", "list"], capture_output=True, text=True, check=False
    )
    entries = []
    current_ids = set()
    decode_budget = 12

    for line in result.stdout.splitlines()[:120]:
        if "\t" not in line:
            continue
        entry_id, preview = line.split("\t", 1)
        current_ids.add(entry_id)
        is_image = "[[ binary data" in preview
        content = preview.strip()
        content_size = 1800 if is_image else known_sizes.get(entry_id)

        if is_image:
            image_path = os.path.join(cache_dir, f"{entry_id}.png")
            if not os.path.exists(image_path):
                with open(image_path, "wb") as image_file:
                    subprocess.run(
                        ["cliphist", "decode", entry_id],
                        stdout=image_file,
                        check=False,
                    )
            content = image_path
        elif content_size is None and decode_budget > 0:
            decoded = subprocess.run(
                ["cliphist", "decode", entry_id],
                capture_output=True,
                check=False,
            ).stdout
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

    known_sizes = {
        entry_id: size for entry_id, size in known_sizes.items()
        if entry_id in current_ids
    }
    temporary_sizes = sizes_path + ".tmp"
    try:
        with open(temporary_sizes, "w", encoding="utf-8") as size_file:
            json.dump(known_sizes, size_file, separators=(",", ":"))
        os.replace(temporary_sizes, sizes_path)
    except OSError:
        try:
            os.unlink(temporary_sizes)
        except OSError:
            pass

    print(json.dumps(entries, ensure_ascii=False))


if __name__ == "__main__":
    main()
