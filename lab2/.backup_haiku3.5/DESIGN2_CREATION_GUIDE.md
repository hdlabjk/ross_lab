# Design_2 ブロックデザイン作成ガイド

## 概要
3つの変更を反映した新しいブロックデザイン `design_2` を作成します：
1. BRAM: 8K×1port → 4K×true dual port (A:0x0000, B:0x1000)
2. クロック/リセット: 外部端子から供給、PS用に400MHz逓倍、他IP用に100MHz
3. ファイル名: `design_2` として保存

---

## Step 1: 新しいブロックデザイン作成

### 方法A: Vivado GUI から（推奨）

1. Vivado を開く（既に起動している場合はスキップ）
2. **File** → **Open Project** → `lab2.xpr` を選択
3. **Flow Navigator** の **Create Block Design** をクリック
   - 名前: `design_2`
   - ディレクトリ: `<project>/lab2.srcs/sources_1/bd` を指定
4. OK をクリック

**または**

Vivado TCL コンソールで以下を実行：
```tcl
create_bd_design -name design_2 -dir lab2.srcs/sources_1/bd/design_2
```

---

## Step 2: IP コアの追加と接続

### 2.1 外部クロック/リセットポート作成

**Vivado GUI:**
1. Canvas 右クリック → **Create Interface Port** または **Create Port**
2. ポート設定：
   - **ポート名**: `clk_100m`
   - **タイプ**: Clock (CLK)
   - **方向**: Input
   - **周波数**: 100MHz
3. 同様に **resetn** ポート作成
   - **タイプ**: Reset (RST)
   - **極性**: Active Low

**TCL:**
```tcl
set clk_port [create_bd_port -name clk_100m -type CLK -dir I]
set_property -dict [list CONFIG.FREQ_HZ 100000000] $clk_port

set rst_port [create_bd_port -name resetn -type RST -dir I]
set_property -dict [list CONFIG.POLARITY ACTIVE_LOW] $rst_port
```

---

### 2.2 Clock Wizard (100MHz → 400MHz 変換)

**Vivado GUI:**
1. Canvas 右クリック → **Add IP**
2. 検索: `clock wizard`
3. **Clocking Wizard** を選択 (xilinx.com:ip:clk_wiz)
4. インスタンス名: `clk_wiz_0`
5. **Customize IP** をクリック
   - **Clocking Options**:
     - Input Clock: 100 MHz
     - Output Clock Count: 1
   - **Output Clocks**:
     - **clk_out1**: 400 MHz (S型, Duty 50%)
   - OK をクリック
6. `clk_100m` ポートを `clk_wiz_0/clk_in1` に接続

---

### 2.3 Zynq PS コア追加と設定

**Vivado GUI:**
1. **Add IP** → `zynq_ultra_ps_e` (バージョン 3.3以上)
2. インスタンス名: `zynq_ultra_ps_e_0`
3. **Customize IP** をクリック
   - **PS-PL Configuration**:
     - **AXI Interfaces**: M_AXI_HPM0_FPD 有効化
   - **Clocking**: PS内部クロック生成は無効化（外部から供給）
   - OK
4. 接続:
   - `clk_100m` ポート → `zynq_ultra_ps_e_0/pl_clk0` (**外部100MHz**)
   - **クロック逓倍は PS内部で実施**（pl_clk0入力に対してPS内部で100MHz→400MHzに逓倍）
   - `resetn` ポート → `zynq_ultra_ps_e_0/pl_resetn0`

---

### 2.4 Processor System Reset

1. **Add IP** → `proc_sys_reset` (v5.0)
2. インスタンス名: `proc_sys_reset_0`
3. 接続:
   - `clk_100m` → `proc_sys_reset_0/slowest_clk`
   - `resetn` → `proc_sys_reset_0/ext_reset_in`
   - `proc_sys_reset_0/peripheral_aresetn` → 全PL IP の aresetn へ

---

### 2.5 Block Memory Generator (4K×32 true dual port)

1. **Add IP** → `blk_mem_gen` (v8.4以上)
2. インスタンス名: `blk_mem_gen_0`
3. **Customize IP**:
   - **Memory Type**: True Dual Port RAM
   - **Width A**: 32 bits
   - **Depth A**: 4096 (4K)
   - **Width B**: 32 bits
   - **Depth B**: 4096 (4K)
   - **Operating Modes**: Read First
   - **Synchronize Clocks**: チェック
   - OK
4. 接続:
   - `clk_100m` → `blk_mem_gen_0/clka`
   - `clk_100m` → `blk_mem_gen_0/clkb`

---

### 2.6 AXI BRAM Controller

1. **Add IP** → `axi_bram_controller` (v4.1)
2. インスタンス名: `axi_bram_controller_0`
3. **Customize IP**:
   - **BRAM Instance Mode**: External
   - ECC: 無効
   - OK
4. 接続:
   - `clk_100m` → `axi_bram_controller_0/s_axi_aclk`
   - `proc_sys_reset_0/peripheral_aresetn` → `axi_bram_controller_0/s_axi_aresetn`
   - `axi_bram_controller_0/BRAM_PORTA` ↔ `blk_mem_gen_0/BRAM_PORTA`
   - `axi_bram_controller_0/BRAM_PORTB` ↔ `blk_mem_gen_0/BRAM_PORTB`

**アドレスマップ設定:**
- Canvas 右クリック → **Address Editor**
- `axi_bram_controller_0/S_AXI/Mem0`:
  - **ベースアドレス**: 0xA0020000
  - **サイズ**: 16 KB (0x4000)
  - **Port A**: 0xA0020000 - 0xA0020FFF (0x0000 - 0x0FFF)
  - **Port B**: 0xA0021000 - 0xA0021FFF (0x1000 - 0x1FFF)

---

### 2.7 AXI DMA

1. **Add IP** → `axi_dma` (v7.1以上)
2. インスタンス名: `axi_dma_0`
3. **Customize IP**:
   - **Basic**:
     - **Scatter Gather**: チェック外し (Simple)
     - **Enable Multi-Channel**: チェック外し
   - **MM2S**:
     - **Width**: 64 bits
   - **S2MM**:
     - **Width**: 64 bits
   - OK
4. 接続:
   - `clk_100m` → `axi_dma_0/m_axi_mm2s_aclk`, `m_axi_s2mm_aclk`, `s_axi_lite_aclk`
   - `proc_sys_reset_0/peripheral_aresetn` → `axi_dma_0/axi_resetn`

---

### 2.8 AXI Timer

1. **Add IP** → `axi_timer` (v2.0)
2. インスタンス名: `axi_timer_0`
3. **Customize IP**:
   - **General**: デフォルト設定
   - OK
4. 接続:
   - `clk_100m` → `axi_timer_0/s_axi_aclk`
   - `proc_sys_reset_0/peripheral_aresetn` → `axi_timer_0/s_axi_aresetn`

---

### 2.9 Custom AXI-Stream Filter

1. **Add IP** → `axis_filter` (xilinx.com:user:axis_filter:1.0)
2. インスタンス名: `axis_filter_0`
3. 接続:
   - `clk_100m` → `axis_filter_0/aclk`
   - `proc_sys_reset_0/peripheral_aresetn` → `axis_filter_0/aresetn`

---

### 2.10 AXI Interconnect

1. **Add IP** → `axi_interconnect` (v2.1)
2. インスタンス名: `axi_interconnect_0`
3. **Customize IP**:
   - **Slave Interfaces**: 1 (S00_AXI)
   - **Master Interfaces**: 3 (M00_AXI, M01_AXI, M02_AXI)
   - OK
4. 接続:
   - `clk_100m` → `axi_interconnect_0/ACLK`
   - `proc_sys_reset_0/peripheral_aresetn` → `axi_interconnect_0/ARESETN`
   - `zynq_ultra_ps_e_0/M_AXI_HPM0_FPD` → `axi_interconnect_0/S00_AXI`
   - `axi_interconnect_0/M00_AXI` → `axi_dma_0/S_AXI_LITE` (アドレス: 0xA0000000)
   - `axi_interconnect_0/M01_AXI` → `axi_timer_0/S_AXI` (アドレス: 0xA0010000)
   - `axi_interconnect_0/M02_AXI` → `axi_bram_controller_0/S_AXI` (アドレス: 0xA0020000)

---

### 2.11 割り込み集約 (xlconcat)

1. **Add IP** → `xlconcat` (v2.1)
2. インスタンス名: `xlconcat_0`
3. **Customize IP**:
   - **Number of Ports**: 2
   - OK
4. 接続:
   - `axi_dma_0/mm2s_irq` → `xlconcat_0/In0`
   - `axi_timer_0/interrupt` → `xlconcat_0/In1`
   - `xlconcat_0/dout` → `zynq_ultra_ps_e_0/pl_ps_irq0`

---

### 2.12 データパス接続

1. DMA MM2S → Filter → DMA S2MM:
   - `axi_dma_0/M_AXIS_MM2S` → `axis_filter_0/axis_slave_in`
   - `axis_filter_0/axis_slave_out` → `axi_dma_0/S_AXIS_S2MM`

2. DMA データ転送パス (→ BRAM):
   - `axi_dma_0/M_AXI_MM2S` → `axi_bram_controller_0/S_AXI`
   - `axi_dma_0/M_AXI_S2MM` → `axi_bram_controller_0/S_AXI`

---

## Step 3: 検証と保存

### 3.1 ブロックデザイン検証

**Vivado GUI:**
1. **Flow Navigator** → **Validate Design**
2. エラーなし、警告のみであれば OK

**TCL:**
```tcl
validate_bd_design
```

### 3.2 ブロックデザイン保存

**Vivado GUI:**
- **File** → **Save Block Design** (Ctrl+S)

**TCL:**
```tcl
save_bd_design
```

### 3.3 RTL/XDC 生成

**Vivado GUI:**
1. **Flow Navigator** → **Generate Block Design**
   - または **Design** → **Generate HDL Wrapper**

**TCL:**
```tcl
generate_target all [get_files design_2.bd]
```

---

## 主な変更点のサマリ

| 項目 | Design_1 | Design_2 |
|------|----------|----------|
| **BRAM構成** | 8K×1port | 4K×dual port (A/B) |
| **クロック入力** | PS内部生成 | 外部100MHz入力 |
| **リセット入力** | PS内部生成 | 外部resetn入力 |
| **PS用クロック** | 100MHz | 100MHz → Clock Wizard → 400MHz (PS内部で逓倍) |
| **他IP用クロック** | PS pl_clk0 (100MHz) | 外部100MHz（変わらず） |
| **外部ポート** | なし | clk_100m, resetn |
| **ベースアドレス** | DMA: 0xA000_0000 | DMA: 0xA000_0000 (同じ) |
| **BRAM領域** | 0xA002_0000-0xA003_FFFF | 0xA002_0000-0xA002_FFFF (A: 0x0000-0x0FFF, B: 0x1000-0x1FFF) |

---

## トラブルシューティング

### IP接続エラー
- Canvas 左側の **Diagram** タブで IP をすべて確認
- 赤い X マークがあればクリックしてエラーメッセージを確認
- ポート名、方向、タイプを再確認

### クロック周波数エラー
- Clock Wizard の設定を確認（入力: 100MHz, 出力: 400MHz）
- PS pl_clk0 は外部100MHz入力で OK

### アドレスマップエラー
- **Address Editor** で overlap を確認
- BRAM: 0xA0020000-0xA0023FFF (16KB)
- DMA: 0xA0000000-0xA0001FFF
- Timer: 0xA0010000-0xA001FFFF

---

## 検証方法（devmem2コマンド）

デザイン完成後、ボード上で以下でテスト：

```bash
# BRAM Port A (0xA0020000) に書き込み
devmem2 0xA0020000 32 0x12345678

# BRAM Port B (0xA0021000) から読み取り
devmem2 0xA0021000 32

# 同じ値が返れば OK
```

---

EOF
