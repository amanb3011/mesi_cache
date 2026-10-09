`ifndef CACHE_DEFS_SVH
`define CACHE_DEFS_SVH

// ---------------------------------------------------------
// Basic system parameters
// ---------------------------------------------------------

`define ADDR_WIDTH 16
`define DATA_WIDTH 32

// Cache line = 16 bytes = 4 x 32-bit words
`define LINE_SIZE_BYTES 16
`define WORDS_PER_LINE   4

// ---------------------------------------------------------
// Cache sizes
// ---------------------------------------------------------

`define L1_SIZE_BYTES 256
`define L2_SIZE_BYTES 1024

// ---------------------------------------------------------
// Memory
// ---------------------------------------------------------

`define MEMORY_SIZE_BYTES 65536

// ---------------------------------------------------------
// Latencies (in clock cycles)
// ---------------------------------------------------------

`define L1_LATENCY     1
`define L2_LATENCY     5
`define MEMORY_LATENCY 20

`endif