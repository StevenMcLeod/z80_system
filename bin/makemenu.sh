#!/bin/bash

MAME_DIR="/c/Program Files/MAME/"
DKONG_PATH="roms/dkong/"
Z80FLAGS=""

INPUT_FILES="menu.z80"
BIN_FILE="menu.bin"
ROM_SIZE="4096"
TOTAL_ROM_SIZE="$((4*$ROM_SIZE))"

set -e

echo "Assembling..."
z80asm $Z80FLAGS $INPUT_FILES -o $BIN_FILE

BINSIZE=$(stat -c%s "$BIN_FILE")

# Zeropad bin
echo "Padding..."
dd if=/dev/zero bs=1 count=$(($TOTAL_ROM_SIZE - $BINSIZE)) seek=$BINSIZE >> $BIN_FILE

echo "Copying..."
head -c$ROM_SIZE menu.bin                           > "$MAME_DIR$DKONG_PATH/c_5et_g.bin"
head -c$((2*$ROM_SIZE)) menu.bin | tail -c$ROM_SIZE  > "$MAME_DIR$DKONG_PATH/c_5ct_g.bin"
head -c$((3*$ROM_SIZE)) menu.bin | tail -c$ROM_SIZE  > "$MAME_DIR$DKONG_PATH/c_5bt_g.bin"
head -c$((4*$ROM_SIZE)) menu.bin | tail -c$ROM_SIZE  > "$MAME_DIR$DKONG_PATH/c_5at_g.bin"

echo "Runinng..."
cd "$MAME_DIR" 
./mame64 dkong -debug &
