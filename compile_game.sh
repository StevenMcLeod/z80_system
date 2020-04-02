#!/bin/bash

VFLAGS="+define+SIMULATION"

VLIB="vlib.exe"
VMAP="vmap.exe"
VCOM="vcom.exe"
VLOG="vlog.exe $VFLAGS"
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
$VLOG z80rom_banked.sv
$VLOG z80uart.sv

# Bus Masters
$VLOG tv80/rtl/core/tv80_alu.v
$VLOG tv80/rtl/core/tv80_core.v
$VLOG tv80/rtl/core/tv80_mcode.v
$VLOG tv80/rtl/core/tv80_reg.v
$VLOG tv80/rtl/core/tv80n.v
$VLOG tv80/rtl/core/tv80s.v
$VLOG fakedma.sv

# T48
$VCOM t48/t48_pack-p.vhd
$VCOM t48/int.vhd
$VCOM t48/*_pack-p.vhd

$VCOM t48/alu.vhd
$VCOM t48/bus_mux.vhd
$VCOM t48/clock_ctrl.vhd
$VCOM t48/cond_branch.vhd
$VCOM t48/db_bus.vhd
$VCOM t48/decoder.vhd
$VCOM t48/dmem_ctrl.vhd
$VCOM t48/p1.vhd
$VCOM t48/p2.vhd
$VCOM t48/pmem_ctrl.vhd
$VCOM t48/psw.vhd
$VCOM t48/timer.vhd
$VCOM t48/t48_core.vhd

# Sound Devices
$VLOG sound/dkong_sound.sv

# Video Devices
$VLOG video/paletter.sv
$VLOG video/tilegen.sv
$VLOG video/spritegen.sv
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
