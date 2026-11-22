#!/usr/bin/env python3
"""Search Wikimedia Commons for large images and download selected results.

Commons exposes a documented JSON API and license metadata, so Tonantzintla does
not need to scrape a private web token or inherit another shell's search flow.
Downloaded files remain user data and are never added to the repository.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import http.cookiejar
import ipaddress
import json
import mimetypes
import os
from pathlib import Path
import socket
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request


USER_AGENT = "Tonantzintla/1.0 wallpaper-browser (https://github.com/deltadasher/Tonantzintla)"
MAX_RESULTS = 24
QUERY_LIMIT = 32
MAX_JSON_BYTES = 8 * 1024 * 1024
MAX_THUMB_BYTES = 2 * 1024 * 1024
MAX_DOWNLOAD = 64 * 1024 * 1024
MAX_REDIRECTS = 4
PREVIEW_WIDTH = 640
THUMBNAIL_WORKERS = 6
SEARCH_CACHE_SECONDS = 15 * 60
COMMONS_API = "https://commons.wikimedia.org/w/api.php"
ALLOWED_HOSTS = frozenset({"commons.wikimedia.org", "upload.wikimedia.org"})


def validate_remote_url(url: str) -> str:
    """Allow only HTTPS Wikimedia URLs resolving to public IP addresses."""
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme.lower() != "https":
        raise ValueError("Only HTTPS Wikimedia URLs are allowed")
    if parsed.username or parsed.password:
        raise ValueError("URL credentials are not allowed")
    if parsed.port not in (None, 443):
        raise ValueError("Non-standard ports are not allowed")
    host = (parsed.hostname or "").rstrip(".").lower()
    if host not in ALLOWED_HOSTS:
        raise ValueError("Remote host is not in the Wikimedia allowlist")
    try:
        infos = socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM)
    except OSError as error:
        raise RuntimeError(f"Could not resolve {host}") from error
    if not infos:
        raise RuntimeError(f"Could not resolve {host}")
    for _family, _socktype, _proto, _canonname, sockaddr in infos:
        address = ipaddress.ip_address(sockaddr[0])
        if not address.is_global:
            raise ValueError("Remote host resolved to a non-public address")
    return url


class SafeRedirectHandler(urllib.request.HTTPRedirectHandler):
    max_redirections = MAX_REDIRECTS

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        target = urllib.parse.urljoin(req.full_url, newurl)
        validate_remote_url(target)
        return super().redirect_request(req, fp, code, msg, headers, target)


def valid_image_bytes(data: bytes) -> bool:
    header = data[:32]
    return (
        header.startswith(b"\x89PNG\r\n\x1a\n")
        or header.startswith(b"\xff\xd8\xff")
        or header.startswith((b"GIF87a", b"GIF89a"))
        or (header.startswith(b"RIFF") and header[8:12] == b"WEBP")
        or (len(header) >= 12 and header[4:8] == b"ftyp"
            and header[8:12] in {b"avif", b"avis", b"mif1"})
    )


def cache_root() -> Path:
    root = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "tonantzintla" / "online-wallpapers"
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    return root


def opener() -> urllib.request.OpenerDirector:
    cookies = http.cookiejar.CookieJar()
    return urllib.request.build_opener(SafeRedirectHandler(), urllib.request.HTTPCookieProcessor(cookies))


def request_json(client: urllib.request.OpenerDirector, url: str) -> dict:
    validate_remote_url(url)
    request = urllib.request.Request(url, headers={
        "User-Agent": USER_AGENT,
        "Accept": "application/json",
    })
    with client.open(request, timeout=12) as response:
        payload = response.read(MAX_JSON_BYTES + 1)
    if len(payload) > MAX_JSON_BYTES:
        raise RuntimeError("Search response exceeded size limit")
    return json.loads(payload.decode("utf-8"))


def metadata_value(info: dict[str, object], key: str) -> str:
    metadata = info.get("extmetadata", {})
    if not isinstance(metadata, dict):
        return ""
    value = metadata.get(key, {})
    return str(value.get("value", "")) if isinstance(value, dict) else ""


def commons_search_url(query: str) -> str:
    params = {
        "action": "query",
        "format": "json",
        "formatversion": "2",
        "generator": "search",
        "gsrnamespace": "6",
        "gsrsearch": query,
        "gsrlimit": str(QUERY_LIMIT),
        "gsrsort": "relevance",
        "prop": "imageinfo",
        "iiprop": "url|size|mime|extmetadata",
        "iiextmetadatafilter": "LicenseShortName|Artist",
        "iiurlwidth": str(PREVIEW_WIDTH),
        "origin": "*",
    }
    return COMMONS_API + "?" + urllib.parse.urlencode(params)


def parse_commons_results(data: dict[str, object]) -> list[dict[str, object]]:
    query = data.get("query", {})
    pages = query.get("pages", []) if isinstance(query, dict) else []
    if not isinstance(pages, list):
        return []

    entries: list[dict[str, object]] = []
    for page in pages:
        if not isinstance(page, dict):
            continue
        image_info = page.get("imageinfo", [])
        if not isinstance(image_info, list) or not image_info:
            continue
        info = image_info[0]
        if not isinstance(info, dict):
            continue
        try:
            width = int(info.get("width", 0))
            height = int(info.get("height", 0))
        except (TypeError, ValueError):
            continue
        mime = str(info.get("mime", ""))
        image_url = str(info.get("url", ""))
        preview_url = str(info.get("thumburl", image_url))
        if width < 1920 or height < 1080 or not mime.startswith("image/"):
            continue
        if not image_url or not preview_url:
            continue
        title = str(page.get("title", "Commons image"))
        if title.lower().startswith("file:"):
            title = title[5:]
        entries.append({
            "path": "",
            "preview": "",
            "previewUrl": preview_url,
            "name": title[:90],
            "kind": "image",
            "source": "Online",
            "provider": "Wikimedia Commons",
            "color": "",
            "bucket": "Unsorted",
            "remoteUrl": image_url,
            "sourcePage": str(info.get("descriptionurl", "")),
            "license": metadata_value(info, "LicenseShortName"),
            "artist": metadata_value(info, "Artist"),
            "width": width,
            "height": height,
        })
    return entries


def download_thumbnail(url: str, key: str) -> str:
    directory = cache_root() / "thumbs"
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    destination = directory / f"{key}.jpg"
    if destination.is_file() and destination.stat().st_size > 512:
        return str(destination)
    try:
        validate_remote_url(url)
        client = opener()
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with client.open(request, timeout=6) as response:
            data = response.read(MAX_THUMB_BYTES + 1)
        if 512 < len(data) <= MAX_THUMB_BYTES and valid_image_bytes(data):
            temporary = None
            try:
                with tempfile.NamedTemporaryFile(dir=directory, suffix=".tmp", delete=False) as handle:
                    temporary = Path(handle.name)
                    handle.write(data)
                os.chmod(temporary, 0o600)
                temporary.replace(destination)
                temporary = None
            finally:
                if temporary is not None:
                    temporary.unlink(missing_ok=True)
            return str(destination)
    except (OSError, ValueError, RuntimeError, urllib.error.URLError):
        pass
    return ""


def search_cache_path(query: str) -> Path:
    key = hashlib.sha1(query.casefold().encode()).hexdigest()[:20]
    return cache_root() / "searches" / f"{key}.json"


def cached_search(query: str) -> list[dict[str, object]] | None:
    path = search_cache_path(query)
    try:
        if time.time() - path.stat().st_mtime > SEARCH_CACHE_SECONDS:
            return None
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError, TypeError):
        return None
    if not isinstance(payload, list):
        return None
    entries = [entry for entry in payload
               if isinstance(entry, dict)
               and Path(str(entry.get("preview", ""))).is_file()]
    return entries or None


def cache_search(query: str, entries: list[dict[str, object]]) -> None:
    path = search_cache_path(query)
    temporary = None
    try:
        path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        with tempfile.NamedTemporaryFile("w", dir=path.parent, suffix=".tmp", delete=False, encoding="utf-8") as handle:
            temporary = Path(handle.name)
            json.dump(entries, handle, separators=(",", ":"))
        os.chmod(temporary, 0o600)
        temporary.replace(path)
        temporary = None
    except OSError:
        pass
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def prepare_result(result: dict[str, object]) -> dict[str, object] | None:
    image_url = str(result["remoteUrl"])
    key = hashlib.sha1(image_url.encode()).hexdigest()[:20]
    preview = download_thumbnail(str(result.pop("previewUrl")), key)
    if not preview:
        return None
    result["preview"] = preview
    return result


def search(raw_query: str) -> list[dict[str, object]]:
    query = raw_query.strip()
    if not query:
        return []
    cached = cached_search(query)
    if cached is not None:
        return cached
    client = opener()
    data = request_json(client, commons_search_url(query))
    candidates = parse_commons_results(data)[:MAX_RESULTS]
    workers = min(THUMBNAIL_WORKERS, max(1, len(candidates)))
    with ThreadPoolExecutor(max_workers=workers, thread_name_prefix="tonantzintla-wall") as pool:
        resolved = pool.map(prepare_result, candidates)
        entries = [entry for entry in resolved if entry is not None]
    cache_search(query, entries)
    return entries


def safe_extension(content_type: str, url: str) -> str:
    guessed = mimetypes.guess_extension(content_type.split(";", 1)[0].strip()) or ""
    if guessed in {".jpg", ".jpeg", ".png", ".webp", ".gif", ".avif"}:
        return guessed
    suffix = Path(urllib.parse.urlparse(url).path).suffix.lower()
    return suffix if suffix in {".jpg", ".jpeg", ".png", ".webp", ".gif", ".avif"} else ".jpg"


def download(url: str) -> dict[str, object]:
    validate_remote_url(url)
    directory = Path.home() / "Pictures" / "Wallpapers" / "Tonantzintla" / "Stills"
    directory.mkdir(parents=True, exist_ok=True)
    client = opener()
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with client.open(request, timeout=20) as response:
        content_type = response.headers.get("Content-Type", "image/jpeg")
        if not content_type.lower().startswith("image/"):
            raise RuntimeError("Remote result did not return an image")
        extension = safe_extension(content_type, url)
        key = hashlib.sha1(url.encode()).hexdigest()[:18]
        destination = directory / f"tonantzintla-{key}{extension}"
        temporary = None
        written = 0
        signature = bytearray()
        try:
            with tempfile.NamedTemporaryFile(dir=directory, suffix=".part", delete=False) as handle:
                temporary = Path(handle.name)
                while True:
                    block = response.read(128 * 1024)
                    if not block:
                        break
                    if len(signature) < 32:
                        signature.extend(block[:32 - len(signature)])
                    written += len(block)
                    if written > MAX_DOWNLOAD:
                        raise RuntimeError("Wallpaper exceeded the 64 MB download limit")
                    handle.write(block)
            if written < 1024:
                raise RuntimeError("Remote wallpaper was empty")
            if not valid_image_bytes(bytes(signature)):
                raise RuntimeError("Remote result was not a supported image")
            os.chmod(temporary, 0o644)
            temporary.replace(destination)
            temporary = None
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)
    return {"ok": True, "path": str(destination), "name": destination.name, "kind": "image"}


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    search_parser = subparsers.add_parser("search")
    search_parser.add_argument("query")
    download_parser = subparsers.add_parser("download")
    download_parser.add_argument("url")
    args = parser.parse_args()
    try:
        payload: object = search(args.query) if args.command == "search" else download(args.url)
        print(json.dumps(payload, separators=(",", ":")))
    except Exception as error:  # Network failures are surfaced to the QML status line.
        print(json.dumps({"ok": False, "error": str(error)}, separators=(",", ":")))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
