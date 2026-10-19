"""Board firmware with a linker script generated from the memory map"""

load("@coralnpu_hw//rules:coralnpu_v2.bzl", "coralnpu_v2_binary")

def _linker_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name + ".ld")
    ctx.actions.run(
        executable = ctx.executable.generator,
        arguments = [
            "--map",
            ctx.file.memory_map.path,
            "--linker-template",
            ctx.file.template.path,
            "--out",
            output.path,
            "--stack-size",
            str(ctx.attr.stack_size_bytes),
        ],
        inputs = [ctx.file.memory_map, ctx.file.template],
        outputs = [output],
        mnemonic = "XupFirmwareLinker",
    )
    return [DefaultInfo(files = depset([output]))]

_linker_script = rule(
    implementation = _linker_impl,
    attrs = {
        "memory_map": attr.label(default = "//config:memory_map.yaml", allow_single_file = True),
        "template": attr.label(default = "@coralnpu_hw//toolchain:coralnpu_tcm.ld.tpl", allow_single_file = True),
        "stack_size_bytes": attr.int(default = 2048),
        "generator": attr.label(default = "//tools:generate_memory_map", executable = True, cfg = "exec"),
    },
)

_ISAS = {
    "scalar": "rv32im_zicsr_zifencei",
    "rvv": "rv32imf_zve32f_zicsr_zifencei_zbb_zfbfmin_zvfbfmin_zvfbfwma",
    "vme": "rv32imf_zve32f_zicsr_zifencei_zbb_zfbfmin_zvfbfmin_zvfbfwma",
}

# Keep non-HTIF runtime libraries while selecting our own ISA
_CRT_LINKOPTS = [
    "--specs=nano.specs",
    "-Wl,--start-group",
    "-lstdc++",
    "-lm",
    "-lc",
    "-lgcc",
    "-Wl,--end-group",
    "-nostartfiles",
]

def _firmware_transition_impl(settings, attr):
    flags = ["-mcmodel=medany", "-nostdlib", "-mabi=ilp32"]

    # GCC supplies RV32 runtime only with F/Zbb. Select that multilib at link
    # time while compiling scalar sources for RV32IM
    link_isa = "rv32imf_zicsr_zifencei_zbb" if attr.core == "scalar" else _ISAS[attr.core]
    return {
        "//command_line_option:copt": settings["//command_line_option:copt"] + flags + ["-march=" + _ISAS[attr.core]],
        "//command_line_option:linkopt": settings["//command_line_option:linkopt"] + flags + ["-march=" + link_isa] + _CRT_LINKOPTS,
        "//command_line_option:features": settings["//command_line_option:features"] + ["-sys_spec"],
    }

_firmware_transition = transition(
    implementation = _firmware_transition_impl,
    inputs = ["//command_line_option:copt", "//command_line_option:linkopt", "//command_line_option:features"],
    outputs = ["//command_line_option:copt", "//command_line_option:linkopt", "//command_line_option:features"],
)

def _firmware_impl(ctx):
    binary = ctx.attr.binary[0]
    files = []
    output_groups = {}
    for extension, group in [("elf", "elf_file"), ("bin", "bin_file")]:
        source = getattr(binary[OutputGroupInfo], group).to_list()[0]
        output = ctx.actions.declare_file(ctx.label.name + "." + extension)
        ctx.actions.symlink(output = output, target_file = source)
        files.append(output)
        output_groups[group] = depset([output])
    return [DefaultInfo(files = depset(files)), OutputGroupInfo(**output_groups)]

_firmware = rule(
    implementation = _firmware_impl,
    attrs = {
        "binary": attr.label(cfg = _firmware_transition),
        "core": attr.string(values = _ISAS.keys()),
        "_allowlist_function_transition": attr.label(default = "@bazel_tools//tools/allowlists/function_transition_allowlist"),
    },
)

def xup_firmware_binary(name, srcs, core = "scalar", stack_size_bytes = 2048, **kwargs):
    """Build application/dependencies for the selected core ISA

    Args:
        name: Application name. Also exports <name>.elf and <name>.bin
        srcs: Application sources. Upstream CRT supplies startup
        core: scalar, rvv, or vme. Independent of FPGA build settings
        stack_size_bytes: Stack reservation in DTCM
        **kwargs: Additional coralnpu_v2_binary attributes
    """
    tags = kwargs.pop("tags", [])
    visibility = kwargs.pop("visibility", None)
    testonly = kwargs.pop("testonly", False)
    _linker_script(name = name + "_linker", stack_size_bytes = stack_size_bytes)
    coralnpu_v2_binary(
        name = name + "_binary",
        srcs = srcs,
        linker_script = ":" + name + "_linker",
        # Upstream's default //toolchain/crt label resolves in the caller repo
        crt = "@coralnpu_hw//toolchain/crt:crt",
        enable_vmem = False,
        tags = tags + ["manual"],
        visibility = ["//visibility:private"],
        testonly = testonly,
        **kwargs
    )
    _firmware(
        name = name,
        binary = ":" + name + "_binary",
        core = core,
        tags = tags,
        visibility = visibility,
        testonly = testonly,
    )
    for extension in ["elf", "bin"]:
        native.filegroup(
            name = name + "." + extension,
            srcs = [":" + name],
            output_group = extension + "_file",
            tags = tags,
            visibility = visibility,
            testonly = testonly,
        )
