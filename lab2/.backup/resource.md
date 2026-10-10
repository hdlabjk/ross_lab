# Session Resource Summary

## Elapsed time

| Item | Start (JST) | End (JST) | Elapsed |
|------|-------------|-----------|---------|
| Chat session | 2026-10-10 08:27:46 | 08:49:41 (last update when this file was written) | about 22 min |
| Vivado GUI session (`vivado-20261010-082807-375e6353`) | 08:28:07 | about 08:49 (stopped on request; log last written 08:42:27) | about 21 min |
| Vivado TCL session for pin lookup (`vivado-20261010-084544-cea0cfc9`) | 08:45:44 | about 08:47:45 | about 2 min |

The stop time of the GUI session is estimated from the chat session timestamps.

## Vivado resource usage

| Item | Value |
|------|-------|
| Peak memory, GUI session | 3524.785 MB (`generate_target` of design_2) |
| Peak memory, TCL session | 1631.238 MB (`link_design -part xck26-sfvc784-2LV-c`) |
| Commands executed, GUI session | 61 (from the Vivado journal) |
| Commands that report timing in the log | 18 |
| Total elapsed time of those commands | 268 s |
| Total CPU time of those commands | 267 s |
| `link_design` in TCL session | CPU 16 s, elapsed 28 s |

Longest commands:

| Command | Elapsed | CPU |
|---------|---------|-----|
| `generate_target` (design_1) | 59 s | 51 s |
| `generate_target` (design_2) | 51 s | 48 s |
| `save_bd_design_as` | 21 s | 20 s |

No synthesis, implementation, or bitstream generation was run.

## Chat session

| Item | Value |
|------|-------|
| Turns recorded | 11 |
| LLM token usage | Not available from the local session store |

## Files created in this session

- `rep/ip_status.rpt`, `rep/bd_properties.rpt`, `rep/bd_address_map.rpt`, `rep/design_2_address_map.rpt`
- `update/hardware_spec.md`
- `rep/resource.md`
- Vivado project `lab2/` with `design_1` and `design_2`
