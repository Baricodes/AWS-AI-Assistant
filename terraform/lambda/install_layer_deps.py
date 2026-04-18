#!/usr/bin/env python3
"""Install third-party packages into the Lambda layer tree; invoked by Terraform external data source."""
import json
import os
import shutil
import subprocess
import sys


def main() -> None:
    query = json.load(sys.stdin)
    want_hash = query["hash"]
    module_root = os.environ["MODULE_ROOT"]
    req_path = os.path.join(module_root, "lambda", "layer_requirements.txt")
    layer_root = os.path.join(module_root, "lambda", ".layer_content")
    stamp_path = os.path.join(module_root, "lambda", ".layer_deps_stamp")
    site_packages = os.path.join(
        layer_root, "python", "lib", "python3.11", "site-packages"
    )

    if os.path.isfile(stamp_path):
        with open(stamp_path, encoding="utf-8") as f:
            if f.read().strip() == want_hash:
                print(json.dumps({"id": want_hash}))
                return

    shutil.rmtree(layer_root, ignore_errors=True)
    os.makedirs(site_packages, exist_ok=True)

    cmd = [
        sys.executable,
        "-m",
        "pip",
        "install",
        "-r",
        req_path,
        "-t",
        site_packages,
        "--platform",
        "manylinux2014_x86_64",
        "--implementation",
        "cp",
        "--python-version",
        "311",
        "--only-binary=:all:",
        "-q",
    ]
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError:
        subprocess.run(
            [
                sys.executable,
                "-m",
                "pip",
                "install",
                "-r",
                req_path,
                "-t",
                site_packages,
                "-q",
            ],
            check=True,
        )

    with open(stamp_path, "w", encoding="utf-8") as f:
        f.write(want_hash)

    print(json.dumps({"id": want_hash}))


if __name__ == "__main__":
    main()
