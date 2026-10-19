"""Build XUP configurations with FuseSoC/Edalize Flow API"""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo", "bool_flag", "string_flag")
load("@nonhermetic//:env.bzl", "BIN_PATHS", "ENV")

_SYSTEM = "bittware_xup_vvp_coral_0.1"

def _hooks(ctx, names, script_file):
    # Vivado run hooks require script files, not inline Tcl
    files = []
    for name in names:
        hook = ctx.actions.declare_file(ctx.label.name + "/hooks/" + name + ".tcl")
        ctx.actions.write(hook, """source [file join [file dirname [info script]] .. project_context.tcl]
source [file join $root_dir tcl %s]
xup_implementation::%s
""" % (script_file, name))
        files.append(hook)
    return files

def _memory_map_impl(ctx):
    tcl = ctx.actions.declare_file("generated/memory_map.tcl")
    svh = ctx.actions.declare_file("generated/memory_map.svh")
    ctx.actions.run(
        executable = ctx.executable.generator,
        arguments = ["--map", ctx.file.src.path, "--out", tcl.dirname],
        inputs = [ctx.file.src],
        outputs = [tcl, svh],
        mnemonic = "XupMemoryMap",
    )
    return [
        DefaultInfo(files = depset([tcl, svh])),
        OutputGroupInfo(tcl = depset([tcl]), svh = depset([svh])),
    ]

_memory_map = rule(
    implementation = _memory_map_impl,
    attrs = {
        "src": attr.label(allow_single_file = True, mandatory = True),
        "generator": attr.label(executable = True, cfg = "exec", default = "//tools:generate_memory_map"),
    },
)

def _project_impl(ctx):
    # Upstream's Bazel helper assumes the old Tool API. Reuse its CLI
    project = ctx.actions.declare_directory(ctx.label.name + "/" + _SYSTEM)
    elaborate = ctx.actions.declare_file(ctx.label.name + "/elaborate.tcl")
    ctx.actions.write(elaborate, """source %s.tcl
if {[catch {synth_design -rtl -name rtl_1} message]} {
    puts stderr $message; exit 1
}
close_project
""" % _SYSTEM)
    env = dict(ENV)
    env["PATH"] = BIN_PATHS["vivado"] + ":/bin:/usr/bin:/usr/local/bin"
    ctx.actions.run_shell(
        command = """set -eu
project="$PWD/$1"
fusesoc="$PWD/$2"
cores="$PWD/$3"
phase="$4"
elaborate="$PWD/$5"
export HOME="$project/.vivado-home"
mkdir -p "$HOME"
"$fusesoc" --cores-root="$cores" run --target=synth --setup --build-root="$(dirname "$project")" bittware:xup_vvp:coral:0.1
cd "$project/synth"
if [ "$phase" = synth ]; then
    exec make synth
else
    exec vivado -mode batch -notrace -nojournal -source "$elaborate"
fi
""",
        arguments = [project.path, ctx.executable.fusesoc.path, ctx.files.sources[0].path, ctx.attr.phase, elaborate.path],
        inputs = ctx.files.sources + [elaborate],
        tools = [ctx.attr.fusesoc[DefaultInfo].files_to_run],
        outputs = [project],
        env = env,
        mnemonic = "XupVivadoProject",
        execution_requirements = {"no-remote": "1"},
    )
    return [DefaultInfo(files = depset([project]))]

_project = rule(
    implementation = _project_impl,
    attrs = {
        "sources": attr.label(mandatory = True),
        "phase": attr.string(values = ["elab", "synth"], mandatory = True),
        "fusesoc": attr.label(default = "@lowrisc_opentitan_gh//util:fusesoc_build", executable = True, cfg = "exec"),
    },
)

def _artifacts_impl(ctx):
    project = ctx.file.project
    reports = ctx.actions.declare_directory(ctx.label.name + "/reports")
    args = ctx.actions.args()
    work_dir = project.path + "/synth"
    args.add(work_dir + "/reports")
    args.add(reports.path)
    outputs = [reports]
    output_groups = {"project": depset([project]), "reports": depset([reports])}
    if ctx.attr.phase == "bitstream":
        for group, filename in [("bitstream", "xup_coral.bit"), ("probes", "xup_coral.ltx"), ("checkpoint", "xup_coral_routed.dcp")]:
            artifact = ctx.actions.declare_file(ctx.label.name + "/" + filename)
            args.add(work_dir + "/release/" + filename)
            args.add(artifact.path)
            outputs.append(artifact)
            output_groups[group] = depset([artifact])
    elif ctx.attr.phase == "synth":
        checkpoint = ctx.actions.declare_file(ctx.label.name + "/xup_coral_synth.dcp")
        args.add(work_dir + "/" + _SYSTEM + ".runs/synth_1/xup_core_top.dcp")
        args.add(checkpoint.path)
        outputs.append(checkpoint)
        output_groups["checkpoint"] = depset([checkpoint])
    ctx.actions.run_shell(
        command = """set -eu
mkdir -p "$2"
cp -RL "$1/." "$2/"
shift 2
while [ "$#" -gt 0 ]; do
    cp "$1" "$2"
    shift 2
done
""",
        arguments = [args],
        inputs = [project],
        outputs = outputs,
        mnemonic = "XupFpgaArtifacts",
    )
    return [DefaultInfo(files = depset(outputs)), OutputGroupInfo(**output_groups)]

_artifacts = rule(
    implementation = _artifacts_impl,
    attrs = {
        "project": attr.label(allow_single_file = True, mandatory = True),
        "phase": attr.string(values = ["elab", "synth", "bitstream"]),
    },
)

def _implement_impl(ctx):
    project = ctx.actions.declare_directory(ctx.label.name + "/" + _SYSTEM)
    hooks = _hooks(
        ctx,
        ["finalize_synth", "apply_incremental", "prepare_placement", "optimize_pcie_reset", "check_route", "check_bitstream", "capture_release"],
        "implementation/macros.tcl",
    )
    scripts = ctx.files.scripts + hooks
    args = ctx.actions.args()
    args.add(ctx.file.synthesis.path)
    args.add(project.path)
    args.add(_SYSTEM)
    references = ctx.files.reference if ctx.attr.incremental[BuildSettingInfo].value else []
    args.add(len(references))
    args.add_all(references)
    args.add_all(scripts)
    env = dict(ENV)
    env["PATH"] = BIN_PATHS["vivado"] + ":/bin:/usr/bin:/usr/local/bin"
    ctx.actions.run_shell(
        command = """set -eu
source_project="$1"
project="$PWD/$2"
system="$3"
reference_count="$4"
shift 4
mkdir -p "$project"
# Vivado uses source timestamps to check whether synthesis is up to date
cp -a "$source_project/." "$project/"
chmod -R u+w "$project"
mkdir -p "$project/synth/incremental"
while [ "$reference_count" -gt 0 ]; do
    cp "$1" "$project/synth/incremental/"
    shift
    reference_count=$((reference_count - 1))
done
board_sources="$project/synth/src/$system/sources"
mkdir -p "$board_sources/tcl/implementation"
for script in "$@"; do
    cp "$script" "$board_sources/tcl/implementation/"
done
export HOME="$project/.vivado-home"
mkdir -p "$HOME"
cd "$project/synth"
exec vivado -mode batch -notrace -nojournal -source "$board_sources/tcl/implementation/run_implementation.tcl" -tclargs "$project/synth/$system.xpr"
""",
        arguments = [args],
        inputs = [ctx.file.synthesis] + scripts + references,
        outputs = [project],
        env = env,
        mnemonic = "XupVivadoImplementation",
        execution_requirements = {"no-remote": "1"},
    )
    return [DefaultInfo(files = depset([project]))]

_implement = rule(
    implementation = _implement_impl,
    attrs = {
        "synthesis": attr.label(allow_single_file = True, mandatory = True),
        "scripts": attr.label_list(allow_files = True),
        "reference": attr.label(allow_files = True),
        "incremental": attr.label(mandatory = True),
    },
)

def _export_impl(ctx):
    # One directory output prevents stale descriptors after file renames
    bundle = ctx.actions.declare_directory("coral_fusesoc")
    args = ctx.actions.args()
    args.add("--output", bundle.path + "/sources")
    args.add("--core-output", bundle.path + "/xup_vvp.core")
    args.add("--production-core-output", bundle.path + "/production_axi.core")
    args.add("--core", ctx.attr.core[BuildSettingInfo].value)
    args.add("--pcie", ctx.attr.pcie[BuildSettingInfo].value)
    args.add("--profile", ctx.attr.profile[BuildSettingInfo].value)
    args.add("--ext-mem", ctx.attr.ext_mem[BuildSettingInfo].value)
    args.add("--package", ctx.label.package)
    args.add("--template", ctx.file.template.path)
    args.add("--board", ctx.file.board.path)
    args.add("--map-tcl", ctx.file.map_tcl.path)
    args.add("--map-header", ctx.file.map_header.path)
    args.add_all(ctx.files.board_sources, before_each = "--board-source")
    args.add("--upstream-root", ctx.files.upstream_sources[0].owner.workspace_root)
    args.add_all(ctx.files.upstream_sources, before_each = "--upstream-source")
    args.add("--rtl", [file for file in ctx.files.production_axi if file.extension == "sv"][0].path)
    args.add("--rtl-resources", [file for file in ctx.files.production_axi if file.extension == "zip"][0].path)
    args.add("--core-binding", ctx.file.core_binding.path)
    ctx.actions.run(
        executable = ctx.executable.exporter,
        arguments = [args],
        inputs = ctx.files.board_sources + ctx.files.upstream_sources + ctx.files.production_axi + [ctx.file.board, ctx.file.template, ctx.file.core_binding, ctx.file.map_tcl, ctx.file.map_header],
        outputs = [bundle],
        mnemonic = "XupFuseSoCSources",
    )
    return [DefaultInfo(files = depset([bundle]))]

_export = rule(
    implementation = _export_impl,
    attrs = {
        "core": attr.label(mandatory = True),
        "pcie": attr.label(mandatory = True),
        "profile": attr.label(mandatory = True),
        "ext_mem": attr.label(mandatory = True),
        "board_sources": attr.label_list(allow_files = True),
        "board": attr.label(allow_single_file = True, mandatory = True),
        "upstream_sources": attr.label_list(allow_files = True),
        "template": attr.label(allow_single_file = True),
        "map_tcl": attr.label(allow_single_file = True),
        "map_header": attr.label(allow_single_file = True),
        "production_axi": attr.label(mandatory = True),
        "core_binding": attr.label(allow_single_file = True),
        "exporter": attr.label(executable = True, cfg = "exec"),
    },
)

def xup_fpga_targets(name):
    """Declare board feature flags, source export, FPGA build stages

    Args:
        name: FuseSoC source export target name
    """
    _memory_map(name = "memory_map", src = "//config:memory_map.yaml")
    for kind in ["tcl", "svh"]:
        native.filegroup(name = "memory_map_" + kind, srcs = [":memory_map"], output_group = kind)
    string_flag(name = "core", build_setting_default = "rvv", values = ["scalar", "rvv", "vme"])
    string_flag(name = "pcie", build_setting_default = "gen2x4", values = ["none", "gen2x4", "gen3x16"])
    string_flag(name = "profile", build_setting_default = "release", values = ["debug", "release"])
    string_flag(name = "ext_mem", build_setting_default = "bram", values = ["bram", "uram", "dram"])
    bool_flag(name = "incremental", build_setting_default = True)
    for kind in ["scalar", "rvv", "vme"]:
        native.config_setting(name = "core_" + kind, flag_values = {":core": kind})
        native.filegroup(
            name = kind + "_reference",
            srcs = native.glob([
                "build/incremental/" + kind + "/latest.dcp",
                "build/incremental/" + kind + "/latest.txt",
            ], allow_empty = True),
        )

    native.filegroup(
        name = "production_axi",
        srcs = select({
            ":core_rvv": ["@coralnpu_hw//hdl/chisel/src/coralnpu/prod:RvvCoreMiniAxi.sv", "@coralnpu_hw//hdl/chisel/src/coralnpu/prod:RvvCoreMiniAxi.zip"],
            ":core_vme": ["@coralnpu_hw//hdl/chisel/src/coralnpu/prod:VmeCoreMiniAxi.sv", "@coralnpu_hw//hdl/chisel/src/coralnpu/prod:VmeCoreMiniAxi.zip"],
            "//conditions:default": ["@coralnpu_hw//hdl/chisel/src/coralnpu/prod:CoreMiniAxi.sv", "@coralnpu_hw//hdl/chisel/src/coralnpu/prod:CoreMiniAxi.zip"],
        }),
    )

    # Exclude hardware-control scripts from the synthesis source bundle
    common_sources = native.glob(
        [
            "rtl/*.sv",
            "rtl/*.v",
            "tcl/*.tcl",
            "tcl/setup/*.tcl",
            "tcl/synthesis/*.tcl",
            "constraints/fabric_clock.xdc",
        ],
        exclude = [
            "rtl/xup_ddr4_powerup_reset.sv",
            "rtl/ddr4_ready_sync.sv",
            "tcl/setup/pcie_host.tcl",
        ],
    ) + [
        "tcl/setup/extmem_backends/onchip.tcl",
    ]
    dimm_sources = [
        "//config:dimm0_mig.tcl",
        "//config:dimm_parts/BLS4G4D240FSB.csv",
        "constraints/dimm0.xdc",
        "constraints/dimm0_startup_timing.xdc",
        "rtl/xup_ddr4_powerup_reset.sv",
        "rtl/ddr4_ready_sync.sv",
        "tcl/setup/extmem_backends/dram.tcl",
    ]
    pcie_sources = [
        "//config:pcie_xdma.tcl",
        "constraints/pcie.xdc",
        "tcl/setup/pcie_host.tcl",
    ]
    _export(
        name = name,
        core = ":core",
        pcie = ":pcie",
        profile = ":profile",
        ext_mem = ":ext_mem",
        board = "//config:board.yaml",
        board_sources = common_sources + dimm_sources + pcie_sources,
        upstream_sources = [
            "@coralnpu_hw//fpga:check_pin_assignments.tcl",
            "@coralnpu_hw//fpga/rtl:clkgen_wrapper.sv",
            "@coralnpu_hw//fpga/rtl:clkgen_xilultrascaleplus.sv",
        ],
        template = "//integration:xup_vvp.core",
        map_tcl = ":memory_map_tcl",
        map_header = ":memory_map_svh",
        production_axi = ":production_axi",
        core_binding = "rtl/core_mini_axi.v.tpl",
        exporter = "//tools:export_fusesoc",
    )
    for phase in ["elab", "synth"]:
        _project(
            name = "project_" + phase,
            sources = ":" + name,
            phase = phase,
            tags = ["manual"],
        )
    _implement(
        name = "project_bitstream",
        synthesis = ":project_synth",
        incremental = ":incremental",
        reference = select({
            ":core_scalar": ":scalar_reference",
            ":core_rvv": ":rvv_reference",
            ":core_vme": ":vme_reference",
        }),
        scripts = [
            "tcl/implementation/macros.tcl",
            "tcl/implementation/run_implementation.tcl",
        ],
        tags = ["manual"],
    )
    for phase in ["elab", "synth", "bitstream"]:
        _artifacts(
            name = "build_" + phase,
            project = ":project_" + phase,
            phase = phase,
            tags = ["manual"],
        )
