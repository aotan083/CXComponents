{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ TCsEditor - TCSynEdit をタブで複数持つエディタ部品（TCsEditor_Design.md）
  環境: Lazarus 5.0 以降 / FPC 3.2.2 / Windows 11 x64 / ATFlatControls（Lazarus 4.8 はコンパイルが通るだけ）

  使い方（名前・動き・既定値）は TCMonacoEditor と同じ。編集の部分を Monaco（WebView2）から TCSynEdit に替えた。
  ・フォームに貼るだけで使える。設定はオブジェクトインスペクタ。
  ・プレビューは別の部品 TCPreview（uCPreview）。Preview プロパティで選び、ShowPreview で表示する。
  ・エディタを並べるときは、TCsEditor を複数貼り、TSplitter で並べる。タブは、同じフォームの別の TCsEditor へ
    ドラッグで移せる。同じファイルは同じフォームの中で 1 か所だけで開く。
  ・検索・置換ダイアログ（TCsFindDialog）・標準アクション 25 個・ミニマップ（TCsMinimap）もこのユニットに入れる。 }
unit uCsEditor;

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils, Controls, Forms, ExtCtrls, StdCtrls, Graphics, Dialogs, Menus,
  LCLType, LCLIntf, LMessages, ActnList, Clipbrd, Registry, ShellApi,
  ATTabs, SynEdit, SynEditTypes, SynEditKeyCmds, SynEditMouseCmds, SynEditMarkupWordGroup,
  SynEditMarkupHighAll, SynEditWrappedView, csynedit, ucmmonacoview, CMonacoTabs, uCmonacos, uCPreview;

type
  { アプリが uCsEditor だけを uses すれば済むように、使い回す型と値を出し直す（2.2。uCmonacos と同じやり方） }
  TCMEncoding = ucmmonacoview.TCMEncoding;
  TCMFindOption = ucmmonacoview.TCMFindOption;
  TCMFindOptions = ucmmonacoview.TCMFindOptions;
  TCMTheme = uCmonacos.TCMTheme;
  TCMSelectionColorStyle = uCmonacos.TCMSelectionColorStyle;

const
  ceUTF8 = ucmmonacoview.ceUTF8;
  ceUTF8BOM = ucmmonacoview.ceUTF8BOM;
  ceUTF16LE = ucmmonacoview.ceUTF16LE;
  ceUTF16BE = ucmmonacoview.ceUTF16BE;
  ceCP932 = ucmmonacoview.ceCP932;
  foMatchCase = ucmmonacoview.foMatchCase;
  foWholeWord = ucmmonacoview.foWholeWord;
  foLoop = ucmmonacoview.foLoop;
  ctAuto = uCmonacos.ctAuto;
  ctLight = uCmonacos.ctLight;
  ctDark = uCmonacos.ctDark;
  scStandard = uCmonacos.scStandard;
  scBlue = uCmonacos.scBlue;
  scAmber = uCmonacos.scAmber;
  scPurple = uCmonacos.scPurple;
  scCustom = uCmonacos.scCustom;

type
  TCsEditor = class;
  TCsPage = class;
  TCsFindDialog = class;

  { TCsSynEdit : 1 つのタブの中の部品（5章）。TCSynEdit を継承し、キー・ホイール・ドロップ・色・フォーカスを
    TCsEditor の動きにする（TCSynEdit 本体は変えない）。アプリは作らない（登録しない） }
  TCsSynEdit = class(TCSynEdit)
  private
    FEditor: TCsEditor;               { 今のエディタ（タブを別の TCsEditor へ移すと変わる。4.12） }
    FPage: TCsPage;                   { このタブのページ }
    FWrap: TLazSynEditLineWrapPlugin; { 折り返し。WordWrap = False なら nil }
    FDarkBars: Integer;               { スクロールバーに当てた見た目（-1=まだ 0=ライト 1=ダーク。4.7） }
  protected
    procedure CreateWnd; override;                                                      { 4.7 のスクロールバー }
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;                     { 6章 }
    function DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint): Boolean; override; { 5.4 }
    function DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean; override;
    procedure DoDropFiles(const AFiles: array of string); override;                     { 4.9 }
    procedure ApplyEditStyle; override;                                                 { 5.3 }
    procedure DoEnter; override;
    procedure DoExit; override;
  public
    procedure SetWrap(AOn: Boolean);
    { ミニマップ用：行（0 始まり）の字句を、色と桁（0 始まり）・桁数で返す（10.2） }
    procedure ScanLineTokens(ALineIndex: Integer; ACols: TList; AColors: TList; ATabSize: Integer);
    { 10.5：表示の行（折り返し・折りたたみの後）の数と、表示の先頭の行（中の部品の protected を読む） }
    function ViewLineCount: Integer;
    function GetViewTop: Integer;
    procedure SetViewTop(AValue: Integer);
  end;

  { TCsMenuItem : 右クリックの内蔵の項目（7章）。Vis：1=選んでいるとき 2=いつも 3=選んでいないとき }
  TCsMenuItem = class(TMenuItem)
  public
    Cmd: Integer;
    Vis: Integer;
    NeedEdit: Boolean;
  end;

  { TCsPage : 1 つのタブ（3.3）。Ed.Pages[n] で取り出す。作るのはエディタ。アプリは Create・Free しない。
    並べ替えても同じタブを指す。閉じたあとは、読む値は空、操作は何もしない }
  TCsPage = class
  private
    FOwner: TCsEditor;
    FSyn: TCsSynEdit;               { 中の部品。閉じたら nil }
    FFileName: string;
    FEncoding: TCMEncoding;
    FLineBreak: string;             { #13#10 か #10 }
    FLanguage: string;
    FEmpty: TStringList;            { 閉じたページの Lines が返す空の一覧 }
    FWasModified: Boolean;          { 前に知らせた Modified（変わったときだけイベントを出す） }
    FLastStamp: Int64;              { 前に OnChange を出したときの本文の変更の番号（1 つの変更で 1 回だけ出す） }
    FUpdating: Boolean;             { 中の部品が本文を書き換えている途中（終わってから OnChange を出す） }
    function GetIndex: Integer;
    function GetCaption: string;
    function GetFileName: string;
    function GetModified: Boolean;
    function GetEncoding: TCMEncoding;
    procedure SetEncoding(AValue: TCMEncoding);
    function GetLanguage: string;
    procedure SetLanguage(const AValue: string);
    function GetText: string;
    procedure SetText(const AValue: string);
    function GetLines: TStrings;
    function GetLineCount: Integer;
    function GetSynEdit: TCSynEdit;
  public
    constructor Create(AOwner: TCsEditor);
    destructor Destroy; override;
    procedure Clear;
    function LoadFromFile(const AFileName: string): Boolean;
    function Save: Boolean;
    function SaveAs(const AFileName: string = ''): Boolean;
    function Close(Force: Boolean = False): Boolean;
    property Index: Integer read GetIndex;
    property Caption: string read GetCaption;
    property FileName: string read GetFileName;
    property Modified: Boolean read GetModified;
    property Encoding: TCMEncoding read GetEncoding write SetEncoding;
    property Language: string read GetLanguage write SetLanguage;
    property Text: string read GetText write SetText;
    property Lines: TStrings read GetLines;
    property LineCount: Integer read GetLineCount;
    property SynEdit: TCSynEdit read GetSynEdit;
  end;

  { TCsMinimap : 右端のミニマップ（10章）。見えているタブの本文を、色付きの小さな四角で描く }
  TCsMinimap = class(TCustomControl)
  private
    FEditor: TCsEditor;
    FBmp: TBitmap;
    FTimer: TTimer;           { 本文の変更をまとめる（100 ミリ秒） }
    FHover: Boolean;
    FDragging: Boolean;
    FDragY: Integer;
    FDragTop: Integer;
    FOrigin: Integer;         { 描き始めの行（1 始まり） }
    procedure TimerTick(Sender: TObject);
    function RowH: Integer;
    function SliderRect: TRect;
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Rebuild;            { 絵を作り直す }
    procedure ScheduleRebuild;    { 100 ミリ秒待ってから作り直す }
  end;

  { TCsFindForm : 検索・置換ダイアログの画面（8.1。TCMFindForm を写した） }
  TCsFindForm = class(TForm)
  private
    FDlg: TCsFindDialog;
    FCmbFind, FCmbReplace: TComboBox;
    FChkCase, FChkWord, FChkLoop: TCheckBox;
    FLblStatus: TLabel;
    FShownOnce: Boolean;
    function AddLabel(const ACaption: string; X, Y: Integer): TLabel;
    function AddButton(const ACaption: string; Y: Integer; AClick: TNotifyEvent): TButton;
    function AddCheck(const ACaption: string; Y: Integer): TCheckBox;
    function GetOptions: TCMFindOptions;
    procedure SetOptions(AValue: TCMFindOptions);
    procedure RefreshHistory;
    function Prepare: Boolean;
    procedure NextClick(Sender: TObject);
    procedure PrevClick(Sender: TObject);
    procedure ReplaceClick(Sender: TObject);
    procedure ReplaceAllClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
  public
    constructor CreateFor(ADlg: TCsFindDialog);
  end;

  { TCsFindDialog : TCsEditor の検索・置換ダイアログ（8.1。TCMFindDialog と同じ見た目・動き） }
  TCsFindDialog = class(TComponent)
  private
    FForm: TCsFindForm;
    FTarget: TCsEditor;
    FFindHistory, FReplaceHistory: TStringList;
    FSearchText, FReplaceText: string;
    FOptions: TCMFindOptions;
    function GetForm: TCsFindForm;
    procedure SetTarget(AValue: TCsEditor);
    procedure AddHistory(AList: TStringList; const S: string);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowFor(AEditor: TCsEditor; const InitialText: string = '');
    procedure CloseDialog;
    function IsShowing: Boolean;
    procedure UpdateCaption;
    procedure NotifyFindDone(AEditor: TCsEditor; Found: Boolean);
    procedure NotifyReplaceAllDone(AEditor: TCsEditor; Count: Integer);
    property Target: TCsEditor read FTarget write SetTarget;
    property SearchText: string read FSearchText;
    property ReplaceText: string read FReplaceText;
    property Options: TCMFindOptions read FOptions;
    property FindHistory: TStringList read FFindHistory;
    property ReplaceHistory: TStringList read FReplaceHistory;
  end;

  { TCsFormHook : フォームごとに 1 つ（3.4。TCMFormHook と同じ作り） }
  TCsFormHook = class(TComponent)
  private
    FForm: TForm;
    FEditors: TFPList;
    FActive: TCsEditor;
    FFindDialog: TCsFindDialog;
    FOldCloseQuery: TCloseQueryEvent;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor CreateFor(AForm: TForm);
    destructor Destroy; override;
    procedure AddEditor(AEditor: TCsEditor);
    procedure RemoveEditor(AEditor: TCsEditor);
    procedure SetActive(AEditor: TCsEditor);
    function ActiveEditor: TCsEditor;
    function SharedFindDialog: TCsFindDialog;
  end;

  { TCsEditor }

  TCsEditor = class(TCustomPanel)
  private
    FPages: TList;                  { 今あるタブ（並びの順） }
    FAllPages: TList;               { 作ったページすべて（閉じたものも。壊すときに解放する） }
    FCur: TCsPage;                  { 見えているタブ }
    FTabs: TATTabs;
    FMinimap: TCsMinimap;
    FVBar: TScrollBar;              { ミニマップを出している間の縦のスクロールバー（10.5） }
    FUpdatingBar: Boolean;          { FVBar を合わせ直している間 }
    FMenu: TPopupMenu;
    FMnuMinimap, FMnuPreview: TMenuItem;
    FHook: TCsFormHook;
    FDesignLines: TStringList;      { 設計時の Lines }
    FReadyDone: Boolean;
    FFocusPending: Boolean;
    FUpdatingTabs: Boolean;
    FDropHandled: Boolean;
    FFocusOnMouseUp: Boolean;
    FSuppressChange: Integer;       { 0 より大きい間は、中の部品の OnChange を知らせない }
    FLastCurLine, FLastCurCol: Integer;
    FErrQueue: TStringList;
    FDropFiles: TStringList;
    FLineWords: TStringList;
    FLineWordsKey: string;
    FLastDir: string;
    FInnerOpenDlg: TOpenDialog;
    FInnerSaveDlg: TSaveDialog;
    FSysImages: TImageList;
    FSysIconExts: TStringList;
    FOsDark: Boolean;
    { 設定 }
    FMultiDocument: Boolean;
    FConfirmOnFormClose: Boolean;
    FTabTearOff: Boolean;
    FOpenDialog: TOpenDialog;
    FSaveDialog: TSaveDialog;
    FFindDialog: TCsFindDialog;
    FTabFlat, FTabSeparator, FTabIcons: Boolean;
    FTabImages: TImageList;
    FWordWrap: Boolean;
    FLineNumbers: Boolean;
    FTabSize: Integer;
    FFolding: Boolean;
    FMatchBrackets: Boolean;
    FOccurrencesHighlight: Boolean;
    FMinimapOn: Boolean;
    FTheme: TCMTheme;
    FReadOnly: Boolean;
    FDefaultLanguage: string;
    FAutoLanguage: Boolean;
    FOpenDroppedFiles: Boolean;
    FQuotePrefix: string;
    FHitColorLight, FHitColorDark: TColor;
    FCursorLineColorLight, FCursorLineColorDark: TColor;
    FSelectionColorStyle: TCMSelectionColorStyle;
    FSelectionColorLight, FSelectionColorDark: TColor;
    FShowPreview: Boolean;
    FAllowRemoteImages: Boolean;    { Preview が無い間の AllowRemoteImages（9章） }
    FPreview: TCPreview;
    FLineDelimiters: string;
    FLineSkipEmpty: Boolean;
    FLineQuoteChar: Char;
    FSearchText, FReplaceText: string;
    FSearchOptions: TCMFindOptions;
    { 分離・結合・移す（4.11・4.12） }
    FTearOffHead: TStringList;
    FTearOffBody: string;
    FTearOffPending: Boolean;
    FMergeQueue: TStringList;
    FDragOutPage: TCsPage;
    FDragOutPos: TPoint;
    FMovePage: TCsPage;
    FMoveDest: TCsEditor;
    { イベント }
    FOnReady: TNotifyEvent;
    FOnChange: TNotifyEvent;
    FOnCursorChange: TCMCursorEvent;
    FOnModeChange: TCMModeEvent;
    FOnModifiedChange: TNotifyEvent;
    FOnActiveChange: TNotifyEvent;
    FOnDocListChange: TNotifyEvent;
    FOnDocumentChange: TCMDocIndexEvent;
    FOnSave: TCMSaveEvent;
    FOnQueryClose: TCMQueryCloseEvent;
    FOnNeedFileName: TCMNeedFileNameEvent;
    FOnFileDrop: TCMFileDropEvent;
    FOnToggleMaximize: TNotifyEvent;
    FOnFontSizeChange: TNotifyEvent;
    FOnLineNumbersChange: TNotifyEvent;
    FOnFindDone: TCMFindDoneEvent;
    FOnReplaceAllDone: TCMReplaceAllDoneEvent;
    FOnPopup: TNotifyEvent;
    FOnGetTabImageIndex: TCMTabImageEvent;
    FOnTabDragOut: TCMTabDragOutEvent;
    FOnError: TCMErrorEvent;

    { ページ・タブ }
    function NewPageObj: TCsPage;
    procedure SetCurPage(P: TCsPage);
    procedure RemovePage(P: TCsPage);
    procedure RebuildTabs;
    procedure UpdateTab(P: TCsPage);
    function TabCaptionFor(P: TCsPage): string;
    function ImageIndexFor(P: TCsPage): Integer;
    function SystemIconIndex(const AFileName: string): Integer;
    procedure ApplyTabShape;
    procedure ApplyTabIcons;
    procedure ApplyTabColors;
    procedure TabClick(Sender: TObject);
    procedure TabPlusClick(Sender: TObject);
    procedure TabClose(Sender: TObject; ATabIndex: Integer; var ACanClose, ACanContinue: Boolean);
    procedure TabDropQuery(Sender: TObject; AIndexFrom, AIndexTo: Integer; var ACanDrop: Boolean);
    procedure TabMove(Sender: TObject; AIndexFrom, AIndexTo: Integer);
    procedure TabsMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure TabsEndDrag(Sender, Target: TObject; X, Y: Integer);
    procedure AsyncTabClose(Data: PtrInt);
    procedure AsyncFocus(Data: PtrInt);
    procedure AsyncSetFocus(Data: PtrInt);
    procedure FocusLater;
    { 本文・ファイル }
    procedure SetBodyText(P: TCsPage; const S: string);
    procedure LoadCore(P: TCsPage; const AFileName, ABody: string; AEnc: TCMEncoding);
    function WriteCore(P: TCsPage; const AFileName: string): Boolean;
    function PageLoad(P: TCsPage; const AFileName: string): Boolean;
    function PageSave(P: TCsPage): Boolean;
    function PageSaveAs(P: TCsPage; const AFileName: string): Boolean;
    procedure PageClear(P: TCsPage);
    function PageClose(P: TCsPage; Force: Boolean): Boolean;
    procedure PageSetText(P: TCsPage; const AValue: string);
    procedure PageSetLanguage(P: TCsPage; const AValue: string; AFire: Boolean);
    function OpenWithDialog: Integer;
    function AskPageFileName(P: TCsPage; var AFileName: string): Boolean;
    function AskSaveFileName(P: TCsPage; var AFileName: string): Boolean;
    function DefaultExtFor(const ALanguage: string): string;
    function QueryCurrent: Boolean;
    procedure DoQueryClose(AIndex: Integer; var CanClose: Boolean);
    function OpenedElsewhere(P: TCsPage; const AFileName: string): Boolean;
    function FindInOtherEditors(const AFileName: string; out AEditor: TCsEditor): Integer;
    { イベントの中継 }
    procedure InnerChange(Sender: TObject);
    procedure InnerUpdating(ASender: TObject; AnUpdating: Boolean);
    procedure InnerStatus(Sender: TObject; Changes: TSynStatusChanges);
    procedure CheckModified(P: TCsPage);
    procedure DocChanged(P: TCsPage);
    procedure DoDocListChange;
    procedure InnerEnter(S: TCsSynEdit);
    procedure InnerExit(S: TCsSynEdit);
    procedure QueueDrop(const AFiles: array of string);
    procedure AsyncDropFiles(Data: PtrInt);
    procedure AsyncReady(Data: PtrInt);
    procedure AsyncPrint(Data: PtrInt);
    procedure DoError(const AMessage: string);
    procedure AsyncShowError(Data: PtrInt);
    { 設定 }
    procedure ApplyOptionsTo(S: TCsSynEdit; AFirst: Boolean);
    procedure ApplyAllOptions;
    procedure UpdateVBar;
    procedure VBarChange(Sender: TObject);
    procedure ApplyBarsLayout;
    procedure ApplyEditorColors(S: TCsSynEdit);
    procedure ApplyTheme;
    procedure ReadOsTheme;
    procedure AsyncOsTheme(Data: PtrInt);
    procedure RegisterWithForm;
    { キー（6章） }
    function HandleKey(S: TCsSynEdit; var Key: Word; Shift: TShiftState): Boolean;
    function RunFormShortcut(Key: Word; Shift: TShiftState): Boolean;
    procedure GotoLineDialog;
    { 編集（6.4） }
    procedure TargetLines(S: TCsSynEdit; out L1, L2: Integer);
    procedure MoveLines(AUp: Boolean);
    procedure CopyLines(AUp: Boolean);
    procedure ToggleComment;
    procedure InsertLineBelow;
    procedure ConvertSelection(ACmd: Integer);
    { 右クリック（7章） }
    procedure BuildMenu;
    function AddMenuItem(const ACaption: string; ACmd, AVis: Integer; ANeedEdit: Boolean): TCsMenuItem;
    procedure MenuPopup(Sender: TObject);
    procedure MenuClick(Sender: TObject);
    procedure MenuMinimapClick(Sender: TObject);
    procedure MenuPreviewClick(Sender: TObject);
    { 分離・結合・移す（4.11・4.12） }
    function TearOffName: string;
    procedure AsyncTabDragOut(Data: PtrInt);
    procedure AsyncMoveTab(Data: PtrInt);
    procedure MovePageTo(P: TCsPage; ADest: TCsEditor);
    function MakeTearOffFile(P: TCsPage; X, Y: Integer; out AFile: string): Boolean;
    function TryMerge(P: TCsPage; X, Y: Integer): Boolean;
    function SendTearOff(P: TCsPage; X, Y: Integer): Boolean;
    function TryClaimTearOff: Boolean;
    procedure MoveFormToTearOff;
    procedure ApplyTearOff;
    procedure AsyncMerge(Data: PtrInt);
    procedure AsyncBringFront(Data: PtrInt);
    function CurrentFindDialog(ACreate: Boolean): TCsFindDialog;
    { プロパティ }
    function GetPage(AIndex: Integer): TCsPage;
    function GetPageCount: Integer;
    function GetActiveIndex: Integer;
    procedure SetActiveIndex(AValue: Integer);
    function GetEdText: string;
    procedure SetEdText(const AValue: string);
    function GetEdCaption: string;
    function GetEdFileName: string;
    function GetEdModified: Boolean;
    function GetEdEncoding: TCMEncoding;
    procedure SetEdEncoding(AValue: TCMEncoding);
    function GetEdLanguage: string;
    procedure SetEdLanguage(const AValue: string);
    function GetEdLineCount: Integer;
    function GetSynEdit: TCSynEdit;
    function GetLines: TStrings;
    procedure SetLines(AValue: TStrings);
    function GetSelText: string;
    procedure SetSelText(const AValue: string);
    function GetSelStart: Integer;
    function GetSelLength: Integer;
    function GetCanUndo: Boolean;
    function GetCanRedo: Boolean;
    function GetLineText: string;
    function GetLineWords: TStrings;
    function GetReady: Boolean;
    procedure SetMultiDocument(AValue: Boolean);
    procedure SetOpenDialog(AValue: TOpenDialog);
    procedure SetSaveDialog(AValue: TSaveDialog);
    procedure SetFindDialog(AValue: TCsFindDialog);
    procedure SetTabFlat(AValue: Boolean);
    procedure SetTabSeparator(AValue: Boolean);
    procedure SetTabIcons(AValue: Boolean);
    procedure SetTabImages(AValue: TImageList);
    procedure SetWordWrap(AValue: Boolean);
    procedure SetLineNumbers(AValue: Boolean);
    function GetFontSize: Integer;
    procedure SetFontSize(AValue: Integer);
    procedure SetTabSize(AValue: Integer);
    procedure SetFolding(AValue: Boolean);
    procedure SetMatchBrackets(AValue: Boolean);
    procedure SetOccurrencesHighlight(AValue: Boolean);
    procedure SetMinimap(AValue: Boolean);
    procedure SetTheme(AValue: TCMTheme);
    procedure SetReadOnly(AValue: Boolean);
    procedure SetDefaultLanguage(const AValue: string);
    procedure SetHitColorLight(AValue: TColor);
    procedure SetHitColorDark(AValue: TColor);
    procedure SetCursorLineColorLight(AValue: TColor);
    procedure SetCursorLineColorDark(AValue: TColor);
    procedure SetSelectionColorStyle(AValue: TCMSelectionColorStyle);
    procedure SetSelectionColorLight(AValue: TColor);
    procedure SetSelectionColorDark(AValue: TColor);
    function IsSelColorStored: Boolean;
    function IsDefaultLanguageStored: Boolean;
    function IsQuotePrefixStored: Boolean;
    function GetShowPreview: Boolean;
    function GetAllowRemoteImages: Boolean;
    procedure SetAllowRemoteImages(AValue: Boolean);
    procedure SetShowPreview(AValue: Boolean);
    procedure SetPreview(AValue: TCPreview);
    function GetSearchOptions: TCMFindOptions;
  protected
    procedure Loaded; override;
    procedure CreateWnd; override;
    procedure Paint; override;
    procedure FontChanged(Sender: TObject); override;
    procedure Resize; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    { キー（6.1 の 1）。override して inherited を呼ぶと OnKeyDown が呼ばれる（TWinControl と同じ） }
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { タブの集まり（4.1） }
    function OpenFile(const AFileName: string = ''): Integer;
    function NewPage: Integer;
    procedure SaveAll;
    function CloseAll(Force: Boolean = False): Boolean;
    function CanCloseAll: Boolean;
    function FindPage(const AFileName: string): Integer;
    procedure MovePage(AFromIndex, AToIndex: Integer);
    { 見えているタブ }
    function LoadFromFile(const AFileName: string): Boolean;
    function Save: Boolean;
    function SaveAs(const AFileName: string = ''): Boolean;
    procedure Clear;
    function Close(Force: Boolean = False): Boolean;
    { 画面の上での操作（3.2） }
    procedure GetCursorPos(out ALine, AColumn: Integer);
    procedure SetCursorPos(ALine, AColumn: Integer);
    procedure SetSelection(ALine1, AColumn1, ALine2, AColumn2: Integer);
    procedure Undo;
    procedure Redo;
    procedure Cut;
    procedure Copy;
    procedure Paste;
    procedure SelectAll;
    procedure DeleteToEnd;
    procedure DeleteToStart;
    procedure DuplicateLine;
    procedure ToggleOverwrite;
    procedure Find(const S: string; AOptions: TCMFindOptions; AForward: Boolean = True);
    procedure FindNext;
    procedure FindPrev;
    procedure Replace(const S, R: string; AOptions: TCMFindOptions);
    procedure ReplaceAll(const S, R: string; AOptions: TCMFindOptions);
    procedure ShowFindDialog(const InitialText: string = '');
    function CanPrint: Boolean;
    procedure Print;
    procedure SetFocus; override;
    function TopLine: Double;
    procedure ScrollToLine(ALine: Double);
    { 今ダークで描いているか（ctDark=True、ctLight=False、ctAuto=OS の設定）。TCPreview が境目の色に使う }
    function IsDarkTheme: Boolean;

    property Pages[AIndex: Integer]: TCsPage read GetPage;
    property PageCount: Integer read GetPageCount;
    property ActiveIndex: Integer read GetActiveIndex write SetActiveIndex;
    property Text: string read GetEdText write SetEdText;
    property Caption: string read GetEdCaption;
    property FileName: string read GetEdFileName;
    property Modified: Boolean read GetEdModified;
    property Encoding: TCMEncoding read GetEdEncoding write SetEdEncoding;
    property Language: string read GetEdLanguage write SetEdLanguage;
    property LineCount: Integer read GetEdLineCount;
    property SynEdit: TCSynEdit read GetSynEdit;
    property SelText: string read GetSelText write SetSelText;
    property SelStart: Integer read GetSelStart;
    property SelLength: Integer read GetSelLength;
    property CanUndo: Boolean read GetCanUndo;
    property CanRedo: Boolean read GetCanRedo;
    property LineText: string read GetLineText;
    property LineWords: TStrings read GetLineWords;
    property LineDelimiters: string read FLineDelimiters write FLineDelimiters;
    property LineSkipEmpty: Boolean read FLineSkipEmpty write FLineSkipEmpty;
    property LineQuoteChar: Char read FLineQuoteChar write FLineQuoteChar;
    property SearchText: string read FSearchText write FSearchText;
    property ReplaceText: string read FReplaceText write FReplaceText;
    property SearchOptions: TCMFindOptions read GetSearchOptions write FSearchOptions;
    property Ready: Boolean read GetReady;
    property ContextMenu: TPopupMenu read FMenu;
    property Color;
  published
    property MultiDocument: Boolean read FMultiDocument write SetMultiDocument default True;
    property ConfirmOnFormClose: Boolean read FConfirmOnFormClose write FConfirmOnFormClose default True;
    property TabTearOff: Boolean read FTabTearOff write FTabTearOff default True;
    property OpenDialog: TOpenDialog read FOpenDialog write SetOpenDialog;
    property SaveDialog: TSaveDialog read FSaveDialog write SetSaveDialog;
    property FindDialog: TCsFindDialog read FFindDialog write SetFindDialog;
    property TabFlat: Boolean read FTabFlat write SetTabFlat default True;
    property TabSeparator: Boolean read FTabSeparator write SetTabSeparator default False;
    property TabIcons: Boolean read FTabIcons write SetTabIcons default True;
    property TabImages: TImageList read FTabImages write SetTabImages;
    property WordWrap: Boolean read FWordWrap write SetWordWrap default True;
    property LineNumbers: Boolean read FLineNumbers write SetLineNumbers default False;
    property Font;
    property FontSize: Integer read GetFontSize write SetFontSize stored False;
    property TabSize: Integer read FTabSize write SetTabSize default 4;
    property Folding: Boolean read FFolding write SetFolding default True;
    property MatchBrackets: Boolean read FMatchBrackets write SetMatchBrackets default True;
    property OccurrencesHighlight: Boolean read FOccurrencesHighlight write SetOccurrencesHighlight default True;
    property Minimap: Boolean read FMinimapOn write SetMinimap default False;
    property Theme: TCMTheme read FTheme write SetTheme default ctAuto;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly default False;
    property DefaultLanguage: string read FDefaultLanguage write SetDefaultLanguage stored IsDefaultLanguageStored;
    property AutoLanguage: Boolean read FAutoLanguage write FAutoLanguage default True;
    property OpenDroppedFiles: Boolean read FOpenDroppedFiles write FOpenDroppedFiles default True;
    property QuotePrefix: string read FQuotePrefix write FQuotePrefix stored IsQuotePrefixStored;
    property HitColorLight: TColor read FHitColorLight write SetHitColorLight default DefHitColorLight;
    property HitColorDark: TColor read FHitColorDark write SetHitColorDark default DefHitColorDark;
    property CursorLineColorLight: TColor read FCursorLineColorLight write SetCursorLineColorLight default DefCursorLineColorLight;
    property CursorLineColorDark: TColor read FCursorLineColorDark write SetCursorLineColorDark default DefCursorLineColorDark;
    property SelectionColorStyle: TCMSelectionColorStyle read FSelectionColorStyle write SetSelectionColorStyle default scStandard;
    property SelectionColorLight: TColor read FSelectionColorLight write SetSelectionColorLight stored IsSelColorStored;
    property SelectionColorDark: TColor read FSelectionColorDark write SetSelectionColorDark stored IsSelColorStored;
    property ShowPreview: Boolean read GetShowPreview write SetShowPreview default False;
    { プレビューでネット（http）の画像を出すか。つながっている TCPreview の AllowRemoteImages（TCMonacoEditor と同じ名前） }
    property AllowRemoteImages: Boolean read GetAllowRemoteImages write SetAllowRemoteImages default False;
    property Preview: TCPreview read FPreview write SetPreview;
    property Lines: TStrings read GetLines write SetLines;
    property Align;
    property Anchors;
    property BorderSpacing;
    property Constraints;
    property Enabled;
    property Visible;
    property TabOrder;
    property TabStop;
    property OnReady: TNotifyEvent read FOnReady write FOnReady;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnCursorChange: TCMCursorEvent read FOnCursorChange write FOnCursorChange;
    property OnModeChange: TCMModeEvent read FOnModeChange write FOnModeChange;
    property OnModifiedChange: TNotifyEvent read FOnModifiedChange write FOnModifiedChange;
    property OnActiveChange: TNotifyEvent read FOnActiveChange write FOnActiveChange;
    property OnDocListChange: TNotifyEvent read FOnDocListChange write FOnDocListChange;
    property OnDocumentChange: TCMDocIndexEvent read FOnDocumentChange write FOnDocumentChange;
    property OnSave: TCMSaveEvent read FOnSave write FOnSave;
    property OnQueryClose: TCMQueryCloseEvent read FOnQueryClose write FOnQueryClose;
    property OnNeedFileName: TCMNeedFileNameEvent read FOnNeedFileName write FOnNeedFileName;
    property OnFileDrop: TCMFileDropEvent read FOnFileDrop write FOnFileDrop;
    property OnToggleMaximize: TNotifyEvent read FOnToggleMaximize write FOnToggleMaximize;
    property OnFontSizeChange: TNotifyEvent read FOnFontSizeChange write FOnFontSizeChange;
    property OnLineNumbersChange: TNotifyEvent read FOnLineNumbersChange write FOnLineNumbersChange;
    property OnFindDone: TCMFindDoneEvent read FOnFindDone write FOnFindDone;
    property OnReplaceAllDone: TCMReplaceAllDoneEvent read FOnReplaceAllDone write FOnReplaceAllDone;
    property OnPopup: TNotifyEvent read FOnPopup write FOnPopup;
    property OnGetTabImageIndex: TCMTabImageEvent read FOnGetTabImageIndex write FOnGetTabImageIndex;
    property OnTabDragOut: TCMTabDragOutEvent read FOnTabDragOut write FOnTabDragOut;
    property OnKeyDown;
    property OnError: TCMErrorEvent read FOnError write FOnError;
  end;

  { ---------- 標準アクション（11章） ---------- }

  { TCsEditorAction : 標準アクションの元のクラス。対象は CsActiveEditor(フォーム) }
  TCsEditorAction = class(TAction)
  protected
    function TargetEditor: TCsEditor;
    function CanRun(AEditor: TCsEditor): Boolean; virtual;
    procedure Run(AEditor: TCsEditor); virtual; abstract;
  public
    constructor Create(AOwner: TComponent); override;
    function Execute: Boolean; override;
    function Update: Boolean; override;
  end;

  { TCsEditorToggleAction : 切り替えのアクションの元のクラス（実行で反転、Update でチェックを合わせる） }
  TCsEditorToggleAction = class(TCsEditorAction)
  protected
    function GetValue(AEditor: TCsEditor): Boolean; virtual; abstract;
    procedure SetValue(AEditor: TCsEditor; AValue: Boolean); virtual; abstract;
    procedure Run(AEditor: TCsEditor); override;
  public
    function Update: Boolean; override;
  end;

  TCsEditorNew = class(TCsEditorAction)
  protected procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorOpen = class(TCsEditorAction)
  protected procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorSave = class(TCsEditorAction)
  protected procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorSaveAs = class(TCsEditorAction)
  protected procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorClose = class(TCsEditorAction)
  protected procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorPrint = class(TCsEditorAction)
  protected function CanRun(AEditor: TCsEditor): Boolean; override; procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorSaveAll = class(TCsEditorAction)
  protected function CanRun(AEditor: TCsEditor): Boolean; override; procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorCloseAll = class(TCsEditorAction)
  protected procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorUndo = class(TCsEditorAction)
  protected function CanRun(AEditor: TCsEditor): Boolean; override; procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorRedo = class(TCsEditorAction)
  protected function CanRun(AEditor: TCsEditor): Boolean; override; procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorCut = class(TCsEditorAction)
  protected function CanRun(AEditor: TCsEditor): Boolean; override; procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorCopy = class(TCsEditorAction)
  protected function CanRun(AEditor: TCsEditor): Boolean; override; procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorPaste = class(TCsEditorAction)
  protected function CanRun(AEditor: TCsEditor): Boolean; override; procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorSelectAll = class(TCsEditorAction)
  protected procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorDuplicateLine = class(TCsEditorAction)
  protected function CanRun(AEditor: TCsEditor): Boolean; override; procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorDeleteToEnd = class(TCsEditorAction)
  protected function CanRun(AEditor: TCsEditor): Boolean; override; procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorDeleteToStart = class(TCsEditorAction)
  protected function CanRun(AEditor: TCsEditor): Boolean; override; procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorFind = class(TCsEditorAction)
  protected procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorFindNext = class(TCsEditorAction)
  protected procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorFindPrev = class(TCsEditorAction)
  protected procedure Run(AEditor: TCsEditor); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorMinimap = class(TCsEditorToggleAction)
  protected
    function GetValue(AEditor: TCsEditor): Boolean; override;
    procedure SetValue(AEditor: TCsEditor; AValue: Boolean); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorPreview = class(TCsEditorToggleAction)
  protected
    function CanRun(AEditor: TCsEditor): Boolean; override;
    function GetValue(AEditor: TCsEditor): Boolean; override;
    procedure SetValue(AEditor: TCsEditor; AValue: Boolean); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorLineNumbers = class(TCsEditorToggleAction)
  protected
    function GetValue(AEditor: TCsEditor): Boolean; override;
    procedure SetValue(AEditor: TCsEditor; AValue: Boolean); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorWordWrap = class(TCsEditorToggleAction)
  protected
    function GetValue(AEditor: TCsEditor): Boolean; override;
    procedure SetValue(AEditor: TCsEditor; AValue: Boolean); override;
  public constructor Create(AOwner: TComponent); override; end;
  TCsEditorRemoteImages = class(TCsEditorToggleAction)
  protected
    function CanRun(AEditor: TCsEditor): Boolean; override;
    function GetValue(AEditor: TCsEditor): Boolean; override;
    procedure SetValue(AEditor: TCsEditor; AValue: Boolean); override;
  public constructor Create(AOwner: TComponent); override; end;

{ フォームで最後にフォーカスされた TCsEditor。まだどれもフォーカスされていなければ最初のもの。無ければ nil }
function CsActiveEditor(AForm: TCustomForm): TCsEditor;

{ OS がダークか（レジストリ AppsUseLightTheme が 0 ならダーク。値が無ければライト）。TCPreview が、表示元が無いときに使う }
function CsOsIsDark: Boolean;

implementation

uses
  uCXLang,
  LazUTF8, LConvEncoding, StrUtils, Math, SynEditHighlighter;

{ ================================================================== }
{ 写したもの（2.2：uCmonacos・ucmmonacoview の implementation にあるもの） }
{ ================================================================== }

const
  { 選択範囲の色の組（暗い配色・明るい配色）。scCustom は使わない }
  SelStyleDark: array[TCMSelectionColorStyle] of TColor =
    (TColor($00784F26), TColor($009E5A0E), TColor($00004E6B), TColor($00822D5A), clNone);
  SelStyleLight: array[TCMSelectionColorStyle] of TColor =
    (TColor($00FFD6AD), TColor($00FFB67F), TColor($004FD5FF), TColor($00FFA3C5), clNone);
  MAX_HISTORY = 30;

  { 右クリックの項目の番号（Cmd） }
  mcCut = 1; mcCopy = 2; mcPaste = 3; mcSelectAll = 4; mcUndo = 5; mcRedo = 6;
  mcQuoteCopy = 7; mcAppendCut = 8; mcAppendCopy = 9; mcDelete = 10;
  mcUpper = 11; mcLower = 12; mcHankaku = 13; mcHiragana = 14; mcKatakana = 15;
  mcDetab = 16; mcEntab = 17; mcIndent = 18; mcOutdent = 19; mcSep = 0;

{ 内蔵の開く・保存ダイアログのフィルター（TCMonacoEditor と同じ）。
  「テキスト・すべてのファイル」の部分は今の言語の文字列（CXT）なので、定数ではなく関数で返す }
function InnerFilter: string;
begin
  Result := 'Markdown (*.md;*.markdown)|*.md;*.markdown|' + CXT(sFilterText);
end;

function BytesToStr(const B: TBytes; AStart: Integer): string;
var
  N: Integer;
begin
  N := Length(B) - AStart;
  if N <= 0 then Exit('');
  SetLength(Result, N);
  Move(B[AStart], Result[1], N);
end;

{ 文字コードを判定して UTF-8 にする（BOM → UTF-8 として正しいか → CP932。TCMonacoEditor と同じ） }
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

{ UTF-8 の文字列を、その文字コードのバイトにする。CP932 で表せない文字があれば例外 }
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
          raise Exception.Create(CXT(sErrCp932));
        SetLength(Result, Length(T));
        if Length(T) > 0 then Move(T[1], Result[0], Length(T));
      end;
  end;
end;

{ ファイルを読んで UTF-8 にする（読む間だけ開く。ファイルを押さえない） }
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

{ ================================================================== }
{ 小さな道具                                                          }
{ ================================================================== }

{ 色を実際の色にする（システム色は今の色、clDefault・clNone は既定値） }
function RealColor(AColor, ADefault: TColor): TColor;
begin
  if (AColor = clDefault) or (AColor = clNone) then AColor := ADefault;
  Result := ColorToRGB(AColor);
end;

{ UTF-8 の文字列の、UTF-16 での長さ（6.5） }
function U16Len(const S: string): Integer;
begin
  Result := Length(UTF8Decode(S));
end;

{ 中の部品の行（1 始まり）。無ければ '' }
function LineOf(S: TCustomSynEdit; ALine: Integer): string;
begin
  if (ALine >= 1) and (ALine <= S.Lines.Count) then Result := S.Lines[ALine - 1] else Result := '';
end;

{ 中の部品の行数（空の本文も 1 行と数える） }
function LineTotal(S: TCustomSynEdit): Integer;
begin
  Result := Max(1, S.Lines.Count);
end;

{ UTF-8 のバイトの桁（1 始まり）→ UTF-16 の桁（1 始まり） }
function ByteToU16Col(const ALine: string; ALogX: Integer): Integer;
begin
  Result := U16Len(System.Copy(ALine, 1, ALogX - 1)) + 1;
end;

{ UTF-16 の桁（1 始まり）→ UTF-8 のバイトの桁（1 始まり）。行の長さを越えたら行の終わり }
function U16ToByteCol(const ALine: string; ACol: Integer): Integer;
var
  P, N, L, U: Integer;
begin
  P := 1;
  N := 1;
  while (N < ACol) and (P <= Length(ALine)) do
  begin
    L := UTF8CodepointSize(@ALine[P]);
    if L < 1 then L := 1;
    if L = 4 then U := 2 else U := 1;      { 4 バイトの文字は UTF-16 で 2 つ（絵文字など） }
    if N + U > ACol then Break;            { 2 つの真ん中は指せないので、その文字の前 }
    Inc(N, U);
    Inc(P, L);
  end;
  Result := P;
end;

{ 改行を #13#10・#10・#13 のどれでも、指定の改行にそろえる }
function NormalizeBreaks(const S, ABreak: string): string;
begin
  Result := StringReplace(S, #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #13, #10, [rfReplaceAll]);
  if ABreak <> #10 then Result := StringReplace(Result, #10, ABreak, [rfReplaceAll]);
end;

{ 行の頭の空白・タブ }
function LeadingSpace(const S: string): string;
var
  I: Integer;
begin
  I := 1;
  while (I <= Length(S)) and (S[I] in [' ', #9]) do Inc(I);
  Result := System.Copy(S, 1, I - 1);
end;

{ OS がダークか（レジストリ AppsUseLightTheme が 0 ならダーク。値が無ければライト。4.7） }
function OsIsDark: Boolean;
var
  R: TRegistry;
begin
  Result := False;
  R := TRegistry.Create(KEY_READ);
  try
    R.RootKey := HKEY_CURRENT_USER;
    if R.OpenKeyReadOnly('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize') then
      if R.ValueExists('AppsUseLightTheme') then
        Result := R.ReadInteger('AppsUseLightTheme') = 0;
  finally
    R.Free;
  end;
end;

var
  GShownErrors: TStringList = nil;    { 既定のエラー表示で、表示済みのメッセージ（同じものは 1 回だけ） }
  GEditors: TFPList = nil;            { 実行時の TCsEditor の一覧（結合・OS のテーマの知らせ。4.11・4.7） }
  GReceiverWnd: HWND = 0;             { 受け口のウィンドウ（プロセスに 1 つ） }
  GReceiverClassOk: Boolean = False;

procedure EnsureReceiver; forward;

{ スクロールバーの見た目（Windows が描く部分）を変える（uxtheme.dll。4.7） }
function CsSetWindowTheme(AWnd: HWND; ASubAppName, ASubIdList: PWideChar): HRESULT; stdcall;
  external 'uxtheme.dll' name 'SetWindowTheme';

{ スクロールバーの部品に、ダーク・ライトの見た目を当てる（変わったときだけ。Tag に 当てた値+1 を覚える。4.7） }
procedure ApplyBarTheme(W: TWinControl; ADark: Boolean);
begin
  if (W = nil) or not W.HandleAllocated or (W.Tag = Ord(ADark) + 1) then Exit;
  W.Tag := Ord(ADark) + 1;
  try
    if ADark then CsSetWindowTheme(W.Handle, 'DarkMode_Explorer', nil)
    else CsSetWindowTheme(W.Handle, 'Explorer', nil);
  except
    { uxtheme が無い・古い Windows：色は変わらない }
  end;
end;

function CsOsIsDark: Boolean;
begin
  try
    Result := OsIsDark;
  except
    Result := False;
  end;
end;

{ ================================================================== }
{ TCsSynEdit（5章）                                                   }
{ ================================================================== }

procedure TCsSynEdit.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if FEditor = nil then
  begin
    inherited KeyDown(Key, Shift);
    Exit;
  end;
  { 6.1 の 1：TCsEditor の KeyDown（その中の inherited で OnKeyDown） }
  FEditor.KeyDown(Key, Shift);
  if Key = 0 then Exit;
  { 6.1 の 2〜7：TCsEditor が受けるキー }
  if FEditor.HandleKey(Self, Key, Shift) then
  begin
    Key := 0;
    Exit;
  end;
  { 6.1 の 8：Keystrokes（5.5）。TCSynEdit の Ctrl+S・Shift+F10・F12 は 6.1 の 5 で受けているので届かない }
  inherited KeyDown(Key, Shift);
end;

function TCsSynEdit.DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint): Boolean;
var
  Old: Integer;
begin
  if (FEditor <> nil) and (ssCtrl in Shift) then
  begin
    { Ctrl+ホイール：全タブの文字の大きさを 1 下げる（5.4） }
    Old := FEditor.FontSize;
    FEditor.FontSize := Old - 1;
    if (FEditor.FontSize <> Old) and Assigned(FEditor.FOnFontSizeChange) then FEditor.FOnFontSizeChange(FEditor);
    Exit(True);
  end;
  Result := inherited DoMouseWheelDown(Shift, MousePos);
end;

function TCsSynEdit.DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean;
var
  Old: Integer;
begin
  if (FEditor <> nil) and (ssCtrl in Shift) then
  begin
    Old := FEditor.FontSize;
    FEditor.FontSize := Old + 1;
    if (FEditor.FontSize <> Old) and Assigned(FEditor.FOnFontSizeChange) then FEditor.FOnFontSizeChange(FEditor);
    Exit(True);
  end;
  Result := inherited DoMouseWheelUp(Shift, MousePos);
end;

procedure TCsSynEdit.DoDropFiles(const AFiles: array of string);
begin
  { ウィンドウのメッセージの途中で確認のダイアログを出さないよう、あとで開く（4.9） }
  if FEditor <> nil then FEditor.QueueDrop(AFiles);
end;

procedure TCsSynEdit.ApplyEditStyle;
begin
  inherited ApplyEditStyle;                { TCSynEdit の csVSLight・csVSDark の色 }
  if FEditor <> nil then FEditor.ApplyEditorColors(Self);   { そのあとで TCsEditor の設定の色（5.3） }
end;

procedure TCsSynEdit.DoEnter;
begin
  inherited DoEnter;
  if FEditor <> nil then FEditor.InnerEnter(Self);
end;

procedure TCsSynEdit.CreateWnd;
begin
  inherited CreateWnd;
  { ウィンドウを作り直すと、当てたスクロールバーの見た目は消えるので当て直す }
  FDarkBars := -1;
  if FEditor <> nil then FEditor.ApplyEditorColors(Self);
end;

procedure TCsSynEdit.DoExit;
begin
  inherited DoExit;
  if FEditor <> nil then FEditor.InnerExit(Self);
end;

function TCsSynEdit.ViewLineCount: Integer;
begin
  Result := Max(1, ViewedTextBuffer.ViewedCount);
end;

function TCsSynEdit.GetViewTop: Integer;
begin
  Result := TopView;
end;

procedure TCsSynEdit.SetViewTop(AValue: Integer);
begin
  TopView := Max(1, AValue);
end;

procedure TCsSynEdit.SetWrap(AOn: Boolean);
begin
  if AOn then
  begin
    if FWrap = nil then FWrap := TLazSynEditLineWrapPlugin.Create(Self);
  end
  else
    FreeAndNil(FWrap);
end;

{ 行（0 始まり）を色分けでたどり、字句ごとに「桁の始まり・桁数・色」を入れる（10.2）。
  ACols には 始まり・桁数 の 2 つずつ、AColors には色を 1 つずつ入れる。空白だけの字句は入れない }
procedure TCsSynEdit.ScanLineTokens(ALineIndex: Integer; ACols: TList; AColors: TList; ATabSize: Integer);
var
  H: TSynCustomHighlighter;
  L, Tok: string;
  TS: PChar;
  TL, Col, StartCol, P, CL, I: Integer;
  C, Def: TColor;
  HasInk: Boolean;
begin
  ACols.Clear;
  AColors.Clear;
  if (ALineIndex < 0) or (ALineIndex >= Lines.Count) then Exit;
  L := Lines[ALineIndex];
  if L = '' then Exit;
  Def := Font.Color;
  if Def = clDefault then Def := clWindowText;
  H := nil;
  if Highlighter is TSynCustomHighlighter then H := TSynCustomHighlighter(Highlighter);
  Col := 0;
  if H = nil then
  begin
    { 色分けが無い：行全体を本文の文字色で }
    Tok := L;
    P := 1;
    while P <= Length(Tok) do
    begin
      CL := UTF8CodepointSize(@Tok[P]);
      if CL < 1 then CL := 1;
      if Tok[P] = #9 then
        Col := (Col div ATabSize + 1) * ATabSize
      else
      begin
        if Tok[P] <> ' ' then
        begin
          ACols.Add(Pointer(PtrInt(Col)));
          if CL >= 3 then I := 2 else I := 1;
          ACols.Add(Pointer(PtrInt(I)));
          AColors.Add(Pointer(PtrInt(Def)));
          Inc(Col, I);
        end
        else
          Inc(Col);
      end;
      Inc(P, CL);
    end;
    Exit;
  end;
  if H.CurrentLines <> TextBuffer then H.CurrentLines := TextBuffer;
  H.StartAtLineIndex(ALineIndex);
  while not H.GetEol do
  begin
    H.GetTokenEx(TS, TL);
    SetString(Tok, TS, TL);
    C := clNone;
    with H.GetTokenAttribute do
      if True then C := Foreground;
    if (C = clNone) or (C = clDefault) then C := Def;
    StartCol := Col;
    HasInk := False;
    P := 1;
    while P <= Length(Tok) do
    begin
      CL := UTF8CodepointSize(@Tok[P]);
      if CL < 1 then CL := 1;
      if Tok[P] = #9 then
        Col := (Col div ATabSize + 1) * ATabSize
      else
      begin
        if Tok[P] <> ' ' then HasInk := True;
        if CL >= 3 then Inc(Col, 2) else Inc(Col);   { 全角の文字は 2 桁 }
      end;
      Inc(P, CL);
    end;
    if HasInk and (Trim(Tok) <> '') then
    begin
      { 字句の中の空白を飛ばし、空白でない所だけを塗る }
      Col := StartCol;
      P := 1;
      while P <= Length(Tok) do
      begin
        CL := UTF8CodepointSize(@Tok[P]);
        if CL < 1 then CL := 1;
        if Tok[P] = #9 then
          Col := (Col div ATabSize + 1) * ATabSize
        else
        begin
          if CL >= 3 then I := 2 else I := 1;
          if Tok[P] <> ' ' then
          begin
            ACols.Add(Pointer(PtrInt(Col)));
            ACols.Add(Pointer(PtrInt(I)));
            AColors.Add(Pointer(PtrInt(C)));
          end;
          Inc(Col, I);
        end;
        Inc(P, CL);
      end;
    end;
    H.Next;
  end;
end;

{ ================================================================== }
{ TCsPage（3.3）                                                       }
{ ================================================================== }

constructor TCsPage.Create(AOwner: TCsEditor);
begin
  inherited Create;
  FOwner := AOwner;
  FEncoding := ceUTF8;
  FLineBreak := #13#10;
  FEmpty := TStringList.Create;
end;

destructor TCsPage.Destroy;
begin
  FEmpty.Free;
  inherited Destroy;
end;

function TCsPage.GetIndex: Integer;
begin
  if FSyn = nil then Exit(-1);
  Result := FOwner.FPages.IndexOf(Self);
end;

function TCsPage.GetCaption: string;
begin
  if FSyn = nil then Exit('');
  if FFileName = '' then Result := CXT(sUntitled) else Result := ExtractFileName(FFileName);
end;

function TCsPage.GetFileName: string;
begin
  if FSyn = nil then Result := '' else Result := FFileName;
end;

function TCsPage.GetModified: Boolean;
begin
  Result := (FSyn <> nil) and FSyn.Modified;
end;

function TCsPage.GetEncoding: TCMEncoding;
begin
  if FSyn = nil then Result := ceUTF8 else Result := FEncoding;
end;

procedure TCsPage.SetEncoding(AValue: TCMEncoding);
begin
  if FSyn <> nil then FEncoding := AValue;
end;

function TCsPage.GetLanguage: string;
begin
  if FSyn = nil then Result := '' else Result := FLanguage;
end;

procedure TCsPage.SetLanguage(const AValue: string);
begin
  if FSyn <> nil then FOwner.PageSetLanguage(Self, AValue, True);
end;

{ 本文：各行を、そのタブの改行コードでつなぐ（最後の行の後ろには付けない。4.2） }
function TCsPage.GetText: string;
var
  I: Integer;
  L: TStrings;
begin
  Result := '';
  if FSyn = nil then Exit;
  L := FSyn.Lines;
  for I := 0 to L.Count - 1 do
  begin
    if I > 0 then Result := Result + FLineBreak;
    Result := Result + L[I];
  end;
end;

procedure TCsPage.SetText(const AValue: string);
begin
  if FSyn <> nil then FOwner.PageSetText(Self, AValue);
end;

function TCsPage.GetLines: TStrings;
begin
  if FSyn = nil then Result := FEmpty else Result := FSyn.Lines;
end;

function TCsPage.GetLineCount: Integer;
begin
  if FSyn = nil then Result := 0 else Result := LineTotal(FSyn);
end;

function TCsPage.GetSynEdit: TCSynEdit;
begin
  Result := FSyn;
end;

procedure TCsPage.Clear;
begin
  if FSyn <> nil then FOwner.PageClear(Self);
end;

function TCsPage.LoadFromFile(const AFileName: string): Boolean;
begin
  Result := (FSyn <> nil) and FOwner.PageLoad(Self, AFileName);
end;

function TCsPage.Save: Boolean;
begin
  Result := (FSyn <> nil) and FOwner.PageSave(Self);
end;

function TCsPage.SaveAs(const AFileName: string): Boolean;
begin
  Result := (FSyn <> nil) and FOwner.PageSaveAs(Self, AFileName);
end;

function TCsPage.Close(Force: Boolean): Boolean;
begin
  Result := (FSyn <> nil) and FOwner.PageClose(Self, Force);
end;

{ ================================================================== }
{ TCsMinimap（10章）                                                  }
{ ================================================================== }

constructor TCsMinimap.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  FBmp := TBitmap.Create;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 100;
  FTimer.OnTimer := @TimerTick;
  FOrigin := 1;
end;

destructor TCsMinimap.Destroy;
begin
  FBmp.Free;
  inherited Destroy;
end;

function TCsMinimap.RowH: Integer;
begin
  Result := Max(2, Scale96ToForm(2));
end;

procedure TCsMinimap.TimerTick(Sender: TObject);
begin
  FTimer.Enabled := False;
  Rebuild;
end;

procedure TCsMinimap.ScheduleRebuild;
begin
  if not Visible then Exit;
  FTimer.Enabled := False;
  FTimer.Enabled := True;
end;

{ エディタの見えている範囲（スライダー）の四角 }
function TCsMinimap.SliderRect: TRect;
var
  S: TCsSynEdit;
  T, V: Integer;
begin
  Result := Rect(0, 0, 0, 0);
  if (FEditor = nil) or (FEditor.FCur = nil) then Exit;
  S := FEditor.FCur.FSyn;
  T := S.TopLine;
  V := Max(1, S.LinesInWindow);
  Result := Rect(0, (T - FOrigin) * RowH, ClientWidth, (T - FOrigin + V) * RowH);
end;

procedure TCsMinimap.Rebuild;
var
  S: TCsSynEdit;
  N, M, V, T, R, ColW, Left0, Row, I, X, W: Integer;
  Cols, Colors: TList;
  Bg, Mix: TColor;
  SR: TRect;
  Pct: Integer;

  function Blend(A, B: TColor; APct: Integer): TColor;
  var
    CA, CB: TColor;
  begin
    CA := ColorToRGB(A);
    CB := ColorToRGB(B);
    Result := RGBToColor(
      (Red(CA) * (100 - APct) + Red(CB) * APct) div 100,
      (Green(CA) * (100 - APct) + Green(CB) * APct) div 100,
      (Blue(CA) * (100 - APct) + Blue(CB) * APct) div 100);
  end;

begin
  if (FEditor = nil) or (FEditor.FCur = nil) or not HandleAllocated then
  begin
    Invalidate;
    Exit;
  end;
  S := FEditor.FCur.FSyn;
  FBmp.SetSize(Max(1, ClientWidth), Max(1, ClientHeight));
  Bg := S.Color;
  if Bg = clDefault then Bg := clWindow;
  FBmp.Canvas.Brush.Style := bsSolid;
  FBmp.Canvas.Brush.Color := Bg;
  FBmp.Canvas.FillRect(0, 0, FBmp.Width, FBmp.Height);
  R := RowH;
  ColW := Max(1, Scale96ToForm(1));
  Left0 := Max(1, Scale96ToForm(2));
  N := LineTotal(S);
  M := Max(1, ClientHeight div R);
  V := Max(1, S.LinesInWindow);
  T := S.TopLine;
  { どの行から描くか：行数が入りきらなければ、エディタの位置に比例して決める（10.2） }
  if N <= M then
    FOrigin := 1
  else
  begin
    FOrigin := 1 + Round((T - 1) * (N - M) / Max(1, N - V));
    if FOrigin < 1 then FOrigin := 1;
    if FOrigin > N - M + 1 then FOrigin := N - M + 1;
  end;
  { スライダー（マウスを乗せている間だけ）。背景に #797979 を混ぜた色 }
  if FHover or FDragging then
  begin
    if FDragging then Pct := 50 else Pct := 35;
    Mix := Blend(Bg, TColor($797979), Pct);
    SR := SliderRect;
    FBmp.Canvas.Brush.Color := Mix;
    FBmp.Canvas.FillRect(SR);
  end;
  Cols := TList.Create;
  Colors := TList.Create;
  try
    for Row := 0 to M - 1 do
    begin
      if FOrigin + Row > S.Lines.Count then Break;
      S.ScanLineTokens(FOrigin + Row - 1, Cols, Colors, FEditor.FTabSize);
      for I := 0 to Colors.Count - 1 do
      begin
        X := Left0 + Integer(PtrUInt(Cols[I * 2])) * ColW;
        W := Integer(PtrUInt(Cols[I * 2 + 1])) * ColW;
        if X >= FBmp.Width then Break;            { 幅を越えた文字は描かない }
        FBmp.Canvas.Brush.Color := TColor(PtrUInt(Colors[I]));
        FBmp.Canvas.FillRect(X, Row * R, X + W, Row * R + R - 1);
      end;
    end;
  finally
    Cols.Free;
    Colors.Free;
  end;
  Invalidate;
end;

procedure TCsMinimap.Paint;
begin
  if (FBmp.Width <> ClientWidth) or (FBmp.Height <> ClientHeight) then
  begin
    Canvas.Brush.Color := Color;
    Canvas.FillRect(ClientRect);
  end;
  Canvas.Draw(0, 0, FBmp);
end;

procedure TCsMinimap.Resize;
begin
  inherited Resize;
  if Visible then Rebuild;
end;

procedure TCsMinimap.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  S: TCsSynEdit;
  L: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or (FEditor = nil) or (FEditor.FCur = nil) then Exit;
  S := FEditor.FCur.FSyn;
  if PtInRect(SliderRect, Point(X, Y)) then
  begin
    { スライダーをドラッグする }
    FDragging := True;
    FDragY := Y;
    FDragTop := S.TopLine;
    MouseCapture := True;
    Rebuild;
  end
  else
  begin
    { スライダーの外：その行がエディタの真ん中に来るようにする }
    L := FOrigin + Y div RowH;
    S.TopLine := Max(1, L - S.LinesInWindow div 2);
  end;
end;

procedure TCsMinimap.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  S: TCsSynEdit;
  N, V, M, D: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if not FDragging or (FEditor = nil) or (FEditor.FCur = nil) then Exit;
  S := FEditor.FCur.FSyn;
  N := LineTotal(S);
  V := Max(1, S.LinesInWindow);
  M := Max(1, ClientHeight div RowH);
  if N <= V then Exit;
  { 端から端まで動かすと、文書の端から端まで動く（10.3） }
  D := Round((Y - FDragY) * (N - V) / Max(1, (Min(N, M) - V) * RowH));
  S.TopLine := Max(1, FDragTop + D);
end;

procedure TCsMinimap.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if FDragging then
  begin
    FDragging := False;
    MouseCapture := False;
    Rebuild;
  end;
end;

procedure TCsMinimap.MouseEnter;
begin
  inherited MouseEnter;
  FHover := True;
  Rebuild;
end;

procedure TCsMinimap.MouseLeave;
begin
  inherited MouseLeave;
  FHover := False;
  Rebuild;
end;

function TCsMinimap.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  S: TCsSynEdit;
begin
  Result := True;
  if (FEditor = nil) or (FEditor.FCur = nil) then Exit;
  S := FEditor.FCur.FSyn;
  S.TopLine := Max(1, S.TopLine - Sign(WheelDelta) * Mouse.WheelScrollLines);
end;

{ ================================================================== }
{ TCsFindForm・TCsFindDialog（8.1。CMonacoFindDlg を写した）          }
{ ================================================================== }

constructor TCsFindForm.CreateFor(ADlg: TCsFindDialog);
begin
  inherited CreateNew(ADlg);
  FDlg := ADlg;
  Caption := CXT(sFindTitle);
  BorderStyle := bsDialog;
  ClientWidth := 470;
  ClientHeight := 190;
  Position := poDesigned;

  AddLabel(CXT(sFindLblFind), 12, 16);
  FCmbFind := TComboBox.Create(Self);
  FCmbFind.Parent := Self;
  FCmbFind.SetBounds(80, 12, 250, 24);

  AddLabel(CXT(sFindLblRepl), 12, 52);
  FCmbReplace := TComboBox.Create(Self);
  FCmbReplace.Parent := Self;
  FCmbReplace.SetBounds(80, 48, 250, 24);

  FChkCase := AddCheck(CXT(sFindChkCase), 88);
  FChkWord := AddCheck(CXT(sFindChkWord), 112);
  FChkLoop := AddCheck(CXT(sFindChkLoop), 136);
  SetOptions(FDlg.Options);

  AddButton(CXT(sActFindNextCap), 10, @NextClick).Default := True;
  AddButton(CXT(sFindBtnPrev), 42, @PrevClick);
  AddButton(CXT(sFindBtnReplace), 74, @ReplaceClick);
  AddButton(CXT(sFindBtnReplaceAll), 106, @ReplaceAllClick);
  AddButton(CXT(sFindBtnClose), 146, @CloseClick).Cancel := True;

  FLblStatus := AddLabel('', 80, 166);
end;

function TCsFindForm.AddLabel(const ACaption: string; X, Y: Integer): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := Self;
  Result.Caption := ACaption;
  Result.SetBounds(X, Y, 60, 16);
  Result.AutoSize := True;
end;

function TCsFindForm.AddButton(const ACaption: string; Y: Integer; AClick: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := Self;
  Result.Caption := ACaption;
  Result.SetBounds(345, Y, 115, 28);
  Result.OnClick := AClick;
end;

function TCsFindForm.AddCheck(const ACaption: string; Y: Integer): TCheckBox;
begin
  Result := TCheckBox.Create(Self);
  Result.Parent := Self;
  Result.Caption := ACaption;
  Result.SetBounds(80, Y, 250, 20);
end;

function TCsFindForm.GetOptions: TCMFindOptions;
begin
  Result := [];
  if FChkCase.Checked then Include(Result, foMatchCase);
  if FChkWord.Checked then Include(Result, foWholeWord);
  if FChkLoop.Checked then Include(Result, foLoop);
end;

procedure TCsFindForm.SetOptions(AValue: TCMFindOptions);
begin
  FChkCase.Checked := foMatchCase in AValue;
  FChkWord.Checked := foWholeWord in AValue;
  FChkLoop.Checked := foLoop in AValue;
end;

procedure TCsFindForm.RefreshHistory;
var
  F, R: string;
begin
  F := FCmbFind.Text;
  R := FCmbReplace.Text;
  FCmbFind.Items.Assign(FDlg.FindHistory);
  FCmbReplace.Items.Assign(FDlg.ReplaceHistory);
  FCmbFind.Text := F;
  FCmbReplace.Text := R;
end;

function TCsFindForm.Prepare: Boolean;
begin
  Result := (FDlg.Target <> nil) and (FCmbFind.Text <> '');
  if not Result then Exit;
  { 検索語・置換語・オプションは、ダイアログ側で覚える（全エディタで共通） }
  FDlg.FSearchText := FCmbFind.Text;
  FDlg.FReplaceText := FCmbReplace.Text;
  FDlg.FOptions := GetOptions;
  FDlg.AddHistory(FDlg.FindHistory, FCmbFind.Text);
  if FCmbReplace.Text <> '' then FDlg.AddHistory(FDlg.ReplaceHistory, FCmbReplace.Text);
  RefreshHistory;
  FLblStatus.Caption := '';
end;

procedure TCsFindForm.NextClick(Sender: TObject);
begin
  if Prepare then FDlg.Target.Find(FDlg.SearchText, FDlg.Options, True);
end;

procedure TCsFindForm.PrevClick(Sender: TObject);
begin
  if Prepare then FDlg.Target.Find(FDlg.SearchText, FDlg.Options, False);
end;

procedure TCsFindForm.ReplaceClick(Sender: TObject);
begin
  if Prepare then FDlg.Target.Replace(FDlg.SearchText, FDlg.ReplaceText, FDlg.Options);
end;

procedure TCsFindForm.ReplaceAllClick(Sender: TObject);
begin
  if Prepare then FDlg.Target.ReplaceAll(FDlg.SearchText, FDlg.ReplaceText, FDlg.Options);
end;

procedure TCsFindForm.CloseClick(Sender: TObject);
begin
  Close;
end;

constructor TCsFindDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FFindHistory := TStringList.Create;
  FReplaceHistory := TStringList.Create;
  FOptions := [foLoop];
end;

destructor TCsFindDialog.Destroy;
begin
  SetTarget(nil);
  FFindHistory.Free;
  FReplaceHistory.Free;
  inherited Destroy;
end;

procedure TCsFindDialog.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then Exit;
  if AComponent = FTarget then
  begin
    FTarget := nil;
    if (FForm <> nil) and not (csDestroying in ComponentState) then UpdateCaption;
  end
  else if AComponent = FForm then
    FForm := nil;
end;

function TCsFindDialog.GetForm: TCsFindForm;
begin
  if FForm = nil then
  begin
    FForm := TCsFindForm.CreateFor(Self);
    FForm.FreeNotification(Self);
  end;
  Result := FForm;
end;

procedure TCsFindDialog.SetTarget(AValue: TCsEditor);
begin
  if FTarget = AValue then Exit;
  if FTarget <> nil then FTarget.RemoveFreeNotification(Self);
  FTarget := AValue;
  if FTarget <> nil then FTarget.FreeNotification(Self);
  if FForm <> nil then UpdateCaption;
end;

procedure TCsFindDialog.AddHistory(AList: TStringList; const S: string);
var
  I: Integer;
begin
  if S = '' then Exit;
  I := AList.IndexOf(S);
  if I >= 0 then AList.Delete(I);
  AList.Insert(0, S);
  while AList.Count > MAX_HISTORY do AList.Delete(AList.Count - 1);
end;

procedure TCsFindDialog.UpdateCaption;
var
  S: string;
begin
  if FForm = nil then Exit;
  S := CXT(sFindTitle);
  if (FTarget <> nil) and (FTarget.FCur <> nil) then S := S + ' - ' + FTarget.Caption;
  FForm.Caption := S;
end;

procedure TCsFindDialog.ShowFor(AEditor: TCsEditor; const InitialText: string);
var
  F: TCsFindForm;
  PF: TCustomForm;
begin
  SetTarget(AEditor);
  F := GetForm;
  if InitialText <> '' then
    F.FCmbFind.Text := InitialText
  else if F.FCmbFind.Text = '' then
    F.FCmbFind.Text := FSearchText;
  F.RefreshHistory;
  F.FLblStatus.Caption := '';
  UpdateCaption;
  PF := nil;
  if AEditor <> nil then PF := GetParentForm(AEditor);
  if PF <> nil then
  begin
    F.PopupMode := pmExplicit;
    F.PopupParent := PF;
  end;
  if not F.FShownOnce then
  begin
    { 初回は、エディタのあるフォームの中央。2 回目からは前の位置のまま }
    F.Position := poDesigned;
    if PF <> nil then
    begin
      F.Left := PF.Left + (PF.Width - F.Width) div 2;
      F.Top := PF.Top + (PF.Height - F.Height) div 2;
    end
    else
      F.Position := poScreenCenter;
  end;
  F.Show;
  F.FShownOnce := True;
  if F.FCmbFind.CanFocus then F.FCmbFind.SetFocus;
  F.FCmbFind.SelectAll;
end;

procedure TCsFindDialog.CloseDialog;
begin
  if FForm <> nil then FForm.Close;
end;

function TCsFindDialog.IsShowing: Boolean;
begin
  Result := (FForm <> nil) and FForm.Visible;
end;

procedure TCsFindDialog.NotifyFindDone(AEditor: TCsEditor; Found: Boolean);
begin
  if (FForm = nil) or (AEditor <> FTarget) then Exit;
  if Found then FForm.FLblStatus.Caption := '' else FForm.FLblStatus.Caption := CXT(sFindNotFound);
end;

procedure TCsFindDialog.NotifyReplaceAllDone(AEditor: TCsEditor; Count: Integer);
begin
  if (FForm = nil) or (AEditor <> FTarget) then Exit;
  FForm.FLblStatus.Caption := Format(CXT(sFindReplaced), [Count]);
end;

{ ================================================================== }
{ TCsFormHook（3.4）                                                  }
{ ================================================================== }

function FindHook(AForm: TCustomForm; ACreate: Boolean): TCsFormHook;
var
  I: Integer;
begin
  Result := nil;
  if AForm = nil then Exit;
  for I := 0 to AForm.ComponentCount - 1 do
    if AForm.Components[I] is TCsFormHook then Exit(TCsFormHook(AForm.Components[I]));
  if ACreate and (AForm is TForm) then Result := TCsFormHook.CreateFor(TForm(AForm));
end;

function CsActiveEditor(AForm: TCustomForm): TCsEditor;
var
  H: TCsFormHook;
begin
  Result := nil;
  H := FindHook(AForm, False);
  if H <> nil then Result := H.ActiveEditor;
end;

constructor TCsFormHook.CreateFor(AForm: TForm);
begin
  inherited Create(AForm);
  FForm := AForm;
  FEditors := TFPList.Create;
  FOldCloseQuery := FForm.OnCloseQuery;
  FForm.OnCloseQuery := @FormCloseQuery;
end;

destructor TCsFormHook.Destroy;
var
  M: TCloseQueryEvent;
begin
  if (FForm <> nil) and not (csDestroying in FForm.ComponentState) then
  begin
    M := FForm.OnCloseQuery;
    if TMethod(M).Data = Pointer(Self) then FForm.OnCloseQuery := FOldCloseQuery;
  end;
  FreeAndNil(FEditors);
  inherited Destroy;
end;

procedure TCsFormHook.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then Exit;
  if AComponent is TCsEditor then
  begin
    if FEditors <> nil then FEditors.Remove(AComponent);
    if AComponent = FActive then FActive := nil;
  end
  else if AComponent = FFindDialog then
    FFindDialog := nil;
end;

procedure TCsFormHook.AddEditor(AEditor: TCsEditor);
begin
  if FEditors.IndexOf(AEditor) >= 0 then Exit;
  FEditors.Add(AEditor);
  AEditor.FreeNotification(Self);
end;

procedure TCsFormHook.RemoveEditor(AEditor: TCsEditor);
begin
  if FEditors <> nil then FEditors.Remove(AEditor);
  if FActive = AEditor then FActive := nil;
  AEditor.RemoveFreeNotification(Self);
end;

procedure TCsFormHook.SetActive(AEditor: TCsEditor);
begin
  FActive := AEditor;
end;

function TCsFormHook.ActiveEditor: TCsEditor;
begin
  Result := FActive;
  if (Result = nil) and (FEditors.Count > 0) then Result := TCsEditor(FEditors[0]);
end;

function TCsFormHook.SharedFindDialog: TCsFindDialog;
begin
  if FFindDialog = nil then
  begin
    FFindDialog := TCsFindDialog.Create(Self);
    FFindDialog.FreeNotification(Self);
  end;
  Result := FFindDialog;
end;

procedure TCsFormHook.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  I: Integer;
begin
  if Assigned(FOldCloseQuery) then FOldCloseQuery(Sender, CanClose);
  if not CanClose then Exit;
  { 1 つでもキャンセルされたら、その時点で中止（残りは聞かない） }
  for I := 0 to FEditors.Count - 1 do
    if not TCsEditor(FEditors[I]).CanCloseAll then
    begin
      CanClose := False;
      Exit;
    end;
end;

{ ================================================================== }
{ TCsEditor：作る・壊す（3.1）                                        }
{ ================================================================== }

constructor TCsEditor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csSetCaption, csAcceptsControls];
  SetTextBuf('');
  BevelOuter := bvNone;
  BevelInner := bvNone;
  Width := 500;
  Height := 300;
  TabStop := True;
  ParentColor := False;
  ParentFont := False;

  FMultiDocument := True;
  FConfirmOnFormClose := True;
  FTabTearOff := True;
  FTabFlat := True;
  FTabSeparator := False;
  FTabIcons := True;
  FWordWrap := True;
  FLineNumbers := False;
  FTabSize := 4;
  FFolding := True;
  FMatchBrackets := True;
  FOccurrencesHighlight := True;
  FMinimapOn := False;
  FTheme := ctAuto;
  FDefaultLanguage := 'pascal';
  FAutoLanguage := True;
  FOpenDroppedFiles := True;
  FQuotePrefix := '> ';
  FHitColorLight := DefHitColorLight;
  FHitColorDark := DefHitColorDark;
  FCursorLineColorLight := DefCursorLineColorLight;
  FCursorLineColorDark := DefCursorLineColorDark;
  FSelectionColorStyle := scStandard;
  FSelectionColorLight := SelStyleLight[scStandard];
  FSelectionColorDark := SelStyleDark[scStandard];
  FLineDelimiters := ' ' + '　' + #9 + ',' + '、';   { 半角空白・全角空白・タブ・カンマ・読点 }
  FLineSkipEmpty := True;
  FLineQuoteChar := '"';
  FSearchOptions := [foLoop];
  FLastCurLine := -1;
  FLastCurCol := -1;

  Font.Name := 'BIZ UDGothic';
  Font.Size := 14;
  Font.Quality := fqCleartypeNatural;

  FPages := TList.Create;
  FAllPages := TList.Create;
  FErrQueue := TStringList.Create;
  FDropFiles := TStringList.Create;
  FLineWords := TStringList.Create;
  FTearOffHead := TStringList.Create;
  FMergeQueue := TStringList.Create;
  FDesignLines := TStringList.Create;

  { 設計時（IDE の上）は中の部品を作らない。Paint で枠と部品の名前を描く }
  if csDesigning in ComponentState then Exit;

  ReadOsTheme;
  FSysImages := TImageList.Create(Self);
  FSysImages.Width := 16;
  FSysImages.Height := 16;
  FSysIconExts := TStringList.Create;
  FSysIconExts.Sorted := True;

  FTabs := TATTabs.Create(Self);
  FTabs.Parent := Self;
  FTabs.Align := alTop;
  FTabs.OptShowPlusTab := True;
  FTabs.OptShowFlatMouseOver := True;
  FTabs.OptShowEntireColor := True;
  FTabs.OptMouseDragOutEnabled := False;   { ほかの ATTabs へタブだけを移す機能は止める（4.11・4.12 で行う） }
  FTabs.TabStop := False;
  FTabs.ParentFont := False;              { タブの文字は Font・FontSize に合わせない（大きくするとはみ出すため。4.6） }
  FTabs.OnTabClick := @TabClick;
  FTabs.OnTabPlusClick := @TabPlusClick;
  FTabs.OnTabClose := @TabClose;
  FTabs.OnTabDropQuery := @TabDropQuery;
  FTabs.OnTabMove := @TabMove;
  FTabs.OnMouseUp := @TabsMouseUp;
  FTabs.OnEndDrag := @TabsEndDrag;

  FMinimap := TCsMinimap.Create(Self);
  FMinimap.FEditor := Self;
  FMinimap.Visible := False;
  FMinimap.Parent := Self;
  FMinimap.Align := alRight;
  FMinimap.Width := 120;

  { 10.5：ミニマップを出している間だけ、一番右に置く縦のスクロールバー }
  FVBar := TScrollBar.Create(Self);
  FVBar.Kind := sbVertical;
  FVBar.TabStop := False;
  FVBar.Visible := False;
  FVBar.Parent := Self;
  FVBar.Align := alRight;
  FVBar.OnChange := @VBarChange;

  BuildMenu;
  ApplyTabShape;
  ApplyTabIcons;

  { 起動直後に 1 枚、空の無題のタブを作る（4.1） }
  SetCurPage(NewPageObj);
  RebuildTabs;
  ApplyTheme;
end;

destructor TCsEditor.Destroy;
var
  I: Integer;
  P: TCsPage;
begin
  Application.RemoveAsyncCalls(Self);
  if FHook <> nil then FHook.RemoveEditor(Self);
  if GEditors <> nil then GEditors.Remove(Self);
  if FPreview <> nil then
  begin
    FPreview.SourceRemoved(Self);
    FPreview.RemoveFreeNotification(Self);
    FPreview := nil;
  end;
  FCur := nil;
  { 中の部品からの知らせを止めてから、ページを解放する（中の部品はこのあと inherited で壊れる） }
  if FAllPages <> nil then
  begin
    for I := 0 to FAllPages.Count - 1 do
    begin
      P := TCsPage(FAllPages[I]);
      if P.FSyn <> nil then
      begin
        P.FSyn.OnChange := nil;
        P.FSyn.OnChangeUpdating := nil;
        P.FSyn.OnStatusChange := nil;
        P.FSyn.FEditor := nil;
        P.FSyn.FPage := nil;
      end;
      P.Free;
    end;
  end;
  if FMinimap <> nil then FMinimap.FEditor := nil;
  FreeAndNil(FAllPages);
  FreeAndNil(FPages);
  FreeAndNil(FErrQueue);
  FreeAndNil(FDropFiles);
  FreeAndNil(FLineWords);
  FreeAndNil(FTearOffHead);
  FreeAndNil(FMergeQueue);
  FreeAndNil(FDesignLines);
  FreeAndNil(FSysIconExts);
  inherited Destroy;
end;

procedure TCsEditor.Loaded;
begin
  inherited Loaded;
  if csDesigning in ComponentState then Exit;
  { .lfm の設定をまとめて全タブに渡す。設計時の Lines は 1 枚目に入っている（4.2） }
  ApplyAllOptions;
  if FCur <> nil then
  begin
    FCur.FSyn.ClearUndo;
    FCur.FSyn.Modified := False;
    CheckModified(FCur);
  end;
  if (FPreview <> nil) and FAllowRemoteImages then FPreview.AllowRemoteImages := True;
  if (FPreview <> nil) and FShowPreview then FPreview.Visible := True;
  { 分離で起動されたなら、ここで受け取り、フォームを落とした位置に出す（4.11） }
  if TryClaimTearOff then MoveFormToTearOff;
end;

procedure TCsEditor.CreateWnd;
begin
  inherited CreateWnd;
  if csDesigning in ComponentState then Exit;
  if FTabs <> nil then FTabs.Visible := FMultiDocument;
  RegisterWithForm;
  if (GEditors <> nil) and (GEditors.IndexOf(Self) < 0) then GEditors.Add(Self);
  EnsureReceiver;
  if not FReadyDone then
  begin
    FReadyDone := True;
    Application.QueueAsyncCall(@AsyncReady, 0);
  end;
end;

procedure TCsEditor.AsyncReady(Data: PtrInt);
begin
  { コードで作ったエディタは Loaded を通らないので、ここで分離を受け取る }
  if not FTearOffPending and TryClaimTearOff then MoveFormToTearOff;
  if FTearOffPending then ApplyTearOff;
  if Assigned(FOnReady) then FOnReady(Self);
  if (FPreview <> nil) and (FPreview.Source = nil) then FPreview.SetSource(Self);
end;

procedure TCsEditor.Paint;
begin
  inherited Paint;
  if not (csDesigning in ComponentState) then Exit;
  Canvas.Pen.Color := clGrayText;
  Canvas.Pen.Style := psDash;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(0, 0, Width, Height);
  Canvas.Font.Color := clGrayText;
  Canvas.TextOut(8, 8, Name + ' : TCsEditor');
end;

procedure TCsEditor.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then Exit;
  if AComponent = FOpenDialog then FOpenDialog := nil
  else if AComponent = FSaveDialog then FSaveDialog := nil
  else if AComponent = FFindDialog then FFindDialog := nil
  else if AComponent = FPreview then FPreview := nil
  else if AComponent = FTabImages then
  begin
    FTabImages := nil;
    if not (csDestroying in ComponentState) then ApplyTabIcons;
  end
  else if AComponent = FHook then FHook := nil;
end;

procedure TCsEditor.RegisterWithForm;
var
  F: TCustomForm;
begin
  if FHook <> nil then Exit;
  F := GetParentForm(Self);
  FHook := FindHook(F, True);
  if FHook = nil then Exit;
  FHook.AddEditor(Self);
  FHook.FreeNotification(Self);
end;

procedure TCsEditor.SetFocus;
begin
  { 今の処理（ボタンのクリック・タブのクリックなど）が終わってから移す（TCMonacoEditor と同じ） }
  if FFocusPending then Exit;
  FFocusPending := True;
  Application.QueueAsyncCall(@AsyncSetFocus, 0);
end;

procedure TCsEditor.AsyncSetFocus(Data: PtrInt);
begin
  FFocusPending := False;
  if not CanFocus then Exit;                     { 見えない・使えないなら何もしない }
  if (FCur <> nil) and FCur.FSyn.CanFocus then FCur.FSyn.SetFocus else inherited SetFocus;
end;

procedure TCsEditor.FocusLater;
begin
  Application.QueueAsyncCall(@AsyncFocus, 0);
end;

procedure TCsEditor.AsyncFocus(Data: PtrInt);
begin
  if (FCur <> nil) and FCur.FSyn.CanFocus then FCur.FSyn.SetFocus;
end;

{ ================================================================== }
{ ページとタブ（4.1・4.6）                                            }
{ ================================================================== }

{ 新しいタブを作る（右端に足す。見えるタブにはしない。イベントは出さない） }
function TCsEditor.NewPageObj: TCsPage;
var
  S: TCsSynEdit;
begin
  Result := TCsPage.Create(Self);
  FAllPages.Add(Result);
  S := TCsSynEdit.Create(Self);
  S.FEditor := Self;
  S.FPage := Result;
  Result.FSyn := S;
  S.Visible := False;
  S.Parent := Self;
  S.Align := alClient;
  S.BorderStyle := bsNone;
  S.PopupMenu := FMenu;
  Result.FEncoding := ceUTF8;
  Result.FLineBreak := #13#10;
  Result.FFileName := '';
  ApplyOptionsTo(S, True);
  PageSetLanguage(Result, FDefaultLanguage, False);
  S.OnChange := @InnerChange;
  S.OnChangeUpdating := @InnerUpdating;
  S.OnStatusChange := @InnerStatus;
  FPages.Add(Result);
end;

{ 見えるタブを P にする（4.1 の ActiveIndex） }
{ 5.2：フォントを渡すが、文字色は配色（4.7）のまま残す }
procedure AssignFontKeepColor(S: TCsSynEdit; AFont: TFont);
var
  C: TColor;
begin
  C := S.Font.Color;
  S.Font.Assign(AFont);
  S.Font.Color := C;
end;

procedure TCsEditor.SetCurPage(P: TCsPage);
var
  Old: TCsPage;
  HadFocus: Boolean;
begin
  if (P = nil) or (P = FCur) then Exit;
  Old := FCur;
  FCur := P;
  { 4.1：前の本文にフォーカスがあれば、新しい本文へ移してから前を隠す（Ctrl+Tab を続けて押せるように） }
  HadFocus := (Old <> nil) and (Old.FSyn <> nil) and Old.FSyn.Focused;
  P.FSyn.Visible := True;
  if HadFocus and P.FSyn.CanFocus then P.FSyn.SetFocus;
  if (Old <> nil) and (Old.FSyn <> nil) then Old.FSyn.Visible := False;
  if (FTabs <> nil) and not FUpdatingTabs then
  begin
    FUpdatingTabs := True;
    try
      FTabs.TabIndex := FPages.IndexOf(P);
    finally
      FUpdatingTabs := False;
    end;
  end;
  FLastCurLine := -1;
  FLastCurCol := -1;
  if (FMinimap <> nil) and FMinimap.Visible then FMinimap.Rebuild;
  UpdateVBar;
  if CurrentFindDialog(False) <> nil then CurrentFindDialog(False).UpdateCaption;
  if FPreview <> nil then FPreview.SourceSwitched(Self);
  if Old <> nil then
    if Assigned(FOnActiveChange) then FOnActiveChange(Self);
end;

{ タブを外す（中の部品は壊さない）。見えていたタブなら隣を見えるタブにし、0 枚になったら空の無題を作る }
procedure TCsEditor.RemovePage(P: TCsPage);
var
  I: Integer;
  Next: TCsPage;
  HadFocus: Boolean;
begin
  I := FPages.IndexOf(P);
  if I < 0 then Exit;
  HadFocus := (P = FCur) and (P.FSyn <> nil) and P.FSyn.Focused;
  FPages.Delete(I);
  if FPages.Count = 0 then NewPageObj;
  Next := nil;
  if P = FCur then
  begin
    if I < FPages.Count then Next := TCsPage(FPages[I]) else Next := TCsPage(FPages[FPages.Count - 1]);
    FCur := nil;
  end;
  RebuildTabs;
  DoDocListChange;
  if Next <> nil then
  begin
    { 前の見えるタブは外れているので、新しいタブを出して知らせる }
    FCur := Next;
    Next.FSyn.Visible := True;
    if HadFocus and Next.FSyn.CanFocus then Next.FSyn.SetFocus;
    if FTabs <> nil then
    begin
      FUpdatingTabs := True;
      try
        FTabs.TabIndex := FPages.IndexOf(Next);
      finally
        FUpdatingTabs := False;
      end;
    end;
    FLastCurLine := -1;
    if (FMinimap <> nil) and FMinimap.Visible then FMinimap.Rebuild;
    UpdateVBar;
    if CurrentFindDialog(False) <> nil then CurrentFindDialog(False).UpdateCaption;
    if FPreview <> nil then FPreview.SourceSwitched(Self);
    if Assigned(FOnActiveChange) then FOnActiveChange(Self);
  end;
end;

function TCsEditor.TabCaptionFor(P: TCsPage): string;
begin
  Result := P.Caption;
  if P.Modified then Result := Result + ' *';
end;

function TCsEditor.ImageIndexFor(P: TCsPage): Integer;
begin
  Result := -1;
  if not FTabIcons or (FSysIconExts = nil) or (csDestroying in ComponentState) then Exit;
  if FTabImages <> nil then
  begin
    Result := 0;
    if Assigned(FOnGetTabImageIndex) then FOnGetTabImageIndex(Self, FPages.IndexOf(P), P.FFileName, Result);
  end
  else
    Result := SystemIconIndex(P.FFileName);
end;

{ 拡張子から、エクスプローラーと同じアイコンを取り出す（同じ拡張子は 1 回。無題は .txt） }
function TCsEditor.SystemIconIndex(const AFileName: string): Integer;
var
  Ext: string;
  Info: TSHFileInfoW;
  Ico: TIcon;
  I: Integer;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  if Ext = '' then Ext := '.txt';
  I := FSysIconExts.IndexOf(Ext);
  if I >= 0 then Exit(PtrInt(FSysIconExts.Objects[I]));
  Result := -1;
  FillChar(Info, SizeOf(Info), 0);
  if (SHGetFileInfoW(PWideChar(UnicodeString('x' + Ext)), FILE_ATTRIBUTE_NORMAL, Info, SizeOf(Info),
      SHGFI_ICON or SHGFI_SMALLICON or SHGFI_USEFILEATTRIBUTES) <> 0) and (Info.hIcon <> 0) then
  begin
    Ico := TIcon.Create;
    try
      Ico.Handle := Info.hIcon;
      Result := FSysImages.AddIcon(Ico);
    finally
      Ico.Free;
    end;
  end;
  FSysIconExts.AddObject(Ext, TObject(PtrInt(Result)));
end;

procedure TCsEditor.RebuildTabs;
var
  I: Integer;
  P: TCsPage;
  D: TATTabData;
begin
  if FTabs = nil then Exit;
  FUpdatingTabs := True;
  try
    FTabs.Clear;
    for I := 0 to FPages.Count - 1 do
    begin
      P := TCsPage(FPages[I]);
      D := FTabs.AddTab(-1, TabCaptionFor(P), P, P.Modified);
      D.TabHint := P.FFileName;
      D.TabImageIndex := ImageIndexFor(P);
    end;
    ApplyTabColors;
    if FCur <> nil then FTabs.TabIndex := FPages.IndexOf(FCur);
  finally
    FUpdatingTabs := False;
  end;
  FTabs.Invalidate;
end;

procedure TCsEditor.UpdateTab(P: TCsPage);
var
  I: Integer;
  D: TATTabData;
begin
  if FTabs = nil then Exit;
  I := FPages.IndexOf(P);
  if (I < 0) or (I >= FTabs.TabCount) then Exit;
  D := FTabs.GetTabData(I);
  if D = nil then Exit;
  D.TabCaption := TabCaptionFor(P);
  D.TabModified := P.Modified;
  D.TabHint := P.FFileName;
  D.TabImageIndex := ImageIndexFor(P);
  FTabs.Invalidate;
end;

procedure TCsEditor.ApplyTabShape;
begin
  if FTabs = nil then Exit;
  FTabs.OptShowFlat := FTabFlat;
  FTabs.OptShowFlatSepar := FTabSeparator;
  FTabs.Invalidate;
end;

procedure TCsEditor.ApplyTabIcons;
begin
  if FTabs = nil then Exit;
  if not FTabIcons then FTabs.Images := nil
  else if FTabImages <> nil then FTabs.Images := FTabImages
  else FTabs.Images := FSysImages;
  RebuildTabs;
end;

{ タブ・背景の色（TCMonacoEditor の ApplyThemeColors と同じ値） }
procedure TCsEditor.ApplyTabColors;
var
  CBar, COver, CActive, CFont, CFontActive, CLine: TColor;
  I: Integer;
  D: TATTabData;
begin
  if IsDarkTheme then
  begin
    CBar := TColor($2B2B2B); COver := TColor($383838); CActive := TColor($1E1E1E);
    CFont := TColor($C5C5C5); CFontActive := TColor($FFFFFF); CLine := TColor($3A3A3A);
  end
  else
  begin
    CBar := TColor($F0F0F0); COver := TColor($E5E5E5); CActive := TColor($FFFFFF);
    CFont := TColor($5C5C5C); CFontActive := TColor($000000); CLine := TColor($D9D9D9);
  end;
  Color := CActive;
  if FTabs = nil then Exit;
  FTabs.ColorBg := CBar;
  FTabs.ColorTabPassive := CBar;
  FTabs.ColorTabOver := COver;
  FTabs.ColorTabActive := CActive;
  FTabs.ColorFont := CFont;
  FTabs.ColorFontModified := CFont;
  FTabs.ColorFontActive := CFontActive;
  FTabs.ColorFontHot := CFontActive;
  FTabs.ColorBorderActive := CLine;
  FTabs.ColorBorderPassive := CLine;
  FTabs.ColorSeparator := CLine;
  FTabs.ColorArrow := CFont;
  FTabs.ColorArrowOver := CFontActive;
  FTabs.ColorCloseX := CFont;
  FTabs.ColorCloseXOver := CFontActive;
  FTabs.ColorCloseBg := CBar;
  FTabs.ColorCloseBgOver := COver;
  FTabs.ColorCloseBorderOver := COver;
  FTabs.ColorActiveMark := CActive;       { アクセントの線は出さない（背景と同じ色） }
  for I := 0 to FTabs.TabCount - 1 do
  begin
    D := FTabs.GetTabData(I);
    if D = nil then Continue;
    D.TabColorActive := CActive;
    D.TabColorOver := COver;
  end;
  FTabs.Invalidate;
end;

procedure TCsEditor.TabClick(Sender: TObject);
begin
  if FUpdatingTabs then Exit;
  if (FTabs.TabIndex >= 0) and (FTabs.TabIndex < FPages.Count) then
    SetCurPage(TCsPage(FPages[FTabs.TabIndex]));
  FFocusOnMouseUp := True;     { ボタンを離したあと（TabsMouseUp）で本文にフォーカス }
end;

procedure TCsEditor.TabsMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if FFocusOnMouseUp then
  begin
    FFocusOnMouseUp := False;
    FocusLater;
  end;
end;

procedure TCsEditor.TabPlusClick(Sender: TObject);
begin
  NewPage;
  FFocusOnMouseUp := True;
end;

procedure TCsEditor.TabClose(Sender: TObject; ATabIndex: Integer; var ACanClose, ACanContinue: Boolean);
begin
  { ATTabs の処理の途中で閉じないよう、あとで閉じる（確認のダイアログもその外で出す） }
  ACanClose := False;
  ACanContinue := False;
  if (ATabIndex >= 0) and (ATabIndex < FPages.Count) then
    Application.QueueAsyncCall(@AsyncTabClose, PtrInt(FPages[ATabIndex]));
end;

procedure TCsEditor.AsyncTabClose(Data: PtrInt);
var
  P: TCsPage;
begin
  P := TCsPage(Data);
  if FPages.IndexOf(P) < 0 then Exit;
  if P.Close then FocusLater;
end;

procedure TCsEditor.TabDropQuery(Sender: TObject; AIndexFrom, AIndexTo: Integer; var ACanDrop: Boolean);
begin
  { ドラッグが終わる前に並びを入れ替えておく }
  ACanDrop := True;
  if (AIndexFrom >= 0) and (AIndexTo >= 0) and (AIndexFrom < FPages.Count) and (AIndexTo < FPages.Count) then
    FPages.Move(AIndexFrom, AIndexTo);
  FDropHandled := True;
end;

procedure TCsEditor.TabMove(Sender: TObject; AIndexFrom, AIndexTo: Integer);
begin
  if (AIndexFrom < 0) or (AIndexTo < 0) then Exit;
  if FDropHandled then
  begin
    FDropHandled := False;
    if Assigned(FOnDocListChange) then FOnDocListChange(Self);
    Exit;
  end;
  if (AIndexFrom < FPages.Count) and (AIndexTo < FPages.Count) then FPages.Move(AIndexFrom, AIndexTo);
  if Assigned(FOnDocListChange) then FOnDocListChange(Self);
end;

{ ================================================================== }
{ 本文とファイル（4.2・4.3）                                          }
{ ================================================================== }

{ 本文を入れる。改行で終わっていれば、最後に空の行を 1 つ持つ（4.2） }
procedure TCsEditor.SetBodyText(P: TCsPage; const S: string);
begin
  P.FSyn.Lines.Text := S;
  if (S <> '') and (S[Length(S)] in [#10, #13]) then P.FSyn.Lines.Add('');
end;

procedure TCsEditor.PageSetText(P: TCsPage; const AValue: string);
begin
  if P.GetText = AValue then Exit;              { 同じなら何もしない }
  Inc(FSuppressChange);
  try
    SetBodyText(P, AValue);
    P.FSyn.ClearUndo;
    P.FSyn.Modified := True;
  finally
    Dec(FSuppressChange);
  end;
  CheckModified(P);
  InnerChange(P.FSyn);                           { 本文が変わった知らせは 1 回 }
end;

procedure TCsEditor.PageSetLanguage(P: TCsPage; const AValue: string; AFire: Boolean);
var
  V: string;
begin
  V := AValue;
  if V = '' then V := FDefaultLanguage;
  P.FLanguage := V;
  P.FSyn.Language := V;                          { TCSynEdit 1.1：色分けを替えて配色を当て直す（ApplyEditStyle） }
  if AFire then DocChanged(P);
end;

{ 読み込んだ本文をページに入れる（4.3） }
procedure TCsEditor.LoadCore(P: TCsPage; const AFileName, ABody: string; AEnc: TCMEncoding);
var
  I: Integer;
begin
  { 改行コード：最初に見つかった改行が #13#10 なら #13#10、#10 なら #10、無ければ #13#10 }
  P.FLineBreak := #13#10;
  I := Pos(#10, ABody);
  if (I > 0) and ((I = 1) or (ABody[I - 1] <> #13)) then P.FLineBreak := #10;
  Inc(FSuppressChange);
  try
    SetBodyText(P, ABody);
    P.FFileName := AFileName;
    P.FEncoding := AEnc;
    if FAutoLanguage then PageSetLanguage(P, CSLanguageForFile(AFileName, FDefaultLanguage), False);
    P.FSyn.ClearUndo;
    P.FSyn.Modified := False;
    P.FSyn.MarkTextAsSaved;
    P.FSyn.LogicalCaretXY := Point(1, 1);
    P.FSyn.BlockBegin := Point(1, 1);
    P.FSyn.TopLine := 1;
  finally
    Dec(FSuppressChange);
  end;
  CheckModified(P);
  UpdateTab(P);
  DocChanged(P);
  if P = FCur then InnerChange(P.FSyn);
end;

{ 書く（4.3）。書けたら ' *' を消し、OnSave }
function TCsEditor.WriteCore(P: TCsPage; const AFileName: string): Boolean;
var
  B: TBytes;
  FS: TFileStream;
  OldExt: string;
begin
  Result := False;
  try
    B := EncodeText(P.GetText, P.FEncoding);
    FS := TFileStream.Create(AFileName, fmCreate);
    try
      if Length(B) > 0 then FS.WriteBuffer(B[0], Length(B));
    finally
      FS.Free;
    end;
  except
    on E: Exception do
    begin
      DoError(AFileName + ': ' + E.Message);       { ' *' は残る }
      Exit;
    end;
  end;
  OldExt := LowerCase(ExtractFileExt(P.FFileName));
  P.FFileName := AFileName;
  if FAutoLanguage and ((OldExt <> LowerCase(ExtractFileExt(AFileName))) or (OldExt = '')) then
    PageSetLanguage(P, CSLanguageForFile(AFileName, FDefaultLanguage), False);
  P.FSyn.Modified := False;
  P.FSyn.MarkTextAsSaved;
  CheckModified(P);
  if Assigned(FOnSave) then FOnSave(Self, AFileName);
  UpdateTab(P);
  DocChanged(P);
  Result := True;
end;

{ 同じファイルを、このエディタの別のタブ・同じフォームの別の TCsEditor で開いているか（4.12） }
function TCsEditor.OpenedElsewhere(P: TCsPage; const AFileName: string): Boolean;
var
  I: Integer;
  E: TCsEditor;
begin
  I := FindPage(AFileName);
  if (I >= 0) and (TCsPage(FPages[I]) <> P) then Exit(True);
  Result := FindInOtherEditors(AFileName, E) >= 0;
end;

{ 同じフォームの別の TCsEditor で開いていれば、その番号（AEditor にそのエディタ）。無ければ -1 }
function TCsEditor.FindInOtherEditors(const AFileName: string; out AEditor: TCsEditor): Integer;
var
  I: Integer;
  E: TCsEditor;
begin
  Result := -1;
  AEditor := nil;
  if FHook = nil then Exit;
  for I := 0 to FHook.FEditors.Count - 1 do
  begin
    E := TCsEditor(FHook.FEditors[I]);
    if E = Self then Continue;
    Result := E.FindPage(AFileName);
    if Result >= 0 then
    begin
      AEditor := E;
      Exit;
    end;
  end;
end;

function TCsEditor.PageLoad(P: TCsPage; const AFileName: string): Boolean;
var
  N, S: string;
  Enc: TCMEncoding;
begin
  Result := False;
  if P.FSyn = nil then Exit;
  N := ExpandFileName(AFileName);
  if not FileExists(N) then
  begin
    DoError(CXT(sErrFileNotFound) + N);
    Exit;
  end;
  if OpenedElsewhere(P, N) then
  begin
    DoError(CXT(sErrAlreadyOpen) + N);
    Exit;
  end;
  try
    S := LoadTextFile(N, Enc);
  except
    on E: Exception do
    begin
      DoError(N + ': ' + E.Message);
      Exit;
    end;
  end;
  LoadCore(P, N, S, Enc);
  Result := True;
end;

function TCsEditor.AskPageFileName(P: TCsPage; var AFileName: string): Boolean;
var
  Cancel: Boolean;
begin
  Cancel := False;
  if Assigned(FOnNeedFileName) then
    FOnNeedFileName(Self, AFileName, Cancel)
  else
    Cancel := not AskSaveFileName(P, AFileName);
  Result := (not Cancel) and (AFileName <> '');
end;

function TCsEditor.DefaultExtFor(const ALanguage: string): string;
var
  L: string;
begin
  L := LowerCase(ALanguage);
  if L = 'markdown' then Result := 'md'
  else if L = 'plaintext' then Result := 'txt'
  else if L = 'pascal' then Result := 'pas'
  else if L = 'html' then Result := 'html'
  else if L = 'css' then Result := 'css'
  else if L = 'javascript' then Result := 'js'
  else if L = 'json' then Result := 'json'
  else if L = 'xml' then Result := 'xml'
  else if L = 'sql' then Result := 'sql'
  else if L = 'ini' then Result := 'ini'
  else if L = 'bat' then Result := 'bat'
  else if L = 'python' then Result := 'py'
  else if L = 'cpp' then Result := 'cpp'
  else if L = 'csharp' then Result := 'cs'
  else if L = 'typescript' then Result := 'ts'
  else if L = 'java' then Result := 'java'
  else if L = 'shell' then Result := 'sh'
  else if L = 'powershell' then Result := 'ps1'
  else if L = 'yaml' then Result := 'yaml'
  else if L = 'php' then Result := 'php'
  else if L = 'go' then Result := 'go'
  else Result := '';
end;

{ 保存ダイアログ（SaveDialog、無ければ内蔵。TCMonacoEditor と同じ） }
function TCsEditor.AskSaveFileName(P: TCsPage; var AFileName: string): Boolean;
var
  Dlg: TSaveDialog;
  L, Dir: string;
begin
  if FSaveDialog <> nil then
    Dlg := FSaveDialog
  else
  begin
    if FInnerSaveDlg = nil then
    begin
      FInnerSaveDlg := TSaveDialog.Create(Self);
      FInnerSaveDlg.Filter := InnerFilter;
      FInnerSaveDlg.Options := FInnerSaveDlg.Options + [ofOverwritePrompt, ofPathMustExist];
    end;
    Dlg := FInnerSaveDlg;
    L := LowerCase(P.FLanguage);
    Dlg.DefaultExt := DefaultExtFor(L);
    if L = 'markdown' then Dlg.FilterIndex := 1
    else if L = 'plaintext' then Dlg.FilterIndex := 2
    else Dlg.FilterIndex := 3;
    Dir := ExtractFilePath(P.FFileName);
    if Dir = '' then Dir := FLastDir;
    Dlg.InitialDir := Dir;
    Dlg.FileName := ExtractFileName(P.FFileName);
  end;
  Result := Dlg.Execute;
  if Result then
  begin
    AFileName := Dlg.FileName;
    FLastDir := ExtractFilePath(AFileName);
  end;
end;

function TCsEditor.PageSave(P: TCsPage): Boolean;
begin
  Result := False;
  if P.FSyn = nil then Exit;
  if P.FFileName = '' then Exit(PageSaveAs(P, ''));    { 無題：名前を聞く }
  Result := WriteCore(P, P.FFileName);
end;

function TCsEditor.PageSaveAs(P: TCsPage; const AFileName: string): Boolean;
var
  N: string;
begin
  Result := False;
  if P.FSyn = nil then Exit;
  N := AFileName;
  if (N = '') and not AskPageFileName(P, N) then Exit;   { キャンセル：何も書かない（' *' は残る） }
  N := ExpandFileName(N);
  if OpenedElsewhere(P, N) then
  begin
    DoError(CXT(sErrAlreadyOpen) + N);
    Exit;
  end;
  Result := WriteCore(P, N);
end;

procedure TCsEditor.PageClear(P: TCsPage);
begin
  if P.FSyn = nil then Exit;
  Inc(FSuppressChange);
  try
    P.FSyn.Lines.Clear;
    P.FFileName := '';
    PageSetLanguage(P, FDefaultLanguage, False);
    P.FEncoding := ceUTF8;
    P.FLineBreak := #13#10;
    P.FSyn.ClearUndo;
    P.FSyn.Modified := False;
    P.FSyn.MarkTextAsSaved;
  finally
    Dec(FSuppressChange);
  end;
  CheckModified(P);
  UpdateTab(P);
  DocChanged(P);
  if P = FCur then InnerChange(P.FSyn);
end;

{ 保存していない文書の確認（4.4。TCMonacoEditor と同じ） }
procedure TCsEditor.DoQueryClose(AIndex: Integer; var CanClose: Boolean);
var
  P: TCsPage;
begin
  CanClose := True;
  if Assigned(FOnQueryClose) then
    FOnQueryClose(Self, AIndex, CanClose)
  else if FConfirmOnFormClose then
  begin
    P := TCsPage(FPages[AIndex]);
    case MessageDlg(CXT(sUnsavedTitle),
        Format(CXT(sUnsavedLine1), [P.Caption]) + LineEnding +
        CXT(sUnsavedLine2),
        mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
      mrYes:
        begin
          if P.FFileName = '' then SetCurPage(P);
          PageSave(P);
          CanClose := not P.Modified;               { 保存されなければ閉じない }
        end;
      mrNo: CanClose := True;
    else
      CanClose := False;
    end;
  end;
end;

{ MultiDocument = False：0 番の中身を入れ替える前の確認 }
function TCsEditor.QueryCurrent: Boolean;
var
  C: Boolean;
begin
  Result := True;
  if (FPages.Count > 0) and TCsPage(FPages[0]).Modified then
  begin
    C := True;
    DoQueryClose(0, C);
    Result := C;
  end;
end;

function TCsEditor.PageClose(P: TCsPage; Force: Boolean): Boolean;
var
  C: Boolean;
  S: TCsSynEdit;
begin
  Result := False;
  if P.FSyn = nil then Exit;
  if not FMultiDocument then
  begin
    { 閉じずに中身を空にする（タブは 1 枚のまま。4.5） }
    if (not Force) and not QueryCurrent then Exit;
    PageClear(P);
    Exit(True);
  end;
  if (not Force) and P.Modified then
  begin
    C := True;
    DoQueryClose(FPages.IndexOf(P), C);
    if not C then Exit;
  end;
  S := P.FSyn;
  RemovePage(P);
  P.FSyn := nil;
  S.OnChange := nil;
  S.OnChangeUpdating := nil;
  S.OnStatusChange := nil;
  S.FEditor := nil;
  S.FPage := nil;
  S.Free;
  Result := True;
end;

{ ================================================================== }
{ タブの集まり（4.1）                                                 }
{ ================================================================== }

function TCsEditor.OpenFile(const AFileName: string): Integer;
var
  N, S: string;
  Enc: TCMEncoding;
  E: TCsEditor;
  I: Integer;
  P: TCsPage;
begin
  if AFileName = '' then Exit(OpenWithDialog);
  if FCur = nil then Exit(-1);
  N := ExpandFileName(AFileName);
  { 1. このエディタで開いていれば、そのタブに切り替える }
  I := FindPage(N);
  if I >= 0 then
  begin
    ActiveIndex := I;
    Exit(I);
  end;
  { 2. 同じフォームの別の TCsEditor で開いていれば、そちらに切り替える（同じファイルは 1 か所だけ） }
  I := FindInOtherEditors(N, E);
  if I >= 0 then
  begin
    E.ActiveIndex := I;
    E.SetFocus;
    Exit(-1);
  end;
  { 3. 読む（読めなければ、タブを残さずに例外） }
  if not FMultiDocument then
  begin
    if not QueryCurrent then Exit(-1);
    S := LoadTextFile(N, Enc);
    LoadCore(TCsPage(FPages[0]), N, S, Enc);
    Exit(0);
  end;
  S := LoadTextFile(N, Enc);
  P := NewPageObj;
  LoadCore(P, N, S, Enc);
  RebuildTabs;
  DoDocListChange;
  SetCurPage(P);
  Result := FPages.IndexOf(P);
end;

{ 開くダイアログで選んだファイルを開く（TCMonacoEditor と同じ） }
function TCsEditor.OpenWithDialog: Integer;
var
  Dlg: TOpenDialog;
  Dir: string;
  Files: TStringList;
  I, R: Integer;
begin
  Result := -1;
  if FOpenDialog <> nil then
    Dlg := FOpenDialog
  else
  begin
    if FInnerOpenDlg = nil then
    begin
      FInnerOpenDlg := TOpenDialog.Create(Self);
      FInnerOpenDlg.Filter := InnerFilter;
      FInnerOpenDlg.Options := FInnerOpenDlg.Options + [ofFileMustExist, ofPathMustExist];
    end;
    Dlg := FInnerOpenDlg;
    if FMultiDocument then
      Dlg.Options := Dlg.Options + [ofAllowMultiSelect]
    else
      Dlg.Options := Dlg.Options - [ofAllowMultiSelect];
    Dir := '';
    if FCur <> nil then Dir := ExtractFilePath(FCur.FFileName);
    if Dir = '' then Dir := FLastDir;
    Dlg.InitialDir := Dir;
    Dlg.FileName := '';
  end;
  if not Dlg.Execute then Exit;
  Files := TStringList.Create;
  try
    if (ofAllowMultiSelect in Dlg.Options) and (Dlg.Files.Count > 0) then
      Files.Assign(Dlg.Files)
    else
      Files.Add(Dlg.FileName);
    if not FMultiDocument then
      while Files.Count > 1 do Files.Delete(Files.Count - 1);
    for I := 0 to Files.Count - 1 do
    begin
      if Files[I] = '' then Continue;
      try
        R := OpenFile(Files[I]);
        if R >= 0 then
        begin
          Result := R;
          FLastDir := ExtractFilePath(Files[I]);
        end;
      except
        on E: Exception do DoError(Files[I] + ': ' + E.Message);
      end;
    end;
  finally
    Files.Free;
  end;
end;

function TCsEditor.NewPage: Integer;
var
  P: TCsPage;
begin
  if FCur = nil then Exit(-1);
  if not FMultiDocument then
  begin
    if not QueryCurrent then Exit(-1);
    PageClear(TCsPage(FPages[0]));
    Exit(0);
  end;
  P := NewPageObj;
  RebuildTabs;
  DoDocListChange;
  SetCurPage(P);
  Result := FPages.IndexOf(P);
end;

procedure TCsEditor.SaveAll;
var
  I: Integer;
  P: TCsPage;
begin
  I := 0;
  while I < FPages.Count do
  begin
    P := TCsPage(FPages[I]);
    if P.Modified then
    begin
      if P.FFileName = '' then SetCurPage(P);    { 無題は、そのタブに切り替えてから名前を聞く }
      PageSave(P);
    end;
    Inc(I);
  end;
end;

function TCsEditor.CloseAll(Force: Boolean): Boolean;
var
  I: Integer;
begin
  if FCur = nil then Exit(False);
  if not FMultiDocument then Exit(PageClose(TCsPage(FPages[0]), Force));
  Result := True;
  { 右から閉じる。最後の 1 枚を閉じると空の無題ができ、それで終わる }
  for I := FPages.Count - 1 downto 0 do
  begin
    if I >= FPages.Count then Continue;
    if not PageClose(TCsPage(FPages[I]), Force) then Exit(False);
  end;
end;

function TCsEditor.CanCloseAll: Boolean;
var
  I: Integer;
  C: Boolean;
begin
  Result := True;
  if FPages = nil then Exit;
  for I := 0 to FPages.Count - 1 do
    if TCsPage(FPages[I]).Modified then
    begin
      C := True;
      DoQueryClose(I, C);
      if not C then Exit(False);
    end;
end;

function TCsEditor.FindPage(const AFileName: string): Integer;
var
  N: string;
  I: Integer;
  P: TCsPage;
begin
  Result := -1;
  if (AFileName = '') or (FPages = nil) then Exit;
  N := ExpandFileName(AFileName);
  for I := 0 to FPages.Count - 1 do
  begin
    P := TCsPage(FPages[I]);
    if (P.FFileName <> '') and (AnsiCompareText(ExpandFileName(P.FFileName), N) = 0) then Exit(I);
  end;
end;

procedure TCsEditor.MovePage(AFromIndex, AToIndex: Integer);
begin
  if (AFromIndex < 0) or (AToIndex < 0) or (AFromIndex >= FPages.Count) or (AToIndex >= FPages.Count) or
     (AFromIndex = AToIndex) then Exit;
  FPages.Move(AFromIndex, AToIndex);
  RebuildTabs;
  DoDocListChange;
end;

{ ================================================================== }
{ 見えているタブ（ed.〜 は ed.Pages[ActiveIndex].〜 と同じ）          }
{ ================================================================== }

function TCsEditor.GetPage(AIndex: Integer): TCsPage;
begin
  Result := TCsPage(FPages[AIndex]);       { 範囲の外は EListError }
end;

function TCsEditor.GetPageCount: Integer;
begin
  Result := FPages.Count;
end;

function TCsEditor.GetActiveIndex: Integer;
begin
  if FCur = nil then Result := -1 else Result := FPages.IndexOf(FCur);
end;

procedure TCsEditor.SetActiveIndex(AValue: Integer);
begin
  if (AValue < 0) or (AValue >= FPages.Count) then Exit;   { 範囲の外は何もしない }
  SetCurPage(TCsPage(FPages[AValue]));
end;

function TCsEditor.GetEdText: string;
begin
  if FCur = nil then Result := '' else Result := FCur.Text;
end;

procedure TCsEditor.SetEdText(const AValue: string);
begin
  if FCur <> nil then FCur.Text := AValue;
end;

function TCsEditor.GetEdCaption: string;
begin
  if FCur = nil then Result := '' else Result := FCur.Caption;
end;

function TCsEditor.GetEdFileName: string;
begin
  if FCur = nil then Result := '' else Result := FCur.FileName;
end;

function TCsEditor.GetEdModified: Boolean;
begin
  Result := (FCur <> nil) and FCur.Modified;
end;

function TCsEditor.GetEdEncoding: TCMEncoding;
begin
  if FCur = nil then Result := ceUTF8 else Result := FCur.Encoding;
end;

procedure TCsEditor.SetEdEncoding(AValue: TCMEncoding);
begin
  if FCur <> nil then FCur.Encoding := AValue;
end;

function TCsEditor.GetEdLanguage: string;
begin
  if FCur = nil then Result := '' else Result := FCur.Language;
end;

procedure TCsEditor.SetEdLanguage(const AValue: string);
begin
  if FCur <> nil then FCur.Language := AValue;
end;

function TCsEditor.GetEdLineCount: Integer;
begin
  if FCur = nil then Result := 0 else Result := FCur.LineCount;
end;

function TCsEditor.GetSynEdit: TCSynEdit;
begin
  if FCur = nil then Result := nil else Result := FCur.FSyn;
end;

function TCsEditor.GetLines: TStrings;
begin
  if FCur = nil then Result := FDesignLines else Result := FCur.Lines;
end;

procedure TCsEditor.SetLines(AValue: TStrings);
begin
  GetLines.Assign(AValue);
end;

function TCsEditor.LoadFromFile(const AFileName: string): Boolean;
begin
  Result := (FCur <> nil) and FCur.LoadFromFile(AFileName);
end;

function TCsEditor.Save: Boolean;
begin
  Result := (FCur <> nil) and FCur.Save;
end;

function TCsEditor.SaveAs(const AFileName: string): Boolean;
begin
  Result := (FCur <> nil) and FCur.SaveAs(AFileName);
end;

procedure TCsEditor.Clear;
begin
  if FCur <> nil then FCur.Clear;
end;

function TCsEditor.Close(Force: Boolean): Boolean;
begin
  Result := (FCur <> nil) and FCur.Close(Force);
end;

{ ================================================================== }
{ イベントの中継（3.2・5.1）                                          }
{ ================================================================== }

procedure TCsEditor.InnerChange(Sender: TObject);
var
  S: TCsSynEdit;
begin
  if FSuppressChange > 0 then Exit;
  S := TCsSynEdit(Sender);
  if (S.FPage = nil) or S.FPage.FUpdating then Exit;   { 書き換えの途中は、終わってから（InnerUpdating） }
  { 中の部品の OnChange は Undo の記録ごとに来るので、本文の変更の番号が進んだときだけ知らせる }
  if S.ChangeStamp = S.FPage.FLastStamp then Exit;
  S.FPage.FLastStamp := S.ChangeStamp;
  if S.FPage <> FCur then Exit;                        { 見えているタブだけ }
  if Assigned(FOnChange) then FOnChange(Self);
  if FPreview <> nil then FPreview.SourceChanged(Self);
  if (FMinimap <> nil) and FMinimap.Visible then FMinimap.ScheduleRebuild;
  UpdateVBar;
end;

{ 中の部品の書き換えの始まり・終わり。終わったときに、本文が変わっていれば OnChange を 1 回 }
procedure TCsEditor.InnerUpdating(ASender: TObject; AnUpdating: Boolean);
var
  S: TCsSynEdit;
begin
  S := TCsSynEdit(ASender);
  if S.FPage = nil then Exit;
  S.FPage.FUpdating := AnUpdating;
  if not AnUpdating then InnerChange(S);
end;

procedure TCsEditor.InnerStatus(Sender: TObject; Changes: TSynStatusChanges);
var
  S: TCsSynEdit;
  P: TCsPage;
  L, C: Integer;
begin
  S := TCsSynEdit(Sender);
  P := S.FPage;
  if P = nil then Exit;
  CheckModified(P);
  if P <> FCur then Exit;
  if Changes * [scCaretX, scCaretY] <> [] then
  begin
    GetCursorPos(L, C);
    if (L <> FLastCurLine) or (C <> FLastCurCol) then
    begin
      FLastCurLine := L;
      FLastCurCol := C;
      if Assigned(FOnCursorChange) then FOnCursorChange(Self, L, C);
    end;
  end;
  if scInsertMode in Changes then
    if Assigned(FOnModeChange) then FOnModeChange(Self, not S.InsertMode);
  if scTopLine in Changes then
  begin
    if FPreview <> nil then FPreview.SourceScrolled(Self, S.TopLine);
    if (FMinimap <> nil) and FMinimap.Visible then FMinimap.Rebuild;
  end;
  if Changes * [scTopLine, scLinesInWindow] <> [] then UpdateVBar;
end;

{ ' *' が付いた・消えたときだけ、タブ・OnModifiedChange・OnDocumentChange }
procedure TCsEditor.CheckModified(P: TCsPage);
var
  M: Boolean;
begin
  if (P = nil) or (P.FSyn = nil) then Exit;
  M := P.FSyn.Modified;
  if M = P.FWasModified then Exit;
  P.FWasModified := M;
  UpdateTab(P);
  if (P = FCur) and Assigned(FOnModifiedChange) then FOnModifiedChange(Self);
  if Assigned(FOnDocumentChange) then FOnDocumentChange(Self, FPages.IndexOf(P));
end;

{ タブの名前・言語が変わった（見えていないタブも） }
procedure TCsEditor.DocChanged(P: TCsPage);
begin
  UpdateTab(P);
  if Assigned(FOnDocumentChange) then FOnDocumentChange(Self, FPages.IndexOf(P));
  if (P = FCur) and (FPreview <> nil) then FPreview.SourceSwitched(Self);
  if (P = FCur) and (CurrentFindDialog(False) <> nil) then CurrentFindDialog(False).UpdateCaption;
end;

procedure TCsEditor.DoDocListChange;
begin
  if Assigned(FOnDocListChange) then FOnDocListChange(Self);
end;

procedure TCsEditor.InnerEnter(S: TCsSynEdit);
var
  D: TCsFindDialog;
begin
  ApplyEditorColors(S);                          { 選択の色を SelectionColor… に }
  if FHook <> nil then FHook.SetActive(Self);
  if FPreview <> nil then FPreview.SetSource(Self);
  D := CurrentFindDialog(False);
  if (D <> nil) and D.IsShowing then D.Target := Self;
end;

procedure TCsEditor.InnerExit(S: TCsSynEdit);
begin
  ApplyEditorColors(S);                          { 選択の色を HitColor… に（検索ダイアログを使っている間） }
end;

{ ---------- ドロップ（4.9） ---------- }

procedure TCsEditor.QueueDrop(const AFiles: array of string);
var
  I: Integer;
begin
  for I := 0 to High(AFiles) do FDropFiles.Add(AFiles[I]);
  Application.QueueAsyncCall(@AsyncDropFiles, 0);
end;

procedure TCsEditor.AsyncDropFiles(Data: PtrInt);
var
  L: TStringList;
  Handled: Boolean;
  I: Integer;
begin
  if (FDropFiles = nil) or (FDropFiles.Count = 0) then Exit;
  L := TStringList.Create;
  try
    L.Assign(FDropFiles);
    FDropFiles.Clear;
    Handled := False;
    if Assigned(FOnFileDrop) then FOnFileDrop(Self, L, Handled);
    if Handled or not FOpenDroppedFiles then Exit;
    for I := 0 to L.Count - 1 do
    begin
      if not FileExists(L[I]) or DirectoryExists(L[I]) then Continue;   { フォルダーは無視する }
      try
        OpenFile(L[I]);
      except
        on E: Exception do DoError(L[I] + ': ' + E.Message);
      end;
      if not FMultiDocument then Break;          { タブなしは最初の 1 つだけ }
    end;
  finally
    L.Free;
  end;
end;

{ ---------- エラー ---------- }

procedure TCsEditor.DoError(const AMessage: string);
begin
  if Assigned(FOnError) then
  begin
    FOnError(Self, AMessage);
    Exit;
  end;
  if csDesigning in ComponentState then Exit;
  FErrQueue.Add(AMessage);
  Application.QueueAsyncCall(@AsyncShowError, 0);
end;

procedure TCsEditor.AsyncShowError(Data: PtrInt);
var
  S: string;
begin
  while (FErrQueue <> nil) and (FErrQueue.Count > 0) do
  begin
    S := FErrQueue[0];
    FErrQueue.Delete(0);
    if GShownErrors.IndexOf(S) >= 0 then Continue;   { 同じメッセージは 1 回だけ }
    GShownErrors.Add(S);
    MessageDlg(S, mtError, [mbOK], 0);
  end;
end;

{ ================================================================== }
{ 設定の渡し方（5.2）・色（5.3）・配色（4.7）                          }
{ ================================================================== }

procedure AddKey(KS: TSynEditKeyStrokes; ACmd: TSynEditorCommand; AKey: Word; AShift: TShiftState);
var
  K: TSynEditKeyStroke;
begin
  K := KS.Add;
  K.Key := AKey;
  K.Shift := AShift;
  K.Command := ACmd;
end;

{ 5.5：Keystrokes を空にして、この表だけを入れる }
procedure SetupKeys(S: TCustomSynEdit);
var
  KS: TSynEditKeyStrokes;
begin
  KS := S.Keystrokes;
  KS.Clear;
  AddKey(KS, ecLeft, VK_LEFT, []);
  AddKey(KS, ecRight, VK_RIGHT, []);
  AddKey(KS, ecUp, VK_UP, []);
  AddKey(KS, ecDown, VK_DOWN, []);
  AddKey(KS, ecSelLeft, VK_LEFT, [ssShift]);
  AddKey(KS, ecSelRight, VK_RIGHT, [ssShift]);
  AddKey(KS, ecSelUp, VK_UP, [ssShift]);
  AddKey(KS, ecSelDown, VK_DOWN, [ssShift]);
  AddKey(KS, ecWordLeft, VK_LEFT, [ssCtrl]);
  AddKey(KS, ecWordRight, VK_RIGHT, [ssCtrl]);
  AddKey(KS, ecSelWordLeft, VK_LEFT, [ssCtrl, ssShift]);
  AddKey(KS, ecSelWordRight, VK_RIGHT, [ssCtrl, ssShift]);
  AddKey(KS, ecScrollUp, VK_UP, [ssCtrl]);
  AddKey(KS, ecScrollDown, VK_DOWN, [ssCtrl]);
  AddKey(KS, ecLineStart, VK_HOME, []);
  AddKey(KS, ecLineEnd, VK_END, []);
  AddKey(KS, ecSelLineStart, VK_HOME, [ssShift]);
  AddKey(KS, ecSelLineEnd, VK_END, [ssShift]);
  AddKey(KS, ecEditorTop, VK_HOME, [ssCtrl]);
  AddKey(KS, ecEditorBottom, VK_END, [ssCtrl]);
  AddKey(KS, ecSelEditorTop, VK_HOME, [ssCtrl, ssShift]);
  AddKey(KS, ecSelEditorBottom, VK_END, [ssCtrl, ssShift]);
  AddKey(KS, ecPageUp, VK_PRIOR, []);
  AddKey(KS, ecPageDown, VK_NEXT, []);
  AddKey(KS, ecSelPageUp, VK_PRIOR, [ssShift]);
  AddKey(KS, ecSelPageDown, VK_NEXT, [ssShift]);
  AddKey(KS, ecDeleteLastChar, VK_BACK, []);
  AddKey(KS, ecDeleteLastChar, VK_BACK, [ssShift]);
  AddKey(KS, ecDeleteChar, VK_DELETE, []);
  AddKey(KS, ecDeleteLastWord, VK_BACK, [ssCtrl]);
  AddKey(KS, ecDeleteWord, VK_DELETE, [ssCtrl]);
  AddKey(KS, ecLineBreak, VK_RETURN, []);
  AddKey(KS, ecLineBreak, VK_RETURN, [ssShift]);
  AddKey(KS, ecTab, VK_TAB, []);
  AddKey(KS, ecShiftTab, VK_TAB, [ssShift]);
  AddKey(KS, ecToggleMode, VK_INSERT, []);
  AddKey(KS, ecCut, VK_X, [ssCtrl]);
  AddKey(KS, ecCut, VK_DELETE, [ssShift]);
  AddKey(KS, ecCopy, VK_C, [ssCtrl]);
  AddKey(KS, ecCopy, VK_INSERT, [ssCtrl]);
  AddKey(KS, ecPaste, VK_V, [ssCtrl]);
  AddKey(KS, ecPaste, VK_INSERT, [ssShift]);
  AddKey(KS, ecUndo, VK_Z, [ssCtrl]);
  AddKey(KS, ecRedo, VK_Y, [ssCtrl]);
  AddKey(KS, ecRedo, VK_Z, [ssCtrl, ssShift]);
  AddKey(KS, ecSelectAll, VK_A, [ssCtrl]);
  AddKey(KS, ecBlockIndent, VK_OEM_6, [ssCtrl]);          { Ctrl+] }
  AddKey(KS, ecBlockUnindent, VK_OEM_4, [ssCtrl]);        { Ctrl+[ }
  AddKey(KS, ecFoldCurrent, VK_OEM_4, [ssCtrl, ssShift]); { Ctrl+Shift+[ }
  AddKey(KS, ecUnFoldCurrent, VK_OEM_6, [ssCtrl, ssShift]); { Ctrl+Shift+] }
end;

{ 中の部品に設定を渡す。AFirst は作ったときだけ入れるもの（5.2 の「作ったときに入れる設定」） }
procedure TCsEditor.ApplyOptionsTo(S: TCsSynEdit; AFirst: Boolean);
var
  Opt: TSynEditorOptions;
  HA: TSynEditMarkupHighlightAllCaret;
begin
  if AFirst then
  begin
    SetupKeys(S);
    S.MouseActions.AddCommand(emcStartColumnSelections, True, mbXLeft, ccSingle, cdDown,
      [ssShift, ssAlt], [ssShift, ssAlt, ssCtrl]);
    S.Gutter.LineNumberPart.ShowOnlyLineNumbersMultiplesOf := 1;
    S.WantTabs := True;
    S.HideSelection := False;
  end;
  { 10.5：ミニマップを出している間は、中の部品の縦のスクロールバーを隠す（TCsEditor のものを一番右に出す） }
  if FMinimapOn then S.ScrollBars := ssAutoHorizontal else S.ScrollBars := ssAutoBoth;
  Opt := [eoAutoIndent, eoGroupUndo, eoTabsToSpaces, eoKeepCaretX, eoEnhanceHomeKey, eoDragDropEditing,
    eoScrollPastEof, eoAltSetsColumnMode, eoShowScrollHint];
  if FMatchBrackets then Include(Opt, eoBracketHighlight);
  S.Options := Opt;
  S.SetWrap(FWordWrap);
  S.Gutter.LineNumberPart.Visible := FLineNumbers;
  AssignFontKeepColor(S, Font);
  S.TabWidth := FTabSize;
  S.BlockIndent := FTabSize;
  S.BlockTabIndent := 0;
  if S.Gutter.CodeFoldPart.Visible <> FFolding then
  begin
    S.Gutter.CodeFoldPart.Visible := FFolding;
    if not FFolding then S.UnfoldAll;
  end;
  if S.MarkupByClass[TSynEditMarkupWordGroup] <> nil then
    S.MarkupByClass[TSynEditMarkupWordGroup].Enabled := FMatchBrackets;
  if S.MarkupByClass[TSynEditMarkupHighlightAllCaret] <> nil then
  begin
    HA := TSynEditMarkupHighlightAllCaret(S.MarkupByClass[TSynEditMarkupHighlightAllCaret]);
    HA.FullWord := True;
    HA.Trim := True;
    HA.WaitTime := 200;
    HA.Enabled := FOccurrencesHighlight;
  end;
  S.ReadOnly := FReadOnly;
  if IsDarkTheme then
  begin
    if S.EditStyle <> csVSDark then S.EditStyle := csVSDark else ApplyEditorColors(S);
  end
  else
  begin
    if S.EditStyle <> csVSLight then S.EditStyle := csVSLight else ApplyEditorColors(S);
  end;
end;

procedure TCsEditor.ApplyAllOptions;
var
  I: Integer;
begin
  if FPages = nil then Exit;
  for I := 0 to FPages.Count - 1 do ApplyOptionsTo(TCsPage(FPages[I]).FSyn, False);
  if FTabs <> nil then FTabs.Visible := FMultiDocument and HandleAllocated;
  if FMinimap <> nil then FMinimap.Visible := FMinimapOn;
  ApplyBarsLayout;
end;

{ 5.3：TCsEditor の設定の色（カーソル行・選択）。inherited ApplyEditStyle の後で入れる }
procedure TCsEditor.ApplyEditorColors(S: TCsSynEdit);
var
  Dark: Boolean;
begin
  Dark := S.EditStyle = csVSDark;
  if Dark then
    S.LineHighlightColor.Background := RealColor(FCursorLineColorDark, DefCursorLineColorDark)
  else
    S.LineHighlightColor.Background := RealColor(FCursorLineColorLight, DefCursorLineColorLight);
  S.LineHighlightColor.Foreground := clNone;
  S.LineHighlightColor.FrameColor := clNone;
  if S.Focused then
  begin
    if Dark then
      S.SelectedColor.Background := RealColor(FSelectionColorDark, SelStyleDark[scStandard])
    else
      S.SelectedColor.Background := RealColor(FSelectionColorLight, SelStyleLight[scStandard]);
  end
  else
  begin
    if Dark then
      S.SelectedColor.Background := RealColor(FHitColorDark, DefHitColorDark)
    else
      S.SelectedColor.Background := RealColor(FHitColorLight, DefHitColorLight);
  end;
  S.SelectedColor.Foreground := clNone;
  { スクロールバー：ダークなら DarkMode_Explorer、ライトなら Explorer の見た目（変わったときだけ当てる。4.7） }
  if S.HandleAllocated and (S.FDarkBars <> Ord(Dark)) then
  begin
    S.FDarkBars := Ord(Dark);
    try
      if Dark then
        CsSetWindowTheme(S.Handle, 'DarkMode_Explorer', nil)
      else
        CsSetWindowTheme(S.Handle, 'Explorer', nil);
    except
      { uxtheme が無い・古い Windows：色は変わらない（動きは同じ） }
    end;
  end;
end;

function TCsEditor.IsDarkTheme: Boolean;
begin
  case FTheme of
    ctDark: Result := True;
    ctLight: Result := False;
  else
    Result := FOsDark;
  end;
end;

procedure TCsEditor.ReadOsTheme;
begin
  try
    FOsDark := OsIsDark;
  except
    FOsDark := False;
  end;
end;

{ OS のテーマが変わった（受け口のウィンドウから。4.7） }
procedure TCsEditor.AsyncOsTheme(Data: PtrInt);
var
  Old: Boolean;
begin
  Old := FOsDark;
  ReadOsTheme;
  if (FTheme = ctAuto) and (Old <> FOsDark) then ApplyTheme;
end;

{ 全タブの配色・タブの色・背景・ミニマップ・プレビュー }
procedure TCsEditor.ApplyTheme;
var
  I: Integer;
begin
  if FPages = nil then Exit;
  for I := 0 to FPages.Count - 1 do
    with TCsPage(FPages[I]).FSyn do
      if IsDarkTheme then
      begin
        if EditStyle <> csVSDark then EditStyle := csVSDark else ApplyEditorColors(TCsPage(FPages[I]).FSyn);
      end
      else
      begin
        if EditStyle <> csVSLight then EditStyle := csVSLight else ApplyEditorColors(TCsPage(FPages[I]).FSyn);
      end;
  ApplyTabColors;
  UpdateVBar;
  if (FMinimap <> nil) and FMinimap.Visible then FMinimap.Rebuild;
  if FPreview <> nil then FPreview.SourceSwitched(Self);
  Invalidate;
end;

procedure TCsEditor.FontChanged(Sender: TObject);
var
  I: Integer;
begin
  inherited FontChanged(Sender);
  if FPages = nil then Exit;
  for I := 0 to FPages.Count - 1 do
    if TCsPage(FPages[I]).FSyn <> nil then AssignFontKeepColor(TCsPage(FPages[I]).FSyn, Font);
  if (FMinimap <> nil) and FMinimap.Visible then FMinimap.ScheduleRebuild;
  UpdateVBar;
end;

{ ================================================================== }
{ キー（6章）                                                         }
{ ================================================================== }

procedure TCsEditor.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);     { OnKeyDown を呼ぶ }
end;

{ フォームのメニュー・ActionList に同じショートカットがあれば実行する（6.1 の 6）。
  LCL の IsShortcut は Ctrl・Shift を本物のキーボードから読むため、渡された Shift で探す（TCMonacoEditor と同じ） }
function TCsEditor.RunFormShortcut(Key: Word; Shift: TShiftState): Boolean;
var
  F: TCustomForm;
  SC: TShortCut;
  I, J: Integer;
  AL: TCustomActionList;
  MI: TMenuItem;
  A: TCustomAction;
begin
  Result := False;
  F := GetParentForm(Self);
  if F = nil then Exit;
  SC := ShortCut(Key, Shift * [ssShift, ssCtrl, ssAlt]);
  if (F is TForm) and (TForm(F).Menu <> nil) then
  begin
    MI := TForm(F).Menu.FindItem(SC, fkShortCut);
    if MI <> nil then
    begin
      if MI.Enabled then MI.Click;
      Exit(True);
    end;
  end;
  for I := 0 to F.ComponentCount - 1 do
    if F.Components[I] is TCustomActionList then
    begin
      AL := TCustomActionList(F.Components[I]);
      for J := 0 to AL.ActionCount - 1 do
        if (AL.Actions[J] is TCustomAction) and (TCustomAction(AL.Actions[J]).ShortCut = SC) then
        begin
          A := TCustomAction(AL.Actions[J]);
          A.Update;
          if A.Enabled then A.Execute;
          Exit(True);
        end;
    end;
end;

{ 6.1 の 2〜7。受けたら True（Key := 0 は呼んだ側） }
function TCsEditor.HandleKey(S: TCsSynEdit; var Key: Word; Shift: TShiftState): Boolean;
var
  M: TShiftState;
  T: string;
begin
  Result := True;
  M := Shift * [ssShift, ssCtrl, ssAlt];
  { 2. Ctrl+P：印刷 }
  if (Key = VK_P) and (M = [ssCtrl]) then
  begin
    Application.QueueAsyncCall(@AsyncPrint, 0);
    Exit;
  end;
  { 3. Ctrl+Shift+M：ミニマップ }
  if (Key = VK_M) and (M = [ssCtrl, ssShift]) then
  begin
    Minimap := not Minimap;
    Exit;
  end;
  { 4. Ctrl+Tab・Ctrl+Shift+Tab：次・前のタブ（端まで行ったら反対側） }
  if (Key = VK_TAB) and (M * [ssCtrl, ssAlt] = [ssCtrl]) then
  begin
    if FMultiDocument and (FPages.Count > 1) then
    begin
      if ssShift in M then
        ActiveIndex := (ActiveIndex - 1 + FPages.Count) mod FPages.Count
      else
        ActiveIndex := (ActiveIndex + 1) mod FPages.Count;
    end;
    Exit;
  end;
  { 5. 内蔵のショートカット（6.2） }
  if M = [ssCtrl] then
    case Key of
      VK_S: begin Save; Exit; end;
      VK_F:
        begin
          T := '';
          if S.SelAvail and (S.BlockBegin.Y = S.BlockEnd.Y) then T := S.SelText;
          ShowFindDialog(T);
          Exit;
        end;
      VK_Z, VK_Y, VK_X, VK_C, VK_V: Exit(False);        { エディタのコマンドで行う（7 へ） }
    end;
  if M = [ssCtrl, ssShift] then
    case Key of
      VK_V: begin if FPreview <> nil then ShowPreview := not ShowPreview; Exit; end;
      VK_Z: Exit(False);
    end;
  if (M = []) and (Key = VK_F5) then begin FindNext; Exit; end;
  if (M = [ssShift]) and (Key = VK_F5) then begin FindPrev; Exit; end;
  if (M = [ssShift]) and (Key = VK_F10) then begin DuplicateLine; Exit; end;
  if (M = []) and (Key = VK_F11) then
  begin
    LineNumbers := not LineNumbers;
    if Assigned(FOnLineNumbersChange) then FOnLineNumbersChange(Self);
    Exit;
  end;
  if (M = []) and (Key = VK_F12) then
  begin
    if Assigned(FOnToggleMaximize) then FOnToggleMaximize(Self);
    Exit;
  end;
  { 6. フォームのメニュー・ActionList }
  if (M <> []) or ((Key >= VK_F1) and (Key <= VK_F24)) then
    if RunFormShortcut(Key, M) then Exit;
  { Ctrl+Shift+P：何もしない（フォームに無ければ止める） }
  if (Key = VK_P) and (M = [ssCtrl, ssShift]) then Exit;
  { 7. Monaco に最初からあるキー（6.3） }
  if (M = [ssAlt]) and (Key in [VK_UP, VK_DOWN]) then
  begin
    MoveLines(Key = VK_UP);
    Exit;
  end;
  if (M = [ssShift, ssAlt]) and (Key in [VK_UP, VK_DOWN]) then
  begin
    CopyLines(Key = VK_UP);
    Exit;
  end;
  if (M = [ssCtrl]) and ((Key = VK_OEM_2) or (Key = VK_DIVIDE)) then
  begin
    ToggleComment;
    Exit;
  end;
  if (M = [ssCtrl]) and (Key = VK_G) then
  begin
    GotoLineDialog;
    Exit;
  end;
  if (M = [ssCtrl]) and (Key = VK_RETURN) then
  begin
    InsertLineBelow;
    Exit;
  end;
  Result := False;                                   { 8. Keystrokes へ }
end;

procedure TCsEditor.GotoLineDialog;
var
  S: string;
  N: Integer;
begin
  if FCur = nil then Exit;
  S := '';
  if not InputQuery(CXT(sGoToLineTitle), Format(CXT(sGoToLinePrompt), [LineCount]), S) then Exit;
  if TryStrToInt(Trim(S), N) then SetCursorPos(N, 1);
end;

procedure TCsEditor.AsyncPrint(Data: PtrInt);
begin
  Print;
end;

{ ================================================================== }
{ 位置（6.5）・画面の上での操作（3.2）                                 }
{ ================================================================== }

procedure TCsEditor.GetCursorPos(out ALine, AColumn: Integer);
var
  P: TPoint;
begin
  ALine := 1;
  AColumn := 1;
  if FCur = nil then Exit;
  P := FCur.FSyn.LogicalCaretXY;
  ALine := P.Y;
  AColumn := ByteToU16Col(LineOf(FCur.FSyn, P.Y), P.X);
end;

procedure TCsEditor.SetCursorPos(ALine, AColumn: Integer);
var
  S: TCsSynEdit;
  P: TPoint;
begin
  if FCur = nil then Exit;
  S := FCur.FSyn;
  ALine := EnsureRange(ALine, 1, LineTotal(S));
  P := Point(U16ToByteCol(LineOf(S, ALine), Max(1, AColumn)), ALine);
  S.LogicalCaretXY := P;
  S.BlockBegin := P;                         { 選択を外す }
end;

procedure TCsEditor.SetSelection(ALine1, AColumn1, ALine2, AColumn2: Integer);
var
  S: TCsSynEdit;
  P1, P2: TPoint;
begin
  if FCur = nil then Exit;
  S := FCur.FSyn;
  ALine1 := EnsureRange(ALine1, 1, LineTotal(S));
  ALine2 := EnsureRange(ALine2, 1, LineTotal(S));
  P1 := Point(U16ToByteCol(LineOf(S, ALine1), Max(1, AColumn1)), ALine1);
  P2 := Point(U16ToByteCol(LineOf(S, ALine2), Max(1, AColumn2)), ALine2);
  S.LogicalCaretXY := P2;                    { カーソルは終わり }
  S.BlockBegin := P1;
  S.BlockEnd := P2;
end;

function TCsEditor.GetSelText: string;
begin
  Result := '';
  if (FCur = nil) or not FCur.FSyn.SelAvail then Exit;
  Result := NormalizeBreaks(FCur.FSyn.SelText, FCur.FLineBreak);
end;

procedure TCsEditor.SetSelText(const AValue: string);
var
  S: TCsSynEdit;
begin
  if (FCur = nil) or FReadOnly then Exit;
  S := FCur.FSyn;
  if (AValue = '') and not S.SelAvail then Exit;
  S.BeginUndoBlock;
  try
    S.SelText := NormalizeBreaks(AValue, LineEnding);
  finally
    S.EndUndoBlock;
  end;
  S.BlockBegin := S.LogicalCaretXY;         { 後ろにカーソル、選択は外す }
end;

function TCsEditor.GetSelStart: Integer;
var
  S: TCsSynEdit;
  B: TPoint;
  I: Integer;
begin
  Result := 0;
  if FCur = nil then Exit;
  S := FCur.FSyn;
  if S.SelAvail then B := S.BlockBegin else B := S.LogicalCaretXY;
  for I := 1 to B.Y - 1 do Inc(Result, U16Len(LineOf(S, I)) + Length(FCur.FLineBreak));
  Inc(Result, ByteToU16Col(LineOf(S, B.Y), B.X) - 1);
end;

function TCsEditor.GetSelLength: Integer;
begin
  Result := U16Len(GetSelText);
end;

function TCsEditor.GetCanUndo: Boolean;
begin
  Result := (FCur <> nil) and FCur.FSyn.CanUndo;
end;

function TCsEditor.GetCanRedo: Boolean;
begin
  Result := (FCur <> nil) and FCur.FSyn.CanRedo;
end;

function TCsEditor.GetLineText: string;
begin
  if FCur = nil then Exit('');
  Result := LineOf(FCur.FSyn, FCur.FSyn.LogicalCaretXY.Y);
end;

{ カーソル行の単語（4.10）。行・区切り文字・空の単語・引用符が前と同じなら分け直さない }
function TCsEditor.GetLineWords: TStrings;
var
  L, Key: string;
begin
  L := GetLineText;
  Key := L + #1 + FLineDelimiters + #1 + BoolToStr(FLineSkipEmpty, True) + #1 + FLineQuoteChar;
  if (Key <> FLineWordsKey) or (FLineWordsKey = '') then
  begin
    CMSplitLine(L, FLineDelimiters, FLineSkipEmpty, FLineQuoteChar, FLineWords);
    FLineWordsKey := Key;
  end;
  Result := FLineWords;
end;

function TCsEditor.GetReady: Boolean;
begin
  Result := not (csDesigning in ComponentState);
end;

procedure TCsEditor.Undo;
begin
  if FCur <> nil then FCur.FSyn.Undo;
end;

procedure TCsEditor.Redo;
begin
  if FCur <> nil then FCur.FSyn.Redo;
end;

procedure TCsEditor.Cut;
begin
  if (FCur <> nil) and not FReadOnly then FCur.FSyn.CutToClipboard;
end;

procedure TCsEditor.Copy;
begin
  if FCur <> nil then FCur.FSyn.CopyToClipboard;
end;

procedure TCsEditor.Paste;
begin
  if (FCur <> nil) and not FReadOnly then FCur.FSyn.PasteFromClipboard;
end;

procedure TCsEditor.SelectAll;
begin
  if FCur <> nil then FCur.FSyn.SelectAll;
end;

procedure TCsEditor.ToggleOverwrite;
begin
  if FCur <> nil then FCur.FSyn.InsertMode := not FCur.FSyn.InsertMode;
end;

function TCsEditor.TopLine: Double;
begin
  if FCur = nil then Result := 1 else Result := FCur.FSyn.TopLine;
end;

procedure TCsEditor.ScrollToLine(ALine: Double);
begin
  if FCur <> nil then FCur.FSyn.TopLine := Max(1, Trunc(ALine));
end;

function TCsEditor.CanPrint: Boolean;
begin
  Result := FPreview <> nil;
end;

procedure TCsEditor.Print;
begin
  if FPreview <> nil then FPreview.PrintFor(Self);
end;

{ ================================================================== }
{ 編集（6.4）                                                         }
{ ================================================================== }

{ 対象の行：選んでいればその行（終わりが行の頭なら、その行は入れない）、選んでいなければカーソル行 }
procedure TCsEditor.TargetLines(S: TCsSynEdit; out L1, L2: Integer);
var
  B, E: TPoint;
begin
  if S.SelAvail then
  begin
    B := S.BlockBegin;
    E := S.BlockEnd;
    L1 := B.Y;
    L2 := E.Y;
    if (E.X = 1) and (L2 > L1) then Dec(L2);
  end
  else
  begin
    L1 := S.LogicalCaretXY.Y;
    L2 := L1;
  end;
  L1 := EnsureRange(L1, 1, LineTotal(S));
  L2 := EnsureRange(L2, L1, LineTotal(S));
end;

{ 行 L1〜L2 を改行でつないだもの }
function JoinLines(S: TCustomSynEdit; L1, L2: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := L1 to L2 do
  begin
    if I > L1 then Result := Result + LineEnding;
    Result := Result + LineOf(S, I);
  end;
end;

procedure TCsEditor.DuplicateLine;
var
  S: TCsSynEdit;
  L1, L2, N: Integer;
  HadSel: Boolean;
  B, E, C, P: TPoint;
begin
  if (FCur = nil) or FReadOnly then Exit;
  S := FCur.FSyn;
  TargetLines(S, L1, L2);
  N := L2 - L1 + 1;
  HadSel := S.SelAvail;
  B := S.BlockBegin;
  E := S.BlockEnd;
  C := S.LogicalCaretXY;
  P := Point(Length(LineOf(S, L2)) + 1, L2);
  S.BeginUndoBlock;
  try
    S.TextBetweenPoints[P, P] := LineEnding + JoinLines(S, L1, L2);
  finally
    S.EndUndoBlock;
  end;
  { カーソル（選択）を複製した行へ }
  if HadSel then
  begin
    S.LogicalCaretXY := Point(E.X, E.Y + N);
    S.BlockBegin := Point(B.X, B.Y + N);
    S.BlockEnd := Point(E.X, E.Y + N);
  end
  else
  begin
    S.LogicalCaretXY := Point(C.X, C.Y + N);
    S.BlockBegin := S.LogicalCaretXY;
  end;
end;

procedure TCsEditor.DeleteToEnd;
var
  S: TCsSynEdit;
  P, E: TPoint;
begin
  if (FCur = nil) or FReadOnly then Exit;
  S := FCur.FSyn;
  if S.SelAvail then P := S.BlockBegin else P := S.LogicalCaretXY;
  E := Point(Length(LineOf(S, LineTotal(S))) + 1, LineTotal(S));
  S.BeginUndoBlock;
  try
    S.TextBetweenPoints[P, E] := '';
  finally
    S.EndUndoBlock;
  end;
  S.LogicalCaretXY := P;
  S.BlockBegin := P;
end;

procedure TCsEditor.DeleteToStart;
var
  S: TCsSynEdit;
  E: TPoint;
begin
  if (FCur = nil) or FReadOnly then Exit;
  S := FCur.FSyn;
  if S.SelAvail then E := S.BlockEnd else E := S.LogicalCaretXY;
  S.BeginUndoBlock;
  try
    S.TextBetweenPoints[Point(1, 1), E] := '';
  finally
    S.EndUndoBlock;
  end;
  S.LogicalCaretXY := Point(1, 1);
  S.BlockBegin := Point(1, 1);
end;

{ Alt+↑・Alt+↓：対象の行と、上（下）の 1 行を入れ替える。カーソル・選択も一緒に動かす }
procedure TCsEditor.MoveLines(AUp: Boolean);
var
  S: TCsSynEdit;
  L1, L2, D: Integer;
  HadSel: Boolean;
  B, E, C: TPoint;
  Block, Other: string;
begin
  if (FCur = nil) or FReadOnly then Exit;
  S := FCur.FSyn;
  TargetLines(S, L1, L2);
  if AUp and (L1 <= 1) then Exit;
  if (not AUp) and (L2 >= S.Lines.Count) then Exit;
  HadSel := S.SelAvail;
  B := S.BlockBegin;
  E := S.BlockEnd;
  C := S.LogicalCaretXY;
  Block := JoinLines(S, L1, L2);
  S.BeginUndoBlock;
  try
    if AUp then
    begin
      Other := LineOf(S, L1 - 1);
      S.TextBetweenPoints[Point(1, L1 - 1), Point(Length(LineOf(S, L2)) + 1, L2)] := Block + LineEnding + Other;
      D := -1;
    end
    else
    begin
      Other := LineOf(S, L2 + 1);
      S.TextBetweenPoints[Point(1, L1), Point(Length(Other) + 1, L2 + 1)] := Other + LineEnding + Block;
      D := 1;
    end;
  finally
    S.EndUndoBlock;
  end;
  if HadSel then
  begin
    S.LogicalCaretXY := Point(C.X, C.Y + D);
    S.BlockBegin := Point(B.X, B.Y + D);
    S.BlockEnd := Point(E.X, E.Y + D);
  end
  else
  begin
    S.LogicalCaretXY := Point(C.X, C.Y + D);
    S.BlockBegin := S.LogicalCaretXY;
  end;
end;

{ Shift+Alt+↑・↓：対象の行を上・下に複製する。カーソルは、上なら元の位置、下なら複製した行 }
procedure TCsEditor.CopyLines(AUp: Boolean);
var
  S: TCsSynEdit;
  L1, L2, N: Integer;
  C, P: TPoint;
  Block: string;
begin
  if (FCur = nil) or FReadOnly then Exit;
  S := FCur.FSyn;
  TargetLines(S, L1, L2);
  N := L2 - L1 + 1;
  C := S.LogicalCaretXY;
  Block := JoinLines(S, L1, L2);
  S.BeginUndoBlock;
  try
    if AUp then
    begin
      P := Point(1, L1);
      S.TextBetweenPoints[P, P] := Block + LineEnding;
    end
    else
    begin
      P := Point(Length(LineOf(S, L2)) + 1, L2);
      S.TextBetweenPoints[P, P] := LineEnding + Block;
    end;
  finally
    S.EndUndoBlock;
  end;
  if AUp then S.LogicalCaretXY := C else S.LogicalCaretXY := Point(C.X, C.Y + N);
  S.BlockBegin := S.LogicalCaretXY;
end;

{ 言語の行コメントの書き方（6.4 の表）。無ければ APre = '' }
procedure CommentStyle(const ALanguage: string; out APre, ASuf: string);
var
  L: string;
begin
  L := LowerCase(ALanguage);
  APre := '';
  ASuf := '';
  if (L = 'pascal') or (L = 'javascript') or (L = 'json') or (L = 'typescript') or (L = 'cpp') or
     (L = 'csharp') or (L = 'java') or (L = 'php') or (L = 'go') then APre := '// '
  else if (L = 'python') or (L = 'shell') or (L = 'yaml') or (L = 'powershell') then APre := '# '
  else if L = 'sql' then APre := '-- '
  else if L = 'ini' then APre := '; '
  else if L = 'bat' then APre := 'REM '
  else if (L = 'html') or (L = 'xml') or (L = 'markdown') then
  begin
    APre := '<!-- ';
    ASuf := ' -->';
  end
  else if L = 'css' then
  begin
    APre := '/* ';
    ASuf := ' */';
  end;
end;

{ Ctrl+/：行コメントの切り替え（6.4） }
procedure TCsEditor.ToggleComment;
var
  S: TCsSynEdit;
  L1, L2, I, MinInd, K: Integer;
  Pre, Suf, PreT, SufT, Line, Ind, Body: string;
  AllOn, HadSel, AnyLine: Boolean;
  Res: TStringList;
  C: TPoint;
begin
  if (FCur = nil) or FReadOnly then Exit;
  S := FCur.FSyn;
  CommentStyle(FCur.FLanguage, Pre, Suf);
  if Pre = '' then Exit;
  PreT := TrimRight(Pre);
  SufT := TrimLeft(Suf);
  TargetLines(S, L1, L2);
  HadSel := S.SelAvail;
  C := S.LogicalCaretXY;
  { 空の行を除くすべてが、字下げの後ろがコメントの印で始まっていれば外す }
  AllOn := True;
  AnyLine := False;
  MinInd := MaxInt;
  for I := L1 to L2 do
  begin
    Line := LineOf(S, I);
    if Trim(Line) = '' then Continue;
    AnyLine := True;
    Ind := LeadingSpace(Line);
    if Length(Ind) < MinInd then MinInd := Length(Ind);
    Body := System.Copy(Line, Length(Ind) + 1, MaxInt);
    if not AnsiStartsStr(PreT, Body) then AllOn := False
    else if (SufT <> '') and not AnsiEndsStr(SufT, TrimRight(Body)) then AllOn := False;
  end;
  if not AnyLine then Exit;
  Res := TStringList.Create;
  try
    for I := L1 to L2 do
    begin
      Line := LineOf(S, I);
      if Trim(Line) = '' then
      begin
        Res.Add(Line);
        Continue;
      end;
      if AllOn then
      begin
        Ind := LeadingSpace(Line);
        Body := System.Copy(Line, Length(Ind) + 1, MaxInt);
        if AnsiStartsStr(Pre, Body) then Delete(Body, 1, Length(Pre))
        else Delete(Body, 1, Length(PreT));
        if SufT <> '' then
        begin
          Body := TrimRight(Body);
          if AnsiEndsStr(Suf, Body) then SetLength(Body, Length(Body) - Length(Suf))
          else SetLength(Body, Length(Body) - Length(SufT));
        end;
        Res.Add(Ind + Body);
      end
      else
      begin
        K := MinInd;
        Res.Add(System.Copy(Line, 1, K) + Pre + System.Copy(Line, K + 1, MaxInt) + Suf);
      end;
    end;
    Body := '';
    for I := 0 to Res.Count - 1 do
    begin
      if I > 0 then Body := Body + LineEnding;
      Body := Body + Res[I];
    end;
  finally
    Res.Free;
  end;
  S.BeginUndoBlock;
  try
    S.TextBetweenPoints[Point(1, L1), Point(Length(LineOf(S, L2)) + 1, L2)] := Body;
  finally
    S.EndUndoBlock;
  end;
  if HadSel then
  begin
    S.LogicalCaretXY := Point(Length(LineOf(S, L2)) + 1, L2);
    S.BlockBegin := Point(1, L1);
    S.BlockEnd := Point(Length(LineOf(S, L2)) + 1, L2);
  end
  else
  begin
    S.LogicalCaretXY := Point(Min(C.X, Length(LineOf(S, C.Y)) + 1), C.Y);
    S.BlockBegin := S.LogicalCaretXY;
  end;
end;

{ Ctrl+Enter：下に空の行を入れて、そこへ移る（字下げは今の行と同じ） }
procedure TCsEditor.InsertLineBelow;
var
  S: TCsSynEdit;
  C, P: TPoint;
  Ind: string;
begin
  if (FCur = nil) or FReadOnly then Exit;
  S := FCur.FSyn;
  C := S.LogicalCaretXY;
  Ind := LeadingSpace(LineOf(S, C.Y));
  P := Point(Length(LineOf(S, C.Y)) + 1, C.Y);
  S.BeginUndoBlock;
  try
    S.TextBetweenPoints[P, P] := LineEnding + Ind;
  finally
    S.EndUndoBlock;
  end;
  S.LogicalCaretXY := Point(Length(Ind) + 1, C.Y + 1);
  S.BlockBegin := S.LogicalCaretXY;
end;

{ 右クリックの変換（7章）：選択を変換した文字列に置き換え、置き換えた範囲を選び直す }
procedure TCsEditor.ConvertSelection(ACmd: Integer);
var
  S: TCsSynEdit;
  B, E, E2: TPoint;
  Src, R, Sp: string;
  I, N, LastBr: Integer;
begin
  if (FCur = nil) or FReadOnly then Exit;
  S := FCur.FSyn;
  if not S.SelAvail then Exit;
  B := S.BlockBegin;
  E := S.BlockEnd;
  Src := S.SelText;
  Sp := StringOfChar(' ', FTabSize);
  case ACmd of
    mcUpper: R := UTF8UpperCase(Src);
    mcLower: R := UTF8LowerCase(Src);
    mcHankaku: R := CMToHankaku(Src);
    mcHiragana: R := CMToZenkakuHiragana(Src);
    mcKatakana: R := CMToZenkakuKatakana(Src);
    mcDetab: R := StringReplace(Src, #9, Sp, [rfReplaceAll]);
    mcEntab: R := StringReplace(Src, Sp, #9, [rfReplaceAll]);
  else
    Exit;
  end;
  if R = Src then Exit;
  R := NormalizeBreaks(R, LineEnding);
  S.BeginUndoBlock;
  try
    S.TextBetweenPoints[B, E] := R;
  finally
    S.EndUndoBlock;
  end;
  { 置き換えた範囲の終わり }
  N := 0;
  LastBr := 0;
  for I := 1 to Length(R) do
    if R[I] = #10 then
    begin
      Inc(N);
      LastBr := I;
    end;
  if N = 0 then E2 := Point(B.X + Length(R), B.Y)
  else E2 := Point(Length(R) - LastBr + 1, B.Y + N);
  S.LogicalCaretXY := E2;
  S.BlockBegin := B;
  S.BlockEnd := E2;
end;

{ ================================================================== }
{ 右クリックメニュー（7章）                                           }
{ ================================================================== }

function TCsEditor.AddMenuItem(const ACaption: string; ACmd, AVis: Integer; ANeedEdit: Boolean): TCsMenuItem;
begin
  Result := TCsMenuItem.Create(FMenu);
  Result.Caption := ACaption;
  Result.Cmd := ACmd;
  Result.Vis := AVis;
  Result.NeedEdit := ANeedEdit;
  if ACaption <> '-' then Result.OnClick := @MenuClick;
  FMenu.Items.Add(Result);
end;

procedure TCsEditor.BuildMenu;
var
  MI: TMenuItem;
begin
  FMenu := TPopupMenu.Create(Self);
  FMenu.OnPopup := @MenuPopup;
  { TCMonacoEditor の取説 9.7 と同じ項目・同じ並び }
  AddMenuItem(CXT(sMnCut), mcCut, 1, True);
  AddMenuItem(CXT(sActCopyHint), mcCopy, 1, False);
  AddMenuItem(CXT(sActPasteHint), mcPaste, 2, True);
  AddMenuItem('-', mcSep, 1, False);
  AddMenuItem('-', mcSep, 3, False);
  AddMenuItem(CXT(sActSelectAllHint), mcSelectAll, 3, False);
  AddMenuItem(CXT(sActUndoHint), mcUndo, 3, True);
  AddMenuItem(CXT(sActRedoHint), mcRedo, 3, True);
  AddMenuItem(CXT(sMnQuoteCopy), mcQuoteCopy, 1, False);
  AddMenuItem(CXT(sMnAppendCut), mcAppendCut, 1, True);
  AddMenuItem(CXT(sMnAppendCopy), mcAppendCopy, 1, False);
  AddMenuItem('-', mcSep, 1, False);
  AddMenuItem(CXT(sMnDelete), mcDelete, 1, True);
  AddMenuItem('-', mcSep, 1, False);
  AddMenuItem('TO UPPER CASE', mcUpper, 1, True);
  AddMenuItem('to lower case', mcLower, 1, True);
  AddMenuItem('-', mcSep, 1, False);
  AddMenuItem(CXT(sMnToHalfKana), mcHankaku, 1, True);
  AddMenuItem(CXT(sMnToHiragana), mcHiragana, 1, True);
  AddMenuItem(CXT(sMnToKatakana), mcKatakana, 1, True);
  AddMenuItem('-', mcSep, 1, False);
  AddMenuItem(CXT(sMnTabToSpace), mcDetab, 1, True);
  AddMenuItem(CXT(sMnSpaceToTab), mcEntab, 1, True);
  AddMenuItem('-', mcSep, 1, False);
  AddMenuItem(CXT(sMnIndent), mcIndent, 1, True);
  AddMenuItem(CXT(sMnOutdent), mcOutdent, 1, True);
  { 選択の有無で変わらない項目（いつも出す） }
  MI := TMenuItem.Create(FMenu);
  MI.Caption := '-';
  FMenu.Items.Add(MI);
  FMnuMinimap := TMenuItem.Create(FMenu);
  FMnuMinimap.Caption := CXT(sMnMinimap);
  FMnuMinimap.ShortCut := ShortCut(VK_M, [ssCtrl, ssShift]);   { 表示用。キーは HandleKey }
  FMnuMinimap.OnClick := @MenuMinimapClick;
  FMenu.Items.Add(FMnuMinimap);
  FMnuPreview := TMenuItem.Create(FMenu);
  FMnuPreview.Caption := CXT(sMnPreview);
  FMnuPreview.ShortCut := ShortCut(VK_V, [ssCtrl, ssShift]);
  FMnuPreview.OnClick := @MenuPreviewClick;
  FMenu.Items.Add(FMnuPreview);
end;

{ 出す直前：選んでいるか・ReadOnly・Minimap・ShowPreview・Preview で、表示・使える・チェックを決める }
procedure TCsEditor.MenuPopup(Sender: TObject);
var
  I: Integer;
  HasSel: Boolean;
  M: TMenuItem;
begin
  HasSel := (FCur <> nil) and FCur.FSyn.SelAvail;
  for I := 0 to FMenu.Items.Count - 1 do
  begin
    M := FMenu.Items[I];
    if M is TCsMenuItem then
      with TCsMenuItem(M) do
      begin
        case Vis of
          1: Visible := HasSel;
          2: Visible := True;
          3: Visible := not HasSel;
        end;
        if NeedEdit then Enabled := not FReadOnly;
      end;
  end;
  FMnuMinimap.Checked := FMinimapOn;
  FMnuPreview.Checked := ShowPreview;
  FMnuPreview.Enabled := FPreview <> nil;
  if Assigned(FOnPopup) then FOnPopup(Self);
end;

procedure TCsEditor.MenuClick(Sender: TObject);
var
  S: TCsSynEdit;
  T, R: string;
  L: TStringList;
  I: Integer;
begin
  if FCur = nil then Exit;
  S := FCur.FSyn;
  case TCsMenuItem(Sender).Cmd of
    mcCut: Cut;
    mcCopy: Copy;
    mcPaste: Paste;
    mcSelectAll: SelectAll;
    mcUndo: Undo;
    mcRedo: Redo;
    mcQuoteCopy:
      begin
        { 選択の各行の先頭に QuotePrefix を付ける（最後の改行は保つ） }
        T := NormalizeBreaks(S.SelText, #10);
        L := TStringList.Create;
        try
          L.StrictDelimiter := True;
          L.Delimiter := #10;
          L.DelimitedText := T;
          R := '';
          for I := 0 to L.Count - 1 do
          begin
            if I > 0 then R := R + LineEnding;
            if (I = L.Count - 1) and (L[I] = '') then Continue;
            R := R + FQuotePrefix + L[I];
          end;
        finally
          L.Free;
        end;
        Clipboard.AsText := R;
      end;
    mcAppendCut:
      if not FReadOnly then
      begin
        Clipboard.AsText := Clipboard.AsText + S.SelText;
        S.ClearSelection;
      end;
    mcAppendCopy:
      Clipboard.AsText := Clipboard.AsText + S.SelText;
    mcDelete:
      if not FReadOnly then S.ClearSelection;
    mcUpper, mcLower, mcHankaku, mcHiragana, mcKatakana, mcDetab, mcEntab:
      ConvertSelection(TCsMenuItem(Sender).Cmd);
    mcIndent:
      if not FReadOnly then S.ExecuteCommand(ecBlockIndent, '', nil);
    mcOutdent:
      if not FReadOnly then S.ExecuteCommand(ecBlockUnindent, '', nil);
  end;
end;

procedure TCsEditor.MenuMinimapClick(Sender: TObject);
begin
  Minimap := not Minimap;
end;

procedure TCsEditor.MenuPreviewClick(Sender: TObject);
begin
  if FPreview <> nil then ShowPreview := not ShowPreview;
end;

{ ================================================================== }
{ 検索・置換（8.2）                                                   }
{ ================================================================== }

function TCsEditor.CurrentFindDialog(ACreate: Boolean): TCsFindDialog;
begin
  Result := FFindDialog;
  if Result <> nil then Exit;
  if FHook = nil then
  begin
    if not ACreate then Exit;
    RegisterWithForm;
  end;
  if FHook <> nil then
  begin
    if ACreate or (FHook.FFindDialog <> nil) then Result := FHook.SharedFindDialog;
  end;
end;

function TCsEditor.GetSearchOptions: TCMFindOptions;
begin
  Result := FSearchOptions;
end;

procedure TCsEditor.ShowFindDialog(const InitialText: string);
var
  D: TCsFindDialog;
begin
  D := CurrentFindDialog(True);
  if D <> nil then D.ShowFor(Self, InitialText);
end;

procedure TCsEditor.Find(const S: string; AOptions: TCMFindOptions; AForward: Boolean);
var
  Syn: TCsSynEdit;
  Opt: TSynSearchOptions;
  Start: TPoint;
  N: Integer;
  B, E: TPoint;
  D: TCsFindDialog;
begin
  if (FCur = nil) or (S = '') then Exit;
  FSearchText := S;
  FSearchOptions := AOptions;
  Syn := FCur.FSyn;
  Opt := [];
  if foMatchCase in AOptions then Include(Opt, ssoMatchCase);
  if foWholeWord in AOptions then Include(Opt, ssoWholeWord);
  if not AForward then Include(Opt, ssoBackwards);
  { 次へは選択の終わりから、前へは選択の始まりから }
  if Syn.SelAvail then
  begin
    if AForward then Start := Syn.BlockEnd else Start := Syn.BlockBegin;
  end
  else
    Start := Syn.LogicalCaretXY;
  N := Syn.SearchReplaceEx(S, '', Opt, Start);
  if (N = 0) and (foLoop in AOptions) then
  begin
    { 見つからない：先頭（前へは末尾）からもう一度 }
    if AForward then Start := Point(1, 1)
    else Start := Point(Length(LineOf(Syn, LineTotal(Syn))) + 1, LineTotal(Syn));
    N := Syn.SearchReplaceEx(S, '', Opt, Start);
  end;
  if N > 0 then
  begin
    { 見つかった範囲を選び、カーソルは終わりに置く（向きによらず同じ） }
    B := Syn.BlockBegin;
    E := Syn.BlockEnd;
    Syn.LogicalCaretXY := E;
    Syn.BlockBegin := B;
    Syn.BlockEnd := E;
    Syn.EnsureCursorPosVisible;
  end;
  if Assigned(FOnFindDone) then FOnFindDone(Self, N > 0);
  D := CurrentFindDialog(False);
  if D <> nil then D.NotifyFindDone(Self, N > 0);
end;

procedure TCsEditor.FindNext;
begin
  if FSearchText = '' then ShowFindDialog else Find(FSearchText, FSearchOptions, True);
end;

procedure TCsEditor.FindPrev;
begin
  if FSearchText = '' then ShowFindDialog else Find(FSearchText, FSearchOptions, False);
end;

procedure TCsEditor.Replace(const S, R: string; AOptions: TCMFindOptions);
var
  Syn: TCsSynEdit;
  Sel: string;
  Same: Boolean;
begin
  if (FCur = nil) or FReadOnly or (S = '') then Exit;
  Syn := FCur.FSyn;
  Sel := Syn.SelText;
  if foMatchCase in AOptions then Same := Sel = S else Same := UTF8LowerCase(Sel) = UTF8LowerCase(S);
  if Syn.SelAvail and Same then
  begin
    Syn.BeginUndoBlock;
    try
      Syn.SelText := R;
    finally
      Syn.EndUndoBlock;
    end;
    Syn.BlockBegin := Syn.LogicalCaretXY;
  end;
  Find(S, AOptions, True);
end;

procedure TCsEditor.ReplaceAll(const S, R: string; AOptions: TCMFindOptions);
var
  Syn: TCsSynEdit;
  Opt: TSynSearchOptions;
  N: Integer;
  D: TCsFindDialog;
begin
  if (FCur = nil) or FReadOnly or (S = '') then Exit;
  FSearchText := S;
  FReplaceText := R;
  FSearchOptions := AOptions;
  Syn := FCur.FSyn;
  Opt := [ssoReplace, ssoReplaceAll, ssoEntireScope];
  if foMatchCase in AOptions then Include(Opt, ssoMatchCase);
  if foWholeWord in AOptions then Include(Opt, ssoWholeWord);
  Syn.BeginUndoBlock;
  try
    N := Syn.SearchReplace(S, R, Opt);
  finally
    Syn.EndUndoBlock;
  end;
  if Assigned(FOnReplaceAllDone) then FOnReplaceAllDone(Self, N);
  D := CurrentFindDialog(False);
  if D <> nil then D.NotifyReplaceAllDone(Self, N);
end;

{ ================================================================== }
{ プロパティ                                                          }
{ ================================================================== }

procedure TCsEditor.SetMultiDocument(AValue: Boolean);
begin
  { 設計時と、作ってから表示されるまでだけ変えられる（4.5） }
  if (csLoading in ComponentState) or (csDesigning in ComponentState) or not HandleAllocated then
    FMultiDocument := AValue;
end;

procedure TCsEditor.SetOpenDialog(AValue: TOpenDialog);
begin
  if FOpenDialog = AValue then Exit;
  if FOpenDialog <> nil then FOpenDialog.RemoveFreeNotification(Self);
  FOpenDialog := AValue;
  if FOpenDialog <> nil then FOpenDialog.FreeNotification(Self);
end;

procedure TCsEditor.SetSaveDialog(AValue: TSaveDialog);
begin
  if FSaveDialog = AValue then Exit;
  if FSaveDialog <> nil then FSaveDialog.RemoveFreeNotification(Self);
  FSaveDialog := AValue;
  if FSaveDialog <> nil then FSaveDialog.FreeNotification(Self);
end;

procedure TCsEditor.SetFindDialog(AValue: TCsFindDialog);
begin
  if FFindDialog = AValue then Exit;
  if FFindDialog <> nil then FFindDialog.RemoveFreeNotification(Self);
  FFindDialog := AValue;
  if FFindDialog <> nil then FFindDialog.FreeNotification(Self);
end;

procedure TCsEditor.SetTabFlat(AValue: Boolean);
begin
  FTabFlat := AValue;
  ApplyTabShape;
end;

procedure TCsEditor.SetTabSeparator(AValue: Boolean);
begin
  FTabSeparator := AValue;
  ApplyTabShape;
end;

procedure TCsEditor.SetTabIcons(AValue: Boolean);
begin
  FTabIcons := AValue;
  ApplyTabIcons;
end;

procedure TCsEditor.SetTabImages(AValue: TImageList);
begin
  if FTabImages = AValue then Exit;
  if FTabImages <> nil then FTabImages.RemoveFreeNotification(Self);
  FTabImages := AValue;
  if FTabImages <> nil then FTabImages.FreeNotification(Self);
  ApplyTabIcons;
end;

procedure TCsEditor.SetWordWrap(AValue: Boolean);
var
  I: Integer;
begin
  FWordWrap := AValue;
  if (FPages = nil) or (csLoading in ComponentState) then Exit;
  for I := 0 to FPages.Count - 1 do TCsPage(FPages[I]).FSyn.SetWrap(AValue);
  UpdateVBar;
end;

procedure TCsEditor.SetLineNumbers(AValue: Boolean);
var
  I: Integer;
begin
  FLineNumbers := AValue;
  if (FPages = nil) or (csLoading in ComponentState) then Exit;
  for I := 0 to FPages.Count - 1 do TCsPage(FPages[I]).FSyn.Gutter.LineNumberPart.Visible := AValue;
end;

function TCsEditor.GetFontSize: Integer;
begin
  Result := Font.Size;
end;

procedure TCsEditor.SetFontSize(AValue: Integer);
begin
  Font.Size := EnsureRange(AValue, 6, 72);      { 全タブへは FontChanged で渡す }
end;

procedure TCsEditor.SetTabSize(AValue: Integer);
var
  I: Integer;
begin
  FTabSize := EnsureRange(AValue, 1, 16);
  if (FPages = nil) or (csLoading in ComponentState) then Exit;
  for I := 0 to FPages.Count - 1 do
    with TCsPage(FPages[I]).FSyn do
    begin
      TabWidth := FTabSize;
      BlockIndent := FTabSize;
      BlockTabIndent := 0;
    end;
  if (FMinimap <> nil) and FMinimap.Visible then FMinimap.Rebuild;
end;

procedure TCsEditor.SetFolding(AValue: Boolean);
begin
  FFolding := AValue;
  if not (csLoading in ComponentState) then ApplyAllOptions;
end;

procedure TCsEditor.SetMatchBrackets(AValue: Boolean);
begin
  FMatchBrackets := AValue;
  if not (csLoading in ComponentState) then ApplyAllOptions;
end;

procedure TCsEditor.SetOccurrencesHighlight(AValue: Boolean);
begin
  FOccurrencesHighlight := AValue;
  if not (csLoading in ComponentState) then ApplyAllOptions;
end;

procedure TCsEditor.SetMinimap(AValue: Boolean);
begin
  FMinimapOn := AValue;
  if (FMinimap = nil) or (csLoading in ComponentState) then Exit;
  FMinimap.Width := Scale96ToForm(120);
  FMinimap.Visible := AValue;
  ApplyBarsLayout;
  if AValue then FMinimap.Rebuild;
end;

{ 10.5：ミニマップとスクロールバーを出す・隠し、全タブの中の部品の縦のスクロールバーを切り替える }
procedure TCsEditor.ApplyBarsLayout;
var
  I: Integer;
begin
  if (FVBar = nil) or (FPages = nil) then Exit;
  for I := 0 to FPages.Count - 1 do
    with TCsPage(FPages[I]).FSyn do
      if FMinimapOn then ScrollBars := ssAutoHorizontal else ScrollBars := ssAutoBoth;
  FVBar.Visible := FMinimapOn;
  if FMinimapOn then
  begin
    { alRight の部品は位置の順に並ぶ。スクロールバーを一番右、ミニマップをその左にする }
    FMinimap.Left := 0;
    FVBar.Left := Width;
    UpdateVBar;
  end;
end;

{ 10.5：見えているタブの、表示の行で合わせ直す }
procedure TCsEditor.UpdateVBar;
var
  S: TCsSynEdit;
  N, V: Integer;
begin
  if (FVBar = nil) or not FVBar.Visible or (FCur = nil) or (FCur.FSyn = nil) then Exit;
  S := FCur.FSyn;
  N := S.ViewLineCount;
  V := Max(1, S.LinesInWindow);
  FUpdatingBar := True;
  try
    FVBar.SetParams(EnsureRange(S.GetViewTop, 1, N), 1, N + V - 1, V);
  finally
    FUpdatingBar := False;
  end;
  ApplyBarTheme(FVBar, IsDarkTheme);
end;

procedure TCsEditor.VBarChange(Sender: TObject);
begin
  if FUpdatingBar or (FCur = nil) or (FCur.FSyn = nil) then Exit;
  FCur.FSyn.SetViewTop(FVBar.Position);
end;

procedure TCsEditor.Resize;
begin
  inherited Resize;
  UpdateVBar;
end;

procedure TCsEditor.SetTheme(AValue: TCMTheme);
begin
  FTheme := AValue;
  if not (csLoading in ComponentState) then ApplyTheme;
end;

procedure TCsEditor.SetReadOnly(AValue: Boolean);
var
  I: Integer;
begin
  FReadOnly := AValue;
  if FPages = nil then Exit;
  for I := 0 to FPages.Count - 1 do TCsPage(FPages[I]).FSyn.ReadOnly := AValue;
end;

procedure TCsEditor.SetDefaultLanguage(const AValue: string);
begin
  if AValue = '' then FDefaultLanguage := 'pascal' else FDefaultLanguage := AValue;
end;

function TCsEditor.IsDefaultLanguageStored: Boolean;
begin
  Result := FDefaultLanguage <> 'pascal';
end;

function TCsEditor.IsQuotePrefixStored: Boolean;
begin
  Result := FQuotePrefix <> '> ';
end;

procedure TCsEditor.SetHitColorLight(AValue: TColor);
begin
  FHitColorLight := AValue;
  if not (csLoading in ComponentState) then ApplyTheme;
end;

procedure TCsEditor.SetHitColorDark(AValue: TColor);
begin
  FHitColorDark := AValue;
  if not (csLoading in ComponentState) then ApplyTheme;
end;

procedure TCsEditor.SetCursorLineColorLight(AValue: TColor);
begin
  FCursorLineColorLight := AValue;
  if not (csLoading in ComponentState) then ApplyTheme;
end;

procedure TCsEditor.SetCursorLineColorDark(AValue: TColor);
begin
  FCursorLineColorDark := AValue;
  if not (csLoading in ComponentState) then ApplyTheme;
end;

procedure TCsEditor.SetSelectionColorStyle(AValue: TCMSelectionColorStyle);
begin
  FSelectionColorStyle := AValue;
  if AValue = scCustom then Exit;               { 色は変えない }
  FSelectionColorDark := SelStyleDark[AValue];
  FSelectionColorLight := SelStyleLight[AValue];
  if not (csLoading in ComponentState) then ApplyTheme;
end;

procedure TCsEditor.SetSelectionColorLight(AValue: TColor);
begin
  FSelectionColorLight := AValue;
  if not (csLoading in ComponentState) then
  begin
    FSelectionColorStyle := scCustom;
    ApplyTheme;
  end;
end;

procedure TCsEditor.SetSelectionColorDark(AValue: TColor);
begin
  FSelectionColorDark := AValue;
  if not (csLoading in ComponentState) then
  begin
    FSelectionColorStyle := scCustom;
    ApplyTheme;
  end;
end;

function TCsEditor.IsSelColorStored: Boolean;
begin
  Result := FSelectionColorStyle = scCustom;
end;

{ ---------- プレビュー（9章） ---------- }

function TCsEditor.GetShowPreview: Boolean;
begin
  if FPreview = nil then Exit(False);
  if (csDesigning in ComponentState) or (csLoading in ComponentState) then Exit(FShowPreview);
  Result := FPreview.Visible;
end;

procedure TCsEditor.SetShowPreview(AValue: Boolean);
begin
  FShowPreview := AValue;
  if (csDesigning in ComponentState) or (csLoading in ComponentState) or (FPreview = nil) then Exit;
  if AValue then
  begin
    FPreview.SetSource(Self);
    FPreview.Visible := True;
  end
  else
    FPreview.Visible := False;
end;

procedure TCsEditor.SetPreview(AValue: TCPreview);
begin
  if FPreview = AValue then Exit;
  if FPreview <> nil then
  begin
    if not (csDesigning in ComponentState) and not (csLoading in ComponentState) then
      FPreview.SourceRemoved(Self);
    FPreview.RemoveFreeNotification(Self);
  end;
  FPreview := AValue;
  if FPreview <> nil then
  begin
    FPreview.FreeNotification(Self);
    { ed.AllowRemoteImages で覚えていた値を入れる（.lfm の読み込み中は Loaded で入れる） }
    if not (csLoading in ComponentState) and not (csDesigning in ComponentState) then
      FPreview.AllowRemoteImages := FAllowRemoteImages;
  end;
end;

function TCsEditor.GetAllowRemoteImages: Boolean;
begin
  if (FPreview <> nil) and not (csDesigning in ComponentState) and not (csLoading in ComponentState) then
    Result := FPreview.AllowRemoteImages
  else
    Result := FAllowRemoteImages;
end;

procedure TCsEditor.SetAllowRemoteImages(AValue: Boolean);
begin
  FAllowRemoteImages := AValue;
  if (FPreview <> nil) and not (csDesigning in ComponentState) and not (csLoading in ComponentState) then
    FPreview.AllowRemoteImages := AValue;
end;

{ ================================================================== }
{ 同じフォームの別の TCsEditor へタブを移す（4.12）・分離と結合（4.11） }
{ ================================================================== }

const
  TearOffMark = 'CSTEAROFF1';     { 一時ファイルの 1 行目（目印） }
  TearOffEnv = 'CS_TEAROFF';      { 一時ファイルの場所を渡す環境変数 }
  CS_CREATE_UNICODE_ENVIRONMENT = $00000400;
  CS_GA_ROOT = 2;
  CS_PROCESS_QUERY_LIMITED_INFORMATION = $1000;
  CS_SMTO_ABORTIFHUNG = $0002;
  CS_MERGE_MAGIC = $4353544F;     { WM_COPYDATA の dwData（'CSTO'） }
  CS_MERGE_TIMEOUT = 3000;
  ReceiverClassName = 'CSEditorReceiver';

function CSGetAncestor(AWnd: HWND; AFlags: UINT): HWND; stdcall;
  external 'user32.dll' name 'GetAncestor';
function CSFindWindowExW(AParent, AChildAfter: HWND; AClass, AWindow: PWideChar): HWND; stdcall;
  external 'user32.dll' name 'FindWindowExW';
function CSSendMessageTimeoutW(AWnd: HWND; AMsg: UINT; AWParam: WPARAM; ALParam: LPARAM;
  AFlags, ATimeout: UINT; AResult: PPtrUInt): LRESULT; stdcall;
  external 'user32.dll' name 'SendMessageTimeoutW';
function CSAllowSetForegroundWindow(AProcessId: DWORD): BOOL; stdcall;
  external 'user32.dll' name 'AllowSetForegroundWindow';
function CSQueryFullProcessImageNameW(AProcess: THandle; AFlags: DWORD; AExeName: PWideChar;
  var ASize: DWORD): BOOL; stdcall; external 'kernel32.dll' name 'QueryFullProcessImageNameW';

var
  GTearOffRead: Boolean = False;
  GTearOffFile: string = '';
  GTearOffClaimed: Boolean = False;

{ 画面の位置 P が、自分のアプリのウィンドウの上ではないか }
function IsOutsideApp(const P: TPoint): Boolean;
var
  W, Root: HWND;
  Pid: DWORD;
begin
  W := Windows.WindowFromPoint(P);
  if W = 0 then Exit(True);
  Root := CSGetAncestor(W, CS_GA_ROOT);
  if Root = 0 then Root := W;
  Pid := 0;
  Windows.GetWindowThreadProcessId(Root, @Pid);
  Result := Pid <> Windows.GetCurrentProcessId;
end;

{ マウスの左ボタン（左右を入れ替えていれば右）が押されているか（Esc で取り消したドラッグを除くため） }
function MainButtonDown: Boolean;
var
  VK: Integer;
begin
  if Windows.GetSystemMetrics(SM_SWAPBUTTON) <> 0 then VK := VK_RBUTTON else VK := VK_LBUTTON;
  Result := (Windows.GetAsyncKeyState(VK) and $8000) <> 0;
end;

{ 分離で起動されたときの一時ファイル。最初に 1 回だけ環境変数を読み、すぐに消す }
function TearOffFile: string;
var
  Buf: array[0..32767] of WideChar;
  N: DWORD;
begin
  if not GTearOffRead then
  begin
    GTearOffRead := True;
    N := Windows.GetEnvironmentVariableW(PWideChar(UnicodeString(TearOffEnv)), @Buf[0], Length(Buf));
    if (N > 0) and (N < Length(Buf)) then
    begin
      GTearOffFile := UTF8Encode(UnicodeString(PWideChar(@Buf[0])));
      Windows.SetEnvironmentVariableW(PWideChar(UnicodeString(TearOffEnv)), nil);
    end;
  end;
  Result := GTearOffFile;
end;

{ 一時ファイルを書く（UTF-8）。1 行目が目印、空の行までが見出し（名前=値）、その後ろが本文 }
procedure WriteTearOffFile(const AFile: string; AHead: TStrings; const ABody: string);
var
  S: string;
  I: Integer;
  FS: TFileStream;
begin
  S := TearOffMark + #13#10;
  for I := 0 to AHead.Count - 1 do S := S + AHead[I] + #13#10;
  S := S + #13#10 + ABody;
  FS := TFileStream.Create(AFile, fmCreate);
  try
    if S <> '' then FS.WriteBuffer(S[1], Length(S));
  finally
    FS.Free;
  end;
end;

function ReadTearOffFile(const AFile: string; AHead: TStrings; out ABody: string): Boolean;
var
  FS: TFileStream;
  S: string;
  P, Q: Integer;
begin
  Result := False;
  ABody := '';
  AHead.Clear;
  try
    FS := TFileStream.Create(AFile, fmOpenRead or fmShareDenyNone);
    try
      SetLength(S, FS.Size);
      if S <> '' then FS.ReadBuffer(S[1], Length(S));
    finally
      FS.Free;
    end;
  except
    Exit;
  end;
  P := Pos(#13#10, S);
  if (P = 0) or (System.Copy(S, 1, P - 1) <> TearOffMark) then Exit;
  Inc(P, 2);
  while True do
  begin
    Q := PosEx(#13#10, S, P);
    if Q = 0 then Exit;
    if Q = P then Break;
    AHead.Add(System.Copy(S, P, Q - P));
    P := Q + 2;
  end;
  ABody := System.Copy(S, P + 2, MaxInt);
  Result := True;
end;

function ProcessExePath(APid: DWORD): string;
var
  H: THandle;
  Buf: array[0..32767] of WideChar;
  N: DWORD;
begin
  Result := '';
  H := Windows.OpenProcess(CS_PROCESS_QUERY_LIMITED_INFORMATION, False, APid);
  if H = 0 then Exit;
  try
    N := Length(Buf);
    if CSQueryFullProcessImageNameW(H, 0, @Buf[0], N) then
      Result := UTF8Encode(UnicodeString(PWideChar(@Buf[0])));
  finally
    Windows.CloseHandle(H);
  end;
end;

{ (X, Y) の下が「同じ EXE の別のウィンドウ」なら、そのプロセスの受け口を返す（見えないトップレベルのウィンドウ） }
function FindMergeReceiver(X, Y: Integer; out APid: DWORD): HWND;
var
  W, Root: HWND;
  Pid: DWORD;
  MyPath, Path: string;
begin
  Result := 0;
  APid := 0;
  W := Windows.WindowFromPoint(Point(X, Y));
  if W = 0 then Exit;
  Root := CSGetAncestor(W, CS_GA_ROOT);
  if Root = 0 then Root := W;
  Windows.GetWindowThreadProcessId(Root, @APid);
  if (APid = 0) or (APid = Windows.GetCurrentProcessId) then Exit;
  MyPath := ProcessExePath(Windows.GetCurrentProcessId);
  Path := ProcessExePath(APid);
  if (MyPath = '') or (Path = '') or not SameText(MyPath, Path) then Exit;
  W := 0;
  repeat
    W := CSFindWindowExW(0, W, PWideChar(UnicodeString(ReceiverClassName)), nil);
    if W = 0 then Break;
    Pid := 0;
    Windows.GetWindowThreadProcessId(W, @Pid);
    if Pid = APid then Exit(W);
  until False;
end;

{ 受け口のウィンドウ手続き。
  WM_COPYDATA（'CSTO'）：結合を受ける。返事 1＝受け取った 2＝同じファイルを開いている 0＝受け取らない。
  WM_SETTINGCHANGE（'ImmersiveColorSet'）：OS のテーマが変わった（4.7） }
function ReceiverWndProc(AWnd: HWND; AMsg: UINT; AWParam: WPARAM; ALParam: LPARAM): LRESULT; stdcall;
var
  CDS: PCopyDataStruct;
  U: UnicodeString;
  Parts, Head: TStringList;
  Body, FN, FileN: string;
  X, Y, I, Idx: Integer;
  E, Target: TCsEditor;
  P: TPoint;
  Root: HWND;
begin
  if AMsg = WM_SETTINGCHANGE then
  begin
    if (ALParam <> 0) and (WideCompareText(PWideChar(ALParam), 'ImmersiveColorSet') = 0) and (GEditors <> nil) then
      for I := 0 to GEditors.Count - 1 do
        Application.QueueAsyncCall(@TCsEditor(GEditors[I]).AsyncOsTheme, 0);
    Exit(Windows.DefWindowProcW(AWnd, AMsg, AWParam, ALParam));
  end;
  if AMsg <> WM_COPYDATA then Exit(Windows.DefWindowProcW(AWnd, AMsg, AWParam, ALParam));
  Result := 0;
  CDS := PCopyDataStruct(ALParam);
  if (CDS = nil) or (CDS^.dwData <> CS_MERGE_MAGIC) or (CDS^.lpData = nil) then Exit;
  try
    SetString(U, PWideChar(CDS^.lpData), CDS^.cbData div SizeOf(WideChar));
    Parts := TStringList.Create;
    Head := TStringList.Create;
    try
      Parts.Delimiter := #10;
      Parts.StrictDelimiter := True;
      Parts.DelimitedText := UTF8Encode(U);
      if Parts.Count < 3 then Exit;
      FN := Parts[0];
      X := StrToIntDef(Parts[1], 0);
      Y := StrToIntDef(Parts[2], 0);
      if not ReadTearOffFile(FN, Head, Body) then Exit;
      Target := nil;
      Root := CSGetAncestor(Windows.WindowFromPoint(Point(X, Y)), CS_GA_ROOT);
      for I := 0 to GEditors.Count - 1 do
      begin
        E := TCsEditor(GEditors[I]);
        if (csDestroying in E.ComponentState) or not E.Showing or not E.HandleAllocated then Continue;
        P := E.ScreenToClient(Point(X, Y));
        if not PtInRect(E.ClientRect, P) then Continue;
        if CSGetAncestor(E.Handle, CS_GA_ROOT) <> Root then Continue;
        Target := E;
        Break;
      end;
      if Target = nil then Exit;
      if not Target.FTabTearOff or not Target.FMultiDocument then Exit;
      FileN := Head.Values['FileName'];
      if FileN <> '' then
      begin
        Idx := Target.FindPage(FileN);
        if Idx >= 0 then
        begin
          Target.ActiveIndex := Idx;
          Application.QueueAsyncCall(@Target.AsyncBringFront, 0);
          Exit(2);
        end;
      end;
      Target.FMergeQueue.Add(FN);
      Application.QueueAsyncCall(@Target.AsyncMerge, 0);
      Result := 1;
    finally
      Head.Free;
      Parts.Free;
    end;
  except
    Result := 0;
  end;
end;

{ 受け口を作る（プロセスに 1 つ）。OS のテーマの知らせはトップレベルのウィンドウにしか届かないため、
  見えないトップレベルのウィンドウ（WS_POPUP、表示しない、持ち主なし）にする }
procedure EnsureReceiver;
var
  WC: Windows.TWndClassW;
begin
  if GReceiverWnd <> 0 then Exit;
  if not GReceiverClassOk then
  begin
    FillChar(WC, SizeOf(WC), 0);
    WC.lpfnWndProc := @ReceiverWndProc;
    WC.hInstance := System.HInstance;
    WC.lpszClassName := PWideChar(UnicodeString(ReceiverClassName));
    GReceiverClassOk := Windows.RegisterClassW(WC) <> 0;
    if not GReceiverClassOk then Exit;
  end;
  GReceiverWnd := Windows.CreateWindowExW(WS_EX_TOOLWINDOW, PWideChar(UnicodeString(ReceiverClassName)), nil,
    WS_POPUP, 0, 0, 0, 0, 0, 0, System.HInstance, nil);
end;

function TCsEditor.TearOffName: string;
begin
  if Owner <> nil then Result := Owner.Name + '.' + Name else Result := Name;
end;

{ 離した位置の部品から、TCsEditor をたどる }
function EditorAt(ATarget: TObject; const P: TPoint): TCsEditor;
var
  C: TControl;
begin
  Result := nil;
  if ATarget is TControl then C := TControl(ATarget) else C := FindControlAtPosition(P, False);
  while C <> nil do
  begin
    if C is TCsEditor then Exit(TCsEditor(C));
    C := C.Parent;
  end;
end;

{ タブのドラッグの終わり：同じフォームの別の TCsEditor の上なら移す（4.12）。アプリの外なら分離（4.11） }
procedure TCsEditor.TabsEndDrag(Sender, Target: TObject; X, Y: Integer);
var
  P: TPoint;
  Dest: TCsEditor;
begin
  Screen.Cursor := crDefault;
  if (FTabs = nil) or not FTabs.Visible or (FCur = nil) then Exit;
  if MainButtonDown then Exit;                     { Esc で取り消した }
  P := Mouse.CursorPos;
  Dest := EditorAt(Target, P);
  if (Dest <> nil) and (Dest <> Self) and (GetParentForm(Dest) = GetParentForm(Self)) then
  begin
    FMovePage := FCur;
    FMoveDest := Dest;
    Application.QueueAsyncCall(@AsyncMoveTab, 0);
    Exit;
  end;
  if Target <> nil then Exit;
  if not IsOutsideApp(P) then Exit;
  FDragOutPage := FCur;
  FDragOutPos := P;
  Application.QueueAsyncCall(@AsyncTabDragOut, 0);
end;

procedure TCsEditor.AsyncMoveTab(Data: PtrInt);
var
  P: TCsPage;
  D: TCsEditor;
begin
  P := FMovePage;
  D := FMoveDest;
  FMovePage := nil;
  FMoveDest := nil;
  if (P = nil) or (D = nil) or (FPages.IndexOf(P) < 0) then Exit;
  if (GEditors = nil) or (GEditors.IndexOf(D) < 0) then Exit;       { 相手がその間に壊された }
  MovePageTo(P, D);
end;

{ ページを中の部品ごと相手のエディタへ移す（Undo の履歴・カーソル位置も残る） }
procedure TCsEditor.MovePageTo(P: TCsPage; ADest: TCsEditor);
var
  S: TCsSynEdit;
  I: Integer;
begin
  if not ADest.FMultiDocument then Exit;
  if (FPages.Count = 1) and (P.FFileName = '') and (P.GetText = '') then Exit;   { 何も入っていない無題 }
  if P.FFileName <> '' then
  begin
    I := ADest.FindPage(P.FFileName);
    if I >= 0 then
    begin
      ADest.ActiveIndex := I;
      ADest.SetFocus;
      Exit;
    end;
  end;
  S := P.FSyn;
  { 1. 元のエディタから外す（中の部品は壊さない） }
  RemovePage(P);
  FAllPages.Remove(P);
  { 2. 中の部品を相手へ }
  RemoveComponent(S);
  ADest.InsertComponent(S);
  S.Parent := ADest;
  S.FEditor := ADest;
  S.PopupMenu := ADest.FMenu;
  S.Visible := False;
  { 3. ページを相手へ }
  P.FOwner := ADest;
  ADest.FPages.Add(P);
  ADest.FAllPages.Add(P);
  { 4. 相手の設定を渡す }
  ADest.ApplyOptionsTo(S, False);
  { 5. 相手：タブを作り直し、移したタブを見えるタブにしてフォーカス }
  ADest.RebuildTabs;
  ADest.DoDocListChange;
  ADest.SetCurPage(P);
  ADest.SetFocus;
end;

{ タブがウィンドウの外へ落とされた：OnTabDragOut を呼び、TearOff が True のままなら分離する }
procedure TCsEditor.AsyncTabDragOut(Data: PtrInt);
var
  P: TCsPage;
  TearOff: Boolean;
  I: Integer;
begin
  P := FDragOutPage;
  FDragOutPage := nil;
  if (P = nil) or (FPages.IndexOf(P) < 0) then Exit;
  TearOff := FTabTearOff;
  if (FPages.Count = 1) and (P.FFileName = '') and (P.GetText = '') then TearOff := False;
  I := FPages.IndexOf(P);
  if Assigned(FOnTabDragOut) then FOnTabDragOut(Self, I, FDragOutPos.X, FDragOutPos.Y, TearOff);
  if not TearOff then Exit;
  if FPages.IndexOf(P) < 0 then Exit;            { イベントの中で閉じられた }
  SendTearOff(P, FDragOutPos.X, FDragOutPos.Y);
end;

function TCsEditor.MakeTearOffFile(P: TCsPage; X, Y: Integer; out AFile: string): Boolean;
var
  Head: TStringList;
begin
  Result := False;
  AFile := GetTempFileName(GetTempDir, 'cst');
  Head := TStringList.Create;
  try
    Head.Add('Editor=' + TearOffName);
    Head.Add('FileName=' + P.FFileName);
    Head.Add('Encoding=' + IntToStr(Ord(P.FEncoding)));
    Head.Add('Language=' + P.FLanguage);
    Head.Add('Modified=' + IntToStr(Ord(P.Modified)));
    if P.FLineBreak = #10 then Head.Add('LineBreak=LF') else Head.Add('LineBreak=CRLF');
    Head.Add('X=' + IntToStr(X));
    Head.Add('Y=' + IntToStr(Y));
    try
      WriteTearOffFile(AFile, Head, P.GetText);
      Result := True;
    except
      on E: Exception do
      begin
        DeleteFile(AFile);
        DoError(CXT(sErrOpenOtherWindow) + E.Message);
      end;
    end;
  finally
    Head.Free;
  end;
end;

function TCsEditor.TryMerge(P: TCsPage; X, Y: Integer): Boolean;
var
  Recv: HWND;
  Pid: DWORD;
  FN: string;
  U: UnicodeString;
  CDS: TCopyDataStruct;
  Res: PtrUInt;
begin
  Result := False;
  Recv := FindMergeReceiver(X, Y, Pid);
  if Recv = 0 then Exit;
  Result := True;
  if not MakeTearOffFile(P, X, Y, FN) then Exit;
  U := UTF8Decode(FN + #10 + IntToStr(X) + #10 + IntToStr(Y));
  FillChar(CDS, SizeOf(CDS), 0);
  CDS.dwData := CS_MERGE_MAGIC;
  CDS.cbData := (Length(U) + 1) * SizeOf(WideChar);
  CDS.lpData := PWideChar(U);
  CSAllowSetForegroundWindow(Pid);
  Res := 0;
  if CSSendMessageTimeoutW(Recv, WM_COPYDATA, 0, LPARAM(@CDS), CS_SMTO_ABORTIFHUNG,
       CS_MERGE_TIMEOUT, @Res) = 0 then
  begin
    DeleteFile(FN);
    DoError(CXT(sErrMoveOtherWindow));
    Exit;
  end;
  case Res of
    1: PageClose(P, True);
  else
    DeleteFile(FN);
  end;
end;

function TCsEditor.SendTearOff(P: TCsPage; X, Y: Integer): Boolean;
var
  FN: string;
  EnvBlock, Cmd, Exe, Entry: UnicodeString;
  PW, Env: PWideChar;
  SI: Windows.TStartupInfoW;
  ProcInfo: TProcessInformation;
  Ok: Boolean;
  Err: DWORD;
begin
  Result := False;
  if TryMerge(P, X, Y) then Exit(True);
  if not MakeTearOffFile(P, X, Y, FN) then Exit;
  EnvBlock := '';
  Env := Windows.GetEnvironmentStringsW;
  if Env <> nil then
  try
    PW := Env;
    while PW^ <> #0 do
    begin
      Entry := PW;
      if not SameText(UTF8Encode(System.Copy(Entry, 1, Length(TearOffEnv) + 1)), TearOffEnv + '=') then
        EnvBlock := EnvBlock + Entry + #0;
      Inc(PW, Length(Entry) + 1);
    end;
  finally
    Windows.FreeEnvironmentStringsW(Env);
  end;
  EnvBlock := EnvBlock + UnicodeString(TearOffEnv) + '=' + UTF8Decode(FN) + #0 + #0;
  Exe := UTF8Decode(Application.ExeName);
  Cmd := '"' + Exe + '"';
  UniqueString(Cmd);
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  FillChar(ProcInfo, SizeOf(ProcInfo), 0);
  Ok := Windows.CreateProcessW(PWideChar(Exe), PWideChar(Cmd), nil, nil, False,
    CS_CREATE_UNICODE_ENVIRONMENT, PWideChar(EnvBlock), nil, SI, ProcInfo);
  if not Ok then
  begin
    Err := Windows.GetLastError;
    DeleteFile(FN);
    DoError(CXT(sErrOpenOtherWindow) + SysErrorMessage(Err));
    Exit;
  end;
  Windows.CloseHandle(ProcInfo.hThread);
  Windows.CloseHandle(ProcInfo.hProcess);
  PageClose(P, True);
  Result := True;
end;

function TCsEditor.TryClaimTearOff: Boolean;
var
  FN: string;
begin
  Result := False;
  if FTearOffPending then Exit(True);
  if not FTabTearOff or GTearOffClaimed then Exit;
  if csDesigning in ComponentState then Exit;
  FN := TearOffFile;
  if (FN = '') or not FileExists(FN) then Exit;
  if not ReadTearOffFile(FN, FTearOffHead, FTearOffBody) then Exit;
  if FTearOffHead.Values['Editor'] <> TearOffName then
  begin
    FTearOffHead.Clear;
    FTearOffBody := '';
    Exit;
  end;
  GTearOffClaimed := True;
  FTearOffPending := True;
  Result := True;
end;

procedure TCsEditor.MoveFormToTearOff;
var
  F: TCustomForm;
  X, Y: Integer;
  WA: TRect;
  M: TMonitor;
begin
  F := GetParentForm(Self);
  if F = nil then Exit;
  X := StrToIntDef(FTearOffHead.Values['X'], F.Left);
  Y := StrToIntDef(FTearOffHead.Values['Y'], F.Top);
  M := Screen.MonitorFromPoint(Point(X, Y));
  if M <> nil then
  begin
    WA := M.WorkareaRect;
    if X + F.Width > WA.Right then X := WA.Right - F.Width;
    if Y + F.Height > WA.Bottom then Y := WA.Bottom - F.Height;
    if X < WA.Left then X := WA.Left;
    if Y < WA.Top then Y := WA.Top;
  end;
  F.Position := poDesigned;
  F.Left := X;
  F.Top := Y;
end;

{ 受け取った一時ファイルから、0 番（起動直後の無題）にタブを作る（AsyncReady の中で、OnReady の前） }
procedure TCsEditor.ApplyTearOff;
var
  FN, FileN: string;
  P: TCsPage;
  N: Integer;
begin
  FTearOffPending := False;
  if FPages.Count = 0 then Exit;
  P := TCsPage(FPages[0]);
  FileN := FTearOffHead.Values['FileName'];
  if (FileN <> '') and FileExists(FileN) then
  begin
    if PageLoad(P, FileN) then
    begin
      if FTearOffHead.Values['Modified'] = '1' then P.Text := FTearOffBody;
    end
    else
      P.Text := FTearOffBody;
  end
  else
    P.Text := FTearOffBody;
  if FTearOffHead.Values['LineBreak'] = 'LF' then P.FLineBreak := #10 else P.FLineBreak := #13#10;
  N := StrToIntDef(FTearOffHead.Values['Encoding'], Ord(ceUTF8));
  if (N >= Ord(Low(TCMEncoding))) and (N <= Ord(High(TCMEncoding))) then P.FEncoding := TCMEncoding(N);
  if FTearOffHead.Values['Language'] <> '' then P.Language := FTearOffHead.Values['Language'];
  FN := TearOffFile;
  if FN <> '' then DeleteFile(FN);
  FTearOffHead.Clear;
  FTearOffBody := '';
end;

procedure TCsEditor.AsyncMerge(Data: PtrInt);
var
  FN, FileN, Body: string;
  Head: TStringList;
  I, N: Integer;
  P: TCsPage;
begin
  if (FMergeQueue = nil) or (csDestroying in ComponentState) then Exit;
  Head := TStringList.Create;
  try
    while FMergeQueue.Count > 0 do
    begin
      FN := FMergeQueue[0];
      FMergeQueue.Delete(0);
      if not ReadTearOffFile(FN, Head, Body) then Continue;
      I := -1;
      FileN := Head.Values['FileName'];
      if (FileN <> '') and FileExists(FileN) then
      begin
        try
          I := OpenFile(FileN);
        except
          on E: Exception do
          begin
            DoError(FileN + ': ' + E.Message);
            I := -1;
          end;
        end;
        if (I >= 0) and (Head.Values['Modified'] = '1') then GetPage(I).Text := Body;
      end;
      if I < 0 then
      begin
        I := NewPage;
        if I < 0 then Continue;
        GetPage(I).Text := Body;
      end;
      P := GetPage(I);
      if Head.Values['LineBreak'] = 'LF' then P.FLineBreak := #10 else P.FLineBreak := #13#10;
      N := StrToIntDef(Head.Values['Encoding'], Ord(ceUTF8));
      if (N >= Ord(Low(TCMEncoding))) and (N <= Ord(High(TCMEncoding))) then P.FEncoding := TCMEncoding(N);
      if Head.Values['Language'] <> '' then P.Language := Head.Values['Language'];
      ActiveIndex := I;
      DeleteFile(FN);
    end;
  finally
    Head.Free;
  end;
  AsyncBringFront(0);
end;

procedure TCsEditor.AsyncBringFront(Data: PtrInt);
var
  F: TCustomForm;
begin
  F := GetParentForm(Self);
  if F = nil then Exit;
  if F.WindowState = wsMinimized then F.WindowState := wsNormal;
  F.BringToFront;
  if F.HandleAllocated then Windows.SetForegroundWindow(F.Handle);
end;

{ ================================================================== }
{ 標準アクション（11章。CMonacoActions と同じ作り）                    }
{ ================================================================== }

constructor TCsEditorAction.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DisableIfNoHandler := False;     { OnExecute が無くても、標準の動きで使える }
end;

function TCsEditorAction.TargetEditor: TCsEditor;
var
  C: TComponent;
begin
  Result := nil;
  C := ActionList;
  if C <> nil then C := C.Owner;
  while (C <> nil) and not (C is TCustomForm) do C := C.Owner;
  if C <> nil then Result := CsActiveEditor(TCustomForm(C));
end;

function TCsEditorAction.CanRun(AEditor: TCsEditor): Boolean;
begin
  Result := AEditor <> nil;
end;

function TCsEditorAction.Execute: Boolean;
var
  E: TCsEditor;
begin
  Result := inherited Execute;      { OnExecute があれば、そちらだけ }
  if Result then Exit;
  E := TargetEditor;
  if CanRun(E) then
  begin
    Run(E);
    Result := True;
  end;
end;

function TCsEditorAction.Update: Boolean;
begin
  Result := inherited Update;
  if Result then Exit;
  Enabled := CanRun(TargetEditor);
  Result := True;
end;

procedure TCsEditorToggleAction.Run(AEditor: TCsEditor);
begin
  SetValue(AEditor, not GetValue(AEditor));
end;

function TCsEditorToggleAction.Update: Boolean;
var
  E: TCsEditor;
begin
  Result := inherited Update;
  if Assigned(OnUpdate) then Exit;
  E := TargetEditor;
  Checked := (E <> nil) and CanRun(E) and GetValue(E);
end;

constructor TCsEditorNew.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActNewCap);
  Hint := CXT(sActNewHint);
  ShortCut := Menus.ShortCut(VK_N, [ssCtrl]);
end;

procedure TCsEditorNew.Run(AEditor: TCsEditor);
begin
  AEditor.NewPage;
end;

constructor TCsEditorOpen.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActOpenCap);
  Hint := CXT(sActOpenHint);
  ShortCut := Menus.ShortCut(VK_O, [ssCtrl]);
end;

procedure TCsEditorOpen.Run(AEditor: TCsEditor);
begin
  AEditor.OpenFile('');            { OpenDialog（無ければ内蔵）で選ぶ。タブありなら複数選べる }
end;

constructor TCsEditorSave.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActSaveCap);
  Hint := CXT(sActSaveHint);
  ShortCut := Menus.ShortCut(VK_S, [ssCtrl]);
end;

procedure TCsEditorSave.Run(AEditor: TCsEditor);
begin
  AEditor.Save;
end;

constructor TCsEditorSaveAs.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActSaveAsCap);
  Hint := CXT(sActSaveAsHint);
end;

procedure TCsEditorSaveAs.Run(AEditor: TCsEditor);
begin
  AEditor.SaveAs;
end;

constructor TCsEditorClose.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActCloseCap);
  Hint := CXT(sActCloseHint);
  ShortCut := Menus.ShortCut(VK_W, [ssCtrl]);
end;

procedure TCsEditorClose.Run(AEditor: TCsEditor);
begin
  AEditor.Close;
end;

constructor TCsEditorPrint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActPrintCap);
  Hint := CXT(sActPrintHint);
  ShortCut := Menus.ShortCut(VK_P, [ssCtrl]);
end;

function TCsEditorPrint.CanRun(AEditor: TCsEditor): Boolean;
begin
  Result := (AEditor <> nil) and AEditor.CanPrint;
end;

procedure TCsEditorPrint.Run(AEditor: TCsEditor);
begin
  AEditor.Print;
end;

constructor TCsEditorSaveAll.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActSaveAllCap);
  Hint := CXT(sActSaveAllHint);
  ShortCut := Menus.ShortCut(VK_S, [ssCtrl, ssShift]);
end;

function TCsEditorSaveAll.CanRun(AEditor: TCsEditor): Boolean;
var
  I: Integer;
begin
  Result := False;
  if AEditor = nil then Exit;
  for I := 0 to AEditor.PageCount - 1 do
    if AEditor.Pages[I].Modified then Exit(True);
end;

procedure TCsEditorSaveAll.Run(AEditor: TCsEditor);
begin
  AEditor.SaveAll;
end;

constructor TCsEditorCloseAll.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActCloseAllCap);
  Hint := CXT(sActCloseAllHint);
end;

procedure TCsEditorCloseAll.Run(AEditor: TCsEditor);
begin
  AEditor.CloseAll;
end;

constructor TCsEditorUndo.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActUndoCap);
  Hint := CXT(sActUndoHint);
  ShortCut := Menus.ShortCut(VK_Z, [ssCtrl]);
end;

function TCsEditorUndo.CanRun(AEditor: TCsEditor): Boolean;
begin
  Result := (AEditor <> nil) and AEditor.CanUndo;
end;

procedure TCsEditorUndo.Run(AEditor: TCsEditor);
begin
  AEditor.Undo;
end;

constructor TCsEditorRedo.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActRedoCap);
  Hint := CXT(sActRedoHint);
  ShortCut := Menus.ShortCut(VK_Y, [ssCtrl]);
end;

function TCsEditorRedo.CanRun(AEditor: TCsEditor): Boolean;
begin
  Result := (AEditor <> nil) and AEditor.CanRedo;
end;

procedure TCsEditorRedo.Run(AEditor: TCsEditor);
begin
  AEditor.Redo;
end;

constructor TCsEditorCut.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActCutCap);
  Hint := CXT(sActCutHint);
  ShortCut := Menus.ShortCut(VK_X, [ssCtrl]);
end;

function TCsEditorCut.CanRun(AEditor: TCsEditor): Boolean;
begin
  Result := (AEditor <> nil) and (AEditor.SelLength > 0) and not AEditor.ReadOnly;
end;

procedure TCsEditorCut.Run(AEditor: TCsEditor);
begin
  AEditor.Cut;
end;

constructor TCsEditorCopy.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActCopyCap);
  Hint := CXT(sActCopyHint);
  ShortCut := Menus.ShortCut(VK_C, [ssCtrl]);
end;

function TCsEditorCopy.CanRun(AEditor: TCsEditor): Boolean;
begin
  Result := (AEditor <> nil) and (AEditor.SelLength > 0);
end;

procedure TCsEditorCopy.Run(AEditor: TCsEditor);
begin
  AEditor.Copy;
end;

constructor TCsEditorPaste.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActPasteCap);
  Hint := CXT(sActPasteHint);
  ShortCut := Menus.ShortCut(VK_V, [ssCtrl]);
end;

function TCsEditorPaste.CanRun(AEditor: TCsEditor): Boolean;
begin
  Result := (AEditor <> nil) and not AEditor.ReadOnly and
    Clipboard.HasFormat(PredefinedClipboardFormat(pcfText));
end;

procedure TCsEditorPaste.Run(AEditor: TCsEditor);
begin
  AEditor.Paste;
end;

constructor TCsEditorSelectAll.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActSelectAllCap);
  Hint := CXT(sActSelectAllHint);
  ShortCut := Menus.ShortCut(VK_A, [ssCtrl]);
end;

procedure TCsEditorSelectAll.Run(AEditor: TCsEditor);
begin
  AEditor.SelectAll;
end;

constructor TCsEditorDuplicateLine.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActDupLineCap);
  Hint := CXT(sActDupLineHint);
  ShortCut := Menus.ShortCut(VK_F10, [ssShift]);
end;

function TCsEditorDuplicateLine.CanRun(AEditor: TCsEditor): Boolean;
begin
  Result := (AEditor <> nil) and not AEditor.ReadOnly;
end;

procedure TCsEditorDuplicateLine.Run(AEditor: TCsEditor);
begin
  AEditor.DuplicateLine;
end;

constructor TCsEditorDeleteToEnd.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActDelToEndCap);
  Hint := CXT(sActDelToEndHint);
end;

function TCsEditorDeleteToEnd.CanRun(AEditor: TCsEditor): Boolean;
begin
  Result := (AEditor <> nil) and not AEditor.ReadOnly;
end;

procedure TCsEditorDeleteToEnd.Run(AEditor: TCsEditor);
begin
  AEditor.DeleteToEnd;
end;

constructor TCsEditorDeleteToStart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActDelToStartCap);
  Hint := CXT(sActDelToStartHint);
end;

function TCsEditorDeleteToStart.CanRun(AEditor: TCsEditor): Boolean;
begin
  Result := (AEditor <> nil) and not AEditor.ReadOnly;
end;

procedure TCsEditorDeleteToStart.Run(AEditor: TCsEditor);
begin
  AEditor.DeleteToStart;
end;

constructor TCsEditorFind.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActFindCap);
  Hint := CXT(sActFindHint);
  ShortCut := Menus.ShortCut(VK_F, [ssCtrl]);
end;

procedure TCsEditorFind.Run(AEditor: TCsEditor);
begin
  AEditor.ShowFindDialog;
end;

constructor TCsEditorFindNext.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActFindNextCap);
  Hint := CXT(sActFindNextHint);
  ShortCut := Menus.ShortCut(VK_F5, []);
end;

procedure TCsEditorFindNext.Run(AEditor: TCsEditor);
begin
  AEditor.FindNext;
end;

constructor TCsEditorFindPrev.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActFindPrevCap);
  Hint := CXT(sActFindPrevHint);
  ShortCut := Menus.ShortCut(VK_F5, [ssShift]);
end;

procedure TCsEditorFindPrev.Run(AEditor: TCsEditor);
begin
  AEditor.FindPrev;
end;

constructor TCsEditorMinimap.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActMinimapCap);
  Hint := CXT(sActMinimapHint);
  ShortCut := Menus.ShortCut(VK_M, [ssCtrl, ssShift]);
end;

function TCsEditorMinimap.GetValue(AEditor: TCsEditor): Boolean;
begin
  Result := AEditor.Minimap;
end;

procedure TCsEditorMinimap.SetValue(AEditor: TCsEditor; AValue: Boolean);
begin
  AEditor.Minimap := AValue;
end;

constructor TCsEditorPreview.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActPreviewCap);
  Hint := CXT(sActPreviewHint);
  ShortCut := Menus.ShortCut(VK_V, [ssCtrl, ssShift]);
end;

function TCsEditorPreview.CanRun(AEditor: TCsEditor): Boolean;
begin
  Result := (AEditor <> nil) and (AEditor.Preview <> nil);
end;

function TCsEditorPreview.GetValue(AEditor: TCsEditor): Boolean;
begin
  Result := AEditor.ShowPreview;
end;

procedure TCsEditorPreview.SetValue(AEditor: TCsEditor; AValue: Boolean);
begin
  AEditor.ShowPreview := AValue;
end;

constructor TCsEditorLineNumbers.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActLineNumbersCap);
  Hint := CXT(sActLineNumbersHint);
  ShortCut := Menus.ShortCut(VK_F11, []);
end;

function TCsEditorLineNumbers.GetValue(AEditor: TCsEditor): Boolean;
begin
  Result := AEditor.LineNumbers;
end;

procedure TCsEditorLineNumbers.SetValue(AEditor: TCsEditor; AValue: Boolean);
begin
  AEditor.LineNumbers := AValue;
end;

constructor TCsEditorWordWrap.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActWordWrapCap);
  Hint := CXT(sActWordWrapHint);
end;

function TCsEditorWordWrap.GetValue(AEditor: TCsEditor): Boolean;
begin
  Result := AEditor.WordWrap;
end;

procedure TCsEditorWordWrap.SetValue(AEditor: TCsEditor; AValue: Boolean);
begin
  AEditor.WordWrap := AValue;
end;

constructor TCsEditorRemoteImages.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := CXT(sActRemoteImagesCap);
  Hint := CXT(sActRemoteImagesHint);
end;

function TCsEditorRemoteImages.CanRun(AEditor: TCsEditor): Boolean;
begin
  Result := (AEditor <> nil) and (AEditor.Preview <> nil);
end;

function TCsEditorRemoteImages.GetValue(AEditor: TCsEditor): Boolean;
begin
  Result := AEditor.AllowRemoteImages;
end;

procedure TCsEditorRemoteImages.SetValue(AEditor: TCsEditor; AValue: Boolean);
begin
  AEditor.AllowRemoteImages := AValue;
end;

initialization
  GShownErrors := TStringList.Create;
  GEditors := TFPList.Create;

finalization
  if GReceiverWnd <> 0 then
  begin
    Windows.DestroyWindow(GReceiverWnd);
    GReceiverWnd := 0;
  end;
  FreeAndNil(GEditors);
  FreeAndNil(GShownErrors);

end.
