# TCSynEdit 設計書

作者: aotan083
日付: 2026-10-29
版: 1.0

---

## 1. 目的

TSynEdit を元に、次を足したテキストエディタを作る。

- ファイルの読み書き（読み書きしたファイルは、ほかのアプリから書き込めないように押さえる）。
- 配色（`EditStyle`）の切り替え。
- 拡張子に合わせた色分け（ハイライター）の自動切り替え。
- 秀丸エディタに似た右クリックメニュー。
- 状態の変化（ファイル名・挿入/上書き・カーソル・元に戻す/やり直し・変更あり・選択・フォーカス）を知らせるイベント。
- ファイルのドロップ、Ctrl+S・Shift+F10・F12・Ctrl+ホイールの操作。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `cSynedit.pas`（unit 名 `csynedit`） | cx（実行時） | 型と `TCSynEdit` |
| `uCXReg.pas` | cxdsgn（設計時） | パレット [CX] への登録（`RegisterComponents('CX', [..., TCSynEdit, ...])`）。uses には `cSynEdit` と書く |
| `cx_icons.lrs` | cxdsgn（設計時） | アイコン（`TCSynEdit`・`TCSynEdit_150`・`TCSynEdit_200`） |

- interface の uses：`Classes, SysUtils, Graphics, Menus, LCLType, LCLIntf, Clipbrd, LazUTF8, Math, SynEdit, SynEditKeyCmds, SynHighlighterXML, SynHighlighterHTML, SynHighlighterPas, SynEditTypes, SynGutterLineNumber, Registry`
- implementation の uses（Windows のときだけ）：`Windows, ShellAPI`
- cx の必要パッケージに SynEdit が要る。
- initialization・finalization はない。

## 3. 型

```pascal
TCEditStyle = (csBlack, csGray, csWhite, csThema);
TCFileEncoding = (feUTF8, feANSI_SJIS, feUTF16LE, feUTF16BE, feEUCJP);
TCLineEnding = (leCRLF, leLF, leCR);
TCSynTextChangeEvent = procedure(Sender: TObject; const AText: string) of object;
TOnFileNameChangeEvent = procedure(Sender: TObject; var sFileName: String) of object;
TOnLoadFromFileEvent = procedure(Sender: TObject; var sFileName: String) of object;
TOnSaveToFileEvent = procedure(Sender: TObject; var sFileName: String) of object;
TOnInsModeChangeEvent = procedure(Sender: TObject; var bMode: Boolean) of object;
TOnCaretChangeEvent = procedure(Sender: TObject; var iX, iY: Integer) of object;
TOnUndoRedoStateChangeEvent = procedure(Sender: TObject; var bCanUndo, bCanRedo: Boolean) of object;
TOnModifiedChangeEvent = procedure(Sender: TObject; var bModified: Boolean) of object;
TOnSelectionChangeEvent = procedure(Sender: TObject; var sSelText: String; var iStartX, iStartY, iEndX, iEndY: Integer) of object;
TOnFocusChangeEvent = procedure(Sender: TObject; var bFocused: Boolean) of object;
TOnDropFilesEvent = procedure(Sender: TObject; const AFiles: array of string) of object;

TCSynEdit = class(TSynEdit)
```

## 4. フィールド

| 名前 | 型 | 中身 |
|---|---|---|
| `FFileName` | `string` | ファイル名 |
| `FEditStyle` | `TCEditStyle` | 配色 |
| `FEncodingType` | `TCFileEncoding` | 文字コードの入れ物（読み書きには使わない） |
| `FHasBOM` | `Boolean` | BOM の有無の入れ物（読み書きには使わない） |
| `FLineEndingType` | `TCLineEnding` | 改行コードの入れ物（読み書きには使わない） |
| `FOnTextChange` ほか11個 | 各イベント型 | イベント（5.1 の published のイベントと1対1） |
| `FPopupMenu` | `TPopupMenu` | 部品が持つ右クリックメニュー |
| `FFileStream` | `TFileStream` | ファイルを押さえるためのストリーム |
| `FLoadingFlag` | `Boolean` | `Create` で `False` にするだけ（ほかでは使っていない） |
| `FOldInsertMode` | `Boolean` | 前の `InsertMode`（変化を見つけるため） |
| `FOldCaretX`・`FOldCaretY` | `Integer` | 前のカーソル位置 |
| `FOldCanUndo`・`FOldCanRedo` | `Boolean` | 前の `CanUndo`・`CanRedo` |
| `FOldModified` | `Boolean` | 前の `Modified` |
| `FOldSelText` | `string` | 前の `SelText` |
| `FMenuItemCut` ほか13個 | `TMenuItem` | メニュー項目（使えるかを切り替えるため。8章） |

## 5. 宣言

### 5.1 published

```pascal
property FileName: string read FFileName write SetFileName;
property EditStyle: TCEditStyle read FEditStyle write SetEditStyle default csGray;
property InsMode: Boolean read GetInsModeValue write SetInsModeValue default True;
property EncodingType: TCFileEncoding read FEncodingType write FEncodingType default feUTF8;
property HasBOM: Boolean read FHasBOM write FHasBOM default False;
property LineEndingType: TCLineEnding read FLineEndingType write FLineEndingType default leCRLF;
property CaretY: Integer read GetCaretYValue write SetCaretYValue;
property CaretX: Integer read GetCaretXValue write SetCaretXValue;
property OnTextChange: TCSynTextChangeEvent read FOnTextChange write FOnTextChange;
property OnFileNameChangeEvent: TOnFileNameChangeEvent read FOnFileNameChange write FOnFileNameChange;
property OnLoadFromFileEvent: TOnLoadFromFileEvent read FOnLoadFromFile write FOnLoadFromFile;
property OnSaveToFileEvent: TOnSaveToFileEvent read FOnSaveToFile write FOnSaveToFile;
property OnInsModeChangeEvent: TOnInsModeChangeEvent read FOnInsModeChange write FOnInsModeChange;
property OnCaretChangeEvent: TOnCaretChangeEvent read FOnCaretChange write FOnCaretChange;
property OnUndoRedoStateChangeEvent: TOnUndoRedoStateChangeEvent read FOnUndoRedoStateChange write FOnUndoRedoStateChange;
property OnModifiedChangeEvent: TOnModifiedChangeEvent read FOnModifiedChange write FOnModifiedChange;
property OnSelectionChangeEvent: TOnSelectionChangeEvent read FOnSelectionChange write FOnSelectionChange;
property OnFocusChangeEvent: TOnFocusChangeEvent read FOnFocusChange write FOnFocusChange;
property OnDropFilesEvent: TOnDropFilesEvent read FOnDropFiles write FOnDropFiles;
```

- `CaretX`・`CaretY` は、親の `CaretX`・`CaretY` を `inherited` で読み書きするだけ（オブジェクトインスペクタに出すため）。
- `InsMode` の読みは `InsertMode` を返す。

### 5.2 public

```pascal
constructor Create(AOwner: TComponent); override;
destructor Destroy; override;
procedure LoadFromFile(const AFileName: string);
procedure SaveToFile(const AFileName: string);
procedure Save;
procedure DuplicateCurrentLine;
procedure ToggleLineNumbers;
procedure InsertTextAtCaret(const AText: string);
procedure ReplaceSelection(const AText: string);
procedure SetCaretPosition(const AX, AY: Integer);
procedure SelectLine(const ALineIndex: Integer);
procedure SelectRange(const AStartX, AStartY, AEndX, AEndY: Integer);
function SearchText(const ASearchStr: string; ACaseSensitive, AWholeWord, AForward: Boolean): Boolean;
function ReplaceText(const ASearchStr, AReplaceStr: string; ACaseSensitive, AWholeWord: Boolean): Boolean;
function ReplaceAllText(const ASearchStr, AReplaceStr: string; ACaseSensitive, AWholeWord: Boolean): Integer;
property DisplayTitle: string read GetDisplayTitle;
```

### 5.3 protected

```pascal
procedure OnFileNameChange(var sFileName: String); virtual;
procedure OnLoadFromFile(var sFileName: String); virtual;
procedure OnSaveToFile(var sFileName: String); virtual;
procedure OnInsModeChange(var bMode: Boolean); virtual;
procedure OnCaretChange(var iX, iY: Integer); virtual;
procedure OnUndoRedoStateChange(var bCanUndo, bCanRedo: Boolean); virtual;
procedure OnModifiedChange(var bModified: Boolean); virtual;
procedure OnSelectionChange(var sSelText: String; var iStartX, iStartY, iEndX, iEndY: Integer); virtual;
procedure OnFocusChange(var bFocused: Boolean); virtual;
procedure DoEnter; override;
procedure DoExit; override;
procedure StatusChanged(AChanges: TSynStatusChanges); override;
procedure KeyDown(var Key: Word; Shift: TShiftState); override;
function DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint): Boolean; override;
function DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean; override;
procedure CreateWnd; override;
procedure DestroyWnd; override;
procedure DoDropFiles(const AFiles: array of string); virtual;
procedure Loaded; override;
```

`OnFileNameChange` から `OnFocusChange` までの9個は、対応するイベントがあれば呼ぶだけ。

## 6. 作る・壊す

Create：

1. `inherited Create`、`FLoadingFlag := False`。
2. `Font.Name := 'BIZ UDGothic'`、`Font.Size := 12`、`Font.Quality := fqCleartypeNatural`。
3. `FFileName := ExtractFilePath(ParamStr(0)) + '無題.txt'`。
4. `InsertMode := True`、`FOldInsertMode := True`、`FOldCaretX := 1`、`FOldCaretY := 1`、`FOldCanUndo := False`、`FOldCanRedo := False`、`FOldModified := False`、`FOldSelText := ''`、`FFileStream := nil`。
5. `FEditStyle := csGray`（ここでは配色を当てない。当てるのは `Loaded` と `SetEditStyle`）。
6. `Highlighter := TSynPasSyn.Create(Self)`。
7. `FEncodingType := feUTF8`、`FHasBOM := False`、`FLineEndingType := leCRLF`。
8. `CreateHidemaruLikePopupMenu`、`PopupMenu := FPopupMenu`。

Destroy：`UnlockFile`、`FreeAndNil(FPopupMenu)`、`inherited`。

Loaded：`inherited` のあと `ApplyEditStyle`（読み込みが終わってから配色を決める）。

## 7. 処理

### 7.1 ファイル名

`SetFileName(v)`：値が変わったときだけ、`FFileName := v`、`OnFileNameChange(FFileName)`（イベントの中で `sFileName` を変えると `FFileName` が変わる。var で渡すため）、`AutoSelectHighlighter(FFileName)`。

`GetDisplayTitle`：`FFileName` が空でなければ `ExtractFileName(FFileName)`、空なら `'無題.txt'`。

### 7.2 色分けの自動切り替え（AutoSelectHighlighter）

`Ext := LowerCase(ExtractFileExt(APath))` で次のとおり。新しいハイライターは Owner = Self で作る（前のものは Self が持ったまま、壊すときに一緒に壊れる）。

| 拡張子 | 作るもの |
|---|---|
| `.json`・`.html`・`.htm`・`.csv`・`.md`・`.markdown`・`.yaml`・`.yml` | `TSynHTMLSyn.Create(Self)` |
| `.xml` | `TSynXMLSyn.Create(Self)` |
| `.pas`・`.pp`・`.lpr`・`.dpr`・''・`.txt` | `TSynPasSyn.Create(Self)` |
| ほか | 何もしない |

- 切り替えたあと、配色（`ApplyEditStyle`）は当て直さない。

### 7.3 ファイルを読む・書く

| 手続き | 処理 |
|---|---|
| `LoadFromFile(f)` | `UnlockFile` → `Lines.LoadFromFile(f)` → `FileName := f` → `Modified := False` → `LockFile(f)` → `OnLoadFromFile(FFileName)` |
| `SaveToFile(f)` | `UnlockFile` → `Lines.SaveToFile(f)` → `FileName := f` → `Modified := False` → `LockFile(f)` → `OnSaveToFile(FFileName)` |
| `Save` | `SaveToFile(FFileName)` |
| `LockFile(f)` | `UnlockFile`。ファイルがあれば `TFileStream.Create(f, fmOpenRead or fmShareDenyWrite)`。失敗したら `FFileStream := nil`（例外は出さない） |
| `UnlockFile` | `FFileStream` があれば `FreeAndNil` |

- 文字コード・改行コードの変換はしない。`EncodingType`・`HasBOM`・`LineEndingType` は見ない。

### 7.4 配色（ApplyEditStyle）

`csLoading` 中なら何もしない。すべての配色で、`Gutter.MarksPart.Visible := False`（ブックマークの欄を出さない）。

配色ごとに次を入れる。

| 項目 | csThema | csBlack | csGray | csWhite |
|---|---|---|---|---|
| `Font.Color` | `clWindowText` | `clWhite` | `clWhite` | `clBlack` |
| `Color` | `clWindow` | `clBlack` | `clBlack` | `clWhite` |
| `BorderWidth` | 0 | 0 | 変えない | 0 |
| `RightEdge` | 80 | 80 | 80 | 80 |
| `RightEdgeColor` | `clWindow` | `clBlack` | `clBlack` | `clWhite` |
| `SelectedColor` | 背景 `clHighlight`・文字 `clHighlightText` | 変えない | 変えない | 変えない |
| `Gutter.Visible` | `True` | `True` | `True` | `True` |
| `Gutter.Color` | `clWindow` | `clBlack` | `clBlack` | `clWhite` |
| `Gutter.SeparatorPart.Visible` | `False` | `False` | `False` | `False` |
| 行番号の背景 | `clWindow` | `clBlack` | `clBlack` | `clWhite` |
| 行番号の文字 | `clGrayText` | `TColor($3B3B3B)` | `TColor($3B3B3B)` | `TColor($EEEEEE00)` |
| 行番号の間引き | 変えない | 変えない | `ShowOnlyLineNumbersMultiplesOf := 5`（`TSynGutterLineNumber` のとき） | 変えない |
| カーソル行の背景 | ダーク：`RGBToColor(38,38,38)`、ライト：`RGBToColor(242,242,242)` | `TColor($00101010)` | `RGB(2,20,26)` | `TColor($F2F2F2)` |
| カーソル行の文字 | `clNone` | `clWhite` | `clWhite` | `clBlack` |
| カーソル行の枠 | `clNone` | `clNone` | `clNone` | `clNone` |

- 右端のガイド線は背景と同じ色にして見えなくする。
- csThema のダーク／ライトは `IsOSDarkTheme`（レジストリ `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize` の `AppsUseLightTheme` が 0 ならダーク。値がなければライト）で決める。ほかの色はシステム色にして、MetaDarkStyle などに読み替えを任せる。

**Pascal の色分けの配色**（`Highlighter is TSynPasSyn` のときだけ）

| 属性 | csThema（ダーク） | csThema（ライト） | csBlack | csGray | csWhite |
|---|---|---|---|---|---|
| `KeyAttri`（予約語） | `RGBToColor(86,156,214)` | `RGBToColor(0,0,255)` | `clWhite` | `clAqua` | `clNavy` |
| `StringAttri`（文字列） | `RGBToColor(206,145,120)` | `RGBToColor(163,21,21)` | `clYellow` | `clYellow` | `clBlue` |
| `CommentAttri`（コメント） | `RGBToColor(106,153,85)` | `RGBToColor(0,128,0)` | `clGray` | `clGreen` | `clGreen` |
| `NumberAttri`（数値） | `RGBToColor(181,206,168)` | `RGBToColor(9,134,88)` | `TColor($008080FF)` | `TColor($008080FF)` | `clPurple` |
| `IdentifierAttri`（識別子） | `clWindowText` | `clWindowText` | `clWhite` | `clWhite` | `clBlack` |
| `ModifierAttri` | 予約語と同じ | 予約語と同じ | 予約語と同じ | 予約語と同じ | 予約語と同じ |
| `SymbolAttri`（記号） | 予約語と同じ | 予約語と同じ | 予約語と同じ | 予約語と同じ | 予約語と同じ |
| 各属性の背景 | `clNone` | `clNone` | `clBlack` | `clBlack` | `clWhite` |

- `KeyAttri.Style`・`CommentAttri.Style`・`ModifierAttri.Style` は `[]`（太字・斜体にしない）。

`SetEditStyle(v)`：値が変わったときだけ `FEditStyle := v`、`ApplyEditStyle`。

### 7.5 挿入・上書き（SetInsModeValue）

値が変わったときだけ：`InsertMode := v`、`FOldInsertMode := InsertMode`、`CurMode := InsertMode`、`OnInsModeChange(CurMode)`。イベントで `CurMode` が変えられたら、`InsertMode`・`FOldInsertMode` をその値にする。

### 7.6 状態の変化（StatusChanged）

`inherited StatusChanged(AChanges)` のあと、次の順に調べる。

| 順 | 条件 | 処理 |
|---|---|---|
| 1 | `AChanges <> []` | `FOnTextChange(Self, Text)` |
| 2 | `FOldInsertMode <> InsertMode` | `FOldInsertMode` を更新し、`OnInsModeChange(CurMode)`。変えられたら `InsertMode`・`FOldInsertMode` に入れる |
| 3 | カーソル位置が前と違う | `OnCaretChange(CurX, CurY)`。変えられたら `CaretX`・`CaretY` に入れる。`FOldCaretX`・`FOldCaretY` を `CurX`・`CurY` にする |
| 4 | `CanUndo`・`CanRedo` が前と違う | `OnUndoRedoStateChange(CurCanUndo, CurCanRedo)`。前の値として `CurCanUndo`・`CurCanRedo` を覚える（部品には入れない） |
| 5 | `Modified` が前と違う | `OnModifiedChange(CurModified)`。変えられたら `Modified` に入れる。`FOldModified := Modified` |
| 6 | `SelText` が前と違う | `FOldSelText := SelText`。`OnSelectionChange(SelText, BlockBegin.X, BlockBegin.Y, BlockEnd.X, BlockEnd.Y)`（部品には戻さない） |

### 7.7 フォーカス

`DoEnter`：`inherited` のあと `OnFocusChange(True)`。`DoExit`：`inherited` のあと `OnFocusChange(False)`（どちらも変数を通して渡し、戻り値は使わない）。

### 7.8 キー（KeyDown）

| キー | 処理 |
|---|---|
| Ctrl+S | `Save`、`Key := 0`、終わる |
| Shift+F10 | `DuplicateCurrentLine`、`Key := 0`、終わる |
| F12（Shift なし） | `ToggleLineNumbers`、`Key := 0`、終わる |
| ほか | `inherited KeyDown` |

### 7.9 ホイール

- `DoMouseWheelDown`：Ctrl があれば、`Font.Size > 6` なら 1 減らし、`True` を返す。なければ `inherited`。
- `DoMouseWheelUp`：Ctrl があれば、`Font.Size < 72` なら 1 増やし、`True` を返す。なければ `inherited`。

### 7.10 ドロップ（Windows のときだけ）

- `CreateWnd`：`inherited` のあと、`DragAcceptFiles(Handle, True)`、`SetWindowSubclass(Handle, @DropSubclassProc, DROP_SUBCLASS_ID, DWORD_PTR(Self))`（`DROP_SUBCLASS_ID = 1`）。
- `DestroyWnd`：ハンドルがあれば `RemoveWindowSubclass`・`DragAcceptFiles(Handle, False)`、そのあと `inherited`。
- `SetWindowSubclass`・`RemoveWindowSubclass`・`DefSubclassProc` は `comctl32.dll` から external で宣言する。
- `DropSubclassProc`：`WM_DROPFILES` なら、`DragQueryFileW` で数と各ファイル名（UTF-16）を取り、`UTF8Encode` で string の配列にし、`DragFinish`、`TCSynEdit(dwRefData).DoDropFiles(Files)`、0 を返す。`WM_NCDESTROY` なら `RemoveWindowSubclass`。それ以外は `DefSubclassProc`。
- `DoDropFiles(AFiles)`：空なら終わる。`FOnDropFiles` があれば呼ぶ。なければ `LoadFromFile(AFiles[0])`。

### 7.11 編集

| 手続き | 処理 |
|---|---|
| `DuplicateCurrentLine` | カーソル位置を覚え、`1 <= CaretY <= Lines.Count` なら `Lines.Insert(CaretY, Lines[CaretY - 1])`、カーソルを戻す |
| `ToggleLineNumbers` | `Gutter.LineNumberPart.Visible` を反転し、`Gutter.Visible := True`（欄そのものは常に出す） |
| `InsertTextAtCaret(s)` | `s` が空でなければ `inherited InsertTextAtCaret(s)` |
| `ReplaceSelection(s)` | `SelText := s` |
| `SetCaretPosition(x, y)` | 行が 0 なら `y := 1`、それ以外は `EnsureRange(y, 1, Lines.Count)`。桁は `EnsureRange(x, 1, 行の長さ + 1)`（行がなければ 1）。`CaretX`・`CaretY` に入れる |
| `SelectLine(n)` | 行が 0 なら終わる。`n` を `1..Lines.Count` に収め、`BlockBegin := (1, n)`、`BlockEnd := (行の長さ + 1, n)` |
| `SelectRange(x1, y1, x2, y2)` | 行が 0 なら終わる。行は `1..Lines.Count`、桁は `1..行の長さ + 1` に収め、`BlockBegin`・`BlockEnd` に入れる |

### 7.12 検索・置換

どれも、探す文字列が空なら何もせず `False`・0 を返す。`SearchReplace` を使う。

| 手続き | オプション | 戻り値 |
|---|---|---|
| `SearchText` | `ACaseSensitive` → `ssoMatchCase`、`AWholeWord` → `ssoWholeWord`、`not AForward` → `ssoBackwards` | `SearchReplace(s, '', opt) > 0` |
| `ReplaceText` | `ssoReplace` ＋ 上と同じ大文字小文字・単語 | `SearchReplace(s, r, opt) > 0` |
| `ReplaceAllText` | `ssoReplace, ssoReplaceAll, ssoEntireScope` ＋ 上と同じ | `SearchReplace(s, r, opt)` の値（置き換えた数） |

## 8. 右クリックメニュー

`CreateHidemaruLikePopupMenu`：`FPopupMenu` があれば壊し、`TPopupMenu.Create(Self)` で作る。`OnPopup := OnPopupMenuPopup`。項目は次の順（グループの間に区切り線 `'-'`）。

| グループ | 表示 | 処理 | フィールド |
|---|---|---|---|
| 1 | 切り抜き | `CutToClipboard` | `FMenuItemCut` |
| 1 | コピー | `CopyToClipboard` | `FMenuItemCopy` |
| 1 | 貼り付け | `PasteFromClipboard` | `FMenuItemPaste` |
| 2 | 引用付きコピー | 選択を行に分け、各行の先頭に `'> '` を付けて `Clipboard.AsText` に入れる | `FMenuItemQuoteCopy` |
| 2 | 追加切り抜き | `Clipboard.AsText := 今のクリップボード + SelText`、`ClearSelection` | `FMenuItemAppendCut` |
| 2 | 追加コピー | `Clipboard.AsText := 今のクリップボード + SelText` | `FMenuItemAppendCopy` |
| 3 | 削除 | `ClearSelection` | `FMenuItemDelete` |
| 4 | TO UPPER CASE | `SelText := UpperCase(SelText)` | `FMenuItemUpperCase` |
| 4 | to lower case | `SelText := LowerCase(SelText)` | `FMenuItemLowerCase` |
| 5 | ハンカクに変換 | UTF-16 にして、U+FF01〜U+FF5E を `- $FEE0`、U+3000 を空白にする | `FMenuItemToHalf` |
| 5 | 全角ひらがなに変換 | UTF-16 にして、U+30A1〜U+30F6 を `- $60` | `FMenuItemToHiragana` |
| 5 | 全角カタカナに変換 | UTF-16 にして、U+3041〜U+3096 を `+ $60` | `FMenuItemToKatakana` |
| 6 | TAB -> 空白 変換 | 選択の中の `#9` を `TabWidth` 個の空白にする | `FMenuItemTabToSpace` |
| 6 | 空白 -> TAB 変換 | 選択の中の `TabWidth` 個の空白を `#9` にする | `FMenuItemSpaceToTab` |
| 7 | インデント | `ExecuteCommand(ecBlockIndent, ' ', nil)` | なし |
| 7 | 逆インデント | `ExecuteCommand(ecBlockUnindent, ' ', nil)` | なし |

- 選択を使う項目は、選択が空なら何もしない。
- `OnPopupMenuPopup`：`SelText <> ''` のとき、グループ 1 の「切り抜き」「コピー」とグループ 2〜6 の項目を使えるようにする。「貼り付け」は `Clipboard.HasFormat(CF_TEXT)` のとき使える。グループ 7 は常に使える。
- `OnMenuSelectAllClick`（`SelectAll`）は宣言があるが、メニューには入れていない。

## 9. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| コードで作ったときに配色が当たらない | `Create` では `ApplyEditStyle` を呼ばない（6章）。`EditStyle` を別の値にしたとき、`Loaded` のときだけ当たる |
| ファイルを開いたあと、Pascal の色分けの配色が既定の色になる | `AutoSelectHighlighter` は新しいハイライターを作るだけで、配色を当て直さない（7.2） |
| ほかのアプリでファイルを保存できない | `LockFile`（7.3） |
| ドロップしても開かない | `CreateWnd` のサブクラス化、`DoDropFiles`（7.10） |
| イベントの引数を変えても反映されない | 7.6 の表で「部品に入れる」ものかどうか |
| Ctrl+S などが効かない | `KeyDown`（7.8）。フォームの `KeyPreview` で `Key := 0` にしていないか |
