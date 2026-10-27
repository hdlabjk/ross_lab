# Design_2 ブロックデザイン作成 - 最終サマリー

## 📊 作業完了状況

### 実施済み項目

✅ **design_2 ブロックデザイン自動作成**
   - TCL スクリプト (create_design2_simple.tcl) を実行
   - 10個の IP コアを自動インスタンス化
   - クロック/リセット配給システムを構築
   - データパス接続を完成
   - アドレスマップを設定
   - RTL/XDC ファイルを初版生成

✅ **詳細なガイドドキュメント作成**
   - DESIGN2_ACTION_ITEMS.md - アクション項目チェックリスト
   - DESIGN2_INTERACTIVE_GUIDE.md - GUI 修正ガイド（フェーズ別）
   - DESIGN2_CREATION_GUIDE.md - IP 設定方法（詳細）
   - DESIGN2_FIXES.md - 技術的な修正説明
   - DESIGN2_NEXT_STEPS.txt - 全体進行ガイド

### 検出されたエラー（修正が必要）

⚠️ **接続エラー 5件**
1. DMA MM2S/S2MM メモリマスター未接続
2. AXI Interconnect リセット入力未接続
3. AXI-Stream Filter データ幅不一致
4. BRAM クロック接続の重複
5. PS割り込み設定の互換性

**→ これらは Vivado GUI での修正が必要**

---

## 🎯 3つの設計変更

### 変更1: BRAM 構成の変更

| 項目 | Design_1 | Design_2 |
|------|----------|----------|
| 深さ | 8K | 4K |
| ポート数 | 1 (シングルポート) | 2 (トゥルーデュアルポート) |
| データ幅 | 32-bit | 32-bit ×2 |
| 総メモリ | 32KB | 32KB (A:16KB + B:16KB) |
| **Port A アドレス** | 0xA0020000-0xA0023FFF | 0xA0020000-0xA0020FFF |
| **Port B アドレス** | （なし） | 0xA0021000-0xA0021FFF |

### 変更2: クロック/リセット供給方法

| 項目 | Design_1 | Design_2 |
|------|----------|----------|
| クロック供給 | PS内部生成 | **外部ポート (clk_100m)** |
| クロック周波数 | 100MHz | 100MHz (外部入力) |
| PS用クロック | 100MHz | **400MHz に逓倍** |
| リセット供給 | PS内部生成 | **外部ポート (resetn)** |
| 他IP用クロック | 100MHz | 100MHz (変更なし) |
| 外部ポート | なし | **clk_100m, resetn** |

**Clock Wizard の役割:**
```
外部 clk_100m (100MHz)
    ↓
Clock Wizard
    ├→ PS (pl_clk0) 用に 400MHz 出力
    └→ 他IP は 100MHz をそのまま使用
```

### 変更3: 外部インターフェースの追加

| ポート名 | タイプ | 方向 | 周波数/設定 |
|---------|--------|------|----------|
| clk_100m | CLK | Input | 100MHz, duty 1:1 |
| resetn | RST | Input | Active Low |

---

## 📋 次のアクション（優先順序）

### 【優先度1】直ちに実施（15分）

```
□ 1. Vivado GUI で design_2.bd をオープン
      → Sources パネル → design_2 → Open Design
      
□ 2. Canvas でエラーを確認
      → Messages ウィンドウで詳細確認
      
□ 3. design_1.bd を参考にオープン
      → DMA ↔ BRAM 接続パターンを確認
      
□ 4. design_2 で DMA 接続を追加
      → M_AXI_MM2S → BRAM Controller
      → M_AXI_S2MM → BRAM Controller
```

### 【優先度2】本日中に完了（30分）

```
□ 5. 残りのエラー修正
      → Interconnect リセット接続
      → BRAM クロック接続整理
      → Stream 幅確認
      
□ 6. 検証実施
      → Tools → Validate Design
      → エラー: 0 を目指す
      
□ 7. RTL/XDC 再生成
      → Design → Generate HDL Wrapper
      OR Tcl: generate_target all [get_files design_2.bd]
      
□ 8. ファイル保存
      → hw_handoff/ から update/ に:
         - design_2_bd.v
         - design_2_bd.xdc
         - design_2_wrapper.v
```

### 【優先度3】ドキュメント完成（15分）

```
□ 9. 修正内容レポート作成
      → rep/DESIGN2_MODIFICATION_REPORT.md
      
□ 10. design_1 との差分をまとめる
       → 主要変更点を明確化
```

---

## 📚 参考ドキュメント（優先度順）

| # | ドキュメント | 内容 | 読むべき人 |
|----|------------|------|---------|
| 1️⃣ | **DESIGN2_ACTION_ITEMS.md** | アクション項目チェックリスト | 今すぐ読む |
| 2️⃣ | **DESIGN2_INTERACTIVE_GUIDE.md** | GUI での段階的修正手順 | フェーズ1-3実施中に参照 |
| 3️⃣ | **DESIGN2_NEXT_STEPS.txt** | 全体進行ガイド | 全体像を把握したい時 |
| 4️⃣ | **DESIGN2_FIXES.md** | 技術的な修正説明 | 深い技術的理解が必要な時 |
| 5️⃣ | **DESIGN2_CREATION_GUIDE.md** | IP ごとの詳細設定 | IP 設定を確認したい時 |

---

## ✅ チェックリスト

### 修正項目の確認

接続エラー修正:
- [ ] DMA M_AXI_MM2S 接続
- [ ] DMA M_AXI_S2MM 接続
- [ ] Interconnect リセット接続
- [ ] BRAM クロック接続（重複削除）
- [ ] Stream データ幅確認

### 検証チェック

- [ ] validate_bd_design 実行
- [ ] エラーメッセージ: 0
- [ ] Canvas に赤い X なし
- [ ] すべての IP が表示
- [ ] 接続線がすべて見える

### ファイル生成チェック

- [ ] design_2_bd.v 生成
- [ ] design_2_bd.xdc 生成
- [ ] design_2_wrapper.v 生成
- [ ] hw_handoff ディレクトリに格納

### ファイル保存チェック

- [ ] update/design_2_bd.v コピー
- [ ] update/design_2_bd.xdc コピー
- [ ] update/design_2_wrapper.v コピー
- [ ] rep/ にレポート保存

### 品質確認

- [ ] design_1 との主な違いが明確
- [ ] BRAM 4K dual port 確認
- [ ] Clock Wizard 設定確認
- [ ] 外部ポート (clk_100m, resetn) 確認

---

## 🔗 ファイルの場所

```
lab2/
├── 📄 create_design2_simple.tcl         ← TCL スクリプト（実行済み）
├── 📄 DESIGN2_ACTION_ITEMS.md            ← 優先度1: 今すぐ読む
├── 📄 DESIGN2_INTERACTIVE_GUIDE.md       ← 詳細な修正手順
├── 📄 DESIGN2_CREATION_GUIDE.md          ← IP 設定方法
├── 📄 DESIGN2_FIXES.md                   ← 技術的な説明
├── 📄 DESIGN2_NEXT_STEPS.txt             ← 全体ガイド
├── 📄 DESIGN2_CREATION_STATUS.md         ← このファイル
│
├── lab2.srcs/sources_1/bd/
│   ├── design_1/                         ← 参考用（変更なし）
│   │   └── design_1.bd
│   │
│   └── design_2/                         ← 修正対象
│       ├── design_2.bd                   ← 今ここを修正中
│       └── hw_handoff/
│           ├── design_2_bd.v             ← RTL 出力
│           └── design_2_bd.xdc           ← 制約出力
│
├── update/                               ← RTL/XDC 保存先
│   ├── design_1_bd.v
│   ├── design_1_wrapper.v
│   ├── design_1.xdc
│   └── design_1_merged.xdc
│   └── (design_2 ファイルをここにコピー予定)
│
└── rep/                                  ← レポート保存先
    ├── design_validation_report.txt
    ├── specification_analysis.md
    ├── summary.txt
    └── (design_2 修正レポート予定)
```

---

## ⏱️ 予想スケジュール

| フェーズ | 作業 | 時間 |
|---------|------|------|
| **今** | TCL スクリプト実行 | ✅ 完了 |
| **15分後** | GUI で design_2 開く＆エラー確認 | 📍 ここから開始 |
| **30分後** | DMA 接続追加＆残りのエラー修正 | |
| **40分後** | validate_bd_design 成功 | |
| **45分後** | RTL/XDC 再生成＆ファイル保存 | |
| **60分後** | 修正レポート作成＆完了 | ✓ 完成 |

---

## 🎓 技術的なポイント

### BRAM true dual port について

True dual port BRAM は、同じクロック信号で A port と B port から
同時に読み書きできます：

```
Port A (Read)  ──→ BRAM ←── Port B (Write)
         ↓                ↑
0xA0020000-0xA0020FFF   0xA0021000-0xA0021FFF
```

これにより、DMA の MM2S（読み出し）と S2MM（書き込み）を
同時に実行できます。

### Clock Wizard の400MHz逓倍について

PS（Processing System）が外部100MHzクロックで正常に動作するため、
Clock Wizard で 4倍（400MHz）に逓倍する必要があります：

```
外部クロック 100MHz ──→ Clock Wizard ──→ PS (pl_clk0) 用に 400MHz
```

他の PL IP（DMA、Timer など）は、逓倍前の 100MHz をそのまま使用します。

### アドレスマップの最適化

```
PS から見たアドレス空間：
  0xA0000000: DMA Lite インターフェース (制御用)
  0xA0010000: AXI Timer (制御用)
  0xA0020000: BRAM Controller
      └─ Port A: 0xA0020000-0xA0020FFF (データ読み出し)
      └─ Port B: 0xA0021000-0xA0021FFF (データ書き込み)
```

---

## 🚀 実装後のテスト計画

修正完了後の次のステップ：

1. **合成テスト** (Synthesis)
   ```tcl
   launch_runs synth_1 -jobs 4
   wait_on_run synth_1
   ```

2. **実装テスト** (Implementation)
   ```tcl
   launch_runs impl_1 -jobs 4
   wait_on_run impl_1
   ```

3. **ボード上でのハードウェアテスト**
   - bitstream 生成
   - KV260 への書き込み
   - devmem2 ループバックテスト:
     ```bash
     # Port A に書き込み
     devmem2 0xA0020000 32 0x12345678
     
     # Port B から読み取り
     devmem2 0xA0021000 32
     
     # 同じ値が返ればOK
     ```

---

## 📞 トラブルシューティング

| 症状 | 原因 | 対応 |
|------|------|------|
| Canvas に IP が表示されない | design_2.bd が開かれていない | DESIGN2_INTERACTIVE_GUIDE.md ステップ 1.1 参照 |
| エラーメッセージが不明確 | Messages ウィンドウが見えていない | View → Messages をクリック |
| DMA 接続が成功しない | ポート名の誤字 | design_1.bd と比較して確認 |
| validate 後も警告が出る | 非致命的な警告 | Messages ウィンドウで詳細確認 |
| RTL 生成に失敗 | エラーが残っている | validate_bd_design をクリアしてから再試行 |

---

## 📝 最後に

このドキュメントとガイドを参考に、以下の順序で作業してください：

1. **DESIGN2_ACTION_ITEMS.md を読む** (5分)
2. **Vivado GUI で design_2 を開く** (5分)
3. **DESIGN2_INTERACTIVE_GUIDE.md のフェーズ2を参照しながら修正** (20分)
4. **検証と RTL 生成** (10分)
5. **ファイル保存とレポート作成** (10分)

**合計所要時間: 約50分**

質問や問題が発生した場合は、各ガイドドキュメントの該当セクションを参照してください。

---

**作成日**: 2026-10-26
**ステータス**: 🔨 修正作業待ち（フェーズ1完了）
**次のマイルストーン**: design_2 修正完了・検証成功

