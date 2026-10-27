# Design_2 ブロックデザイン - アクション項目

## 現況

✅ **完了**: design_2 ブロックデザインを TCL スクリプトで自動作成
⚠️ **状況**: 接続エラーが検出されており、修正が必要

---

## 🎯 推奨アクション（優先順）

### 【優先度1】直ちに実施（15分）

```
□ 1. Vivado GUI で design_2.bd をオープン
      Sources パネル → design_2 → 右クリック → Open Design
      
□ 2. Canvas でエラーを目視確認
      Messages ウィンドウを確認
      
□ 3. design_1.bd を参考にオープン
      File → Open Block Design → design_1.bd
      DMA → BRAM の接続パターンを確認
      
□ 4. design_2 で DMA 接続を追加
      DMA MM2S → BRAM Controller/S_AXI に接続
      DMA S2MM → BRAM Controller/S_AXI に接続
```

### 【優先度2】本日中に完了（45分）

```
□ 5. 残りのエラーを修正
      • Interconnect リセット入力接続
      • BRAM クロック接続整理
      • Stream 幅確認/修正
      
□ 6. validate_bd_design で検証
      Tools → Validate Design
      エラー: 0, 警告: 最小化
      
□ 7. RTL/XDC を再生成
      Design → Generate HDL Wrapper
      OR Tcl: generate_target all [get_files design_2.bd]
      
□ 8. update/ ディレクトリに保存
      hw_handoff/ から:
        - design_2_bd.v
        - design_2_bd.xdc
        - design_2_wrapper.v
      を update/ にコピー
```

### 【優先度3】ドキュメント完成（30分）

```
□ 9. 修正内容をレポートにまとめる
      rep/DESIGN2_MODIFICATION_REPORT.md を作成
      
□ 10. design_1 と design_2 の差分をまとめる
       主要変更点:
         - BRAM: 8K×1port → 4K×dual port
         - Clock: PS用400MHz逓倍追加
         - 外部ポート: clk_100m, resetn
```

---

## 📋 修正内容チェックリスト

### 接続エラー修正

- [ ] DMA M_AXI_MM2S 接続
- [ ] DMA M_AXI_S2MM 接続  
- [ ] Interconnect リセット入力接続
- [ ] BRAM クロック接続（重複削除）
- [ ] Stream データ幅確認
- [ ] PS割り込み接続確認

### 検証チェック

- [ ] validate_bd_design 実行
- [ ] エラーメッセージ: 0
- [ ] 警告: 非致命的のみ
- [ ] すべてのIPが Canvas に表示
- [ ] 接続線（赤いX）がない

### ファイル生成チェック

- [ ] design_2_bd.v 生成
- [ ] design_2_bd.xdc 生成
- [ ] design_2_wrapper.v 生成
- [ ] hw_handoff ディレクトリに格納

### ファイル保存チェック

- [ ] update/design_2_bd.v コピー
- [ ] update/design_2_bd.xdc コピー
- [ ] update/design_2_wrapper.v コピー
- [ ] update/design_2_merged.xdc コピー
- [ ] rep/ にレポート保存

---

## 参考ドキュメント

| ドキュメント | 用途 |
|------------|------|
| DESIGN2_INTERACTIVE_GUIDE.md | GUI での段階的修正手順 |
| DESIGN2_CREATION_GUIDE.md | IP ごとの詳細設定方法 |
| DESIGN2_FIXES.md | 技術的な修正説明 |
| DESIGN2_NEXT_STEPS.txt | 全体の進行ガイド |

---

## ⏱️ 予想所要時間

| 作業 | 時間 |
|------|------|
| デザイン2の GUI 修正 | 20分 |
| 検証・RTL 再生成 | 10分 |
| ファイル保存・レポート | 10分 |
| **合計** | **40分** |

---

## 🔗 関連ファイル

```
lab2/
├── create_design2_simple.tcl           ← すでに実行済み
├── DESIGN2_***.md/txt                  ← ガイド類
│
├── lab2.srcs/sources_1/bd/
│   ├── design_1/                       ← 参考用
│   │   └── design_1.bd
│   │
│   └── design_2/                       ← 修正対象
│       └── design_2.bd                 ← 今すぐ開く
│
├── update/                             ← 出力先
└── rep/                                ← レポート先
```

---

## ✅ 完了目標

**本日中に以下を達成:**

1. ✅ design_2.bd を完全に修正
2. ✅ validate_bd_design をクリア
3. ✅ RTL/XDC を再生成
4. ✅ update/ に保存
5. ✅ 修正レポート作成

**その後:**
- 合成・実装テスト
- ボード上でハードウェアテスト

---

## 💬 質問・トラブル時

| 症状 | 対応 |
|------|------|
| Canvas に IP が表示されない | DESIGN2_INTERACTIVE_GUIDE.md ステップ1.2 参照 |
| エラーメッセージが不明確 | Messages ウィンドウで詳細を右クリック → "Show Details" |
| DMA 接続方法が不明 | design_1.bd の DMA 接続を参照 |
| BRAM 設定が不確か | DESIGN2_CREATION_GUIDE.md セクション 2.5 参照 |

---

**最終確認: 修正が完了したら、各ガイドの「チェックリスト」セクションをすべて✅にしてください。**

