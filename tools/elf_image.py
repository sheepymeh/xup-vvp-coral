"""Validate RV32 ELF images against XUP loadable memory"""

import io
from pathlib import Path
from typing import NotRequired, TypedDict

from elftools.common.exceptions import ELFError
from elftools.elf.elffile import ELFFile

from tools.generate_memory_map import MemoryMap, MemoryRegion


class ElfSegment(TypedDict):
    address: int
    file_size: int
    memory_size: int
    flags: int
    data: bytes
    region: NotRequired[str]


class ElfImage(TypedDict):
    entry_point: int
    segments: list[ElfSegment]


def read_elf(data: bytes) -> ElfImage:
    """Read little-endian RV32 ELF and retain file-backed PT_LOAD bytes

    Use physical addresses for host loads. Validate layout before building a JTAG transaction
    """
    try:
        elf = ELFFile(io.BytesIO(data))
        load_segments = list(elf.iter_segments(type="PT_LOAD"))
    except ELFError as error:
        raise ValueError(f"Invalid ELF image: {error}") from error

    if (
        elf.elfclass != 32
        or not elf.little_endian
        or elf.header["e_machine"] != "EM_RISCV"
    ):
        raise ValueError("expected little-endian RV32 ELF executable")
    if elf.header["e_type"] not in ("ET_EXEC", "ET_DYN"):
        raise ValueError("expected RV32 executable/shared ELF")

    segments: list[ElfSegment] = []
    for segment in load_segments:
        header = segment.header
        physical_address = header["p_paddr"]
        file_size = header["p_filesz"]
        memory_size = header["p_memsz"]
        file_offset = header["p_offset"]

        if (
            file_size > memory_size
            or file_offset > len(data)
            or file_size > len(data) - file_offset
        ):
            raise ValueError("truncated/invalid PT_LOAD segment")
        if physical_address + memory_size > 0x100000000:
            raise ValueError("PT_LOAD address wraps RV32")
        if not memory_size:
            continue

        segments.append(
            {
                "address": physical_address,
                "file_size": file_size,
                "memory_size": memory_size,
                "flags": header["p_flags"],
                "data": segment.data(),
            }
        )
    return {"entry_point": elf.header["e_entry"], "segments": segments}


def memory_region(memory_map: MemoryMap, address: int, size: int) -> MemoryRegion:
    end = address + size
    region = next(
        (
            item
            for item in memory_map["regions"]
            if item["loadable"]
            and item["base"] <= address < end <= item["base"] + item["size"]
        ),
        None,
    )
    if region is None:
        raise ValueError("range is outside loadable memory")
    return region


def read_image(data: bytes, memory_map: MemoryMap) -> ElfImage:
    image = read_elf(data)
    previous_end = 0
    for segment in sorted(image["segments"], key=lambda item: item["address"]):
        address = segment["address"]
        region = memory_region(memory_map, address, segment["memory_size"])
        if address < previous_end:
            raise ValueError("ELF load segments overlap")
        previous_end = address + segment["memory_size"]
        if segment["flags"] & 1 and not region["executable"]:
            raise ValueError("executable ELF segment is outside executable memory")
        segment["region"] = region["name"]

    entry_point = image["entry_point"]
    if entry_point % 4 or not any(
        segment["flags"] & 1
        and segment["address"] <= entry_point
        and entry_point + 4 <= segment["address"] + segment["file_size"]
        for segment in image["segments"]
    ):
        raise ValueError(
            "entry point must be aligned and file-backed in executable memory"
        )
    return image


def write_load_plan(image: ElfImage, directory: str | Path) -> Path:
    """Keep binary payload separate from the small Tcl segment manifest"""
    directory = Path(directory)
    segments: list[dict[str, int | str]] = []
    with (directory / "segments.bin").open("wb") as payload:
        for segment in image["segments"]:
            segments.append(
                {
                    "address": segment["address"],
                    "file_offset": payload.tell(),
                    "file_size": segment["file_size"],
                    "memory_size": segment["memory_size"],
                    "region": segment["region"],
                }
            )
            payload.write(segment["data"])
    plan = directory / "plan.tcldata"
    plan.write_text(
        serialize_tcl_data({"entry_point": image["entry_point"], "segments": segments})
    )
    return plan


def serialize_tcl_data(value: object) -> str:
    """Serialize load-plan lists/dicts as inert Tcl data instead of Tcl commands"""
    if isinstance(value, dict):
        value = [item for pair in value.items() for item in pair]
    if isinstance(value, (tuple, list)):
        return " ".join("{" + serialize_tcl_data(item) + "}" for item in value)
    value = str(value)
    if not value or any(
        character
        not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
        for character in value
    ):
        raise ValueError("load-plan atom must be an inert identifier or integer")
    return value
