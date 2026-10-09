#!/bin/bash
set -e
mkdir -p waves

BIN="/tmp/mesi_read_sim"
trap 'rm -f "$BIN"' EXIT

echo "Compiling MESI read-sharing demonstration..."
iverilog -g2005 -I rtl -o "$BIN" \
    rtl/main_memory.v rtl/l2_cache.v rtl/l1_cache.v rtl/shared_bus.v rtl/cache_system.v \
    tb/mesi_read_tb.v

echo "Running MESI read-sharing demonstration..."
vvp "$BIN"

echo ""
echo "Waveform generated: waves/mesi_read.vcd"
