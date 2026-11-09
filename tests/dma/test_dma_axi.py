"""Check the standard DMA engine through its AXI control and memory ports"""

import struct

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge
from coralnpu_test_utils.axi_slave import AxiSlave

DMA_BASE = 0x40050000
CTRL = 0x00
STATUS = 0x04
DESC_ADDR = 0x08
CTRL_ENABLE = 1 << 0
CTRL_START = 1 << 1
STATUS_DONE = 1 << 1
STATUS_ERROR = 1 << 2
WIDTH_SHIFT = 24

AXI_ID = 5
AXI_TIMEOUT_CYCLES = 1000
DMA_POLL_LIMIT = 10000
DESCRIPTOR_ADDRESS = 0x110000
GUARD_BYTES = 16
GUARD_VALUE = 0xA5


class Registers:
    def __init__(self, dut):
        self.dut = dut
        self.clock = dut.io_aclk

    def signal(self, channel, field):
        return getattr(self.dut, f"io_axi_slave_{channel}_{field}")

    async def send(self, channel, fields):
        await FallingEdge(self.clock)
        for name, value in fields.items():
            self.signal(channel, "bits_" + name).value = value
        self.signal(channel, "valid").value = 1
        for _ in range(AXI_TIMEOUT_CYCLES):
            await RisingEdge(self.clock)
            if self.signal(channel, "ready").value:
                break
        else:
            raise AssertionError(f"AXI request timed out: {channel}")
        await FallingEdge(self.clock)
        self.signal(channel, "valid").value = 0

    async def receive(self, channel):
        await FallingEdge(self.clock)
        self.signal(channel, "ready").value = 1
        for _ in range(AXI_TIMEOUT_CYCLES):
            await RisingEdge(self.clock)
            if self.signal(channel, "valid").value:
                assert int(self.signal(channel, "bits_resp").value) == 0
                assert int(self.signal(channel, "bits_id").value) == AXI_ID
                data = (
                    int(self.signal(channel, "bits_data").value)
                    if channel == "read_data"
                    else 0
                )
                break
        else:
            raise AssertionError(f"AXI response timed out: {channel}")
        await FallingEdge(self.clock)
        self.signal(channel, "ready").value = 0
        return data

    async def write(self, offset, data):
        await self.send("write_addr", {"addr": DMA_BASE + offset})
        await self.send("write_data", {"data": data, "strb": 0xF, "last": 1})
        await self.receive("write_resp")

    async def read(self, offset):
        await self.send("read_addr", {"addr": DMA_BASE + offset})
        return await self.receive("read_data")


@cocotb.test()
async def test_dma_axi_copy(dut):
    cocotb.start_soon(Clock(dut.io_aclk, 10, unit="ns").start())
    registers = Registers(dut)
    dut.io_aresetn.value = 0
    for channel in ("read_addr", "write_addr", "write_data"):
        registers.signal(channel, "valid").value = 0
    for channel in ("read_data", "write_resp"):
        registers.signal(channel, "ready").value = 0
    for channel in ("read_addr", "write_addr"):
        for field in (
            "addr",
            "id",
            "size",
            "len",
            "burst",
            "lock",
            "cache",
            "prot",
            "qos",
            "region",
        ):
            registers.signal(channel, "bits_" + field).value = {
                "id": AXI_ID,
                "size": 2,
                "burst": 1,
            }.get(field, 0)
    memory = AxiSlave(
        dut, "axi_master", dut.io_aclk, dut.io_aresetn, dut._log, has_memory=True
    )
    memory.start()
    await ClockCycles(dut.io_aclk, 5)
    dut.io_aresetn.value = 1
    await ClockCycles(dut.io_aclk, 5)

    # Exercise narrow transfers in different byte lanes and full rows across 4 KiB
    for width, source, target, length in (
        (2, 0x80001004, 0x100408, 68),
        (4, 0x80000FF0, 0x100400, 4112),
    ):
        expected = bytes(i % 256 for i in range(length))
        memory.memory.update(enumerate(expected, source))
        memory.memory.update(
            (address, GUARD_VALUE)
            for address in range(target - GUARD_BYTES, target + length + GUARD_BYTES)
        )
        descriptor = struct.pack(
            "<8I", source, target, length | width << WIDTH_SHIFT, 0, 0, 0, 0, 0
        )
        memory.memory.update(enumerate(descriptor, DESCRIPTOR_ADDRESS))
        await registers.write(DESC_ADDR, DESCRIPTOR_ADDRESS)
        await registers.write(CTRL, CTRL_ENABLE | CTRL_START)
        for _ in range(DMA_POLL_LIMIT):
            status = await registers.read(STATUS)
            if status & (STATUS_DONE | STATUS_ERROR):
                assert status & STATUS_DONE and not status & STATUS_ERROR, hex(status)
                break
        else:
            raise AssertionError("DMA copy timed out")
        assert bytes(memory.memory[target + i] for i in range(length)) == expected
        assert all(
            memory.memory[address] == GUARD_VALUE
            for address in range(target - GUARD_BYTES, target)
        )
        assert all(
            memory.memory[address] == GUARD_VALUE
            for address in range(target + length, target + length + GUARD_BYTES)
        )
