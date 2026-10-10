# AXI4 Master 検証結果

デバイス: xc7a35tcpg236-1 / シミュレータ: Vivado XSim (behavioral) / 検証 IP: AXI VIP (slave), AXI Protocol Checker

修正後 RTL は `update/`、ログは `rep/` に保存。`rtl/` の元ファイルは未変更。
修正後は全テストベンチで違反 0 件、2425 ns で完走(PASS)。

| テストベンチ | 検出エラー(修正前) | RTL の問題点 | 差分(`-` 修正前 / `+` 修正後) | 修正後 |
|---|---|---|---|---|
| `tb_axi_master` (baseline) | なし(TEST PASSED) | なし | なし | PASS |
| `tb_axi_master_bug1` | 285 ns `XIL_AXI_WLAST_VIOLATION` / `AXI4_ERRM_WDATA_NUM`(AWLEN=7 に対し 1 ビートで WLAST) | `WLAST` を最初のビートで出力しており、バースト最終ビートで立たない | `update/axi_master_bug1.sv`<br>`- m_axi_wlast  = (beat_q == 8'b0);`<br>`+ m_axi_wlast  = (beat_q == cur_len);` | PASS |
| `tb_axi_master_bug2` | 205 ns `AXI4_ERRM_AWVALID_RESET`(リセット直後に AWVALID=1) | リセット時の状態が `ST_WR_ADDR` で、リセット解除直後から AWVALID を出力 | `update/axi_master_bug2.sv`<br>`- state_q <= ST_WR_ADDR;`<br>`+ state_q <= ST_IDLE;` | PASS |
| `tb_axi_master_bug3` | 285 ns `AXI4_ERRM_WDATA_X`(WVALID 中の WDATA が X) | `m_axi_wdata` が未駆動の `wdata_from_fifo` に接続されている | `update/axi_master_bug3.sv`<br>`- m_axi_wdata  = wdata_from_fifo;`<br>`+ m_axi_wdata  = cur_beat_wdata;` | PASS |
| `tb_axi_master_bug4` | 535 ns `AXI_AUXM_WCAM_OVERFLOW` / 1005 ns `XIL_AXI_WLAST_VIOLATION`(期待 1 ビートに 16 ビート) | `awvalid_latch` が一度 1 になると下がらず、AWVALID が出続けて AW が多重発行される | `update/axi_master_bug4.sv`<br>`- logic awvalid_latch = 1'b0;`<br>`- always_comb begin if (state_q == ST_WR_ADDR) awvalid_latch = 1'b1; end`<br>`- assign m_axi_awvalid = awvalid_latch;`<br>`+ assign m_axi_awvalid = (state_q == ST_WR_ADDR);` | PASS |
| `tb_axi_master_bug5` | 2235 ns `AXI_AUXM_WCAM_OVERFLOW`(未完了の書き込みが溢れる) | 最終 W ビート後に `ST_WR_RESP` を飛ばして `ST_DISPATCH` へ戻り、B 応答待ちと `op_idx_q` 更新が行われず同じ書き込みを繰り返す | `update/axi_master_bug5.sv`<br>`- if (beat_q == cur_len) state_q <= ST_DISPATCH;`<br>`+ if (beat_q == cur_len) state_q <= ST_WR_RESP;` | PASS |

## ログ

| テストベンチ | 修正前 | 修正後 |
|---|---|---|
| `tb_axi_master` | `simulate_tb_axi_master.log` | - |
| `tb_axi_master_bug1` | `simulate_tb_axi_master_bug1.log` | `simulate_tb_axi_master_bug1_fixed.log` |
| `tb_axi_master_bug2` | `simulate_tb_axi_master_bug2.log` | `simulate_tb_axi_master_bug2_fixed.log` |
| `tb_axi_master_bug3` | `simulate_tb_axi_master_bug3.log` | `simulate_tb_axi_master_bug3_fixed.log` |
| `tb_axi_master_bug4` | `simulate_tb_axi_master_bug4.log` | `simulate_tb_axi_master_bug4_fixed.log` |
| `tb_axi_master_bug5` | `simulate_tb_axi_master_bug5.log` | `simulate_tb_axi_master_bug5_fixed.log` |
