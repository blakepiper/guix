#!/usr/bin/env python3
"""Prepare locked source dependencies, before entering Guix's offline sandbox.

Run with ./scripts/guix shell -m scripts/codex-manifest.scm -- python3 scripts/prepare-codex.py
The manifest supplies Python 3.12+ and Rust/Cargo 1.95.0, matching the recipe
and upstream toolchain pin. No upstream executables are downloaded.
Cargo verifies registry checksums and the exact Git revisions in Cargo.lock.
The result is local source input, not a globally downloadable Guix substitute.
"""
import gzip
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]


def prepare():
    release = json.loads((ROOT / "sources/releases.json").read_text())["codex"]
    destination = ROOT / "sources" / f"codex-{release['version']}-vendored.tar.gz"
    with tempfile.TemporaryDirectory(prefix=".prepare-", dir=ROOT / "sources") as tmp:
        work = pathlib.Path(tmp)
        archive = work / "source.tar.gz"
        with urllib.request.urlopen(release["url"]) as response, archive.open("wb") as out:
            shutil.copyfileobj(response, out)
        if hashlib.file_digest(archive.open("rb"), "sha256").hexdigest() != release["sha256"]:
            raise RuntimeError("Codex source checksum mismatch")
        with tarfile.open(archive) as tar:
            tar.extractall(work, filter="data")
        source = next(p for p in work.iterdir() if p.is_dir())
        rust = source / "codex-rs"
        # Upstream's release tagging changes Cargo.toml but leaves local
        # workspace versions at 0.0.0 in Cargo.lock. Change only those entries;
        # every registry/Git dependency and checksum remains exactly pinned.
        lock = rust / "Cargo.lock"
        blocks = lock.read_text().split("[[package]]")
        for index, block in enumerate(blocks):
            if index and not re.search(r"^source =", block, re.M):
                blocks[index] = re.sub(r'^version = "0\.0\.0"$',
                                       f'version = "{release["version"]}"',
                                       block, flags=re.M)
        lock.write_text("[[package]]".join(blocks))
        original_lock = (rust / "Cargo.lock").read_bytes()
        config = subprocess.check_output(
            ["cargo", "vendor", "--locked", "vendor"], cwd=rust, text=True
        )
        assert (rust / "Cargo.lock").read_bytes() == original_lock, "Cargo changed the lockfile"
        with (rust / ".cargo/config.toml").open("a") as out:
            out.write("\n" + config)
        # Stable metadata and traversal order; no host paths or timestamps.
        def normalize(info):
            info.uid = info.gid = info.mtime = 0
            info.uname = info.gname = ""
            return info
        packed = work / "packed.tar.gz"
        with packed.open("wb") as raw, gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as gz:
            with tarfile.open(fileobj=gz, mode="w") as tar:
                tar.add(source, arcname="codex-source", filter=normalize)
        packed.replace(destination)
    print(destination)
    with destination.open("rb") as source:
        print("SHA256", hashlib.file_digest(source, "sha256").hexdigest())


if __name__ == "__main__":
    prepare()
