#!/bin/bash

VLIB="vlib.exe"
VMAP="vmap.exe"
VCOM="vcom.exe"
VLOG="vlog.exe"
VSIM="vsim.exe"

set -e

rm -rf work

cd hdl
$VLIB ../work
$VMAP work ../work

# Common Components
$VLOG prio_encoder.sv
$VLOG ram.sv
$VLOG rom.sv
$VLOG z80ram.sv
$VLOG z80rom.sv
$VLOG z80uart.sv

# Bus Masters
$VLOG tv80/rtl/core/tv80_alu.v
$VLOG tv80/rtl/core/tv80_core.v
$VLOG tv80/rtl/core/tv80_mcode.v
$VLOG tv80/rtl/core/tv80_reg.v
$VLOG tv80/rtl/core/tv80n.v
$VLOG tv80/rtl/core/tv80s.v

# Video Devices
$VLOG video/paletter.sv
$VLOG video/tilegen.sv
$VLOG video/dkong_video.sv

# System Devices
$VLOG addr_decoder.sv
$VLOG sysmux.sv
$VLOG dkong_system.sv

# Testbench
$VLOG game_tb.sv

# Run Sim
cd ..
$VSIM game_tb &
