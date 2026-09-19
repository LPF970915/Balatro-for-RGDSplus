"""Reproduce the reviewed, game-free adapter. Uses only Python's standard library."""

import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
APP = "Ports/BalatroDual/"
ENTRY = "Ports/Balatro for RGDSplus.sh"
GAME_DATA_NOTICE = APP + "gamedata/PUT_Balatro.exe_HERE.txt"
EMPTY_DIRS = tuple(APP + p + "/" for p in ("saves", "logs", "cache"))
FORBIDDEN = {".exe", ".love", ".jkr", ".png", ".jpg", ".ogg", ".wav", ".ttf", ".otf",
             ".zip", ".7z", ".tar", ".gz", ".log"}
SENSITIVE = (
    rb"(?:192\.168|10\.0)\.\d+\.\d+",
    rb"[A-Za-z]:[\\/](?:Users|Works|Program Files)[\\/]",
    rb"gh[pousr]_[A-Za-z0-9]{20,}",
    rb"github_pat_[A-Za-z0-9_]{20,}",
    rb"-----BEGIN (?:OPENSSH|RSA|EC|DSA) PRIVATE KEY-----",
    rb"steamLoginSecure",
    rb"(?<!\d)7656119\d{10}(?!\d)",
)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def allowed_name(name):
    path = PurePosixPath(name)
    return (bool(name) and not path.is_absolute() and
            not any(p in ("", ".", "..") for p in name.split("/")) and
            not any(c in name for c in ("\\", ":")) and
            not any(ord(c) < 32 for c in name) and
            path.suffix.lower() not in FORBIDDEN and
            not any(p.lower() in ("saves", "logs", "cache", "private", "private-test")
                    for p in path.parts) and
            ("gamedata" not in path.parts or name == GAME_DATA_NOTICE))


def verify_adapter(root=ROOT):
    root = Path(root)
    source = root / "adapter"
    inventory = json.loads((root / "metadata/adapter-files.json").read_text(encoding="utf-8"))
    expected = inventory["files"]
    actual = {}
    for path in source.rglob("*"):
        if path.is_symlink():
            raise ValueError("Symlink not allowed: " + str(path))
        if not path.is_file():
            continue
        name = path.relative_to(source).as_posix()
        if not allowed_name(name):
            raise ValueError("Forbidden package path: " + name)
        data = path.read_bytes()
        if name not in expected or digest(data) != expected[name]:
            raise ValueError("Unreviewed or changed package file: " + name)
        if name.endswith((".lua", ".bin", ".sh", ".json", ".md", ".txt")):
            data.decode("utf-8")
            if any(re.search(pattern, data) for pattern in SENSITIVE):
                raise ValueError("Potential private information: " + name)
        actual[name] = data
    if set(actual) != set(expected):
        raise ValueError("Missing reviewed files")
    manifest = json.loads(actual[APP + "build-manifest.json"])
    if manifest["bundled_game"] is not False or manifest["tests_enabled"] is not False:
        raise ValueError("Release manifest must disable bundled game and test commands")
    if manifest["entrypoint"] != ENTRY:
        raise ValueError("Unexpected entrypoint")
    checked = set()
    for line in actual[APP + "CHECKSUMS.sha256"].decode().splitlines():
        sha, name = line.split("  ", 1)
        key = ENTRY if name == "../" + PurePosixPath(ENTRY).name else APP + name
        if key in checked or not allowed_name(key) or digest(actual[key]) != sha:
            raise ValueError("Invalid internal checksum: " + name)
        checked.add(key)
    required = {n for n in actual if n.startswith(APP) and n != APP + "CHECKSUMS.sha256"} | {ENTRY}
    if checked != required:
        raise ValueError("Internal checksum coverage differs from package contents")
    patch_map = json.loads((root / "metadata/patch-map.json").read_text())
    payloads = set()
    for item in patch_map["files"]:
        payload = item.get("payload")
        if payload:
            name = APP + "installer/" + payload
            data = actual[name]
            if digest(data) != item["payload_sha256"]:
                raise ValueError("Patch payload mismatch")
            payloads.add(name)
            if not item.get("source") and not item["path"].endswith(".lua"):
                raise ValueError("Non-code addon")
    if payloads != {n for n in actual if n.startswith(APP + "installer/payload/")}:
        raise ValueError("Unexpected patch payload")
    for name in (ENTRY, APP + "launch.sh", APP + "dual_touch.sh"):
        if b"\r" in actual[name]:
            raise ValueError("Shell scripts must use LF endings")
    if not actual[APP + "runtime/love.aarch64"].startswith(b"\x7fELF"):
        raise ValueError("Unexpected runtime format")
    return actual, inventory


def build(root=ROOT):
    root = Path(root)
    files, inventory = verify_adapter(root)
    out = root / "dist" / inventory["release_file"]
    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as archive:
        for name in EMPTY_DIRS:
            info = zipfile.ZipInfo(name, (2026, 9, 19, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (0o40755 << 16) | 0x10
            archive.writestr(info, b"")
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(name, (2026, 9, 19, 0, 0, 0))
            info.create_system = 3
            executable = name.endswith(".sh") or name.endswith("/love.aarch64")
            info.external_attr = (0o100755 if executable else 0o100644) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, data)
    with zipfile.ZipFile(out) as archive:
        if archive.testzip() is not None:
            raise ValueError("Release ZIP CRC failure")
        if set(archive.namelist()) != set(files) | set(EMPTY_DIRS):
            raise ValueError("Release ZIP membership mismatch")
        for name, data in files.items():
            if archive.read(name) != data:
                raise ValueError("Release ZIP content mismatch")
    sha = digest(out.read_bytes())
    out.with_suffix(".zip.sha256").write_text(f"{sha}  {out.name}\n", encoding="ascii")
    report = {"release_file": out.name, "bytes": out.stat().st_size, "sha256": sha,
              "bundled_game": False, "reviewed_files": len(files),
              "bundled_game_archives": 0, "bundled_game_assets": 0, "private_data_files": 0}
    out.with_suffix(".audit.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return out


if __name__ == "__main__":
    build()
