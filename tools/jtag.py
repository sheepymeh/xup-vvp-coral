"""Run JTAG operations with declared maps, Tcl scripts, and hardware selectors"""

import argparse
import os
import subprocess
import tempfile
from collections.abc import Sequence
from pathlib import Path
from typing import cast

import yaml
from python.runfiles import runfiles

from tools.elf_image import read_image, write_load_plan
from tools.generate_memory_map import load_map


def runfile(name: str) -> Path:
    return Path(runfiles.Create().Rlocation("xup_vvp/" + name))


def log_path(action: str) -> Path:
    return (
        Path(os.environ["BUILD_WORKSPACE_DIRECTORY"])
        / "build/hardware"
        / f"{action}.log"
    )


def resolve_input_path(value: Path) -> Path:
    # bazel run starts in runfiles. Resolve paths from the caller's cwd
    return (Path(os.environ["BUILD_WORKING_DIRECTORY"]) / value.expanduser()).resolve()


def hardware_config() -> dict[str, str]:
    return cast(dict[str, str], yaml.safe_load(runfile("config/hardware.yaml").read_text()))


def run_vivado(
    script: Path,
    tcl_args: Sequence[str | Path],
    log_file: Path,
    *,
    timeout: float | None = None,
) -> None:
    log_file.parent.mkdir(parents=True, exist_ok=True)
    print(f"JTAG {script.stem} (log: {log_file})", flush=True)
    command = [
        "vivado",
        "-mode",
        "batch",
        "-nojournal",
        "-nolog",
        "-source",
        str(script),
        "-tclargs",
        str(runfile("generated/memory_map.tcl")),
        *map(str, tcl_args),
    ]

    try:
        with log_file.open("w") as output:
            subprocess.run(
                command,
                cwd=log_file.parent,
                check=True,
                timeout=timeout,
                stdout=output,
                stderr=subprocess.STDOUT,
            )
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        raise RuntimeError(f"JTAG operation failed. See {log_file}") from error

    for line in log_file.read_text().splitlines():
        if line.startswith("XUP_STATUS "):
            print(line.removeprefix("XUP_STATUS "))


def program(bit: Path) -> None:
    if bit.suffix != ".bit":
        raise ValueError(f"Expected .bit file: {bit}")
    if not bit.is_file():
        raise FileNotFoundError(bit)

    probes = bit.with_suffix(".ltx")
    config = hardware_config()
    bdf = config["pcie_bdf"]
    remove_path = Path("/sys/bus/pci/devices") / bdf / "remove"
    rescan_path = Path("/sys/class/pci_bus") / bdf.rsplit(":", 1)[0] / "rescan"

    if remove_path.exists():
        print(f"Removing PCIe endpoint {bdf}", flush=True)
        remove_path.write_text("1\n")
    try:
        tcl_args: list[str | Path] = [
            config["server"],
            config["target"],
            config["device"],
            config["axi"],
            bit,
        ]
        if probes.is_file():
            tcl_args.append(probes)
        run_vivado(
            runfile("tcl/post_build/program_fpga.tcl"),
            tcl_args,
            log_path("program"),
            timeout=180,
        )
    finally:
        print(f"Rescanning PCIe bus {rescan_path.parent.name}", flush=True)
        rescan_path.write_text("1\n")
    print(f"Programmed {bit}. Core remains stopped")


def control(action: str, elf: Path | None = None) -> None:
    # Prepare/validate PT_LOADs before opening Vivado hardware session
    image = None
    if action in {"load", "run"}:
        assert elf is not None
        memory_map = load_map(runfile("config/memory_map.yaml"))
        image = read_image(elf.read_bytes(), memory_map)

    config = hardware_config()
    tcl_args: list[str | Path] = [
        config[name] for name in ("server", "target", "device", "axi")
    ]
    tcl_args.append(action)
    with tempfile.TemporaryDirectory(prefix="xup-load-") as directory:
        if image is not None:
            tcl_args.append(write_load_plan(image, directory))
        run_vivado(runfile("tcl/post_build/control_core.tcl"), tcl_args, log_path(action))
    match action:
        case "load" | "run":
            state = "execution started" if action == "run" else "core remains stopped"
            print(f"Loaded {elf}: {state}")
        case "stop":
            print("Core stopped: reset asserted, clock gated")


def make_parser() -> argparse.ArgumentParser:
    cli = argparse.ArgumentParser(description=__doc__)
    commands = cli.add_subparsers(dest="command", required=True)
    program_parser = commands.add_parser(
        "program", help="Program BIT file. Use its sibling LTX when present"
    )
    program_parser.add_argument("bitstream", type=Path)
    for command, help_text in (
        ("load", "Load/verify an RV32 ELF"),
        ("run", "Load/verify/start an RV32 ELF"),
    ):
        parser = commands.add_parser(command, help=help_text)
        parser.add_argument("elf", type=Path)
    commands.add_parser("stop")
    commands.add_parser("status")
    return cli


def main() -> None:
    cli = make_parser()
    args = cli.parse_args()

    try:
        match args.command:
            case "program":
                program(resolve_input_path(args.bitstream))
            case "load" | "run":
                control(args.command, resolve_input_path(args.elf))
            case "stop" | "status":
                control(args.command)
    except (OSError, ValueError, RuntimeError) as error:
        cli.exit(1, f"{args.command}: {error}\n")


if __name__ == "__main__":
    main()
