# Step4 タイミング解析 (RTL 修正後の合成結果)

- 対象: `update/` の修正版 RTL (`mreduc.sv`, `dsp_pipeline.sv`, `stats_engine.sv`) + `constraints/mreduc.xdc` (読み込みのみ)
- 合成: `synth_design -top mreduc -part xc7a100tfgg676-2 -flatten_hierarchy rebuilt` (project の `synth_1` と同じ既定設定)
- クロック: `sys_clk` 3.000 ns (333.3 MHz)
- レポート: [timing1.rpt](timing1.rpt), [timing1_mean_path.rpt](timing1_mean_path.rpt), [timing1_ce_path.rpt](timing1_ce_path.rpt), [drc_step4.rpt](drc_step4.rpt), [methodology_step4.rpt](methodology_step4.rpt), [util_step4.rpt](util_step4.rpt)

## RTL の変更内容

1. リセットを H レベル有効の同期リセット `rst` に変更 (ポート `rst_n` → `rst`)。
   - 削除: `delay_line`, `coeffs`, `products`, `accum_chain`, `pre_add`, `feedback_reg`, `final_accum`, `xbar_out`, `ch_data_out`, `hist_addr_r` のリセット (初期値 `'0` を宣言で指定)。
   - 残した: `valid_pipe`, `overflow_flags`, `xbar_valid`, `ch_valid_out`, `ch_overflow`, `cfg_regs`, 統計 (`stat_min/max`, `mean_reg`, `count`, `hist_valid_r`)。
2. 乗算の後ろに `mult_r` を追加し、乗算 → MREG → PREG の 2 段にして DSP48 の MREG を使わせた。`valid_pipe` も 1 段延長 (`NUM_TAPS+1` 段) してレイテンシを合わせた。

## 結果サマリ (step0 との比較)

| 項目 | step0 | step4 |
|---|---|---|
| WNS (セットアップ) | -1.494 ns | -0.499 ns |
| TNS | -9045.681 ns | -218.079 ns |
| セットアップ違反エンドポイント | 6680 / 20709 | 536 / 13437 |
| WHS (ホールド) | +0.136 ns | +0.079 ns (違反なし) |
| WPWS (パルス幅) | 1.000 ns | 0.646 ns (違反なし) |
| DSP48E1 の `AREG/BREG/MREG/PREG` | 0/0/0/1 | 2/2/1/1 |
| DSP の違反 (A/B ピン) | 6144 本 | 0 本 |
| DPIP-1 / DPOP-2 / DPIR-1 | 256 / 128 / 6144 件 | 0 件 |
| Slice Registers | 10964 | 5980 |
| Slice LUTs | 5699 | 5562 |

結論: **まだタイミングバイオレーションがある** (WNS -0.499 ns)。DSP 周りの違反は解消した。

## 残っている問題

違反エンドポイントは 536 本で、すべて統計エンジン `stats_engine` 内のパスである。

| エンドポイント | 本数 | 最悪スラック (ns) |
|---|---|---|
| FDRE:D (`mean_reg`) | 152 | -0.499 |
| FDRE:CE / FDSE:CE (`stat_min`, `stat_max`) | 384 | -0.479 |

### 1. `mean_reg` の D ピン (WNS -0.499 ns)

- パス: `xbar_out_reg[0][1]/C` → `stats[0].u_stats/mean_reg_reg[23]/D`
- データパス遅延 3.391 ns、ロジック 10 段 (LUT2 2 個と CARRY4 が 7 段連続)。
- 原因: `diff = data_in - mean_reg; mean_reg <= mean_reg + (diff >>> 4);` が 1 サイクルの組み合わせ演算になっている。
  24 ビットの減算、算術右シフト、24 ビットの加算が直列に並び、キャリーチェーンが 2 回通る。
  3.0 ns の周期には収まらない。

### 2. `stat_min` / `stat_max` の CE ピン (最悪 -0.479 ns)

- パス: `xbar_out_reg[0][0]/C` → `stats[0].u_stats/stat_min_reg[0]/CE`
- データパス遅延 3.134 ns (ロジック 1.431 ns、配線 1.703 ns)、ロジックは LUT4 → CARRY4 ×3 → LUT3。
- 原因: `if (data_in < stat_min) stat_min <= data_in;` の比較結果がそのまま FF のクロックイネーブルになっている。
  24 ビット比較のキャリーチェーンの出力が、24 本の FF の CE (fanout 24) を駆動する。

### 共通の特徴

- 起点はどちらも `xbar_out` で、この値が `stats_engine` の比較・減算に直結している。
- 3 ns という周期に対して、1 サイクルに 24 ビットの比較/加減算を入れていることが問題である。
- ホールドとパルス幅には問題がない。
- DSP 側は A/B/M/P すべてレジスタを使うようになり、違反はなくなった。

## 今回の変更で解消した項目

- DPIR-1 (非同期リセットによる DSP 取り込み阻害): 6144 件 → 0 件
- DPIP-1 / DPOP-2 (DSP 入力・MREG 未使用): 384 件 → 0 件
- `rst_n` の fanout が約 10574 から大幅に減少。FF の総数も 10964 から 5980 に減った。

## まだ残っている DRC / メソドロジ

- NSTD-1 / UCIO-1 (Critical Warning): I/O 標準とピン位置が未指定 (XDC に未記載)。
- CFGBVS-1 (Warning): `CFGBVS` / `CONFIG_VOLTAGE` が未設定。
- TIMING-18 (Warning, 234 件): 入出力ポートの遅延制約が未設定。

## 次の対策案

1. `mean_reg`: 差分計算 (`diff`) とシフト・加算を別の段に分け、パイプライン化する。
2. `stat_min` / `stat_max`: 比較結果をレジスタに保存し、次サイクルで更新する (`data_in` も 1 段遅らせる)。
3. 必要であれば XDC に I/O 標準、ピン位置、入出力遅延を追加する (`update/` に新規保存)。

既存の RTL, XDC, DCP は変更していない。
