# RTL Design & Verification of MESI Cache Coherence Protocol with Next-Line Prefetching

Mid-semester RTL submission for the two-core MESI cache hierarchy.
The next-line prefetcher is final-stage work and is not included in the mid-sem RTL.

## RTL architecture

- 2 cores / request generators
- 2 private 256 B direct-mapped L1 caches
- Shared 1 KB direct-mapped L2 cache
- 64 KB main memory
- 16 B cache line (4 x 32-bit words)
- 16-bit byte addresses, 32-bit data
- Write-back + write-allocate
- MESI states: I=00, S=01, E=10, M=11
- Shared snooping bus; arbitration is inside `shared_bus.v`
- Configured latencies: L1=1, L2=5, Memory=20 cycles

## Mid-sem demonstration testbenches

Each report demonstration has one dedicated testbench and one VCD waveform.

| Report case | Testbench | Run command | Waveform |
|---|---|---|---|
| Cold L1/L2 miss -> main memory | `tb/cold_miss_tb.v` | `./scripts/run_cold_miss.sh` | `waves/cold_miss.vcd` |
| L1 hit | `tb/l1_hit_tb.v` | `./scripts/run_l1_hit.sh` | `waves/l1_hit.vcd` |
| L2 hit | `tb/l2_hit_tb.v` | `./scripts/run_l2_hit.sh` | `waves/l2_hit.vcd` |
| Simultaneous two-core requests | `tb/two_l1_tb.v` | `./scripts/run_two_l1.sh` | `waves/two_l1.vcd` |
| MESI read sharing | `tb/mesi_read_tb.v` | `./scripts/run_mesi_read.sh` | `waves/mesi_read.vcd` |
| MESI write + invalidation | `tb/mesi_write_tb.v` | `./scripts/run_mesi_write.sh` | `waves/mesi_write.vcd` |
| Modified-line intervention | `tb/mesi_intervention_tb.v` | `./scripts/run_mesi_intervention.sh` | `waves/mesi_intervention.vcd` |
| Dirty eviction / write-back | `tb/dirty_eviction_tb.v` | `./scripts/run_dirty_eviction.sh` | `waves/dirty_eviction.vcd` |

Run the scripts from the project root. Each script compiles with Icarus Verilog `-g2005`, prints one concise demonstration result, and writes its own waveform under `waves/`.

The `LAT` values printed by the hierarchy demonstrations are testbench-measured end-to-end transaction latencies. They are not the configured component latency values themselves.
