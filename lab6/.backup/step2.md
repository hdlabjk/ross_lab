# Step2: タイミング以外の問題 (DRC / 使用率 / メソドロジ)

対象: `synth_1` 合成後の `mreduc` (xc7a100tfgg676-2, Vivado 2025.2)。
すべて合成済みデザインを `open_run synth_1` で開いた状態で実行した。

## 使用したコマンド

```tcl
report_drc               -file rep/drc_synth.rpt
report_utilization       -file rep/util_synth.rpt
report_methodology       -file rep/methodology_synth.rpt
report_cdc               -file rep/cdc_synth.rpt
report_high_fanout_nets  -timing -load_types -max_nets 10 -file rep/fanout_synth.rpt
report_control_sets      -verbose -file rep/control_sets_synth.rpt
```

(実際の出力先は `C:/cygwin64/home/jkikkawa/src/ai-assistant-ea/lab6/rep/` の絶対パス)

## 結果サマリ

| 項目 | 結果 | 判定 |
|---|---|---|
| DRC | 387 件 (Critical Warning 2, Warning 385) | 要対応 |
| メソドロジ | 7378 件 (すべて Warning) | 要対応 |
| CDC | 指摘なし (クロックは `sys_clk` のみ) | 問題なし |
| 使用率 | LUT 9.0%, FF 8.7%, DSP 53.3%, BRAM 0%, IOB 78.3% | 逼迫なし (IOB, DSP はやや高め) |
| 制御セット | 215 | 問題なし |

## DRC (`rep/drc_synth.rpt`)

| ルール | 重大度 | 件数 | 内容 |
|---|---|---|---|
| NSTD-1 | Critical Warning | 1 | 全 235 ポートの IOSTANDARD が未指定 |
| UCIO-1 | Critical Warning | 1 | 全 235 ポートのピン位置 (LOC) が未指定 |
| CFGBVS-1 | Warning | 1 | `CFGBVS` / `CONFIG_VOLTAGE` が未設定 |
| DPIP-1 | Warning | 256 | DSP48 の入力 (A/B) がパイプライン化されていない |
| DPOP-2 | Warning | 128 | DSP48 の MREG が使われていない |

- NSTD-1 / UCIO-1 は、このままではビットストリームを生成できない。
- 制約ファイル [constraints/mreduc.xdc](../constraints/mreduc.xdc) には `create_clock` 1 行しかなく、I/O の標準・ピン配置・入出力遅延がない。
- DPIP-1 / DPOP-2 はタイミング違反の原因そのもの (step0 参照)。

## メソドロジ (`rep/methodology_synth.rpt`)

| ルール | 重大度 | 件数 | 内容 |
|---|---|---|---|
| DPIR-1 | Warning | 6144 | DSP 入力に接続された FF が非同期リセットで、DSP 内レジスタに吸収できない |
| TIMING-16 | Warning | 1000 | 大きなセットアップ違反 (報告上限 1000 件) |
| TIMING-18 | Warning | 234 | 入力または出力遅延 (`set_input_delay` / `set_output_delay`) が未設定 |

- DPIR-1 が重要な発見である。
  - `delay_line` と `coeffs` が `always_ff @(posedge clk or negedge rst_n)` の非同期リセット付きである。
  - DSP48E1 のレジスタは同期リセットしか持たない。
  - そのため、A/B レジスタに FF を取り込めず、`AREG=0, BREG=0, MREG=0` になっている。
  - step0 のタイミング違反の根本原因の一つで、パイプラインを足すだけでなくリセット方式も直す必要がある。
- TIMING-18: 入出力ポートに遅延制約がなく、I/O タイミングが検証されていない。

## 使用率 (`rep/util_synth.rpt`)

| リソース | 使用 | 利用可能 | 使用率 |
|---|---|---|---|
| Slice LUTs | 5699 | 63400 | 8.99% |
| Slice Registers | 10964 | 126800 | 8.65% |
| F7 Muxes | 186 | 31700 | 0.59% |
| Block RAM | 0 | 135 | 0% |
| DSPs | 128 | 240 | 53.33% |
| Bonded IOB | 235 | 300 | 78.33% |
| BUFG | 1 | 32 | 3.13% |

- LUT / FF / BRAM は余裕がある。使用率が原因の問題はない。
- DSP は 8 チャネル x 16 タップ = 128 個で、半分強を使用している。
- IOB が 78% と高い。`cfg_rdata[31:0]`, `cfg_wdata[31:0]` など幅の広いポートが多く、ピン割り当てが難しくなる可能性がある。

## その他の問題 (ファンアウト, `rep/fanout_synth.rpt`)

| ネット | ファンアウト | 備考 |
|---|---|---|
| `channel[7].u_dsp/rst_n` | 10574 | リセット信号がほぼ全 FF に接続 |
| `cfg_regs_reg_n_0_[0][*]` | 443 (各) | 設定レジスタが約 440 個の負荷を駆動 |
| `acc_stage[0].accum_chain_reg[1][23]_i_2__0_n_0` | 384 | |

- リセットは全体で 1 本に集中しており、リセットのファンアウトが非常に大きい。
- 非同期リセットの全面使用は DPIR-1 の原因でもある。
- 同期リセットにして、DSP に接続される FF は可能なら完全に省略する。
- 先に報告した `ce` の CE ピン違反 (step0) と合わせて、制御信号の分散を検討する。

## 優先度付き対応案

1. DSP 経路: 非同期リセットを除去 (または同期リセット化) し、A/B/M レジスタを使えるように乗算の前後へパイプラインを追加する。
2. 制約: IOSTANDARD, LOC, `CFGBVS` / `CONFIG_VOLTAGE`, 入出力遅延を XDC に追加する (`update/` に新規保存する)。
3. 制御信号: `rst_n` の同期化とファンアウト削減、`ce` の複製を行う。
4. 統計エンジンの長い組み合わせ経路を分割する (step0 参照)。

既存の RTL, XDC, DCP は変更しない。変更案は `update/` に保存する。
