# Step 7: RTL Lint Report (updated RTL)

| Item | Value |
|------|-------|
| Design | `packet_processor` (top) |
| RTL | [update/packet_processor.sv](../update/packet_processor.sv) (derived from `src/packet_processor.v`, which is unchanged) |
| XDC | [constraints/packet_processor.xdc](../constraints/packet_processor.xdc) (unchanged) |
| Part | `xc7a100tfgg676-2` |
| Tool | Vivado v2025.2 |
| Command | `synth_design -top packet_processor -part xc7a100tfgg676-2 -lint -file rep/step7.lint.rpt` |
| Raw report | [rep/step7.lint.rpt](step7.lint.rpt) |
| Total violations | **2** (1 CRITICAL WARNING, 1 WARNING; 0 waived) — down from 8 in [step 1](step1.lint.md) |

## Changes applied

| # | Change | Location in `update/packet_processor.sv` |
|--:|--------|------------------------------------------|
| 1 | `next_state` case: `default` branch added, `next_state = ST_IDLE` | [L91-L93](../update/packet_processor.sv#L91-L93) |
| 1 | Datapath case on `curr_state`: the `ST_IDLE` branch became `default`, so undefined states behave as `ST_IDLE` | [L125-L131](../update/packet_processor.sv#L125-L131) |
| 1 | Output case: selects on `mode_sel[1:0]` (the MSB is ignored), so all 4 values are covered | [L140-L161](../update/packet_processor.sv#L140-L161) |
| 2 | `payload_offset <= rx_data[3:0] >> 14;` left as is | [L112](../update/packet_processor.sv#L112) |
| 3 | `debug_status` has `(* mark_debug = "true" *)` | [L48](../update/packet_processor.sv#L48) |
| 4 | All three `always_ff` blocks use a synchronous reset (`@(posedge clk)`, no `negedge rst_n`) | state, datapath and `debug_status` registers |

## Summary

### By rule ID

| Rule ID | Severity | Count | Description | Step 1 |
|---------|----------|------:|-------------|-------:|
| ASSIGN-3 | CRITICAL WARNING | 1 | Shifter overflow | 1 |
| ASSIGN-10 | WARNING | 1 | IO bit(s) not read | 0 (new) |
| INFER-1 | CRITICAL WARNING | 0 | Inferred latch | 4 |
| INFER-2 | CRITICAL WARNING | 0 | Incomplete case statement | 2 |
| ASSIGN-6 | WARNING | 0 | Signal assigned but not read | 1 |

### By source file

| File | Count |
|------|------:|
| packet_processor.sv | 2 |

## Remaining violations

| # | Rule | Severity | Signal / Item | Line |
|--:|------|----------|---------------|-----:|
| 1 | ASSIGN-3 | CRITICAL WARNING | `>>` (`rx_data[3:0] >> 14`) | [112](../update/packet_processor.sv#L112) |
| 2 | ASSIGN-10 | WARNING | `mode_sel` (first unread bit: 2) | [21](../update/packet_processor.sv#L21) |

### 1. ASSIGN-3 – Shifter overflow (line 112)

Left unchanged as instructed. `rx_data[3:0]` is 4 bits wide and is shifted right by 14, so the result is always 0. The LHS `payload_offset` is 13 bits wide. The line was 116 in the original file; it moved to 112 because the `ST_IDLE` branch was reordered.

### 2. ASSIGN-10 – `mode_sel[2]` not read (line 21)

This is a consequence of change 1: the output `case` now uses `mode_sel[1:0]`, so bit 2 is intentionally unused. Accept it, or waive it:

```tcl
create_waiver -type LINT -id ASSIGN-10 -rtl_name mode_sel -rtl_hierarchy packet_processor -rtl_file packet_processor.sv
```

## Resolved violations

| Step 1 violation | Resolution |
|------------------|------------|
| INFER-1 x4 (`next_state`, `tx_data`, `tx_valid`, `rx_ready`) | `default` branch in the next-state case; the output case is now fully covered by `mode_sel[1:0]` |
| INFER-2 x2 (lines 66, 136) | Same as above |
| ASSIGN-6 (`debug_status`) | The signal is now kept by `mark_debug` |

## Other observations from the synthesis log

- `Synth 8-6014`: `pkt_priority_reg` and `payload_offset_reg` are still removed as unused (not a lint rule). `debug_status_reg` is no longer removed.
- The project source set now contains `update/packet_processor.sv` instead of `src/packet_processor.v`.
- Behavioral problems discussed earlier are not addressed by these changes: `crc_accum` is not cleared between packets, FSM transitions ignore `rx_ready`, and `rx_valid` is not checked in `HEADER` and `PAYLOAD`.
