{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ cSynEdit（TCSynEdit 1.1。TCSynEdit_Design.md 1.1）
  SynEdit をもとにしたテキストエディタ。1.1 版で足したもの：
  ・配色 csVSLight・csVSDark（VS Code・TCMonacoEditor と同じ色）
  ・言語（Language）と、拡張子から言語を決める CSLanguageForFile（TCMonacoEditor と同じ表）
  ・色分けを入れ替えても配色を保つ（入れ替えのたびに ApplyEditStyle）。古い色分けは壊す
  ・Pascal 以外の色分けにも、その配色の色を入れる
  ・Markdown の色分け TCSynMarkdownSyn
  動作環境：Lazarus 5.0 以降。4.8 はコンパイルが通るだけ（版で分けるコードはない）。
  5.0 では TSynHighlighterAttributes・SYN_ATTR_…・SetLine・SetRange が「古い書き方」の警告になるが、動きは同じ。 }
unit csynedit;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  Graphics,
  Menus,
  LCLType,
  LCLIntf,
  Clipbrd,
  LazUTF8,
  Math,
  SynEdit,
  SynEditKeyCmds,
  SynEditHighlighter,
  SynEditTypes,
  SynGutterLineNumber,
  SynEditMarkup,
  SynEditMarkupWordGroup,
  SynEditMarkupHighAll,
  SynHighlighterPas,
  SynHighlighterHTML,
  SynHighlighterXML,
  SynHighlighterCss,
  SynHighlighterJScript,
  SynHighlighterSQL,
  SynHighlighterIni,
  SynHighlighterBat,
  SynHighlighterPython,
  SynHighlighterCpp,
  SynHighlighterJava,
  SynHighlighterUNIXShellScript,
  SynHighlighterPHP,
  Registry;

type
  { エディタスタイル定義 }
  TCEditStyle = (csBlack, csGray, csWhite, csThema, csVSLight, csVSDark);   // 設計書 3章。VS の 2 つは 1.1 で足した

  { 文字コード種別定義 }
  TCFileEncoding = (feUTF8, feANSI_SJIS, feUTF16LE, feUTF16BE, feEUCJP);

  { 改行コード種別定義 }
  TCLineEnding = (leCRLF, leLF, leCR);

  { テキスト変更通知用イベント型（リアルタイムプレビュー連携用） }
  TCSynTextChangeEvent = procedure(Sender: TObject; const AText: string) of object;

  { 1: FileName変更時用イベント型（var引数） }
  TOnFileNameChangeEvent = procedure(Sender: TObject; var sFileName: String) of object;

  { 2: ファイル読込完了時用イベント型（var引数） }
  TOnLoadFromFileEvent = procedure(Sender: TObject; var sFileName: String) of object;

  { 3: ファイル書込完了時用イベント型（var引数） }
  TOnSaveToFileEvent = procedure(Sender: TObject; var sFileName: String) of object;

  { 4: InsMode変更時用イベント型（var引数） }
  TOnInsModeChangeEvent = procedure(Sender: TObject; var bMode: Boolean) of object;

  { 5: カーソル移動時用イベント型（var引数） }
  TOnCaretChangeEvent = procedure(Sender: TObject; var iX, iY: Integer) of object;

  { 6: Undo/Redo可能状態変更時用イベント型（var引数） }
  TOnUndoRedoStateChangeEvent = procedure(Sender: TObject; var bCanUndo, bCanRedo: Boolean) of object;

  { 7: Modified（変更フラグ）状態変更時用イベント型（var引数） }
  TOnModifiedChangeEvent = procedure(Sender: TObject; var bModified: Boolean) of object;

  { 8: 選択範囲変更時用イベント型（var引数） }
  TOnSelectionChangeEvent = procedure(Sender: TObject; var sSelText: String; var iStartX, iStartY, iEndX, iEndY: Integer) of object;

  { 9: フォーカス変更時用イベント型（var引数） }
  TOnFocusChangeEvent = procedure(Sender: TObject; var bFocused: Boolean) of object;

  { 10: ファイルドロップ時用イベント型 }
  TOnDropFilesEvent = procedure(Sender: TObject; const AFiles: array of string) of object;


  { 9.1 Markdown の行の頭の状態。普通 / コードブロック（``` か ~~~ の中） }
  TCMdRange = (mrNormal, mrFence);

  { 9.1 Markdown の字句の種類 }
  TCMdTokenKind = (mtText, mtSpace, mtHeading, mtStrong, mtEmphasis, mtCode,
    mtQuote, mtList, mtLink, mtRule);

  { 9.1 Markdown の色分け。
    SetLine で 1 行を字句に分けて FToks に並べ、Next で 1 つずつ進める。
    行の後の状態（コードブロックの中か）は GetRange で SynEdit に預ける。 }

  { TCSynMarkdownSyn }

  TCSynMarkdownSyn = class(TSynCustomHighlighter)
  private
    type
      TTok = record
        Pos, Len: Integer;          // 行の中の位置（0 から）と長さ（バイト）
        Kind: TCMdTokenKind;
      end;
  private
    FLineStr: string;               // 今の行（GetTokenEx が指すので、行の写しを持つ）
    FLine: PChar;
    FLineLen: Integer;
    FTokenPos: Integer;             // 今の字句の始まり（0 から）
    FTokenKind: TCMdTokenKind;      // 今の字句の種類
    FRange: TCMdRange;              // SetLine の前：行の頭の状態。SetLine の後：次の行の頭の状態
    FLineMode: TCMdTokenKind;       // 行全体が 1 つの種類のときの種類（なければ mtText）
    FToks: array of TTok;           // 行の字句
    FTokCount: Integer;
    FTokIndex: Integer;             // 今の字句の番号
    FHeadingAttri, FStrongAttri, FEmphasisAttri, FCodeAttri, FQuoteAttri,
    FListAttri, FLinkAttri, FRuleAttri, FTextAttri, FSpaceAttri: TSynHighlighterAttributes;
    procedure AddTok(APos, ALen: Integer; AKind: TCMdTokenKind);
    procedure ScanInline(AFrom: Integer);
    function AttriOf(AKind: TCMdTokenKind): TSynHighlighterAttributes;
  public
    constructor Create(AOwner: TComponent); override;
    class function GetLanguageName: string; override;
    procedure SetLine(const NewValue: String; LineNumber: Integer); override;
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
    property HeadingAttri: TSynHighlighterAttributes read FHeadingAttri;
    property StrongAttri: TSynHighlighterAttributes read FStrongAttri;
    property EmphasisAttri: TSynHighlighterAttributes read FEmphasisAttri;
    property CodeAttri: TSynHighlighterAttributes read FCodeAttri;
    property QuoteAttri: TSynHighlighterAttributes read FQuoteAttri;
    property ListAttri: TSynHighlighterAttributes read FListAttri;
    property LinkAttri: TSynHighlighterAttributes read FLinkAttri;
    property RuleAttri: TSynHighlighterAttributes read FRuleAttri;
    property TextAttri: TSynHighlighterAttributes read FTextAttri;
    property SpaceAttri: TSynHighlighterAttributes read FSpaceAttri;
  end;

  { TCSynEdit コンポーネント定義 }
  TCSynEdit = class(TSynEdit)
  private
    FFileName: string;
    FEditStyle: TCEditStyle;
    FLanguage: string;          // 今の言語（7.2）。既定 'pascal'
    FEncodingType: TCFileEncoding;
    FHasBOM: Boolean;
    FLineEndingType: TCLineEnding;
    FOnTextChange: TCSynTextChangeEvent;
    FOnFileNameChange: TOnFileNameChangeEvent;
    FOnLoadFromFile: TOnLoadFromFileEvent;
    FOnSaveToFile: TOnSaveToFileEvent;
    FOnInsModeChange: TOnInsModeChangeEvent;
    FOnCaretChange: TOnCaretChangeEvent;
    FOnUndoRedoStateChange: TOnUndoRedoStateChangeEvent;
    FOnModifiedChange: TOnModifiedChangeEvent;
    FOnSelectionChange: TOnSelectionChangeEvent;
    FOnFocusChange: TOnFocusChangeEvent;
    FOnDropFiles: TOnDropFilesEvent;
    FPopupMenu: TPopupMenu;
    FFileStream: TFileStream;   // ファイル排他ロック用ストリーム
    FLoadingFlag: Boolean;      // Loaded 再帰防止フラグ
    FOldInsertMode: Boolean;    // InsMode 変更検知用の状態保持
    FOldCaretX: Integer;        // CaretX 変更検知用
    FOldCaretY: Integer;        // CaretY 変更検知用
    FOldCanUndo: Boolean;       // CanUndo 変更検知用
    FOldCanRedo: Boolean;       // CanRedo 変更検知用
    FOldModified: Boolean;      // Modified 変更検知用
    FOldSelText: string;        // SelText 変更検知用

    { 動的制御用メニュー項目参照 }
    FMenuItemCut: TMenuItem;
    FMenuItemCopy: TMenuItem;
    FMenuItemPaste: TMenuItem;
    FMenuItemQuoteCopy: TMenuItem;
    FMenuItemAppendCut: TMenuItem;
    FMenuItemAppendCopy: TMenuItem;
    FMenuItemDelete: TMenuItem;
    FMenuItemUpperCase: TMenuItem;
    FMenuItemLowerCase: TMenuItem;
    FMenuItemToHalf: TMenuItem;
    FMenuItemToHiragana: TMenuItem;
    FMenuItemToKatakana: TMenuItem;
    FMenuItemTabToSpace: TMenuItem;
    FMenuItemSpaceToTab: TMenuItem;

    procedure SetFileName(const AValue: string);
    procedure SetEditStyle(const AValue: TCEditStyle);
    procedure ApplyGutterBackground;
    procedure SetInsModeValue(const AValue: Boolean);
    function GetInsModeValue: Boolean;
    function GetCaretYValue: Integer;
    procedure SetCaretYValue(const AValue: Integer);
    function GetCaretXValue: Integer;
    procedure SetCaretXValue(const AValue: Integer);
    function GetDisplayTitle: string;

    procedure SetLanguage(const AValue: string);
    procedure AutoSelectHighlighter(const APath: string);
    procedure ApplyHighlighterColors;
    procedure CreateHidemaruLikePopupMenu;
    procedure LockFile(const APath: string);
    procedure UnlockFile;

    { ポップアップメニュー表示直前イベントハンドラ }
    procedure OnPopupMenuPopup(Sender: TObject);

    { ポップアップメニュー用イベントハンドラ }
    procedure OnMenuCutClick({%H-}Sender: TObject);
    procedure OnMenuCopyClick({%H-}Sender: TObject);
    procedure OnMenuPasteClick({%H-}Sender: TObject);
    procedure OnMenuQuoteCopyClick({%H-}Sender: TObject);     // 引用付きコピー
    procedure OnMenuAppendCutClick({%H-}Sender: TObject);     // 追加切り抜き
    procedure OnMenuAppendCopyClick({%H-}Sender: TObject);    // 追加コピー
    procedure OnMenuDeleteClick({%H-}Sender: TObject);
    procedure OnMenuUpperCaseClick({%H-}Sender: TObject);     // 大文字変換
    procedure OnMenuLowerCaseClick({%H-}Sender: TObject);     // 小文字変換
    procedure OnMenuToHalfClick({%H-}Sender: TObject);        // ハンカクに変換
    procedure OnMenuToHiraganaClick({%H-}Sender: TObject);    // 全角ひらがなに変換
    procedure OnMenuToKatakanaClick({%H-}Sender: TObject);    // 全角カタカナに変換
    procedure OnMenuTabToSpaceClick({%H-}Sender: TObject);    // TAB -> 空白 変換
    procedure OnMenuSpaceToTabClick({%H-}Sender: TObject);    // 空白 -> TAB 変換
    procedure OnMenuIndentClick({%H-}Sender: TObject);        // インデント
    procedure OnMenuUnindentClick({%H-}Sender: TObject);      // 逆インデント
    procedure OnMenuSelectAllClick({%H-}Sender: TObject);

  protected
    { 7.4 配色を当てる。継承した部品（TCsEditor の中の部品）が色を足せるように protected virtual }
    procedure ApplyEditStyle; virtual;

    { 1: FileName変更通知用メソッド }
    procedure OnFileNameChange(var sFileName: String); virtual;

    { 2: ファイル読込完了通知用メソッド }
    procedure OnLoadFromFile(var sFileName: String); virtual;

    { 3: ファイル書込完了通知用メソッド }
    procedure OnSaveToFile(var sFileName: String); virtual;

    { 4: InsMode変更通知用メソッド }
    procedure OnInsModeChange(var bMode: Boolean); virtual;

    { 5: カーソル移動通知用メソッド }
    procedure OnCaretChange(var iX, iY: Integer); virtual;

    { 6: Undo/Redo可能状態変更通知用メソッド }
    procedure OnUndoRedoStateChange(var bCanUndo, bCanRedo: Boolean); virtual;

    { 7: Modified状態変更通知用メソッド }
    procedure OnModifiedChange(var bModified: Boolean); virtual;

    { 8: 選択範囲変更通知用メソッド }
    procedure OnSelectionChange(var sSelText: String; var iStartX, iStartY, iEndX, iEndY: Integer); virtual;

    { 9: フォーカス変更通知用メソッド }
    procedure OnFocusChange(var bFocused: Boolean); virtual;

    { フォーカス関連のオーバーライド }
    procedure DoEnter; override;
    procedure DoExit; override;

    { 状態変更通知イベントのオーバーライド（テキスト、InsMode、Caret位置、Undo/Redo、Modified、Selectionの検知） }
    procedure StatusChanged(AChanges: TSynStatusChanges); override;

    { キーボード & マウスオーバーライド }
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    function DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint): Boolean; override;
    function DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean; override;

    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure DoDropFiles(const AFiles: array of string); virtual;

    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { ファイル入出力メソッド }
    procedure LoadFromFile(const AFileName: string);
    procedure SaveToFile(const AFileName: string);
    procedure Save; // Ctrl+S 上書き保存用

    { カーソル行複製挿入 (Shift+F10 用) }
    procedure DuplicateCurrentLine;

    { 行番号表示トグル (F12 用) }
    procedure ToggleLineNumbers;

    { 1. API / メソッド（マクロ・AI用） }
    procedure InsertTextAtCaret(const AText: string);
    procedure ReplaceSelection(const AText: string);
    procedure SetCaretPosition(const AX, AY: Integer);
    procedure SelectLine(const ALineIndex: Integer);
    procedure SelectRange(const AStartX, AStartY, AEndX, AEndY: Integer);

    { ★ 4. 検索・置換メソッド }
    function SearchText(const ASearchStr: string; ACaseSensitive, AWholeWord, AForward: Boolean): Boolean;
    function ReplaceText(const ASearchStr, AReplaceStr: string; ACaseSensitive, AWholeWord: Boolean): Boolean;
    function ReplaceAllText(const ASearchStr, AReplaceStr: string; ACaseSensitive, AWholeWord: Boolean): Integer;

    { タブ等での表示用短縮タイトル（読み取り専用） }
    property DisplayTitle: string read GetDisplayTitle;

    { 7.2 言語（'pascal'・'markdown' など）。書くと、その言語の色分けに切り替えて配色を当て直す }
    property Language: string read FLanguage write SetLanguage;

  published
    { 仕様に基づくプロパティ }
    property FileName: string read FFileName write SetFileName;
    property EditStyle: TCEditStyle read FEditStyle write SetEditStyle default csGray;
    property InsMode: Boolean read GetInsModeValue write SetInsModeValue default True;

    { 文字コード・改行コード保持用プロパティ }
    property EncodingType: TCFileEncoding read FEncodingType write FEncodingType default feUTF8;
    property HasBOM: Boolean read FHasBOM write FHasBOM default False;
    property LineEndingType: TCLineEnding read FLineEndingType write FLineEndingType default leCRLF;

    { 行・桁プロパティ }
    property CaretY: Integer read GetCaretYValue write SetCaretYValue;
    property CaretX: Integer read GetCaretXValue write SetCaretXValue;

    { リアルタイムプレビュー連携イベント }
    property OnTextChange: TCSynTextChangeEvent read FOnTextChange write FOnTextChange;

    { 1: FileName変更時イベントプロパティ }
    property OnFileNameChangeEvent: TOnFileNameChangeEvent read FOnFileNameChange write FOnFileNameChange;

    { 2: ファイル読込完了時イベントプロパティ }
    property OnLoadFromFileEvent: TOnLoadFromFileEvent read FOnLoadFromFile write FOnLoadFromFile;

    { 3: ファイル書込完了時イベントプロパティ }
    property OnSaveToFileEvent: TOnSaveToFileEvent read FOnSaveToFile write FOnSaveToFile;

    { 4: InsMode変更時イベントプロパティ }
    property OnInsModeChangeEvent: TOnInsModeChangeEvent read FOnInsModeChange write FOnInsModeChange;

    { 5: カーソル移動時イベントプロパティ }
    property OnCaretChangeEvent: TOnCaretChangeEvent read FOnCaretChange write FOnCaretChange;

    { 6: Undo/Redo可能状態変更時イベントプロパティ }
    property OnUndoRedoStateChangeEvent: TOnUndoRedoStateChangeEvent read FOnUndoRedoStateChange write FOnUndoRedoStateChange;

    { 7: Modified状態変更時イベントプロパティ }
    property OnModifiedChangeEvent: TOnModifiedChangeEvent read FOnModifiedChange write FOnModifiedChange;

    { 8: 選択範囲変更時イベントプロパティ }
    property OnSelectionChangeEvent: TOnSelectionChangeEvent read FOnSelectionChange write FOnSelectionChange;

    { 9: フォーカス変更時イベントプロパティ }
    property OnFocusChangeEvent: TOnFocusChangeEvent read FOnFocusChange write FOnFocusChange;
    property OnDropFilesEvent: TOnDropFilesEvent read FOnDropFiles write FOnDropFiles;
  end;

{ 3章 拡張子から言語の名前を返す（TCMonacoEditor の LanguageForFile と同じ表）。表にない拡張子は ADefault }
function CSLanguageForFile(const AFileName, ADefault: string): string;

implementation

uses
  uCXLang,
  TypInfo,                // NumberAttri を名前で探す（7.4.3）
  StrUtils                // PosEx（Markdown の色分け）
  {$IFDEF WINDOWS}, Windows, ShellAPI{$ENDIF};

{$IFDEF WINDOWS}

function SetWindowSubclass(hWnd: HWND; pfnSubclass: Pointer; uIdSubclass: UINT_PTR;
  dwRefData: DWORD_PTR): BOOL; stdcall; external 'comctl32.dll';
function RemoveWindowSubclass(hWnd: HWND; pfnSubclass: Pointer;
  uIdSubclass: UINT_PTR): BOOL; stdcall; external 'comctl32.dll';
function DefSubclassProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM;
  lParam: LPARAM): LRESULT; stdcall; external 'comctl32.dll';

const
  DROP_SUBCLASS_ID = 1;

function DropSubclassProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM;
  uIdSubclass: UINT_PTR; dwRefData: DWORD_PTR): LRESULT; stdcall;
var
  hDrop_: HDROP;
  Cnt, I, Len: UINT;
  WBuf: UnicodeString;
  Files: array of string;
begin
  if uMsg = WM_DROPFILES then
  begin
    hDrop_ := HDROP(wParam);
    Cnt := DragQueryFileW(hDrop_, $FFFFFFFF, nil, 0);
    SetLength(Files, Cnt);
    for I := 0 to Cnt - 1 do
    begin
      Len := DragQueryFileW(hDrop_, I, nil, 0);
      SetLength(WBuf, Len);
      DragQueryFileW(hDrop_, I, PWideChar(WBuf), Len + 1);
      Files[I] := UTF8Encode(WBuf);
    end;
    DragFinish(hDrop_);
    TCSynEdit(dwRefData).DoDropFiles(Files);
    Exit(0);
  end;

  if uMsg = WM_NCDESTROY then
    RemoveWindowSubclass(hWnd, @DropSubclassProc, DROP_SUBCLASS_ID);

  Result := DefSubclassProc(hWnd, uMsg, wParam, lParam);
end;
{$ENDIF}

function IsOSDarkTheme: Boolean;
var
  Reg: TRegistry;
begin
  Result := False;
  Reg := TRegistry.Create;  // RootKey の既定は HKEY_CURRENT_USER
  try
    if Reg.OpenKeyReadOnly('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize') and
       Reg.ValueExists('AppsUseLightTheme') then
      Result := (Reg.ReadInteger('AppsUseLightTheme') = 0);
  finally
    Reg.Free;
  end;
end;

{ ------------------------------------------------------------------ }
{ 3章 拡張子から言語                                                   }
{ ------------------------------------------------------------------ }

function CSLanguageForFile(const AFileName, ADefault: string): string;
var
  E: string;
begin
  E := LowerCase(ExtractFileExt(AFileName));
  if (E = '.pas') or (E = '.pp') or (E = '.lpr') or (E = '.inc') or (E = '.dpr') or (E = '.lpk') then Result := 'pascal'
  else if (E = '.md') or (E = '.markdown') then Result := 'markdown'
  else if E = '.txt' then Result := 'plaintext'
  else if (E = '.html') or (E = '.htm') then Result := 'html'
  else if E = '.css' then Result := 'css'
  else if E = '.js' then Result := 'javascript'
  else if E = '.json' then Result := 'json'
  else if E = '.xml' then Result := 'xml'
  else if E = '.sql' then Result := 'sql'
  else if (E = '.ini') or (E = '.cfg') then Result := 'ini'
  else if (E = '.bat') or (E = '.cmd') then Result := 'bat'
  else if E = '.py' then Result := 'python'
  else if (E = '.c') or (E = '.h') or (E = '.cpp') or (E = '.hpp') then Result := 'cpp'
  else if E = '.cs' then Result := 'csharp'
  else if (E = '.ts') or (E = '.tsx') then Result := 'typescript'
  else if E = '.java' then Result := 'java'
  else if (E = '.sh') or (E = '.bash') then Result := 'shell'
  else if (E = '.ps1') or (E = '.psm1') or (E = '.psd1') then Result := 'powershell'
  else if (E = '.yml') or (E = '.yaml') then Result := 'yaml'
  else if E = '.php' then Result := 'php'
  else if E = '.go' then Result := 'go'
  else Result := ADefault;
end;

{ ------------------------------------------------------------------ }
{ 7.4 配色の道具                                                       }
{ ------------------------------------------------------------------ }

type
  { GetDefaultAttribute は色分けの基のクラスで protected なので、継承しただけのクラスを通して呼ぶ（7.4.3） }
  THlAccess = class(TSynCustomHighlighter);

  { 7.4.2 色の組 }
  TCSynPalette = record
    Text, Key, Str, Comment, Number, Symbol, Tag, TagMark, AttrName, AttrValue, Bg: TColor;
  end;

{ '#RRGGBB' の色を TColor にする（TColor は内部が 青・緑・赤 の順） }
function HexColor(R, G, B: Byte): TColor; inline;
begin
  Result := RGBToColor(R, G, B);
end;

{ 7.4.1 csVSLight・csVSDark の本文・左端の欄・カーソル行など（TCMonacoEditor と同じ色） }
procedure ApplyVSStyle(E: TCSynEdit; ADark: Boolean);
var
  Bg, Fg, LineNo, LineNoCur, FoldMark, CurLine, Sel, Bracket, WordBg, Folded: TColor;
  M: TSynEditMarkup;
begin
  if ADark then
  begin
    Bg := HexColor($1E, $1E, $1E);        Fg := HexColor($D4, $D4, $D4);
    LineNo := HexColor($6E, $76, $81);    LineNoCur := HexColor($C6, $C6, $C6);   // 行番号は本文より暗く（VS Code と同じ）
    FoldMark := HexColor($5A, $5A, $5A);  CurLine := HexColor($2C, $31, $3C);   // 折りたたみの印も暗く（Lazarus IDE に近い）
    Sel := HexColor($26, $4F, $78);       Bracket := HexColor($88, $88, $88);
    WordBg := HexColor($47, $47, $47);    Folded := HexColor($80, $80, $80);
  end
  else
  begin
    Bg := HexColor($FF, $FF, $FE);        Fg := HexColor($00, $00, $00);
    LineNo := HexColor($23, $78, $93);    LineNoCur := HexColor($0B, $21, $6F);
    FoldMark := HexColor($42, $42, $42);  CurLine := HexColor($EA, $F2, $FF);
    Sel := HexColor($AD, $D6, $FF);       Bracket := HexColor($B9, $B9, $B9);
    WordBg := HexColor($D5, $D5, $D5);    Folded := HexColor($A0, $A0, $A0);
  end;

  // 本文
  E.Font.Color := Fg;
  E.Color := Bg;
  E.BorderWidth := 0;
  E.RightEdge := 80;
  E.RightEdgeColor := Bg;                       // 右端のガイド線は背景と同じ色（見えない）
  E.SelectedColor.Background := Sel;
  E.SelectedColor.Foreground := clNone;         // 選んだ文字の色分けは消さない

  // 左端の欄（部品ごとに色を持つので、すべてに入れる）
  if Assigned(E.Gutter) then
  begin
    E.Gutter.Visible := True;
    E.Gutter.Color := Bg;
    if Assigned(E.Gutter.SeparatorPart) then
      E.Gutter.SeparatorPart.Visible := False;
    if Assigned(E.Gutter.LineNumberPart) then
    begin
      E.Gutter.LineNumberPart.MarkupInfo.Background := Bg;
      E.Gutter.LineNumberPart.MarkupInfo.Foreground := LineNo;
      E.Gutter.LineNumberPart.MarkupInfoCurrentLine.Background := clNone;   // カーソル行の行番号は文字の色だけ変える
      E.Gutter.LineNumberPart.MarkupInfoCurrentLine.Foreground := LineNoCur;
      TSynGutterLineNumber(E.Gutter.LineNumberPart).ShowOnlyLineNumbersMultiplesOf := 1;
    end;
    if Assigned(E.Gutter.CodeFoldPart) then
    begin
      E.Gutter.CodeFoldPart.MarkupInfo.Background := Bg;
      E.Gutter.CodeFoldPart.MarkupInfo.Foreground := FoldMark;
    end;
  end;

  // カーソル行（背景だけ。文字の色分けは残す）
  E.LineHighlightColor.Background := CurLine;
  E.LineHighlightColor.Foreground := clNone;
  E.LineHighlightColor.FrameColor := clNone;

  // 括弧の対応：枠だけ
  E.BracketMatchColor.Background := clNone;
  E.BracketMatchColor.Foreground := clNone;
  E.BracketMatchColor.FrameColor := Bracket;
  E.BracketMatchColor.Style := [];

  // キーワードの組（begin／end など）：括弧の対応と同じ
  M := E.MarkupByClass[TSynEditMarkupWordGroup];
  if M <> nil then
  begin
    M.MarkupInfo.Background := clNone;
    M.MarkupInfo.Foreground := clNone;
    M.MarkupInfo.FrameColor := Bracket;
    M.MarkupInfo.Style := [];
  end;

  // カーソル位置の単語と同じ単語の強調
  M := E.MarkupByClass[TSynEditMarkupHighlightAllCaret];
  if M <> nil then
  begin
    M.MarkupInfo.Background := WordBg;
    M.MarkupInfo.Foreground := clNone;
  end;

  // 折りたたんだ所：枠だけ
  E.FoldedCodeColor.Background := clNone;
  E.FoldedCodeColor.Foreground := clNone;
  E.FoldedCodeColor.FrameColor := Folded;
end;

{ 7.4.2 配色ごとの色の組。既存の 4 つは、1.0 の Pascal の色をそのまま組にしたもの }
procedure GetStylePalette(AStyle: TCEditStyle; out P: TCSynPalette);
begin
  case AStyle of
    csThema:
      begin
        if IsOSDarkTheme then
        begin
          P.Key := RGBToColor(86, 156, 214);   P.Str := RGBToColor(206, 145, 120);
          P.Comment := RGBToColor(106, 153, 85); P.Number := RGBToColor(181, 206, 168);
        end
        else
        begin
          P.Key := RGBToColor(0, 0, 255);      P.Str := RGBToColor(163, 21, 21);
          P.Comment := RGBToColor(0, 128, 0);  P.Number := RGBToColor(9, 134, 88);
        end;
        P.Text := clWindowText;
        P.Bg := clNone;
      end;
    csBlack:
      begin
        P.Text := clWhite; P.Key := clWhite; P.Str := clYellow; P.Comment := clGray;
        P.Number := TColor($008080FF); P.Bg := clBlack;
      end;
    csGray:
      begin
        P.Text := clWhite; P.Key := clAqua; P.Str := clYellow; P.Comment := clGreen;
        P.Number := TColor($008080FF); P.Bg := clBlack;
      end;
    csWhite:
      begin
        P.Text := clBlack; P.Key := clNavy; P.Str := clBlue; P.Comment := clGreen;
        P.Number := clPurple; P.Bg := clWhite;
      end;
    csVSDark:
      begin
        P.Text := HexColor($D4, $D4, $D4);    P.Key := HexColor($56, $9C, $D6);
        P.Str := HexColor($CE, $91, $78);     P.Comment := HexColor($6A, $99, $55);
        P.Number := HexColor($B5, $CE, $A8);  P.Symbol := HexColor($D4, $D4, $D4);
        P.Tag := HexColor($56, $9C, $D6);     P.TagMark := HexColor($80, $80, $80);
        P.AttrName := HexColor($9C, $DC, $FE); P.AttrValue := HexColor($CE, $91, $78);
        P.Bg := clNone;
        Exit;
      end;
    csVSLight:
      begin
        P.Text := HexColor($00, $00, $00);    P.Key := HexColor($00, $00, $FF);
        P.Str := HexColor($A3, $15, $15);     P.Comment := HexColor($00, $80, $00);
        P.Number := HexColor($09, $86, $58);  P.Symbol := HexColor($00, $00, $00);
        P.Tag := HexColor($80, $00, $00);     P.TagMark := HexColor($38, $38, $38);
        P.AttrName := HexColor($FF, $00, $00); P.AttrValue := HexColor($00, $00, $FF);
        P.Bg := clNone;
        Exit;
      end;
  end;
  // 既存の 4 つ：記号・タグ・タグの記号は予約語の色、属性名は文字の色、属性値は文字列の色
  P.Symbol := P.Key;
  P.Tag := P.Key;
  P.TagMark := P.Key;
  P.AttrName := P.Text;
  P.AttrValue := P.Str;
end;

{ TCSynEdit }
constructor TCSynEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FLoadingFlag := False;

  // 要件１: フォント「NSimSun」、サイズ 21
  Font.Name := 'BIZ UDGothic'; //'BIZ UDGothic';  //'Cascadia Code';  // Consolas'; //'NSimSun';
  Font.Size := 12;
  Font.Quality := fqCleartypeNatural;

  // 初期値の設定
  FFileName := ExtractFilePath(ParamStr(0)) + CXT(sUntitledTxt);
  InsertMode := True;
  FOldInsertMode := True;
  FOldCaretX := 1;
  FOldCaretY := 1;
  FOldCanUndo := False;
  FOldCanRedo := False;
  FOldModified := False;
  FOldSelText := '';
  FFileStream := nil;

  // 要件２: 背景の既定値を csGray に設定
  FEditStyle := csGray;

  // ★ Pascal ハイライターを既定値として割り当て（言語は pascal）
  FLanguage := 'pascal';
  Highlighter := TSynPasSyn.Create(Self);

  // データ保持用プロパティの初期値設定
  FEncodingType := feUTF8;
  FHasBOM := False;
  FLineEndingType := leCRLF;

  // ポップアップメニューの生成と割り当て
  CreateHidemaruLikePopupMenu;
  PopupMenu := FPopupMenu;
end;

destructor TCSynEdit.Destroy;
begin
  UnlockFile;
  FreeAndNil(FPopupMenu);

  inherited Destroy;
end;

procedure TCSynEdit.Loaded;
begin
  inherited Loaded;
  ApplyEditStyle; // ★ 追加：ロード完了後（csLoading解除後）に配色を確定
end;

{ プロパティ・アクセサ }
procedure TCSynEdit.SetFileName(const AValue: string);
begin
  if FFileName <> AValue then
  begin
    FFileName := AValue;
    OnFileNameChange(FFileName);
    AutoSelectHighlighter(FFileName);
  end;
end;

function TCSynEdit.GetDisplayTitle: string;
begin
  if FFileName <> '' then
    Result := ExtractFileName(FFileName)
  else
    Result := CXT(sUntitledTxt);
end;

procedure TCSynEdit.OnFileNameChange(var sFileName: String);
begin
  if Assigned(FOnFileNameChange) then
    FOnFileNameChange(Self, sFileName);
end;

procedure TCSynEdit.OnLoadFromFile(var sFileName: String);
begin
  if Assigned(FOnLoadFromFile) then
    FOnLoadFromFile(Self, sFileName);
end;

procedure TCSynEdit.OnSaveToFile(var sFileName: String);
begin
  if Assigned(FOnSaveToFile) then
    FOnSaveToFile(Self, sFileName);
end;

procedure TCSynEdit.OnInsModeChange(var bMode: Boolean);
begin
  if Assigned(FOnInsModeChange) then
    FOnInsModeChange(Self, bMode);
end;

procedure TCSynEdit.OnCaretChange(var iX, iY: Integer);
begin
  if Assigned(FOnCaretChange) then
    FOnCaretChange(Self, iX, iY);
end;

procedure TCSynEdit.OnUndoRedoStateChange(var bCanUndo, bCanRedo: Boolean);
begin
  if Assigned(FOnUndoRedoStateChange) then
    FOnUndoRedoStateChange(Self, bCanUndo, bCanRedo);
end;

procedure TCSynEdit.OnModifiedChange(var bModified: Boolean);
begin
  if Assigned(FOnModifiedChange) then
    FOnModifiedChange(Self, bModified);
end;

procedure TCSynEdit.OnSelectionChange(var sSelText: String; var iStartX, iStartY, iEndX, iEndY: Integer);
begin
  if Assigned(FOnSelectionChange) then
    FOnSelectionChange(Self, sSelText, iStartX, iStartY, iEndX, iEndY);
end;

procedure TCSynEdit.OnFocusChange(var bFocused: Boolean);
begin
  if Assigned(FOnFocusChange) then
    FOnFocusChange(Self, bFocused);
end;

procedure TCSynEdit.DoEnter;
var
  FocusedState: Boolean;
begin
  inherited DoEnter;
  FocusedState := True;
  OnFocusChange(FocusedState);
end;

procedure TCSynEdit.DoExit;
var
  FocusedState: Boolean;
begin
  inherited DoExit;
  FocusedState := False;
  OnFocusChange(FocusedState);
end;

procedure TCSynEdit.SetEditStyle(const AValue: TCEditStyle);
begin
  if FEditStyle <> AValue then
  begin
    FEditStyle := AValue;
    ApplyEditStyle;
  end;
end;

function TCSynEdit.GetInsModeValue: Boolean;
begin
  Result := InsertMode;
end;

procedure TCSynEdit.SetInsModeValue(const AValue: Boolean);
var
  CurMode: Boolean;
begin
  if InsertMode <> AValue then
  begin
    InsertMode := AValue;
    FOldInsertMode := InsertMode;
    CurMode := InsertMode;
    OnInsModeChange(CurMode);

    if InsertMode <> CurMode then
    begin
      InsertMode := CurMode;
      FOldInsertMode := CurMode;
    end;
  end;
end;

function TCSynEdit.GetCaretYValue: Integer;
begin
  Result := inherited CaretY;
end;

procedure TCSynEdit.SetCaretYValue(const AValue: Integer);
begin
  inherited CaretY := AValue;
end;

function TCSynEdit.GetCaretXValue: Integer;
begin
  Result := inherited CaretX;
end;

procedure TCSynEdit.SetCaretXValue(const AValue: Integer);
begin
  inherited CaretX := AValue;
end;

procedure TCSynEdit.CreateWnd;
begin
  inherited CreateWnd;
  {$IFDEF WINDOWS}
  DragAcceptFiles(Handle, True);
  SetWindowSubclass(Handle, @DropSubclassProc, DROP_SUBCLASS_ID, DWORD_PTR(Self));
  {$ENDIF}
end;

procedure TCSynEdit.DestroyWnd;
begin
  {$IFDEF WINDOWS}
  if HandleAllocated then
  begin
    RemoveWindowSubclass(Handle, @DropSubclassProc, DROP_SUBCLASS_ID);
    DragAcceptFiles(Handle, False);
  end;
  {$ENDIF}
  inherited DestroyWnd;
end;

procedure TCSynEdit.DoDropFiles(const AFiles: array of string);
begin
  if Length(AFiles) = 0 then Exit;
  if Assigned(FOnDropFiles) then
    FOnDropFiles(Self, AFiles)
  else
    LoadFromFile(AFiles[0]);   // イベント未設定なら先頭ファイルを開く
end;


{ gutter（行番号の欄）の各部分の背景を、エディタの背景（Color）にそろえる。
  部分ごとの背景が決まっていないと、ダーク表示で、変更の印の欄などに、既定の色（白）が出ることがある }
procedure TCSynEdit.ApplyGutterBackground;
var
  Bg: TColor;
begin
  if not Assigned(Gutter) then Exit;
  Bg := Color;
  Gutter.Color := Bg;
  if Assigned(Gutter.ChangesPart) then Gutter.ChangesPart.MarkupInfo.Background := Bg;
  if Assigned(Gutter.LineNumberPart) then Gutter.LineNumberPart.MarkupInfo.Background := Bg;
  if Assigned(Gutter.CodeFoldPart) then Gutter.CodeFoldPart.MarkupInfo.Background := Bg;
  if Assigned(Gutter.SeparatorPart) then Gutter.SeparatorPart.MarkupInfo.Background := Bg;
end;

{ 外観・スタイル設定 }
procedure TCSynEdit.ApplyEditStyle;
var
  Dark: Boolean;
begin
  if (csLoading in ComponentState) then Exit;

  // ★ 追加：全スタイル共通でブックマーク欄を常時非表示
  if Assigned(Gutter) and Assigned(Gutter.MarksPart) then
    Gutter.MarksPart.Visible := False;

  // 7.4.1 変更行の印：VS の配色では出さない（Monaco と同じ）。ほかの配色では出す
  // （VS から戻したときに、消えたままにならないように）
  if Assigned(Gutter) and Assigned(Gutter.ChangesPart) then
    Gutter.ChangesPart.Visible := not (FEditStyle in [csVSLight, csVSDark]);

  case FEditStyle of
    csThema:
      begin
        // 基本色はシステム色 → MetaDarkStyle が読み替える
        Dark := IsOSDarkTheme;

        Font.Color := clWindowText;
        Color := clWindow;
        BorderWidth := 0;
        RightEdge := 80;
        RightEdgeColor := clWindow;   // 右端ガイド線を非表示化

        SelectedColor.Background := clHighlight;
        SelectedColor.Foreground := clHighlightText;

        if Assigned(Gutter) then
        begin
          Gutter.Visible := True;
          Gutter.Color := clWindow;
          if Assigned(Gutter.SeparatorPart) then
            Gutter.SeparatorPart.Visible := False;
          if Assigned(Gutter.LineNumberPart) then
          begin
            Gutter.LineNumberPart.MarkupInfo.Background := clWindow;
            Gutter.LineNumberPart.MarkupInfo.Foreground := clGrayText;
          end;
        end;

        // 現在行（システム色に適当なものがないためテーマ別）
        if Assigned(LineHighlightColor) then
        begin
          if Dark then
            LineHighlightColor.Background := RGBToColor(38, 38, 38)
          else
            LineHighlightColor.Background := RGBToColor(242, 242, 242);
          LineHighlightColor.Foreground := clNone;  // 文字色はシンタックス色を維持
          LineHighlightColor.FrameColor := clNone;
        end;

        // シンタックス色（背景は clNone でエディタ背景をそのまま使う）
        if Assigned(Highlighter) and (Highlighter is TSynPasSyn) then
        begin
          with TSynPasSyn(Highlighter) do
          begin
            if Dark then
            begin
              KeyAttri.Foreground        := RGBToColor( 86, 156, 214); // 予約語: 青
              StringAttri.Foreground     := RGBToColor(206, 145, 120); // 文字列: 橙
              CommentAttri.Foreground    := RGBToColor(106, 153,  85); // コメント: 緑
              NumberAttri.Foreground     := RGBToColor(181, 206, 168); // 数値: 薄緑
            end
            else
            begin
              KeyAttri.Foreground        := RGBToColor(  0,   0, 255); // 予約語: 青
              StringAttri.Foreground     := RGBToColor(163,  21,  21); // 文字列: 赤茶
              CommentAttri.Foreground    := RGBToColor(  0, 128,   0); // コメント: 緑
              NumberAttri.Foreground     := RGBToColor(  9, 134,  88); // 数値: 緑青
            end;

            IdentifierAttri.Foreground := clWindowText;          // 識別子: 通常文字色
            ModifierAttri.Foreground   := KeyAttri.Foreground;   // virtual/override → 予約語と同色
            SymbolAttri.Foreground     := KeyAttri.Foreground;   // := ; () 等 → 予約語と同色

            KeyAttri.Background        := clNone;
            StringAttri.Background     := clNone;
            CommentAttri.Background    := clNone;
            NumberAttri.Background     := clNone;
            IdentifierAttri.Background := clNone;
            ModifierAttri.Background   := clNone;
            SymbolAttri.Background     := clNone;

            KeyAttri.Style      := [];
            CommentAttri.Style  := [];
            ModifierAttri.Style := [];
          end;
        end;
      end;

    csBlack:
      begin
         Font.Color := clWhite;
         Color := clBlack;
         BorderWidth := 0;
         RightEdge := 80;
         RightEdgeColor := clBlack;

         if Assigned(Gutter) then
         begin
           Gutter.Visible := True;
           Gutter.Color := clBlack;
           if Assigned(Gutter.SeparatorPart) then
             Gutter.SeparatorPart.Visible := False;
           if Assigned(Gutter.LineNumberPart) then
           begin
             Gutter.LineNumberPart.MarkupInfo.Background := clBlack;
             Gutter.LineNumberPart.MarkupInfo.Foreground :=  TColor($3B3B3B); // ← 変更
           end;
         end;

         if Assigned(LineHighlightColor) then
         begin
           LineHighlightColor.Background := TColor($00101010);
           LineHighlightColor.Foreground := clWhite;
           LineHighlightColor.FrameColor := clNone;
         end;

         // ★ csBlack 用 Pascal ハイライター配色（黒背景向け）
         if Assigned(Highlighter) and (Highlighter is TSynPasSyn) then
         begin
           with TSynPasSyn(Highlighter) do
           begin
             KeyAttri.Foreground := clWhite;          // 予約語: 白色
             KeyAttri.Background := clBlack;
             KeyAttri.Style := [];

             StringAttri.Foreground := clYellow;      // 文字列: 黄色
             StringAttri.Background := clBlack;

             SymbolAttri.Foreground := clAqua;        // 演算子/記号: 水色
             SymbolAttri.Background := clBlack;

             CommentAttri.Foreground := clGray;       // コメント: 灰色
             CommentAttri.Background := clBlack;
             CommentAttri.Style := [];

             IdentifierAttri.Foreground := clWhite;   // 識別子/変数: 白色
             IdentifierAttri.Background := clBlack;

             NumberAttri.Foreground := TColor($008080FF); // 数値: ピンク
             NumberAttri.Background := clBlack;

             ModifierAttri.Foreground := KeyAttri.Foreground;  // virtual/override → キーワードと同色
             ModifierAttri.Background := clBlack;

             SymbolAttri.Foreground := KeyAttri.Foreground;    // := <> ; () 等の記号 → キーワードと同色
             SymbolAttri.Background := clBlack;
             ModifierAttri.Style := [];  // ★追加：ボールド解除
           end;
         end;
      end;

    csGray:
      begin
         Font.Color := clWhite;
         Color := clBlack;
         // 右端ガイド線を背景と同じ黒色にして非表示化
         RightEdge := 80;
         RightEdgeColor := clBlack;

         if Assigned(Gutter) then
         begin
           // 要件: ガッター常時表示・黒背景
           Gutter.Visible := True;
           Gutter.Color := clBlack;

           if Assigned(Gutter.SeparatorPart) then
             Gutter.SeparatorPart.Visible := False;

           // 行番号パーツの設定
           if Assigned(Gutter.LineNumberPart) then
           begin
             Gutter.LineNumberPart.MarkupInfo.Background := clBlack;
             Gutter.LineNumberPart.MarkupInfo.Foreground := TColor($3B3B3B); // ← 変更

             if Gutter.LineNumberPart is TSynGutterLineNumber then
               TSynGutterLineNumber(Gutter.LineNumberPart).ShowOnlyLineNumbersMultiplesOf := 5;
           end;
         end;

         if Assigned(LineHighlightColor) then
         begin
           LineHighlightColor.Background := RGB(2, 20, 26);
           LineHighlightColor.Foreground := clWhite;
           LineHighlightColor.FrameColor := clNone;
         end;

         // ★ ハイライターが TSynPasSyn の場合、黒背景に合わせたダーク配色（色分け）を設定
         if Assigned(Highlighter) and (Highlighter is TSynPasSyn) then
         begin
           with TSynPasSyn(Highlighter) do
           begin
             // 予約語 (begin, end, type 等) : 水色
             KeyAttri.Foreground := clAqua;
             KeyAttri.Background := clBlack;
             KeyAttri.Style := [];

             // 文字列 ('type a.txt...') : 黄色
             StringAttri.Foreground := clYellow;
             StringAttri.Background := clBlack;

             // 演算子/記号 (:=, ;, 等) : 白
             SymbolAttri.Foreground := clWhite;
             SymbolAttri.Background := clBlack;

             // コメント (例、リダイレクトで出力 等) : 灰色・斜体
             CommentAttri.Foreground := clGreen;
             CommentAttri.Background := clBlack;
             CommentAttri.Style := [];

             // 識別子/変数 (sCmd, ob 等) : 白色
             IdentifierAttri.Foreground := clWhite;
             IdentifierAttri.Background := clBlack;

             // 数値 : 明るい赤・ピンク
             NumberAttri.Foreground := TColor($008080FF);
             NumberAttri.Background := clBlack;

             ModifierAttri.Foreground := KeyAttri.Foreground;  // virtual/override → キーワードと同色
             ModifierAttri.Background := clBlack;

             SymbolAttri.Foreground := KeyAttri.Foreground;    // := <> ; () 等の記号 → キーワードと同色
             SymbolAttri.Background := clBlack;
             ModifierAttri.Style := [];  // ★追加：ボールド解除
           end;
         end;
      end;

    csWhite:
      begin
        Font.Color := clBlack;
        Color := clWhite;
        BorderWidth := 0;
        RightEdge := 80;
        RightEdgeColor := clWhite;

        if Assigned(Gutter) then
        begin
          Gutter.Visible := True;
          Gutter.Color := clWhite;
          if Assigned(Gutter.SeparatorPart) then
            Gutter.SeparatorPart.Visible := False;
          if Assigned(Gutter.LineNumberPart) then
          begin
            Gutter.LineNumberPart.MarkupInfo.Background := clWhite;
            Gutter.LineNumberPart.MarkupInfo.Foreground := TColor($EEEEEE00);
          end;
        end;

        if Assigned(LineHighlightColor) then
        begin
          LineHighlightColor.Background := TColor($F2F2F2);
          LineHighlightColor.Foreground := clBlack;
          LineHighlightColor.FrameColor := clNone;
        end;

        // ★ csWhite 用 Pascal ハイライター配色（白背景向け視認性確保）
        if Assigned(Highlighter) and (Highlighter is TSynPasSyn) then
        begin
          with TSynPasSyn(Highlighter) do
          begin
            KeyAttri.Foreground := clNavy;          // 予約語: 濃い青・太字
            KeyAttri.Background := clWhite;
            KeyAttri.Style := [];

            StringAttri.Foreground := clBlue;        // 文字列: 青
            StringAttri.Background := clWhite;

            SymbolAttri.Foreground := clBlack;      // 演算子/記号: エンジ/茶色
            SymbolAttri.Background := clWhite;

            CommentAttri.Foreground := clGreen;      // コメント: 緑・斜体
            CommentAttri.Background := clWhite;
            CommentAttri.Style := [];

            IdentifierAttri.Foreground := clBlack;   // 識別子/変数: 黒色
            IdentifierAttri.Background := clWhite;

            NumberAttri.Foreground := clPurple;      // 数値: 紫
            NumberAttri.Background := clWhite;

            ModifierAttri.Foreground := KeyAttri.Foreground;  // virtual/override → キーワードと同色
            ModifierAttri.Background := clWhite;

            SymbolAttri.Foreground := KeyAttri.Foreground;    // := <> ; () 等の記号 → キーワードと同色
            SymbolAttri.Background := clWhite;
            ModifierAttri.Style := [];  // ★追加：ボールド解除
          end;
        end;
      end;

    csVSLight, csVSDark:
      ApplyVSStyle(Self, FEditStyle = csVSDark);
  end;

  ApplyGutterBackground;      // gutter の背景を、エディタの背景にそろえる
  // 7.4.3 色分けの属性（Pascal で既存の 4 つの配色は、上の case で入れ終わっている）
  ApplyHighlighterColors;
end;

{ 拡張子に応じたハイライター設定 }

procedure TCSynEdit.AutoSelectHighlighter(const APath: string);
var
  L: string;
begin
  // 7.1 拡張子なしは pascal。表にある拡張子はその言語。表にない拡張子は切り替えない
  if ExtractFileExt(APath) = '' then
    Language := 'pascal'
  else
  begin
    L := CSLanguageForFile(APath, '');
    if L <> '' then
      Language := L;
  end;
end;

{ 7.2 言語の名前から、使う色分けのクラスを決める（nil は色分けなし） }
function HighlighterClassFor(const ALang: string): TSynCustomHighlighterClass;
begin
  if ALang = 'pascal' then Result := TSynPasSyn
  else if ALang = 'markdown' then Result := TCSynMarkdownSyn
  else if ALang = 'html' then Result := TSynHTMLSyn
  else if ALang = 'css' then Result := TSynCssSyn
  else if (ALang = 'javascript') or (ALang = 'json') or (ALang = 'typescript') then Result := TSynJScriptSyn
  else if ALang = 'xml' then Result := TSynXMLSyn
  else if ALang = 'sql' then Result := TSynSQLSyn
  else if ALang = 'ini' then Result := TSynIniSyn
  else if ALang = 'bat' then Result := TSynBatSyn
  else if ALang = 'python' then Result := TSynPythonSyn
  else if (ALang = 'cpp') or (ALang = 'csharp') then Result := TSynCppSyn
  else if ALang = 'java' then Result := TSynJavaSyn
  else if ALang = 'shell' then Result := TSynUNIXShellScriptSyn
  else if ALang = 'php' then Result := TSynPHPSyn
  else Result := nil;   // plaintext・powershell・yaml・go・それ以外
end;

procedure TCSynEdit.SetLanguage(const AValue: string);
var
  V: string;
  Cls: TSynCustomHighlighterClass;
  Old: TComponent;
  i: Integer;
begin
  V := LowerCase(AValue);
  Cls := HighlighterClassFor(V);
  // 同じクラスなら作り直さない（Undo・表示はそのまま）
  if not ((Highlighter <> nil) and (Cls <> nil) and (Highlighter.ClassType = Cls)) then
  begin
    Old := Highlighter;
    if (Old <> nil) and (Old.Owner = Self) then
    begin
      // 自分が作った古い色分けは壊す（1.0 では残していて、開くたびにメモリが増えた）
      Highlighter := nil;
      Old.Free;
    end;
    // アプリが入れた色分け（Owner が自分でない）は壊さず、外すだけ
    if Cls = nil then
      Highlighter := nil
    else
      Highlighter := Cls.Create(Self);
  end;
  // 自分が作った色分けで、使っていないものも壊す（アプリが自分の色分けを入れたときに外れて残ったもの）
  for i := ComponentCount - 1 downto 0 do
    if (Components[i] is TSynCustomHighlighter) and (TObject(Components[i]) <> TObject(Highlighter)) then
      Components[i].Free;
  FLanguage := V;
  // 入れ替えても配色を保つ（1.0 では既定の色に戻っていた）
  ApplyEditStyle;
end;

{ 7.4.3 上書き用の属性か：元の属性（コメント・文字列など）の色の上に重ねて使う属性。
  親のクラスをたどって名前で見る（5.0 は TLazEditTextAttributeModifier、4.8 は TSynHighlighterAttributesModifier） }
function IsModifierAttr(A: TObject): Boolean;
var
  C: TClass;
begin
  Result := False;
  if A = nil then Exit;
  C := A.ClassType;
  while C <> nil do
  begin
    if SameText(C.ClassName, 'TLazEditTextAttributeModifier') or
       SameText(C.ClassName, 'TSynHighlighterAttributesModifier') then Exit(True);
    C := C.ClassParent;
  end;
end;

{ 7.4.3 色分けの属性に、その配色の色を入れる }
procedure TCSynEdit.ApplyHighlighterColors;
var
  P: TCSynPalette;
  H: TSynCustomHighlighter;
  i: Integer;

  { 属性 1 つに文字の色を入れる（背景は色の組の背景） }
  procedure SetFg(AAttri: TSynHighlighterAttributes; AColor: TColor);
  begin
    if AAttri = nil then Exit;
    AAttri.Foreground := AColor;
    AAttri.Background := P.Bg;
  end;

  { どの色分けにもある属性（SYN_ATTR_…）。その色分けに無ければ何もしない }
  procedure SetDef(AIndex: Integer; AColor: TColor);
  begin
    SetFg(THlAccess(H).GetDefaultAttribute(AIndex), AColor);
  end;

begin
  if Highlighter = nil then Exit;
  // Pascal で既存の 4 つの配色は、ApplyEditStyle の case で 1.0 のとおり入れ終わっている
  if (Highlighter is TSynPasSyn) and not (FEditStyle in [csVSLight, csVSDark]) then Exit;

  GetStylePalette(FEditStyle, P);
  H := TSynCustomHighlighter(Highlighter);

  // 1. すべての属性を、文字の色・背景・飾りなしにする（白い背景向けの既定の色を残さない）
  //    ただし上書き用の属性は色を持たせない（clNone）。文字の色を入れると、重ねたときに
  //    元の属性の色（コメントの緑・文字列の色など）を消してしまうため
  for i := 0 to H.AttrCount - 1 do
    with H.Attribute[i] do
      if IsModifierAttr(H.Attribute[i]) then
      begin
        Foreground := clNone;
        Background := clNone;
        FrameColor := clNone;
        Style := [];
      end
      else
      begin
        Foreground := P.Text;
        Background := P.Bg;
        Style := [];
      end;

  // 2. どの色分けにもある属性
  SetDef(SYN_ATTR_COMMENT, P.Comment);
  SetDef(SYN_ATTR_IDENTIFIER, P.Text);
  SetDef(SYN_ATTR_KEYWORD, P.Key);
  SetDef(SYN_ATTR_STRING, P.Str);
  SetDef(SYN_ATTR_SYMBOL, P.Symbol);
  SetDef(SYN_ATTR_NUMBER, P.Number);
  SetDef(SYN_ATTR_DIRECTIVE, P.Comment);   // Monaco は Pascal の {$...} をコメントの色で出す
  // 数値：Lazarus 5.0 の色分けの多くは、数値を「どの色分けにもある属性」で返さないので、
  // NumberAttri という名前の属性（published）があれば、それに入れる
  if IsPublishedProp(H, 'NumberAttri') then
    SetFg(TSynHighlighterAttributes(GetObjectProp(H, 'NumberAttri')), P.Number);

  // 3. 色分けごとの属性
  if H is TSynPasSyn then
    SetFg(TSynPasSyn(H).ModifierAttri, P.Key)
  else if H is TSynHTMLSyn then
    with TSynHTMLSyn(H) do
    begin
      SetFg(KeyAttri, P.Tag);
      SetFg(UndefKeyAttri, P.Tag);
      SetFg(DOCTYPEAttri, P.Tag);
      SetFg(IdentifierAttri, P.AttrName);
      SetFg(ValueAttri, P.AttrValue);
      SetFg(SymbolAttri, P.TagMark);
      SetFg(AndAttri, P.Key);
      SetFg(TextAttri, P.Text);
    end
  else if H is TSynXMLSyn then
    with TSynXMLSyn(H) do
    begin
      SetFg(ElementAttri, P.Tag);
      // 5.0 では ProcessingInstructionAttri の型が違う（Modifier）ので、SetFg を通さずに入れる
      ProcessingInstructionAttri.Foreground := P.Tag;
      ProcessingInstructionAttri.Background := P.Bg;
      SetFg(DocTypeAttri, P.Tag);
      SetFg(AttributeAttri, P.AttrName);
      SetFg(NamespaceAttributeAttri, P.AttrName);
      SetFg(AttributeValueAttri, P.AttrValue);
      SetFg(NamespaceAttributeValueAttri, P.AttrValue);
      SetFg(SymbolAttri, P.TagMark);
      SetFg(CDATAAttri, P.Str);
      SetFg(EntityRefAttri, P.Key);
    end
  else if H is TSynCssSyn then
    with TSynCssSyn(H) do
    begin
      SetFg(SelectorAttri, P.Tag);
      SetFg(KeyAttri, P.AttrName);           // プロパティの名前
    end
  else if H is TCSynMarkdownSyn then
    with TCSynMarkdownSyn(H) do
    begin
      // 9.3
      SetFg(HeadingAttri, P.Key);
      SetFg(StrongAttri, P.Text);
      StrongAttri.Style := [fsBold];
      SetFg(EmphasisAttri, P.Text);
      EmphasisAttri.Style := [fsItalic];
      SetFg(CodeAttri, P.Str);
      SetFg(QuoteAttri, P.Comment);
      SetFg(ListAttri, P.Key);
      SetFg(LinkAttri, P.Str);
      SetFg(RuleAttri, P.Key);
      SetFg(TextAttri, P.Text);
      SetFg(SpaceAttri, P.Text);
    end;
end;

{ ファイル排他制御 }

procedure TCSynEdit.LockFile(const APath: string);
begin
  UnlockFile;
  if FileExists(APath) then
  begin
    try
      FFileStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
    except
      FFileStream := nil;
    end;
  end;
end;

procedure TCSynEdit.UnlockFile;
begin
  if Assigned(FFileStream) then
  begin
    FreeAndNil(FFileStream);
  end;
end;

{ ファイル操作 }

procedure TCSynEdit.LoadFromFile(const AFileName: string);
begin
  UnlockFile;
  Lines.LoadFromFile(AFileName);
  FileName := AFileName;
  Modified := False;
  LockFile(AFileName);

  OnLoadFromFile(FFileName);
end;

procedure TCSynEdit.SaveToFile(const AFileName: string);
var
  FS: TFileStream;
begin
  UnlockFile;
  try
    { Lines.SaveToFile は、共有しない開き方（fmCreate）になり、ほかのアプリが読んでいるだけでも失敗する。
      共有付きで開いたストリームへ書く（uCXLang）。書けなかったときも、押さえ直す }
    FS := CXCreateFileShared(AFileName);
    try
      Lines.SaveToStream(FS);
    finally
      FS.Free;
    end;
  except
    LockFile(FFileName);          { 失敗：これまでのファイルを押さえ直して、例外はそのまま伝える }
    raise;
  end;
  FileName := AFileName;
  Modified := False;
  LockFile(AFileName);

  OnSaveToFile(FFileName);
end;

procedure TCSynEdit.Save;
begin
  SaveToFile(FFileName);
end;

{ 特殊機能・コマンド }

procedure TCSynEdit.DuplicateCurrentLine;
var
  CurrLine: string;
  SaveCaret: TPoint;
begin
  SaveCaret := CaretXY;
  if (CaretY >= 1) and (CaretY <= Lines.Count) then
  begin
    CurrLine := Lines[CaretY - 1];
    Lines.Insert(CaretY, CurrLine);
    CaretXY := SaveCaret;
  end;
end;

{ 要件３－６: 行番号トグル時もガッター自体は常にON }
procedure TCSynEdit.ToggleLineNumbers;
begin
  if Assigned(Gutter) and Assigned(Gutter.LineNumberPart) then
  begin
    Gutter.LineNumberPart.Visible := not Gutter.LineNumberPart.Visible;
    Gutter.Visible := True;
  end;
end;

{ 1. API / メソッド（マクロ・AI用）の実装 }

procedure TCSynEdit.InsertTextAtCaret(const AText: string);
begin
  if AText <> '' then
    inherited InsertTextAtCaret(AText);
end;

procedure TCSynEdit.ReplaceSelection(const AText: string);
begin
  SelText := AText;
end;

procedure TCSynEdit.SetCaretPosition(const AX, AY: Integer);
var
  TargetY, TargetX: Integer;
begin
  if Lines.Count = 0 then
    TargetY := 1
  else
    TargetY := EnsureRange(AY, 1, Lines.Count);

  if (TargetY >= 1) and (TargetY <= Lines.Count) then
    TargetX := EnsureRange(AX, 1, Length(Lines[TargetY - 1]) + 1)
  else
    TargetX := 1;

  CaretX := TargetX;
  CaretY := TargetY;
end;

procedure TCSynEdit.SelectLine(const ALineIndex: Integer);
var
  TargetY: Integer;
begin
  if Lines.Count = 0 then Exit;

  TargetY := EnsureRange(ALineIndex, 1, Lines.Count);
  BlockBegin := Classes.Point(1, TargetY);
  BlockEnd := Classes.Point(Length(Lines[TargetY - 1]) + 1, TargetY);
end;

procedure TCSynEdit.SelectRange(const AStartX, AStartY, AEndX, AEndY: Integer);
var
  StartY, EndY, StartX, EndX: Integer;
begin
  if Lines.Count = 0 then Exit;

  StartY := EnsureRange(AStartY, 1, Lines.Count);
  EndY := EnsureRange(AEndY, 1, Lines.Count);

  StartX := EnsureRange(AStartX, 1, Length(Lines[StartY - 1]) + 1);
  EndX := EnsureRange(AEndX, 1, Length(Lines[EndY - 1]) + 1);

  BlockBegin := Classes.Point(StartX, StartY);
  BlockEnd := Classes.Point(EndX, EndY);
end;

{ 4. 検索・置換メソッドの実装 }

function TCSynEdit.SearchText(const ASearchStr: string; ACaseSensitive, AWholeWord, AForward: Boolean): Boolean;
var
  SearchOptions: TSynSearchOptions;
begin
  Result := False;
  if ASearchStr = '' then Exit;

  SearchOptions := [];
  if ACaseSensitive then Include(SearchOptions, ssoMatchCase);
  if AWholeWord then Include(SearchOptions, ssoWholeWord);
  if not AForward then Include(SearchOptions, ssoBackwards);

  Result := (SearchReplace(ASearchStr, '', SearchOptions) > 0);
end;

function TCSynEdit.ReplaceText(const ASearchStr, AReplaceStr: string; ACaseSensitive, AWholeWord: Boolean): Boolean;
var
  SearchOptions: TSynSearchOptions;
begin
  Result := False;
  if ASearchStr = '' then Exit;

  SearchOptions := [ssoReplace];
  if ACaseSensitive then Include(SearchOptions, ssoMatchCase);
  if AWholeWord then Include(SearchOptions, ssoWholeWord);

  Result := (SearchReplace(ASearchStr, AReplaceStr, SearchOptions) > 0);
end;

function TCSynEdit.ReplaceAllText(const ASearchStr, AReplaceStr: string; ACaseSensitive, AWholeWord: Boolean): Integer;
var
  SearchOptions: TSynSearchOptions;
begin
  Result := 0;
  if ASearchStr = '' then Exit;

  SearchOptions := [ssoReplace, ssoReplaceAll, ssoEntireScope];
  if ACaseSensitive then Include(SearchOptions, ssoMatchCase);
  if AWholeWord then Include(SearchOptions, ssoWholeWord);

  Result := SearchReplace(ASearchStr, AReplaceStr, SearchOptions);
end;

{ キーボード・マウス操作オーバーライド }
procedure TCSynEdit.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if (ssCtrl in Shift) and (Key = VK_S) then
  begin
    Save;
    Key := 0;
    Exit;
  end;

  if (ssShift in Shift) and (Key = VK_F10) then
  begin
    DuplicateCurrentLine;
    Key := 0;
    Exit;
  end;

  if (Shift = []) and (Key = VK_F12) then
  begin
    ToggleLineNumbers;
    Key := 0;
    Exit;
  end;

  inherited KeyDown(Key, Shift);
end;

function TCSynEdit.DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint): Boolean;
begin
  if ssCtrl in Shift then
  begin
    if Font.Size > 6 then
      Font.Size := Font.Size - 1;
    Result := True;
    Exit;
  end;
  Result := inherited DoMouseWheelDown(Shift, MousePos);
end;

function TCSynEdit.DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean;
begin
  if ssCtrl in Shift then
  begin
    if Font.Size < 72 then
      Font.Size := Font.Size + 1;
    Result := True;
    Exit;
  end;
  Result := inherited DoMouseWheelUp(Shift, MousePos);
end;

{ テキストや状態が変化した際のイベント通知 }

procedure TCSynEdit.StatusChanged(AChanges: TSynStatusChanges);
var
  CurMode: Boolean;
  CurX, CurY: Integer;
  CurCanUndo, CurCanRedo: Boolean;
  CurModified: Boolean;
  CurSelText: string;
  CurSelStart, CurSelLen: Integer;
begin
  inherited StatusChanged(AChanges);

  if AChanges <> [] then
  begin
    if Assigned(FOnTextChange) then
      FOnTextChange(Self, Text);
  end;

  if FOldInsertMode <> InsertMode then
  begin
    FOldInsertMode := InsertMode;
    CurMode := InsertMode;
    OnInsModeChange(CurMode);

    if InsertMode <> CurMode then
    begin
      InsertMode := CurMode;
      FOldInsertMode := CurMode;
    end;
  end;

  if (FOldCaretX <> CaretX) or (FOldCaretY <> CaretY) then
  begin
    CurX := CaretX;
    CurY := CaretY;

    OnCaretChange(CurX, CurY);

    if (CurX <> CaretX) or (CurY <> CaretY) then
    begin
      CaretX := CurX;
      CaretY := CurY;
    end;

    FOldCaretX := CurX;
    FOldCaretY := CurY;
  end;

  if (FOldCanUndo <> CanUndo) or (FOldCanRedo <> CanRedo) then
  begin
    CurCanUndo := CanUndo;
    CurCanRedo := CanRedo;

    OnUndoRedoStateChange(CurCanUndo, CurCanRedo);

    FOldCanUndo := CurCanUndo;
    FOldCanRedo := CurCanRedo;
  end;

  if FOldModified <> Modified then
  begin
    CurModified := Modified;

    OnModifiedChange(CurModified);

    if Modified <> CurModified then
      Modified := CurModified;

    FOldModified := Modified;
  end;

  if FOldSelText <> SelText then
  begin
    FOldSelText := SelText;
    CurSelText := SelText;

    CurSelStart := BlockBegin.X;
    CurSelLen   := BlockBegin.Y;
    CurX        := BlockEnd.X;
    CurY        := BlockEnd.Y;

    OnSelectionChange(CurSelText, CurSelStart, CurSelLen, CurX, CurY);
  end;
end;

{ 秀丸風内蔵ポップアップメニュー生成 }

procedure TCSynEdit.CreateHidemaruLikePopupMenu;

  function AddItem(const ACaption: string; AEvent: TNotifyEvent): TMenuItem;
  begin
    Result := TMenuItem.Create(FPopupMenu);
    Result.Caption := ACaption;
    Result.OnClick := AEvent;
    FPopupMenu.Items.Add(Result);
  end;

  procedure AddSeparator;
  var
    Item: TMenuItem;
  begin
    Item := TMenuItem.Create(FPopupMenu);
    Item.Caption := '-';
    FPopupMenu.Items.Add(Item);
  end;

begin
  if Assigned(FPopupMenu) then FreeAndNil(FPopupMenu);
  FPopupMenu := TPopupMenu.Create(Self);

  FPopupMenu.OnPopup := @OnPopupMenuPopup;

  // --- グループ 1 ---
  FMenuItemCut := AddItem(CXT(sMnCut), @OnMenuCutClick);
  FMenuItemCopy := AddItem(CXT(sMnCopy), @OnMenuCopyClick);
  FMenuItemPaste := AddItem(CXT(sMnPaste), @OnMenuPasteClick);
  AddSeparator;

  // --- グループ 2 ---
  FMenuItemQuoteCopy := AddItem(CXT(sMnQuoteCopy), @OnMenuQuoteCopyClick);
  FMenuItemAppendCut := AddItem(CXT(sMnAppendCut), @OnMenuAppendCutClick);
  FMenuItemAppendCopy := AddItem(CXT(sMnAppendCopy), @OnMenuAppendCopyClick);
  AddSeparator;

  // --- グループ 3 ---
  FMenuItemDelete := AddItem(CXT(sMnDelete), @OnMenuDeleteClick);
  AddSeparator;

  // --- グループ 4 ---
  FMenuItemUpperCase := AddItem('TO UPPER CASE', @OnMenuUpperCaseClick);
  FMenuItemLowerCase := AddItem('to lower case', @OnMenuLowerCaseClick);
  AddSeparator;

  // --- グループ 5 ---
  FMenuItemToHalf := AddItem(CXT(sMnToHalfKanaSyn), @OnMenuToHalfClick);
  FMenuItemToHiragana := AddItem(CXT(sMnToHiragana), @OnMenuToHiraganaClick);
  FMenuItemToKatakana := AddItem(CXT(sMnToKatakana), @OnMenuToKatakanaClick);
  AddSeparator;

  // --- グループ 6 ---
  FMenuItemTabToSpace := AddItem(CXT(sMnTabToSpaceSyn), @OnMenuTabToSpaceClick);
  FMenuItemSpaceToTab := AddItem(CXT(sMnSpaceToTabSyn), @OnMenuSpaceToTabClick);
  AddSeparator;

  // --- グループ 7 ---
  AddItem(CXT(sMnIndent), @OnMenuIndentClick);
  AddItem(CXT(sMnOutdent), @OnMenuUnindentClick);
end;

procedure TCSynEdit.OnPopupMenuPopup(Sender: TObject);
var
  HasSelection: Boolean;
  HasClipText: Boolean;
begin
  HasSelection := SelText <> '';
  HasClipText := Clipboard.HasFormat(CF_TEXT);

  if Assigned(FMenuItemCut) then FMenuItemCut.Enabled := HasSelection;
  if Assigned(FMenuItemCopy) then FMenuItemCopy.Enabled := HasSelection;
  if Assigned(FMenuItemQuoteCopy) then FMenuItemQuoteCopy.Enabled := HasSelection;
  if Assigned(FMenuItemAppendCut) then FMenuItemAppendCut.Enabled := HasSelection;
  if Assigned(FMenuItemAppendCopy) then FMenuItemAppendCopy.Enabled := HasSelection;
  if Assigned(FMenuItemDelete) then FMenuItemDelete.Enabled := HasSelection;
  if Assigned(FMenuItemUpperCase) then FMenuItemUpperCase.Enabled := HasSelection;
  if Assigned(FMenuItemLowerCase) then FMenuItemLowerCase.Enabled := HasSelection;
  if Assigned(FMenuItemToHalf) then FMenuItemToHalf.Enabled := HasSelection;
  if Assigned(FMenuItemToHiragana) then FMenuItemToHiragana.Enabled := HasSelection;
  if Assigned(FMenuItemToKatakana) then FMenuItemToKatakana.Enabled := HasSelection;
  if Assigned(FMenuItemTabToSpace) then FMenuItemTabToSpace.Enabled := HasSelection;
  if Assigned(FMenuItemSpaceToTab) then FMenuItemSpaceToTab.Enabled := HasSelection;

  if Assigned(FMenuItemPaste) then FMenuItemPaste.Enabled := HasClipText;
end;

{ メニューハンドラの実装 }

procedure TCSynEdit.OnMenuCutClick(Sender: TObject);
begin
  CutToClipboard;
end;

procedure TCSynEdit.OnMenuCopyClick(Sender: TObject);
begin
  CopyToClipboard;
end;

procedure TCSynEdit.OnMenuPasteClick(Sender: TObject);
begin
  PasteFromClipboard;
end;

procedure TCSynEdit.OnMenuQuoteCopyClick(Sender: TObject);
var
  SelectedStr: string;
  SL: TStringList;
  I: Integer;
begin
  if SelText = '' then Exit;
  SelectedStr := SelText;
  SL := TStringList.Create;
  try
    SL.Text := SelectedStr;
    for I := 0 to SL.Count - 1 do
      SL[I] := '> ' + SL[I];
    Clipboard.AsText := SL.Text;
  finally
    SL.Free;
  end;
end;

procedure TCSynEdit.OnMenuAppendCutClick(Sender: TObject);
var
  OldText: string;
begin
  if SelText = '' then Exit;
  OldText := Clipboard.AsText;
  Clipboard.AsText := OldText + SelText;
  ClearSelection;
end;

procedure TCSynEdit.OnMenuAppendCopyClick(Sender: TObject);
var
  OldText: string;
begin
  if SelText = '' then Exit;
  OldText := Clipboard.AsText;
  Clipboard.AsText := OldText + SelText;
end;

procedure TCSynEdit.OnMenuDeleteClick(Sender: TObject);
begin
  ClearSelection;
end;

procedure TCSynEdit.OnMenuUpperCaseClick(Sender: TObject);
begin
  if SelText <> '' then
    SelText := UpperCase(SelText);
end;

procedure TCSynEdit.OnMenuLowerCaseClick(Sender: TObject);
begin
  if SelText <> '' then
    SelText := LowerCase(SelText);
end;

procedure TCSynEdit.OnMenuToHalfClick(Sender: TObject);
var
  S: UnicodeString;
  I: Integer;
begin
  if SelText = '' then Exit;
  S := UTF8ToUTF16(SelText);
  for I := 1 to Length(S) do
  begin
    if (Ord(S[I]) >= $FF01) and (Ord(S[I]) <= $FF5E) then
      S[I] := WideChar(Ord(S[I]) - $FEE0)
    else if Ord(S[I]) = $3000 then
      S[I] := #$20;
  end;
  SelText := UTF16ToUTF8(S);
end;

procedure TCSynEdit.OnMenuToHiraganaClick(Sender: TObject);
var
  S: UnicodeString;
  I: Integer;
begin
  if SelText = '' then Exit;
  S := UTF8ToUTF16(SelText);
  for I := 1 to Length(S) do
  begin
    if (Ord(S[I]) >= $30A1) and (Ord(S[I]) <= $30F6) then
      S[I] := WideChar(Ord(S[I]) - $60);
  end;
  SelText := UTF16ToUTF8(S);
end;

procedure TCSynEdit.OnMenuToKatakanaClick(Sender: TObject);
var
  S: UnicodeString;
  I: Integer;
begin
  if SelText = '' then Exit;
  S := UTF8ToUTF16(SelText);
  for I := 1 to Length(S) do
  begin
    if (Ord(S[I]) >= $3041) and (Ord(S[I]) <= $3096) then
      S[I] := WideChar(Ord(S[I]) + $60);
  end;
  SelText := UTF16ToUTF8(S);
end;

procedure TCSynEdit.OnMenuTabToSpaceClick(Sender: TObject);
begin
  if SelText <> '' then
    SelText := StringReplace(SelText, #9, StringOfChar(' ', TabWidth), [rfReplaceAll]);
end;

procedure TCSynEdit.OnMenuSpaceToTabClick(Sender: TObject);
begin
  if SelText <> '' then
    SelText := StringReplace(SelText, StringOfChar(' ', TabWidth), #9, [rfReplaceAll]);
end;

procedure TCSynEdit.OnMenuIndentClick(Sender: TObject);
begin
  ExecuteCommand(ecBlockIndent, ' ', nil);
end;

procedure TCSynEdit.OnMenuUnindentClick(Sender: TObject);
begin
  ExecuteCommand(ecBlockUnindent, ' ', nil);
end;

procedure TCSynEdit.OnMenuSelectAllClick(Sender: TObject);
begin
  SelectAll;
end;

{ ------------------------------------------------------------------ }
{ 9章 Markdown の色分け（TCSynMarkdownSyn）                           }
{ ------------------------------------------------------------------ }

constructor TCSynMarkdownSyn.Create(AOwner: TComponent);

  function NewAttri(const ACaption, AStoredName: string): TSynHighlighterAttributes;
  begin
    Result := TSynHighlighterAttributes.Create(ACaption, AStoredName);
    AddAttribute(Result);           // 登録した属性は、色分けを壊すときに一緒に壊れる
  end;

begin
  inherited Create(AOwner);
  FHeadingAttri := NewAttri('Heading', 'Heading');
  FStrongAttri := NewAttri('Strong', 'Strong');
  FEmphasisAttri := NewAttri('Emphasis', 'Emphasis');
  FCodeAttri := NewAttri('Code', 'Code');
  FQuoteAttri := NewAttri('Quote', 'Quote');
  FListAttri := NewAttri('List', 'List');
  FLinkAttri := NewAttri('Link', 'Link');
  FRuleAttri := NewAttri('Rule', 'Rule');
  FTextAttri := NewAttri('Text', 'Text');
  FSpaceAttri := NewAttri('Space', 'Space');
  // 配色を当てる前の色（白い背景向け）。TCSynEdit が配色を当てると上書きされる
  FHeadingAttri.Foreground := clNavy;
  FStrongAttri.Style := [fsBold];
  FEmphasisAttri.Style := [fsItalic];
  FCodeAttri.Foreground := clMaroon;
  FQuoteAttri.Foreground := clGreen;
  FListAttri.Foreground := clNavy;
  FLinkAttri.Foreground := clBlue;
  FRuleAttri.Foreground := clNavy;
  FRange := mrNormal;
end;

class function TCSynMarkdownSyn.GetLanguageName: string;
begin
  Result := 'Markdown';
end;

function TCSynMarkdownSyn.AttriOf(AKind: TCMdTokenKind): TSynHighlighterAttributes;
begin
  case AKind of
    mtSpace: Result := FSpaceAttri;
    mtHeading: Result := FHeadingAttri;
    mtStrong: Result := FStrongAttri;
    mtEmphasis: Result := FEmphasisAttri;
    mtCode: Result := FCodeAttri;
    mtQuote: Result := FQuoteAttri;
    mtList: Result := FListAttri;
    mtLink: Result := FLinkAttri;
    mtRule: Result := FRuleAttri;
  else
    Result := FTextAttri;
  end;
end;

procedure TCSynMarkdownSyn.AddTok(APos, ALen: Integer; AKind: TCMdTokenKind);
begin
  if ALen <= 0 then Exit;
  if FTokCount >= Length(FToks) then
    SetLength(FToks, FTokCount * 2 + 8);
  FToks[FTokCount].Pos := APos;
  FToks[FTokCount].Len := ALen;
  FToks[FTokCount].Kind := AKind;
  Inc(FTokCount);
end;

{ 英数字・アンダースコア・UTF-8 の多バイト文字（日本語など）は「単語の文字」 }
function IsWordByte(C: Char): Boolean; inline;
begin
  Result := (C in ['0'..'9', 'A'..'Z', 'a'..'z', '_']) or (Ord(C) >= $80);
end;

{ 9.2「行の中」：AFrom（0 から）から行の終わりまでを字句に分ける }
procedure TCSynMarkdownSyn.ScanInline(AFrom: Integer);
var
  S: string;
  L, P, Q, N, K: Integer;
  C: Char;
  AtHead: Boolean;

  { 1 から数える位置 I の文字（範囲の外は #0） }
  function Ch(I: Integer): Char;
  begin
    if (I >= 1) and (I <= L) then Result := S[I] else Result := #0;
  end;

  { 位置 AStart から、文字列 ASub を探す（見つからなければ 0） }
  function FindFrom(const ASub: string; AStart: Integer): Integer;
  begin
    Result := PosEx(ASub, S, AStart);
  end;

begin
  S := FLineStr;
  L := Length(S);
  P := AFrom + 1;                  // ここからは 1 から数える
  AtHead := True;                  // 行の頭（空白の後ろ）か：リストの印を見るため

  // 行の頭の空白・タブ
  Q := P;
  while (Q <= L) and (S[Q] in [' ', #9]) do Inc(Q);
  if Q > P then
  begin
    AddTok(P - 1, Q - P, mtSpace);
    P := Q;
  end;

  // リストの印（印と後ろの空白 1 つ）
  if AtHead and (P <= L) then
  begin
    if (S[P] in ['-', '*', '+']) and (Ch(P + 1) in [' ', #9]) then
    begin
      AddTok(P - 1, 2, mtList);
      Inc(P, 2);
    end
    else if S[P] in ['0'..'9'] then
    begin
      Q := P;
      while (Q <= L) and (S[Q] in ['0'..'9']) and (Q - P < 9) do Inc(Q);
      if (Ch(Q) in ['.', ')']) and (Ch(Q + 1) in [' ', #9]) then
      begin
        AddTok(P - 1, Q + 2 - P, mtList);
        P := Q + 2;
      end;
    end;
  end;

  while P <= L do
  begin
    C := S[P];
    case C of
      ' ', #9:
        begin
          Q := P;
          while (Q <= L) and (S[Q] in [' ', #9]) do Inc(Q);
          AddTok(P - 1, Q - P, mtSpace);
          P := Q;
        end;

      '`':
        begin
          // 同じ数の ` で閉じる所まで。閉じなければ行の終わりまで
          N := 0;
          while Ch(P + N) = '`' do Inc(N);
          Q := P + N;
          K := 0;
          while Q <= L do
          begin
            if S[Q] = '`' then
            begin
              K := 0;
              while Ch(Q + K) = '`' do Inc(K);
              if K = N then Break;
              Inc(Q, K);
              K := 0;
            end
            else
              Inc(Q);
          end;
          if (Q <= L) and (K = N) then
          begin
            AddTok(P - 1, Q + N - P, mtCode);
            P := Q + N;
          end
          else
          begin
            AddTok(P - 1, L - P + 1, mtCode);
            P := L + 1;
          end;
        end;

      '*', '_':
        begin
          if (C = '_') and (P > 1) and IsWordByte(S[P - 1]) then
          begin
            // 単語の中の _（snake_case）は普通の文字
            AddTok(P - 1, 1, mtText);
            Inc(P);
          end
          else if Ch(P + 1) = C then
          begin
            // ** か __：同じ記号 2 つで閉じる所まで太字
            Q := FindFrom(C + C, P + 3);
            if Q > 0 then
            begin
              AddTok(P - 1, Q + 2 - P, mtStrong);
              P := Q + 2;
            end
            else
            begin
              AddTok(P - 1, 2, mtText);      // 閉じない：記号だけ文字
              Inc(P, 2);
            end;
          end
          else
          begin
            // * か _：同じ記号 1 つで閉じる所まで斜体
            Q := FindFrom(C, P + 2);
            if Q > 0 then
            begin
              AddTok(P - 1, Q + 1 - P, mtEmphasis);
              P := Q + 1;
            end
            else
            begin
              AddTok(P - 1, 1, mtText);
              Inc(P);
            end;
          end;
        end;

      '[':
        begin
          // [文字](アドレス)
          Q := FindFrom(']', P + 1);
          if (Q > 0) and (Ch(Q + 1) = '(') then
            Q := FindFrom(')', Q + 2)
          else
            Q := 0;
          if Q > 0 then
          begin
            AddTok(P - 1, Q + 1 - P, mtLink);
            P := Q + 1;
          end
          else
          begin
            AddTok(P - 1, 1, mtText);
            Inc(P);
          end;
        end;

      '<':
        begin
          // <http…>
          Q := 0;
          if LowerCase(Copy(S, P + 1, 4)) = 'http' then
            Q := FindFrom('>', P + 1);
          if Q > 0 then
          begin
            AddTok(P - 1, Q + 1 - P, mtLink);
            P := Q + 1;
          end
          else
          begin
            AddTok(P - 1, 1, mtText);
            Inc(P);
          end;
        end;
    else
      // 文字：次の記号・空白の手前まで（単語の中の _ は続ける）
      Q := P + 1;
      while Q <= L do
      begin
        if S[Q] in [' ', #9, '`', '*', '[', '<'] then Break;
        if (S[Q] = '_') and not IsWordByte(S[Q - 1]) then Break;
        Inc(Q);
      end;
      AddTok(P - 1, Q - P, mtText);
      P := Q;
    end;
  end;
end;

procedure TCSynMarkdownSyn.SetLine(const NewValue: String; LineNumber: Integer);
var
  L, Ind, N, I, Cnt: Integer;
  T: string;
  IndentOK, IsFence, IsRule: Boolean;
  RuleCh: Char;
begin
  FLineStr := NewValue;
  FLine := PChar(FLineStr);
  FLineLen := Length(FLineStr);
  FTokCount := 0;
  FTokIndex := 0;
  FLineMode := mtText;
  L := FLineLen;

  // 行の頭の空白（3 個まで許す）
  Ind := 0;
  while (Ind < L) and (FLineStr[Ind + 1] = ' ') do Inc(Ind);
  IndentOK := Ind <= 3;
  T := Copy(FLineStr, Ind + 1, MaxInt);
  IsFence := IndentOK and ((Copy(T, 1, 3) = '```') or (Copy(T, 1, 3) = '~~~'));

  // 9.2 の表の 1・2：コードブロックの中
  if FRange = mrFence then
  begin
    FLineMode := mtCode;
    if IsFence then FRange := mrNormal;     // 閉じる行もコード。次の行から普通
    AddTok(0, L, mtCode);
    if FTokCount > 0 then FTokenKind := FToks[0].Kind;
    Exit;
  end;

  // 3：コードブロックの始まり
  if IsFence then
  begin
    FLineMode := mtCode;
    FRange := mrFence;
    AddTok(0, L, mtCode);
  end
  else
  begin
    // 4：見出し（# が 1〜6 個、後ろが空白か行の終わり）
    N := 0;
    while (N < Length(T)) and (T[N + 1] = '#') do Inc(N);
    if IndentOK and (N >= 1) and (N <= 6) and ((N = Length(T)) or (T[N + 1] in [' ', #9])) then
      FLineMode := mtHeading
    else
    begin
      // 5：罫線（- * _ のどれか 1 種類だけが 3 個以上。間の空白は可）
      IsRule := False;
      if IndentOK and (T <> '') and (T[1] in ['-', '*', '_']) then
      begin
        RuleCh := T[1];
        Cnt := 0;
        IsRule := True;
        for I := 1 to Length(T) do
          if T[I] = RuleCh then
            Inc(Cnt)
          else if not (T[I] in [' ', #9]) then
          begin
            IsRule := False;
            Break;
          end;
        IsRule := IsRule and (Cnt >= 3);
      end;
      if IsRule then
        FLineMode := mtRule
      // 6：引用
      else if IndentOK and (T <> '') and (T[1] = '>') then
        FLineMode := mtQuote;
    end;

    if FLineMode <> mtText then
      AddTok(0, L, FLineMode)             // 行全体を 1 つの字句にする
    else
      ScanInline(0);                      // 7：行の中で分ける
  end;
  if FTokCount > 0 then FTokenKind := FToks[0].Kind;
end;

procedure TCSynMarkdownSyn.Next;
begin
  if FTokIndex < FTokCount then Inc(FTokIndex);
  if FTokIndex < FTokCount then FTokenKind := FToks[FTokIndex].Kind;
end;

function TCSynMarkdownSyn.GetEol: Boolean;
begin
  Result := FTokIndex >= FTokCount;
end;

function TCSynMarkdownSyn.GetToken: string;
begin
  if FTokIndex < FTokCount then
    Result := Copy(FLineStr, FToks[FTokIndex].Pos + 1, FToks[FTokIndex].Len)
  else
    Result := '';
end;

procedure TCSynMarkdownSyn.GetTokenEx(out TokenStart: PChar; out TokenLength: integer);
begin
  if FTokIndex < FTokCount then
  begin
    TokenStart := FLine + FToks[FTokIndex].Pos;
    TokenLength := FToks[FTokIndex].Len;
  end
  else
  begin
    TokenStart := FLine + FLineLen;
    TokenLength := 0;
  end;
end;

function TCSynMarkdownSyn.GetTokenAttribute: TSynHighlighterAttributes;
begin
  if FTokIndex < FTokCount then
    Result := AttriOf(FToks[FTokIndex].Kind)
  else
    Result := nil;
end;

function TCSynMarkdownSyn.GetTokenKind: integer;
begin
  Result := Ord(FTokenKind);
end;

function TCSynMarkdownSyn.GetTokenPos: Integer;
begin
  if FTokIndex < FTokCount then
    Result := FToks[FTokIndex].Pos
  else
    Result := FLineLen;
  FTokenPos := Result;
end;

function TCSynMarkdownSyn.GetDefaultAttribute(Index: integer): TSynHighlighterAttributes;
begin
  case Index of
    SYN_ATTR_COMMENT: Result := FQuoteAttri;
    SYN_ATTR_IDENTIFIER: Result := FTextAttri;
    SYN_ATTR_KEYWORD: Result := FHeadingAttri;
    SYN_ATTR_STRING: Result := FCodeAttri;
    SYN_ATTR_WHITESPACE: Result := FSpaceAttri;
    SYN_ATTR_SYMBOL: Result := FListAttri;
  else
    Result := nil;
  end;
end;

function TCSynMarkdownSyn.GetRange: Pointer;
begin
  Result := Pointer(PtrUInt(Ord(FRange)));   // mrNormal = 0、mrFence = 1
end;

procedure TCSynMarkdownSyn.SetRange(Value: Pointer);
begin
  if PtrUInt(Value) = PtrUInt(Ord(mrFence)) then
    FRange := mrFence
  else
    FRange := mrNormal;
end;

procedure TCSynMarkdownSyn.ResetRange;
begin
  FRange := mrNormal;
end;

end.

