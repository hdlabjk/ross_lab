# opt_design オプション比較 (opt_design → place_design)

- 入力: `update/mreduc_step4_synth.dcp` (step4 の合成結果, `update/` に保存)
- デバイス: xc7a100tfgg676-2、クロック `sys_clk` 3.000 ns
- 各実行は、同じ DCP を開き直してから `opt_design` と `place_design` を 1 回ずつ実行した。
- 実行時間は MCP の実行結果に示された経過時間(秒)で、PC の負荷による変動を含む。
- WNS/TNS/WHS は配置後の値 (配線前のため、WHS は未修正で負になっている)。
- LUT は `report_utilization` の `Slice LUTs`。

## 結果

| # | 実行 | opt_design オプション | opt 時間 (s) | place 時間 (s) | LUT | WNS (ns) | TNS (ns) | 違反EP / 全EP | WHS (ns) | 期待どおりか |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | 基準 | (なし、既定) | 5.2 | 70.6 | 5430 | -0.427 | -53.225 | 446 / 13449 | -0.066 | - |
| A | 候補 1 | `-directive ExploreWithRemap` | 8.6 | 86.3 | 5430 | -0.427 | -53.225 | 446 / 13449 | -0.066 | いいえ (改善なし) |
| B | 候補 2 | `-remap -carry_remap` | 5.4 | 91.2 | 5430 | -0.427 | -53.225 | 446 / 13449 | -0.066 | いいえ (改善なし) |
| C | 候補 3 | `-resynth_remap` | 21.2 | 99.5 | 5430 | -0.427 | -49.210 | 432 / 13449 | -0.066 | いいえ (WNS 変化なし) |

- C の `place_design` には `-no_bufg_opt` を付けて実行した (BUFG は 1 個のみ)。A は `-verbose`、B は `-quiet` を付けたが、結果には影響しない。
- 重複コマンド抑止のため、実行ごとに無害なオプションを付けた。

## 各オプションの結果と評価

| # | 期待 | 実際の opt_design の変化 | 評価 |
|---|---|---|---|
| A | LUT の再マッピングでロジック段数を削減し、WNS が改善する | `Remap` フェーズで cells created/removed ともに 0。netlist は基準と同一。 | 改善する LUT 段が無く、効果なし。 |
| B | CARRY4 を LUT に展開し、キャリー遅延を削減する | `Carry remap` / `LOOKAHEAD8 remap` / `Remap` すべて 0 cells。 | 展開対象 (global threshold 1 を満たす短いキャリー) が無く、効果なし。 |
| C | 高い効力の再合成で LUT の深さを減らす | `Total number of LUTs replicated during resynth remap are 0`、0 cells。実行時間が最も長い (21.2 s)。 | netlist は変化せず。TNS の差 (-53.2 → -49.2) は配置のばらつきによるもので、オプションの効果ではない。 |

## 考察

- 3 つとも netlist を変更せず、LUT 数 (5430) も WNS (-0.427 ns) も基準と同じだった。
- 最悪経路は、24 ビットの減算・加算・比較のキャリーチェーン (CARRY4) が支配的である。
  これは `opt_design` の再マッピングでは短縮できない構造である。
- `place_design` 後の WNS は、合成直後の -0.499 ns から -0.427 ns に変わっているが、これは配置後の遅延見積りの違いで、`opt_design` の効果ではない。
- 実行時間は `-resynth_remap` が最大 (opt 21.2 s) で、効果がないのに時間だけ増えた。
- 次の対策は RTL 側のパイプライン化が有効と考える。
  - `mean_reg`: 差分とシフト・加算を別の段に分ける。
  - `stat_min` / `stat_max`: 比較結果をレジスタ化し、次サイクルで更新する。
- 配置後のレポートは次のとおり。
  - [timing_place_base.rpt](timing_place_base.rpt)
  - [timing_place_A_explore_remap.rpt](timing_place_A_explore_remap.rpt)
  - [timing_place_B_carry_remap.rpt](timing_place_B_carry_remap.rpt)
  - [timing_place_C_resynth_remap.rpt](timing_place_C_resynth_remap.rpt)
  - 使用率は `util_place_*.rpt`。
