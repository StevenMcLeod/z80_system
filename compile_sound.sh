#!/bin/bash

VFLAGS="+define+SIMULATION +define+SIM_CLEAR_RAM"

VLIB="vlib.exe"
VMAP="vmap.exe"
VCOM="vcom.exe"
VLOG="vlog.exe $VFLAGS"
VSIM="vsim.exe"

set -e

rm -rf work

pushd hdl/sound
$VLIB ../../work
$VMAP work ../../work

# Common Components
$VLOG ../rom.sv
$VLOG ../ram.sv

# T48
$VCOM ../t48/t48_pack-p.vhd
$VCOM ../t48/int.vhd
$VCOM ../t48/int-c.vhd
$VCOM ../t48/*_pack-p.vhd

$VCOM ../t48/alu.vhd
$VCOM ../t48/bus_mux.vhd
$VCOM ../t48/clock_ctrl.vhd
$VCOM ../t48/cond_branch.vhd
$VCOM ../t48/db_bus.vhd
$VCOM ../t48/decoder.vhd
$VCOM ../t48/dmem_ctrl.vhd
$VCOM ../t48/p1.vhd
$VCOM ../t48/p2.vhd
$VCOM ../t48/pmem_ctrl.vhd
$VCOM ../t48/psw.vhd
$VCOM ../t48/timer.vhd
$VCOM ../t48/t48_core.vhd


$VLOG dkong_sound.sv
$VLOG sound_tb.sv

# Run Sim
popd
$VSIM sound_tb &
