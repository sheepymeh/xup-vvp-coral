package xup

import bus._

import chisel3._
import chisel3.stage.ChiselGeneratorAnnotation
import _root_.circt.stage.{ChiselStage, FirtoolOption}
import scala.annotation.nowarn

/** Expose the standard DMA engine as AXI register and memory interfaces */
class DmaAxi extends RawModule {
  private val hostParams   = new TLULParameters(dataBits = 128, addrBits = 32, idBits = 6)
  private val deviceParams = new TLULParameters(dataBits = 32, addrBits = 32, idBits = 6)

  val io = IO(new Bundle {
    val aclk       = Input(Clock())
    val aresetn    = Input(AsyncReset())
    val axi_slave  = Flipped(new AxiMasterIO(32, 32, 6))
    val axi_master = new AxiMasterIO(32, 128, 6)
  })

  withClockAndReset(io.aclk, (!io.aresetn.asBool).asAsyncReset) {
    val dma       = Module(new DmaEngine(hostParams, deviceParams))
    val registers = Module(
      new Axi2TLUL(
        deviceParams,
        () => new OpenTitanTileLink_A_User,
        () => new OpenTitanTileLink_D_User
      )
    )
    val memory = Module(
      new TLUL2Axi(
        hostParams,
        128,
        32,
        6,
        () => new OpenTitanTileLink_A_User,
        () => new OpenTitanTileLink_D_User
      )
    )

    registers.io.axi <> io.axi_slave
    dma.io.tl_device.a <> registers.io.tl_a
    registers.io.tl_d <> dma.io.tl_device.d
    memory.io.tl_a <> dma.io.tl_host.a
    dma.io.tl_host.d <> memory.io.tl_d
    io.axi_master <> memory.io.axi
  }
}

@nowarn
object EmitDmaAxi extends App {
  (new ChiselStage).execute(
    Array("--target", "systemverilog") ++ args,
    Seq(ChiselGeneratorAnnotation(() => new DmaAxi), FirtoolOption("-enable-layers=Verification"))
  )
}
