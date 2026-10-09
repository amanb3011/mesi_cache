#!/bin/bash
set -e
mkdir -p waves

BIN="/tmp/l2_hit_sim"
trap 'rm -f "$BIN"' EXIT

echo "Compiling L2-hit demonstration..."
iverilog -g2005 -I rtl -o "$BIN" \
    rtl/main_memory.v rtl/l2_cache.v rtl/l1_cache.v \
    tb/l2_hit_tb.v

echo "Running L2-hit demonstration..."
vvp "$BIN"

echo ""
echo "Waveform generated: waves/l2_hit.vcd"
