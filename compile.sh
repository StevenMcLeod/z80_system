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

# Bus Masters
$VLOG tv80/rtl/core/*

# Peripherals
$VLOG oport.sv
$VLOG rom.sv

# System Devices
$VLOG addr_decoder.sv
$VLOG sysmux.sv
$VLOG z80System.sv

# Testbench
$VLOG tb.sv

# Run Sim
cd ..
$VSIM tb &
