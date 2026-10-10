# Step 1: RTL Lint Report

| Item | Value |
|------|-------|
| Design | `packet_processor` (top) |
| RTL | [src/packet_processor.v](../src/packet_processor.v) (file type: SystemVerilog) |
| XDC | [constraints/packet_processor.xdc](../constraints/packet_processor.xdc) |
| Part | `xc7a100tfgg676-2` |
| Tool | Vivado v2025.2 |
| Command | `synth_design -top packet_processor -part xc7a100tfgg676-2 -lint -file rep/step1.lint.rpt` |
| Raw report | [rep/step1.lint.rpt](step1.lint.rpt) |
| Total violations | **8** (6 CRITICAL WARNING, 1 WARNING; 0 waived) |

Note: the source file has a `.v` extension but uses SystemVerilog constructs (`logic`, `typedef enum`, `always_comb`). It was added to the project with file type `SystemVerilog`. The source file was not modified.

## Summary

### By rule ID

| Rule ID | Severity | Count | Description |
|---------|----------|------:|-------------|
| INFER-1 | CRITICAL WARNING | 4 | Inferred latch |
| INFER-2 | CRITICAL WARNING | 2 | Incomplete case statement (no default) |
| ASSIGN-3 | CRITICAL WARNING | 1 | Shifter overflow |
| ASSIGN-6 | WARNING | 1 | Signal assigned but not read |

### By source file

| File | Count |
|------|------:|
| packet_processor.v | 8 |

## Violations

| # | Rule | Severity | Signal / Item | Line | Section |
|--:|------|----------|---------------|-----:|---------|
| 1 | ASSIGN-3 | CRITICAL WARNING | `>>` (`rx_data[3:0] >> 14`) | [116](../src/packet_processor.v#L116) | Datapath, `ST_HEADER` |
| 2 | ASSIGN-6 | WARNING | `debug_status` (bit 0 first unread) | [48](../src/packet_processor.v#L48) | Declaration |
| 3 | INFER-1 | CRITICAL WARNING | `next_state_reg` | [69](../src/packet_processor.v#L69) | Next-state logic |
| 4 | INFER-1 | CRITICAL WARNING | `tx_data_reg` | [138](../src/packet_processor.v#L138) | Mode-based output |
| 5 | INFER-1 | CRITICAL WARNING | `tx_valid_reg` | [139](../src/packet_processor.v#L139) | Mode-based output |
| 6 | INFER-1 | CRITICAL WARNING | `rx_ready_reg` | [140](../src/packet_processor.v#L140) | Mode-based output |
| 7 | INFER-2 | CRITICAL WARNING | case on `curr_state` | [66](../src/packet_processor.v#L66) | Next-state logic |
| 8 | INFER-2 | CRITICAL WARNING | case on `mode_sel` | [136](../src/packet_processor.v#L136) | Mode-based output |

### 1. ASSIGN-3 – Shifter overflow (line 116)

`rx_data[3:0] >> 14` shifts a 4-bit value by 14, so the result is always 0. The LHS `payload_offset` is 13 bits wide. The intended shift is probably a left shift, or the shift amount is wrong.

```diff
-                    payload_offset <= rx_data[3:0] >> 14;   // shift amount (14) exceeds operand width; result is constant 0
+                    payload_offset <= {9'b0, rx_data[3:0]}; // example: define the intended offset explicitly (confirm with spec)
```

### 2. ASSIGN-6 – `debug_status` not read (line 48)

`debug_status` is written in the debug register process but never read, so Vivado removes it (`Synth 8-6014`). `pkt_priority` and `payload_offset` are also removed as unused in the same way.

```diff
-    logic [7:0]              debug_status;                  // never read; removed during synthesis
+    (* mark_debug = "true" *) logic [7:0] debug_status;     // keep for ILA debug, or delete the signal and its always_ff block
```

If it is not needed, delete the declaration and the `always_ff` block that drives it. If it is only for monitoring, drive an output port or add `mark_debug`.

### 3-6. INFER-1 – Inferred latches (lines 69, 138, 139, 140)

Both `always_comb` blocks contain a `case` that does not assign the outputs for every possible selector value, so latches are inferred:

- `next_state`: `curr_state` is 3 bits (8 values) but only 5 are covered (`3'b101`-`3'b111` are missing).
- `tx_data`, `tx_valid`, `rx_ready`: `mode_sel` is 3 bits (8 values) but only `3'b000`-`3'b011` are covered.

Fix with a default branch (see INFER-2 below), or assign default values at the top of the `always_comb` block.

### 7-8. INFER-2 – Incomplete case statements (lines 66, 136)

Next-state logic (line 66):

```diff
             ST_FORWARD: begin
                 next_state = ST_IDLE;
             end
+            default: next_state = ST_IDLE;   // cover unused encodings 3'b101-3'b111 and return to a safe state
         endcase
```

Mode-based output (line 136):

```diff
             3'b011: begin
                 tx_data  = rx_data;
                 tx_valid = 1'b0;
                 rx_ready = 1'b0;
             end
+            default: begin                   // cover mode_sel 3'b100-3'b111
+                tx_data  = '0;
+                tx_valid = 1'b0;
+                rx_ready = 1'b0;
+            end
         endcase
```

## Recommendations

| Priority | Action | Rules |
|----------|--------|-------|
| Immediate (fix before synthesis) | Add `default` branches to both `case` statements to remove latches | INFER-1 x4, INFER-2 x2 |
| Immediate | Correct the `payload_offset` expression | ASSIGN-3 |
| Cleanup | Remove `debug_status` or make it observable (output port / `mark_debug`) | ASSIGN-6 |

Any RTL fix must be saved as a new file under `update/` (for example `update/packet_processor.v`); the original `src/packet_processor.v` and `constraints/packet_processor.xdc` stay unchanged.

## Other observations from the synthesis log

- `Synth 8-155`: the three `case` statements (lines 66, 105, 136) are not full and have no default. The one at line 105 (datapath) is not flagged by the linter.
- `Synth 8-87`: `always_comb` on `next_state_reg`, `tx_data_reg`, `tx_valid_reg` and `rx_ready_reg` did not result in combinational logic (consistent with the latch findings).
