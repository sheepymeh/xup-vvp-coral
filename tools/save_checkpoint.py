"""Retain one validated incremental implementation reference per core"""

import argparse
import os
import shutil
import tempfile
from pathlib import Path


def read_settings(path: Path) -> dict[str, str]:
    return dict(
        line.split("=", 1) for line in path.read_text().splitlines() if "=" in line
    )


def save_checkpoint(
    checkpoint: Path, configuration: Path, gates: Path, cache_root: Path
) -> None:
    if read_settings(gates).get("result") != "PASS":
        raise ValueError("Checkpoint requires passing build gates")
    core = read_settings(configuration)["core"]
    if core not in ("scalar", "rvv", "vme"):
        raise ValueError(f"Unknown core: {core}")

    directory = cache_root / core
    directory.mkdir(parents=True, exist_ok=True)
    # Stage copies before replacing the previous successful reference
    with tempfile.TemporaryDirectory(prefix=".save-", dir=directory) as temporary:
        staging = Path(temporary)
        shutil.copyfile(checkpoint, staging / "latest.dcp")
        shutil.copyfile(configuration, staging / "latest.txt")
        os.replace(staging / "latest.txt", directory / "latest.txt")
        os.replace(staging / "latest.dcp", directory / "latest.dcp")
    print(f"Saved {core} incremental reference: {directory / 'latest.dcp'}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    workspace = Path(os.environ.get("BUILD_WORKSPACE_DIRECTORY", Path.cwd()))
    caller = Path(os.environ.get("BUILD_WORKING_DIRECTORY", Path.cwd()))
    parser.add_argument(
        "artifacts",
        nargs="?",
        type=Path,
        default=workspace / "bazel-bin/build_bitstream",
    )
    parser.add_argument(
        "--cache-root", type=Path, default=workspace / "build/incremental"
    )
    arguments = parser.parse_args()
    artifacts = caller / arguments.artifacts.expanduser()
    save_checkpoint(
        artifacts / "xup_coral_routed.dcp",
        artifacts / "reports/build_configuration.txt",
        artifacts / "reports/build_gates.txt",
        caller / arguments.cache_root.expanduser(),
    )


if __name__ == "__main__":
    main()
