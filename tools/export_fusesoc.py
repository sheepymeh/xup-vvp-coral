"""Package board sources/production RTL into FuseSoC cores"""

import argparse
import shutil
import zipfile
from pathlib import Path
from typing import TypedDict, cast

import yaml


class BoardConfig(TypedDict):
    fpga_part: str
    reference_hz: int
    fabric_hz: int
    scalar_fabric_hz: int
    vme_fabric_hz: int
    build_jobs: int


def copy_core_rtl(source: str | Path, directory: Path, archive: str | Path) -> None:
    """Keep upstream compilation unit/referenced include resources"""
    directory.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, directory / Path(source).name)
    with zipfile.ZipFile(archive) as bundle:
        for name in bundle.namelist():
            if name.endswith((".svh", ".vh")):
                bundle.extract(name, directory)


def export(arguments: argparse.Namespace) -> None:
    destination = Path(arguments.output)
    destination.mkdir(parents=True, exist_ok=True)

    for source in arguments.board_source:
        path = Path(source)
        relative = path.relative_to(arguments.package)
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)

    for source in arguments.upstream_source:
        path = Path(source)
        relative = path.relative_to(Path(arguments.upstream_root) / "fpga")
        target = destination / "upstream/fpga" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)

    # Generated inputs live under bazel-out, outside the source package
    generated = destination / "generated"
    generated.mkdir(parents=True, exist_ok=True)
    shutil.copy2(arguments.map_tcl, generated / "memory_map.tcl")
    shutil.copy2(arguments.map_header, generated / "memory_map.svh")
    # Its FPU macros share a compilation unit with their consumers
    copy_core_rtl(
        arguments.rtl, destination / "generated/core/rtl", arguments.rtl_resources
    )

    core_module = {
        "scalar": "CoreMiniAxi",
        "rvv": "RvvCoreMiniAxi",
        "vme": "VmeCoreMiniAxi",
    }[arguments.core]
    (generated / "core_mini_axi.v").write_text(
        Path(arguments.core_binding).read_text().replace("__CORE_MODULE__", core_module)
    )

    (destination / "config/build_settings.tcl").write_text(
        f"set XUP_CORE_TYPE {arguments.core}\n"
        f"set XUP_CORE_MODULE {core_module}\n"
        f"set XUP_PCIE {arguments.pcie}\n"
        f"set XUP_BUILD_PROFILE {arguments.profile}\n"
        f"set XUP_EXT_MEM {arguments.ext_mem}\n"
    )

    board = cast(BoardConfig, yaml.safe_load(Path(arguments.board).read_text()))
    (destination / "config/board.tcl").write_text(
        "".join(f"set XUP_{key.upper()} {{{value}}}\n" for key, value in board.items())
    )
    board_core = yaml.safe_load(Path(arguments.template).read_text().split("\n", 1)[1])
    synth_target = board_core["targets"]["synth"]
    synth_target["flags"] = {
        "pcie": arguments.pcie != "none",
        "dimm": arguments.ext_mem == "dram",
    }
    synth_target["flow_options"].update(
        part=board["fpga_part"], jobs=board["build_jobs"]
    )

    frequency = {
        "scalar": board["scalar_fabric_hz"],
        "rvv": board["fabric_hz"],
        "vme": board["vme_fabric_hz"],
    }[arguments.core]
    board_core["parameters"]["ClockFrequencyMhz"]["default"] = frequency // 1000000
    board_core["parameters"]["PcieLanes"]["default"] = (
        16 if arguments.pcie == "gen3x16" else 4
    )
    Path(arguments.core_output).write_text(
        "CAPI=2:\n" + yaml.safe_dump(board_core, sort_keys=False)
    )

    files: list[dict[str, dict[str, str | bool]]] = [
        {"sources/generated/core_mini_axi.v": {"file_type": "verilogSource"}}
    ]
    for path in sorted((generated / "core/rtl").rglob("*")):
        if path.is_file():
            properties: dict[str, str | bool] = {"file_type": "systemVerilogSource"}
            if path.suffix in (".vh", ".svh"):
                properties["is_include_file"] = True
            files.append(
                {"sources/" + path.relative_to(destination).as_posix(): properties}
            )

    definitions = ["FPGA_XILINX", "SYNTHESIS", "USE_GENERIC"]
    if arguments.core != "scalar":
        definitions += ["VLEN_128", "ZVE32F_ON", "TB_SUPPORT"]
    if arguments.core == "vme":
        definitions += ["ZVT_ON", "ZVTBF16FMM_ON"]

    production_core = {
        "name": "bittware:xup_vvp:production_axi:0.1",
        "description": f"Upstream production {core_module} with board AXI port binding",
        "filesets": {"rtl": {"files": files}},
        "parameters": {
            name: {"datatype": "bool", "paramtype": "vlogdefine", "default": True}
            for name in definitions
        },
        "targets": {"default": {"filesets": ["rtl"], "parameters": definitions}},
    }
    Path(arguments.production_core_output).write_text(
        "CAPI=2:\n" + yaml.safe_dump(production_core, sort_keys=False)
    )


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in (
        "output",
        "core-output",
        "production-core-output",
        "core-binding",
        "board",
        "package",
        "template",
        "map-tcl",
        "map-header",
        "rtl",
        "rtl-resources",
    ):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--core", choices=("scalar", "rvv", "vme"), required=True)
    parser.add_argument("--pcie", choices=("none", "gen2x4", "gen3x16"), required=True)
    parser.add_argument("--profile", choices=("debug", "release"), default="release")
    parser.add_argument("--ext-mem", choices=("bram", "uram", "dram"), required=True)
    parser.add_argument("--board-source", action="append", default=[])
    parser.add_argument("--upstream-root", required=True)
    parser.add_argument("--upstream-source", action="append", default=[])
    export(parser.parse_args(argv))


if __name__ == "__main__":
    main()
