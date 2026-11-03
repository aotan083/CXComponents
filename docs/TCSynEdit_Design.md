# TCSynEdit 設計書

作者: aotan083
日付: 2026-10-31
版: 1.1

---

## 1. 目的

TSynEdit を元に、次を足したテキストエディタを作る。

- ファイルの読み書き（読み書きしたファイルは、ほかのアプリから書き込めないように押さえる）。
- 配色（`EditStyle`）の切り替え。VS Code（TCMonacoEditor）と同じ配色 `csVSLight`・`csVSDark` を持つ。
- 言語（`Language`）に合わせた色分け（ハイライター）の切り替え。拡張子と言語の対応は TCMonacoEditor と同じ。
- Markdown の色分け（自作の `TCSynMarkdownSyn`）。
- 秀丸エディタに似た右クリックメニュー。
- 状態の変化（ファイル名・挿入/上書き・カーソル・元に戻す/やり直し・変更あり・選択・フォーカス）を知らせるイベント。
- ファイルのドロップ、Ctrl+S・Shift+F10・F12・Ctrl+ホイールの操作。

**動作環境**：Lazarus 5.0 以降（テストは 5.0 RC1）。Lazarus 4.8 は、cx パッケージのコンパイルが通るようにするだけで、動作の確認・テストはしない（4.8 で不具合が出ても直さない）。版で分けるコードはない（4.8 の名前で書き、5.0 でもそのまま通る）。5.0 では `TSynHighlighterAttributes`・`TSynCustomHighlighter`・`SYN_ATTR_…`・`SetLine`・`SetRange` などが「古い書き方」の警告になるが、動きは同じ（Lazarus 5.99 で取り除かれる予定。そのときに書き直す）。

TCsEditor（`TCsEditor_Design.md`）は、この部品を 1 タブに 1 つ持つ。TCsEditor が使うのは、配色 `csVSLight`・`csVSDark`、`Language`、`ApplyEditStyle`（継承して色を足す）、`CSLanguageForFile`。

## 2. ファイルとパッケージ

| ファイル | パッケージ | 中身 |
|---|---|---|
| `cSynedit.pas`（unit 名 `csynedit`） | cx（実行時） | 型、`TCSynEdit`、`TCSynMarkdownSyn`、関数 `CSLanguageForFile` |
| `uCXReg.pas` | cxdsgn（設計時） | パレット [CX] への登録（`RegisterComponents('CX', [..., TCSynEdit, ...])`）。uses には `cSynEdit` と書く |
| `cx_icons.lrs` | cxdsgn（設計時） | アイコン（`TCSynEdit`・`TCSynEdit_150`・`TCSynEdit_200`） |

- interface の uses：`Classes, SysUtils, Graphics, Menus, LCLType, LCLIntf, Clipbrd, LazUTF8, Math, SynEdit, SynEditKeyCmds, SynEditHighlighter, SynEditTypes, SynGutterLineNumber, SynGutterCodeFolding, SynGutterChanges, SynEditMarkup, SynEditMarkupWordGroup, SynEditMarkupHighAll, SynHighlighterPas, SynHighlighterHTML, SynHighlighterXML, SynHighlighterCss, SynHighlighterJScript, SynHighlighterSQL, SynHighlighterIni, SynHighlighterBat, SynHighlighterPython, SynHighlighterCpp, SynHighlighterJava, SynHighlighterUNIXShellScript, SynHighlighterPHP, Registry`
- implementation の uses：`TypInfo, StrUtils`、Windows のときだけ `Windows, ShellAPI`
- cx の必要パッケージに SynEdit が要る（今のまま）。
- initialization・finalization はない。

## 3. 型

```pascal
TCEditStyle = (csBlack, csGray, csWhite, csThema, csVSLight, csVSDark);
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

TCSynMarkdownSyn = class(TSynCustomHighlighter)   // 9章
TCSynEdit = class(TSynEdit)

function CSLanguageForFile(const AFileName, ADefault: string): string;
```

- `csVSLight`・`csVSDark` は後ろに足す（.lfm には名前で保存されるので、並びを変えても既存の .lfm は壊れないが、念のため既存の 4 つの順番は変えない）。

**CSLanguageForFile**

拡張子（小文字にして比べる）から言語の名前を返す。TCMonacoEditor の `LanguageForFile`（`uCmmonacoview.pas`）と同じ表。

| 拡張子 | 言語 |
|---|---|
| .pas .pp .lpr .inc .dpr .lpk | pascal |
| .md .markdown | markdown |
| .txt | plaintext |
| .html .htm | html |
| .css | css |
| .js | javascript |
| .json | json |
| .xml | xml |
| .sql | sql |
| .ini .cfg | ini |
| .bat .cmd | bat |
| .py | python |
| .c .h .cpp .hpp | cpp |
| .cs | csharp |
| .ts .tsx | typescript |
| .java | java |
| .sh .bash | shell |
| .ps1 .psm1 .psd1 | powershell |
| .yml .yaml | yaml |
| .php | php |
| .go | go |
| それ以外 | `ADefault` |

## 4. フィールド

| 名前 | 型 | 中身 |
|---|---|---|
| `FFileName` | `string` | ファイル名 |
| `FEditStyle` | `TCEditStyle` | 配色 |
| `FLanguage` | `string` | 今の言語（7.2）。既定 'pascal' |
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
property Language: string read FLanguage write SetLanguage;     // 7.2
```

- `Language` は public（.lfm には保存しない。ファイル名・コードで決めるもの）。

### 5.3 protected

```pascal
procedure ApplyEditStyle; virtual;          // 1.0 は private。継承した部品（TCsEditor の中の部品）が色を足せるように protected virtual にする
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
5. `FEditStyle := csGray`（ここでは配色を当てない。当てるのは `Loaded`・`SetEditStyle`・`SetLanguage`）。
6. `FLanguage := 'pascal'`、`Highlighter := TSynPasSyn.Create(Self)`。
7. `FEncodingType := feUTF8`、`FHasBOM := False`、`FLineEndingType := leCRLF`。
8. `CreateHidemaruLikePopupMenu`、`PopupMenu := FPopupMenu`。

Destroy：`UnlockFile`、`FreeAndNil(FPopupMenu)`、`inherited`。

Loaded：`inherited` のあと `ApplyEditStyle`（読み込みが終わってから配色を決める）。

## 7. 処理

### 7.1 ファイル名

`SetFileName(v)`：値が変わったときだけ、`FFileName := v`、`OnFileNameChange(FFileName)`（イベントの中で `sFileName` を変えると `FFileName` が変わる。var で渡すため）、`AutoSelectHighlighter(FFileName)`。

`GetDisplayTitle`：`FFileName` が空でなければ `ExtractFileName(FFileName)`、空なら `'無題.txt'`。

`AutoSelectHighlighter(APath)`：

1. 拡張子が ''（拡張子なし）なら `Language := 'pascal'`。
2. それ以外は `L := CSLanguageForFile(APath, '')`。`L <> ''` なら `Language := L`。`L = ''`（表にない拡張子）なら何もしない（それまでの色分けのまま）。

### 7.2 言語と色分け（SetLanguage）

`SetLanguage(v)`：

1. `v := LowerCase(v)`。
2. 言語から、使う色分けのクラスを決める（下の表）。
3. 今の `Highlighter` が、そのクラスそのもの（`Highlighter.ClassType = 決めたクラス`）なら作り直さない。違えば：
   - 今の `Highlighter` が自分の作ったもの（`Highlighter.Owner = Self`）なら、`H := Highlighter`、`Highlighter := nil`、`H.Free`。アプリが入れたもの（Owner が自分でない）は壊さない。
   - クラスが nil（色分けなし）なら `Highlighter := nil`。そうでなければ `Highlighter := クラス.Create(Self)`。
   - 自分が作った色分け（`Components` の `TSynCustomHighlighter`）で、今の `Highlighter` でないものも壊す（アプリが自分の色分けを入れたときに、外れて残ったもの）。
4. `FLanguage := v`。
5. `ApplyEditStyle`（色分けを入れ替えても配色を保つ）。

| 言語 | 色分けのクラス |
|---|---|
| pascal | `TSynPasSyn` |
| markdown | `TCSynMarkdownSyn`（9章） |
| html | `TSynHTMLSyn` |
| css | `TSynCssSyn` |
| javascript・json・typescript | `TSynJScriptSyn` |
| xml | `TSynXMLSyn` |
| sql | `TSynSQLSyn` |
| ini | `TSynIniSyn` |
| bat | `TSynBatSyn` |
| python | `TSynPythonSyn` |
| cpp・csharp | `TSynCppSyn` |
| java | `TSynJavaSyn` |
| shell | `TSynUNIXShellScriptSyn` |
| php | `TSynPHPSyn` |
| plaintext・powershell・yaml・go・それ以外 | nil（色分けなし） |

- 前の版で、色分けを入れ替えるたびに新しいものを作って古いものを残していた（開くたびにメモリが増え、配色が既定の色に戻った）。この版で直す（11章 No.2）。

### 7.3 ファイルを読む・書く

| 手続き | 処理 |
|---|---|
| `LoadFromFile(f)` | `UnlockFile` → `Lines.LoadFromFile(f)` → `FileName := f` → `Modified := False` → `LockFile(f)` → `OnLoadFromFile(FFileName)` |
| `SaveToFile(f)` | `UnlockFile` → `Lines.SaveToFile(f)` → `FileName := f` → `Modified := False` → `LockFile(f)` → `OnSaveToFile(FFileName)` |
| `Save` | `SaveToFile(FFileName)` |
| `LockFile(f)` | `UnlockFile`。ファイルがあれば `TFileStream.Create(f, fmOpenRead or fmShareDenyWrite)`。失敗したら `FFileStream := nil`（例外は出さない） |
| `UnlockFile` | `FFileStream` があれば `FreeAndNil` |

- 文字コード・改行コードの変換はしない。`EncodingType`・`HasBOM`・`LineEndingType` は見ない。
- TCsEditor は、この 3 つを使わない（ファイルの読み書きは TCsEditor が行う）。

### 7.4 配色（ApplyEditStyle）

`csLoading` 中なら何もしない。すべての配色で、`Gutter.MarksPart.Visible := False`（ブックマークの欄を出さない）。

順番：

1. 7.4.1 の表で、本文・左端の欄・カーソル行などの色を入れる。
2. 7.4.2 の表で、その配色の「色の組」を決める。
3. 7.4.3 のとおり、今の色分け（`Highlighter`）の属性に色を入れる。`Highlighter` が nil なら何もしない。

#### 7.4.1 本文と左端の欄

既存の 4 つ（csThema・csBlack・csGray・csWhite）は 1.0 のまま。`ChangesPart.Visible := True` だけを足す（`csVSLight`・`csVSDark` から戻したときに、変更行の印が消えたままにならないように）。

| 項目 | csThema | csBlack | csGray | csWhite | csVSLight | csVSDark |
|---|---|---|---|---|---|---|
| `Font.Color` | `clWindowText` | `clWhite` | `clWhite` | `clBlack` | #000000 | #D4D4D4 |
| `Color` | `clWindow` | `clBlack` | `clBlack` | `clWhite` | #FFFFFE | #1E1E1E |
| `BorderWidth` | 0 | 0 | 変えない | 0 | 0 | 0 |
| `RightEdge` | 80 | 80 | 80 | 80 | 80 | 80 |
| `RightEdgeColor` | `clWindow` | `clBlack` | `clBlack` | `clWhite` | #FFFFFE | #1E1E1E |
| `SelectedColor` | 背景 `clHighlight`・文字 `clHighlightText` | 変えない | 変えない | 変えない | 背景 #ADD6FF・文字 `clNone` | 背景 #264F78・文字 `clNone` |
| `Gutter.Visible` | `True` | `True` | `True` | `True` | `True` | `True` |
| `Gutter.Color` | `clWindow` | `clBlack` | `clBlack` | `clWhite` | #FFFFFE | #1E1E1E |
| `Gutter.SeparatorPart.Visible` | `False` | `False` | `False` | `False` | `False` | `False` |
| `Gutter.ChangesPart.Visible` | `True` | `True` | `True` | `True` | `False` | `False` |
| 行番号の背景 | `clWindow` | `clBlack` | `clBlack` | `clWhite` | #FFFFFE | #1E1E1E |
| 行番号の文字 | `clGrayText` | `TColor($3B3B3B)` | `TColor($3B3B3B)` | `TColor($EEEEEE00)` | #237893 | #6E7681 |
| カーソル行の行番号の文字（`LineNumberPart.MarkupInfoCurrentLine`） | 変えない | 変えない | 変えない | 変えない | #0B216F（背景 `clNone`） | #C6C6C6（背景 `clNone`） |
| 行番号の間引き | 変えない | 変えない | `ShowOnlyLineNumbersMultiplesOf := 5` | 変えない | 1 | 1 |
| 折りたたみの欄（`CodeFoldPart.MarkupInfo`） | 変えない | 変えない | 変えない | 変えない | 背景 #FFFFFE・印 #424242 | 背景 #1E1E1E・印 #5A5A5A |
| カーソル行の背景 | ダーク：`RGBToColor(38,38,38)`、ライト：`RGBToColor(242,242,242)` | `TColor($00101010)` | `RGB(2,20,26)` | `TColor($F2F2F2)` | #EAF2FF | #2C313C |
| カーソル行の文字 | `clNone` | `clWhite` | `clWhite` | `clBlack` | `clNone` | `clNone` |
| カーソル行の枠 | `clNone` | `clNone` | `clNone` | `clNone` | `clNone` | `clNone` |
| 括弧の対応（`BracketMatchColor`） | 変えない | 変えない | 変えない | 変えない | 背景・文字 `clNone`、枠 #B9B9B9、`Style := []` | 背景・文字 `clNone`、枠 #888888、`Style := []` |
| キーワードの組（`MarkupByClass[TSynEditMarkupWordGroup].MarkupInfo`） | 変えない | 変えない | 変えない | 変えない | 括弧の対応と同じ | 括弧の対応と同じ |
| 同じ単語の強調（`MarkupByClass[TSynEditMarkupHighlightAllCaret].MarkupInfo`） | 変えない | 変えない | 変えない | 変えない | 背景 #D5D5D5・文字 `clNone` | 背景 #474747・文字 `clNone` |
| 折りたたんだ所（`FoldedCodeColor`） | 変えない | 変えない | 変えない | 変えない | 背景・文字 `clNone`、枠 #A0A0A0 | 背景・文字 `clNone`、枠 #808080 |

- #RRGGBB の色は `RGBToColor(R, G, B)` で入れる（TColor は内部が 青・緑・赤 の順のため）。
- 右端のガイド線は背景と同じ色にして見えなくする。
- csThema のダーク／ライトは `IsOSDarkTheme`（レジストリ `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize` の `AppsUseLightTheme` が 0 ならダーク。値がなければライト）で決める。ほかの色はシステム色にして、MetaDarkStyle などに読み替えを任せる。
- `csVSLight`・`csVSDark` の値は、TCMonacoEditor（Monaco の `vs`・`vs-dark`）と同じ。ただし `csVSDark` の行番号の文字（#6E7681。今の VS Code と同じ）と折りたたみの印（#5A5A5A。Lazarus IDE に近い）は、本文より目立たないように暗くする。カーソル行・選択の色は TCMonacoEditor の既定値（`CursorLineColor…`・`SelectionColor…` の `scStandard`）と同じ。
- `MarkupByClass[...]` が nil のときは何もしない。

#### 7.4.2 色の組

配色ごとに、次の色の組を決める。既存の 4 つは、1.0 の Pascal の色をそのまま組にしたもの。

| 色 | csThema（ダーク） | csThema（ライト） | csBlack | csGray | csWhite | csVSLight | csVSDark |
|---|---|---|---|---|---|---|---|
| 文字（`Text`） | `clWindowText` | `clWindowText` | `clWhite` | `clWhite` | `clBlack` | #000000 | #D4D4D4 |
| 予約語（`Key`） | `RGBToColor(86,156,214)` | `RGBToColor(0,0,255)` | `clWhite` | `clAqua` | `clNavy` | #0000FF | #569CD6 |
| 文字列（`Str`） | `RGBToColor(206,145,120)` | `RGBToColor(163,21,21)` | `clYellow` | `clYellow` | `clBlue` | #A31515 | #CE9178 |
| コメント（`Comment`） | `RGBToColor(106,153,85)` | `RGBToColor(0,128,0)` | `clGray` | `clGreen` | `clGreen` | #008000 | #6A9955 |
| 数値（`Number`） | `RGBToColor(181,206,168)` | `RGBToColor(9,134,88)` | `TColor($008080FF)` | `TColor($008080FF)` | `clPurple` | #098658 | #B5CEA8 |
| 記号（`Symbol`） | 予約語と同じ | 予約語と同じ | 予約語と同じ | 予約語と同じ | 予約語と同じ | #000000 | #D4D4D4 |
| タグ（`Tag`） | 予約語と同じ | 予約語と同じ | 予約語と同じ | 予約語と同じ | 予約語と同じ | #800000 | #569CD6 |
| タグの記号（`TagMark`） | 予約語と同じ | 予約語と同じ | 予約語と同じ | 予約語と同じ | 予約語と同じ | #383838 | #808080 |
| 属性名（`AttrName`） | 文字と同じ | 文字と同じ | 文字と同じ | 文字と同じ | 文字と同じ | #FF0000 | #9CDCFE |
| 属性値（`AttrValue`） | 文字列と同じ | 文字列と同じ | 文字列と同じ | 文字列と同じ | 文字列と同じ | #0000FF | #CE9178 |
| 各属性の背景（`Bg`） | `clNone` | `clNone` | `clBlack` | `clBlack` | `clWhite` | `clNone` | `clNone` |

- 記号を予約語と同じ色にするのは 1.0 の決め方（Pascal の `:=`・`;` など）。`csVSLight`・`csVSDark` は Monaco に合わせて文字と同じ色にする。

#### 7.4.3 色分けの属性への入れ方

**Pascal（`TSynPasSyn`）で、既存の 4 つの配色**：1.0 と同じ（下の表）。ほかの属性には触らない。

| 属性 | 色 |
|---|---|
| `KeyAttri`・`ModifierAttri`・`SymbolAttri` | `Key` |
| `StringAttri` | `Str` |
| `CommentAttri` | `Comment` |
| `NumberAttri` | `Number` |
| `IdentifierAttri` | `Text` |
| 上の 7 つの背景 | `Bg` |
| `KeyAttri.Style`・`CommentAttri.Style`・`ModifierAttri.Style` | `[]` |

**それ以外（Pascal 以外の色分け、または `csVSLight`・`csVSDark`）**：次の順で入れる。

1. すべての属性（`Highlighter.AttrCount` 個の `Highlighter.Attribute[i]`）を、文字色 `Text`・背景 `Bg`・`Style := []` にする（表にない属性が、白い背景向けの既定の色のまま残らないように）。
   - ただし「上書き用の属性」（Lazarus 5.0 の `TLazEditTextAttributeModifier` の子孫。4.8 では `TSynHighlighterAttributesModifier` の子孫）は、文字色・背景・枠を `clNone`、`Style := []` にする。上書き用の属性は、元の属性（コメント・文字列など）の色の上に重ねて使われるため、`Text` を入れると元の色が消える（例：Pascal の `Ansi Comment`・`Curly Comment`・`Slash Comment` が `Comment` の緑を、`String_Singlequote` などが `Str` の色を白で消す）。`clNone` なら元の属性の色がそのまま出る。
   - 上書き用かどうかは、クラスの親をたどり、名前が `TLazEditTextAttributeModifier` か `TSynHighlighterAttributesModifier` のものがあるかで決める（版で分けるコードを作らないため）。
2. どの色分けにもある属性（`GetDefaultAttribute(…)`。nil なら飛ばす）に入れる。`GetDefaultAttribute` は色分けの基のクラスで protected なので、implementation に継承しただけのクラス `THlAccess = class(TSynCustomHighlighter)` を置き、`THlAccess(Highlighter).GetDefaultAttribute(…)` で呼ぶ。`Highlighter` プロパティの型は 5.0 では `TLazEditCustomHighlighter` なので、属性の一覧（`AttrCount`・`Attribute[i]`）も `TSynCustomHighlighter(Highlighter)` にしてから読む。

| 属性 | 色 |
|---|---|
| `SYN_ATTR_COMMENT` | `Comment` |
| `SYN_ATTR_IDENTIFIER` | `Text` |
| `SYN_ATTR_KEYWORD` | `Key` |
| `SYN_ATTR_STRING` | `Str` |
| `SYN_ATTR_SYMBOL` | `Symbol` |
| `SYN_ATTR_NUMBER` | `Number` |
| `SYN_ATTR_DIRECTIVE` | `Comment`（Monaco は Pascal の `{$...}` をコメントの色で出す） |
| `NumberAttri`（published の属性。`IsPublishedProp`・`GetObjectProp` で名前で探す） | `Number`（5.0 の多くの色分けは、数値を `SYN_ATTR_NUMBER` で返さないため） |

3. 色分けごとの属性に入れる（下の表）。

| 色分け | 属性 | 色 |
|---|---|---|
| `TSynPasSyn` | `ModifierAttri` | `Key` |
| `TSynHTMLSyn` | `KeyAttri`・`UndefKeyAttri`・`DOCTYPEAttri` | `Tag` |
| `TSynHTMLSyn` | `IdentifierAttri` | `AttrName` |
| `TSynHTMLSyn` | `ValueAttri` | `AttrValue` |
| `TSynHTMLSyn` | `SymbolAttri` | `TagMark` |
| `TSynHTMLSyn` | `AndAttri` | `Key` |
| `TSynHTMLSyn` | `TextAttri` | `Text` |
| `TSynXMLSyn` | `ElementAttri`・`ProcessingInstructionAttri`・`DocTypeAttri` | `Tag` |
| `TSynXMLSyn` | `AttributeAttri`・`NamespaceAttributeAttri` | `AttrName` |
| `TSynXMLSyn` | `AttributeValueAttri`・`NamespaceAttributeValueAttri` | `AttrValue` |
| `TSynXMLSyn` | `SymbolAttri` | `TagMark` |
| `TSynXMLSyn` | `CDATAAttri` | `Str` |
| `TSynXMLSyn` | `EntityRefAttri` | `Key` |
| `TSynCssSyn` | `SelectorAttri` | `Tag` |
| `TSynCssSyn` | `KeyAttri`（プロパティの名前） | `AttrName` |
| `TCSynMarkdownSyn` | 9.3 の表 | 9.3 の表 |

- 属性の名前は Lazarus 5.0 RC1 の SynEdit のソースに合わせる（コンパイルで確かめる）。名前が違っていたら、意味が同じ属性に入れる。

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

- この 3 つは `inherited KeyDown`（その中で `OnKeyDown` が呼ばれる）より前に処理する。そのため、この部品の `OnKeyDown` では止められない。止めるときは、フォームの `KeyPreview = True` にして、フォームの `OnKeyDown` で `Key := 0` にする（取説 7.2 の注意をこの形に直す）。
- TCsEditor は、継承した部品の `KeyDown` で先に受けるので、この 3 つの処理には届かない（`TCsEditor_Design.md` 6.2）。

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
- TCsEditor は、このメニューを使わない（TCsEditor が自分のメニューを入れる。`TCsEditor_Design.md` 7章）。

## 9. Markdown の色分け（TCSynMarkdownSyn）

### 9.1 クラス

- 属性の型は `TSynHighlighterAttributes`（4.8 の名前。5.0 では警告が出るが、そのまま通る）。`GetTokenAttribute` の戻り値も `TSynHighlighterAttributes`。

```pascal
TCSynMarkdownSyn = class(TSynCustomHighlighter)
private
  FLine: PChar; FLineLen: Integer;           // 今の行
  FPos, FTokenPos: Integer;                  // 今の位置・字句の始まり
  FTokenKind: TCMdTokenKind;                 // 今の字句の種類
  FRange: TCMdRange;                         // 行の頭の状態
  FLineMode: TCMdTokenKind;                  // 行全体が 1 つの種類のときの種類（なければ mtText）
  FHeadingAttri, FStrongAttri, FEmphasisAttri, FCodeAttri, FQuoteAttri,
  FListAttri, FLinkAttri, FRuleAttri, FTextAttri, FSpaceAttri: TSynHighlighterAttributes;
public
  constructor Create(AOwner: TComponent); override;
  class function GetLanguageName: string; override;          // 'Markdown'
  procedure SetLine(const NewValue: string; LineNumber: Integer); override;
  procedure Next; override;
  function GetEol: Boolean; override;
  function GetToken: string; override;
  procedure GetTokenEx(out TokenStart: PChar; out TokenLength: integer); override;
  function GetTokenAttribute: TSynHighlighterAttributes; override;
  function GetTokenKind: integer; override;
  function GetTokenPos: Integer; override;
  function GetDefaultAttribute(Index: integer): TSynHighlighterAttributes; override;
  function GetRange: Pointer; override;
  procedure SetRange(Value: Pointer); override;
  procedure ResetRange; override;
published
  property HeadingAttri, StrongAttri, EmphasisAttri, CodeAttri, QuoteAttri,
    ListAttri, LinkAttri, RuleAttri, TextAttri, SpaceAttri: TSynHighlighterAttributes;
end;

TCMdRange = (mrNormal, mrFence);              // 普通 / コードブロックの中
TCMdTokenKind = (mtText, mtSpace, mtHeading, mtStrong, mtEmphasis, mtCode,
  mtQuote, mtList, mtLink, mtRule);
```

- 状態（Range）は `Pointer(PtrInt(Ord(FRange)))` で SynEdit に預ける（行ごとに覚えられる）。
- 折りたたみは持たない。
- `GetDefaultAttribute`：`SYN_ATTR_COMMENT` → `FQuoteAttri`、`SYN_ATTR_IDENTIFIER` → `FTextAttri`、`SYN_ATTR_KEYWORD` → `FHeadingAttri`、`SYN_ATTR_STRING` → `FCodeAttri`、`SYN_ATTR_WHITESPACE` → `FSpaceAttri`、`SYN_ATTR_SYMBOL` → `FListAttri`。ほかは nil。

### 9.2 分け方

**行の頭で決めるもの**（`SetLine` で決める。行の頭の空白は 3 個まで許す）

| 順 | 状態・行の形 | 行全体の種類 | 次の行の状態 |
|---|---|---|---|
| 1 | 状態が `mrFence` で、` ``` ` か `~~~` で始まる | コード | `mrNormal` |
| 2 | 状態が `mrFence` | コード | `mrFence` |
| 3 | ` ``` ` か `~~~` で始まる | コード | `mrFence` |
| 4 | `#` が 1〜6 個続き、その後ろが空白か行の終わり | 見出し | `mrNormal` |
| 5 | `-`・`*`・`_` のどれか 1 種類だけが 3 個以上（間の空白は可）で、ほかの文字がない | 罫線 | `mrNormal` |
| 6 | `>` で始まる | 引用 | `mrNormal` |
| 7 | それ以外 | 下の「行の中」で分ける | `mrNormal` |

- 1〜6 は、行全体を 1 つの字句にする（`FLineMode`）。

**行の中**（7 のとき、先頭から順に）

| 形 | 種類 |
|---|---|
| 行の頭（空白の後ろ）の `-`・`*`・`+` に空白が続くもの、数字の後ろに `.` か `)` と空白が続くもの | リストの印（印と後ろの空白 1 つ） |
| 空白・タブが続く所 | 空白 |
| `` ` `` で始まり、同じ数の `` ` `` で閉じる所（閉じなければ行の終わりまで） | コード |
| `**`・`__` で始まり、同じ記号で閉じる所 | 太字 |
| `*`・`_` で始まり、同じ記号で閉じる所（`_` は前が英数字でないときだけ） | 斜体 |
| `[` で始まり `](` … `)` で閉じる所、`<http` で始まり `>` で閉じる所 | リンク |
| それ以外（次のどれかの記号・空白の手前まで） | 文字 |

- 閉じる記号が同じ行にないときは、始まりの記号だけを文字として扱う（コードを除く）。
- 太字・斜体・リンクの中は、さらに分けない。
- 表・見出しの下線（`===`・`---`）・4 つの空白で始まるコードは、特別に扱わない。

### 9.3 色（7.4.2 の色の組から）

| 属性 | 色 | Style |
|---|---|---|
| `HeadingAttri`（見出し） | `Key` | `[]` |
| `StrongAttri`（太字） | `Text` | `[fsBold]` |
| `EmphasisAttri`（斜体） | `Text` | `[fsItalic]` |
| `CodeAttri`（コード） | `Str` | `[]` |
| `QuoteAttri`（引用） | `Comment` | `[]` |
| `ListAttri`（リストの印） | `Key` | `[]` |
| `LinkAttri`（リンク） | `Str` | `[]` |
| `RuleAttri`（罫線） | `Key` | `[]` |
| `TextAttri`・`SpaceAttri` | `Text` | `[]` |
| 背景 | `Bg` | ― |

- 7.4.3 の手順 1 で `Style := []` にしてから、この表を入れる（太字・斜体はこの表で付く）。

## 10. 不具合を調べるときの見どころ

| 症状 | 見る場所 |
|---|---|
| コードで作ったときに配色が当たらない | `Create` では `ApplyEditStyle` を呼ばない（6章）。`EditStyle` を別の値にしたとき、`Loaded` のとき、`Language` を変えたときに当たる |
| ファイルを開いたあと、色分けの配色が既定の色になる | `SetLanguage` の最後の `ApplyEditStyle`（7.2） |
| 開くたびにメモリが増える | `SetLanguage` で古い色分けを壊しているか（Owner が自分のものだけ。7.2） |
| アプリが入れた色分けが消える | `SetLanguage` が Owner を見ているか（7.2）。拡張子で切り替えたくないときは `Highlighter` をファイル名の後で入れ直す |
| 黒い背景に暗い色の文字が出る | 7.4.3 の手順 1（すべての属性を文字色にする）。属性の名前（7.4.3 の表）が SynEdit と合っているか |
| 左端の欄の一部（折りたたみ・変更行の印）だけ白い | 7.4.1 の `CodeFoldPart`・`ChangesPart`。`csVSLight`・`csVSDark` 以外は 1.0 と同じで、折りたたみの欄に色を入れていない |
| カーソル行の色分けが消える | `LineHighlightColor.Foreground` が `clNone` か（7.4.1） |
| Markdown の色がおかしい | 9.2 の分け方。`SetLine` の行の頭の判定と、状態（`mrFence`）の受け渡し |
| ほかのアプリでファイルを保存できない | `LockFile`（7.3） |
| ドロップしても開かない | `CreateWnd` のサブクラス化、`DoDropFiles`（7.10） |
| イベントの引数を変えても反映されない | 7.6 の表で「部品に入れる」ものかどうか |
| Ctrl+S などが効かない・止められない | `KeyDown`（7.8）。部品の `OnKeyDown` より先に処理する |

## 11. この版の変更（1.0 → 1.1）

コードを作るための手順。取説には入れない。

| No | 項目 | 今（1.0） | 変更後（1.1） | 変える理由 | リスク |
|---|---|---|---|---|---|
| 1 | 配色 | `csBlack`・`csGray`・`csWhite`・`csThema` の 4 つ | `csVSLight`・`csVSDark` を足す（7.4） | TCsEditor の配色を TCMonacoEditor（VS Code）と同じにするため | 既存の 4 つは変わらない（`ChangesPart.Visible := True` を足すだけ） |
| 2 | 色分けの切り替え | `FileName` を設定するたびに新しい色分けを作り、古いものは残す。配色を当て直さない | 同じ種類なら作り直さない。違えば自分の作った古いものを壊して作る。最後に `ApplyEditStyle`（7.2） | 開いた後に配色が既定の色に戻る・開くたびにメモリが増えるため | アプリが自分で入れた色分けは壊さない（Owner を見る）。「開いた後は既定の色」を前提にしたアプリは見た目が変わる |
| 3 | 拡張子と色分け | 下の表の「今」 | TCMonacoEditor と同じ表で言語を決め、言語から色分けを決める（`CSLanguageForFile`・`Language`。3章・7.1・7.2） | TCsEditor と同じ決め方にするため。.md を HTML で色分けしていたのは合っていなかったため | 下の表の拡張子は、色分けが変わる |
| 4 | Pascal 以外の配色 | 色分けの配色は Pascal のときだけ | どの色分けにも、その配色の色を入れる（7.4.2・7.4.3） | 黒い背景で HTML などが読みにくかったため | Pascal 以外のファイルの色が変わる |
| 5 | Markdown の色分け | なし（HTML で代用） | `TCSynMarkdownSyn` を作る（9章） | Markdown を主に扱うため | 簡単な分け方（9.2）なので、Markdown のすべての書き方は区別しない |
| 6 | `ApplyEditStyle` | private | protected virtual（5.3） | TCsEditor の中の部品が、カーソル行などの色を足すため | なし（動きは変わらない） |
| 7 | `Language` | なし | public のプロパティ（5.2・7.2） | TCsEditor が言語を決めるため | なし |
| 8 | 取説 7.2 の注意 | 「`OnKeyDown` で `Key := 0` にすると部品の動作が止まる」 | 「フォームの `KeyPreview` と `OnKeyDown` で止める」（7.8） | コードの動き（`OnKeyDown` より先に処理する）と合っていなかったため | 取説だけの変更（コードは変えない） |
| 9 | 動作環境 | Lazarus 4.8・5.0 RC1 | 5.0 以降。4.8 は cx のコンパイルが通るだけ（1章）。版で分けるコードはない | 5.0 の SynEdit が変わったため | 4.8 で TCSynEdit を使ったアプリは、動作を保証しない。5.0 で「古い書き方」の警告が出る |
| 10 | 使っていない自分の色分け | 残る | 言語を切り替えたときに壊す（7.2） | アプリが自分の色分けを入れたとき、最初の色分けが残っていたため | なし |
| 11 | 数値の色 | Pascal だけ | `NumberAttri` がある色分けすべて（7.4.3） | 5.0 の色分けの多くは、数値を「どの色分けにもある属性」で返さないため | なし |
| 12 | 上書き用の属性 | 手順 1 で `Text` の色を入れる | `clNone` にする（7.4.3 の手順 1） | Pascal のコメント・文字列が白になり、色分けされなかったため | Pascal の宣言部の名前など、上書き用の属性で色が決まっていた部分は、元の属性の色になる。`csVSLight` も同じく直る |
| 13 | `csVSDark` の行番号・折りたたみの印 | 行番号 #858585・印 #C5C5C5 | 行番号 #6E7681・印 #5A5A5A（7.4.1） | 本文より目立ち、Lazarus IDE より明るかったため | 見た目だけ（ほかの配色は変わらない） |

**No.3 の拡張子ごとの違い**

| 拡張子 | 今（1.0） | 変更後（1.1） |
|---|---|---|
| .pas .pp .lpr .dpr、拡張子なし | Pascal | Pascal |
| .inc .lpk | 切り替えない | Pascal |
| .txt | Pascal | なし |
| .md .markdown | HTML | Markdown |
| .html .htm | HTML | HTML |
| .json | HTML | JavaScript |
| .csv | HTML | 切り替えない |
| .yaml .yml | HTML | なし |
| .xml | XML | XML |
| .css .js .sql .ini .cfg .bat .cmd .py .c .h .cpp .hpp .cs .ts .tsx .java .sh .bash .php | 切り替えない | それぞれの色分け（7.2 の表） |
| .ps1 .psm1 .psd1 .go | 切り替えない | なし |

**ファイルごとの変更**

| ファイル | 変更 |
|---|---|
| `cSynedit.pas` | 上の No.1〜7。uses に 2章の色分けのユニットを足す |
| `uCXReg.pas`・`cx_icons.lrs` | 変更なし |
| 取説 `TCSynEdit_Usage.md` | 3章（配色 2 つ）、4章（拡張子の表）、5.1（`Language`）、7.2 の注意（No.8）。取説は最後に直す |
