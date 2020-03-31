#!/bin/bash

VFLAGS="+define+SIMULATION"

VLIB="vlib.exe"
VMAP="vmap.exe"
VCOM="vcom.exe"
VLOG="vlog.exe $VFLAGS"
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
$VLOG spritegen.sv
$VLOG dkong_video.sv
#$VLOG video_tb.sv
#$VLOG video_tb.sv +define+TILEFILE='"test_data/dkong.game"'
$VLOG video_tb.sv +define+TILEFILE='"test_data/dkong.title"'
#$VLOG video_tb.sv +define+OBJFILE='"test_data/allscans.sprite"'

# Run Sim
popd
./testers/scrbuf/scrbuf.exe &
$VSIM video_tb &
