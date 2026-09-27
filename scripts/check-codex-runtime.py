#!/usr/bin/env python3
"""Validate/relocate the official bundle, then exercise code-mode discovery offline."""
import argparse
import http.server
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import threading


REQUIRED = (
    "bin/codex", "bin/codex-code-mode-host", "codex-path/rg",
    "codex-resources/bwrap", "codex-resources/zsh/bin/zsh",
    "codex-resources/voice/bin/codex-voice-host",
)


def validate_layout(root, version):
    metadata = json.loads((root / "codex-package.json").read_text())
    for key, value in dict(layoutVersion=1, version=version,
                           target="x86_64-unknown-linux-musl", variant="codex",
                           entrypoint="bin/codex", resourcesDir="codex-resources",
                           pathDir="codex-path").items():
        if metadata.get(key) != value:
            raise RuntimeError(f"Unsupported Codex package metadata: {key}={metadata.get(key)!r}")
    for name in REQUIRED:
        file = root / name
        if not file.is_file() or not os.access(file, os.X_OK):
            raise RuntimeError(f"Missing executable in official Codex runtime: {name}")
    for name in ("codex-resources/voice/manifest.json", "codex-resources/voice/runtime.json"):
        if not (root / name).is_file():
            raise RuntimeError(f"Missing official Codex resource: {name}")
    voice = root / "codex-resources/voice"
    manifest = json.loads((voice / "manifest.json").read_text())
    if manifest.get("appVersion") != version:
        raise RuntimeError("Voice resources belong to another Codex release")
    runtime = json.loads((voice / "runtime.json").read_text())
    for name in [entry["path"] for entry in runtime["libraries"]] + runtime["plugins"]:
        file = (voice / name).resolve()
        if not file.is_relative_to(voice) or not file.is_file():
            raise RuntimeError(f"Missing or invalid voice resource: {name}")


def run(*args, **kwargs):
    result = subprocess.run(args, capture_output=True, text=True, timeout=45, **kwargs)
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}): {args!r}\n"
                           f"{result.stdout}\n{result.stderr}")
    return result.stdout


def elf_interpreter(file):
    with file.open("rb") as stream:
        header = stream.read(64)
        if header[:4] != b"\x7fELF":
            return None
        if header[4:6] != b"\x02\x01" or struct.unpack_from("<H", header, 18)[0] != 62:
            raise RuntimeError(f"Unexpected ELF architecture: {file}")
        offset = struct.unpack_from("<Q", header, 32)[0]
        size, count = struct.unpack_from("<HH", header, 54)
        for index in range(count):
            stream.seek(offset + index * size)
            segment = stream.read(size)
            if struct.unpack_from("<I", segment)[0] == 3:  # PT_INTERP
                position = struct.unpack_from("<Q", segment, 8)[0]
                length = struct.unpack_from("<Q", segment, 32)[0]
                stream.seek(position)
                return stream.read(length).rstrip(b"\0").decode()
    return ""  # ELF without an interpreter (static PIE or a shared library)


def relocate(root, patchelf, libc, tinfo):
    """Keep upstream binaries/resources; relocate only dynamically linked ELF files."""
    loader = str(Path(libc) / "lib/ld-linux-x86-64.so.2")
    libraries = f"{libc}/lib:{tinfo}/lib"
    dynamic = []
    for file in sorted(root.rglob("*")):
        if not file.is_file():
            continue
        interpreter = elf_interpreter(file)
        if interpreter is None:
            continue
        needed = run(patchelf, "--print-needed", str(file)).splitlines()
        if not interpreter and not needed:
            continue  # Do not rewrite static musl binaries.
        file.chmod(file.stat().st_mode | 0o200)
        if interpreter:
            run(patchelf, "--set-interpreter", loader, str(file))
        # Preserve upstream $ORIGIN paths, including the bundled voice libraries.
        run(patchelf, "--add-rpath", libraries, str(file))
        dynamic.append(file)
    for file in dynamic:
        # Resolve every dependency, including dlopen'ed voice plugins. This is
        # run inside the Guix build container as well as by local validation.
        run(loader, "--list", str(file), env={"LC_ALL": "C"})
    print(f"Relocated and resolved {len(dynamic)} dynamic ELF files; static binaries unchanged.")


def check_discovery(program, env, work):
    """Have the real CLI execute code through its discovered host; no account/API."""
    requests = []

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_POST(self):
            body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            requests.append(body)
            if self.path != "/v1/responses" or len(requests) > 2:
                self.send_error(400)
                return
            if len(requests) == 1:
                item = dict(type="custom_tool_call", call_id="package-smoke", name="exec",
                            input='text("GUIX_CODE_HOST_OK")')
            else:
                item = dict(type="message", role="assistant", id="done",
                            content=[dict(type="output_text", text="Done")])
            response_id = f"package-{len(requests)}"
            events = [
                dict(type="response.created", response=dict(id=response_id)),
                dict(type="response.output_item.done", item=item),
                dict(type="response.completed", response=dict(
                    id=response_id, usage=dict(input_tokens=1, output_tokens=1, total_tokens=2))),
            ]
            data = "".join(f"event: {event['type']}\ndata: {json.dumps(event)}\n\n"
                           for event in events).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

    with http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            run(str(program), "--no-daemon", "exec", "--skip-git-repo-check",
                "--ephemeral", "--json", "-m", "gpt-5.4",
                "-c", 'model_provider="package_test"',
                "-c", 'model_providers.package_test.name="Package test"',
                "-c", f'model_providers.package_test.base_url="http://127.0.0.1:{server.server_port}/v1"',
                "-c", 'model_providers.package_test.wire_api="responses"',
                "-c", "model_providers.package_test.requires_openai_auth=false",
                "-c", "features.code_mode=true", "-c", "features.code_mode_host=true",
                "run package test", env=env, cwd=work, stdin=subprocess.DEVNULL)
        finally:
            server.shutdown()
            thread.join()
    outputs = [item for request in requests for item in request.get("input", [])
               if item.get("type") == "custom_tool_call_output"
               and item.get("call_id") == "package-smoke"]
    if len(requests) != 2 or len(outputs) != 1 or "GUIX_CODE_HOST_OK" not in json.dumps(outputs[0]):
        raise RuntimeError(f"Codex failed to discover/execute its code-mode host: {outputs!r}")
    print("CLI discovered its adjacent host and evaluated JavaScript successfully (local mock API).")


def check(root, version):
    validate_layout(root, version)
    for name in REQUIRED:
        interpreter = elf_interpreter(root / name)
        if interpreter and not interpreter.startswith(("/gnu/store/", "/nix/store/")):
            raise RuntimeError(f"Executable still requires an FHS loader: {name}: {interpreter}")
    with tempfile.TemporaryDirectory(prefix="codex-runtime-check-") as work:
        home = Path(work)
        (home / "codex-home").mkdir()
        # Deliberately exclude bin/codex-code-mode-host from PATH. Drop inherited
        # credentials, proxies, install-method overrides and user configuration.
        env = dict(HOME=work, CODEX_HOME=str(home / "codex-home"), PATH="",
                   XDG_CONFIG_HOME=str(home / "config"), XDG_CACHE_HOME=str(home / "cache"),
                   LC_ALL="C", RUST_LOG="error")
        program = root / "bin/codex"
        result = run(str(program), "--version", env=env, cwd=work)
        if result.strip() != f"codex-cli {version}":
            raise RuntimeError(f"Binary/manifest version mismatch: {result!r}")
        for arguments in (("--help",), ("exec", "--help"), ("--no-daemon", "--version")):
            run(str(program), *arguments, env=env, cwd=work)
        for name, arg in (("bin/codex-code-mode-host", "--help"),
                          ("codex-path/rg", "--version"),
                          ("codex-resources/bwrap", "--version"),
                          ("codex-resources/zsh/bin/zsh", "--version"),
                          ("codex-resources/voice/bin/codex-voice-host", "--build-commit")):
            run(str(root / name), arg, env=env, cwd=work)
        check_discovery(program, env, work)
    print("Complete Codex runtime validation passed.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("version")
    parser.add_argument("--relocate", nargs=3, metavar=("PATCHELF", "GLIBC", "TINFO"))
    args = parser.parse_args()
    root = args.root.resolve()
    validate_layout(root, args.version)
    if args.relocate:
        relocate(root, *args.relocate)
    else:
        check(root, args.version)
