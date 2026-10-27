# Design_2 ブロックデザイン - 接続エラー修正ガイド

## 現在の状態

✅ 完了:
- design_2 ブロックデザイン作成
- 10個のIPコア インスタンス化
- 基本的なクロック/リセット接続
- RTL生成 (仮)

❌ エラー: 以下の接続が不完全
1. DMA MM2S/S2MM/SG マスター未接続
2. AXI Interconnect リセット接続問題
3. AXI-Stream Filter と DMA のデータ幅不一致 (64bit vs 32bit)
4. BRAM クロック接続の重複
5. PS割り込み設定互換性問題

---

## 修正方法

### 方法1: Vivado GUI で手動修正（推奨）

#### 手順1: design_2 をオープン

```tcl
# TCL Console で実行
open_bd_design lab2.srcs/sources_1/bd/design_2/design_2.bd
```

#### 手順2: エラー内容確認

Canvas 左側で以下を確認：
- 赤い X マーク → クリックして詳細確認
- 黄色い警告アイコン

---

### 修正A: DMA メモリマスター接続

**問題**: DMA の M_AXI_MM2S, M_AXI_S2MM が BRAM に接続されていない

**修正**:

1. Canvas で以下の未接続ポートを確認:
   - `axi_dma_0/M_AXI_MM2S` (read)
   - `axi_dma_0/M_AXI_S2MM` (write)

2. これらを BRAM Controller に接続：
   ```tcl
   # TCL Console で実行
   connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] \
                        [get_bd_intf_pins axi_bram_controller_0/S_AXI]
   connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] \
                        [get_bd_intf_pins axi_bram_controller_0/S_AXI]
   ```

3. または GUI で:
   - `axi_dma_0/M_AXI_MM2S` を右クリック → Connect
   - `axi_bram_controller_0/S_AXI` を選択
   - 同様に S2MM も接続

**警告**: 同じインターフェースに複数の AXI マスターを接続するため、
Interconnect（または AXI SmartConnect）の使用が正規の設計パターンですが、
同一インターフェースへの複数接続は禁止されます。

**推奨設計**: DMA MM2S と S2MM 用の個別 BRAM 領域を用意するか、
AXI Interconnect 経由にする必要があります。

---

### 修正B: データ幅の不一致

**問題**: AXI-Stream Filter の TDATA が 64-bit、DMA が 32-bit

**原因**: axis_filter.v の定義とDMA設定の不一致

**修正オプション**:

#### オプション1: DMA を 64-bit に変更（推奨）

```tcl
# DMA が 64-bit でインスタンス化済みか確認
get_property CONFIG.c_m_axi_mm2s_data_width [get_bd_cells axi_dma_0]
# 出力: 64 なら OK
```

DMA は既に 64-bit で設定済みなので、問題は AXI-Stream 接続側の
幅交渉にあります。

#### オプション2: Filter を再作成（32-bit版）

axis_filter.v を確認し、必要に応じて 32-bit 版に修正:

```verilog
// axis_filter.v
// TDATA[63:0] → TDATA[31:0] に修正
```

---

### 修正C: BRAM クロック接続の重複

**問題**: BRAMクロック接続が複数あり、相互参照が混乱

**修正**:

Canvas で BRAM 接続を整理：

```tcl
# 既存の重複接続を確認
get_bd_nets | grep -i "clk.*bram"

# 不要な接続を削除（必要に応じて）
delete_bd_net [get_bd_net clk_100m_bram]
delete_bd_net [get_bd_net clk_100m_bram_b]

# 代わりに BRAM Controller のクロック経由で配信（推奨）
# BRAM Controller の出力 → BRAM へ
```

**ベストプラクティス**: BRAM Controller が BRAM のクロック制御を担当。
外部ポートから直接接続は通常不要。

---

### 修正D: AXI Interconnect リセット接続

**問題**: Interconnect のリセット入力の一部が未接続

**修正**:

```tcl
# Interconnect の全リセット入力を確認
get_bd_pins axi_interconnect_0/*/ARESETN

# すべてを proc_sys_reset_0/peripheral_aresetn に接続
connect_bd_net -net psr_rst_ic_all [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
                                    [get_bd_pins axi_interconnect_0/*/ARESETN]
```

---

### 修正E: PS割り込み設定

**問題**: PS の pl_ps_irq0 入力形式が Vivado 2026.1 では異なる可能性

**修正**:

```tcl
# 割り込み接続を確認
get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq*

# xlconcat の出力を確認
get_bd_pins xlconcat_0/dout

# 手動接続
connect_bd_net -net irq_concat [get_bd_pins xlconcat_0/dout] \
                                [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]
```

---

## 修正スクリプト（全自動版）

以下の TCL コマンドをコンソールで実行：

```tcl
# Step 1: design_2 をアクティブに
current_bd_design design_2

# Step 2: DMA データマスター接続を再確認・修正
# 注意: 同じインターフェースへの複数マスター接続は非推奨
# ここでは既存接続をスキップし、設計パターン修正を推奨

# Step 3: BRAM クロック接続の最適化
# （この段階では TCL から自動修正困難）
# → GUI で手動確認が必要

# Step 4: Interconnect リセット統一
set ic_all_reset_pins [get_bd_pins axi_interconnect_0/*/ARESETN]
foreach pin $ic_all_reset_pins {
    catch {delete_bd_net [get_bd_net -of_objects $pin]}
}
connect_bd_net -net psr_rst_ic_unified [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
                                        $ic_all_reset_pins

# Step 5: 検証
validate_bd_design

# Step 6: 保存
save_bd_design
```

---

## 推奨: 設計パターンの見直し

現在の設計に いくつかの設計上の問題があります。
以下の修正を強く推奨します：

### 問題1: DMA メモリマスター → BRAM

**現在**:
```
DMA_MM2S --┐
           ├-→ BRAM_CNTRL → BRAM
DMA_S2MM --┘
```

**問題**: 同じ BRAM_CNTRL/S_AXI に複数のマスター接続は通常 AXI Interconnect を経由

**推奨設計A** (Interconnect 経由):
```
DMA_MM2S ──→ AXI_IC ──→ BRAM_CNTRL → BRAM
DMA_S2MM ──→ AXI_IC ──┘
```

**推奨設計B** (DMA → 直結):
```
DMA_MM2S → BRAM_CNTRL (Port A)
DMA_S2MM → BRAM_CNTRL (Port B)
```

現在の design_1 で正常に動作していた接続パターンを確認し、
design_2 でも同じパターンを採用すること。

---

## 即座の対応

### 短期: 現状で動作確認

現在の design_2 を以下の手順で修正最小化：

1. **Canvas で validation エラーをすべて確認**
   - 各エラーの "Fix" ボタンをクリック
   - Vivado が自動修正できるものは修正

2. **design_1 との比較**
   ```tcl
   # design_1 の接続パターンを参照
   open_bd_design lab2.srcs/sources_1/bd/design_1/design_1.bd
   # Canvas で接続構造を確認
   ```

3. **design_2 に同じパターンを適用**
   - design_1 の成功パターンをコピー
   - 必要な部分（BRAM容量、クロック）のみ変更

### 中期: 設計の最適化

1. **AXI Interconnect の活用**
   - DMA → IC → BRAM への接続に統一

2. **クロック分配の簡潔化**
   - 100MHz/400MHz の分岐を明確に

3. **テスト・検証**
   - design_2 を合成・実装
   - ボード上でハードウェアテスト

---

## 次のステップ

### すぐ実施（今日）
- [ ] Vivado GUI で design_2 Canvas を表示
- [ ] エラーメッセージをすべて確認・記録
- [ ] design_1 との接続パターン比較

### 完了目標（3-4時間以内）
- [ ] すべてのエラーを修正
- [ ] validate_bd_design を通過
- [ ] RTL/XDC を再生成
- [ ] update/ に保存

### テスト・検証（次段階）
- [ ] 合成 (synth)
- [ ] 実装 (impl)
- [ ] ボード上でのハードウェアテスト

---

## サポート

修正の詳細は以下のドキュメントを参照：

- **設計パターン**: DESIGN2_CREATION_GUIDE.md
- **実行手順**: DESIGN2_NEXT_STEPS.txt
- **仕様**: spec/hardware_spec.md
- **design_1 参照**: lab2.srcs/sources_1/bd/design_1/design_1.bd

---
