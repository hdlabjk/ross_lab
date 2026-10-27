# Design_2 インタラクティブ修正ガイド

## 現状と対応方針

上記の TCL スクリプト実行により、design_2 ブロックデザインが部分的に作成されました。
ただし、いくつかの接続エラーが報告されています。

**この文書では、Vivado GUI を使用してこれらのエラーを段階的に修正する手順を提供します。**

---

## 前提条件

- Vivado が起動中 (PID 4912)
- lab2.xpr プロジェクトが開かれている
- design_2 ブロックデザインが部分的に存在

---

## 推奨される修正順序

### フェーズ1: 現状把握（5分）

#### ステップ1.1: design_2 をオープン

**GUI操作:**
1. Vivado ウィンドウの左側 **Sources** パネルから探す
2. **Design Sources** → **design_2** を右クリック
3. **Open Design** をクリック

**または TCL で:**
```tcl
open_bd_design lab2.srcs/sources_1/bd/design_2/design_2.bd
```

#### ステップ1.2: エラー・警告の確認

Canvas が表示されたら、以下を確認：

1. **右側ウィンドウの "Messages" タブ**
   - すべてのエラーメッセージをコピー・保存
   - エラーの順序を記録

2. **Canvas 上の視覚的エラー表示**
   - 赤い X マーク: クリックして詳細確認
   - 黄色い警告: 設計上の問題（非致命的）

3. **各エラーメッセージの記録**
   - 例: "M_AXI_MM2S not connected"
   - 例: "Address overlap in axi_bram_controller_0"

---

### フェーズ2: 接続エラーの修正（10-15分）

#### ステップ2.1: design_1 との比較

**GUI操作:**
1. **Flow Navigator** → **File** → **Open Recent** 
   または **File** → **Open Block Design**
2. `design_1.bd` をオープン（新規ウィンドウ、または別タブ）
3. Canvas 上の以下を確認：
   - IP コアの配置
   - データパス接続
   - クロック/リセット配線
   - アドレスマップ

**記録する情報:**
```
Design_1 の構造:
  • どの IP コアが相互接続されているか
  • アドレスマップ（DMA/Timer/BRAM のベースアドレス）
  • クロック配給のパターン
  • 外部ポート（あれば）
```

#### ステップ2.2: design_2 に同じパターンを適用

design_1 を参考にしながら、design_2 の以下を修正：

**2.2.1: DMA メモリマスター接続**

**問題の症状:**
```
ERROR: [BD XX] M_AXI_MM2S (axi_dma_0) is not connected
ERROR: [BD XX] M_AXI_S2MM (axi_dma_0) is not connected
```

**修正方法:**

Canvas で以下を視認的に接続：

1. `axi_dma_0/M_AXI_MM2S` ピンを右クリック
2. **Make Connection** → Canvas上の接続ターゲットをクリック
   - ターゲット: `axi_bram_controller_0/S_AXI`
   - またはインターコネクト経由

3. 同様に `axi_dma_0/M_AXI_S2MM` も接続

**または TCL で:**
```tcl
# design_2 をアクティブにしていることを確認
current_bd_design design_2

# DMA MM2S を BRAM に直接接続
connect_bd_intf_net -intf_net dma_mm2s_bram \
  [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] \
  [get_bd_intf_pins axi_bram_controller_0/S_AXI]

# DMA S2MM を BRAM に直接接続
connect_bd_intf_net -intf_net dma_s2mm_bram \
  [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] \
  [get_bd_intf_pins axi_bram_controller_0/S_AXI]

# ⚠️ 警告: 同じインターフェースに複数マスター接続
# これが通常の AXI パターンではない場合は、
# Interconnect 経由の接続に修正してください
```

**注意:**
```
AXI バスの標準パターン:
  マスター → Interconnect → スレーブ

同じスレーブに複数マスターを接続する場合:
  M1 ┐
     ├→ AXI Interconnect → Slave
  M2 ┘

現在の design_2 では、複数マスター → 単一スレーブの
非標準パターンになっています。

Design_1 ではどうなっているかを確認してください。
```

**2.2.2: AXI Interconnect リセット接続**

**問題の症状:**
```
WARNING: [BD XX] axi_interconnect_0/S00_AXI_ARESETN not connected
WARNING: [BD XX] axi_interconnect_0/M00_AXI_ARESETN not connected
(など)
```

**修正方法:**

Canvas で確認：
1. Interconnect の全リセット入力を右クリック
2. **Connect** を選択
3. `proc_sys_reset_0/peripheral_aresetn` に接続

**または TCL で:**
```tcl
# Interconnect の全リセット入力を一括接続
set psr_rst [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
set all_aresetn [get_bd_pins axi_interconnect_0/*/ARESETN]

foreach pin $all_aresetn {
  catch {
    connect_bd_net -net [format "psr_rst_%s" [regsub -all {:} $pin {_}]] \
      $psr_rst $pin
  }
}
```

**2.2.3: BRAM クロック接続（重複・競合の解決）**

**問題の症状:**
```
WARNING: [BD XX] blk_mem_gen_0/clka connected to multiple sources
```

**修正方法:**

Canvas で以下を確認：
1. `blk_mem_gen_0/clka` と `clkb` の接続元を確認
2. 外部ポート `clk_100m` からの直接接続があれば、これを削除
3. 代わりに、BRAM Controller 経由の接続に統一

**または TCL で:**
```tcl
# BRAM クロック接続を確認
get_bd_nets -of_objects [get_bd_pins blk_mem_gen_0/clka]

# 不要な接続を削除（ただし完全に削除する前に確認）
# delete_bd_net [get_bd_net clk_100m_bram]

# 推奨: 外部クロック → Processor System Reset → BRAM
# (既に接続済みの可能性)
```

**推奨パターン:**
```
External clk_100m
  ├→ PS pl_clk0
  ├→ Clock Wizard (100MHz → 400MHz)
  ├→ proc_sys_reset_0/slowest_clk
  ├→ すべてのPL IP (DMA, Timer, Filter, etc.)
  └→ BRAM (直接 or Controller 経由)
```

**2.2.4: AXI-Stream データ幅不一致**

**問題の症状:**
```
WARNING: [BD XX] axis_filter_0/axis_slave_in has width 32 bits
         axi_dma_0/M_AXIS_MM2S has width 64 bits
```

**原因:**
- DMA: 64-bit AXI-Stream
- Filter: 32-bit AXI-Stream (または逆)

**修正方法:**

**オプションA: DMA を 32-bit に変更（推奨・最小変更）**

```tcl
# DMA の現在の設定を確認
get_property CONFIG.c_m_axi_mm2s_data_width [get_bd_cells axi_dma_0]

# 32-bit に変更するには IP を再インスタンス化
# または設定をリセット（既にインスタンス化後の場合は困難）

# 代替案: axis_filter.v を確認し、
# TDATA 幅を実際の設定に合わせる
```

**オプションB: Filter を 64-bit に変更**

```bash
# axis_filter.v を編集
# TDATA[63:0] (64-bit) に修正
```

**オプションC: AXI Stream Converter を追加**

64-bit と 32-bit を変換するIPを挿入：
```tcl
set converter [create_bd_cell -type ip \
  -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_converter_0]
set_property -dict [list CONFIG.TDATA_NUM_BYTES 8] $converter

# DMA → Converter → Filter に接続
```

**推奨:** axis_filter.v が 64-bit 対応か確認し、
DMA 設定と合わせる。

---

### フェーズ3: 検証と再生成（5分）

#### ステップ3.1: ブロックデザイン検証

**GUI操作:**
1. **Flow Navigator** → **Validate Design** ボタン
2. または **Tools** → **Validate Design**
3. メッセージウィンドウでエラー/警告を確認

**TCL で:**
```tcl
validate_bd_design
```

**期待される出力:**
```
✓ No error found
! Only warnings (non-critical)
```

#### ステップ3.2: エラーが残る場合

**再度エラーメッセージを確認:**
- 各エラーをメモ
- 上記のフェーズ2に戻って修正を繰り返す

**design_1 との比較を再実施**
- design_1 で同じエラーが出ていないか確認
- 出ていなければ、その接続パターンを design_2 にコピー

#### ステップ3.3: 検証成功後、RTL再生成

```tcl
# design_2 が完全に検証されたら
generate_target all [get_files design_2.bd]
```

**生成ファイル:**
- `design_2_bd.v` (synthesizable RTL)
- `design_2_bd.xdc` (constraints)
- `design_2_wrapper.v` (top-level wrapper)

---

### フェーズ4: ファイル保存（3分）

#### ステップ4.1: 生成ファイルを update/ に保存

```powershell
# PowerShell で実行
$source = "C:\cygwin64\home\jkikkawa\demo\ross_lab\lab2\lab2.srcs\sources_1\bd\design_2\hw_handoff"
$dest = "C:\cygwin64\home\jkikkawa\demo\ross_lab\lab2\update"

if (Test-Path $source) {
  Copy-Item "$source\design_2_bd.v" $dest -Force
  Copy-Item "$source\design_2_bd.xdc" $dest -Force
  Copy-Item "$source\design_2.hwh" $dest -Force
}
```

#### ステップ4.2: 修正レポート作成

```
ファイル: update/DESIGN2_CREATION_REPORT.txt

内容:
  • 実行日時
  • 修正内容（どのエラーを修正したか）
  • 検証結果
  • 生成ファイルリスト
  • 今後の作業予定
```

---

## トラブルシューティング

### エラー: "Cannot open design_2.bd"

**原因:** design_2 がまだ作成されていない

**対応:**
```tcl
# design_2 を新規作成
create_bd_design -name design_2 -dir lab2.srcs/sources_1/bd/design_2
```

### エラー: "IP core not found"

**原因:** IP catalog に存在しないバージョンが指定されている

**対応:**
1. Tools → IP Catalog で該当IPを検索
2. バージョン番号を確認
3. TCL スクリプトのバージョンを更新

### 接続がうまくいかない

**原因:** Canvas でのドラッグドロップが失敗

**対応:**
1. マウスでの接続ではなく TCL コマンドを使用
2. ピン名が完全に一致しているか確認
3. インターフェース/ネットの種別を確認

---

## チェックリスト

修正の完了を確認するために、以下をチェック：

- [ ] design_2.bd がオープンできる
- [ ] Canvas 上にすべてのIP（10個）が表示される
- [ ] エラーメッセージがゼロ
- [ ] 警告は非致命的なもののみ
- [ ] validate_bd_design が成功
- [ ] RTL/XDC ファイルが生成される
- [ ] update/ にファイルが保存される
- [ ] design_2 と design_1 の主な違い（BRAM容量、クロック配給）が反映される

---

## 次のステップ

修正完了後：

1. **合成テスト**
   ```tcl
   launch_runs synth_1 -jobs 4
   wait_on_run synth_1
   ```

2. **実装テスト**
   ```tcl
   launch_runs impl_1 -jobs 4
   wait_on_run impl_1
   ```

3. **ボード上でのハードウェアテスト**
   - bitstream 生成
   - KV260 への書き込み
   - devmem2 ループバックテスト

---
