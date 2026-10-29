{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ TCMMonacoView - WebView2 + Monaco Editor による Markdown/ソース エディタ（内部の部品）
  環境: Lazarus 4.8 / FPC 3.2.2 / Windows 11 x64 / WebView4Delphi

  ※ 第2版から、フォームに貼る部品は ucmonacos.pas の TCMonacoEditor（複合部品）になった。
    このユニットの TCMMonacoView は、その中に入る内部の部品である（第1版の TCMonacoEditor を改名）。
    通常は直接使わない。上級者向けに、TCMonacoEditor.Monaco から触れる。

  【使い方】
  1. EXE の隣に WebView2.ini（必ず置く）と WebView2Loader.dll を置く。WebView2 の準備は、
     初めて表示されたときにこの部品が自分で行う（uCXRuntime の CXStartWebView2。.lpr には何も書かない）
  2. EXE の隣に monaco\editor.html, monaco\vs\ を置く
     monaco を別の場所に置くときは、ResourcePath か、WebView2.ini の MonacoFolder で指定する
     （ResourcePath が優先。相対パスは EXE のフォルダから数える。uCXRuntime.pas）
  3. 実行時生成:
       Ed := TCMMonacoView.Create(Self); Ed.Parent := Self; Ed.Align := alClient;
       Ed.OpenFile('C:\test.md');

  【複数文書（タブ）】 WebView2 は1つのまま、内部に複数の文書を保持する。
    Text / FileName / Modified / Encoding / Language / Save系 は「アクティブな文書」が対象。
    タブ表示はアプリ側で作り、OnDocListChange / OnDocumentChange / OnActiveChange で同期する。
    起動直後は無題の文書が1つある（OpenFile は使わず、必ず新しい文書で開く）。
    文書は常に1つ以上ある（最後の1つを閉じると、空の無題ができる）。
  ※ Text は JS からの通知で更新される非同期ミラー（編集後 約0.1秒の遅延）。
  ※ Line/Column は Monaco 準拠(1始まり、桁は UTF-16 単位)。 }
unit ucmmonacoview;

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils, Controls, Forms, ExtCtrls, Clipbrd, Menus, LCLType,
  LazUTF8, LConvEncoding,
  uWVBrowser, uWVWindowParent, uWVLoader, uWVTypes, uWVTypeLibrary,
  uWVEvents, uWVCoreWebView2Args, uWVCoreWebView2ObjectCollectionView, uWVCoreWebView2File;

type
  TCMEncoding = (ceUTF8, ceUTF8BOM, ceUTF16LE, ceUTF16BE, ceCP932);

  TCMFindOption = (foMatchCase, foWholeWord, foLoop);
  TCMFindOptions = set of TCMFindOption;

  TCMCursorEvent = procedure(Sender: TObject; Line, Column: Integer) of object;
  TCMModeEvent = procedure(Sender: TObject; IsOverwrite: Boolean) of object;
  TCMSaveEvent = procedure(Sender: TObject; const AFileName: string) of object;
  TCMFindRequestEvent = procedure(Sender: TObject; const InitialText: string) of object;
  TCMFindDoneEvent = procedure(Sender: TObject; Found: Boolean) of object;
  TCMReplaceAllDoneEvent = procedure(Sender: TObject; Count: Integer) of object;
  TCMNeedFileNameEvent = procedure(Sender: TObject; var AFileName: string; var Cancel: Boolean) of object;
  TCMErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;
  TCMDocIndexEvent = procedure(Sender: TObject; Index: Integer) of object;
  TCMQueryCloseEvent = procedure(Sender: TObject; Index: Integer; var CanClose: Boolean) of object;
  TCMFileDropEvent = procedure(Sender: TObject; Files: TStrings; var Handled: Boolean) of object;
  TCMScrollEvent = procedure(Sender: TObject; TopLine: Double) of object;
  TCMKeyEvent = procedure(Sender: TObject; var Key: Word; Shift: TShiftState) of object;

  { TCMDocument : 1つの文書（タブ1つ分）の状態 }
  TCMDocument = class
  public
    Id: Integer;
    FileName: string;
    Encoding: TCMEncoding;
    Modified: Boolean;
    Text: string;
    Language: string;
  end;

  TCMMenuCmd = (mcCut, mcCopy, mcPaste, mcQuoteCopy, mcAppendCut, mcAppendCopy, mcDelete,
    mcUpper, mcLower, mcHankaku, mcHiragana, mcKatakana, mcDetab, mcEntab,
    mcIndent, mcOutdent, mcSelectAll, mcUndo, mcRedo);

  { TCMMenuItem : 内蔵メニュー項目（表示条件つき）。自分で追加する通常の TMenuItem は影響を受けない }
  TCMMenuItem = class(TMenuItem)
  public
    Cmd: TCMMenuCmd;
    Vis: Integer;         { 1=選択あり時のみ 2=常に 3=選択なし時のみ }
    NeedEdit: Boolean;    { True なら ReadOnly 時は無効 }
  end;

  { TCMMonacoView }

  TCMMonacoView = class(TWinControl)
  private
    FBrowser: TWVBrowser;
    FWindowParent: TWVWindowParent;
    FInitTimer: TTimer;
    FBrowserCreated: Boolean;
    FReady: Boolean;
    FDocs: TList;
    FActive: Integer;
    FNextId: Integer;
    FLines: TStringList;
    FOverwrite: Boolean;
    FWordWrap: Boolean;
    FLineNumbers: Boolean;
    FReadOnly: Boolean;
    FFontSize: Integer;
    FTheme: string;
    FResourcePath: string;
    FJapaneseUI: Boolean;
    FDefaultLanguage: string;
    FAutoLanguage: Boolean;
    FHitColorLight, FHitColorDark: string;
    FCursorLineColorLight, FCursorLineColorDark: string;
    FSelectionColorLight, FSelectionColorDark: string;   { 【2.13】選択範囲の背景色 }
    FPopup: TPopupMenu;
    FQuotePrefix: string;
    FTabSize: Integer;
    FFolding: Boolean;
    FMatchBrackets: Boolean;
    FOccurrencesHighlight: Boolean;
    FMinimap: Boolean;
    FOnGotFocus: TNotifyEvent;
    FOnTogglePreview: TNotifyEvent;
    FOnOsThemeChange: TCMModeEvent;
    FOnAccelKeyDown: TCMKeyEvent;
    FOnPopup: TNotifyEvent;
    FMenuPos: TPoint;
    FDropFiles: TStringList;
    FTopLine: Double;
    FOnScrollChange: TCMScrollEvent;
    FOpenDroppedFiles: Boolean;
    FOnFileDrop: TCMFileDropEvent;
    FCursorLine, FCursorCol: Integer;
    FSelectedText: string;
    FSelStart, FSelLength: Integer;   { 【段階6】選択の開始位置（0始まり）と長さ。UTF-16 単位 }
    FCanUndo: Boolean;                { 【段階6】表示中の文書で Undo できるか }
    FCanRedo: Boolean;                { 【2.17】表示中の文書で Redo できるか }
    FCursorLineText: string;          { 【2.13】カーソル行の文字列（cursorline で受ける） }
    FCursorLineSeq: Cardinal;         { 【2.13】FCursorLineText が変わるたびに 1 増やす }
    FSearchText, FReplaceText: string;
    FSearchOptions: TCMFindOptions;
    FSearchHistory, FReplaceHistory: TStringList;

    FOnReady: TNotifyEvent;
    FOnChange: TNotifyEvent;
    FOnCursorChange: TCMCursorEvent;
    FOnModeChange: TCMModeEvent;
    FOnSave: TCMSaveEvent;
    FOnModifiedChange: TNotifyEvent;
    FOnToggleMaximize: TNotifyEvent;
    FOnFindRequest: TCMFindRequestEvent;
    FOnFindDone: TCMFindDoneEvent;
    FOnReplaceAllDone: TCMReplaceAllDoneEvent;
    FOnNeedFileName: TCMNeedFileNameEvent;
    FOnFontSizeChange: TNotifyEvent;
    FOnLineNumbersChange: TNotifyEvent;
    FOnError: TCMErrorEvent;
    FOnActiveChange: TNotifyEvent;
    FOnDocListChange: TNotifyEvent;
    FOnDocumentChange: TCMDocIndexEvent;
    FOnQueryClose: TCMQueryCloseEvent;

    procedure BrowserAfterCreated(Sender: TObject);
    procedure BrowserInitError(Sender: TObject; aErrorCode: HRESULT; const aErrorMessage: wvstring);
    procedure BrowserAcceleratorKeyPressed(Sender: TObject; const aController: ICoreWebView2Controller;
      const aArgs: ICoreWebView2AcceleratorKeyPressedEventArgs);
    procedure BrowserWebMessageReceived(Sender: TObject; const aWebView: ICoreWebView2;
      const aArgs: ICoreWebView2WebMessageReceivedEventArgs);
    procedure InitTimerTick(Sender: TObject);

    procedure DoError(const AMessage: string);
    procedure SendCmd(const S: string);
    procedure ApplyAllOptions;
    procedure HandleMessage(const Msg: string);
    function GetResourceDir: string;
    procedure AddHistory(AList: TStringList; const S: string);
    procedure SendColors;

    { ポップアップメニュー }
    function AddMenuItem(const ACaption: string; ACmd: TCMMenuCmd; AVis: Integer;
      ANeedEdit: Boolean): TCMMenuItem;
    procedure BuildPopupMenu;
    procedure PopupMenuPopup(Sender: TObject);
    procedure MenuItemClick(Sender: TObject);
    procedure ShowContextMenu;
    procedure AsyncContextMenu(Data: PtrInt);
    procedure CollectDroppedFiles(AArgs: TCoreWebView2WebMessageReceivedEventArgs);
    procedure AsyncDropFiles(Data: PtrInt);
    procedure SetTabSize(AValue: Integer);
    procedure SetFolding(AValue: Boolean);
    procedure SetMatchBrackets(AValue: Boolean);
    procedure SetOccurrencesHighlight(AValue: Boolean);
    procedure SetMinimap(AValue: Boolean);

    { 文書管理（内部） }
    function DocAt(AIndex: Integer): TCMDocument;
    function DocById(AId: Integer): TCMDocument;
    function ActiveDoc: TCMDocument;
    function EnsureActiveDoc: TCMDocument;
    function NewDocument(const AFileName: string): TCMDocument;
    procedure SetDocModified(ADoc: TCMDocument; AValue: Boolean);
    procedure DoDocChange(ADoc: TCMDocument);
    procedure DoListChange;
    procedure DoSaveDoc(ADoc: TCMDocument; const AFileName: string);
    procedure LoadIntoDoc(ADoc: TCMDocument; const S, AFileName: string; AEnc: TCMEncoding);

    { プロパティ }
    function GetText: string;
    function GetFileName: string;
    function GetEncoding: TCMEncoding;
    function GetModified: Boolean;
    function GetLanguage: string;
    function GetLines: TStrings;
    procedure SetLines(AValue: TStrings);
    procedure SetText(const AValue: string);
    procedure SetFileName(const AValue: string);
    procedure SetEncoding(AValue: TCMEncoding);
    procedure SetModified(AValue: Boolean);
    procedure SetLanguage(const AValue: string);
    procedure SetWordWrap(AValue: Boolean);
    procedure SetLineNumbers(AValue: Boolean);
    procedure SetFontSize(AValue: Integer);
    procedure SetTheme(const AValue: string);
    procedure SetReadOnly(AValue: Boolean);
    procedure SetHitColorLight(const AValue: string);
    procedure SetHitColorDark(const AValue: string);
    procedure SetCursorLineColorLight(const AValue: string);
    procedure SetCursorLineColorDark(const AValue: string);
    procedure SetSelectionColorLight(const AValue: string);
    procedure SetSelectionColorDark(const AValue: string);
    function GetSearchHistory: TStrings;
    function GetReplaceHistory: TStrings;
    function GetDocumentCount: Integer;
    function GetActiveIndex: Integer;
    procedure SetActiveIndex(AValue: Integer);
    function GetDocumentFileName(AIndex: Integer): string;
    function GetDocumentModified(AIndex: Integer): Boolean;
    function GetDocumentTitle(AIndex: Integer): string;
    function GetDocumentEncoding(AIndex: Integer): TCMEncoding;
    procedure SetDocumentEncoding(AIndex: Integer; AValue: TCMEncoding);
    function GetDocumentLanguage(AIndex: Integer): string;
    function GetDocumentText(AIndex: Integer): string;
    procedure SetDocumentText(AIndex: Integer; const AValue: string);
    procedure SetDocumentLanguage(AIndex: Integer; const AValue: string);
  protected
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetFocus; override;

    { ---- 複数文書 ---- }
    function AddDocument(const AFileName: string = ''): Integer;   { 新規文書を追加してアクティブにする。戻り値=Index }
    function OpenFile(const AFileName: string): Integer;           { 開いて（既に開いていればそのタブへ）アクティブにする }
    function FindDocument(const AFileName: string): Integer;       { 見つからなければ -1 }
    function CloseDocument(AIndex: Integer; Force: Boolean = False): Boolean;
    function CloseAll(Force: Boolean = False): Boolean;
    procedure MoveDocument(AFromIndex, AToIndex: Integer);
    procedure SaveDocument(AIndex: Integer);
    procedure SaveAll;
    property DocumentCount: Integer read GetDocumentCount;
    property ActiveIndex: Integer read GetActiveIndex write SetActiveIndex;
    property DocumentFileName[AIndex: Integer]: string read GetDocumentFileName;
    property DocumentModified[AIndex: Integer]: Boolean read GetDocumentModified;
    property DocumentTitle[AIndex: Integer]: string read GetDocumentTitle;   { ファイル名のみ。無題は '無題' }
    { 【段階2】文書の識別番号（閉じるまで変わらない。並べ替えても変わらない）。範囲外は -1 }
    function DocumentId(AIndex: Integer): Integer;
    { 【段階2】識別番号から今の位置を返す。閉じていれば -1 }
    function IndexOfId(AId: Integer): Integer;
    { 【段階2】番号を指定した文書の操作（表示は切り替えない） }
    property DocumentEncoding[AIndex: Integer]: TCMEncoding read GetDocumentEncoding write SetDocumentEncoding;
    property DocumentLanguage[AIndex: Integer]: string read GetDocumentLanguage write SetDocumentLanguage;
    { 【段階3】本文。代入すると内容だけ置き換え、変更ありにする（ファイル名はそのまま。Undo の履歴は消える） }
    property DocumentText[AIndex: Integer]: string read GetDocumentText write SetDocumentText;
    procedure LoadDocument(AIndex: Integer; const AFileName: string);    { 内容を捨てて読み込む（聞かない）。読めなければ例外（何も変えない） }
    procedure ClearDocument(AIndex: Integer);                            { 内容を空にし、無題にする（聞かない） }
    procedure SaveDocumentTo(AIndex: Integer; const AFileName: string);  { 指定の名前で保存（'' なら今の名前。無題で '' なら OnNeedFileName） }

    { ---- アクティブ文書のファイル入出力（文字コード・BOMは読み込み時のものを保持） ---- }
    procedure LoadFromFile(const AFileName: string);   { アクティブ文書の内容を置き換える }
    procedure SaveToFile(const AFileName: string = '');

    { カーソル・選択 }
    procedure SetCursorPos(ALine, AColumn: Integer);
    procedure GetCursorPos(out ALine, AColumn: Integer);
    procedure SetSelection(AStartLine, AStartCol, AEndLine, AEndCol: Integer);
    function GetSelectedText: string;
    procedure ToggleOverwrite;
    procedure ScrollToLine(ALine: Double);   { 指定の行（小数可）が先頭に来るようにスクロール（同期スクロール用） }
    procedure ReplaceSelection(const S: string);   { 選択範囲を置換（置換後の文字列が選択状態になる。Undo 1回分）。右クリックの変換用 }
    procedure SetSelText(const S: string);         { 【段階6】選択範囲を置換（未選択なら挿入、'' なら削除）。置換後は選択を解除し、後ろにカーソル。Undo 1回分 }
    procedure DeleteToEnd;                         { 【段階6】カーソル位置から末尾までを削除（選択は無視）。Undo 1回分 }
    procedure DeleteToStart;                       { 【段階6】カーソル位置から先頭までを削除（選択は無視）。Undo 1回分 }
    procedure DuplicateLine;                       { 【2.16】カーソル行（選択した行）を複製して下へ（Shift+F10 と同じ）。Undo 1回分 }
    property CursorLineText: string read FCursorLineText;   { 【2.13】カーソル行の文字列（改行なし） }
    property CursorLineSeq: Cardinal read FCursorLineSeq;   { 【2.13】CursorLineText が変わるたびに増える番号 }
    property SelStart: Integer read FSelStart;     { 【段階6】選択の開始位置（未選択ならカーソル位置）。先頭から 0 始まり、UTF-16 単位 }
    property SelLength: Integer read FSelLength;   { 【段階6】選択の長さ。0 なら未選択 }
    property CanUndo: Boolean read FCanUndo;       { 【段階6】表示中の文書で Undo できるか }
    property CanRedo: Boolean read FCanRedo;       { 【2.17】表示中の文書で Redo できるか }

    { 編集 }
    procedure Undo;
    procedure Redo;
    procedure Cut;
    procedure Copy;
    procedure Paste;
    procedure SelectAll;

    { 検索・置換（アクティブ文書が対象）。結果は OnFindDone / OnReplaceAllDone で通知 }
    procedure Find(const S: string; AOptions: TCMFindOptions; AForward: Boolean = True);
    procedure FindNext;
    procedure FindPrev;
    procedure Replace(const S, R: string; AOptions: TCMFindOptions);
    procedure ReplaceAll(const S, R: string; AOptions: TCMFindOptions);

    procedure OpenDevTools;

    property Ready: Boolean read FReady;
    property TopLine: Double read FTopLine;   { 表示している先頭の行（1始まり、小数は行内の位置）。プレビューの同期スクロール用 }
    property Lines: TStrings read GetLines write SetLines;   { Text のコピー。編集結果は Lines を代入し直す }
    property Encoding: TCMEncoding read GetEncoding write SetEncoding;
    property Modified: Boolean read GetModified write SetModified;
    property Language: string read GetLanguage write SetLanguage;   { アクティブ文書の言語 }
    property SearchText: string read FSearchText write FSearchText;
    property ReplaceText: string read FReplaceText write FReplaceText;
    property SearchOptions: TCMFindOptions read FSearchOptions write FSearchOptions;
    property SearchHistory: TStrings read GetSearchHistory;
    property ReplaceHistory: TStrings read GetReplaceHistory;
  published
    property FileName: string read GetFileName write SetFileName;
    property Text: string read GetText write SetText stored False;
    property WordWrap: Boolean read FWordWrap write SetWordWrap default True;
    property LineNumbers: Boolean read FLineNumbers write SetLineNumbers default False;
    property FontSize: Integer read FFontSize write SetFontSize default 14;
    property Theme: string read FTheme write SetTheme;      { 'auto'(OS追従) / 'vs-dark' / 'vs' }
    property ReadOnly: Boolean read FReadOnly write SetReadOnly default False;
    property ResourcePath: string read FResourcePath write FResourcePath;   { 空なら WebView2.ini の MonacoFolder、それも無ければ EXE隣の monaco\（【2.19】） }
    property JapaneseUI: Boolean read FJapaneseUI write FJapaneseUI default True;
    property OpenDroppedFiles: Boolean read FOpenDroppedFiles write FOpenDroppedFiles default True;   { ファイルをD&Dしたら新しいタブで開く }
    property DefaultLanguage: string read FDefaultLanguage write FDefaultLanguage;   { 新規文書・拡張子不明の言語。既定 'pascal' }
    property AutoLanguage: Boolean read FAutoLanguage write FAutoLanguage default True;   { ファイル名から言語を自動判定 }
    property HitColorLight: string read FHitColorLight write SetHitColorLight;   { 検索ヒット(非フォーカス選択)の背景 '#RRGGBB' }
    property HitColorDark: string read FHitColorDark write SetHitColorDark;
    property CursorLineColorLight: string read FCursorLineColorLight write SetCursorLineColorLight;
    property CursorLineColorDark: string read FCursorLineColorDark write SetCursorLineColorDark;
    property SelectionColorLight: string read FSelectionColorLight write SetSelectionColorLight;   { 【2.13】選択範囲の背景 '#RRGGBB' }
    property SelectionColorDark: string read FSelectionColorDark write SetSelectionColorDark;

    property QuotePrefix: string read FQuotePrefix write FQuotePrefix;   { 引用付きコピーの行頭記号。既定 '> ' }
    property TabSize: Integer read FTabSize write SetTabSize default 4;
    property Folding: Boolean read FFolding write SetFolding default True;                      { 折りたたみ }
    property MatchBrackets: Boolean read FMatchBrackets write SetMatchBrackets default True;    { 括弧の対応表示 }
    property OccurrencesHighlight: Boolean read FOccurrencesHighlight write SetOccurrencesHighlight default True;   { 同じ単語の強調 }
    property Minimap: Boolean read FMinimap write SetMinimap default False;                     { ミニマップ }

    property PopupMenu;   { 右クリックメニュー。項目は Ed.PopupMenu.Items.Add で追加できる }
    property Align;
    property Anchors;
    property Enabled;
    property TabOrder;
    property TabStop;
    property Visible;

    property OnReady: TNotifyEvent read FOnReady write FOnReady;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;   { アクティブ文書のユーザー編集 }
    property OnCursorChange: TCMCursorEvent read FOnCursorChange write FOnCursorChange;
    property OnModeChange: TCMModeEvent read FOnModeChange write FOnModeChange;
    property OnSave: TCMSaveEvent read FOnSave write FOnSave;
    property OnModifiedChange: TNotifyEvent read FOnModifiedChange write FOnModifiedChange;   { アクティブ文書の Modified 変化 }
    property OnToggleMaximize: TNotifyEvent read FOnToggleMaximize write FOnToggleMaximize;
    property OnFindRequest: TCMFindRequestEvent read FOnFindRequest write FOnFindRequest;   { Ctrl+F }
    property OnFindDone: TCMFindDoneEvent read FOnFindDone write FOnFindDone;
    property OnReplaceAllDone: TCMReplaceAllDoneEvent read FOnReplaceAllDone write FOnReplaceAllDone;
    property OnNeedFileName: TCMNeedFileNameEvent read FOnNeedFileName write FOnNeedFileName;   { 無題文書の保存時 }
    property OnFontSizeChange: TNotifyEvent read FOnFontSizeChange write FOnFontSizeChange;
    property OnLineNumbersChange: TNotifyEvent read FOnLineNumbersChange write FOnLineNumbersChange;
    property OnError: TCMErrorEvent read FOnError write FOnError;
    property OnActiveChange: TNotifyEvent read FOnActiveChange write FOnActiveChange;      { アクティブ文書が変わった }
    property OnDocListChange: TNotifyEvent read FOnDocListChange write FOnDocListChange;   { 追加・削除・並べ替え }
    property OnDocumentChange: TCMDocIndexEvent read FOnDocumentChange write FOnDocumentChange;   { ファイル名/Modified の変化(タブ表示更新用) }
    property OnScrollChange: TCMScrollEvent read FOnScrollChange write FOnScrollChange;   { 表示位置（先頭行）の変化 }
    property OnFileDrop: TCMFileDropEvent read FOnFileDrop write FOnFileDrop;   { D&D通知。Handled:=True で標準の開く処理を止める }
    property OnPopup: TNotifyEvent read FOnPopup write FOnPopup;   { メニュー表示直前。自作項目の表示/有効を調整する }
    property OnGotFocus: TNotifyEvent read FOnGotFocus write FOnGotFocus;             { Monaco がフォーカスを受けた（JS から通知） }
    property OnTogglePreview: TNotifyEvent read FOnTogglePreview write FOnTogglePreview;   { Ctrl+Shift+V }
    property OnOsThemeChange: TCMModeEvent read FOnOsThemeChange write FOnOsThemeChange;   { 実行中に OS のテーマが変わった（引数 True=ダーク） }
    property OnAccelKeyDown: TCMKeyEvent read FOnAccelKeyDown write FOnAccelKeyDown;  { ショートカット用のキー。Key := 0 で Monaco に渡さない }
    property OnQueryClose: TCMQueryCloseEvent read FOnQueryClose write FOnQueryClose;   { 未保存文書を閉じる前の確認。CanClose:=False で中止 }
  end;

{ 設計時（IDE 上）かどうか。自分・Owner・親のどれかが設計中なら True（複合部品の中に入れた場合も判定できる） }
function CMIsDesigning(AControl: TControl): Boolean;

{ 選択範囲の文字列変換（自作メニューからも使える） }
function CMToHankaku(const S: string): string;             { 全角英数字・記号・カタカナ → 半角 }
function CMToZenkakuKatakana(const S: string): string;     { ひらがな・半角カナ → 全角カタカナ }
function CMToZenkakuHiragana(const S: string): string;     { カタカナ・半角カナ → 全角ひらがな }

implementation

uses
  uCXRuntime;   { monaco フォルダの場所を決める（WebView2.ini の MonacoFolder）・WebView2 の準備 }

const
  SEP = #1;
  VHOST = 'cmonaco.example';
  MAX_HISTORY = 30;

{ ---------- 文字列ヘルパー ---------- }

function WVStr(const S: string): wvstring;
begin
  Result := UTF8Decode(S);
end;

function FromWV(const S: wvstring): string;
begin
  Result := UTF8Encode(UnicodeString(S));
end;

function B2S(B: Boolean): string;
begin
  if B then Result := '1' else Result := '0';
end;

function CMIsDesigning(AControl: TControl): Boolean;
var
  C: TControl;
begin
  Result := False;
  if AControl = nil then Exit;
  if (csDesigning in AControl.ComponentState) or
     ((AControl.Owner <> nil) and (csDesigning in AControl.Owner.ComponentState)) then Exit(True);
  C := AControl.Parent;
  while C <> nil do
  begin
    if csDesigning in C.ComponentState then Exit(True);
    C := C.Parent;
  end;
end;

function NextPart(var S: string): string;
var
  P: Integer;
begin
  P := Pos(SEP, S);
  if P = 0 then
  begin
    Result := S;
    S := '';
  end
  else
  begin
    Result := Copy(S, 1, P - 1);
    Delete(S, 1, P);
  end;
end;

function LanguageForFile(const AFileName, ADefault: string): string;
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
  { 【段階5】追加 }
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

{ ---------- 文字コード変換 ---------- }

function BytesToStr(const B: TBytes; AStart: Integer): string;
var
  N: Integer;
begin
  N := Length(B) - AStart;
  if N <= 0 then Exit('');
  SetLength(Result, N);
  Move(B[AStart], Result[1], N);
end;

function DecodeFileBytes(const B: TBytes; out Enc: TCMEncoding): string;
var
  US: UnicodeString;
  I, N: Integer;
  LE: Boolean;
begin
  Enc := ceUTF8;
  Result := '';
  if Length(B) = 0 then Exit;

  if (Length(B) >= 3) and (B[0] = $EF) and (B[1] = $BB) and (B[2] = $BF) then
  begin
    Enc := ceUTF8BOM;
    Exit(BytesToStr(B, 3));
  end;

  if (Length(B) >= 2) and (((B[0] = $FF) and (B[1] = $FE)) or ((B[0] = $FE) and (B[1] = $FF))) then
  begin
    LE := B[0] = $FF;
    if LE then Enc := ceUTF16LE else Enc := ceUTF16BE;
    N := (Length(B) - 2) div 2;
    SetLength(US, N);
    for I := 0 to N - 1 do
      if LE then
        US[I + 1] := WideChar(B[2 + 2 * I] or (B[3 + 2 * I] shl 8))
      else
        US[I + 1] := WideChar((B[2 + 2 * I] shl 8) or B[3 + 2 * I]);
    Exit(UTF8Encode(US));
  end;

  Result := BytesToStr(B, 0);
  if FindInvalidUTF8Codepoint(PChar(Result), Length(Result), False) = -1 then
    Enc := ceUTF8
  else
  begin
    Enc := ceCP932;
    Result := ConvertEncoding(Result, 'cp932', 'utf8');
  end;
end;

function EncodeText(const S: string; Enc: TCMEncoding): TBytes;
var
  US: UnicodeString;
  T: string;
  I, N, Off: Integer;
  W: Word;
begin
  Result := nil;
  case Enc of
    ceUTF8, ceUTF8BOM:
      begin
        if Enc = ceUTF8BOM then Off := 3 else Off := 0;
        SetLength(Result, Off + Length(S));
        if Off = 3 then
        begin
          Result[0] := $EF; Result[1] := $BB; Result[2] := $BF;
        end;
        if Length(S) > 0 then Move(S[1], Result[Off], Length(S));
      end;
    ceUTF16LE, ceUTF16BE:
      begin
        US := UTF8Decode(S);
        N := Length(US);
        SetLength(Result, 2 + 2 * N);
        if Enc = ceUTF16LE then
        begin
          Result[0] := $FF; Result[1] := $FE;
        end
        else
        begin
          Result[0] := $FE; Result[1] := $FF;
        end;
        for I := 1 to N do
        begin
          W := Word(US[I]);
          if Enc = ceUTF16LE then
          begin
            Result[2 * I] := W and $FF;
            Result[2 * I + 1] := W shr 8;
          end
          else
          begin
            Result[2 * I] := W shr 8;
            Result[2 * I + 1] := W and $FF;
          end;
        end;
      end;
    ceCP932:
      begin
        T := ConvertEncoding(S, 'utf8', 'cp932');
        if ConvertEncoding(T, 'cp932', 'utf8') <> S then
          raise Exception.Create('CP932(Shift_JIS)で表現できない文字が含まれています。Encoding を UTF-8 に変更してください。');
        SetLength(Result, Length(T));
        if Length(T) > 0 then Move(T[1], Result[0], Length(T));
      end;
  end;
end;

function LoadTextFile(const AFileName: string; out Enc: TCMEncoding): string;
var
  FS: TFileStream;
  B: TBytes;
begin
  FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(B, FS.Size);
    if FS.Size > 0 then FS.ReadBuffer(B[0], FS.Size);
  finally
    FS.Free;
  end;
  Result := DecodeFileBytes(B, Enc);
end;

{ ---------- 文字列変換（半角/全角・ひらがな/カタカナ） ---------- }

const
  FullKanaCodes: array[0..62] of Word = (
    $30F2, $30A1, $30A3, $30A5, $30A7, $30A9, $30E3, $30E5,
    $30E7, $30C3, $30FC, $30A2, $30A4, $30A6, $30A8, $30AA,
    $30AB, $30AD, $30AF, $30B1, $30B3, $30B5, $30B7, $30B9,
    $30BB, $30BD, $30BF, $30C1, $30C4, $30C6, $30C8, $30CA,
    $30CB, $30CC, $30CD, $30CE, $30CF, $30D2, $30D5, $30D8,
    $30DB, $30DE, $30DF, $30E0, $30E1, $30E2, $30E4, $30E6,
    $30E8, $30E9, $30EA, $30EB, $30EC, $30ED, $30EF, $30F3,
    $309B, $309C, $3002, $300C, $300D, $3001, $30FB);

  HalfKanaCodes: array[0..62] of Word = (
    $FF66, $FF67, $FF68, $FF69, $FF6A, $FF6B, $FF6C, $FF6D,
    $FF6E, $FF6F, $FF70, $FF71, $FF72, $FF73, $FF74, $FF75,
    $FF76, $FF77, $FF78, $FF79, $FF7A, $FF7B, $FF7C, $FF7D,
    $FF7E, $FF7F, $FF80, $FF81, $FF82, $FF83, $FF84, $FF85,
    $FF86, $FF87, $FF88, $FF89, $FF8A, $FF8B, $FF8C, $FF8D,
    $FF8E, $FF8F, $FF90, $FF91, $FF92, $FF93, $FF94, $FF95,
    $FF96, $FF97, $FF98, $FF99, $FF9A, $FF9B, $FF9C, $FF9D,
    $FF9E, $FF9F, $FF61, $FF62, $FF63, $FF64, $FF65);

function KanaIndexFull(C: Word): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FullKanaCodes) do
    if FullKanaCodes[I] = C then Exit(I);
  Result := -1;
end;

function KanaIndexHalf(C: Word): Integer;
var
  I: Integer;
begin
  for I := 0 to High(HalfKanaCodes) do
    if HalfKanaCodes[I] = C then Exit(I);
  Result := -1;
end;

function IsVoicedKana(C: Word): Boolean;
begin
  case C of
    $30AC, $30AE, $30B0, $30B2, $30B4, $30B6, $30B8, $30BA, $30BC, $30BE,
    $30C0, $30C2, $30C5, $30C7, $30C9, $30D0, $30D3, $30D6, $30D9, $30DC: Result := True;
  else
    Result := False;
  end;
end;

function IsSemiVoicedKana(C: Word): Boolean;
begin
  case C of
    $30D1, $30D4, $30D7, $30DA, $30DD: Result := True;
  else
    Result := False;
  end;
end;

function CanVoiceKana(C: Word): Boolean;
begin
  case C of
    $30A6, $30AB, $30AD, $30AF, $30B1, $30B3, $30B5, $30B7, $30B9, $30BB, $30BD, $30BF,
    $30C1, $30C4, $30C6, $30C8, $30CF, $30D2, $30D5, $30D8, $30DB: Result := True;
  else
    Result := False;
  end;
end;

function CanSemiVoiceKana(C: Word): Boolean;
begin
  case C of
    $30CF, $30D2, $30D5, $30D8, $30DB: Result := True;
  else
    Result := False;
  end;
end;

function KatakanaW(const U: UnicodeString): UnicodeString;
var
  I, N, K: Integer;
  C, D: Word;
  R: UnicodeString;
begin
  SetLength(R, Length(U));
  N := 0;
  I := 1;
  while I <= Length(U) do
  begin
    C := Word(U[I]);
    if ((C >= $3041) and (C <= $3096)) or ((C >= $309D) and (C <= $309E)) then
      C := C + $60
    else
    begin
      K := KanaIndexHalf(C);
      if K >= 0 then
      begin
        D := FullKanaCodes[K];
        if (C <> $FF9E) and (C <> $FF9F) and (I < Length(U)) then
        begin
          if (Word(U[I + 1]) = $FF9E) and CanVoiceKana(D) then
          begin
            if D = $30A6 then D := $30F4 else D := D + 1;
            Inc(I);
          end
          else if (Word(U[I + 1]) = $FF9F) and CanSemiVoiceKana(D) then
          begin
            D := D + 2;
            Inc(I);
          end;
        end;
        C := D;
      end;
    end;
    Inc(N);
    R[N] := WideChar(C);
    Inc(I);
  end;
  SetLength(R, N);
  Result := R;
end;

function CMToZenkakuKatakana(const S: string): string;
begin
  Result := UTF8Encode(KatakanaW(UTF8Decode(S)));
end;

function CMToZenkakuHiragana(const S: string): string;
var
  R: UnicodeString;
  I: Integer;
  C: Word;
begin
  R := KatakanaW(UTF8Decode(S));
  for I := 1 to Length(R) do
  begin
    C := Word(R[I]);
    if ((C >= $30A1) and (C <= $30F6)) or ((C >= $30FD) and (C <= $30FE)) then
      R[I] := WideChar(C - $60);
  end;
  Result := UTF8Encode(R);
end;

function CMToHankaku(const S: string): string;
var
  U, R: UnicodeString;
  I, N, K: Integer;
  C: Word;

  procedure Put(W: Word);
  begin
    Inc(N);
    R[N] := WideChar(W);
  end;

begin
  U := UTF8Decode(S);
  SetLength(R, Length(U) * 2);
  N := 0;
  for I := 1 to Length(U) do
  begin
    C := Word(U[I]);
    if (C >= $FF01) and (C <= $FF5E) then
      Put(C - $FEE0)
    else if C = $3000 then
      Put($20)
    else
    begin
      K := KanaIndexFull(C);
      if K >= 0 then
        Put(HalfKanaCodes[K])
      else if IsVoicedKana(C) then
      begin
        Put(HalfKanaCodes[KanaIndexFull(C - 1)]);
        Put($FF9E);
      end
      else if IsSemiVoicedKana(C) then
      begin
        Put(HalfKanaCodes[KanaIndexFull(C - 2)]);
        Put($FF9F);
      end
      else if C = $30F4 then
      begin
        Put($FF73);
        Put($FF9E);
      end
      else
        Put(C);
    end;
  end;
  SetLength(R, N);
  Result := UTF8Encode(R);
end;

{ ---------- TCMMonacoView ---------- }

constructor TCMMonacoView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 400;
  Height := 300;
  TabStop := True;

  FFontSize := 14;
  FTheme := 'auto';
  FJapaneseUI := True;
  FDefaultLanguage := 'pascal';
  FAutoLanguage := True;
  FHitColorLight := '#FFEE58';
  FHitColorDark := '#7D6608';
  FCursorLineColorLight := '#EAF2FF';
  FCursorLineColorDark := '#2C313C';
  FSelectionColorLight := '#ADD6FF';   { 【2.13】 }
  FSelectionColorDark := '#264F78';
  FSearchOptions := [foLoop];
  FCursorLine := 1;
  FCursorCol := 1;
  FLines := TStringList.Create;
  FSearchHistory := TStringList.Create;
  FReplaceHistory := TStringList.Create;
  FDocs := TList.Create;
  FActive := -1;
  FQuotePrefix := '> ';
  FOpenDroppedFiles := True;
  FTopLine := 1;
  FDropFiles := TStringList.Create;
  FTabSize := 4;
  FWordWrap := True;
  FFolding := True;
  FMatchBrackets := True;
  FOccurrencesHighlight := True;
  FMinimap := False;

  FWindowParent := TWVWindowParent.Create(Self);
  FWindowParent.Parent := Self;
  FWindowParent.Align := alClient;

  FBrowser := TWVBrowser.Create(Self);
  FBrowser.OnAfterCreated := @BrowserAfterCreated;
  FBrowser.OnInitializationError := @BrowserInitError;
  FBrowser.OnWebMessageReceived := @BrowserWebMessageReceived;
  FBrowser.OnAcceleratorKeyPressed := @BrowserAcceleratorKeyPressed;
  FBrowser.AreBrowserAcceleratorKeysEnabled := False;   { F5/F11/F12/Ctrl+S 等の既定動作を無効化 }
  FBrowser.ZoomControlEnabled := False;
  FBrowser.DevToolsEnabled := False;
  FBrowser.StatusBarEnabled := False;
  FWindowParent.Browser := FBrowser;

  FInitTimer := TTimer.Create(Self);
  FInitTimer.Enabled := False;
  FInitTimer.Interval := 100;
  FInitTimer.OnTimer := @InitTimerTick;

  BuildPopupMenu;
  PopupMenu := FPopup;

  { 起動直後は無題の文書を1つ持つ }
  NewDocument('');
  FActive := 0;
end;

destructor TCMMonacoView.Destroy;
var
  I: Integer;
begin
  FInitTimer.Enabled := False;
  Application.RemoveAsyncCalls(Self);
  for I := 0 to FDocs.Count - 1 do
    TCMDocument(FDocs[I]).Free;
  FDocs.Free;
  FDropFiles.Free;
  FLines.Free;
  FSearchHistory.Free;
  FReplaceHistory.Free;
  inherited Destroy;
end;

procedure TCMMonacoView.CreateWnd;
begin
  inherited CreateWnd;
  if not CMIsDesigning(Self) and not FBrowserCreated then
    FInitTimer.Enabled := True;
end;

procedure TCMMonacoView.InitTimerTick(Sender: TObject);
var
  Err: string;
begin
  if FBrowserCreated then
  begin
    FInitTimer.Enabled := False;
    Exit;
  end;
  { 【2.10】見えていない間（TPageControl の選ばれていないシートなど）は作らない。
    見えない状態で作ると、表示しても WebView2 が見えないまま（白く、入力できない）になるため。
    次のタイマーで、もう一度確かめる（プレビューと同じ） }
  if not Showing then Exit;
  { WebView2 の準備：ローダーが無ければ作って起動する（WebView2.ini を読む。uCXRuntime）。
    ほかの部品が先に作っていれば、それを使う。失敗したら知らせて、待つのをやめる }
  if GlobalWebView2Loader = nil then
    if not CXStartWebView2(Err) then
    begin
      FInitTimer.Enabled := False;
      DoError(Err);
      Exit;
    end;
  if GlobalWebView2Loader.InitializationError then
  begin
    FInitTimer.Enabled := False;
    DoError(FromWV(GlobalWebView2Loader.ErrorMessage));
    Exit;
  end;
  if GlobalWebView2Loader.Initialized then
  begin
    FInitTimer.Enabled := False;
    FBrowserCreated := True;
    FBrowser.CreateBrowser(FWindowParent.Handle);
  end;
end;

{ 【2.19】monaco フォルダの場所を決める。
  ① ResourcePath（TCMonacoEditor.MonacoPath）が空でなければ、その場所
  ② 空なら、EXE の隣の WebView2.ini の MonacoFolder
  ③ それも無ければ、EXE の隣の monaco
  相対パスは EXE のフォルダから数える（までは、起動したときの作業フォルダから数えていた） }
function TCMMonacoView.GetResourceDir: string;
begin
  Result := CXResolveRuntimeDir(FResourcePath, 'MonacoFolder', 'monaco');
end;

procedure TCMMonacoView.BrowserAfterCreated(Sender: TObject);
var
  Dir, Url: string;
begin
  FWindowParent.UpdateSize;
  Dir := GetResourceDir;
  if not FileExists(Dir + PathDelim + 'editor.html') then
  begin
    DoError('editor.html が見つかりません: ' + Dir);
    Exit;
  end;
  if not FileExists(Dir + PathDelim + 'vs' + PathDelim + 'loader.js') then
  begin
    DoError('Monaco の vs\loader.js が見つかりません: ' + Dir);
    Exit;
  end;
  FBrowser.SetVirtualHostNameToFolderMapping(WVStr(VHOST), WVStr(Dir),
    COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_ALLOW);
  Url := 'https://' + VHOST + '/editor.html';
  if FJapaneseUI then Url := Url + '?lang=ja';
  FBrowser.Navigate(WVStr(Url));
end;

procedure TCMMonacoView.BrowserInitError(Sender: TObject; aErrorCode: HRESULT;
  const aErrorMessage: wvstring);
begin
  DoError(FromWV(aErrorMessage));
end;

procedure TCMMonacoView.BrowserAcceleratorKeyPressed(Sender: TObject;
  const aController: ICoreWebView2Controller;
  const aArgs: ICoreWebView2AcceleratorKeyPressedEventArgs);
var
  Args: TCoreWebView2AcceleratorKeyPressedEventArgs;
  Key: Word;
  Shift: TShiftState;
begin
  { キーが Monaco に届く前に通知される。Key := 0 にされたら Handled にして、Monaco に渡さない }
  if not Assigned(FOnAccelKeyDown) then Exit;
  Args := TCoreWebView2AcceleratorKeyPressedEventArgs.Create(aArgs);
  try
    if (Args.KeyEventKind <> COREWEBVIEW2_KEY_EVENT_KIND_KEY_DOWN) and
       (Args.KeyEventKind <> COREWEBVIEW2_KEY_EVENT_KIND_SYSTEM_KEY_DOWN) then Exit;
    Key := Word(Args.VirtualKey);
    case Key of
      VK_SHIFT, VK_CONTROL, VK_MENU, VK_LSHIFT, VK_RSHIFT, VK_LCONTROL, VK_RCONTROL,
      VK_LMENU, VK_RMENU, VK_LWIN, VK_RWIN: Exit;   { 修飾キー単体は通知しない }
    end;
    Shift := [];
    if GetKeyState(VK_SHIFT) < 0 then Include(Shift, ssShift);
    if GetKeyState(VK_CONTROL) < 0 then Include(Shift, ssCtrl);
    if GetKeyState(VK_MENU) < 0 then Include(Shift, ssAlt);
    FOnAccelKeyDown(Self, Key, Shift);
    if Key = 0 then Args.Handled := True;
  finally
    Args.Free;
  end;
end;

procedure TCMMonacoView.BrowserWebMessageReceived(Sender: TObject; const aWebView: ICoreWebView2;
  const aArgs: ICoreWebView2WebMessageReceivedEventArgs);
var
  Args: TCoreWebView2WebMessageReceivedEventArgs;
  S: string;
begin
  Args := TCoreWebView2WebMessageReceivedEventArgs.Create(aArgs);
  try
    S := FromWV(Args.WebMessageAsString);
    if S = 'dropfiles' then CollectDroppedFiles(Args);
  finally
    Args.Free;
  end;
  HandleMessage(S);
end;

procedure TCMMonacoView.DoError(const AMessage: string);
begin
  if Assigned(FOnError) then FOnError(Self, AMessage);
end;

procedure TCMMonacoView.SendCmd(const S: string);
begin
  if FReady then FBrowser.PostWebMessageAsString(WVStr(S));
end;

procedure TCMMonacoView.SendColors;
begin
  SendCmd('opt' + SEP + 'colors' + SEP + FHitColorLight + SEP + FHitColorDark + SEP +
    FCursorLineColorLight + SEP + FCursorLineColorDark + SEP +
    FSelectionColorLight + SEP + FSelectionColorDark);   { 【2.13】 }
end;

procedure TCMMonacoView.ApplyAllOptions;
begin
  SendColors;
  SendCmd('opt' + SEP + 'wordwrap' + SEP + B2S(FWordWrap));
  SendCmd('opt' + SEP + 'linenumbers' + SEP + B2S(FLineNumbers));
  SendCmd('opt' + SEP + 'fontsize' + SEP + IntToStr(FFontSize));
  SendCmd('opt' + SEP + 'theme' + SEP + FTheme);
  SendCmd('opt' + SEP + 'readonly' + SEP + B2S(FReadOnly));
  SendCmd('opt' + SEP + 'tabsize' + SEP + IntToStr(FTabSize));
  SendCmd('opt' + SEP + 'folding' + SEP + B2S(FFolding));
  SendCmd('opt' + SEP + 'matchbrackets' + SEP + B2S(FMatchBrackets));
  SendCmd('opt' + SEP + 'occurrences' + SEP + B2S(FOccurrencesHighlight));
  SendCmd('opt' + SEP + 'minimap' + SEP + B2S(FMinimap));
end;

{ ---------- 文書管理（内部） ---------- }

function TCMMonacoView.DocAt(AIndex: Integer): TCMDocument;
begin
  if (AIndex >= 0) and (AIndex < FDocs.Count) then
    Result := TCMDocument(FDocs[AIndex])
  else
    Result := nil;
end;

function TCMMonacoView.DocById(AId: Integer): TCMDocument;
var
  I: Integer;
begin
  for I := 0 to FDocs.Count - 1 do
    if TCMDocument(FDocs[I]).Id = AId then Exit(TCMDocument(FDocs[I]));
  Result := nil;
end;

function TCMMonacoView.ActiveDoc: TCMDocument;
begin
  Result := DocAt(FActive);
end;

function TCMMonacoView.EnsureActiveDoc: TCMDocument;
begin
  if ActiveDoc = nil then AddDocument('');
  Result := ActiveDoc;
end;

function TCMMonacoView.NewDocument(const AFileName: string): TCMDocument;
begin
  Result := TCMDocument.Create;
  Inc(FNextId);
  Result.Id := FNextId;
  Result.FileName := AFileName;
  Result.Encoding := ceUTF8;
  Result.Language := FDefaultLanguage;
  if (AFileName <> '') and FAutoLanguage then
    Result.Language := LanguageForFile(AFileName, FDefaultLanguage);
  FDocs.Add(Result);
  SendCmd('doc.new' + SEP + IntToStr(Result.Id) + SEP + Result.Language + SEP + Result.Text);
end;

procedure TCMMonacoView.DoDocChange(ADoc: TCMDocument);
begin
  if Assigned(FOnDocumentChange) then FOnDocumentChange(Self, FDocs.IndexOf(ADoc));
end;

procedure TCMMonacoView.DoListChange;
begin
  if Assigned(FOnDocListChange) then FOnDocListChange(Self);
end;

procedure TCMMonacoView.SetDocModified(ADoc: TCMDocument; AValue: Boolean);
begin
  if (ADoc = nil) or (ADoc.Modified = AValue) then Exit;
  ADoc.Modified := AValue;
  DoDocChange(ADoc);
  if (ADoc = ActiveDoc) and Assigned(FOnModifiedChange) then FOnModifiedChange(Self);
end;

{ ---------- 文書管理（公開） ---------- }

function TCMMonacoView.GetDocumentCount: Integer;
begin
  Result := FDocs.Count;
end;

function TCMMonacoView.GetActiveIndex: Integer;
begin
  Result := FActive;
end;

procedure TCMMonacoView.SetActiveIndex(AValue: Integer);
var
  Doc: TCMDocument;
begin
  Doc := DocAt(AValue);
  if (Doc = nil) or (AValue = FActive) then Exit;
  FActive := AValue;
  FTopLine := 1;
  FSelectedText := '';
  FSelStart := 0; FSelLength := 0; FCanUndo := False;   { 【段階6】 }
  FCanRedo := False;                                    { 【2.17】 }
  FCursorLine := 1;
  FCursorCol := 1;
  FCursorLineText := ''; Inc(FCursorLineSeq);   { 【2.13】すぐあとに cursorline が届く }
  SendCmd('doc.activate' + SEP + IntToStr(Doc.Id));
  if Assigned(FOnActiveChange) then FOnActiveChange(Self);
end;

function TCMMonacoView.GetDocumentFileName(AIndex: Integer): string;
var
  Doc: TCMDocument;
begin
  Doc := DocAt(AIndex);
  if Doc = nil then Result := '' else Result := Doc.FileName;
end;

function TCMMonacoView.GetDocumentModified(AIndex: Integer): Boolean;
var
  Doc: TCMDocument;
begin
  Doc := DocAt(AIndex);
  Result := (Doc <> nil) and Doc.Modified;
end;

function TCMMonacoView.DocumentId(AIndex: Integer): Integer;
var
  D: TCMDocument;
begin
  D := DocAt(AIndex);
  if D <> nil then Result := D.Id else Result := -1;
end;

function TCMMonacoView.IndexOfId(AId: Integer): Integer;
var
  D: TCMDocument;
begin
  D := DocById(AId);
  if D <> nil then Result := FDocs.IndexOf(D) else Result := -1;
end;

function TCMMonacoView.GetDocumentTitle(AIndex: Integer): string;
var
  Doc: TCMDocument;
begin
  Doc := DocAt(AIndex);
  if Doc = nil then Exit('');
  if Doc.FileName = '' then Result := '無題' else Result := ExtractFileName(Doc.FileName);
end;

function TCMMonacoView.AddDocument(const AFileName: string): Integer;
begin
  NewDocument(AFileName);
  Result := FDocs.Count - 1;
  DoListChange;
  SetActiveIndex(Result);
end;

function TCMMonacoView.FindDocument(const AFileName: string): Integer;
var
  I: Integer;
  N: string;
begin
  Result := -1;
  if AFileName = '' then Exit;
  N := ExpandFileName(AFileName);
  for I := 0 to FDocs.Count - 1 do
    if (TCMDocument(FDocs[I]).FileName <> '') and
       (AnsiCompareText(ExpandFileName(TCMDocument(FDocs[I]).FileName), N) = 0) then
      Exit(I);
end;

function TCMMonacoView.OpenFile(const AFileName: string): Integer;
begin
  Result := FindDocument(AFileName);
  if Result >= 0 then
  begin
    SetActiveIndex(Result);
    Exit;
  end;

  { 【段階5】必ず新しいタブで開く（起動直後の無題も使わない） }
  Result := AddDocument('');
  try
    LoadFromFile(AFileName);
  except
    CloseDocument(Result, True);
    raise;
  end;
end;

function TCMMonacoView.CloseDocument(AIndex: Integer; Force: Boolean): Boolean;
var
  Doc, Keep: TCMDocument;
  CanClose, WasActive: Boolean;
begin
  Doc := DocAt(AIndex);
  if Doc = nil then Exit(False);

  if (not Force) and Doc.Modified and Assigned(FOnQueryClose) then
  begin
    CanClose := True;
    FOnQueryClose(Self, AIndex, CanClose);
    if not CanClose then Exit(False);
  end;

  WasActive := AIndex = FActive;
  Keep := ActiveDoc;
  if FDocs.Count = 1 then
  begin
    { 【2.9】最後の1枚を閉じるときは、先に空の無題を作って表示する（タブを0枚にしない） }
    Keep := NewDocument('');
    SendCmd('doc.activate' + SEP + IntToStr(Keep.Id));
    WasActive := True;
  end
  else if WasActive then
  begin
    if AIndex < FDocs.Count - 1 then
      Keep := DocAt(AIndex + 1)
    else
      Keep := DocAt(AIndex - 1);
    SendCmd('doc.activate' + SEP + IntToStr(Keep.Id));
  end;

  SendCmd('doc.close' + SEP + IntToStr(Doc.Id));
  FDocs.Delete(AIndex);
  Doc.Free;
  FActive := FDocs.IndexOf(Keep);

  if WasActive then
  begin
    FSelectedText := '';
    FSelStart := 0; FSelLength := 0; FCanUndo := False;   { 【段階6】 }
    FCanRedo := False;                                    { 【2.17】 }
    FCursorLine := 1;
    FCursorCol := 1;
    FCursorLineText := ''; Inc(FCursorLineSeq);   { 【2.13】 }
  end;
  DoListChange;
  if WasActive and Assigned(FOnActiveChange) then FOnActiveChange(Self);
  Result := True;
end;

function TCMMonacoView.CloseAll(Force: Boolean): Boolean;
var
  I: Integer;
begin
  { 【2.9】後ろから閉じる。最後の1枚を閉じると空の無題ができ、それで終わる（タブは常に1枚以上） }
  Result := True;
  for I := FDocs.Count - 1 downto 0 do
    if not CloseDocument(I, Force) then Exit(False);
end;

procedure TCMMonacoView.MoveDocument(AFromIndex, AToIndex: Integer);
var
  Keep: TCMDocument;
begin
  if (DocAt(AFromIndex) = nil) or (DocAt(AToIndex) = nil) or (AFromIndex = AToIndex) then Exit;
  Keep := ActiveDoc;
  FDocs.Move(AFromIndex, AToIndex);
  FActive := FDocs.IndexOf(Keep);
  DoListChange;
end;

procedure TCMMonacoView.SaveDocument(AIndex: Integer);
var
  Doc: TCMDocument;
begin
  Doc := DocAt(AIndex);
  if Doc = nil then Exit;
  if Doc.FileName = '' then SetActiveIndex(AIndex);   { ファイル名入力の対象が分かるようにする }
  DoSaveDoc(Doc, '');
end;

procedure TCMMonacoView.SaveAll;
var
  I: Integer;
begin
  for I := 0 to FDocs.Count - 1 do
    if TCMDocument(FDocs[I]).Modified then SaveDocument(I);
end;

{ ---------- メッセージ処理 ---------- }

procedure TCMMonacoView.HandleMessage(const Msg: string);
var
  Cmd, Arg: string;
  P, L, C, I, Id, Code: Integer;
  D: Double;
  Doc: TCMDocument;
begin
  P := Pos(SEP, Msg);
  if P = 0 then
  begin
    Cmd := Msg;
    Arg := '';
  end
  else
  begin
    Cmd := System.Copy(Msg, 1, P - 1);
    Arg := System.Copy(Msg, P + 1, MaxInt);
  end;

  if Cmd = 'ready' then
  begin
    FReady := True;
    FOverwrite := False;
    ApplyAllOptions;
    for I := 0 to FDocs.Count - 1 do
    begin
      Doc := TCMDocument(FDocs[I]);
      SendCmd('doc.new' + SEP + IntToStr(Doc.Id) + SEP + Doc.Language + SEP + Doc.Text);
      if Doc.Modified then SendCmd('doc.dirty' + SEP + IntToStr(Doc.Id));   { 準備前に Text を代入した場合など }
    end;
    Doc := ActiveDoc;
    if Doc <> nil then SendCmd('doc.activate' + SEP + IntToStr(Doc.Id));
    if Assigned(FOnReady) then FOnReady(Self);
  end
  else if Cmd = 'change' then
  begin
    Id := StrToIntDef(NextPart(Arg), 0);
    Doc := DocById(Id);
    if Doc <> nil then
    begin
      Doc.Text := Arg;
      if (Doc = ActiveDoc) and Assigned(FOnChange) then FOnChange(Self);
    end;
  end
  else if Cmd = 'modified' then
  begin
    Id := StrToIntDef(NextPart(Arg), 0);
    SetDocModified(DocById(Id), Arg = '1');
  end
  else if Cmd = 'cursorline' then      { 【2.13】カーソル行の文字列（cursor の直前に届く。イベントは呼ばない） }
  begin
    FCursorLineText := Arg;
    Inc(FCursorLineSeq);
  end
  else if Cmd = 'cursor' then
  begin
    L := StrToIntDef(NextPart(Arg), 1);
    C := StrToIntDef(NextPart(Arg), 1);
    FSelStart := StrToIntDef(NextPart(Arg), 0);    { 【段階6】 }
    FSelLength := StrToIntDef(NextPart(Arg), 0);   { 【段階6】 }
    FSelectedText := Arg;
    FCursorLine := L;
    FCursorCol := C;
    if Assigned(FOnCursorChange) then FOnCursorChange(Self, L, C);
  end
  else if Cmd = 'textsync' then        { 【2.10】doc.settextifdiff で、Monaco 側の本文が違っていたので置き換えた }
  begin
    Id := StrToIntDef(NextPart(Arg), 0);
    Doc := DocById(Id);
    if Doc <> nil then
    begin
      Doc.Text := Arg;
      SetDocModified(Doc, True);
    end;
  end
  else if Cmd = 'canundo' then         { 【段階6】【2.17】引数は Undo できるか(0/1) SEP Redo できるか(0/1) }
  begin
    FCanUndo := System.Copy(Arg, 1, 1) = '1';
    FCanRedo := (Pos(SEP, Arg) > 0) and (System.Copy(Arg, Pos(SEP, Arg) + 1, 1) = '1');   { 2 つ目がなければ False }
  end
  else if Cmd = 'mode' then
  begin
    FOverwrite := Arg = '1';
    if Assigned(FOnModeChange) then FOnModeChange(Self, FOverwrite);
  end
  else if Cmd = 'save' then
  begin
    Id := StrToIntDef(NextPart(Arg), 0);
    Doc := DocById(Id);
    if Doc <> nil then
    begin
      Doc.Text := Arg;
      try
        DoSaveDoc(Doc, '');
      except
        on E: Exception do DoError(E.Message);
      end;
    end;
  end
  else if Cmd = 'findreq' then
  begin
    if Assigned(FOnFindRequest) then FOnFindRequest(Self, Arg);
  end
  else if Cmd = 'findnext' then
    FindNext
  else if Cmd = 'findprev' then
    FindPrev
  else if Cmd = 'finddone' then
  begin
    if Assigned(FOnFindDone) then FOnFindDone(Self, Arg = '1');
  end
  else if Cmd = 'replacealldone' then
  begin
    if Assigned(FOnReplaceAllDone) then FOnReplaceAllDone(Self, StrToIntDef(Arg, 0));
  end
  else if Cmd = 'togglemax' then
  begin
    if Assigned(FOnToggleMaximize) then FOnToggleMaximize(Self);
  end
  else if Cmd = 'gotfocus' then
  begin
    if Assigned(FOnGotFocus) then FOnGotFocus(Self);
  end
  else if Cmd = 'togglepreview' then
  begin
    if Assigned(FOnTogglePreview) then FOnTogglePreview(Self);
  end
  else if Cmd = 'oschange' then
  begin
    if Assigned(FOnOsThemeChange) then FOnOsThemeChange(Self, Arg = '1');
  end
  else if Cmd = 'linenumbers' then
  begin
    FLineNumbers := Arg = '1';
    if Assigned(FOnLineNumbersChange) then FOnLineNumbersChange(Self);
  end
  else if Cmd = 'fontsize' then
  begin
    FFontSize := StrToIntDef(Arg, FFontSize);
    if Assigned(FOnFontSizeChange) then FOnFontSizeChange(Self);
  end
  else if Cmd = 'topline' then
  begin
    Val(Arg, D, Code);
    if Code <> 0 then D := 1;
    FTopLine := D;
    if Assigned(FOnScrollChange) then FOnScrollChange(Self, D);
  end
  else if Cmd = 'contextmenu' then
  begin
    { WebView2 のイベント内で直接メニューを出すと即閉じることがあるため、処理完了後に表示する }
    FMenuPos := Mouse.CursorPos;
    Application.RemoveAsyncCalls(Self);
    Application.QueueAsyncCall(@AsyncContextMenu, 0);
  end
  else if Cmd = 'error' then
    DoError(Arg);
end;

procedure TCMMonacoView.AddHistory(AList: TStringList; const S: string);
var
  I: Integer;
begin
  if S = '' then Exit;
  I := AList.IndexOf(S);
  if I >= 0 then AList.Delete(I);
  AList.Insert(0, S);
  while AList.Count > MAX_HISTORY do AList.Delete(AList.Count - 1);
end;

procedure TCMMonacoView.SetFocus;
begin
  if FReady then
  begin
    { 【2.12】① 外枠（このアプリのウィンドウ）にフォーカスを移す
              ② WebView2 の正式な命令（MoveFocus）で、中へ移してもらう（Edge 自身が移すので、IME もつながる）
              ③ Monaco にフォーカスを頼む。
      2.11 までは、WebView 内部のウィンドウ（別のプロセス）へ Windows.SetFocus で直接移していたが、
      別の WebView2 にフォーカスがある状態から移すと、IME の窓が画面の左上に出て入力できなかった }
    if FWindowParent.CanFocus then FWindowParent.SetFocus;
    FBrowser.SetFocus;   { WebView4Delphi の SetFocus ＝ Controller.MoveFocus(COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC) }
    SendCmd('focus');
  end
  else
    inherited SetFocus;
end;

{ ---------- プロパティ（アクティブ文書） ---------- }

function TCMMonacoView.GetText: string;
var
  Doc: TCMDocument;
begin
  Doc := ActiveDoc;
  if Doc = nil then Result := '' else Result := Doc.Text;
end;

function TCMMonacoView.GetFileName: string;
var
  Doc: TCMDocument;
begin
  Doc := ActiveDoc;
  if Doc = nil then Result := '' else Result := Doc.FileName;
end;

function TCMMonacoView.GetEncoding: TCMEncoding;
var
  Doc: TCMDocument;
begin
  Doc := ActiveDoc;
  if Doc = nil then Result := ceUTF8 else Result := Doc.Encoding;
end;

function TCMMonacoView.GetModified: Boolean;
var
  Doc: TCMDocument;
begin
  Doc := ActiveDoc;
  Result := (Doc <> nil) and Doc.Modified;
end;

function TCMMonacoView.GetLanguage: string;
var
  Doc: TCMDocument;
begin
  Doc := ActiveDoc;
  if Doc = nil then Result := FDefaultLanguage else Result := Doc.Language;
end;

function TCMMonacoView.GetLines: TStrings;
begin
  FLines.Text := GetText;
  Result := FLines;
end;

procedure TCMMonacoView.SetLines(AValue: TStrings);
begin
  SetText(AValue.Text);
end;

procedure TCMMonacoView.SetText(const AValue: string);
var
  Doc: TCMDocument;
begin
  Doc := EnsureActiveDoc;
  Doc.Text := AValue;
  SendCmd('doc.reset' + SEP + IntToStr(Doc.Id) + SEP + AValue);
  SetDocModified(Doc, False);
end;

procedure TCMMonacoView.SetFileName(const AValue: string);
var
  Doc: TCMDocument;
begin
  Doc := EnsureActiveDoc;
  Doc.FileName := AValue;
  DoDocChange(Doc);
end;

procedure TCMMonacoView.SetEncoding(AValue: TCMEncoding);
begin
  EnsureActiveDoc.Encoding := AValue;
end;

procedure TCMMonacoView.SetModified(AValue: Boolean);
var
  Doc: TCMDocument;
begin
  Doc := ActiveDoc;
  if Doc = nil then Exit;
  if not AValue then SendCmd('marksaved' + SEP + IntToStr(Doc.Id));
  SetDocModified(Doc, AValue);
end;

procedure TCMMonacoView.SetLanguage(const AValue: string);
var
  Doc: TCMDocument;
begin
  Doc := EnsureActiveDoc;
  if AValue = '' then Doc.Language := FDefaultLanguage else Doc.Language := AValue;
  SendCmd('doc.lang' + SEP + IntToStr(Doc.Id) + SEP + Doc.Language);
  DoDocChange(Doc);
end;

procedure TCMMonacoView.SetWordWrap(AValue: Boolean);
begin
  FWordWrap := AValue;
  SendCmd('opt' + SEP + 'wordwrap' + SEP + B2S(AValue));
end;

procedure TCMMonacoView.SetFolding(AValue: Boolean);
begin
  FFolding := AValue;
  SendCmd('opt' + SEP + 'folding' + SEP + B2S(AValue));
end;

procedure TCMMonacoView.SetMatchBrackets(AValue: Boolean);
begin
  FMatchBrackets := AValue;
  SendCmd('opt' + SEP + 'matchbrackets' + SEP + B2S(AValue));
end;

procedure TCMMonacoView.SetOccurrencesHighlight(AValue: Boolean);
begin
  FOccurrencesHighlight := AValue;
  SendCmd('opt' + SEP + 'occurrences' + SEP + B2S(AValue));
end;

procedure TCMMonacoView.SetMinimap(AValue: Boolean);
begin
  FMinimap := AValue;
  SendCmd('opt' + SEP + 'minimap' + SEP + B2S(AValue));
end;

procedure TCMMonacoView.SetLineNumbers(AValue: Boolean);
begin
  FLineNumbers := AValue;
  SendCmd('opt' + SEP + 'linenumbers' + SEP + B2S(AValue));
end;

procedure TCMMonacoView.SetFontSize(AValue: Integer);
begin
  if AValue < 6 then AValue := 6;
  if AValue > 72 then AValue := 72;
  FFontSize := AValue;
  SendCmd('opt' + SEP + 'fontsize' + SEP + IntToStr(AValue));
end;

procedure TCMMonacoView.SetTheme(const AValue: string);
begin
  if (AValue = 'vs') or (AValue = 'vs-dark') then
    FTheme := AValue
  else
    FTheme := 'auto';
  SendCmd('opt' + SEP + 'theme' + SEP + FTheme);
end;

procedure TCMMonacoView.SetReadOnly(AValue: Boolean);
begin
  FReadOnly := AValue;
  SendCmd('opt' + SEP + 'readonly' + SEP + B2S(AValue));
end;

procedure TCMMonacoView.SetHitColorLight(const AValue: string);
begin
  FHitColorLight := AValue;
  SendColors;
end;

procedure TCMMonacoView.SetHitColorDark(const AValue: string);
begin
  FHitColorDark := AValue;
  SendColors;
end;

procedure TCMMonacoView.SetCursorLineColorLight(const AValue: string);
begin
  FCursorLineColorLight := AValue;
  SendColors;
end;

procedure TCMMonacoView.SetCursorLineColorDark(const AValue: string);
begin
  FCursorLineColorDark := AValue;
  SendColors;
end;

procedure TCMMonacoView.SetSelectionColorLight(const AValue: string);   { 【2.13】 }
begin
  FSelectionColorLight := AValue;
  SendColors;
end;

procedure TCMMonacoView.SetSelectionColorDark(const AValue: string);    { 【2.13】 }
begin
  FSelectionColorDark := AValue;
  SendColors;
end;

function TCMMonacoView.GetSearchHistory: TStrings;
begin
  Result := FSearchHistory;
end;

function TCMMonacoView.GetReplaceHistory: TStrings;
begin
  Result := FReplaceHistory;
end;

{ ---------- ファイル入出力（アクティブ文書） ---------- }

procedure TCMMonacoView.LoadFromFile(const AFileName: string);
var
  Enc: TCMEncoding;
  S: string;
begin
  S := LoadTextFile(AFileName, Enc);          { 読めなければ、ここで例外（何も変わらない） }
  LoadIntoDoc(EnsureActiveDoc, S, AFileName, Enc);
end;

procedure TCMMonacoView.LoadIntoDoc(ADoc: TCMDocument; const S, AFileName: string; AEnc: TCMEncoding);
begin
  ADoc.Text := S;
  ADoc.Encoding := AEnc;
  ADoc.FileName := AFileName;
  if FAutoLanguage then
  begin
    ADoc.Language := LanguageForFile(AFileName, FDefaultLanguage);
    SendCmd('doc.lang' + SEP + IntToStr(ADoc.Id) + SEP + ADoc.Language);
  end;
  SendCmd('doc.reset' + SEP + IntToStr(ADoc.Id) + SEP + S);
  SetDocModified(ADoc, False);
  DoDocChange(ADoc);
end;

{ ---------- 【段階2】番号を指定した文書の操作（表示は切り替えない） ---------- }

procedure TCMMonacoView.LoadDocument(AIndex: Integer; const AFileName: string);
var
  Doc: TCMDocument;
  Enc: TCMEncoding;
  S: string;
begin
  Doc := DocAt(AIndex);
  if Doc = nil then Exit;
  S := LoadTextFile(AFileName, Enc);          { 読めなければ、ここで例外（何も変わらない） }
  LoadIntoDoc(Doc, S, AFileName, Enc);
end;

procedure TCMMonacoView.ClearDocument(AIndex: Integer);
var
  Doc: TCMDocument;
begin
  Doc := DocAt(AIndex);
  if Doc = nil then Exit;
  Doc.Text := '';
  Doc.FileName := '';
  Doc.Encoding := ceUTF8;
  Doc.Language := FDefaultLanguage;
  SendCmd('doc.lang' + SEP + IntToStr(Doc.Id) + SEP + Doc.Language);
  SendCmd('doc.reset' + SEP + IntToStr(Doc.Id) + SEP);
  SetDocModified(Doc, False);
  DoDocChange(Doc);
end;

procedure TCMMonacoView.SaveDocumentTo(AIndex: Integer; const AFileName: string);
var
  Doc: TCMDocument;
begin
  Doc := DocAt(AIndex);
  if Doc <> nil then DoSaveDoc(Doc, AFileName);
end;

function TCMMonacoView.GetDocumentEncoding(AIndex: Integer): TCMEncoding;
var
  Doc: TCMDocument;
begin
  Doc := DocAt(AIndex);
  if Doc = nil then Result := ceUTF8 else Result := Doc.Encoding;
end;

procedure TCMMonacoView.SetDocumentEncoding(AIndex: Integer; AValue: TCMEncoding);
var
  Doc: TCMDocument;
begin
  Doc := DocAt(AIndex);
  if Doc <> nil then Doc.Encoding := AValue;
end;

function TCMMonacoView.GetDocumentText(AIndex: Integer): string;
var
  Doc: TCMDocument;
begin
  Doc := DocAt(AIndex);
  if Doc = nil then Result := '' else Result := Doc.Text;
end;

procedure TCMMonacoView.SetDocumentText(AIndex: Integer; const AValue: string);
var
  Doc: TCMDocument;
begin
  Doc := DocAt(AIndex);
  if Doc = nil then Exit;
  if Doc.Text = AValue then
  begin
    { 【2.10】写しと同じなら、何もしない（' *' を付けない）。
      写しは入力直後に古いことがあるため、準備後は Monaco にも比べさせ、違うときだけ置き換えさせる（textsync で返る） }
    SendCmd('doc.settextifdiff' + SEP + IntToStr(Doc.Id) + SEP + AValue);
    Exit;
  end;
  Doc.Text := AValue;
  SendCmd('doc.reset' + SEP + IntToStr(Doc.Id) + SEP + AValue);
  SendCmd('doc.dirty' + SEP + IntToStr(Doc.Id));   { Undo で戻しても、保存するまで変更ありのまま }
  SetDocModified(Doc, True);
end;

function TCMMonacoView.GetDocumentLanguage(AIndex: Integer): string;
var
  Doc: TCMDocument;
begin
  Doc := DocAt(AIndex);
  if Doc = nil then Result := FDefaultLanguage else Result := Doc.Language;
end;

procedure TCMMonacoView.SetDocumentLanguage(AIndex: Integer; const AValue: string);
var
  Doc: TCMDocument;
begin
  Doc := DocAt(AIndex);
  if Doc = nil then Exit;
  if AValue = '' then Doc.Language := FDefaultLanguage else Doc.Language := AValue;
  SendCmd('doc.lang' + SEP + IntToStr(Doc.Id) + SEP + Doc.Language);
  DoDocChange(Doc);
end;

procedure TCMMonacoView.SaveToFile(const AFileName: string);
begin
  if ActiveDoc <> nil then DoSaveDoc(ActiveDoc, AFileName);
end;

procedure TCMMonacoView.DoSaveDoc(ADoc: TCMDocument; const AFileName: string);
var
  N, L: string;
  Cancel: Boolean;
  B: TBytes;
  FS: TFileStream;
  NameChanged: Boolean;
begin
  N := AFileName;
  if N = '' then N := ADoc.FileName;
  if N = '' then
  begin
    Cancel := True;
    if Assigned(FOnNeedFileName) then
    begin
      Cancel := False;
      FOnNeedFileName(Self, N, Cancel);
    end;
    if Cancel or (N = '') then Exit;
  end;

  B := EncodeText(ADoc.Text, ADoc.Encoding);
  FS := TFileStream.Create(N, fmCreate);
  try
    if Length(B) > 0 then FS.WriteBuffer(B[0], Length(B));
  finally
    FS.Free;
  end;

  NameChanged := N <> ADoc.FileName;
  ADoc.FileName := N;
  if NameChanged and FAutoLanguage then
  begin
    L := LanguageForFile(N, ADoc.Language);
    if L <> ADoc.Language then
    begin
      ADoc.Language := L;
      SendCmd('doc.lang' + SEP + IntToStr(ADoc.Id) + SEP + L);
    end;
  end;
  SendCmd('marksaved' + SEP + IntToStr(ADoc.Id));
  SetDocModified(ADoc, False);
  if NameChanged then DoDocChange(ADoc);
  if Assigned(FOnSave) then FOnSave(Self, N);
end;

{ ---------- カーソル・選択 ---------- }

procedure TCMMonacoView.SetCursorPos(ALine, AColumn: Integer);
begin
  SendCmd('setcursor' + SEP + IntToStr(ALine) + SEP + IntToStr(AColumn));
end;

procedure TCMMonacoView.GetCursorPos(out ALine, AColumn: Integer);
begin
  ALine := FCursorLine;
  AColumn := FCursorCol;
end;

procedure TCMMonacoView.SetSelection(AStartLine, AStartCol, AEndLine, AEndCol: Integer);
begin
  SendCmd('setsel' + SEP + IntToStr(AStartLine) + SEP + IntToStr(AStartCol) + SEP +
    IntToStr(AEndLine) + SEP + IntToStr(AEndCol));
end;

function TCMMonacoView.GetSelectedText: string;
begin
  Result := FSelectedText;
end;

procedure TCMMonacoView.ToggleOverwrite;
begin
  SendCmd('toggleow');
end;

procedure TCMMonacoView.ScrollToLine(ALine: Double);
var
  S: string;
begin
  Str(ALine:0:3, S);
  SendCmd('scrollto' + SEP + S);
end;

{ ---------- 編集 ---------- }

procedure TCMMonacoView.Undo;
begin
  SendCmd('undo');
end;

procedure TCMMonacoView.Redo;
begin
  SendCmd('redo');
end;

procedure TCMMonacoView.Copy;
begin
  if FSelectedText <> '' then Clipboard.AsText := FSelectedText;
end;

procedure TCMMonacoView.Cut;
begin
  if FReadOnly or (FSelectedText = '') then Exit;
  Clipboard.AsText := FSelectedText;
  SendCmd('delsel');
end;

procedure TCMMonacoView.Paste;
begin
  if FReadOnly then Exit;
  if Clipboard.AsText <> '' then
    SendCmd('paste' + SEP + Clipboard.AsText);
end;

procedure TCMMonacoView.SelectAll;
begin
  SendCmd('selectall');
end;

{ ---------- 検索・置換 ---------- }

procedure TCMMonacoView.Find(const S: string; AOptions: TCMFindOptions; AForward: Boolean);
begin
  FSearchText := S;
  FSearchOptions := AOptions;
  AddHistory(FSearchHistory, S);
  SendCmd('find' + SEP + S + SEP + B2S(foMatchCase in AOptions) + SEP +
    B2S(foWholeWord in AOptions) + SEP + B2S(foLoop in AOptions) + SEP + B2S(AForward));
end;

procedure TCMMonacoView.FindNext;
begin
  if FSearchText = '' then
  begin
    if Assigned(FOnFindRequest) then FOnFindRequest(Self, FSelectedText);
  end
  else
    Find(FSearchText, FSearchOptions, True);
end;

procedure TCMMonacoView.FindPrev;
begin
  if FSearchText = '' then
  begin
    if Assigned(FOnFindRequest) then FOnFindRequest(Self, FSelectedText);
  end
  else
    Find(FSearchText, FSearchOptions, False);
end;

procedure TCMMonacoView.Replace(const S, R: string; AOptions: TCMFindOptions);
begin
  if FReadOnly then Exit;
  FSearchText := S;
  FReplaceText := R;
  FSearchOptions := AOptions;
  AddHistory(FSearchHistory, S);
  AddHistory(FReplaceHistory, R);
  SendCmd('replace' + SEP + S + SEP + R + SEP + B2S(foMatchCase in AOptions) + SEP +
    B2S(foWholeWord in AOptions) + SEP + B2S(foLoop in AOptions));
end;

procedure TCMMonacoView.ReplaceAll(const S, R: string; AOptions: TCMFindOptions);
begin
  if FReadOnly then Exit;
  FSearchText := S;
  FReplaceText := R;
  FSearchOptions := AOptions;
  AddHistory(FSearchHistory, S);
  AddHistory(FReplaceHistory, R);
  SendCmd('replaceall' + SEP + S + SEP + R + SEP + B2S(foMatchCase in AOptions) + SEP +
    B2S(foWholeWord in AOptions));
end;

procedure TCMMonacoView.OpenDevTools;
begin
  FBrowser.DevToolsEnabled := True;
  FBrowser.OpenDevToolsWindow;
end;

{ ---------- ポップアップメニュー ---------- }

function TCMMonacoView.AddMenuItem(const ACaption: string; ACmd: TCMMenuCmd; AVis: Integer;
  ANeedEdit: Boolean): TCMMenuItem;
begin
  Result := TCMMenuItem.Create(FPopup);
  Result.Caption := ACaption;
  Result.Cmd := ACmd;
  Result.Vis := AVis;
  Result.NeedEdit := ANeedEdit;
  if ACaption <> '-' then Result.OnClick := @MenuItemClick;
  FPopup.Items.Add(Result);
end;

procedure TCMMonacoView.BuildPopupMenu;
begin
  FPopup := TPopupMenu.Create(Self);
  FPopup.OnPopup := @PopupMenuPopup;

  AddMenuItem('切り抜き', mcCut, 1, True);
  AddMenuItem('コピー', mcCopy, 1, False);
  AddMenuItem('貼り付け', mcPaste, 2, True);
  AddMenuItem('-', mcCut, 1, False);
  AddMenuItem('-', mcCut, 3, False);
  AddMenuItem('すべて選択', mcSelectAll, 3, False);
  AddMenuItem('元に戻す', mcUndo, 3, True);
  AddMenuItem('やり直し', mcRedo, 3, True);
  AddMenuItem('引用付きコピー', mcQuoteCopy, 1, False);
  AddMenuItem('追加切り抜き', mcAppendCut, 1, True);
  AddMenuItem('追加コピー', mcAppendCopy, 1, False);
  AddMenuItem('-', mcCut, 1, False);
  AddMenuItem('削除', mcDelete, 1, True);
  AddMenuItem('-', mcCut, 1, False);
  AddMenuItem('TO UPPER CASE', mcUpper, 1, True);
  AddMenuItem('to lower case', mcLower, 1, True);
  AddMenuItem('-', mcCut, 1, False);
  AddMenuItem('ﾊﾝｶｸに変換', mcHankaku, 1, True);
  AddMenuItem('全角ひらがなに変換', mcHiragana, 1, True);
  AddMenuItem('全角カタカナに変換', mcKatakana, 1, True);
  AddMenuItem('-', mcCut, 1, False);
  AddMenuItem('TAB -> 空白', mcDetab, 1, True);
  AddMenuItem('空白 -> TAB', mcEntab, 1, True);
  AddMenuItem('-', mcCut, 1, False);
  AddMenuItem('インデント', mcIndent, 1, True);
  AddMenuItem('逆インデント', mcOutdent, 1, True);
end;

procedure TCMMonacoView.PopupMenuPopup(Sender: TObject);
var
  I: Integer;
  HasSel: Boolean;
  M: TMenuItem;
begin
  HasSel := FSelectedText <> '';
  for I := 0 to FPopup.Items.Count - 1 do
  begin
    M := FPopup.Items[I];
    if M is TCMMenuItem then
      with TCMMenuItem(M) do
      begin
        case Vis of
          1: Visible := HasSel;
          2: Visible := True;
          3: Visible := not HasSel;
        end;
        if NeedEdit then Enabled := not FReadOnly;
      end;
  end;
  if Assigned(FOnPopup) then FOnPopup(Self);
end;

procedure TCMMonacoView.ShowContextMenu;
begin
  if (ActiveDoc = nil) or (PopupMenu = nil) then Exit;
  PopupMenu.PopUp(FMenuPos.X, FMenuPos.Y);
end;

procedure TCMMonacoView.CollectDroppedFiles(AArgs: TCoreWebView2WebMessageReceivedEventArgs);
var
  Intf: ICoreWebView2ObjectCollectionView;
  Coll: TCoreWebView2ObjectCollectionView;
  Unk: IUnknown;
  FI: ICoreWebView2File;
  F: TCoreWebView2File;
  I: Integer;
begin
  Intf := AArgs.AdditionalObjects;
  if Intf = nil then Exit;
  Coll := TCoreWebView2ObjectCollectionView.Create(Intf);
  try
    for I := 0 to Integer(Coll.Count) - 1 do
    begin
      Unk := Coll.Items[I];
      if (Unk <> nil) and Supports(Unk, ICoreWebView2File, FI) then
      begin
        F := TCoreWebView2File.Create(FI);
        try
          FDropFiles.Add(FromWV(F.Path));
        finally
          F.Free;
        end;
      end;
    end;
  finally
    Coll.Free;
  end;
  { COM イベントの外で開く }
  if FDropFiles.Count > 0 then Application.QueueAsyncCall(@AsyncDropFiles, 0);
end;

procedure TCMMonacoView.AsyncDropFiles(Data: PtrInt);
var
  Files: TStringList;
  Handled: Boolean;
  I: Integer;
begin
  if FDropFiles.Count = 0 then Exit;
  Files := TStringList.Create;
  try
    Files.Assign(FDropFiles);
    FDropFiles.Clear;
    Handled := False;
    if Assigned(FOnFileDrop) then FOnFileDrop(Self, Files, Handled);
    if Handled or not FOpenDroppedFiles then Exit;
    for I := 0 to Files.Count - 1 do
      if FileExists(Files[I]) then
        try
          OpenFile(Files[I]);
        except
          on E: Exception do DoError(Files[I] + ': ' + E.Message);
        end;
  finally
    Files.Free;
  end;
end;

procedure TCMMonacoView.AsyncContextMenu(Data: PtrInt);
begin
  ShowContextMenu;
end;

procedure TCMMonacoView.MenuItemClick(Sender: TObject);
var
  Body: string;
  EndsLF: Boolean;
begin
  case TCMMenuItem(Sender).Cmd of
    mcCut: Cut;
    mcCopy: Copy;
    mcPaste: Paste;
    mcSelectAll: SelectAll;
    mcUndo: Undo;
    mcRedo: Redo;
    mcQuoteCopy:
      if FSelectedText <> '' then
      begin
        Body := FSelectedText;
        EndsLF := (Body <> '') and (Body[Length(Body)] = #10);
        if EndsLF then Delete(Body, Length(Body), 1);
        Body := FQuotePrefix + StringReplace(Body, #10, #10 + FQuotePrefix, [rfReplaceAll]);
        if EndsLF then Body := Body + #10;
        Clipboard.AsText := Body;
      end;
    mcAppendCopy:
      if FSelectedText <> '' then Clipboard.AsText := Clipboard.AsText + FSelectedText;
    mcAppendCut:
      if (FSelectedText <> '') and not FReadOnly then
      begin
        Clipboard.AsText := Clipboard.AsText + FSelectedText;
        SendCmd('delsel');
      end;
    mcDelete:
      if (FSelectedText <> '') and not FReadOnly then SendCmd('delsel');
    mcUpper: if FSelectedText <> '' then ReplaceSelection(UTF8UpperCase(FSelectedText));
    mcLower: if FSelectedText <> '' then ReplaceSelection(UTF8LowerCase(FSelectedText));
    mcHankaku: if FSelectedText <> '' then ReplaceSelection(CMToHankaku(FSelectedText));
    mcHiragana: if FSelectedText <> '' then ReplaceSelection(CMToZenkakuHiragana(FSelectedText));
    mcKatakana: if FSelectedText <> '' then ReplaceSelection(CMToZenkakuKatakana(FSelectedText));
    mcDetab: if not FReadOnly then SendCmd('xform' + SEP + 'detab');
    mcEntab: if not FReadOnly then SendCmd('xform' + SEP + 'entab');
    mcIndent: if not FReadOnly then SendCmd('xform' + SEP + 'indent');
    mcOutdent: if not FReadOnly then SendCmd('xform' + SEP + 'outdent');
  end;
end;

procedure TCMMonacoView.ReplaceSelection(const S: string);
begin
  if FReadOnly or (ActiveDoc = nil) then Exit;
  SendCmd('replacesel' + SEP + S);
end;

procedure TCMMonacoView.SetSelText(const S: string);
begin
  if FReadOnly or (ActiveDoc = nil) then Exit;
  SendCmd('seltext' + SEP + S);
end;

procedure TCMMonacoView.DeleteToEnd;
begin
  if FReadOnly or (ActiveDoc = nil) then Exit;
  SendCmd('delto' + SEP + 'end');
end;

procedure TCMMonacoView.DeleteToStart;
begin
  if FReadOnly or (ActiveDoc = nil) then Exit;
  SendCmd('delto' + SEP + 'start');
end;

{ 【2.16】カーソル行を複製する。editor.html の Shift+F10 と同じ処理（dupLine）を呼ぶ。
  読み取り専用・文書なしのときは何もしない }
procedure TCMMonacoView.DuplicateLine;
begin
  if FReadOnly or (ActiveDoc = nil) then Exit;
  SendCmd('dupline');
end;

procedure TCMMonacoView.SetTabSize(AValue: Integer);
begin
  if AValue < 1 then AValue := 1;
  if AValue > 16 then AValue := 16;
  FTabSize := AValue;
  SendCmd('opt' + SEP + 'tabsize' + SEP + IntToStr(AValue));
end;

end.
