# TCSynEdit 取扱説明書

作者: aotan083
日付: 2026-10-29
版: 1.0

---

## 1. 概要とクラス

SynEdit をもとにした、テキストエディタの部品です。TSynEdit の機能はそのまま使え、ファイルの読み書き、配色の切り替え、秀丸エディタに似た右クリックメニュー、状態の変化を知らせるイベントなどを加えています。

- ファイル名の拡張子に合わせて、色分け（ハイライター）を自動で切り替える。
- 配色を、黒・灰・白・Windows のテーマに合わせる、の4つから選べる。
- ファイルをドロップすると開く。
- Ctrl+S で上書き保存、Ctrl+マウスホイールで文字の大きさを変えられる。

| 項目 | 内容 |
|---|---|
| Lazarus | 4.8 5.0RC1 |
| FPC | 3.2.2 |
| OS | Windows 11（64 ビット） |
| パレット | CX |
| 使う外部パッケージ | SynEdit（Lazarus に入っている） |

### 1.1 クラスとユニット

| クラス | ユニット | パッケージ | 元のクラス | 中身 |
|---|---|---|---|---|
| `TCSynEdit` | `cSynEdit` | cx | `TSynEdit`（SynEdit） | SynEdit をもとにしたテキストエディタ。ファイルの読み書き、配色の切り替え、秀丸エディタに似た右クリックメニュー、状態の変化を知らせるイベントを足したもの |

| 型 | ユニット | 中身 |
|---|---|---|
| `TCEditStyle` | `cSynEdit` | 配色。`csBlack`・`csGray`・`csWhite`・`csThema`（3章） |
| `TCFileEncoding` | `cSynEdit` | 文字コードの種類。`feUTF8`・`feANSI_SJIS`・`feUTF16LE`・`feUTF16BE`・`feEUCJP` |
| `TCLineEnding` | `cSynEdit` | 改行コードの種類。`leCRLF`・`leLF`・`leCR` |
| `TCSynTextChangeEvent` | `cSynEdit` | `procedure(Sender: TObject; const AText: string) of object`。`OnTextChange` の型 |
| `TOnFileNameChangeEvent` | `cSynEdit` | `procedure(Sender: TObject; var sFileName: String) of object`。`OnFileNameChangeEvent` の型 |
| `TOnLoadFromFileEvent` | `cSynEdit` | `procedure(Sender: TObject; var sFileName: String) of object`。`OnLoadFromFileEvent` の型 |
| `TOnSaveToFileEvent` | `cSynEdit` | `procedure(Sender: TObject; var sFileName: String) of object`。`OnSaveToFileEvent` の型 |
| `TOnInsModeChangeEvent` | `cSynEdit` | `procedure(Sender: TObject; var bMode: Boolean) of object`。`OnInsModeChangeEvent` の型 |
| `TOnCaretChangeEvent` | `cSynEdit` | `procedure(Sender: TObject; var iX, iY: Integer) of object`。`OnCaretChangeEvent` の型 |
| `TOnUndoRedoStateChangeEvent` | `cSynEdit` | `procedure(Sender: TObject; var bCanUndo, bCanRedo: Boolean) of object`。`OnUndoRedoStateChangeEvent` の型 |
| `TOnModifiedChangeEvent` | `cSynEdit` | `procedure(Sender: TObject; var bModified: Boolean) of object`。`OnModifiedChangeEvent` の型 |
| `TOnSelectionChangeEvent` | `cSynEdit` | `procedure(Sender: TObject; var sSelText: String; var iStartX, iStartY, iEndX, iEndY: Integer) of object`。`OnSelectionChangeEvent` の型 |
| `TOnFocusChangeEvent` | `cSynEdit` | `procedure(Sender: TObject; var bFocused: Boolean) of object`。`OnFocusChangeEvent` の型 |
| `TOnDropFilesEvent` | `cSynEdit` | `procedure(Sender: TObject; const AFiles: array of string) of object`。`OnDropFilesEvent` の型 |

- フォームに置くと、uses に `cSynEdit` が自動で入る。
- フォームに置くと、プロジェクトの必要パッケージに cx が自動で追加される。
- コードで作るときは、uses に自分で書く。

## 2. フォームに置いて動かすまで

1. パレット [CX] から、TCSynEdit をフォームに置く。
2. オブジェクトインスペクタの `EditStyle` で配色を選ぶ（既定値は `csGray`）。
3. ファイルを開くボタンを置き、`OnClick` に `CSynEdit1.LoadFromFile(ファイル名)` を書く（9.1）。
4. ファイル名をタイトルに出すときは、イベントタブの `OnFileNameChangeEvent` をダブルクリックして処理を書く（9.2）。
5. 実行する。ファイルをドロップすると開き、Ctrl+S で上書き保存する。

**最初の状態**

| 項目 | 値 |
|---|---|
| フォント | BIZ UDGothic、12 ポイント |
| 配色（`EditStyle`） | `csGray` |
| 色分け | Pascal |
| `FileName` | 実行ファイルのフォルダー ＋「無題.txt」 |
| 挿入・上書き | 挿入 |
| 右クリックメニュー | 部品が持つメニュー（8.3） |

- 最初のフォントは BIZ UDGothic。入っていない環境では、`Font` を設定する。

## 3. 配色（EditStyle）

| 値 | 背景 | 文字 | 中身 |
|---|---|---|---|
| `csBlack` | 黒 | 白 | 黒の配色 |
| `csGray` | 黒 | 白 | 黒の配色。行番号は 5 行ごとに表示（既定値） |
| `csWhite` | 白 | 黒 | 白の配色 |
| `csThema` | システム色 | システム色 | Windows のテーマ（ダーク・ライト）に合わせる。MetaDarkStyle などと組み合わせて使う |

- 予約語・文字列・コメント・数値などの色分けの配色は、Pascal の色分けのときだけ、配色に合わせて変わる。
- どの配色でも、左端のブックマークの欄は出さない。行番号の欄は出す（F12 で切り替え）。
- 右端の 80 桁のガイド線は、背景と同じ色にしているため見えない。

## 4. 色分け（ハイライター）

`FileName` を設定したとき（`LoadFromFile`・`SaveToFile` を含む）、拡張子に合わせて色分けを切り替える。

| 拡張子 | 色分け |
|---|---|
| .pas、.pp、.lpr、.dpr、.txt、拡張子なし | Pascal |
| .html、.htm、.md、.markdown、.json、.csv、.yaml、.yml | HTML |
| .xml | XML |
| 上のほか | 切り替えない（それまでの色分けのまま） |

## 5. プロパティ

### 5.1 この部品で足したもの・動きを変えたもの

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `FileName` | `string` | 読み・書き | 編集中のファイル名（既定値は、実行ファイルのフォルダー ＋「無題.txt」）。書くと `OnFileNameChangeEvent` を出し、拡張子に合わせて色分けを切り替える |
| `DisplayTitle` | `string` | 読み | タブなどに出す短い名前（`FileName` のファイル名の部分。空なら「無題.txt」）。実行時だけ |
| `EditStyle` | `TCEditStyle` | 読み・書き | 配色（3章）。既定値は `csGray` |
| `InsMode` | `Boolean` | 読み・書き | `True`（既定値）：挿入。`False`：上書き |
| `CaretX` | `Integer` | 読み・書き | カーソルの桁（1 から） |
| `CaretY` | `Integer` | 読み・書き | カーソルの行（1 から） |
| `EncodingType` | `TCFileEncoding` | 読み・書き | 文字コードを覚えておく入れ物（既定値は `feUTF8`）。読み書きには使われない |
| `HasBOM` | `Boolean` | 読み・書き | BOM の有無を覚えておく入れ物（既定値は `False`）。読み書きには使われない |
| `LineEndingType` | `TCLineEnding` | 読み・書き | 改行コードを覚えておく入れ物（既定値は `leCRLF`）。読み書きには使われない |

- `EncodingType`・`HasBOM`・`LineEndingType` は、アプリが文字コードや改行コードを覚えておくためのもの。`LoadFromFile`・`SaveToFile` はこの値を見ない（文字コードは変換しない）。

### 5.2 TSynEdit から引き継いだもの

| 名前 | 型 | 読み書き | 中身 |
|---|---|---|---|
| `Align` | `TAlign` | 読み・書き | 親の中での配置 |
| `Anchors` | `TAnchors` | 読み・書き | 親の大きさが変わったときに、どの辺を合わせて動くか |
| `AnchorSideBottom` | `TAnchorSide` | 読み・書き | 下の辺を、どの部品のどこに合わせるか |
| `AnchorSideLeft` | `TAnchorSide` | 読み・書き | 左の辺を、どの部品のどこに合わせるか |
| `AnchorSideRight` | `TAnchorSide` | 読み・書き | 右の辺を、どの部品のどこに合わせるか |
| `AnchorSideTop` | `TAnchorSide` | 読み・書き | 上の辺を、どの部品のどこに合わせるか |
| `Beautifier` | `TSynCustomBeautifier` | 読み・書き | 改行したときの字下げのしかた |
| `BlockIndent` | `Integer` | 読み・書き | ブロックの字下げの幅 |
| `BlockTabIndent` | `Integer` | 読み・書き | ブロックの字下げに使うタブの数 |
| `BookMarkOptions` | `TSynBookMarkOpt` | 読み・書き | ブックマークの設定 |
| `BorderSpacing` | `TControlBorderSpacing` | 読み・書き | 周りの余白 |
| `BorderStyle` | `TBorderStyle` | 読み・書き | 枠の線を出すか（既定値は `bsSingle`） |
| `BracketHighlightStyle` | `TSynEditBracketHighlightStyle` | 読み・書き | 対応する括弧の強調のしかた |
| `BracketMatchColor` | `TSynSelectedColor` | 読み・書き | 対応する括弧の色 |
| `Color` | `TColor` | 読み・書き | 背景色。`EditStyle` を変えると、配色の色で上書きされる |
| `Constraints` | `TSizeConstraints` | 読み・書き | 大きさの上限・下限 |
| `Cursor` | `TCursor` | 読み・書き | 文字の上に来たときのマウスカーソル（既定値は `crIBeam`） |
| `DefaultSelectionMode` | `TSynSelectionMode` | 読み・書き | 選択のしかたの既定値（通常・行・矩形） |
| `Enabled` | `Boolean` | 読み・書き | 使えるか |
| `ExtraCharSpacing` | `Integer` | 読み・書き | 文字の間に足す幅 |
| `ExtraLineSpacing` | `Integer` | 読み・書き | 行の間に足す幅 |
| `FoldedCodeColor` | `TSynSelectedColor` | 読み・書き | 折りたたんだ所の色 |
| `Font` | `TFont` | 読み・書き | 文字（既定値は BIZ UDGothic、12 ポイント） |
| `Gutter` | `TSynGutter` | 読み・書き | 左端の欄（行番号など）。`EditStyle` を変えると、色と表示が上書きされる |
| `Height` | `Integer` | 読み・書き | 高さ |
| `HelpContext` | `THelpContext` | 読み・書き | ヘルプの番号 |
| `HelpKeyword` | `string` | 読み・書き | ヘルプのキーワード |
| `HelpType` | `THelpType` | 読み・書き | ヘルプを番号で引くか（`htContext`）、キーワードで引くか（`htKeyword`） |
| `HideSelection` | `Boolean` | 読み・書き | フォーカスがないときに、選択の色を消すか |
| `HighlightAllColor` | `TSynSelectedColor` | 読み・書き | 同じ文字列をすべて強調するときの色 |
| `Highlighter` | `TSynCustomHighlighter` | 読み・書き | 色分け。`FileName` を設定すると、4章のとおり切り替わる |
| `Hint` | `TTranslateString` | 読み・書き | ヒントの文字 |
| `IncrementColor` | `TSynSelectedColor` | 読み・書き | インクリメンタル検索で見つかった所の色 |
| `InsertCaret` | `TSynEditCaretType` | 読み・書き | 挿入のときのカーソルの形 |
| `InsertMode` | `Boolean` | 読み・書き | 挿入か上書きか（`InsMode` と同じ） |
| `Keystrokes` | `TSynEditKeyStrokes` | 読み・書き | キーと動作の割り当て |
| `Left` | `Integer` | 読み・書き | 左端の位置 |
| `LineHighlightColor` | `TSynSelectedColor` | 読み・書き | カーソル行の色。`EditStyle` を変えると上書きされる |
| `Lines` | `TStrings` | 読み・書き | 本文（行ごと） |
| `MaxLeftChar` | `Integer` | 読み・書き | 1行の最大の桁数 |
| `MaxUndo` | `Integer` | 読み・書き | 元に戻せる回数 |
| `MouseActions` | `TSynEditMouseActions` | 読み・書き | マウスの操作と動作の割り当て |
| `MouseLinkColor` | `TSynSelectedColor` | 読み・書き | リンクの色 |
| `MouseOptions` | `TSynEditorMouseOptions` | 読み・書き | マウスの動きの設定 |
| `MouseSelActions` | `TSynEditMouseActions` | 読み・書き | 選択の上でのマウスの操作と動作の割り当て |
| `MouseTextActions` | `TSynEditMouseActions` | 読み・書き | 文字の上でのマウスの操作と動作の割り当て |
| `Name` | `TComponentName` | 読み・書き | 部品の名前 |
| `OffTextCursor` | `TCursor` | 読み・書き | 文字の外（左端の欄など）に来たときのマウスカーソル |
| `Options` | `TSynEditorOptions` | 読み・書き | 動きと見た目の設定 |
| `Options2` | `TSynEditorOptions2` | 読み・書き | 動きと見た目の設定（続き） |
| `OverwriteCaret` | `TSynEditCaretType` | 読み・書き | 上書きのときのカーソルの形 |
| `ParentColor` | `Boolean` | 読み・書き | 親の色を使うか |
| `ParentFont` | `Boolean` | 読み・書き | 親の `Font` を使うか |
| `ParentShowHint` | `Boolean` | 読み・書き | 親の `ShowHint` を使うか |
| `PopupMenu` | `TPopupMenu` | 読み・書き | 右クリックメニュー。最初は部品のメニュー（8.3）。自分のメニューを入れると、そちらが出る |
| `ReadOnly` | `Boolean` | 読み・書き | `True` で編集できない |
| `RightEdge` | `Integer` | 読み・書き | 右端のガイド線の桁。`EditStyle` を変えると上書きされる |
| `RightEdgeColor` | `TColor` | 読み・書き | 右端のガイド線の色。`EditStyle` を変えると上書きされる |
| `RightGutter` | `TSynGutter` | 読み・書き | 右端の欄 |
| `ScrollBars` | `TScrollStyle` | 読み・書き | スクロールバーの出し方 |
| `ScrollOnEditLeftOptions` | `TSynScrollOnEditOptions` | 読み・書き | 入力でカーソルが左端を越えたときのスクロールのしかた |
| `ScrollOnEditRightOptions` | `TSynScrollOnEditOptions` | 読み・書き | 入力でカーソルが右端を越えたときのスクロールのしかた |
| `SelectedColor` | `TSynSelectedColor` | 読み・書き | 選択の色。`EditStyle` を変えると上書きされる |
| `SelectionMode` | `TSynSelectionMode` | 読み・書き | 今の選択のしかた（通常・行・矩形） |
| `ShowHint` | `Boolean` | 読み・書き | ヒントを出すか |
| `TabOrder` | `TTabOrder` | 読み・書き | Tab キーで移る順番 |
| `TabStop` | `Boolean` | 読み・書き | Tab キーで止まるか（既定値は `True`） |
| `TabWidth` | `Integer` | 読み・書き | タブの幅 |
| `Tag` | `PtrInt` | 読み・書き | アプリが自由に使える数値 |
| `Top` | `Integer` | 読み・書き | 上端の位置 |
| `Visible` | `Boolean` | 読み・書き | 表示するか |
| `VisibleSpecialChars` | `TSynVisibleSpecialChars` | 読み・書き | 空白・タブ・改行を記号で見せるときの対象 |
| `WantTabs` | `Boolean` | 読み・書き | Tab キーでタブを入力するか（`False` なら次の部品へ移る） |
| `Width` | `Integer` | 読み・書き | 幅 |

## 6. メソッド

### 6.1 ファイル

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `Create` | `AOwner: TComponent` | ― | 作る。コードで作るときに使う（9.9） |
| `LoadFromFile` | `const AFileName: string` | ― | ファイルを読み込む。`FileName` を設定し、`Modified` を `False` にして、`OnLoadFromFileEvent` を出す |
| `SaveToFile` | `const AFileName: string` | ― | ファイルに書き込む。`FileName` を設定し、`Modified` を `False` にして、`OnSaveToFileEvent` を出す |
| `Save` | ― | ― | `FileName` に上書き保存する（Ctrl+S と同じ） |

- 開いた・保存したファイルは、ほかのアプリから書き込めないように押さえる（読むことはできる）。別のファイルを開くか、部品を破棄すると放す。

### 6.2 編集

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `InsertTextAtCaret` | `const AText: string` | ― | カーソルの位置に文字列を入れる（'' なら何もしない） |
| `ReplaceSelection` | `const AText: string` | ― | 選んでいる文字列を置き換える（選んでいなければカーソルの位置に入れる） |
| `SetCaretPosition` | `const AX, AY: Integer` | ― | カーソルをその桁・行へ動かす（範囲の外は、いちばん近い位置にする） |
| `SelectLine` | `const ALineIndex: Integer` | ― | その行（1 から）を選ぶ |
| `SelectRange` | `const AStartX, AStartY, AEndX, AEndY: Integer` | ― | その範囲（桁・行は 1 から）を選ぶ |
| `DuplicateCurrentLine` | ― | ― | カーソルの行を複製して、下に入れる（Shift+F10 と同じ） |
| `ToggleLineNumbers` | ― | ― | 行番号の表示・非表示を切り替える（F12 と同じ） |

### 6.3 検索・置換

| 名前 | 引数 | 戻り値 | 中身 |
|---|---|---|---|
| `SearchText` | `const ASearchStr: string; ACaseSensitive, AWholeWord, AForward: Boolean` | `Boolean` | 探して選ぶ。見つかれば `True`。`ACaseSensitive`：大文字と小文字を区別する。`AWholeWord`：単語単位。`AForward`：`True` で下へ、`False` で上へ |
| `ReplaceText` | `const ASearchStr, AReplaceStr: string; ACaseSensitive, AWholeWord: Boolean` | `Boolean` | 次に見つかった1つを置き換える。置き換えたら `True` |
| `ReplaceAllText` | `const ASearchStr, AReplaceStr: string; ACaseSensitive, AWholeWord: Boolean` | `Integer` | 本文全体をすべて置き換え、置き換えた数を返す |

## 7. イベント

### 7.1 この部品で足したもの

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnTextChange` | `Sender: TObject; const AText: string` | 本文・カーソル・選択などの状態が変わった。`AText` は本文全体（プレビューとの連携用） |
| `OnFileNameChangeEvent` | `Sender: TObject; var sFileName: String` | `FileName` が変わった。`sFileName` を変えると、その値が `FileName` になる |
| `OnLoadFromFileEvent` | `Sender: TObject; var sFileName: String` | `LoadFromFile` が終わった。`sFileName` を変えると、その値が `FileName` になる |
| `OnSaveToFileEvent` | `Sender: TObject; var sFileName: String` | `SaveToFile`・`Save` が終わった。`sFileName` を変えると、その値が `FileName` になる |
| `OnInsModeChangeEvent` | `Sender: TObject; var bMode: Boolean` | 挿入・上書きが切り替わった（Insert キーを含む）。`bMode` は `True` で挿入。変えると、その状態になる |
| `OnCaretChangeEvent` | `Sender: TObject; var iX, iY: Integer` | カーソルが動いた。`iX` は桁、`iY` は行。変えると、その位置にカーソルが動く |
| `OnUndoRedoStateChangeEvent` | `Sender: TObject; var bCanUndo, bCanRedo: Boolean` | 元に戻す・やり直しができるかが変わった（引数を変えても部品には反映されない） |
| `OnModifiedChangeEvent` | `Sender: TObject; var bModified: Boolean` | 変更あり・なしが切り替わった。`bModified` を変えると、その値が `Modified` になる |
| `OnSelectionChangeEvent` | `Sender: TObject; var sSelText: String; var iStartX, iStartY, iEndX, iEndY: Integer` | 選んでいる文字列が変わった（引数を変えても部品には反映されない） |
| `OnFocusChangeEvent` | `Sender: TObject; var bFocused: Boolean` | フォーカスが変わった。`bFocused` は `True` で得た、`False` で失った（引数を変えても部品には反映されない） |
| `OnDropFilesEvent` | `Sender: TObject; const AFiles: array of string` | ファイルがドロップされた。`AFiles` はフルパス。これを設定すると、ファイルを開かずにイベントだけを出す（設定していないときは、最初のファイルを `LoadFromFile` で開く） |

### 7.2 TSynEdit から引き継いだもの

| 名前 | 引数 | 中身 |
|---|---|---|
| `OnChange` | `Sender: TObject` | 本文が変わった |
| `OnChangeUpdating` | `ASender: TObject; AnUpdating: Boolean` | まとめての変更が始まった・終わった |
| `OnClearBookmark` | `Sender: TObject; var Mark: TSynEditMark` | ブックマークを消す前 |
| `OnClick` | `Sender: TObject` | クリックされた |
| `OnClickLink` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | リンクがクリックされた |
| `OnCommandProcessed` | `Sender: TObject; var Command: TSynEditorCommand; var AChar: TUTF8Char; Data: Pointer` | 編集の命令を行った後 |
| `OnContextPopup` | `Sender: TObject; MousePos: TPoint; var Handled: Boolean` | 右クリックメニューを出す直前。`Handled := True` で出さない |
| `OnCutCopy` | `Sender: TObject; var AText: String; var AMode: TSynSelectionMode; ALogStartPos: TPoint; var AnAction: TSynCopyPasteAction` | 切り取り・コピーの前。`AText` を変えられる |
| `OnDblClick` | `Sender: TObject` | ダブルクリックされた |
| `OnDragDrop` | `Sender, Source: TObject; X, Y: Integer` | LCL のドラッグ（アプリの中の部品どうし）でドロップされた |
| `OnDragOver` | `Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean` | LCL のドラッグで、ドラッグしている物が上に来た。`Accept` で受けるかを決める |
| `OnEndDock` | `Sender, Target: TObject; X, Y: Integer` | ドッキングが終わった |
| `OnEndDrag` | `Sender, Target: TObject; X, Y: Integer` | LCL のドラッグが終わった |
| `OnEnter` | `Sender: TObject` | フォーカスが入った |
| `OnExit` | `Sender: TObject` | フォーカスが出た |
| `OnGutterClick` | `Sender: TObject; X, Y, Line: Integer; Mark: TSynEditMark` | 左端の欄がクリックされた |
| `OnKeyDown` | `Sender: TObject; var Key: Word; Shift: TShiftState` | キーが押された |
| `OnKeyPress` | `Sender: TObject; var Key: Char` | 文字のキーが押された |
| `OnKeyUp` | `Sender: TObject; var Key: Word; Shift: TShiftState` | キーが離された |
| `OnMouseDown` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | マウスのボタンが押された |
| `OnMouseEnter` | `Sender: TObject` | マウスが上に入った |
| `OnMouseLeave` | `Sender: TObject` | マウスが外に出た |
| `OnMouseLink` | `Sender: TObject; X, Y: Integer; var AllowMouseLink: Boolean` | マウスの下の文字をリンクにするかを決めるとき |
| `OnMouseMove` | `Sender: TObject; Shift: TShiftState; X, Y: Integer` | マウスが動いた |
| `OnMouseUp` | `Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer` | マウスのボタンが離された |
| `OnMouseWheel` | `Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean` | ホイールが回された |
| `OnMouseWheelDown` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | ホイールが手前に回された |
| `OnMouseWheelUp` | `Sender: TObject; Shift: TShiftState; MousePos: TPoint; var Handled: Boolean` | ホイールが奥に回された |
| `OnPaint` | `Sender: TObject; ACanvas: TCanvas` | 描いた後 |
| `OnPaste` | `Sender: TObject; var AText: String; var AMode: TSynSelectionMode; ALogStartPos: TPoint; var AnAction: TSynCopyPasteAction` | 貼り付けの前。`AText` を変えられる |
| `OnPlaceBookmark` | `Sender: TObject; var Mark: TSynEditMark` | ブックマークを置く前 |
| `OnProcessCommand` | `Sender: TObject; var Command: TSynEditorCommand; var AChar: TUTF8Char; Data: Pointer` | 編集の命令を行う前。`Command` を変えられる |
| `OnProcessUserCommand` | `Sender: TObject; var Command: TSynEditorCommand; var AChar: TUTF8Char; Data: Pointer` | アプリで決めた命令を行うとき |
| `OnQuadClick` | `Sender: TObject` | 4回続けてクリックされた |
| `OnReplaceText` | `Sender: TObject; const ASearch, AReplace: string; Line, Column: Integer; var ReplaceAction: TSynReplaceAction` | 置換するかを決めるとき |
| `OnResize` | `Sender: TObject` | 大きさが変わった |
| `OnShowHint` | `Sender: TObject; HintInfo: PHintInfo` | ヒントを出す直前 |
| `OnSpecialLineMarkup` | `Sender: TObject; Line: Integer; var Special: Boolean; Markup: TSynSelectedColor` | 行に特別な色を付けるかを決めるとき |
| `OnStartDock` | `Sender: TObject; var DragObject: TDragDockObject` | ドッキングのドラッグを始めた |
| `OnStartDrag` | `Sender: TObject; var DragObject: TDragObject` | LCL のドラッグを始めた |
| `OnStatusChange` | `Sender: TObject; Changes: TSynStatusChanges` | カーソル・選択・変更あり・挿入と上書きなどの状態が変わった |
| `OnTripleClick` | `Sender: TObject` | 3回続けてクリックされた |
| `OnUTF8KeyPress` | `Sender: TObject; var UTF8Key: TUTF8Char` | 文字のキーが押された（UTF-8 の1文字） |

- 部品が使っているキー（Ctrl+S・Shift+F10・F12）を、`OnKeyDown` やフォームの `OnKeyDown`（`KeyPreview = True`）で `Key := 0` にすると、部品の動作が止まる。

## 8. 操作

### 8.1 キー

| キー | 動作 |
|---|---|
| Ctrl+S | 上書き保存（`Save`） |
| Shift+F10 | カーソルの行を複製 |
| F12 | 行番号の表示・非表示 |

このほかのキーは、TSynEdit と同じ。

### 8.2 マウス

| 操作 | 動作 |
|---|---|
| Ctrl+ホイール上 | 文字を大きくする（最大 72 ポイント） |
| Ctrl+ホイール下 | 文字を小さくする（最小 6 ポイント） |
| ファイルをドロップ | 開く（`OnDropFilesEvent` を設定したときは、イベントだけ） |

### 8.3 右クリックメニュー

| グループ | 項目 | 動作 | 使えるとき |
|---|---|---|---|
| 1 | 切り抜き | 選んでいる文字列を切り取る | 選んでいるとき |
| 1 | コピー | 選んでいる文字列をコピー | 選んでいるとき |
| 1 | 貼り付け | 貼り付け | クリップボードに文字があるとき |
| 2 | 引用付きコピー | 各行の先頭に「> 」を付けてコピー | 選んでいるとき |
| 2 | 追加切り抜き | クリップボードの後ろに足して切り取る | 選んでいるとき |
| 2 | 追加コピー | クリップボードの後ろに足してコピー | 選んでいるとき |
| 3 | 削除 | 選んでいる文字列を消す | 選んでいるとき |
| 4 | TO UPPER CASE | 大文字にする | 選んでいるとき |
| 4 | to lower case | 小文字にする | 選んでいるとき |
| 5 | ハンカクに変換 | 全角の英数字・記号・空白を半角にする（全角カタカナは変えない） | 選んでいるとき |
| 5 | 全角ひらがなに変換 | カタカナをひらがなにする | 選んでいるとき |
| 5 | 全角カタカナに変換 | ひらがなをカタカナにする | 選んでいるとき |
| 6 | TAB -> 空白 変換 | タブを空白（`TabWidth` の数）にする | 選んでいるとき |
| 6 | 空白 -> TAB 変換 | 空白（`TabWidth` の数）をタブにする | 選んでいるとき |
| 7 | インデント | 選んでいる行を字下げする | いつでも |
| 7 | 逆インデント | 選んでいる行の字下げを戻す | いつでも |

## 9. 使い方の例

### 9.1 ファイルを開く・保存する

```pascal
procedure TForm1.btnOpenClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
    CSynEdit1.LoadFromFile(OpenDialog1.FileName);
end;

procedure TForm1.btnSaveAsClick(Sender: TObject);
begin
  SaveDialog1.FileName := CSynEdit1.FileName;
  if SaveDialog1.Execute then
    CSynEdit1.SaveToFile(SaveDialog1.FileName);
end;
```

### 9.2 ファイル名と変更の有無をタイトルに出す

```pascal
procedure TForm1.CSynEdit1FileNameChangeEvent(Sender: TObject; var sFileName: String);
begin
  Caption := CSynEdit1.DisplayTitle;
end;

procedure TForm1.CSynEdit1ModifiedChangeEvent(Sender: TObject; var bModified: Boolean);
begin
  if bModified then
    Caption := '* ' + CSynEdit1.DisplayTitle
  else
    Caption := CSynEdit1.DisplayTitle;
end;
```

### 9.3 カーソルの位置と挿入・上書きをステータスバーに出す

```pascal
procedure TForm1.CSynEdit1CaretChangeEvent(Sender: TObject; var iX, iY: Integer);
begin
  StatusBar1.Panels[0].Text := Format('%d 行 %d 桁', [iY, iX]);
end;

procedure TForm1.CSynEdit1InsModeChangeEvent(Sender: TObject; var bMode: Boolean);
begin
  if bMode then
    StatusBar1.Panels[1].Text := '挿入'
  else
    StatusBar1.Panels[1].Text := '上書き';
end;
```

### 9.4 元に戻す・やり直しのボタンを切り替える

```pascal
procedure TForm1.CSynEdit1UndoRedoStateChangeEvent(Sender: TObject;
  var bCanUndo, bCanRedo: Boolean);
begin
  btnUndo.Enabled := bCanUndo;
  btnRedo.Enabled := bCanRedo;
end;

procedure TForm1.btnUndoClick(Sender: TObject);
begin
  CSynEdit1.Undo;
end;

procedure TForm1.btnRedoClick(Sender: TObject);
begin
  CSynEdit1.Redo;
end;
```

### 9.5 探す・置き換える

```pascal
procedure TForm1.btnFindClick(Sender: TObject);
begin
  if not CSynEdit1.SearchText(Edit1.Text, False, False, True) then
    ShowMessage('見つかりません');
end;

procedure TForm1.btnReplaceAllClick(Sender: TObject);
var
  N: Integer;
begin
  N := CSynEdit1.ReplaceAllText(Edit1.Text, Edit2.Text, False, False);
  ShowMessage(IntToStr(N) + ' 個置き換えました');
end;
```

### 9.6 カーソルの位置に文字を入れる・行を選ぶ

```pascal
CSynEdit1.InsertTextAtCaret(FormatDateTime('yyyy/mm/dd', Now));   // 今日の日付を入れる
CSynEdit1.SetCaretPosition(1, 10);                                // 10 行目の先頭へ
CSynEdit1.SelectLine(10);                                         // 10 行目を選ぶ
```

### 9.7 ドロップされたファイルを、自分で開く

```pascal
procedure TForm1.CSynEdit1DropFilesEvent(Sender: TObject; const AFiles: array of string);
var
  i: Integer;
begin
  // このイベントを設定すると、部品はファイルを開かない
  for i := 0 to High(AFiles) do
    ListBox1.Items.Add(AFiles[i]);       // ドロップされたファイルを一覧に足す
  if Length(AFiles) > 0 then
    CSynEdit1.LoadFromFile(AFiles[0]);   // 最初のファイルを開く
end;
```

### 9.8 配色を Windows のテーマに合わせる

```pascal
CSynEdit1.EditStyle := csThema;   // MetaDarkStyle などと組み合わせて使う
```

### 9.9 コードで作る

```pascal
uses
  cSynEdit;

procedure TForm1.FormCreate(Sender: TObject);
var
  E: TCSynEdit;
begin
  E := TCSynEdit.Create(Self);
  E.Parent := Self;
  E.Align := alClient;
  E.EditStyle := csWhite;
  E.OnFileNameChangeEvent := @CSynEdit1FileNameChangeEvent;   // 9.2 の処理を使う
end;
```
