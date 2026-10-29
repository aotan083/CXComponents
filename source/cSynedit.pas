{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
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
  SynHighlighterXML,
  SynHighlighterHTML,
  SynHighlighterPas,
  SynEditTypes,
  SynGutterLineNumber,
  Registry;

type
  { エディタスタイル定義 }
  TCEditStyle = (csBlack, csGray, csWhite, csThema);

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

  { TCSynEdit コンポーネント定義 }
  TCSynEdit = class(TSynEdit)
  private
    FFileName: string;
    FEditStyle: TCEditStyle;
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
    procedure SetInsModeValue(const AValue: Boolean);
    function GetInsModeValue: Boolean;
    function GetCaretYValue: Integer;
    procedure SetCaretYValue(const AValue: Integer);
    function GetCaretXValue: Integer;
    procedure SetCaretXValue(const AValue: Integer);
    function GetDisplayTitle: string;

    procedure ApplyEditStyle;
    procedure AutoSelectHighlighter(const APath: string);
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

implementation

{$IFDEF WINDOWS}
uses
  Windows, ShellAPI;

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
  FFileName := ExtractFilePath(ParamStr(0)) + '無題.txt';
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

  // ★ Pascal ハイライターを既定値として割り当て
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
    Result := '無題.txt';
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


{ 外観・スタイル設定 }
procedure TCSynEdit.ApplyEditStyle;
var
  Dark: Boolean;
begin
  if (csLoading in ComponentState) then Exit;

  // ★ 追加：全スタイル共通でブックマーク欄を常時非表示
  if Assigned(Gutter) and Assigned(Gutter.MarksPart) then
    Gutter.MarksPart.Visible := False;

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
  end;
end;

{ 拡張子に応じたハイライター設定 }

procedure TCSynEdit.AutoSelectHighlighter(const APath: string);
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(APath));

  if (Ext = '.json') or (Ext = '.html') or (Ext = '.htm') or (Ext = '.csv') or
     (Ext = '.md') or (Ext = '.markdown') or (Ext = '.yaml') or (Ext = '.yml') then
    Highlighter := TSynHTMLSyn.Create(Self)
  else if Ext = '.xml' then
    Highlighter := TSynXMLSyn.Create(Self)
  else if (Ext = '.pas') or (Ext = '.pp') or (Ext = '.lpr') or (Ext = '.dpr') or (Ext = '') or (Ext = '.txt') then
    Highlighter := TSynPasSyn.Create(Self);

//  ApplyEditStyle; // ★ 追加：ハイライター切替後に配色を再適用
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
begin
  UnlockFile;
  Lines.SaveToFile(AFileName);
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
  FMenuItemCut := AddItem('切り抜き', @OnMenuCutClick);
  FMenuItemCopy := AddItem('コピー', @OnMenuCopyClick);
  FMenuItemPaste := AddItem('貼り付け', @OnMenuPasteClick);
  AddSeparator;

  // --- グループ 2 ---
  FMenuItemQuoteCopy := AddItem('引用付きコピー', @OnMenuQuoteCopyClick);
  FMenuItemAppendCut := AddItem('追加切り抜き', @OnMenuAppendCutClick);
  FMenuItemAppendCopy := AddItem('追加コピー', @OnMenuAppendCopyClick);
  AddSeparator;

  // --- グループ 3 ---
  FMenuItemDelete := AddItem('削除', @OnMenuDeleteClick);
  AddSeparator;

  // --- グループ 4 ---
  FMenuItemUpperCase := AddItem('TO UPPER CASE', @OnMenuUpperCaseClick);
  FMenuItemLowerCase := AddItem('to lower case', @OnMenuLowerCaseClick);
  AddSeparator;

  // --- グループ 5 ---
  FMenuItemToHalf := AddItem('ハンカクに変換', @OnMenuToHalfClick);
  FMenuItemToHiragana := AddItem('全角ひらがなに変換', @OnMenuToHiraganaClick);
  FMenuItemToKatakana := AddItem('全角カタカナに変換', @OnMenuToKatakanaClick);
  AddSeparator;

  // --- グループ 6 ---
  FMenuItemTabToSpace := AddItem('TAB -> 空白 変換', @OnMenuTabToSpaceClick);
  FMenuItemSpaceToTab := AddItem('空白 -> TAB 変換', @OnMenuSpaceToTabClick);
  AddSeparator;

  // --- グループ 7 ---
  AddItem('インデント', @OnMenuIndentClick);
  AddItem('逆インデント', @OnMenuUnindentClick);
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

end.

