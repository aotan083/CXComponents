# TCPreview 設計書

作者: aotan083
日付: 2026-11-03
版: 1.1

---

## 1. 目的と方針

TCPreview は、TCsEditor の本文をプレビュー（Markdown は文書、それ以外は色分けしたコード）として表示し、印刷（PDF 保存）する部品である。エディタとは別の部品にして、フォームの好きな場所に置ける。

| No | 方針 |
|---|---|
| 1 | 中身は TCMonacoEditor のプレビュー（`TCMMarkdownPreview`・`preview\preview.html`）をそのまま使う。表示・Mermaid・印刷・リンク・画像の動きは TCMonacoEditor と同じ（`TCMonacoEditor_Design.md` 7章） |
| 2 | つなぎ方は、TCsEditor の `Preview` プロパティでこの部品を選ぶ。1 つの TCPreview を、複数の TCsEditor から選べる |
| 3 | 表示するのは「表示元」の TCsEditor の、見えているタブ。表示元は、最後にフォーカスされた TCsEditor（3章） |
| 4 | 表示・非表示は TCsEditor の `ShowPreview`（`Ctrl+Shift+V`）で行う。TCPreview の `Visible` を直接変えても同じになる |
| 5 | 設定の名前・既定値は TCMonacoEditor のプレビューの設定と同じ。頭の `Preview` は外す（`PreviewFontSize` → `FontSize` など） |
| 6 | `uCmdpreview.pas`・`preview.html` など、TCMonacoEditor のファイルは変えない |
| 7 | 動作環境：Lazarus 5.0 以降（テストは 5.0 RC1。TCsEditor と同じ）。Lazarus 4.8 は cx パッケージのコンパイルが通るだけで、動作の確認・テストはしない |

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `uCPreview.pas`（新しく作る） | cx（実行時） | `TCPreview` |
| `uCmdpreview.pas` | cx（実行時） | `TCMMarkdownPreview`（変えない。中で使う） |
| `uCXReg.pas` | cxdsgn（設計時） | `RegisterComponents('CX', [..., TCPreview, ...])` を足す |
| `cseditor_icon.lrs`（新しく作る） | cxdsgn（設計時） | アイコン（`TCPreview`・`_150`・`_200`。`TCsEditor_Design.md` 12章） |
| `preview\preview.html` と `preview\lib\` | 実行時のファイル | TCMonacoEditor と同じもの（変えない） |

- `uCPreview` の interface の uses：`Classes, SysUtils, Controls, Graphics, ExtCtrls, Forms, Dialogs, ucmdpreview, CMonacoPreview, uCmonacos`
- implementation の uses：`uCsEditor`（表示元を TCsEditor として扱うため。interface ではなく implementation で使うので、循環参照にならない）
- 型の使い回し：`TCMColorScheme`・`CMColorToHex`・色の既定値の定数（`DefPreview…`）は `uCmonacos`、`TCMSyncScroll` は `CMonacoPreview`、`TCMOpenMarkdownEvent` は `ucmdpreview` のものを使う（同じ型なので、TCMonacoEditor からの張り替えで書き方が変わらない）。
- アプリが `uCPreview` だけを uses すれば済むように、`TCMColorScheme`・`TCMSyncScroll` を型の別名で、`csEditor`・`csGitHub`・`ssNone`・`ssEditorToPreview`・`ssBoth` を定数で出し直す（`uCmonacos` と同じやり方）。
- cx の必要パッケージは今のまま（WebView4Delphi はすでに入っている）。

## 3. 表示元

### 3.1 決め方

| きっかけ | 表示元 | 表示 |
|---|---|---|
| TCsEditor の中のエディタがフォーカスを受けた（その TCsEditor の `Preview` がこの部品） | その TCsEditor | 違う TCsEditor に変わったときは、すぐに作り直す |
| 表示元の TCsEditor でタブを切り替えた | 変わらない | すぐに作り直す |
| 表示元の TCsEditor で本文が変わった | 変わらない | `DelayMs` 待って作り直す |
| 表示元でない TCsEditor で本文が変わった・タブを切り替えた | 変わらない | 何もしない |
| エディタ以外（ボタン・ツリーなど）をクリック | 変わらない | 何もしない |
| `ShowPreview := True`・`Ctrl+Shift+V`・`Print` を行った TCsEditor | その TCsEditor | すぐに作り直す |
| 表示元の TCsEditor が壊された、`Preview` を外した | なし | 空にする（`Clear`） |
| 表示元がまだない（起動直後） | `Preview` にこの部品を選んでいる TCsEditor のうち、最初に `OnReady` になったもの | すぐに作り直す |

### 3.2 表示元とのやり取り

TCsEditor は、次のメソッドでこの部品に知らせる（public。アプリは使わない）。

```pascal
procedure SetSource(ASource: TComponent);                   // 表示元にする。違う表示元なら、すぐに Refresh
procedure SourceChanged(ASource: TComponent);               // 本文が変わった。表示元なら DelayMs 待って Refresh
procedure SourceSwitched(ASource: TComponent);              // タブを切り替えた・言語やファイル名が変わった。表示元なら、すぐに Refresh
procedure SourceScrolled(ASource: TComponent; ALine: Double); // 表示している先頭の行が変わった。表示元なら 5.3
procedure SourceRemoved(ASource: TComponent);               // TCsEditor の Preview から外された。表示元なら空にする
procedure PrintFor(ASource: TComponent);                    // その TCsEditor を表示元にして印刷する（5.4）
```

- 表示元は `FSource: TComponent` に持つ。`FreeNotification` で、壊されたら `FSource := nil`・`Clear`。
- 表示元から読むもの（implementation で `TCsEditor(FSource)` として読む）：見えているタブの `Text`・`Language`・`FileName`・`Caption`、`Theme`、`TopLine`。
- 表示元へ頼むもの：スクロール（`TCsEditor.ScrollToLine`）、ファイルを開く（`TCsEditor.OpenFile`）。

## 4. 部品（TCPreview）

### 4.1 構成

```
TCPreview（TCustomPanel）
 └ プレビュー（TCMMarkdownPreview）  … 全面（alClient）。実行時だけ作る
```

- `Create`：`inherited` のあと、`csDesigning` でなければ（実行時だけ）中の `TCMMarkdownPreview` を作る（`Parent := Self`・`Align := alClient`）。設計時は作らない（WebView2 を起動しない）。
- 設計時は `Paint` で薄い枠と部品の名前を描く（TCMonacoEditor と同じ見た目）。
- 中の部品の WebView2 は、TCPreview が初めて表示されたときに作られる（`TCMMarkdownPreview` の今の動き）。一度も表示しなければ作らない。
- `BevelOuter := bvNone`、`Caption` は出さない（`ControlStyle` から `csSetCaption` を外す）。
- 既定の大きさ：`Width := 500`（TCMonacoEditor の `PreviewWidth` の既定）、`Height := 300`。

### 4.2 プロパティ

| 名前 | 型 | 既定値 | 公開 | 中で持つもの・渡し方 |
|---|---|---|---|---|
| `Splitter` | `TSplitter` | nil | published | 表示・非表示を合わせる境目（4.4）。`FreeNotification` |
| `FontSize` | `Integer` | 16 | published | 中の `FontSize`（8〜48 に収める） |
| `ColorScheme` | `TCMColorScheme` | `csEditor` | published | `FColorScheme` → 中の `ColorScheme`（`csEditor`→'editor'、`csGitHub`→'github'） |
| `BackColorLight` | `TColor` | `DefPreviewBackColorLight`（#FFFFFE） | published | `F…` に TColor のまま持ち、中の `BackColorLight` へ `CMColorToHex` で渡す |
| `BackColorDark` | `TColor` | `DefPreviewBackColorDark`（#1E1E1E） | published | 同上 |
| `TextColorLight` | `TColor` | `DefPreviewTextColorLight`（#000000） | published | 同上 |
| `TextColorDark` | `TColor` | `DefPreviewTextColorDark`（#D4D4D4） | published | 同上 |
| `LinkColorLight` | `TColor` | `DefPreviewLinkColorLight`（#006AB1） | published | 同上 |
| `LinkColorDark` | `TColor` | `DefPreviewLinkColorDark`（#3794FF） | published | 同上 |
| `BreakOnNewline` | `Boolean` | `False` | published | 中の同じ名前 |
| `AllowRemoteImages` | `Boolean` | `False` | published | 中の同じ名前 |
| `SyncScroll` | `TCMSyncScroll` | `ssBoth` | published | `FSyncScroll`（5.3） |
| `DelayMs` | `Integer` | 300 | published | `FTimer.Interval`（0 以下ならすぐ） |
| `PreviewPath` | `string` | '' | published | 中の `ResourcePath`（`TCMonacoEditor_Design.md` 6.1） |
| `Source` | `TComponent` | ― | public（読む） | 今の表示元（3章） |
| `Ready` | `Boolean` | ― | public（読む） | 中の `Ready`（中が無ければ `False`） |
| `Align`・`Anchors`・`BorderSpacing`・`Constraints`・`Enabled`・`Visible`・`Width`・`Height`・`TabOrder`・`TabStop` | | | published | LCL のまま |

- 設定は、中の部品ができる前（設計時・.lfm の読み込み中）も `F…` に持ち、中の部品を作ったとき（`Create` の最後と `Loaded`）にまとめて渡す（`ApplyAll`）。
- 中の部品の `Theme` は、表示元の `Theme` から決める（`ctAuto`→'auto'、`ctLight`→'vs'、`ctDark`→'vs-dark'）。表示元が無ければ 'auto'。'auto' のときは、OS のテーマの切り替えに `preview.html` が自分で合わせる（今の動き）。
- 色の 6 つは TCMonacoEditor の決まりと同じ（システム色は `ColorToRGB` で今の色にする。`clDefault`・`clNone` は既定値）。

### 4.3 イベント

| 名前 | 引数 | 中身 | 設定しないとき |
|---|---|---|---|
| `OnOpenMarkdown` | `Sender: TObject; const AFileName: string` | プレビューの `.md` へのリンクが押された | 表示元の TCsEditor で `OpenFile(AFileName)`（`MultiDocument` に従う）。表示元が無ければ何もしない |
| `OnError` | `Sender: TObject; const AMessage: string` | プレビューのエラー（preview.html が見つからない、WebView2 の準備ができない など） | メッセージを表示する。同じメッセージは起動中に 1 回だけ（TCMonacoEditor と同じ。表示済みの一覧は `uCPreview` の中に持つ） |
| `OnReady`・`OnClick` など | | 出さない | ― |

- 中の部品の `OnOpenMarkdown`・`OnError`・`OnScrollLine`・`OnReady`・`OnPrintKey`・`OnAfterPrint`・`OnFontSizeChange` は、TCPreview がつなぐ。

### 4.4 表示・非表示と境目（Splitter）

- `Visible` を変えたとき（`VisibleChanged`）、`Splitter` があれば `Splitter.Visible` も同じにする。
- 表示するときは、境目がプレビューの隣に来るように並べ直す：`Align` が `alRight` なら `Splitter.Left := Left - Splitter.Width`、`alLeft` なら `Splitter.Left := Left + Width`、`alBottom` なら `Splitter.Top := Top - Splitter.Height`、`alTop` なら `Splitter.Top := Top + Height`（LCL の TSplitter は、隣の部品を位置で決めるため）。
- 表示したとき、表示元があれば `Refresh`（隠れている間の変更を反映する）。
- TCsEditor の `ShowPreview` は、この部品の `Visible` を読み書きする（`TCsEditor_Design.md` 9章）。
- 境目の色：`Splitter` の `Color` を、表示元の Theme に合わせて付ける（TCMonacoEditor の中の境目と同じ色。ダーク #2B2B2B、ライト #E5E5E5）。ダークかどうかは表示元の TCsEditor に聞く（`ctAuto` なら OS の設定）。表示元が無ければ OS の設定。付けるのは、`Splitter` を選んだとき・表示元が変わったとき・`SourceSwitched`（配色を変えたときも来る）。アプリが付けた色は上書きする。

## 5. 処理

### 5.1 作り直す（Refresh）

TCMonacoEditor の `TCMPreviewBinder.Refresh` と同じ。

1. `FTimer.Enabled := False`。中の部品が無い（設計時）なら終わる。
2. 表示元が無ければ `Clear` して終わる。
3. 中の `Theme` を表示元に合わせる（4.2）。
4. `DocTitle`：見えているタブの `Caption` から拡張子を外したもの（`abc.md` → `abc`、無題 → 無題）。印刷の PDF の名前になる。
5. 言語が 'markdown' なら `ShowMarkdown(Text, ExtractFilePath(FileName))`、それ以外は `ShowCode(Text, Language)`。
6. `SetTopLine(表示元の TopLine)`。

- 隠れている間（`not Visible`）は作り直さず、`FDirty := True` だけにする。表示したときに作り直す（4.4）。印刷のときは 5.4 で表示してから作り直す。

### 5.2 待ってから作り直す（SourceChanged）

- 表示元からの知らせなら、`DelayMs > 0` なら `FTimer` を止めて動かし直す（入力が続く間は待つ）。`DelayMs <= 0` なら、すぐに `Refresh`。
- 表示元でない TCsEditor からの知らせは無視する。

### 5.3 スクロールを合わせる

| 向き | 処理 |
|---|---|
| エディタ → プレビュー（`SourceScrolled`） | 表示元から、`SyncScroll <> ssNone`、抑えている間（下）でなければ、中の `SetTopLine(ALine)` |
| プレビュー → エディタ（中の `OnScrollLine`） | `SyncScroll = ssBoth` で表示元があれば、表示元の `ScrollToLine(Line)`。そのあと 300 ミリ秒、エディタからの知らせを抑える（`FSuppressUntil := GetTickCount64 + 300`） |

- 抑える理由：エディタを動かすと、エディタがまたプレビューへ知らせ、互いに反応し合ってふらつくため（TCMonacoEditor と同じ考え方）。
- エディタの行は、行の中の位置を持たない（`TopLine` は整数。`TCsEditor_Design.md` 6.6）。プレビューは、その行のブロックの先頭に合わせる。

### 5.4 印刷（PrintFor・Print）

TCMonacoEditor の 7.3 と同じ流れ。

1. `PrintFor(ASource)`：`SetSource(ASource)`。中の部品が無ければ終わる。
2. 隠れていれば `FShownForPrint := True`、`Visible := True`（4.4 で境目も出る）。印刷の間だけ出す（画面に出さない WebView2 では印刷が正しく動く保証がないため）。
3. `Refresh`（今の本文で作り直す）。
4. 中の `Print`（中の部品が、準備ができるのを待ってから、Mermaid の印刷用の図を作り、印刷ダイアログを出す）。
5. 中の `OnAfterPrint` で、`FShownForPrint` なら `Visible := False`・`FShownForPrint := False`。知らせが来なければ、出したまま。

- `Print`（public。引数なし）：今の表示元で `PrintFor`。表示元が無ければ何もしない。
- 中の `OnPrintKey`（プレビューにフォーカスがあって `Ctrl+P`）と、プレビューの右クリックの「印刷...」：`Print`。
- 印刷するのは表示元の見えているタブ。画面がダークでも白い背景・黒い文字になる（`preview.html` の `@media print`。変えない）。

### 5.5 ファイルを開く・エラー

- 中の `OnOpenMarkdown` → `QueueAsyncCall` で、`OnOpenMarkdown` があれば呼ぶ。無ければ表示元の `OpenFile`（中の部品の知らせの途中でダイアログを出さないため。`TCMonacoEditor_Design.md` 5.4）。
- 中の `OnError` → `OnError` があれば呼ぶ。無ければ `QueueAsyncCall` でメッセージを出す（同じメッセージは 1 回だけ）。

### 5.6 フォント

- プレビューで `Ctrl+ホイール` を回すと、中の部品が文字の大きさを変えて `OnFontSizeChange` を出す。そのとき `FFontSize` を中の値に合わせる（オブジェクトインスペクタの値とずれないように。実行中だけ）。

## 6. 決めていること

| 項目 | 決定 |
|---|---|
| 部品の形 | エディタとは別の部品。フォームの好きな場所に置く。境目（TSplitter）はアプリが置き、`Splitter` で選ぶ |
| つなぎ方 | TCsEditor の `Preview` で選ぶ。TCPreview 側には、つなぐ先のプロパティを持たない |
| 共有 | 1 つの TCPreview を複数の TCsEditor から選べる。表示するのは表示元（最後にフォーカスされた TCsEditor）の見えているタブ |
| 表示・非表示 | TCsEditor の `ShowPreview`。同じ TCPreview を選んだ TCsEditor の間で共通 |
| 中身 | `TCMMarkdownPreview` と `preview.html` を変えずに使う |
| 名前 | TCMonacoEditor のプレビューの設定の頭の `Preview` を外す。`PreviewPath` はそのまま（WebView2.ini の `PreviewFolder` と対になるため） |
| 印刷 | 表示元の見えているタブを、Edge の印刷ダイアログで印刷（PDF 保存も）。隠れていれば印刷の間だけ出す |
| 張り替え | TCMonacoEditor の `ShowPreview` は TCsEditor の `ShowPreview` で同じ書き方。プレビューの設定は `ed.Preview.〜` |

**作らないもの**

| 項目 | 理由・代わり |
|---|---|
| `Editor` プロパティ（TCPreview から TCsEditor を選ぶ） | つなぎ方は TCsEditor の `Preview` に一本化する |
| `PreviewWidth`・`SplitterResizeStyle`・`SplitterWidth` | TCPreview の `Width`、アプリが置く TSplitter の設定 |
| 行の中の位置までのスクロールの同期 | SynEdit の `TopLine` は整数のため |
| TCMonacoEditor をつなぐこと | 今回はしない |

## 7. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| 何も表示されない | 表示元（3.1）。`TCsEditor.Preview` にこの部品が入っているか。`Visible`。`preview.html` の場所（`PreviewPath`・WebView2.ini） |
| 別のエディタの内容が出ない | 中のエディタの `DoEnter` から `SetSource` が呼ばれているか（`TCsEditor_Design.md` 9章） |
| 入力しても更新されない | `SourceChanged` が表示元から来ているか。`DelayMs`。隠れている間は作り直さない（5.1） |
| 境目が残る・離れた所に出る | `Splitter` の設定と並べ直し（4.4） |
| 境目の色が配色と合わない | 4.4 の境目の色（`SourceSwitched` で付け直しているか） |
| スクロールがふらつく | 300 ミリ秒の抑え（5.3） |
| 印刷のあとプレビューが出たまま | `OnAfterPrint` が来たか（5.4）。来なければ出したままになる（TCMonacoEditor と同じ） |
| ダイアログで固まる | 中の部品の知らせの途中でダイアログを出していないか（5.5） |
| 設計時に WebView2 が動く | `Create` の `csDesigning` の判定（4.1） |

## 8. この版の変更（1.0。新しく作る）

コードを作るための手順。取説には入れない。

| No | ファイル | 変更 |
|---|---|---|
| 1 | `uCPreview.pas` | 新しく作る（この設計書のすべて） |
| 2 | `cx.lpk` | `../source/uCPreview.pas`（UnitName `uCPreview`）を足す |
| 3 | `uCXReg.pas` | uses に `uCPreview`、`RegisterComponents('CX', [...])` に `TCPreview` を足す |
| 4 | `cseditor_icon.lrs`・`cxdsgn.lpk` | アイコン（`TCsEditor_Design.md` 12章） |
| 5 | `uCmdpreview.pas`・`CMonacoPreview.pas`・`uCmonacos.pas`・`preview.html` | 変更なし |

**1.1（2026-11-03）**

| No | 章 | 1.0 | 1.1 | 理由 |
|---|---|---|---|---|
| 1 | 4.4 | `Splitter` の色は付けない | 表示元の Theme に合わせて付ける | Theme を変えても境目の色が変わらなかった |
