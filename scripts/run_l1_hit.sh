#!/bin/bash
set -e
mkdir -p waves

BIN="/tmp/l1_hit_sim"
trap 'rm -f "$BIN"' EXIT

echo "Compiling L1-hit demonstration..."
iverilog -g2005 -I rtl -o "$BIN" \
    rtl/main_memory.v rtl/l2_cache.v rtl/l1_cache.v \
    tb/l1_hit_tb.v

echo "Running L1-hit demonstration..."
vvp "$BIN"

echo ""
echo "Waveform generated: waves/l1_hit.vcd"
