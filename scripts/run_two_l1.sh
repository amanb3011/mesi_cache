#!/bin/bash
set -e
mkdir -p waves

BIN="/tmp/two_l1_sim"
trap 'rm -f "$BIN"' EXIT

echo "Compiling simultaneous-request demonstration..."
iverilog -g2005 -I rtl -o "$BIN" \
    rtl/main_memory.v rtl/l2_cache.v rtl/l1_cache.v rtl/shared_bus.v rtl/cache_system.v \
    tb/two_l1_tb.v

echo "Running simultaneous-request demonstration..."
vvp "$BIN"

echo ""
echo "Waveform generated: waves/two_l1.vcd"
