#!/bin/bash

VLIB="vlib.exe"
VMAP="vmap.exe"
VCOM="vcom.exe"
VLOG="vlog.exe"
VSIM="vsim.exe"

set -e

rm -rf work

pushd hdl/video
$VLIB ../../work
$VMAP work ../../work

# Common Components
$VLOG ../rom.sv
$VLOG ../ram.sv

$VLOG paletter.sv
$VLOG tilegen.sv
$VLOG dkong_video.sv
$VLOG video_tb.sv +define+TESTFILE='"dkong.game"'
#$VLOG video_tb.sv +define+TESTFILE='"dkong.title"'

# Run Sim
popd
./testers/scrbuf/scrbuf.exe &
$VSIM video_tb &
