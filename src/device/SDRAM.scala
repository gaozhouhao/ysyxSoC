package ysyx

import chisel3._
import chisel3.util._
//import chisel3.experimental.Analog
import chisel3.experimental.{Analog, attach}

import freechips.rocketchip.amba.axi4._
import freechips.rocketchip.amba.apb._
import org.chipsalliance.cde.config.Parameters
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.util._

class SDRAMIO extends Bundle {
  val clk = Output(Bool())
  val cke = Output(Bool())
  val cs  = Output(UInt(2.W))
  val ras = Output(Bool())
  val cas = Output(Bool())
  val we  = Output(Bool())
  val a   = Output(UInt(13.W))
  val ba  = Output(UInt(2.W))
  val dqm = Output(UInt(4.W))
  val dqLo  = Analog(16.W)
  val dqHi  = Analog(16.W)
}

class SDRAMGroupIO extends Bundle {
  val clk = Output(Bool())
  val cke = Output(Bool())
  val cs  = Output(Bool())
  val ras = Output(Bool())
  val cas = Output(Bool())
  val we  = Output(Bool())
  val a   = Output(UInt(13.W))
  val ba  = Output(UInt(2.W))
  val dqm = Output(UInt(4.W))
  val dqLo  = Analog(16.W)
  val dqHi  = Analog(16.W)
}

class SDRAMChipIO extends Bundle {
  val clk = Output(Bool())
  val cke = Output(Bool())
  val cs  = Output(Bool())
  val ras = Output(Bool())
  val cas = Output(Bool())
  val we  = Output(Bool())
  val a   = Output(UInt(13.W))
  val ba  = Output(UInt(2.W))
  val dqm = Output(UInt(2.W))
  val dq  = Analog(16.W)
}

class sdram_top_axi extends BlackBox {
  val io = IO(new Bundle {
    val clock = Input(Clock())
    val reset = Input(Bool())
    val in = Flipped(new AXI4Bundle(AXI4BundleParameters(addrBits = 32, dataBits = 32, idBits = 4)))
    val sdram = new SDRAMIO
  })
}

class sdram_top_apb extends BlackBox {
  val io = IO(new Bundle {
    val clock = Input(Clock())
    val reset = Input(Bool())
    val in = Flipped(new APBBundle(APBBundleParameters(addrBits = 32, dataBits = 32)))
    val sdram = new SDRAMIO
  })
}

class sdram extends BlackBox {
  val io = IO(Flipped(new SDRAMChipIO))
}

class sdramGroup extends RawModule {
  val io = IO(Flipped(new SDRAMGroupIO))

  val chip0 = Module(new sdram)
  val chip1 = Module(new sdram)

  chip0.io.clk := io.clk
  chip1.io.clk := io.clk

  chip0.io.cke := io.cke
  chip1.io.cke := io.cke

  chip0.io.cs := io.cs
  chip1.io.cs := io.cs

  chip0.io.ras := io.ras
  chip1.io.ras := io.ras

  chip0.io.cas := io.cas
  chip1.io.cas := io.cas

  chip0.io.we := io.we
  chip1.io.we := io.we

  chip0.io.a := io.a
  chip1.io.a := io.a

  chip0.io.ba := io.ba
  chip1.io.ba := io.ba

  // DQM
  chip0.io.dqm := io.dqm(1,0)
  chip1.io.dqm := io.dqm(3,2)

  attach(chip0.io.dq, io.dqLo)
  attach(chip1.io.dq, io.dqHi)
}

class sdramChisel extends RawModule {
  val io = IO(Flipped(new SDRAMIO))

  val group0 = Module(new sdramGroup)
  val group1 = Module(new sdramGroup)

  group0.io.clk := io.clk
  group1.io.clk := io.clk

  group0.io.cke := io.cke
  group1.io.cke := io.cke

  group0.io.cs := io.cs(0)
  group1.io.cs := io.cs(1)

  group0.io.ras := io.ras
  group1.io.ras := io.ras

  group0.io.cas := io.cas
  group1.io.cas := io.cas

  group0.io.we := io.we
  group1.io.we := io.we

  group0.io.a := io.a
  group1.io.a := io.a

  group0.io.ba := io.ba
  group1.io.ba := io.ba

  // DQM
  group0.io.dqm := io.dqm
  group1.io.dqm := io.dqm

  attach(group0.io.dqLo, io.dqLo)
  attach(group1.io.dqLo, io.dqLo)

  attach(group0.io.dqHi, io.dqHi)
  attach(group1.io.dqHi, io.dqHi)
}

class AXI4SDRAM(address: Seq[AddressSet])(implicit p: Parameters) extends LazyModule {
  val beatBytes = 4
  val node = AXI4SlaveNode(Seq(AXI4SlavePortParameters(
    Seq(AXI4SlaveParameters(
        address       = address,
        executable    = true,
        supportsWrite = TransferSizes(1, beatBytes),
        supportsRead  = TransferSizes(1, beatBytes),
        interleavedId = Some(0))
    ),
    beatBytes  = beatBytes)))

  lazy val module = new Impl
  class Impl extends LazyModuleImp(this) {
    val (in, _) = node.in(0)
    val sdram_bundle = IO(new SDRAMIO)

    val msdram = Module(new sdram_top_axi)
    msdram.io.clock := clock
    msdram.io.reset := reset.asBool
    msdram.io.in <> in
    sdram_bundle <> msdram.io.sdram
  }
}

class APBSDRAM(address: Seq[AddressSet])(implicit p: Parameters) extends LazyModule {
  val node = APBSlaveNode(Seq(APBSlavePortParameters(
    Seq(APBSlaveParameters(
      address       = address,
      executable    = true,
      supportsRead  = true,
      supportsWrite = true)),
    beatBytes  = 4)))

  lazy val module = new Impl
  class Impl extends LazyModuleImp(this) {
    val (in, _) = node.in(0)
    val sdram_bundle = IO(new SDRAMIO)

    val msdram = Module(new sdram_top_apb)
    msdram.io.clock := clock
    msdram.io.reset := reset.asBool
    msdram.io.in <> in
    sdram_bundle <> msdram.io.sdram
  }
}
