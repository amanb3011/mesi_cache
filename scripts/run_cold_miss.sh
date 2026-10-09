#!/bin/bash
set -e
mkdir -p waves

BIN="/tmp/cold_miss_sim"
trap 'rm -f "$BIN"' EXIT

echo "Compiling cold-miss demonstration..."
iverilog -g2005 -I rtl -o "$BIN" \
    rtl/main_memory.v rtl/l2_cache.v rtl/l1_cache.v \
    tb/cold_miss_tb.v

echo "Running cold-miss demonstration..."
vvp "$BIN"

echo ""
echo "Waveform generated: waves/cold_miss.vcd"
