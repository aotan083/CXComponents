{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ TCBookmark - Firefox のブックマーク画面のような、ブックマーク管理の部品
  設計書: docs\TCBookmark_Design.md
  環境: Lazarus 4.8 / FPC 3.2.2 / Windows 11

  【使い方】コードは書かない。
  1. フォームに TCBookmark を置く
  2. TargetBrowser に TCTabBrowser、TargetEditor に TCMonacoEditor を選ぶ（片方だけでもよい）
  3. 実行すると BookmarkFolder の BookmarkFile（既定は exe と同じフォルダーの bookmark\bookmarks.json）を
     読み込む。操作した内容は自動で保存する

  ・ブックマークは「URL」と「ローカルPCのファイル」の2種類。ほかにフォルダーと区切り線がある。
  ・Chrome・Edge・Firefox と、HTML（Netscape Bookmark File Format）でインポート・エクスポートできる。
  ・エクスプローラーからファイル・フォルダー・.url・.lnk、ブラウザから URL をドロップして登録できる。 }
unit uCbookmark;

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils, Controls, Forms, StdCtrls, ComCtrls, ExtCtrls,
  Menus, Graphics, Dialogs, LCLType, ActiveX,
  uCmonacos, uCTabBrowser;

type
  { ブックマークの種類 }
  TCBookmarkKind = (bkUrl, bkFile, bkFolder, bkSeparator);
  { 開く先 }
  TCBookmarkTarget = (btBrowser, btEditor);
  { 落とす位置。bdpBefore＝その前、bdpInside＝フォルダーの中（一番下）、bdpAfter＝その後 }
  TCBookmarkDropPos = (bdpBefore, bdpInside, bdpAfter);

  TCBookmark = class;

  { IDropTarget（Windows の定義どおり。FPC の宣言の違いで困らないよう、ここで宣言する） }
  ICBDropTarget = interface(IUnknown)
    ['{00000122-0000-0000-C000-000000000046}']
    function DragEnter(const dataObj: IDataObject; grfKeyState: DWORD; pt: TPoint; var dwEffect: DWORD): HResult; stdcall;
    function DragOver(grfKeyState: DWORD; pt: TPoint; var dwEffect: DWORD): HResult; stdcall;
    function DragLeave: HResult; stdcall;
    function Drop(const dataObj: IDataObject; grfKeyState: DWORD; pt: TPoint; var dwEffect: DWORD): HResult; stdcall;
  end;

  { TCBookmarkItem : ブックマーク1件分。
    作るのも消すのも TCBookmark。アプリ側で Create・Free しない。
    Name・Location をコードで書き換えても保存はされない（保存は TCBookmark の操作のときに行う） }
  TCBookmarkItem = class
  private
    FKind: TCBookmarkKind;
    FName: string;
    FLocation: string;
    FExpanded: Boolean;
    FAddDate: TDateTime;
    FParent: TCBookmarkItem;
    FItems: TFPList;          { 子の項目（フォルダーのときだけ作る） }
    FFileMissing: Boolean;
    FNode: TTreeNode;         { 今表示しているツリーの行。ツリーを作り直すたびに入れ直す（無ければ nil） }
    function GetCount: Integer;
    function GetItem(AIndex: Integer): TCBookmarkItem;
    function GetIndex: Integer;
  public
    constructor Create(AKind: TCBookmarkKind);
    destructor Destroy; override;
    { 子を AIndex の位置に入れる（範囲外なら末尾）。AItem の親はこの項目になる }
    procedure InsertChild(AIndex: Integer; AItem: TCBookmarkItem);
    { 子を外す（解放はしない） }
    procedure RemoveChild(AItem: TCBookmarkItem);
    { 自分が AItem の子・孫か（AItem 自身なら False） }
    function IsDescendantOf(AItem: TCBookmarkItem): Boolean;
    { 中身ごとの写しを作る（親は nil） }
    function Clone: TCBookmarkItem;
    { 子・孫の数（自分は含まない） }
    function DescendantCount: Integer;
    property Kind: TCBookmarkKind read FKind;
    property Name: string read FName write FName;
    property Location: string read FLocation write FLocation;
    property Expanded: Boolean read FExpanded write FExpanded;
    property AddDate: TDateTime read FAddDate;
    property Parent: TCBookmarkItem read FParent;
    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: TCBookmarkItem read GetItem; default;
    property Index: Integer read GetIndex;
    property FileMissing: Boolean read FFileMissing;
  end;

  { TCBookmarkTree : ツリーの表示（内部用）。ドラッグ中の落とす位置の線・枠を描く }
  TCBookmarkTree = class(TTreeView)
  private
    FBM: TCBookmark;
    FDropTarget: ICBDropTarget;   { 外部からの D&D の受け取り（実行時のみ登録） }
    FIndOn: Boolean;              { 位置の線・枠を出しているか }
    FIndItem: TCBookmarkItem;     { 位置の基準の項目（nil＝一番下） }
    FIndPos: TCBookmarkDropPos;
  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure Paint; override;
  public
    procedure ShowIndicator(AItem: TCBookmarkItem; APos: TCBookmarkDropPos);
    procedure HideIndicator;
  end;

  { TCBookmarkDropTarget : 外部からの D&D の受け取り }
  TCBookmarkDropTarget = class(TInterfacedObject, ICBDropTarget)
  private
    FBM: TCBookmark;
    FCanDrop: Boolean;
    function PickEffect(AAllowed: DWORD): DWORD;
  public
    constructor Create(ABM: TCBookmark);
    function DragEnter(const dataObj: IDataObject; grfKeyState: DWORD; pt: TPoint; var dwEffect: DWORD): HResult; stdcall;
    function DragOver(grfKeyState: DWORD; pt: TPoint; var dwEffect: DWORD): HResult; stdcall;
    function DragLeave: HResult; stdcall;
    function Drop(const dataObj: IDataObject; grfKeyState: DWORD; pt: TPoint; var dwEffect: DWORD): HResult; stdcall;
  end;

  { TCBookmarkFaviconThread : favicon を裏で取りに行く }
  TCBookmarkFaviconThread = class(TThread)
  private
    FBM: TCBookmark;
    FHost: string;
    FData: TBytes;
    procedure Done;
  protected
    procedure Execute; override;
  public
    constructor Create(ABM: TCBookmark; const AHost: string);
  end;

  { TCBookmark : 部品本体 }
  TCBookmark = class(TCustomPanel)
  private
    FSearch: TEdit;
    FTree: TCBookmarkTree;
    FImages: TImageList;
    FMenu: TPopupMenu;
    FMiTextOpen, FMiTextOpenNew, FMiBrOpen, FMiBrOpenNew: TMenuItem;
    FMiEdit, FMiDelete, FMiCut, FMiCopy, FMiPaste: TMenuItem;
    FMiAddBookmark, FMiAddFolder, FMiAddSeparator, FMiImport, FMiExport: TMenuItem;
    FRoot: TCBookmarkItem;
    FTargetBrowser: TCTabBrowser;
    FTargetEditor: TCMonacoEditor;
    FOnChange: TNotifyEvent;
    FOnSelectionChange: TNotifyEvent;
    FLastSel: TCBookmarkItem;     { 最後に OnSelectionChange で知らせた選択（比べるだけ。中身は触らない） }
    FAppTarget: TControl;         { ドラッグ中、マウスの下にある同じアプリの部品 }
    FAppAccept: Boolean;          { FAppTarget の OnDragOver が受けると答えたか }
    FOleDragging: Boolean;        { 自分で始めた OLE のドラッグ中（自分のツリーでは受けない） }

    FDataDir: string;             { exe のフォルダー\bookmark\ }
    FIconDir: string;             { 保存先のフォルダー\icons\ }
    FBookmarkFolder: string;      { 保存先のフォルダー（相対パスなら exe のフォルダーが起点）。既定 'bookmark' }
    FBookmarkFile: string;        { 保存するファイル名。既定 'bookmarks.json' }
    FDataLoaded: Boolean;
    FSaveErrorShown: Boolean;
    FUpdating: Boolean;           { ツリーを作っている間（開閉の通知を無視する） }

    FSearching: Boolean;          { 検索中（一覧を表示している） }
    FSearchKey: UnicodeString;
    FSearchTimer: TTimer;

    FDragItem: TCBookmarkItem;    { 部品の中でドラッグしている項目 }
    FDragStarted: Boolean;        { 左ボタンを押してからドラッグで動かした（離したときにクリックとしない） }
    FDragArmed: Boolean;          { 項目の上で左ボタンを押した（しきい値を超えて動かしたらドラッグを始める） }
    FDragActive: Boolean;         { 部品の中のドラッグ中 }
    FDragStartPt: TPoint;         { 左ボタンを押した位置 }
    FDownItem: TCBookmarkItem;    { 左ボタンを押した位置の項目（ドラッグする項目・クリックの判定に使う） }
    FDropOk: Boolean;             { 最後の DragOver で落とせる位置だったか }
    FDropTargetItem: TCBookmarkItem;   { 最後の DragOver の落とす位置（nil＝一番下） }
    FDropPos: TCBookmarkDropPos;
    FDragTimer: TTimer;           { ドラッグ中の自動スクロール・フォルダーを開く }
    FHoverItem: TCBookmarkItem;
    FHoverStart: QWord;
    FExtDragging: Boolean;        { 外部からの D&D 中 }

    FPopupItem: TCBookmarkItem;   { 右クリックした項目（nil＝空白部分） }
    FClip: TCBookmarkItem;        { コピーした写し }
    FCutItem: TCBookmarkItem;     { 切り取った項目（貼り付けまで元の場所に残す） }

    FIconKeys: TStringList;       { ファイルのアイコン：キー → FImages の番号 }
    FHostIcons: TStringList;      { favicon：ホスト → FImages の番号（-1＝無い） }
    FBaseIconsMade: Boolean;
    FGlobeIndex, FFolderIndex, FFolderOpenIndex: Integer;
    FFetchTried: TStringList;     { この起動中に取りに行ったホスト }
    FFetchQueue: TStringList;     { 順番待ちのホスト }
    FFetchRunning: Integer;

    FPendingFiles: TStringList;   { ドロップされたファイル（ドロップの処理を終えてから登録する） }
    FPendingUrl, FPendingTitle: string;
    FPendingTarget: TCBookmarkItem;
    FPendingPos: TCBookmarkDropPos;
    FPendingIsUrl: Boolean;

    FDlgName, FDlgLoc: TEdit;     { 追加・編集のダイアログの入力欄（表示している間だけ） }
    FDlgOk: TButton;
    FDlgWithLoc: Boolean;

    procedure SetTargetBrowser(AValue: TCTabBrowser);
    procedure SetTargetEditor(AValue: TCMonacoEditor);
    procedure SetBookmarkFolder(const AValue: string);
    procedure SetBookmarkFile(const AValue: string);
    function IsBookmarkFolderStored: Boolean;
    function IsBookmarkFileStored: Boolean;
    procedure UpdatePaths;
    procedure ReloadData;
    function GetSelected: TCBookmarkItem;
    function GetSearchText: string;
    procedure SetSearchText(const AValue: string);

    { 保存・読み込み }
    procedure LoadData;
    procedure SaveData;
    procedure Changed(ASelect: TCBookmarkItem);
    { ツリー }
    procedure BuildTree;
    procedure AddNodes(AParentNode: TTreeNode; AItem: TCBookmarkItem);
    procedure SetNodeLook(ANode: TTreeNode; AItem: TCBookmarkItem);
    procedure UpdateAllIcons;
    procedure SelectItem(AItem: TCBookmarkItem);
    function ItemOfNode(ANode: TTreeNode): TCBookmarkItem;
    procedure RefreshMissing(AItem: TCBookmarkItem; ADeep: Boolean);
    function IsInTree(AItem: TCBookmarkItem): Boolean;
    { アイコン }
    procedure MakeBaseIcons;
    function AddShellIcon(const APath: UnicodeString; AAttr, AFlags: DWORD): Integer;
    function IconIndexOf(AItem: TCBookmarkItem; AExpanded: Boolean): Integer;
    function FileIconIndex(const APath: string): Integer;
    function HostIconIndex(const AHost: string): Integer;
    function HostIconFile(const AHost: string): string;
    procedure RequestFavicon(const AHost: string);
    procedure StartNextFetch;
    procedure FaviconArrived(const AHost: string; const AData: TBytes);
    procedure SaveHostIcon(const AHost: string; const AData: TBytes);
    { 項目を作る・入れる }
    function NewLink(const AName, ALocation: string): TCBookmarkItem;
    procedure InsertPos(AItem: TCBookmarkItem; out AParent: TCBookmarkItem; out AIndex: Integer);
    procedure DropDest(ATarget: TCBookmarkItem; APos: TCBookmarkDropPos; out AParent: TCBookmarkItem; out AIndex: Integer);
    procedure DoInsert(AParent: TCBookmarkItem; AIndex: Integer; AItem: TCBookmarkItem);
    function MoveInternal(AItem, ANewParent: TCBookmarkItem; ANewIndex: Integer): Boolean;
    function ItemFromPath(const APath: string; AResolveLink: Boolean): TCBookmarkItem;
    procedure AddDirContents(AFolder: TCBookmarkItem; const ADir: string);
    function CountDirEntries(const ADir: string; ALimit: Integer): Integer;
    { 開く }
    procedure OpenInEditor(const APath: string; ANewTab: Boolean);
    procedure OpenInBrowser(const AUrl: string; ANewTab: Boolean);
    { ダイアログ }
    function EditDialog(const ATitle: string; var AName, ALoc: string; AWithLoc: Boolean): Boolean;
    procedure DlgChange(Sender: TObject);
    { インポート }
    function ParseHtml(const S: string; ADest: TCBookmarkItem): Integer;
    { ドラッグ }
    function CalcDrop(X, Y: Integer; out ATarget: TCBookmarkItem; out APos: TCBookmarkDropPos): Boolean;
    function CanDropItem(ADrag, ATarget: TCBookmarkItem; APos: TCBookmarkDropPos): Boolean;
    procedure BeginDragTimer;
    procedure EndDragTimer;
    procedure AsyncExternalDrop(Data: PtrInt);
    procedure FinishInternalDrop;

    { 中の部品からの通知 }
    procedure SearchChange(Sender: TObject);
    procedure SearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure SearchTimer(Sender: TObject);
    procedure DragTimer(Sender: TObject);
    procedure TreeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure TreeMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure TreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TreeExpanded(Sender: TObject; Node: TTreeNode);
    procedure TreeCollapsed(Sender: TObject; Node: TTreeNode);
    procedure TreeDrawItem(Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState;
      Stage: TCustomDrawStage; var PaintImages, DefaultDraw: Boolean);
    procedure TreeMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure TreeSelChange(Sender: TObject; Node: TTreeNode);
    procedure CheckSelection;
    procedure DragMoveTo(X, Y: Integer);
    procedure LeaveAppTarget;
    function IsOwnPart(AControl: TControl): Boolean;
    function CanOleDrag(AItem: TCBookmarkItem): Boolean;
    procedure StartOleDrag;
    procedure UpdateInternalDrag(X, Y: Integer);
    procedure EndInternalDrag(ADrop: Boolean);
    procedure MenuPopup(Sender: TObject);
    procedure MenuClick(Sender: TObject);
  protected
    procedure CreateWnd; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    { 操作を受けたときの処理。マウス・キー・メニューはこれを呼ぶだけ }
    procedure DoItemClick(AItem: TCBookmarkItem); virtual;
    procedure DoMenuOpen(AItem: TCBookmarkItem; ATarget: TCBookmarkTarget; ANewTab: Boolean); virtual;
    procedure DoMenuEdit(AItem: TCBookmarkItem); virtual;
    procedure DoMenuDelete(AItem: TCBookmarkItem); virtual;
    procedure DoMenuCut(AItem: TCBookmarkItem); virtual;
    procedure DoMenuCopy(AItem: TCBookmarkItem); virtual;
    procedure DoMenuPaste(AItem: TCBookmarkItem); virtual;
    procedure DoMenuAddBookmark(AItem: TCBookmarkItem); virtual;
    procedure DoMenuAddFolder(AItem: TCBookmarkItem); virtual;
    procedure DoMenuAddSeparator(AItem: TCBookmarkItem); virtual;
    procedure DoDropItem(AItem, ATarget: TCBookmarkItem; APos: TCBookmarkDropPos); virtual;
    procedure DoDropFiles(const AFiles: TStrings; ATarget: TCBookmarkItem; APos: TCBookmarkDropPos); virtual;
    procedure DoDropUrl(const AUrl, ATitle: string; ATarget: TCBookmarkItem; APos: TCBookmarkDropPos); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { メソッド }
    function ImportFromFile(const AFileName: string): Boolean;
    function ExportToFile(const AFileName: string): Boolean;
    procedure ImportWithDialog;
    procedure ExportWithDialog;
    function AddBookmark(AParent: TCBookmarkItem; AIndex: Integer; const AName, ALocation: string): TCBookmarkItem;
    function AddFolder(AParent: TCBookmarkItem; AIndex: Integer; const AName: string): TCBookmarkItem;
    function AddSeparator(AParent: TCBookmarkItem; AIndex: Integer): TCBookmarkItem;
    procedure DeleteItem(AItem: TCBookmarkItem);
    function MoveItem(AItem, ANewParent: TCBookmarkItem; ANewIndex: Integer): Boolean;
    procedure OpenItem(AItem: TCBookmarkItem; ATarget: TCBookmarkTarget; ANewTab: Boolean);

    { 実行時のみのプロパティ }
    property Root: TCBookmarkItem read FRoot;
    property Selected: TCBookmarkItem read GetSelected;
    property SearchText: string read GetSearchText write SetSearchText;
    { ドラッグ中の項目（ドラッグしていなければ nil）。同じアプリの別の部品の OnDragOver・OnDragDrop で使う }
    property DragItem: TCBookmarkItem read FDragItem;
  published
    property TargetBrowser: TCTabBrowser read FTargetBrowser write SetTargetBrowser;
    property TargetEditor: TCMonacoEditor read FTargetEditor write SetTargetEditor;
    property BookmarkFolder: string read FBookmarkFolder write SetBookmarkFolder stored IsBookmarkFolderStored;
    property BookmarkFile: string read FBookmarkFile write SetBookmarkFile stored IsBookmarkFileStored;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnSelectionChange: TNotifyEvent read FOnSelectionChange write FOnSelectionChange;

    property Align;
    property Anchors;
    property BorderSpacing;
    property Constraints;
    property Enabled;
    property Font;
    property ParentFont;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
  end;

{ URL かファイルかの判定。判定できなければ False（javascript: about: など） }
function CBClassifyLocation(const S: string; out AKind: TCBookmarkKind; out ALocation: string): Boolean;
{ ファイルパスを file:/// の URL にする }
function CBPathToFileUrl(const APath: string): string;
{ file:/// の URL をファイルパスにする }
function CBFileUrlToPath(const AUrl: string): string;
{ URL のホスト名（小文字。取れなければ ''） }
function CBHostOf(const AUrl: string): string;

implementation

uses
  ShellApi, ShlObj, Clipbrd, IniFiles, fpjson, jsonparser, base64, DateUtils, Math, LazUTF8;

resourcestring
  rsMenuTextOpen = 'Text開く';
  rsMenuTextOpenNew = 'Text新しいタブで開く';
  rsMenuBrowserOpen = 'Browserで開く';
  rsMenuBrowserOpenNew = 'Browserで新しいタブで開く';
  rsMenuEdit = 'ブックマークを編集';
  rsMenuDelete = 'ブックマークを削除';
  rsMenuCut = '切取り';
  rsMenuCopy = 'コピー';
  rsMenuPaste = '貼り付け';
  rsMenuAddBookmark = 'ブックマークを追加';
  rsMenuAddFolder = 'フォルダーを追加';
  rsMenuAddSeparator = '区切り線';
  rsMenuImport = 'インポート...';
  rsMenuExport = 'エクスポート...';
  rsSearchHint = 'ブックマークを検索';
  rsFileMissing = 'ファイルがありません：%s';
  rsUnsaved = '保存されていない変更があります。新しいタブで開きますか？';
  rsDeleteFolder = 'フォルダー「%s」と中の %d 件を削除しますか？';
  rsTooMany = '%d 件を登録しますか？';
  rsSaveError = 'ブックマークを保存できません：%s';
  rsLoadError = 'ブックマークを読み込めませんでした。元のファイルは %s に残しました。';
  rsDlgAdd = 'ブックマークを追加';
  rsDlgEdit = 'ブックマークを編集';
  rsDlgAddFolder = 'フォルダーを追加';
  rsDlgEditFolder = 'フォルダー名を編集';
  rsDlgName = '名前';
  rsDlgLocation = 'URL またはファイルパス';
  rsNewFolder = '新しいフォルダー';
  rsOK = 'OK';
  rsCancel = 'キャンセル';
  rsImportFolder = 'インポート %s';
  rsImportNone = 'ブックマークが見つかりませんでした。';
  rsImportError = 'インポートできません：%s';
  rsExportError = 'エクスポートできません：%s';
  rsOpenError = '開けません：%s';
  rsHtmlFilter = 'ブックマーク HTML (*.html;*.htm)|*.html;*.htm|すべてのファイル (*.*)|*.*';

const
  CBMaxFetch = 4;                 { 同時に取りに行く数 }
  CBMaxIconBytes = 512 * 1024;    { 大きさの上限 }
  CBFolderConfirm = 500;          { 確認を出す件数 }
  CBDefaultFolder = 'bookmark';   { 保存先のフォルダーの既定値 }
  CBDefaultFile = 'bookmarks.json';   { 保存するファイル名の既定値 }

  CBDropEffectNone = 0;
  CBDropEffectCopy = 1;
  CBDropEffectLink = 4;

{ ---------- Windows の関数（宣言の違いで困らないよう、ここで宣言する） ---------- }

function CBOleInitialize(pvReserved: Pointer): HResult; stdcall; external 'ole32.dll' name 'OleInitialize';
function CBRegisterDragDrop(wnd: HWND; pDropTarget: Pointer): HResult; stdcall; external 'ole32.dll' name 'RegisterDragDrop';
function CBRevokeDragDrop(wnd: HWND): HResult; stdcall; external 'ole32.dll' name 'RevokeDragDrop';
procedure CBReleaseStgMedium(var medium: STGMEDIUM); stdcall; external 'ole32.dll' name 'ReleaseStgMedium';
function CBDragQueryFileW(hDrop: THandle; iFile: UINT; lpszFile: PWideChar; cch: UINT): UINT; stdcall; external 'shell32.dll' name 'DragQueryFileW';
function CBCreateIconFromResourceEx(presbits: PByte; dwResSize: DWORD; fIcon: BOOL; dwVer: DWORD;
  cxDesired, cyDesired: Integer; Flags: UINT): HICON; stdcall; external 'user32.dll' name 'CreateIconFromResourceEx';
function CBMoveFileExW(lpExistingFileName, lpNewFileName: PWideChar; dwFlags: DWORD): BOOL; stdcall; external 'kernel32.dll' name 'MoveFileExW';
{ 外へのドラッグ }
function CBSHDoDragDrop(hwnd: HWND; pdata: Pointer; pdsrc: Pointer; dwEffect: DWORD;
  out pdwEffect: DWORD): HRESULT; stdcall; external 'shell32.dll' name 'SHDoDragDrop';
function CBSHCreateStdEnumFmtEtc(cfmt: UINT; afmt: Pointer; out ppenumFormatEtc: IUnknown): HRESULT; stdcall;
  external 'shell32.dll' name 'SHCreateStdEnumFmtEtc';
function CBILCreateFromPathW(pszPath: PWideChar): PItemIDList; stdcall; external 'shell32.dll' name 'ILCreateFromPathW';
function CBSHBindToParent(pidl: PItemIDList; const riid: TGUID; out ppv; out ppidlLast: PItemIDList): HRESULT; stdcall;
  external 'shell32.dll' name 'SHBindToParent';
function CBCoCreateInstance(const clsid: TGUID; unkOuter: Pointer; dwClsContext: DWORD; const iid: TGUID;
  out pv): HResult; stdcall; external 'ole32.dll' name 'CoCreateInstance';
function CBRegisterClipboardFormatW(lpszFormat: PWideChar): UINT; stdcall; external 'user32.dll' name 'RegisterClipboardFormatW';

function CBInternetOpenW(lpszAgent: PWideChar; dwAccessType: DWORD; lpszProxy, lpszProxyBypass: PWideChar;
  dwFlags: DWORD): Pointer; stdcall; external 'wininet.dll' name 'InternetOpenW';
function CBInternetOpenUrlW(hInternet: Pointer; lpszUrl, lpszHeaders: PWideChar; dwHeadersLength, dwFlags: DWORD;
  dwContext: PtrUInt): Pointer; stdcall; external 'wininet.dll' name 'InternetOpenUrlW';
function CBInternetReadFile(hFile: Pointer; lpBuffer: Pointer; dwNumberOfBytesToRead: DWORD;
  var lpdwNumberOfBytesRead: DWORD): BOOL; stdcall; external 'wininet.dll' name 'InternetReadFile';
function CBInternetCloseHandle(hInternet: Pointer): BOOL; stdcall; external 'wininet.dll' name 'InternetCloseHandle';
function CBInternetSetOptionW(hInternet: Pointer; dwOption: DWORD; lpBuffer: Pointer;
  dwBufferLength: DWORD): BOOL; stdcall; external 'wininet.dll' name 'InternetSetOptionW';
function CBHttpQueryInfoW(hRequest: Pointer; dwInfoLevel: DWORD; lpBuffer: Pointer; var lpdwBufferLength: DWORD;
  lpdwIndex: PDWORD): BOOL; stdcall; external 'wininet.dll' name 'HttpQueryInfoW';

type
  { .lnk のリンク先を読むための IShellLinkW・IPersistFile（Windows の定義どおりの並び） }
  ICBShellLinkW = interface(IUnknown)
    ['{000214F9-0000-0000-C000-000000000046}']
    function GetPath(pszFile: PWideChar; cch: Integer; pfd: Pointer; fFlags: DWORD): HResult; stdcall;
    function GetIDList(out ppidl: Pointer): HResult; stdcall;
    function SetIDList(pidl: Pointer): HResult; stdcall;
    function GetDescription(pszName: PWideChar; cch: Integer): HResult; stdcall;
    function SetDescription(pszName: PWideChar): HResult; stdcall;
    function GetWorkingDirectory(pszDir: PWideChar; cch: Integer): HResult; stdcall;
    function SetWorkingDirectory(pszDir: PWideChar): HResult; stdcall;
    function GetArguments(pszArgs: PWideChar; cch: Integer): HResult; stdcall;
    function SetArguments(pszArgs: PWideChar): HResult; stdcall;
    function GetHotkey(out pwHotkey: Word): HResult; stdcall;
    function SetHotkey(wHotkey: Word): HResult; stdcall;
    function GetShowCmd(out piShowCmd: Integer): HResult; stdcall;
    function SetShowCmd(iShowCmd: Integer): HResult; stdcall;
    function GetIconLocation(pszIconPath: PWideChar; cch: Integer; out piIcon: Integer): HResult; stdcall;
    function SetIconLocation(pszIconPath: PWideChar; iIcon: Integer): HResult; stdcall;
    function SetRelativePath(pszPathRel: PWideChar; dwReserved: DWORD): HResult; stdcall;
    function Resolve(wnd: HWND; fFlags: DWORD): HResult; stdcall;
    function SetPath(pszFile: PWideChar): HResult; stdcall;
  end;

  ICBPersistFile = interface(IUnknown)
    ['{0000010B-0000-0000-C000-000000000046}']
    function GetClassID(out classID: TGUID): HResult; stdcall;
    function IsDirty: HResult; stdcall;
    function Load(pszFileName: PWideChar; dwMode: DWORD): HResult; stdcall;
    function Save(pszFileName: PWideChar; fRemember: BOOL): HResult; stdcall;
    function SaveCompleted(pszFileName: PWideChar): HResult; stdcall;
    function GetCurFile(out ppszFileName: PWideChar): HResult; stdcall;
  end;

  { ブラウザが付ける「タイトル.url」の入れ物（FILEGROUPDESCRIPTORW） }
  TCBFileDescriptorW = record
    dwFlags: DWORD;
    clsid: TGUID;
    sizel: array[0..1] of Longint;
    pointl: array[0..1] of Longint;
    dwFileAttributes: DWORD;
    ftCreationTime: TFileTime;
    ftLastAccessTime: TFileTime;
    ftLastWriteTime: TFileTime;
    nFileSizeHigh: DWORD;
    nFileSizeLow: DWORD;
    cFileName: array[0..MAX_PATH - 1] of WideChar;
  end;
  PCBFileDescriptorW = ^TCBFileDescriptorW;

const
  CLSID_CBShellLink: TGUID = '{00021401-0000-0000-C000-000000000046}';
  IID_CBUnknown: TGUID = '{00000000-0000-0000-C000-000000000046}';
  IID_CBDataObject: TGUID = '{0000010E-0000-0000-C000-000000000046}';
  CBSLR_NO_UI = $0001;

type
  PCBFormatEtc = ^FORMATETC;
  PCBStgMedium = ^STGMEDIUM;

  { IDataObject（Windows の定義どおりの並び。構造体は参照で受ける。FPC の宣言の違いで困らないよう、ここで宣言する） }
  ICBDataObject = interface(IUnknown)
    ['{0000010E-0000-0000-C000-000000000046}']
    function GetData(pformatetcIn: PCBFormatEtc; pmedium: PCBStgMedium): HResult; stdcall;
    function GetDataHere(pformatetc: PCBFormatEtc; pmedium: PCBStgMedium): HResult; stdcall;
    function QueryGetData(pformatetc: PCBFormatEtc): HResult; stdcall;
    function GetCanonicalFormatEtc(pformatectIn, pformatetcOut: PCBFormatEtc): HResult; stdcall;
    function SetData(pformatetc: PCBFormatEtc; pmedium: PCBStgMedium; fRelease: BOOL): HResult; stdcall;
    function EnumFormatEtc(dwDirection: DWORD; out ppenumFormatEtc: IUnknown): HResult; stdcall;
    function DAdvise(pformatetc: PCBFormatEtc; advf: DWORD; pAdvSink: Pointer; out pdwConnection: DWORD): HResult; stdcall;
    function DUnadvise(dwConnection: DWORD): HResult; stdcall;
    function EnumDAdvise(out ppenumAdvise: IUnknown): HResult; stdcall;
  end;

  { TCBookmarkUrlData : アプリの外へ URL をドラッグするときに渡すデータ。
    ブラウザからリンクをドラッグしたときと同じ形にする：
    「名前.url」を仮のファイル（FileGroupDescriptorW・FileContents）として渡し、URL の文字も渡す }
  TCBookmarkUrlData = class(TInterfacedObject, ICBDataObject)
  private
    FUrl: string;               { URL }
    FFileName: string;          { 「名前.url」 }
    FFormats: array[0..4] of FORMATETC;
    function FindFormat(pformatetc: PCBFormatEtc): Integer;
  public
    constructor Create(const AName, AUrl: string);
    function GetData(pformatetcIn: PCBFormatEtc; pmedium: PCBStgMedium): HResult; stdcall;
    function GetDataHere(pformatetc: PCBFormatEtc; pmedium: PCBStgMedium): HResult; stdcall;
    function QueryGetData(pformatetc: PCBFormatEtc): HResult; stdcall;
    function GetCanonicalFormatEtc(pformatectIn, pformatetcOut: PCBFormatEtc): HResult; stdcall;
    function SetData(pformatetc: PCBFormatEtc; pmedium: PCBStgMedium; fRelease: BOOL): HResult; stdcall;
    function EnumFormatEtc(dwDirection: DWORD; out ppenumFormatEtc: IUnknown): HResult; stdcall;
    function DAdvise(pformatetc: PCBFormatEtc; advf: DWORD; pAdvSink: Pointer; out pdwConnection: DWORD): HResult; stdcall;
    function DUnadvise(dwConnection: DWORD): HResult; stdcall;
    function EnumDAdvise(out ppenumAdvise: IUnknown): HResult; stdcall;
  end;

  { 同じアプリの部品の DragOver（protected）を呼ぶための継承 }
  TCBControlAccess = class(TControl);

var
  GLiveBookmarks: TFPList = nil;  { 生きている TCBookmark（favicon を取り終えたときの確認用） }
  GCfUrlW: UINT = 0;              { UniformResourceLocatorW }
  GCfFileGroupW: UINT = 0;        { FileGroupDescriptorW }
  GCfFileContents: UINT = 0;      { FileContents }
  GCfUrlA: UINT = 0;              { UniformResourceLocator（ANSI） }

{ ================================================================== }
{ 小さな関数                                                         }
{ ================================================================== }

function StartsText(const ASub, S: string): Boolean;
begin
  Result := (Length(S) >= Length(ASub)) and (CompareText(Copy(S, 1, Length(ASub)), ASub) = 0);
end;

{ %xx を元に戻す（バイト単位。UTF-8 の文字列になる） }
function CBPercentDecode(const S: string): string;
var
  I, N: Integer;
  H: string;
begin
  Result := '';
  I := 1;
  N := Length(S);
  while I <= N do
  begin
    if (S[I] = '%') and (I + 2 <= N) then
    begin
      H := '$' + Copy(S, I + 1, 2);
      if (S[I + 1] in ['0'..'9', 'a'..'f', 'A'..'F']) and (S[I + 2] in ['0'..'9', 'a'..'f', 'A'..'F']) then
      begin
        Result := Result + Chr(StrToInt(H));
        Inc(I, 3);
        Continue;
      end;
    end;
    Result := Result + S[I];
    Inc(I);
  end;
end;

function CBPathToFileUrl(const APath: string): string;
var
  I: Integer;
  S: string;
begin
  { 7.3：\ を / に、% → %25、# → %23、空白 → %20。日本語はそのまま }
  S := '';
  for I := 1 to Length(APath) do
    case APath[I] of
      '\': S := S + '/';
      '%': S := S + '%25';
      '#': S := S + '%23';
      ' ': S := S + '%20';
    else
      S := S + APath[I];
    end;
  if Copy(S, 1, 2) = '//' then
    Result := 'file:' + S          { \\server\share → file://server/share }
  else
    Result := 'file:///' + S;
end;

function CBFileUrlToPath(const AUrl: string): string;
var
  S: string;
begin
  if StartsText('file:///', AUrl) then
    S := Copy(AUrl, 9, MaxInt)
  else if StartsText('file://', AUrl) then
    S := '//' + Copy(AUrl, 8, MaxInt)   { file://server/share → \\server\share }
  else
    S := AUrl;
  S := CBPercentDecode(S);
  Result := StringReplace(S, '/', '\', [rfReplaceAll]);
end;

function CBClassifyLocation(const S: string; out AKind: TCBookmarkKind; out ALocation: string): Boolean;
var
  T: string;
begin
  Result := False;
  AKind := bkUrl;
  ALocation := '';
  T := Trim(S);
  if T = '' then Exit;
  if StartsText('file:', T) then
  begin
    AKind := bkFile;
    ALocation := CBFileUrlToPath(T);
    Exit(ALocation <> '');
  end;
  if Pos('://', T) > 0 then
  begin
    AKind := bkUrl;
    ALocation := T;
    Exit(True);
  end;
  if ((Length(T) >= 3) and (T[1] in ['A'..'Z', 'a'..'z']) and (T[2] = ':') and (T[3] in ['\', '/']))
    or (Copy(T, 1, 2) = '\\') then
  begin
    AKind := bkFile;
    ALocation := StringReplace(T, '/', '\', [rfReplaceAll]);
    Exit(True);
  end;
end;

function CBHostOf(const AUrl: string): string;
var
  P, I: Integer;
  S: string;
begin
  Result := '';
  P := Pos('://', AUrl);
  if P = 0 then Exit;
  S := Copy(AUrl, P + 3, MaxInt);
  for I := 1 to Length(S) do
    if S[I] in ['/', '?', '#', '\'] then
    begin
      S := Copy(S, 1, I - 1);
      Break;
    end;
  P := Pos('@', S);                  { user:pass@host は host だけ }
  if P > 0 then S := Copy(S, P + 1, MaxInt);
  Result := LowerCase(S);
end;

{ ホスト名からアイコンのファイル名の部分を作る（「:」は「_」。使えない文字も「_」） }
function CBHostFileKey(const AHost: string): string;
var
  I: Integer;
begin
  Result := AHost;
  for I := 1 to Length(Result) do
    if Result[I] in [':', '\', '/', '*', '?', '"', '<', '>', '|'] then Result[I] := '_';
end;

{ 2026-10-27T23:40:00 の形 }
function CBDateToIso(ADate: TDateTime): string;
var
  Y, Mo, D, H, Mi, S, Ms: Word;
begin
  DecodeDateTime(ADate, Y, Mo, D, H, Mi, S, Ms);
  Result := Format('%.4d-%.2d-%.2dT%.2d:%.2d:%.2d', [Y, Mo, D, H, Mi, S]);
end;

function CBIsoToDate(const S: string): TDateTime;
var
  Y, Mo, D, H, Mi, Sc: Integer;
begin
  Result := 0;
  if Length(S) < 19 then Exit;
  Y := StrToIntDef(Copy(S, 1, 4), 0);
  Mo := StrToIntDef(Copy(S, 6, 2), 0);
  D := StrToIntDef(Copy(S, 9, 2), 0);
  H := StrToIntDef(Copy(S, 12, 2), 0);
  Mi := StrToIntDef(Copy(S, 15, 2), 0);
  Sc := StrToIntDef(Copy(S, 18, 2), 0);
  if not IsValidDateTime(Y, Mo, D, H, Mi, Sc, 0) then Exit;
  Result := EncodeDateTime(Y, Mo, D, H, Mi, Sc, 0);
end;

{ 文字参照にする }
function CBHtmlEscape(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

{ 文字参照を元に戻す（&amp; &lt; &gt; &quot; &#39; &#nnn; &#xhh;） }
function CBHtmlDecode(const S: string): string;
var
  I, J, N, Code: Integer;
  E: string;
begin
  Result := '';
  I := 1;
  N := Length(S);
  while I <= N do
  begin
    if S[I] = '&' then
    begin
      J := I + 1;
      while (J <= N) and (J - I <= 10) and (S[J] <> ';') do Inc(J);
      if (J <= N) and (S[J] = ';') then
      begin
        E := LowerCase(Copy(S, I + 1, J - I - 1));
        Code := -1;
        if E = 'amp' then Code := Ord('&')
        else if E = 'lt' then Code := Ord('<')
        else if E = 'gt' then Code := Ord('>')
        else if E = 'quot' then Code := Ord('"')
        else if E = 'apos' then Code := Ord('''')
        else if E = 'nbsp' then Code := 32
        else if (Length(E) > 1) and (E[1] = '#') then
        begin
          if (Length(E) > 2) and (E[2] = 'x') then
            Code := StrToIntDef('$' + Copy(E, 3, MaxInt), -1)
          else
            Code := StrToIntDef(Copy(E, 2, MaxInt), -1);
        end;
        if (Code > 0) and (Code <= $FFFF) then   { 補助面の文字は使われないので扱わない }
        begin
          Result := Result + UTF8Encode(UnicodeString(WideChar(Word(Code))));
          I := J + 1;
          Continue;
        end;
      end;
    end;
    Result := Result + S[I];
    Inc(I);
  end;
end;

{ 検索用に、全角英数字を半角に、全角空白を半角に、小文字にする }
function CBNormalize(const S: string): UnicodeString;
var
  I: Integer;
  C: Word;
begin
  Result := UTF8Decode(S);
  for I := 1 to Length(Result) do
  begin
    C := Ord(Result[I]);
    if (C >= $FF01) and (C <= $FF5E) then
      Result[I] := WideChar(C - $FEE0)
    else if C = $3000 then
      Result[I] := ' ';
  end;
  Result := WideLowerCase(Result);
end;

function CBReadFileBytes(const AFileName: string): TBytes;
var
  F: TFileStream;
begin
  Result := nil;
  F := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, F.Size);
    if F.Size > 0 then F.ReadBuffer(Result[0], F.Size);
  finally
    F.Free;
  end;
end;

function CBReadFileText(const AFileName: string): string;
var
  B: TBytes;
begin
  B := CBReadFileBytes(AFileName);
  SetLength(Result, Length(B));
  if Length(B) > 0 then Move(B[0], Result[1], Length(B));
  { UTF-8 の BOM は外す }
  if Copy(Result, 1, 3) = #$EF#$BB#$BF then Delete(Result, 1, 3);
end;

procedure CBWriteFileBytes(const AFileName: string; const AData; ALen: Integer);
var
  F: TFileStream;
begin
  F := TFileStream.Create(AFileName, fmCreate);
  try
    if ALen > 0 then F.WriteBuffer(AData, ALen);
  finally
    F.Free;
  end;
end;

procedure CBWriteFileText(const AFileName, S: string);
var
  F: TFileStream;
begin
  F := TFileStream.Create(AFileName, fmCreate);
  try
    if S <> '' then F.WriteBuffer(S[1], Length(S));
  finally
    F.Free;
  end;
end;

{ PNG か ICO の中身か（無いページの HTML などを捨てるため） }
function CBIsPng(const AData: TBytes): Boolean;
begin
  Result := (Length(AData) >= 8) and (AData[0] = $89) and (AData[1] = $50) and (AData[2] = $4E) and (AData[3] = $47);
end;

function CBIsIco(const AData: TBytes): Boolean;
begin
  Result := (Length(AData) >= 22) and (AData[0] = 0) and (AData[1] = 0) and (AData[2] = 1) and (AData[3] = 0);
end;

function CBLE32(const AData: TBytes; P: Integer): DWORD;
begin
  Result := DWORD(AData[P]) or (DWORD(AData[P + 1]) shl 8) or (DWORD(AData[P + 2]) shl 16) or (DWORD(AData[P + 3]) shl 24);
end;

{ PNG・ICO の中身から、ASize の大きさのアイコンを作る（作れなければ 0）。
  ICO は、中の画像のうち ASize 以上で一番小さいもの（無ければ一番大きいもの）を使う }
function CBIconFromBytes(const AData: TBytes; ASize: Integer): HICON;
var
  N, I, W, Best, BestW, Off, Len: Integer;
begin
  Result := 0;
  if CBIsPng(AData) then
    Exit(CBCreateIconFromResourceEx(@AData[0], Length(AData), True, $00030000, ASize, ASize, 0));
  if not CBIsIco(AData) then Exit;
  N := AData[4] or (AData[5] shl 8);
  if (N <= 0) or (6 + N * 16 > Length(AData)) then Exit;
  Best := -1;
  BestW := 0;
  for I := 0 to N - 1 do
  begin
    W := AData[6 + I * 16];
    if W = 0 then W := 256;
    if Best < 0 then
    begin
      Best := I;
      BestW := W;
    end
    else if (W >= ASize) and ((BestW < ASize) or (W < BestW)) then
    begin
      Best := I;
      BestW := W;
    end
    else if (BestW < ASize) and (W > BestW) then
    begin
      Best := I;
      BestW := W;
    end;
  end;
  Len := CBLE32(AData, 6 + Best * 16 + 8);
  Off := CBLE32(AData, 6 + Best * 16 + 12);
  if (Off <= 0) or (Len <= 0) or (Off + Len > Length(AData)) then Exit;
  Result := CBCreateIconFromResourceEx(@AData[Off], Len, True, $00030000, ASize, ASize, 0);
end;

{ .url の中の URL を読む }
function CBReadUrlFile(const AFileName: string): string;
var
  Ini: TIniFile;
begin
  Result := '';
  try
    Ini := TIniFile.Create(AFileName);
    try
      Result := Trim(Ini.ReadString('InternetShortcut', 'URL', ''));
    finally
      Ini.Free;
    end;
  except
    Result := '';
  end;
end;

{ .lnk のリンク先を読む（画面を出さない）。読めなければ '' }
function CBResolveLink(const AFileName: string): string;
var
  Unk: IUnknown;
  SL: ICBShellLinkW;
  PF: ICBPersistFile;
  Buf: array[0..MAX_PATH * 2] of WideChar;
  W: UnicodeString;
begin
  Result := '';
  try
    if CBCoCreateInstance(CLSID_CBShellLink, nil, 1 { CLSCTX_INPROC_SERVER }, IID_CBUnknown, Unk) <> S_OK then Exit;
    if Unk.QueryInterface(ICBShellLinkW, SL) <> S_OK then Exit;
    if SL.QueryInterface(ICBPersistFile, PF) <> S_OK then Exit;
    W := UTF8Decode(AFileName);
    if PF.Load(PWideChar(W), 0) <> S_OK then Exit;
    SL.Resolve(0, CBSLR_NO_UI);
    FillChar(Buf, SizeOf(Buf), 0);
    if SL.GetPath(@Buf[0], Length(Buf) - 1, nil, 0) <> S_OK then Exit;
    Result := UTF8Encode(UnicodeString(PWideChar(@Buf[0])));
  except
    Result := '';
  end;
end;

{ ================================================================== }
{ TCBookmarkItem                                                     }
{ ================================================================== }

constructor TCBookmarkItem.Create(AKind: TCBookmarkKind);
begin
  inherited Create;
  FKind := AKind;
  FAddDate := Now;
  if AKind = bkFolder then FItems := TFPList.Create;
end;

destructor TCBookmarkItem.Destroy;
var
  I: Integer;
begin
  if FItems <> nil then
  begin
    for I := 0 to FItems.Count - 1 do TCBookmarkItem(FItems[I]).Free;
    FItems.Free;
  end;
  inherited Destroy;
end;

function TCBookmarkItem.GetCount: Integer;
begin
  if FItems = nil then Result := 0 else Result := FItems.Count;
end;

function TCBookmarkItem.GetItem(AIndex: Integer): TCBookmarkItem;
begin
  Result := TCBookmarkItem(FItems[AIndex]);
end;

function TCBookmarkItem.GetIndex: Integer;
begin
  if (FParent = nil) or (FParent.FItems = nil) then Result := -1
  else Result := FParent.FItems.IndexOf(Self);
end;

procedure TCBookmarkItem.InsertChild(AIndex: Integer; AItem: TCBookmarkItem);
begin
  if FItems = nil then Exit;
  if (AIndex < 0) or (AIndex > FItems.Count) then AIndex := FItems.Count;
  FItems.Insert(AIndex, AItem);
  AItem.FParent := Self;
end;

procedure TCBookmarkItem.RemoveChild(AItem: TCBookmarkItem);
begin
  if FItems = nil then Exit;
  FItems.Remove(AItem);
  if AItem.FParent = Self then AItem.FParent := nil;
end;

function TCBookmarkItem.IsDescendantOf(AItem: TCBookmarkItem): Boolean;
var
  P: TCBookmarkItem;
begin
  Result := False;
  if AItem = nil then Exit;
  P := FParent;
  while P <> nil do
  begin
    if P = AItem then Exit(True);
    P := P.FParent;
  end;
end;

function TCBookmarkItem.Clone: TCBookmarkItem;
var
  I: Integer;
begin
  Result := TCBookmarkItem.Create(FKind);
  Result.FName := FName;
  Result.FLocation := FLocation;
  Result.FExpanded := FExpanded;
  Result.FAddDate := FAddDate;
  Result.FFileMissing := FFileMissing;
  for I := 0 to Count - 1 do
    Result.InsertChild(-1, Items[I].Clone);
end;

function TCBookmarkItem.DescendantCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Count - 1 do
    Inc(Result, 1 + Items[I].DescendantCount);
end;

{ ================================================================== }
{ TCBookmarkTree                                                     }
{ ================================================================== }

procedure TCBookmarkTree.CreateWnd;
begin
  inherited CreateWnd;
  { 外部からの D&D の受け取りを登録する（実行時のみ） }
  if (FBM <> nil) and not (csDesigning in FBM.ComponentState) then
  begin
    if FDropTarget = nil then FDropTarget := TCBookmarkDropTarget.Create(FBM);
    CBRegisterDragDrop(Handle, Pointer(FDropTarget));
  end;
end;

procedure TCBookmarkTree.DestroyWnd;
begin
  if FDropTarget <> nil then CBRevokeDragDrop(Handle);
  inherited DestroyWnd;
end;

procedure TCBookmarkTree.ShowIndicator(AItem: TCBookmarkItem; APos: TCBookmarkDropPos);
begin
  if FIndOn and (FIndItem = AItem) and (FIndPos = APos) then Exit;
  FIndOn := True;
  FIndItem := AItem;
  FIndPos := APos;
  Invalidate;
end;

procedure TCBookmarkTree.HideIndicator;
begin
  if not FIndOn then Exit;
  FIndOn := False;
  FIndItem := nil;
  Invalidate;
end;

procedure TCBookmarkTree.Paint;
var
  R: TRect;
  Y, X0: Integer;
  N, Last: TTreeNode;
begin
  inherited Paint;
  if not FIndOn then Exit;
  { 落とす位置：前・後は横線、中はフォルダーの行を枠で囲む。色は clHighlight }
  Canvas.Pen.Color := clHighlight;
  Canvas.Pen.Width := 2;
  Canvas.Brush.Style := bsClear;
  if (FIndItem <> nil) and (FIndItem.FNode <> nil) then
  begin
    R := FIndItem.FNode.DisplayRect(False);
    X0 := FIndItem.FNode.DisplayTextLeft - 4;
    if X0 < 0 then X0 := 0;
    case FIndPos of
      bdpBefore:
        begin
          Canvas.MoveTo(X0, R.Top + 1);
          Canvas.LineTo(R.Right, R.Top + 1);
        end;
      bdpAfter:
        begin
          Canvas.MoveTo(X0, R.Bottom - 1);
          Canvas.LineTo(R.Right, R.Bottom - 1);
        end;
      bdpInside:
        Canvas.Rectangle(R.Left + 1, R.Top + 1, R.Right - 1, R.Bottom - 1);
    end;
  end
  else
  begin
    { 一番下：最後に見えている行の下に線 }
    Last := nil;
    N := Items.GetFirstVisibleNode;
    while N <> nil do
    begin
      Last := N;
      N := N.GetNextVisible;
    end;
    if Last <> nil then Y := Last.DisplayRect(False).Bottom - 1 else Y := 2;
    Canvas.MoveTo(0, Y);
    Canvas.LineTo(ClientWidth, Y);
  end;
  Canvas.Pen.Width := 1;
end;

{ ================================================================== }
{ TCBookmarkDropTarget                                        }
{ ================================================================== }

function CBMakeFormat(ACf: UINT): FORMATETC;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.cfFormat := ACf;
  Result.ptd := nil;
  Result.dwAspect := 1;     { DVASPECT_CONTENT }
  Result.lindex := -1;
  Result.tymed := 1;        { TYMED_HGLOBAL }
end;

function CBHasFormat(const AData: IDataObject; ACf: UINT): Boolean;
var
  F: FORMATETC;
begin
  if (AData = nil) or (ACf = 0) then Exit(False);
  F := CBMakeFormat(ACf);
  Result := AData.QueryGetData(F) = S_OK;
end;

{ HGLOBAL の中身を Unicode 文字列として読む }
function CBGetUnicodeText(const AData: IDataObject; ACf: UINT): string;
var
  F: FORMATETC;
  M: STGMEDIUM;
  P: PWideChar;
begin
  Result := '';
  if (AData = nil) or (ACf = 0) then Exit;
  F := CBMakeFormat(ACf);
  FillChar(M, SizeOf(M), 0);
  if AData.GetData(F, M) <> S_OK then Exit;
  try
    P := GlobalLock(M.hGlobal);
    if P <> nil then
    try
      Result := UTF8Encode(UnicodeString(P));
    finally
      GlobalUnlock(M.hGlobal);
    end;
  finally
    CBReleaseStgMedium(M);
  end;
end;

{ CF_HDROP のファイル名を読む }
procedure CBGetDropFiles(const AData: IDataObject; AList: TStrings);
var
  F: FORMATETC;
  M: STGMEDIUM;
  H: THandle;
  N, I, L: UINT;
  W: UnicodeString;
begin
  AList.Clear;
  F := CBMakeFormat(CF_HDROP);
  FillChar(M, SizeOf(M), 0);
  if AData.GetData(F, M) <> S_OK then Exit;
  try
    H := M.hGlobal;
    N := CBDragQueryFileW(H, $FFFFFFFF, nil, 0);
    for I := 0 to N - 1 do
    begin
      L := CBDragQueryFileW(H, I, nil, 0);
      SetLength(W, L);
      if L > 0 then CBDragQueryFileW(H, I, PWideChar(W), L + 1);
      if W <> '' then AList.Add(UTF8Encode(W));
    end;
  finally
    CBReleaseStgMedium(M);
  end;
end;

{ ブラウザが付ける「タイトル.url」からタイトルを読む }
function CBGetDropTitle(const AData: IDataObject): string;
var
  F: FORMATETC;
  M: STGMEDIUM;
  P: PByte;
  D: PCBFileDescriptorW;
begin
  Result := '';
  if not CBHasFormat(AData, GCfFileGroupW) then Exit;
  F := CBMakeFormat(GCfFileGroupW);
  FillChar(M, SizeOf(M), 0);
  if AData.GetData(F, M) <> S_OK then Exit;
  try
    P := GlobalLock(M.hGlobal);
    if P <> nil then
    try
      if PDWORD(P)^ > 0 then
      begin
        D := PCBFileDescriptorW(P + SizeOf(DWORD));
        Result := UTF8Encode(UnicodeString(PWideChar(@D^.cFileName[0])));
        if LowerCase(ExtractFileExt(Result)) = '.url' then
          Result := ChangeFileExt(Result, '');
      end;
    finally
      GlobalUnlock(M.hGlobal);
    end;
  finally
    CBReleaseStgMedium(M);
  end;
end;

constructor TCBookmarkDropTarget.Create(ABM: TCBookmark);
begin
  inherited Create;
  FBM := ABM;
end;

function TCBookmarkDropTarget.PickEffect(AAllowed: DWORD): DWORD;
begin
  { 登録するのはリンクなので、リンクを優先する }
  if (AAllowed and CBDropEffectLink) <> 0 then Result := CBDropEffectLink
  else if (AAllowed and CBDropEffectCopy) <> 0 then Result := CBDropEffectCopy
  else Result := CBDropEffectNone;
end;

function TCBookmarkDropTarget.DragEnter(const dataObj: IDataObject; grfKeyState: DWORD; pt: TPoint;
  var dwEffect: DWORD): HResult; stdcall;
begin
  { 検索中は落とせない（入れる位置が決まらないため） }
  { 自分で始めた OLE のドラッグは、自分のツリーでは受けない（同じブックマークが増えないように） }
  FCanDrop := (not FBM.FSearching) and (not FBM.FOleDragging) and
    (CBHasFormat(dataObj, CF_HDROP) or CBHasFormat(dataObj, GCfUrlW) or
     (CBHasFormat(dataObj, CF_UNICODETEXT) and (Pos('://', CBGetUnicodeText(dataObj, CF_UNICODETEXT)) > 0)));
  if FCanDrop then
  begin
    FBM.FExtDragging := True;
    FBM.BeginDragTimer;
    dwEffect := PickEffect(dwEffect);
  end
  else
    dwEffect := CBDropEffectNone;
  Result := S_OK;
end;

function TCBookmarkDropTarget.DragOver(grfKeyState: DWORD; pt: TPoint; var dwEffect: DWORD): HResult; stdcall;
var
  P: TPoint;
  T: TCBookmarkItem;
  DP: TCBookmarkDropPos;
begin
  Result := S_OK;
  if not FCanDrop then
  begin
    dwEffect := CBDropEffectNone;
    Exit;
  end;
  P := FBM.FTree.ScreenToClient(pt);
  if FBM.CalcDrop(P.X, P.Y, T, DP) then
  begin
    FBM.FTree.ShowIndicator(T, DP);
    dwEffect := PickEffect(dwEffect);
  end
  else
  begin
    FBM.FTree.HideIndicator;
    dwEffect := CBDropEffectNone;
  end;
end;

function TCBookmarkDropTarget.DragLeave: HResult; stdcall;
begin
  FBM.FTree.HideIndicator;
  FBM.FExtDragging := False;
  FBM.EndDragTimer;
  FCanDrop := False;
  Result := S_OK;
end;

function TCBookmarkDropTarget.Drop(const dataObj: IDataObject; grfKeyState: DWORD; pt: TPoint;
  var dwEffect: DWORD): HResult; stdcall;
var
  P: TPoint;
  T: TCBookmarkItem;
  DP: TCBookmarkDropPos;
  S: string;
begin
  Result := S_OK;
  FBM.FTree.HideIndicator;
  FBM.FExtDragging := False;
  FBM.EndDragTimer;
  if not FCanDrop then
  begin
    dwEffect := CBDropEffectNone;
    Exit;
  end;
  FCanDrop := False;
  P := FBM.FTree.ScreenToClient(pt);
  if not FBM.CalcDrop(P.X, P.Y, T, DP) then
  begin
    dwEffect := CBDropEffectNone;
    Exit;
  end;
  { ドロップされた内容を写しておき、ドロップの処理を終えてから登録する }
  FBM.FPendingFiles.Clear;
  FBM.FPendingUrl := '';
  FBM.FPendingTitle := '';
  FBM.FPendingIsUrl := False;
  if CBHasFormat(dataObj, CF_HDROP) then
    CBGetDropFiles(dataObj, FBM.FPendingFiles)
  else
  begin
    S := '';
    if CBHasFormat(dataObj, GCfUrlW) then S := Trim(CBGetUnicodeText(dataObj, GCfUrlW));
    if S = '' then
    begin
      S := Trim(CBGetUnicodeText(dataObj, CF_UNICODETEXT));
      if Pos('://', S) = 0 then S := '';
      if Pos(#10, S) > 0 then S := Trim(Copy(S, 1, Pos(#10, S) - 1));   { 1行目だけ }
    end;
    if S <> '' then
    begin
      FBM.FPendingIsUrl := True;
      FBM.FPendingUrl := S;
      FBM.FPendingTitle := CBGetDropTitle(dataObj);
    end;
  end;
  if (FBM.FPendingFiles.Count = 0) and not FBM.FPendingIsUrl then
  begin
    dwEffect := CBDropEffectNone;
    Exit;
  end;
  FBM.FPendingTarget := T;
  FBM.FPendingPos := DP;
  dwEffect := PickEffect(dwEffect);
  Application.QueueAsyncCall(@FBM.AsyncExternalDrop, 0);
end;

{ ================================================================== }
{ TCBookmarkUrlData（アプリの外へ URL を渡すデータ）            }
{ ================================================================== }

const
  CBDV_E_FORMATETC = HResult($80040064);
  CBOLE_E_ADVISENOTSUPPORTED = HResult($80040003);

{ 「名前.url」の名前に使えない文字を「_」にする。空になったら AFallback }
function CBSafeFileName(const AName, AFallback: string): string;
var
  I: Integer;
begin
  Result := Trim(AName);
  for I := 1 to Length(Result) do
    if Result[I] in ['\', '/', ':', '*', '?', '"', '<', '>', '|', #0..#31] then Result[I] := '_';
  while (Result <> '') and (Result[Length(Result)] in ['.', ' ']) do Delete(Result, Length(Result), 1);
  if UTF8Length(Result) > 200 then Result := UTF8Copy(Result, 1, 200);
  if Result = '' then Result := CBHostFileKey(AFallback);
  if Result = '' then Result := 'link';
end;

{ URL の ASCII 以外の文字を %xx にする（.url の中身・ANSI の URL 用） }
function CBUrlToAscii(const AUrl: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AUrl) do
    if Ord(AUrl[I]) >= 128 then Result := Result + '%' + IntToHex(Ord(AUrl[I]), 2)
    else Result := Result + AUrl[I];
end;

{ バイト列を HGLOBAL にして渡す }
function CBMakeHGlobal(const AData; ALen: Integer): HGLOBAL;
var
  P: Pointer;
begin
  Result := GlobalAlloc(GMEM_MOVEABLE or GMEM_ZEROINIT, ALen);
  if Result = 0 then Exit;
  P := GlobalLock(Result);
  try
    if ALen > 0 then Move(AData, P^, ALen);
  finally
    GlobalUnlock(Result);
  end;
end;

constructor TCBookmarkUrlData.Create(const AName, AUrl: string);
var
  I: Integer;
begin
  inherited Create;
  FUrl := AUrl;
  FFileName := CBSafeFileName(AName, CBHostOf(AUrl)) + '.url';
  for I := 0 to High(FFormats) do
  begin
    FillChar(FFormats[I], SizeOf(FFormats[I]), 0);
    FFormats[I].dwAspect := 1;             { DVASPECT_CONTENT }
    FFormats[I].lindex := -1;
    FFormats[I].tymed := 1;                { TYMED_HGLOBAL }
  end;
  FFormats[0].cfFormat := GCfFileGroupW;    { 「名前.url」という仮のファイル }
  FFormats[1].cfFormat := GCfFileContents;  { その中身 }
  FFormats[1].lindex := 0;
  FFormats[2].cfFormat := GCfUrlW;          { URL（Unicode） }
  FFormats[3].cfFormat := GCfUrlA;          { URL（ANSI） }
  FFormats[4].cfFormat := CF_UNICODETEXT;   { URL の文字 }
end;

function TCBookmarkUrlData.FindFormat(pformatetc: PCBFormatEtc): Integer;
var
  I: Integer;
begin
  Result := -1;
  if pformatetc = nil then Exit;
  if (pformatetc^.tymed and 1) = 0 then Exit;
  for I := 0 to High(FFormats) do
    if pformatetc^.cfFormat = FFormats[I].cfFormat then
    begin
      { FileContents は 0 番目のファイルだけ（lindex は 0 か -1） }
      if (I = 1) and not ((pformatetc^.lindex = 0) or (pformatetc^.lindex = -1)) then Exit;
      Exit(I);
    end;
end;

function TCBookmarkUrlData.GetData(pformatetcIn: PCBFormatEtc; pmedium: PCBStgMedium): HResult; stdcall;
var
  I: Integer;
  H: HGLOBAL;
  W: UnicodeString;
  A, Content: string;
  FGD: array of Byte;
  D: PCBFileDescriptorW;
begin
  Result := CBDV_E_FORMATETC;
  if pmedium = nil then Exit(E_INVALIDARG);
  I := FindFormat(pformatetcIn);
  if I < 0 then Exit;
  H := 0;
  case I of
    0:
      begin
        { FILEGROUPDESCRIPTORW：ファイル1つ（「名前.url」） }
        SetLength(FGD, SizeOf(DWORD) + SizeOf(TCBFileDescriptorW));
        FillChar(FGD[0], Length(FGD), 0);
        PDWORD(@FGD[0])^ := 1;
        D := PCBFileDescriptorW(@FGD[SizeOf(DWORD)]);
        D^.dwFlags := $8000;               { FD_LINKUI：リンクとして扱う（ブラウザと同じ） }
        W := UTF8Decode(FFileName);
        if Length(W) > MAX_PATH - 1 then SetLength(W, MAX_PATH - 1);
        if W <> '' then Move(W[1], D^.cFileName[0], Length(W) * SizeOf(WideChar));
        H := CBMakeHGlobal(FGD[0], Length(FGD));
      end;
    1:
      begin
        { .url の中身（ANSI） }
        Content := '[InternetShortcut]'#13#10'URL=' + CBUrlToAscii(FUrl) + #13#10;
        H := CBMakeHGlobal(Content[1], Length(Content));
      end;
    2, 4:
      begin
        W := UTF8Decode(FUrl) + #0;
        H := CBMakeHGlobal(W[1], Length(W) * SizeOf(WideChar));
      end;
    3:
      begin
        A := CBUrlToAscii(FUrl) + #0;
        H := CBMakeHGlobal(A[1], Length(A));
      end;
  end;
  if H = 0 then Exit(E_OUTOFMEMORY);
  FillChar(pmedium^, SizeOf(STGMEDIUM), 0);
  pmedium^.tymed := 1;                     { TYMED_HGLOBAL }
  pmedium^.hGlobal := H;                   { 受け取った側が解放する }
  Result := S_OK;
end;

function TCBookmarkUrlData.GetDataHere(pformatetc: PCBFormatEtc; pmedium: PCBStgMedium): HResult; stdcall;
begin
  Result := E_NOTIMPL;
end;

function TCBookmarkUrlData.QueryGetData(pformatetc: PCBFormatEtc): HResult; stdcall;
begin
  if FindFormat(pformatetc) >= 0 then Result := S_OK else Result := CBDV_E_FORMATETC;
end;

function TCBookmarkUrlData.GetCanonicalFormatEtc(pformatectIn, pformatetcOut: PCBFormatEtc): HResult; stdcall;
begin
  Result := E_NOTIMPL;
end;

function TCBookmarkUrlData.SetData(pformatetc: PCBFormatEtc; pmedium: PCBStgMedium; fRelease: BOOL): HResult; stdcall;
begin
  Result := E_NOTIMPL;
end;

function TCBookmarkUrlData.EnumFormatEtc(dwDirection: DWORD; out ppenumFormatEtc: IUnknown): HResult; stdcall;
begin
  ppenumFormatEtc := nil;
  if dwDirection <> 1 { DATADIR_GET } then Exit(E_NOTIMPL);
  Result := CBSHCreateStdEnumFmtEtc(Length(FFormats), @FFormats[0], ppenumFormatEtc);
end;

function TCBookmarkUrlData.DAdvise(pformatetc: PCBFormatEtc; advf: DWORD; pAdvSink: Pointer;
  out pdwConnection: DWORD): HResult; stdcall;
begin
  pdwConnection := 0;
  Result := CBOLE_E_ADVISENOTSUPPORTED;
end;

function TCBookmarkUrlData.DUnadvise(dwConnection: DWORD): HResult; stdcall;
begin
  Result := CBOLE_E_ADVISENOTSUPPORTED;
end;

function TCBookmarkUrlData.EnumDAdvise(out ppenumAdvise: IUnknown): HResult; stdcall;
begin
  ppenumAdvise := nil;
  Result := CBOLE_E_ADVISENOTSUPPORTED;
end;

{ ================================================================== }
{ TCBookmarkFaviconThread                                }
{ ================================================================== }

constructor TCBookmarkFaviconThread.Create(ABM: TCBookmark; const AHost: string);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FBM := ABM;
  FHost := AHost;
end;

procedure TCBookmarkFaviconThread.Execute;
var
  hNet, hUrl: Pointer;
  T, Code, L, N: DWORD;
  W, Agent: UnicodeString;
  Buf: array[0..8191] of Byte;
  MS: TMemoryStream;
begin
  FData := nil;
  try
    Agent := 'CXBookmark';
    hNet := CBInternetOpenW(PWideChar(Agent), 0 { PRECONFIG }, nil, nil, 0);
    if hNet <> nil then
    try
      T := 10000;                                           { 待ち時間 10 秒 }
      CBInternetSetOptionW(hNet, 2 { CONNECT_TIMEOUT }, @T, SizeOf(T));
      CBInternetSetOptionW(hNet, 6 { RECEIVE_TIMEOUT }, @T, SizeOf(T));
      W := UTF8Decode('https://' + FHost + '/favicon.ico');
      hUrl := CBInternetOpenUrlW(hNet, PWideChar(W), nil, 0,
        $80000000 { RELOAD } or $00000200 { NO_UI } or $00080000 { NO_COOKIES }, 0);
      if hUrl <> nil then
      try
        Code := 0;
        L := SizeOf(Code);
        if CBHttpQueryInfoW(hUrl, 19 { STATUS_CODE } or $20000000 { FLAG_NUMBER }, @Code, L, nil) and (Code = 200) then
        begin
          MS := TMemoryStream.Create;
          try
            repeat
              N := 0;
              if not CBInternetReadFile(hUrl, @Buf[0], SizeOf(Buf), N) then Break;
              if N > 0 then MS.WriteBuffer(Buf[0], N);
            until (N = 0) or (MS.Size > CBMaxIconBytes) or Terminated;
            if (MS.Size > 0) and (MS.Size <= CBMaxIconBytes) then
            begin
              SetLength(FData, MS.Size);
              Move(MS.Memory^, FData[0], MS.Size);
            end;
          finally
            MS.Free;
          end;
        end;
      finally
        CBInternetCloseHandle(hUrl);
      end;
    finally
      CBInternetCloseHandle(hNet);
    end;
  except
    FData := nil;
  end;
  Synchronize(@Done);
end;

procedure TCBookmarkFaviconThread.Done;
begin
  { 取り終えたとき、部品が破棄されていたら何もしない }
  if (GLiveBookmarks <> nil) and (GLiveBookmarks.IndexOf(FBM) >= 0) then
    FBM.FaviconArrived(FHost, FData);
end;

{ ================================================================== }
{ TCBookmark : 生成                                                   }
{ ================================================================== }

constructor TCBookmark.Create(AOwner: TComponent);

  function AddMI(const ACaption: string; ATag: Integer): TMenuItem;
  begin
    Result := TMenuItem.Create(FMenu);
    Result.Caption := ACaption;
    Result.Tag := ATag;
    if ACaption <> '-' then Result.OnClick := @MenuClick;
    FMenu.Items.Add(Result);
  end;

begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csSetCaption, csAcceptsControls];
  SetTextBuf('');
  BevelOuter := bvNone;
  BevelInner := bvNone;
  Width := 250;
  Height := 300;

  FRoot := TCBookmarkItem.Create(bkFolder);
  FRoot.FExpanded := True;
  FBookmarkFolder := CBDefaultFolder;
  FBookmarkFile := CBDefaultFile;
  UpdatePaths;

  FIconKeys := TStringList.Create;
  FIconKeys.Sorted := True;
  FHostIcons := TStringList.Create;
  FHostIcons.Sorted := True;
  FFetchTried := TStringList.Create;
  FFetchTried.Sorted := True;
  FFetchQueue := TStringList.Create;
  FPendingFiles := TStringList.Create;

  { アイコンの大きさは Windows の小さいアイコンの大きさ }
  FImages := TImageList.Create(Self);
  FImages.Width := GetSystemMetrics(SM_CXSMICON);
  FImages.Height := GetSystemMetrics(SM_CYSMICON);
  FGlobeIndex := -1;
  FFolderIndex := -1;
  FFolderOpenIndex := -1;

  { 検索ボックス（上端） }
  FSearch := TEdit.Create(Self);
  FSearch.ControlStyle := FSearch.ControlStyle + [csNoDesignSelectable];
  FSearch.Parent := Self;
  FSearch.Align := alTop;
  FSearch.TextHint := rsSearchHint;
  FSearch.OnChange := @SearchChange;
  FSearch.OnKeyDown := @SearchKeyDown;

  { ツリー（残りの全体） }
  FTree := TCBookmarkTree.Create(Self);
  FTree.FBM := Self;
  FTree.ControlStyle := FTree.ControlStyle + [csNoDesignSelectable];
  FTree.Parent := Self;
  FTree.Align := alClient;
  FTree.BorderStyle := bsNone;
  FTree.ReadOnly := True;            { 名前の変更はダイアログで行う }
  FTree.RowSelect := True;
  FTree.ShowLines := False;
  FTree.ShowRoot := True;
  FTree.HideSelection := False;
  FTree.ToolTips := False;
  FTree.ScrollBars := ssAutoBoth;    { スクロールが要らないときはスクロールバーを出さない }
  FTree.Options := FTree.Options + [tvoNoDoubleClickExpand];   { 左クリックで開閉するため、ダブルクリックでは開閉しない }
  FTree.Images := FImages;
  FTree.OnMouseDown := @TreeMouseDown;
  FTree.OnMouseUp := @TreeMouseUp;
  FTree.OnKeyDown := @TreeKeyDown;
  FTree.OnExpanded := @TreeExpanded;
  FTree.OnCollapsed := @TreeCollapsed;
  FTree.OnAdvancedCustomDrawItem := @TreeDrawItem;
  FTree.OnMouseMove := @TreeMouseMove;
  FTree.OnChange := @TreeSelChange;    { 選択が変わったとき }

  { 右クリックメニュー。Tag は MenuClick で使う番号 }
  FMenu := TPopupMenu.Create(Self);
  FMenu.OnPopup := @MenuPopup;
  FMiTextOpen := AddMI(rsMenuTextOpen, 1);
  FMiTextOpenNew := AddMI(rsMenuTextOpenNew, 2);
  AddMI('-', 0);
  FMiBrOpen := AddMI(rsMenuBrowserOpen, 3);
  FMiBrOpenNew := AddMI(rsMenuBrowserOpenNew, 4);
  AddMI('-', 0);
  FMiEdit := AddMI(rsMenuEdit, 5);
  FMiDelete := AddMI(rsMenuDelete, 6);
  AddMI('-', 0);
  FMiCut := AddMI(rsMenuCut, 7);
  FMiCopy := AddMI(rsMenuCopy, 8);
  FMiPaste := AddMI(rsMenuPaste, 9);
  AddMI('-', 0);
  FMiAddBookmark := AddMI(rsMenuAddBookmark, 10);
  FMiAddFolder := AddMI(rsMenuAddFolder, 11);
  FMiAddSeparator := AddMI(rsMenuAddSeparator, 12);
  AddMI('-', 0);
  FMiImport := AddMI(rsMenuImport, 13);
  FMiExport := AddMI(rsMenuExport, 14);
  FTree.PopupMenu := FMenu;

  FSearchTimer := TTimer.Create(Self);
  FSearchTimer.Enabled := False;
  FSearchTimer.Interval := 300;       { 入力の 300ms 後に検索する }
  FSearchTimer.OnTimer := @SearchTimer;

  FDragTimer := TTimer.Create(Self);
  FDragTimer.Enabled := False;
  FDragTimer.Interval := 100;
  FDragTimer.OnTimer := @DragTimer;

  if GLiveBookmarks <> nil then GLiveBookmarks.Add(Self);
end;

destructor TCBookmark.Destroy;
begin
  if GLiveBookmarks <> nil then GLiveBookmarks.Remove(Self);
  Application.RemoveAsyncCalls(Self);
  FUpdating := True;                     { ツリーを壊す間の開閉の通知を無視する }
  FCutItem := nil;
  FreeAndNil(FClip);
  FreeAndNil(FRoot);
  FreeAndNil(FIconKeys);
  FreeAndNil(FHostIcons);
  FreeAndNil(FFetchTried);
  FreeAndNil(FFetchQueue);
  FreeAndNil(FPendingFiles);
  inherited Destroy;
end;

procedure TCBookmark.CreateWnd;
begin
  inherited CreateWnd;
  { 実行時、初めて表示されたときに読み込む（設計時は読まない） }
  if (not FDataLoaded) and not (csDesigning in ComponentState) then
  begin
    FDataLoaded := True;
    LoadData;
    BuildTree;
  end;
end;

procedure TCBookmark.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then Exit;
  if AComponent = FTargetBrowser then FTargetBrowser := nil
  else if AComponent = FTargetEditor then FTargetEditor := nil;
end;

procedure TCBookmark.SetTargetBrowser(AValue: TCTabBrowser);
begin
  if FTargetBrowser = AValue then Exit;
  if FTargetBrowser <> nil then FTargetBrowser.RemoveFreeNotification(Self);
  FTargetBrowser := AValue;
  if FTargetBrowser <> nil then FTargetBrowser.FreeNotification(Self);
end;

procedure TCBookmark.SetTargetEditor(AValue: TCMonacoEditor);
begin
  if FTargetEditor = AValue then Exit;
  if FTargetEditor <> nil then FTargetEditor.RemoveFreeNotification(Self);
  FTargetEditor := AValue;
  if FTargetEditor <> nil then FTargetEditor.FreeNotification(Self);
end;

{ BookmarkFolder・BookmarkFile から、保存先のフォルダーと favicon のフォルダーを決める。
  BookmarkFolder が相対パス（空を含む）なら exe のフォルダーが起点。BookmarkFile が空なら既定のファイル名 }
procedure TCBookmark.UpdatePaths;
var
  D: string;
begin
  D := Trim(FBookmarkFolder);
  if (ExtractFileDrive(D) = '') and (Copy(D, 1, 1) <> PathDelim) then
    D := ExtractFilePath(ParamStr(0)) + D;
  FDataDir := IncludeTrailingPathDelimiter(ExpandFileName(D));
  FIconDir := FDataDir + 'icons' + PathDelim;
  if Trim(FBookmarkFile) = '' then FBookmarkFile := CBDefaultFile;
end;

function TCBookmark.IsBookmarkFolderStored: Boolean;
begin
  Result := FBookmarkFolder <> CBDefaultFolder;
end;

function TCBookmark.IsBookmarkFileStored: Boolean;
begin
  Result := FBookmarkFile <> CBDefaultFile;
end;

procedure TCBookmark.SetBookmarkFolder(const AValue: string);
begin
  if FBookmarkFolder = AValue then Exit;
  FBookmarkFolder := AValue;
  UpdatePaths;
  ReloadData;
end;

procedure TCBookmark.SetBookmarkFile(const AValue: string);
begin
  if FBookmarkFile = AValue then Exit;
  FBookmarkFile := AValue;
  UpdatePaths;
  ReloadData;
end;

{ 実行中に保存先を変えたら、新しい場所から読み直す（それまでのデータは前の場所に保存済み）。
  読み込み前（設計時・.lfm の読み込み中）は何もしない（初めて表示されたときに新しい場所から読む） }
procedure TCBookmark.ReloadData;
begin
  if (csDesigning in ComponentState) or (csLoading in ComponentState) or not FDataLoaded then Exit;
  FCutItem := nil;
  FDragItem := nil;
  FDownItem := nil;
  FDropTargetItem := nil;
  FDropOk := False;
  FPopupItem := nil;
  FHoverItem := nil;
  FPendingTarget := nil;
  FUpdating := True;
  FTree.Items.Clear;                  { 古い項目を指す行を先に消す }
  FUpdating := False;
  FreeAndNil(FRoot);
  FRoot := TCBookmarkItem.Create(bkFolder);
  FRoot.FExpanded := True;
  FHostIcons.Clear;                   { favicon のフォルダーも変わるので読み直させる }
  FFetchTried.Clear;
  LoadData;
  BuildTree;
  if Assigned(FOnChange) then FOnChange(Self);
  CheckSelection;
end;

function TCBookmark.GetSelected: TCBookmarkItem;
begin
  Result := ItemOfNode(FTree.Selected);
end;

function TCBookmark.ItemOfNode(ANode: TTreeNode): TCBookmarkItem;
begin
  if ANode = nil then Result := nil else Result := TCBookmarkItem(ANode.Data);
end;

function TCBookmark.IsInTree(AItem: TCBookmarkItem): Boolean;
var
  P: TCBookmarkItem;
begin
  Result := False;
  if AItem = nil then Exit;
  P := AItem;
  while P.FParent <> nil do P := P.FParent;
  Result := P = FRoot;
end;

{ ================================================================== }
{ 保存・読み込み                                              }
{ ================================================================== }

procedure ReadJsonItems(AParent: TCBookmarkItem; A: TJSONArray);
var
  I: Integer;
  O: TJSONObject;
  T: string;
  It: TCBookmarkItem;
  D: TJSONData;
begin
  for I := 0 to A.Count - 1 do
  begin
    if not (A.Items[I] is TJSONObject) then Continue;
    O := TJSONObject(A.Items[I]);
    T := O.Get('type', '');
    if T = 'url' then It := TCBookmarkItem.Create(bkUrl)
    else if T = 'file' then It := TCBookmarkItem.Create(bkFile)
    else if T = 'folder' then It := TCBookmarkItem.Create(bkFolder)
    else if T = 'separator' then It := TCBookmarkItem.Create(bkSeparator)
    else Continue;                       { 知らない type は読み飛ばす }
    It.FName := O.Get('name', '');
    It.FLocation := O.Get('location', '');
    It.FExpanded := O.Get('expanded', False);
    It.FAddDate := CBIsoToDate(O.Get('added', ''));
    if It.FAddDate = 0 then It.FAddDate := Now;
    AParent.InsertChild(-1, It);
    if It.FKind = bkFolder then
    begin
      D := O.Find('items');
      if D is TJSONArray then ReadJsonItems(It, TJSONArray(D));
    end;
  end;
end;

procedure WriteJsonItems(AParent: TCBookmarkItem; A: TJSONArray);
var
  I: Integer;
  It: TCBookmarkItem;
  O: TJSONObject;
  Sub: TJSONArray;
begin
  for I := 0 to AParent.Count - 1 do
  begin
    It := AParent.Items[I];
    O := TJSONObject.Create;
    case It.FKind of
      bkUrl, bkFile:
        begin
          if It.FKind = bkUrl then O.Add('type', 'url') else O.Add('type', 'file');
          O.Add('name', It.FName);
          O.Add('location', It.FLocation);
          O.Add('added', CBDateToIso(It.FAddDate));
        end;
      bkFolder:
        begin
          O.Add('type', 'folder');
          O.Add('name', It.FName);
          O.Add('expanded', It.FExpanded);
          O.Add('added', CBDateToIso(It.FAddDate));
          Sub := TJSONArray.Create;
          WriteJsonItems(It, Sub);
          O.Add('items', Sub);
        end;
      bkSeparator:
        O.Add('type', 'separator');
    end;
    A.Add(O);
  end;
end;

procedure TCBookmark.LoadData;
var
  F, B, S: string;
  J, D: TJSONData;
begin
  UpdatePaths;
  F := FDataDir + FBookmarkFile;
  if not FileExists(F) then Exit;
  try
    S := CBReadFileText(F);
    J := GetJSON(S);
    try
      if not (J is TJSONObject) then raise Exception.Create('format');
      D := TJSONObject(J).Find('items');
      if D is TJSONArray then ReadJsonItems(FRoot, TJSONArray(D));
    finally
      J.Free;
    end;
  except
    { 壊れていて読めないときは、名前を変えて残し、空で始める（空のデータで上書きしない） }
    FreeAndNil(FRoot);
    FRoot := TCBookmarkItem.Create(bkFolder);
    FRoot.FExpanded := True;
    B := F + '.broken-' + FormatDateTime('yyyymmddhhnnss', Now);
    RenameFile(F, B);
    MessageDlg(Format(rsLoadError, [B]), mtWarning, [mbOK], 0);
  end;
  RefreshMissing(FRoot, True);
end;

procedure TCBookmark.SaveData;
var
  J: TJSONObject;
  A: TJSONArray;
  S, F, T: string;
begin
  if csDesigning in ComponentState then Exit;
  J := TJSONObject.Create;
  try
    J.Add('version', 1);
    A := TJSONArray.Create;
    WriteJsonItems(FRoot, A);
    J.Add('items', A);
    S := J.FormatJSON;
  finally
    J.Free;
  end;
  F := FDataDir + FBookmarkFile;
  T := F + '.tmp';
  try
    ForceDirectories(FDataDir);
    { tmp に書いてから置き換える（書いている途中で落ちても壊れない） }
    CBWriteFileText(T, S);
    if not CBMoveFileExW(PWideChar(UTF8Decode(T)), PWideChar(UTF8Decode(F)), 1 { REPLACE_EXISTING } or 8 { WRITE_THROUGH }) then
      raise Exception.Create(SysErrorMessage(GetLastError));
  except
    on E: Exception do
      if not FSaveErrorShown then
      begin
        FSaveErrorShown := True;     { 同じ起動中は1回だけ }
        MessageDlg(Format(rsSaveError, [E.Message]), mtError, [mbOK], 0);
      end;
  end;
end;

{ 変わったあとの共通の処理：ツリーを作り直し、選び、保存し、OnChange }
procedure TCBookmark.Changed(ASelect: TCBookmarkItem);
begin
  BuildTree;
  SelectItem(ASelect);
  SaveData;
  if Assigned(FOnChange) then FOnChange(Self);
  CheckSelection;
end;

{ ツリーの選択が変わったとき（ツリーを作り直している間は知らせない） }
procedure TCBookmark.TreeSelChange(Sender: TObject; Node: TTreeNode);
begin
  if FUpdating then Exit;
  CheckSelection;
end;

{ 選択中の項目が、最後に知らせたものと違えば OnSelectionChange を出す（空になったときも出す） }
procedure TCBookmark.CheckSelection;
var
  It: TCBookmarkItem;
begin
  if FUpdating or (csDestroying in ComponentState) then Exit;
  It := GetSelected;
  if It = FLastSel then Exit;
  FLastSel := It;
  if Assigned(FOnSelectionChange) then FOnSelectionChange(Self);
end;

{ リンク先のファイルがあるかを確かめる }
procedure TCBookmark.RefreshMissing(AItem: TCBookmarkItem; ADeep: Boolean);
var
  I: Integer;
  C: TCBookmarkItem;
begin
  if AItem = nil then Exit;
  if AItem.FKind = bkFile then
  begin
    AItem.FFileMissing := not FileExists(AItem.FLocation);
    Exit;
  end;
  for I := 0 to AItem.Count - 1 do
  begin
    C := AItem.Items[I];
    if C.FKind = bkFile then
      C.FFileMissing := not FileExists(C.FLocation)
    else if ADeep and (C.FKind = bkFolder) then
      RefreshMissing(C, True);
  end;
end;

{ ================================================================== }
{ ツリー                                            }
{ ================================================================== }

procedure ClearNodes(AItem: TCBookmarkItem);
var
  I: Integer;
begin
  AItem.FNode := nil;
  for I := 0 to AItem.Count - 1 do ClearNodes(AItem.Items[I]);
end;

procedure TCBookmark.SetNodeLook(ANode: TTreeNode; AItem: TCBookmarkItem);
var
  I: Integer;
begin
  I := IconIndexOf(AItem, ANode.Expanded);
  ANode.ImageIndex := I;
  ANode.SelectedIndex := I;
  ANode.StateIndex := -1;
  if AItem.FKind = bkSeparator then
    ANode.Height := Max(6, FTree.DefaultItemHeight div 2);   { 区切り線の行は半分の高さ }
end;

procedure TCBookmark.AddNodes(AParentNode: TTreeNode; AItem: TCBookmarkItem);
var
  I: Integer;
  C: TCBookmarkItem;
  N: TTreeNode;
begin
  for I := 0 to AItem.Count - 1 do
  begin
    C := AItem.Items[I];
    N := FTree.Items.AddChildObject(AParentNode, C.FName, C);
    C.FNode := N;
    if C.FKind = bkFolder then
    begin
      AddNodes(N, C);
      N.Expanded := C.FExpanded;
    end;
    SetNodeLook(N, C);
  end;
end;

procedure TCBookmark.BuildTree;

  procedure AddMatches(AItem: TCBookmarkItem);
  var
    I: Integer;
    C: TCBookmarkItem;
    N: TTreeNode;
  begin
    for I := 0 to AItem.Count - 1 do
    begin
      C := AItem.Items[I];
      if C.FKind = bkFolder then
        AddMatches(C)
      else if (C.FKind in [bkUrl, bkFile]) and
        ((Pos(FSearchKey, CBNormalize(C.FName)) > 0) or (Pos(FSearchKey, CBNormalize(C.FLocation)) > 0)) then
      begin
        N := FTree.Items.AddChildObject(nil, C.FName, C);
        C.FNode := N;
        SetNodeLook(N, C);
      end;
    end;
  end;

begin
  MakeBaseIcons;
  FUpdating := True;
  FTree.Items.BeginUpdate;
  try
    FTree.Items.Clear;
    ClearNodes(FRoot);
    if FSearching then
      AddMatches(FRoot)                { フォルダーに関係なく1列の一覧 }
    else
      AddNodes(nil, FRoot);
  finally
    FTree.Items.EndUpdate;
    FUpdating := False;
  end;
  { 検索中は部品の中のドラッグ移動をしない }
  FTree.DragMode := dmManual;      { ドラッグは TreeMouseDown で始める（検索中は始めない） }
end;

procedure TCBookmark.UpdateAllIcons;
var
  I: Integer;
  N: TTreeNode;
  It: TCBookmarkItem;
begin
  for I := 0 to FTree.Items.Count - 1 do
  begin
    N := FTree.Items[I];
    It := ItemOfNode(N);
    if It <> nil then SetNodeLook(N, It);
  end;
  FTree.Invalidate;
end;

procedure TCBookmark.SelectItem(AItem: TCBookmarkItem);
begin
  if (AItem <> nil) and (AItem.FNode <> nil) then
  begin
    FTree.Selected := AItem.FNode;
    AItem.FNode.MakeVisible;
  end;
end;

procedure TCBookmark.TreeExpanded(Sender: TObject; Node: TTreeNode);
var
  It: TCBookmarkItem;
begin
  if FUpdating or FSearching then Exit;
  It := ItemOfNode(Node);
  if (It = nil) or (It.FKind <> bkFolder) then Exit;
  It.FExpanded := True;
  RefreshMissing(It, False);               { フォルダーを開いたときに確かめる }
  SetNodeLook(Node, It);
  FTree.Invalidate;
  SaveData;                                { 開閉の状態を保存する }
end;

procedure TCBookmark.TreeCollapsed(Sender: TObject; Node: TTreeNode);
var
  It: TCBookmarkItem;
begin
  if FUpdating or FSearching then Exit;
  It := ItemOfNode(Node);
  if (It = nil) or (It.FKind <> bkFolder) then Exit;
  It.FExpanded := False;
  SetNodeLook(Node, It);
  SaveData;
end;

{ 区切り線は自分で描く。リンク先が無いファイルは灰色の文字 }
procedure TCBookmark.TreeDrawItem(Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState;
  Stage: TCustomDrawStage; var PaintImages, DefaultDraw: Boolean);
var
  It: TCBookmarkItem;
  R: TRect;
  Y, M: Integer;
begin
  if Stage <> cdPrePaint then Exit;
  It := ItemOfNode(Node);
  if It = nil then Exit;
  if It.FKind = bkSeparator then
  begin
    R := Node.DisplayRect(False);
    if cdsSelected in State then Sender.Canvas.Brush.Color := clHighlight
    else Sender.Canvas.Brush.Color := FTree.Color;
    Sender.Canvas.Brush.Style := bsSolid;
    Sender.Canvas.FillRect(R);
    M := MulDiv(8, Screen.PixelsPerInch, 96);   { 右の余白 8 }
    Y := (R.Top + R.Bottom) div 2;
    Sender.Canvas.Pen.Color := clGrayText;
    Sender.Canvas.Pen.Width := 1;
    Sender.Canvas.MoveTo(Node.DisplayIconLeft, Y);
    Sender.Canvas.LineTo(R.Right - M, Y);
    DefaultDraw := False;
    PaintImages := False;
  end
  else if (It.FKind = bkFile) and It.FFileMissing then
  begin
    { リンク先が無いファイル：行を自分で描き、名前を灰色にする（選択中は選択の色） }
    R := Node.DisplayRect(False);
    Sender.Canvas.Brush.Style := bsSolid;
    if cdsSelected in State then
    begin
      Sender.Canvas.Brush.Color := clHighlight;
      Sender.Canvas.Font.Color := clHighlightText;
    end
    else
    begin
      Sender.Canvas.Brush.Color := FTree.Color;
      Sender.Canvas.Font.Color := clGrayText;
    end;
    Sender.Canvas.FillRect(R);
    if Node.ImageIndex >= 0 then
      FImages.Draw(Sender.Canvas, Node.DisplayIconLeft,
        R.Top + (R.Bottom - R.Top - FImages.Height) div 2, Node.ImageIndex);
    Sender.Canvas.Brush.Style := bsClear;
    Y := R.Top + (R.Bottom - R.Top - Sender.Canvas.TextHeight('Ag')) div 2;
    Sender.Canvas.TextOut(Node.DisplayTextLeft, Y, Node.Text);
    DefaultDraw := False;
    PaintImages := False;
  end;
end;

{ ================================================================== }
{ アイコン                                                    }
{ ================================================================== }

function TCBookmark.AddShellIcon(const APath: UnicodeString; AAttr, AFlags: DWORD): Integer;
var
  Info: TSHFileInfoW;
  Ico: TIcon;
begin
  Result := -1;
  FillChar(Info, SizeOf(Info), 0);
  if (SHGetFileInfoW(PWideChar(APath), AAttr, Info, SizeOf(Info),
      SHGFI_ICON or SHGFI_SMALLICON or AFlags) <> 0) and (Info.hIcon <> 0) then
  begin
    Ico := TIcon.Create;
    try
      Ico.Handle := Info.hIcon;      { TIcon が解放する }
      Result := FImages.AddIcon(Ico);
    finally
      Ico.Free;
    end;
  end;
end;

procedure TCBookmark.MakeBaseIcons;
var
  B: TBitmap;
  W, M, C: Integer;
begin
  if FBaseIconsMade then Exit;
  FBaseIconsMade := True;
  { 地球儀の絵（favicon が無い URL） }
  W := FImages.Width;
  B := TBitmap.Create;
  try
    B.SetSize(W, W);
    B.Canvas.Brush.Color := clFuchsia;
    B.Canvas.FillRect(0, 0, W, W);
    B.Canvas.Pen.Color := TColor($00A06A2E);   { 青 }
    B.Canvas.Pen.Width := Max(1, W div 16);
    B.Canvas.Brush.Style := bsClear;
    M := Max(1, W div 16);
    C := W div 2;
    B.Canvas.Ellipse(M, M, W - M, W - M);
    B.Canvas.Ellipse(W * 3 div 10, M, W - W * 3 div 10, W - M);
    B.Canvas.MoveTo(M, C);
    B.Canvas.LineTo(W - M, C);
    B.Canvas.MoveTo(W * 3 div 16, W * 5 div 16);
    B.Canvas.LineTo(W - W * 3 div 16, W * 5 div 16);
    B.Canvas.MoveTo(W * 3 div 16, W * 11 div 16);
    B.Canvas.LineTo(W - W * 3 div 16, W * 11 div 16);
    FGlobeIndex := FImages.AddMasked(B, clFuchsia);
  finally
    B.Free;
  end;
  { Windows のフォルダーのアイコン（閉じている・開いている） }
  FFolderIndex := AddShellIcon('folder', FILE_ATTRIBUTE_DIRECTORY, SHGFI_USEFILEATTRIBUTES);
  FFolderOpenIndex := AddShellIcon('folder', FILE_ATTRIBUTE_DIRECTORY, SHGFI_USEFILEATTRIBUTES or SHGFI_OPENICON);
  if FFolderOpenIndex < 0 then FFolderOpenIndex := FFolderIndex;
end;

function TCBookmark.FileIconIndex(const APath: string): Integer;
var
  Ext, Key: string;
  I: Integer;
begin
  { 拡張子ごとに覚えておく。.exe・.ico・.lnk はファイルごと }
  Ext := LowerCase(ExtractFileExt(APath));
  if Ext = '' then Ext := '.txt';
  if ((Ext = '.exe') or (Ext = '.ico') or (Ext = '.lnk')) and FileExists(APath) then
    Key := 'p:' + LowerCase(APath)
  else
    Key := 'e:' + Ext;
  I := FIconKeys.IndexOf(Key);
  if I >= 0 then Exit(PtrInt(FIconKeys.Objects[I]));
  if Key[1] = 'p' then
    Result := AddShellIcon(UTF8Decode(APath), 0, 0)
  else
    Result := AddShellIcon(UTF8Decode('x' + Ext), FILE_ATTRIBUTE_NORMAL, SHGFI_USEFILEATTRIBUTES);
  FIconKeys.AddObject(Key, TObject(PtrInt(Result)));
end;

function TCBookmark.HostIconFile(const AHost: string): string;
var
  K: string;
begin
  Result := '';
  if (AHost = '') or (FIconDir = '') then Exit;
  K := FIconDir + CBHostFileKey(AHost);
  if FileExists(K + '.png') then Result := K + '.png'
  else if FileExists(K + '.ico') then Result := K + '.ico';
end;

function TCBookmark.HostIconIndex(const AHost: string): Integer;
var
  I: Integer;
  F: string;
  H: HICON;
  Ico: TIcon;
begin
  Result := -1;
  if AHost = '' then Exit;
  I := FHostIcons.IndexOf(AHost);
  if I >= 0 then Exit(PtrInt(FHostIcons.Objects[I]));
  F := HostIconFile(AHost);
  if F <> '' then
  try
    H := CBIconFromBytes(CBReadFileBytes(F), FImages.Width);
    if H <> 0 then
    begin
      Ico := TIcon.Create;
      try
        Ico.Handle := H;
        Result := FImages.AddIcon(Ico);
      finally
        Ico.Free;
      end;
    end;
  except
    Result := -1;
  end;
  FHostIcons.AddObject(AHost, TObject(PtrInt(Result)));
end;

function TCBookmark.IconIndexOf(AItem: TCBookmarkItem; AExpanded: Boolean): Integer;
begin
  case AItem.FKind of
    bkUrl:
      begin
        Result := HostIconIndex(CBHostOf(AItem.FLocation));
        if Result < 0 then Result := FGlobeIndex;
      end;
    bkFile: Result := FileIconIndex(AItem.FLocation);
    bkFolder:
      if AExpanded then Result := FFolderOpenIndex else Result := FFolderIndex;
  else
    Result := -1;
  end;
end;

{ favicon が無ければ取りに行く（同じホストは1回の起動中に1回だけ） }
procedure TCBookmark.RequestFavicon(const AHost: string);
begin
  if (AHost = '') or (csDesigning in ComponentState) then Exit;
  if HostIconFile(AHost) <> '' then Exit;
  if FFetchTried.IndexOf(AHost) >= 0 then Exit;
  FFetchTried.Add(AHost);
  FFetchQueue.Add(AHost);
  StartNextFetch;
end;

procedure TCBookmark.StartNextFetch;
var
  H: string;
  T: TCBookmarkFaviconThread;
begin
  { 同時に取りに行くのは CBMaxFetch 件まで。残りは順番待ち }
  while (FFetchRunning < CBMaxFetch) and (FFetchQueue.Count > 0) do
  begin
    H := FFetchQueue[0];
    FFetchQueue.Delete(0);
    Inc(FFetchRunning);
    T := TCBookmarkFaviconThread.Create(Self, H);
    T.Start;
  end;
end;

procedure TCBookmark.SaveHostIcon(const AHost: string; const AData: TBytes);
var
  K, Ext: string;
  I: Integer;
begin
  if CBIsPng(AData) then Ext := '.png'
  else if CBIsIco(AData) then Ext := '.ico'
  else Exit;                              { PNG・ICO 以外は捨てる }
  K := FIconDir + CBHostFileKey(AHost);
  try
    ForceDirectories(FIconDir);
    if Ext = '.png' then DeleteFile(K + '.ico') else DeleteFile(K + '.png');
    CBWriteFileBytes(K + Ext, AData[0], Length(AData));
  except
    Exit;
  end;
  I := FHostIcons.IndexOf(AHost);         { 覚えていた「無い」を消して、読み直させる }
  if I >= 0 then FHostIcons.Delete(I);
end;

procedure TCBookmark.FaviconArrived(const AHost: string; const AData: TBytes);
begin
  Dec(FFetchRunning);
  if (Length(AData) > 0) and (HostIconFile(AHost) = '') then
  begin
    SaveHostIcon(AHost, AData);
    UpdateAllIcons;
  end;
  StartNextFetch;
end;

{ ================================================================== }
{ 項目を作る・入れる                                                 }
{ ================================================================== }

{ URL かファイルの項目を作る（判定できなければ nil）。URL なら favicon を取りに行く }
function TCBookmark.NewLink(const AName, ALocation: string): TCBookmarkItem;
var
  K: TCBookmarkKind;
  L: string;
begin
  Result := nil;
  if not CBClassifyLocation(ALocation, K, L) then Exit;
  Result := TCBookmarkItem.Create(K);
  Result.FLocation := L;
  if Trim(AName) <> '' then Result.FName := Trim(AName)
  else if K = bkFile then Result.FName := ExtractFileName(L)
  else Result.FName := L;
  if K = bkFile then
    Result.FFileMissing := not FileExists(L)
  else
    RequestFavicon(CBHostOf(L));
end;

{ 追加・貼り付けの位置：空白＝一番下、フォルダー＝中の一番下、それ以外＝その項目の下 }
procedure TCBookmark.InsertPos(AItem: TCBookmarkItem; out AParent: TCBookmarkItem; out AIndex: Integer);
begin
  if (AItem = nil) or not IsInTree(AItem) then
  begin
    AParent := FRoot;
    AIndex := FRoot.Count;
  end
  else if AItem.FKind = bkFolder then
  begin
    AParent := AItem;
    AIndex := AItem.Count;
  end
  else
  begin
    AParent := AItem.FParent;
    AIndex := AItem.Index + 1;
  end;
end;

{ 落とす位置から、入れる親と位置を決める }
procedure TCBookmark.DropDest(ATarget: TCBookmarkItem; APos: TCBookmarkDropPos; out AParent: TCBookmarkItem;
  out AIndex: Integer);
begin
  if (ATarget = nil) or not IsInTree(ATarget) then
  begin
    AParent := FRoot;
    AIndex := FRoot.Count;
    Exit;
  end;
  case APos of
    bdpBefore:
      begin
        AParent := ATarget.FParent;
        AIndex := ATarget.Index;
      end;
    bdpAfter:
      begin
        AParent := ATarget.FParent;
        AIndex := ATarget.Index + 1;
      end;
  else
    if ATarget.FKind = bkFolder then
    begin
      AParent := ATarget;
      AIndex := ATarget.Count;
    end
    else
    begin
      AParent := ATarget.FParent;
      AIndex := ATarget.Index + 1;
    end;
  end;
end;

{ 入れる。フォルダーの中に入れたら、そのフォルダーを開く }
procedure TCBookmark.DoInsert(AParent: TCBookmarkItem; AIndex: Integer; AItem: TCBookmarkItem);
begin
  if AParent = nil then AParent := FRoot;
  AParent.InsertChild(AIndex, AItem);
  if AParent <> FRoot then AParent.FExpanded := True;
end;

function TCBookmark.MoveInternal(AItem, ANewParent: TCBookmarkItem; ANewIndex: Integer): Boolean;
begin
  Result := False;
  if (AItem = nil) or (AItem = FRoot) or not IsInTree(AItem) then Exit;
  if ANewParent = nil then ANewParent := FRoot;
  if (ANewParent.FKind <> bkFolder) or not IsInTree(ANewParent) then Exit;
  { 自分自身の配下へは移動できない }
  if (ANewParent = AItem) or ANewParent.IsDescendantOf(AItem) then Exit;
  if (ANewIndex < 0) or (ANewIndex > ANewParent.Count) then ANewIndex := ANewParent.Count;
  if (AItem.FParent = ANewParent) and (AItem.Index < ANewIndex) then Dec(ANewIndex);
  AItem.FParent.RemoveChild(AItem);
  DoInsert(ANewParent, ANewIndex, AItem);
  Result := True;
end;

{ ドロップされたパスから項目を作る。AResolveLink=True のときだけ .lnk のリンク先をたどる }
function TCBookmark.ItemFromPath(const APath: string; AResolveLink: Boolean): TCBookmarkItem;
var
  P, Ext, U, Target: string;
begin
  Result := nil;
  P := ExcludeTrailingPathDelimiter(APath);
  if (Length(P) = 2) and (P[2] = ':') then P := P + '\';   { ドライブ C:\ }
  if DirectoryExists(P) then
  begin
    Result := TCBookmarkItem.Create(bkFolder);
    Result.FName := ExtractFileName(ExcludeTrailingPathDelimiter(P));
    if Result.FName = '' then Result.FName := ExcludeTrailingPathDelimiter(P);
    AddDirContents(Result, P);
    Exit;
  end;
  Ext := LowerCase(ExtractFileExt(P));
  if Ext = '.url' then
  begin
    U := CBReadUrlFile(P);
    if U <> '' then
    begin
      Result := NewLink(ChangeFileExt(ExtractFileName(P), ''), U);
      if Result <> nil then Exit;
    end;
  end
  else if (Ext = '.lnk') and AResolveLink then
  begin
    Target := CBResolveLink(P);
    if Target <> '' then
    begin
      if DirectoryExists(Target) then
      begin
        Result := ItemFromPath(Target, False);
        if Result <> nil then Result.FName := ChangeFileExt(ExtractFileName(P), '');
        Exit;
      end;
      Result := TCBookmarkItem.Create(bkFile);
      Result.FName := ChangeFileExt(ExtractFileName(P), '');
      Result.FLocation := Target;
      Result.FFileMissing := not FileExists(Target);
      Exit;
    end;
  end;
  Result := TCBookmarkItem.Create(bkFile);
  Result.FName := ExtractFileName(P);
  Result.FLocation := P;
  Result.FFileMissing := not FileExists(P);
end;

{ フォルダーの中身を同じ構造で入れる。サブフォルダーが先、ファイルが後、それぞれ名前順。
  リンク（ジャンクション・シンボリックリンク）のフォルダーはたどらない }
procedure TCBookmark.AddDirContents(AFolder: TCBookmarkItem; const ADir: string);
var
  SR: TSearchRec;
  Dirs, Files: TStringList;
  I: Integer;
  D: string;
  It: TCBookmarkItem;
begin
  D := IncludeTrailingPathDelimiter(ADir);
  Dirs := TStringList.Create;
  Files := TStringList.Create;
  try
    if FindFirst(D + '*', faAnyFile, SR) = 0 then
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        if (SR.Attr and faDirectory) <> 0 then
        begin
          if (SR.Attr and faSymLink) = 0 then Dirs.Add(SR.Name);
        end
        else
          Files.Add(SR.Name);
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
    Dirs.CaseSensitive := False;
    Files.CaseSensitive := False;
    Dirs.Sort;
    Files.Sort;
    for I := 0 to Dirs.Count - 1 do
    begin
      It := TCBookmarkItem.Create(bkFolder);
      It.FName := Dirs[I];
      AFolder.InsertChild(-1, It);
      AddDirContents(It, D + Dirs[I]);
    end;
    for I := 0 to Files.Count - 1 do
    begin
      It := ItemFromPath(D + Files[I], False);   { 中の .lnk はたどらない }
      if It <> nil then AFolder.InsertChild(-1, It);
    end;
  finally
    Dirs.Free;
    Files.Free;
  end;
end;

{ フォルダーの中のファイル・フォルダーの数（ALimit を超えたら数えるのをやめる） }
function TCBookmark.CountDirEntries(const ADir: string; ALimit: Integer): Integer;
var
  SR: TSearchRec;
  D: string;
begin
  Result := 0;
  D := IncludeTrailingPathDelimiter(ADir);
  if FindFirst(D + '*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then Continue;
      Inc(Result);
      if Result > ALimit then Exit;
      if ((SR.Attr and faDirectory) <> 0) and ((SR.Attr and faSymLink) = 0) then
        Inc(Result, CountDirEntries(D + SR.Name, ALimit - Result));
      if Result > ALimit then Exit;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

{ ================================================================== }
{ 公開メソッド                                                   }
{ ================================================================== }

function TCBookmark.AddBookmark(AParent: TCBookmarkItem; AIndex: Integer; const AName,
  ALocation: string): TCBookmarkItem;
begin
  Result := NewLink(AName, ALocation);
  if Result = nil then Exit;
  if (AParent = nil) or (AParent.FKind <> bkFolder) or not IsInTree(AParent) then AParent := FRoot;
  DoInsert(AParent, AIndex, Result);
  Changed(Result);
end;

function TCBookmark.AddFolder(AParent: TCBookmarkItem; AIndex: Integer; const AName: string): TCBookmarkItem;
begin
  Result := TCBookmarkItem.Create(bkFolder);
  Result.FName := AName;
  if (AParent = nil) or (AParent.FKind <> bkFolder) or not IsInTree(AParent) then AParent := FRoot;
  DoInsert(AParent, AIndex, Result);
  Changed(Result);
end;

function TCBookmark.AddSeparator(AParent: TCBookmarkItem; AIndex: Integer): TCBookmarkItem;
begin
  Result := TCBookmarkItem.Create(bkSeparator);
  if (AParent = nil) or (AParent.FKind <> bkFolder) or not IsInTree(AParent) then AParent := FRoot;
  DoInsert(AParent, AIndex, Result);
  Changed(Result);
end;

procedure TCBookmark.DeleteItem(AItem: TCBookmarkItem);
var
  Next: TCBookmarkItem;
  P: TCBookmarkItem;
  I: Integer;
begin
  if (AItem = nil) or (AItem = FRoot) or not IsInTree(AItem) then Exit;
  { 切り取った項目（またはそれを含むフォルダー）を消したら、切取りを取り消す }
  if (FCutItem <> nil) and ((FCutItem = AItem) or FCutItem.IsDescendantOf(AItem)) then FCutItem := nil;
  if (FLastSel <> nil) and ((FLastSel = AItem) or FLastSel.IsDescendantOf(AItem)) then FLastSel := nil;
  if (FDragItem <> nil) and ((FDragItem = AItem) or FDragItem.IsDescendantOf(AItem)) then FDragItem := nil;
  if (FDownItem <> nil) and ((FDownItem = AItem) or FDownItem.IsDescendantOf(AItem)) then FDownItem := nil;
  if (FDropTargetItem <> nil) and ((FDropTargetItem = AItem) or FDropTargetItem.IsDescendantOf(AItem)) then
  begin
    FDropTargetItem := nil;
    FDropOk := False;
  end;
  { 消したあとに選ぶ項目：同じ親の次、無ければ前、無ければ親 }
  P := AItem.FParent;
  I := AItem.Index;
  P.RemoveChild(AItem);
  AItem.Free;
  if I < P.Count then Next := P.Items[I]
  else if P.Count > 0 then Next := P.Items[P.Count - 1]
  else if P <> FRoot then Next := P
  else Next := nil;
  Changed(Next);
end;

function TCBookmark.MoveItem(AItem, ANewParent: TCBookmarkItem; ANewIndex: Integer): Boolean;
begin
  Result := MoveInternal(AItem, ANewParent, ANewIndex);
  if Result then Changed(AItem);
end;

procedure TCBookmark.OpenItem(AItem: TCBookmarkItem; ATarget: TCBookmarkTarget; ANewTab: Boolean);
begin
  if (AItem = nil) or not (AItem.FKind in [bkUrl, bkFile]) then Exit;
  if AItem.FKind = bkFile then
  begin
    { 開く時点でもう一度確かめ、無ければ知らせて開かない }
    AItem.FFileMissing := not FileExists(AItem.FLocation);
    FTree.Invalidate;
    if AItem.FFileMissing then
    begin
      MessageDlg(Format(rsFileMissing, [AItem.FLocation]), mtWarning, [mbOK], 0);
      Exit;
    end;
  end;
  case ATarget of
    btEditor:
      if (FTargetEditor <> nil) and (AItem.FKind = bkFile) then
        OpenInEditor(AItem.FLocation, ANewTab);
    btBrowser:
      if FTargetBrowser <> nil then
      begin
        if AItem.FKind = bkUrl then
          OpenInBrowser(AItem.FLocation, ANewTab)
        else
          OpenInBrowser(CBPathToFileUrl(AItem.FLocation), ANewTab);
      end;
  end;
end;

{ TCMonacoEditor で開く }
procedure TCBookmark.OpenInEditor(const APath: string; ANewTab: Boolean);
var
  Ed: TCMonacoEditor;
  I: Integer;
begin
  Ed := FTargetEditor;
  try
    if ANewTab then
    begin
      { すでに開いていれば、そのタブに切り替えるだけ（TCMonacoEditor の決まり） }
      if Ed.OpenFile(APath) >= 0 then Ed.SetFocus;
      Exit;
    end;
    { 1. どこかのタブで開いていれば、そのタブにする }
    I := Ed.FindPage(APath);
    if I >= 0 then
    begin
      Ed.ActiveIndex := I;
      Ed.SetFocus;
      Exit;
    end;
    { 2. 表示中のタブが未保存なら聞く。はい＝新しいタブ、いいえ＝開かない }
    if Ed.Modified then
    begin
      if MessageDlg(rsUnsaved, mtConfirmation, [mbYes, mbNo], 0) = mrYes then
        if Ed.OpenFile(APath) >= 0 then Ed.SetFocus;
      Exit;
    end;
    { 3. 表示中のタブに読み込む }
    if Ed.LoadFromFile(APath) then Ed.SetFocus;
  except
    on E: Exception do MessageDlg(Format(rsOpenError, [APath + ' : ' + E.Message]), mtError, [mbOK], 0);
  end;
end;

{ TCTabBrowser で開く }
procedure TCBookmark.OpenInBrowser(const AUrl: string; ANewTab: Boolean);
begin
  try
    if ANewTab then
      FTargetBrowser.Add(AUrl)
    else
      FTargetBrowser.Navigate(AUrl);
  except
    on E: Exception do MessageDlg(Format(rsOpenError, [AUrl + ' : ' + E.Message]), mtError, [mbOK], 0);
  end;
end;

{ ================================================================== }
{ 追加・編集のダイアログ                                         }
{ ================================================================== }

procedure TCBookmark.DlgChange(Sender: TObject);
var
  K: TCBookmarkKind;
  L: string;
begin
  if FDlgOk = nil then Exit;
  { 名前が空、または（ブックマークで）URL・ファイルパスが判定できないときは OK を押せない }
  FDlgOk.Enabled := (Trim(FDlgName.Text) <> '') and
    ((not FDlgWithLoc) or CBClassifyLocation(FDlgLoc.Text, K, L));
end;

function TCBookmark.EditDialog(const ATitle: string; var AName, ALoc: string; AWithLoc: Boolean): Boolean;
var
  F: TForm;
  L1, L2: TLabel;
  BCancel: TButton;
  Y: Integer;

  function S(V: Integer): Integer;
  begin
    Result := MulDiv(V, Screen.PixelsPerInch, 96);
  end;

begin
  Result := False;
  F := TForm.CreateNew(GetParentForm(Self));
  try
    F.Caption := ATitle;
    F.BorderStyle := bsDialog;
    F.Position := poOwnerFormCenter;
    F.ClientWidth := S(440);
    Y := S(12);

    L1 := TLabel.Create(F);
    L1.Parent := F;
    L1.Caption := rsDlgName;
    L1.SetBounds(S(12), Y, S(416), S(18));
    Inc(Y, S(20));
    FDlgName := TEdit.Create(F);
    FDlgName.Parent := F;
    FDlgName.SetBounds(S(12), Y, S(416), S(24));
    FDlgName.Text := AName;
    FDlgName.OnChange := @DlgChange;
    Inc(Y, S(34));

    FDlgWithLoc := AWithLoc;
    FDlgLoc := nil;
    if AWithLoc then
    begin
      L2 := TLabel.Create(F);
      L2.Parent := F;
      L2.Caption := rsDlgLocation;
      L2.SetBounds(S(12), Y, S(416), S(18));
      Inc(Y, S(20));
      FDlgLoc := TEdit.Create(F);
      FDlgLoc.Parent := F;
      FDlgLoc.SetBounds(S(12), Y, S(416), S(24));
      FDlgLoc.Text := ALoc;
      FDlgLoc.OnChange := @DlgChange;
      Inc(Y, S(34));
    end;

    FDlgOk := TButton.Create(F);
    FDlgOk.Parent := F;
    FDlgOk.Caption := rsOK;
    FDlgOk.ModalResult := mrOk;
    FDlgOk.Default := True;
    FDlgOk.SetBounds(S(440 - 12 - 88 - 8 - 88), Y + S(4), S(88), S(28));
    BCancel := TButton.Create(F);
    BCancel.Parent := F;
    BCancel.Caption := rsCancel;
    BCancel.ModalResult := mrCancel;
    BCancel.Cancel := True;
    BCancel.SetBounds(S(440 - 12 - 88), Y + S(4), S(88), S(28));
    F.ClientHeight := Y + S(44);
    F.ActiveControl := FDlgName;
    DlgChange(nil);

    if F.ShowModal = mrOk then
    begin
      AName := Trim(FDlgName.Text);
      if AWithLoc then ALoc := Trim(FDlgLoc.Text);
      Result := True;
    end;
  finally
    FDlgName := nil;
    FDlgLoc := nil;
    FDlgOk := nil;
    F.Free;
  end;
end;

{ ================================================================== }
{ 10. インポート・エクスポート                                       }
{ ================================================================== }

{ タグの属性を読む（name="value"・name='value'・name=value） }
function CBTagAttr(const ATag, AName: string): string;
var
  L, K: string;
  P, I, N, Start: Integer;
  Q: Char;
begin
  Result := '';
  L := LowerCase(ATag);
  K := LowerCase(AName) + '=';
  N := Length(ATag);
  Start := 1;
  while True do
  begin
    P := Pos(K, Copy(L, Start, MaxInt));
    if P = 0 then Exit;
    P := P + Start - 1;
    { 名前の前が空白であること（後ろは '=' で確かめ済み。ICON と ICON_URI を取り違えない） }
    if (P > 1) and not (L[P - 1] in [' ', #9, #10, #13]) then
    begin
      Start := P + Length(K);
      if Start > N then Exit;
      Continue;
    end;
    I := P + Length(K);
    if I > N then Exit;
    if ATag[I] in ['"', ''''] then
    begin
      Q := ATag[I];
      Inc(I);
      P := I;
      while (I <= N) and (ATag[I] <> Q) do Inc(I);
      Result := Copy(ATag, P, I - P);
    end
    else
    begin
      P := I;
      while (I <= N) and not (ATag[I] in [' ', #9, #10, #13, '>']) do Inc(I);
      Result := Copy(ATag, P, I - P);
    end;
    Exit;
  end;
end;

{ タグを外した文字（文字参照は元に戻す） }
function CBStripTags(const S: string): string;
var
  I: Integer;
  InTag: Boolean;
begin
  Result := '';
  InTag := False;
  for I := 1 to Length(S) do
    if S[I] = '<' then InTag := True
    else if S[I] = '>' then InTag := False
    else if not InTag then Result := Result + S[I];
  Result := Trim(CBHtmlDecode(Result));
end;

{ HTML を読み、ADest の中に入れる。入れた URL・ファイルの数を返す }
function TCBookmark.ParseHtml(const S: string; ADest: TCBookmarkItem): Integer;
var
  LS, TagText, TagName, Href, Icon, Txt, Mime, Host: string;
  P, N, Q, E: Integer;
  Closing: Boolean;
  Stack: TFPList;
  Pending, It: TCBookmarkItem;
  AddDate: Int64;
  Bytes: TBytes;
  B64: string;

  function CurParent: TCBookmarkItem;
  begin
    if Stack.Count > 0 then Result := TCBookmarkItem(Stack[Stack.Count - 1]) else Result := ADest;
  end;

  { P から、閉じタグ </AClose まで の文字を読み、P をその後ろへ進める }
  function ReadUntilClose(const AClose: string): string;
  var
    C: Integer;
  begin
    C := Pos('</' + AClose, Copy(LS, P, MaxInt));
    if C = 0 then
    begin
      Result := CBStripTags(Copy(S, P, MaxInt));
      P := N + 1;
      Exit;
    end;
    Result := CBStripTags(Copy(S, P, C - 1));
    P := P + C - 1;
    C := Pos('>', Copy(LS, P, MaxInt));
    if C = 0 then P := N + 1 else P := P + C;
  end;

begin
  Result := 0;
  LS := LowerCase(S);
  N := Length(S);
  P := 1;
  Pending := nil;
  Stack := TFPList.Create;
  try
    while P <= N do
    begin
      if S[P] <> '<' then
      begin
        Inc(P);
        Continue;
      end;
      { コメント }
      if Copy(S, P, 4) = '<!--' then
      begin
        Q := Pos('-->', Copy(S, P + 4, MaxInt));
        if Q = 0 then Break;
        P := P + 4 + Q + 2;
        Continue;
      end;
      { タグを1つ読む（引用符の中の > は飛ばす） }
      E := P + 1;
      while (E <= N) and (S[E] <> '>') do
      begin
        if S[E] in ['"', ''''] then
        begin
          Q := E;
          Inc(E);
          while (E <= N) and (S[E] <> S[Q]) do Inc(E);
        end;
        Inc(E);
      end;
      TagText := Copy(S, P, E - P + 1);
      P := E + 1;
      Closing := (Length(TagText) > 1) and (TagText[2] = '/');
      if Closing then Q := 3 else Q := 2;
      TagName := '';
      while (Q <= Length(TagText)) and (TagText[Q] in ['a'..'z', 'A'..'Z', '0'..'9']) do
      begin
        TagName := TagName + LowerCase(TagText[Q]);
        Inc(Q);
      end;

      if TagName = 'dl' then
      begin
        if not Closing then
        begin
          if Pending <> nil then Stack.Add(Pending)        { 直前の H3 のフォルダーの中身 }
          else if Stack.Count = 0 then Stack.Add(ADest)    { 一番外の DL }
          else Stack.Add(CurParent);
          Pending := nil;
        end
        else if Stack.Count > 0 then
          Stack.Delete(Stack.Count - 1);
      end
      else if (TagName = 'h3') and not Closing then
      begin
        Txt := ReadUntilClose('h3');
        It := TCBookmarkItem.Create(bkFolder);
        It.FName := Txt;
        AddDate := StrToInt64Def(CBTagAttr(TagText, 'add_date'), 0);
        if AddDate > 0 then It.FAddDate := UnixToDateTime(AddDate, False);
        CurParent.InsertChild(-1, It);
        Pending := It;
      end
      else if (TagName = 'a') and not Closing then
      begin
        Pending := nil;
        Href := CBHtmlDecode(CBTagAttr(TagText, 'href'));
        Icon := CBTagAttr(TagText, 'icon');
        Txt := ReadUntilClose('a');
        It := nil;
        if Href <> '' then
        begin
          { ICON があるときは、ここでは取りに行かないよう、先に保存してから作る }
          Host := CBHostOf(Href);
          if (Icon <> '') and (Host <> '') and StartsText('data:', Icon) and (HostIconFile(Host) = '') then
          begin
            Q := Pos(',', Icon);
            Mime := LowerCase(Copy(Icon, 6, Q - 6));
            if (Q > 0) and (Pos(';base64', Mime) > 0) then
            begin
              B64 := DecodeStringBase64(Copy(Icon, Q + 1, MaxInt));
              SetLength(Bytes, Length(B64));
              if Length(B64) > 0 then Move(B64[1], Bytes[0], Length(B64));
              SaveHostIcon(Host, Bytes);
            end;
          end;
          It := NewLink(Txt, Href);
        end;
        if It <> nil then
        begin
          AddDate := StrToInt64Def(CBTagAttr(TagText, 'add_date'), 0);
          if AddDate > 0 then It.FAddDate := UnixToDateTime(AddDate, False);
          CurParent.InsertChild(-1, It);
          Inc(Result);
        end;
      end
      else if (TagName = 'hr') and not Closing then
      begin
        Pending := nil;
        CurParent.InsertChild(-1, TCBookmarkItem.Create(bkSeparator));
      end;
    end;
  finally
    Stack.Free;
  end;
end;

function TCBookmark.ImportFromFile(const AFileName: string): Boolean;
var
  S: string;
  F: TCBookmarkItem;
begin
  Result := False;
  try
    S := CBReadFileText(AFileName);
  except
    on E: Exception do
    begin
      MessageDlg(Format(rsImportError, [E.Message]), mtError, [mbOK], 0);
      Exit;
    end;
  end;
  { 一番下に「インポート yyyy-mm-dd」フォルダーを作り、その中に入れる }
  F := TCBookmarkItem.Create(bkFolder);
  F.FExpanded := True;
  F.FName := Format(rsImportFolder, [FormatDateTime('yyyy"-"mm"-"dd', Now)]);
  if ParseHtml(S, F) = 0 then
  begin
    F.Free;
    Exit;
  end;
  FRoot.InsertChild(-1, F);
  Changed(F);
  Result := True;
end;

function TCBookmark.ExportToFile(const AFileName: string): Boolean;
var
  SL: TStringList;

  function IconAttr(const AUrl: string): string;
  var
    F: string;
    B: TBytes;
    Raw: string;
  begin
    Result := '';
    F := HostIconFile(CBHostOf(AUrl));
    if F = '' then Exit;
    try
      B := CBReadFileBytes(F);
      SetLength(Raw, Length(B));
      if Length(B) > 0 then Move(B[0], Raw[1], Length(B));
      if LowerCase(ExtractFileExt(F)) = '.png' then
        Result := ' ICON="data:image/png;base64,' + EncodeStringBase64(Raw) + '"'
      else
        Result := ' ICON="data:image/x-icon;base64,' + EncodeStringBase64(Raw) + '"';
    except
      Result := '';
    end;
  end;

  procedure WriteLevel(AItem: TCBookmarkItem; const AIndent: string);
  var
    I: Integer;
    C: TCBookmarkItem;
    D: string;
  begin
    for I := 0 to AItem.Count - 1 do
    begin
      C := AItem.Items[I];
      D := ' ADD_DATE="' + IntToStr(DateTimeToUnix(C.FAddDate, False)) + '"';
      case C.FKind of
        bkUrl:
          SL.Add(AIndent + '<DT><A HREF="' + CBHtmlEscape(C.FLocation) + '"' + D + IconAttr(C.FLocation) + '>' +
            CBHtmlEscape(C.FName) + '</A>');
        bkFile:
          SL.Add(AIndent + '<DT><A HREF="' + CBHtmlEscape(CBPathToFileUrl(C.FLocation)) + '"' + D + '>' +
            CBHtmlEscape(C.FName) + '</A>');
        bkSeparator:
          SL.Add(AIndent + '<HR>');
        bkFolder:
          begin
            SL.Add(AIndent + '<DT><H3' + D + '>' + CBHtmlEscape(C.FName) + '</H3>');
            SL.Add(AIndent + '<DL><p>');
            WriteLevel(C, AIndent + '    ');
            SL.Add(AIndent + '</DL><p>');
          end;
      end;
    end;
  end;

begin
  Result := False;
  SL := TStringList.Create;
  try
    SL.LineBreak := #13#10;               { 改行は CRLF }
    SL.Add('<!DOCTYPE NETSCAPE-Bookmark-file-1>');
    SL.Add('<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">');
    SL.Add('<TITLE>Bookmarks</TITLE>');
    SL.Add('<H1>Bookmarks</H1>');
    SL.Add('<DL><p>');
    WriteLevel(FRoot, '    ');
    SL.Add('</DL><p>');
    try
      CBWriteFileText(AFileName, SL.Text);
      Result := True;
    except
      on E: Exception do MessageDlg(Format(rsExportError, [E.Message]), mtError, [mbOK], 0);
    end;
  finally
    SL.Free;
  end;
end;

procedure TCBookmark.ImportWithDialog;
var
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(nil);
  try
    D.Filter := rsHtmlFilter;
    D.Options := D.Options + [ofFileMustExist];
    if not D.Execute then Exit;
    if not ImportFromFile(D.FileName) then
      if FileExists(D.FileName) then MessageDlg(rsImportNone, mtInformation, [mbOK], 0);
  finally
    D.Free;
  end;
end;

procedure TCBookmark.ExportWithDialog;
var
  D: TSaveDialog;
begin
  D := TSaveDialog.Create(nil);
  try
    D.Filter := rsHtmlFilter;
    D.DefaultExt := 'html';
    D.FileName := 'bookmarks.html';
    D.Options := D.Options + [ofOverwritePrompt];
    if D.Execute then ExportToFile(D.FileName);
  finally
    D.Free;
  end;
end;

{ ================================================================== }
{ 検索                                                           }
{ ================================================================== }

function TCBookmark.GetSearchText: string;
begin
  Result := FSearch.Text;
end;

procedure TCBookmark.SetSearchText(const AValue: string);
begin
  FSearch.Text := AValue;      { OnChange でタイマーが動くが、すぐに検索する }
  FSearchTimer.Enabled := False;
  SearchTimer(nil);
end;

procedure TCBookmark.SearchChange(Sender: TObject);
begin
  FSearchTimer.Enabled := False;
  FSearchTimer.Enabled := True;
end;

procedure TCBookmark.SearchTimer(Sender: TObject);
var
  K: UnicodeString;
  Sel: TCBookmarkItem;
begin
  FSearchTimer.Enabled := False;
  if csDesigning in ComponentState then Exit;
  K := CBNormalize(Trim(FSearch.Text));
  if (K = FSearchKey) and (FSearching = (K <> '')) then Exit;
  Sel := GetSelected;
  FSearchKey := K;
  FSearching := K <> '';
  BuildTree;
  SelectItem(Sel);
  CheckSelection;
end;

procedure TCBookmark.SearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    SetSearchText('');            { Esc で元のツリーに戻る }
    Key := 0;
  end
  else if (Key = VK_DOWN) or (Key = VK_RETURN) then
  begin
    if FTree.Items.Count > 0 then
    begin
      if FTree.Selected = nil then FTree.Selected := FTree.Items.GetFirstNode;
      FTree.SetFocus;
    end;
    Key := 0;
  end;
end;

{ ================================================================== }
{ マウス・キー                                                       }
{ ================================================================== }

procedure TCBookmark.TreeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  N: TTreeNode;
begin
  if Button = mbLeft then
  begin
    { 押した位置の項目を覚える。しきい値（SM_CXDRAG・SM_CYDRAG）を超えて動かしたら
      TreeMouseMove でドラッグを始める（TCTreeView と同じ作り。LCL のドラッグの仕組みは使わない） }
    FDragStarted := False;
    FDragArmed := False;
    FDownItem := nil;
    if htOnButton in FTree.GetHitTestInfoAt(X, Y) then Exit;
    FDownItem := ItemOfNode(FTree.GetNodeAt(X, Y));
    if (FDownItem <> nil) and not FSearching then
    begin
      FDragArmed := True;
      FDragStartPt.X := X;
      FDragStartPt.Y := Y;
    end;
  end
  else if Button = mbRight then
  begin
    { 右クリックした項目を選ぶ。空白部分なら選択を外す }
    N := FTree.GetNodeAt(X, Y);
    if N <> nil then FTree.Selected := N else FTree.Selected := nil;
    FPopupItem := ItemOfNode(N);
  end;
end;

procedure TCBookmark.TreeMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  N: TTreeNode;
  HT: THitTests;
begin
  if Button <> mbLeft then Exit;
  FDragArmed := False;
  if FDragActive then
  begin
    EndInternalDrag(True);          { 離した位置（最後に線・枠を出した位置）へ移す }
    Exit;
  end;
  if FDragStarted then
  begin
    FDragStarted := False;          { ドラッグのあとはクリックにしない }
    Exit;
  end;
  if Shift * [ssShift, ssCtrl, ssAlt] <> [] then Exit;
  HT := FTree.GetHitTestInfoAt(X, Y);
  if htOnButton in HT then Exit;    { ［▶］は TTreeView が開閉する }
  N := FTree.GetNodeAt(X, Y);
  if (N = nil) or (ItemOfNode(N) <> FDownItem) then Exit;   { 押した項目と離した項目が同じときだけクリック }
  DoItemClick(ItemOfNode(N));
end;

{ キー操作 }
procedure TCBookmark.TreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  It: TCBookmarkItem;
begin
  if FDragActive then
  begin
    if Key = VK_ESCAPE then EndInternalDrag(False);   { Esc で取りやめ }
    Key := 0;
    Exit;
  end;
  It := GetSelected;
  if Shift = [] then
    case Key of
      VK_RETURN:
        begin
          DoItemClick(It);
          Key := 0;
        end;
      VK_DELETE:
        begin
          if It <> nil then DoMenuDelete(It);
          Key := 0;
        end;
      VK_F2:
        begin
          if (It <> nil) and (It.FKind <> bkSeparator) then DoMenuEdit(It);
          Key := 0;
        end;
    end
  else if Shift = [ssCtrl] then
    case Key of
      VK_X:
        begin
          if It <> nil then DoMenuCut(It);
          Key := 0;
        end;
      VK_C:
        begin
          if It <> nil then DoMenuCopy(It);
          Key := 0;
        end;
      VK_V:
        begin
          if (not FSearching) and ((FClip <> nil) or (FCutItem <> nil)) then DoMenuPaste(It);
          Key := 0;
        end;
      VK_F:
        begin
          FSearch.SetFocus;
          FSearch.SelectAll;
          Key := 0;
        end;
    end;
end;

{ ================================================================== }
{ 右クリックメニュー                                             }
{ ================================================================== }

procedure TCBookmark.MenuPopup(Sender: TObject);
var
  It: TCBookmarkItem;
  IsLink: Boolean;
begin
  { 右クリックで選んだ項目（空白部分なら選択なし）。キーボードでメニューを出したときも同じ }
  It := GetSelected;
  FPopupItem := It;
  IsLink := (It <> nil) and (It.FKind in [bkUrl, bkFile]);
  FMiTextOpen.Enabled := (FTargetEditor <> nil) and (It <> nil) and (It.FKind = bkFile);
  FMiTextOpenNew.Enabled := FMiTextOpen.Enabled;
  FMiBrOpen.Enabled := (FTargetBrowser <> nil) and IsLink;
  FMiBrOpenNew.Enabled := FMiBrOpen.Enabled;
  FMiEdit.Enabled := (It <> nil) and (It.FKind <> bkSeparator);
  FMiDelete.Enabled := It <> nil;
  FMiCut.Enabled := It <> nil;
  FMiCopy.Enabled := It <> nil;
  { 検索中は、貼り付け・追加・インポートを灰色 }
  FMiPaste.Enabled := (not FSearching) and ((FClip <> nil) or (FCutItem <> nil));
  FMiAddBookmark.Enabled := not FSearching;
  FMiAddFolder.Enabled := not FSearching;
  FMiAddSeparator.Enabled := not FSearching;
  FMiImport.Enabled := not FSearching;
  FMiExport.Enabled := True;
end;

procedure TCBookmark.MenuClick(Sender: TObject);
var
  It: TCBookmarkItem;
begin
  It := FPopupItem;
  if (It <> nil) and not IsInTree(It) then It := nil;
  case TMenuItem(Sender).Tag of
    1: DoMenuOpen(It, btEditor, False);
    2: DoMenuOpen(It, btEditor, True);
    3: DoMenuOpen(It, btBrowser, False);
    4: DoMenuOpen(It, btBrowser, True);
    5: DoMenuEdit(It);
    6: DoMenuDelete(It);
    7: DoMenuCut(It);
    8: DoMenuCopy(It);
    9: DoMenuPaste(It);
    10: DoMenuAddBookmark(It);
    11: DoMenuAddFolder(It);
    12: DoMenuAddSeparator(It);
    13: ImportWithDialog;
    14: ExportWithDialog;
  end;
end;

{ ================================================================== }
{ 操作を受けたときの処理                                        }
{ ================================================================== }

procedure TCBookmark.DoItemClick(AItem: TCBookmarkItem);
begin
  if AItem = nil then Exit;
  case AItem.FKind of
    bkFolder:
      if (not FSearching) and (AItem.FNode <> nil) then
        AItem.FNode.Expanded := not AItem.FNode.Expanded;     { 左クリックで開閉 }
    bkUrl:
      if FTargetBrowser <> nil then OpenItem(AItem, btBrowser, False);
    bkFile:
      if FTargetEditor <> nil then OpenItem(AItem, btEditor, False);
  end;
end;

procedure TCBookmark.DoMenuOpen(AItem: TCBookmarkItem; ATarget: TCBookmarkTarget; ANewTab: Boolean);
begin
  OpenItem(AItem, ATarget, ANewTab);
end;

procedure TCBookmark.DoMenuEdit(AItem: TCBookmarkItem);
var
  N, L, L2: string;
  K: TCBookmarkKind;
  OldHost: string;
begin
  if (AItem = nil) or (AItem.FKind = bkSeparator) or not IsInTree(AItem) then Exit;
  N := AItem.FName;
  L := AItem.FLocation;
  if AItem.FKind = bkFolder then
  begin
    if not EditDialog(rsDlgEditFolder, N, L, False) then Exit;
    AItem.FName := N;
  end
  else
  begin
    if not EditDialog(rsDlgEdit, N, L, True) then Exit;
    if not CBClassifyLocation(L, K, L2) then Exit;
    OldHost := '';
    if AItem.FKind = bkUrl then OldHost := CBHostOf(AItem.FLocation);
    AItem.FName := N;
    AItem.FKind := K;                     { 編集で種類が変わってもよい }
    AItem.FLocation := L2;
    if K = bkFile then
      AItem.FFileMissing := not FileExists(L2)
    else
    begin
      AItem.FFileMissing := False;
      if CBHostOf(L2) <> OldHost then RequestFavicon(CBHostOf(L2));
    end;
  end;
  Changed(AItem);
end;

procedure TCBookmark.DoMenuDelete(AItem: TCBookmarkItem);
begin
  if (AItem = nil) or not IsInTree(AItem) then Exit;
  { フォルダーだけ確認する }
  if AItem.FKind = bkFolder then
    if MessageDlg(Format(rsDeleteFolder, [AItem.FName, AItem.DescendantCount]), mtConfirmation,
      [mbYes, mbNo], 0) <> mrYes then Exit;
  DeleteItem(AItem);
end;

{ コピーした項目の URL・ファイルパスを、Windows のクリップボードに文字で入れる }
procedure CBCollectLocations(AItem: TCBookmarkItem; AList: TStrings);
var
  I: Integer;
begin
  case AItem.FKind of
    bkUrl, bkFile: AList.Add(AItem.FLocation);
    bkFolder: for I := 0 to AItem.Count - 1 do CBCollectLocations(AItem.Items[I], AList);
  end;
end;

procedure CBPutClipboardText(AItem: TCBookmarkItem);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.LineBreak := #13#10;
    CBCollectLocations(AItem, SL);
    if SL.Count = 0 then Exit;           { 区切り線だけのときは入れない }
    try
      Clipboard.AsText := TrimRight(SL.Text);
    except
      { クリップボードが使えなくても、部品の中の写しは使える }
    end;
  finally
    SL.Free;
  end;
end;

procedure TCBookmark.DoMenuCut(AItem: TCBookmarkItem);
begin
  if (AItem = nil) or not IsInTree(AItem) then Exit;
  FreeAndNil(FClip);
  FCutItem := AItem;                     { 貼り付けるまで元の場所に残す }
  CBPutClipboardText(AItem);
end;

procedure TCBookmark.DoMenuCopy(AItem: TCBookmarkItem);
begin
  if (AItem = nil) or not IsInTree(AItem) then Exit;
  FreeAndNil(FClip);
  FCutItem := nil;
  FClip := AItem.Clone;                  { フォルダーは中身ごと }
  CBPutClipboardText(AItem);
end;

procedure TCBookmark.DoMenuPaste(AItem: TCBookmarkItem);
var
  P: TCBookmarkItem;
  I: Integer;
  C: TCBookmarkItem;
begin
  if FSearching then Exit;
  if (AItem <> nil) and not IsInTree(AItem) then AItem := nil;
  InsertPos(AItem, P, I);
  if FCutItem <> nil then
  begin
    { 切取り：貼り付けた時点で元の場所から移す。自分自身の配下へは貼れない（何もしない） }
    if not IsInTree(FCutItem) then
    begin
      FCutItem := nil;
      Exit;
    end;
    if (P = FCutItem) or P.IsDescendantOf(FCutItem) then Exit;
    C := FCutItem;
    FCutItem := nil;
    if MoveInternal(C, P, I) then Changed(C);
  end
  else if FClip <> nil then
  begin
    C := FClip.Clone;                    { 何度でも貼れるように、写しの写しを入れる }
    RefreshMissing(C, True);
    DoInsert(P, I, C);
    Changed(C);
  end;
end;

procedure TCBookmark.DoMenuAddBookmark(AItem: TCBookmarkItem);
var
  N, L: string;
  P, It: TCBookmarkItem;
  I: Integer;
begin
  if FSearching then Exit;
  N := '';
  L := '';
  if not EditDialog(rsDlgAdd, N, L, True) then Exit;
  It := NewLink(N, L);
  if It = nil then Exit;
  InsertPos(AItem, P, I);
  DoInsert(P, I, It);
  Changed(It);
end;

procedure TCBookmark.DoMenuAddFolder(AItem: TCBookmarkItem);
var
  N, L: string;
  P, It: TCBookmarkItem;
  I: Integer;
begin
  if FSearching then Exit;
  N := rsNewFolder;
  L := '';
  if not EditDialog(rsDlgAddFolder, N, L, False) then Exit;
  It := TCBookmarkItem.Create(bkFolder);
  It.FName := N;
  InsertPos(AItem, P, I);
  DoInsert(P, I, It);
  Changed(It);
end;

procedure TCBookmark.DoMenuAddSeparator(AItem: TCBookmarkItem);
var
  P, It: TCBookmarkItem;
  I: Integer;
begin
  if FSearching then Exit;
  It := TCBookmarkItem.Create(bkSeparator);
  InsertPos(AItem, P, I);
  DoInsert(P, I, It);
  Changed(It);
end;

procedure TCBookmark.DoDropItem(AItem, ATarget: TCBookmarkItem; APos: TCBookmarkDropPos);
var
  P: TCBookmarkItem;
  I: Integer;
begin
  if FSearching or not CanDropItem(AItem, ATarget, APos) then Exit;
  DropDest(ATarget, APos, P, I);
  if MoveInternal(AItem, P, I) then Changed(AItem);
end;

procedure TCBookmark.DoDropFiles(const AFiles: TStrings; ATarget: TCBookmarkItem; APos: TCBookmarkDropPos);
var
  I, Total, Idx: Integer;
  P, It, Last: TCBookmarkItem;
  F, T: string;
  OldCursor: TCursor;
begin
  if (AFiles = nil) or (AFiles.Count = 0) or FSearching then Exit;
  { フォルダーは登録する前に数え、500件を超えるときは確認する }
  Total := 0;
  for I := 0 to AFiles.Count - 1 do
  begin
    F := AFiles[I];
    if LowerCase(ExtractFileExt(F)) = '.lnk' then
    begin
      T := CBResolveLink(F);
      if (T <> '') and DirectoryExists(T) then F := T;
    end;
    if DirectoryExists(F) then Inc(Total, CountDirEntries(F, MaxInt div 2));
  end;
  if Total > CBFolderConfirm then
    if MessageDlg(Format(rsTooMany, [Total]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  DropDest(ATarget, APos, P, Idx);
  Last := nil;
  OldCursor := Screen.Cursor;
  Screen.Cursor := crHourGlass;
  try
    for I := 0 to AFiles.Count - 1 do
    begin
      It := ItemFromPath(AFiles[I], True);
      if It = nil then Continue;
      DoInsert(P, Idx, It);              { 落とされた順に並べる }
      Inc(Idx);
      Last := It;
    end;
  finally
    Screen.Cursor := OldCursor;
  end;
  if Last <> nil then Changed(Last);
end;

procedure TCBookmark.DoDropUrl(const AUrl, ATitle: string; ATarget: TCBookmarkItem; APos: TCBookmarkDropPos);
var
  P, It: TCBookmarkItem;
  I: Integer;
begin
  if FSearching then Exit;
  It := NewLink(ATitle, AUrl);           { 名前はタイトル。取れなければ URL }
  if It = nil then Exit;
  DropDest(ATarget, APos, P, I);
  DoInsert(P, I, It);
  Changed(It);
end;

procedure TCBookmark.AsyncExternalDrop(Data: PtrInt);
var
  L: TStringList;
begin
  if (FPendingTarget <> nil) and not IsInTree(FPendingTarget) then FPendingTarget := nil;
  if FPendingIsUrl then
    DoDropUrl(FPendingUrl, FPendingTitle, FPendingTarget, FPendingPos)
  else
  begin
    L := TStringList.Create;
    try
      L.Assign(FPendingFiles);
      DoDropFiles(L, FPendingTarget, FPendingPos);
    finally
      L.Free;
    end;
  end;
  FPendingFiles.Clear;
  FPendingIsUrl := False;
  FPendingTarget := nil;
end;

{ ================================================================== }
{ ドラッグ                                                       }
{ ================================================================== }

{ ツリーの座標 X・Y から、落とす位置を決める。空白なら ATarget=nil（一番下） }
function TCBookmark.CalcDrop(X, Y: Integer; out ATarget: TCBookmarkItem; out APos: TCBookmarkDropPos): Boolean;
var
  N: TTreeNode;
  R: TRect;
  H, D: Integer;
begin
  Result := not FSearching;
  ATarget := nil;
  APos := bdpInside;
  if not Result then Exit;
  N := FTree.GetNodeAt(X, Y);
  if N = nil then Exit;
  ATarget := ItemOfNode(N);
  R := N.DisplayRect(False);
  H := Max(1, R.Bottom - R.Top);
  D := Y - R.Top;
  if ATarget.FKind = bkFolder then
  begin
    if D < H div 4 then APos := bdpBefore
    else if D >= H - H div 4 then APos := bdpAfter
    else APos := bdpInside;
  end
  else if D < H div 2 then
    APos := bdpBefore
  else
    APos := bdpAfter;
end;

function TCBookmark.CanDropItem(ADrag, ATarget: TCBookmarkItem; APos: TCBookmarkDropPos): Boolean;
var
  P: TCBookmarkItem;
  I: Integer;
begin
  Result := False;
  if (ADrag = nil) or not IsInTree(ADrag) then Exit;
  if ATarget = ADrag then Exit;
  DropDest(ATarget, APos, P, I);
  { フォルダーを自分自身の配下（自分と子・孫）へは落とせない }
  if (P = ADrag) or P.IsDescendantOf(ADrag) then Exit;
  Result := True;
end;

procedure TCBookmark.BeginDragTimer;
begin
  FHoverItem := nil;
  FDragTimer.Enabled := True;
end;

procedure TCBookmark.EndDragTimer;
begin
  FDragTimer.Enabled := False;
  FHoverItem := nil;
end;

{ ドラッグ中：上下の端で自動スクロール、閉じたフォルダーの上で 1 秒止まったら開く }
procedure TCBookmark.DragTimer(Sender: TObject);
var
  P: TPoint;
  T: TCBookmarkItem;
  DP: TCBookmarkDropPos;
  Edge: Integer;
begin
  P := FTree.ScreenToClient(Mouse.CursorPos);
  Edge := MulDiv(16, Screen.PixelsPerInch, 96);
  if (P.X >= 0) and (P.X < FTree.ClientWidth) then
  begin
    if (P.Y >= 0) and (P.Y < Edge) then
      SendMessage(FTree.Handle, WM_VSCROLL, SB_LINEUP, 0)
    else if (P.Y < FTree.ClientHeight) and (P.Y >= FTree.ClientHeight - Edge) then
      SendMessage(FTree.Handle, WM_VSCROLL, SB_LINEDOWN, 0);
  end;
  { スクロールしたら位置の線を出し直す（ツリーの上のときだけ。外の動きはマウスが動いたときに行う） }
  if FDragActive and (P.X >= 0) and (P.Y >= 0) and (P.X < FTree.ClientWidth) and (P.Y < FTree.ClientHeight) then
    UpdateInternalDrag(P.X, P.Y);
  if CalcDrop(P.X, P.Y, T, DP) and (T <> nil) and (T.FKind = bkFolder) and (DP = bdpInside)
    and (T.FNode <> nil) and not T.FNode.Expanded then
  begin
    if FHoverItem <> T then
    begin
      FHoverItem := T;
      FHoverStart := GetTickCount64;
    end
    else if GetTickCount64 - FHoverStart >= 1000 then
    begin
      T.FNode.Expanded := True;          { 開閉の通知で状態も保存される }
      FHoverItem := nil;
    end;
  end
  else
    FHoverItem := nil;
end;

{ 左ボタンを押したまま動かしたとき：しきい値を超えたらドラッグを始め、ドラッグ中は位置の線・枠を出す }
procedure TCBookmark.TreeMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if FDragActive then
  begin
    DragMoveTo(X, Y);                  { ツリーの上・同じアプリの部品・アプリの外で動きが変わる }
    Exit;
  end;
  if not FDragArmed then Exit;
  if not (ssLeft in Shift) then
  begin
    FDragArmed := False;
    Exit;
  end;
  if (Abs(X - FDragStartPt.X) < GetSystemMetrics(SM_CXDRAG)) and
     (Abs(Y - FDragStartPt.Y) < GetSystemMetrics(SM_CYDRAG)) then Exit;
  { ドラッグを始める }
  FDragArmed := False;
  if (FDownItem = nil) or not IsInTree(FDownItem) then Exit;
  FDragActive := True;
  FDragStarted := True;
  FDragItem := FDownItem;              { 押した位置の項目をドラッグする }
  FDropOk := False;
  FTree.MouseCapture := True;          { ツリーの外で離しても MouseUp を受ける }
  FAppTarget := nil;
  FAppAccept := False;
  BeginDragTimer;
  DragMoveTo(X, Y);
end;

{ ドラッグ中にマウスが動いた（X・Y はツリーの座標。ツリーの外のこともある）。
  ・ツリーの上：部品の中の移動（UpdateInternalDrag）
  ・同じアプリの、ツリー以外の部品の上：その部品の DragOver（OnDragOver）に知らせる
  ・アプリの外：URL・ファイルなら OLE のドラッグに切り替える }
procedure TCBookmark.DragMoveTo(X, Y: Integer);
var
  P, SP, LP: TPoint;
  W: HWND;
  Pid: DWORD;
  C: TControl;
  St: TDragState;
begin
  if (X >= 0) and (Y >= 0) and (X < FTree.ClientWidth) and (Y < FTree.ClientHeight) then
  begin
    LeaveAppTarget;
    UpdateInternalDrag(X, Y);
    Exit;
  end;
  { ツリーの外：部品の中の移動はしない }
  FDropOk := False;
  FTree.HideIndicator;
  P.X := X;
  P.Y := Y;
  SP := FTree.ClientToScreen(P);
  W := WindowFromPoint(SP);
  Pid := 0;
  if W <> 0 then GetWindowThreadProcessId(W, @Pid);
  if (W <> 0) and (Pid = GetCurrentProcessId) then
  begin
    { 同じアプリの部品（TCBookmark とその中の部品は除く） }
    C := FindDragTarget(SP, False);
    if (C <> nil) and IsOwnPart(C) then C := nil;
    if C <> FAppTarget then
    begin
      LeaveAppTarget;
      FAppTarget := C;
      St := dsDragEnter;
    end
    else
      St := dsDragMove;
    FAppAccept := False;
    if C <> nil then
    begin
      LP := C.ScreenToClient(SP);
      TCBControlAccess(C).DragOver(Self, LP.X, LP.Y, St, FAppAccept);
    end;
    if FAppAccept then Screen.Cursor := crDrag else Screen.Cursor := crNoDrop;
  end
  else
  begin
    { アプリの外 }
    LeaveAppTarget;
    if CanOleDrag(FDragItem) then
      StartOleDrag
    else
      Screen.Cursor := crNoDrop;       { フォルダー・区切り線・無いファイルは外へ出さない }
  end;
end;

{ マウスの下だった同じアプリの部品に dsDragLeave を知らせて、外す }
procedure TCBookmark.LeaveAppTarget;
var
  C: TControl;
  LP: TPoint;
  Acc: Boolean;
begin
  C := FAppTarget;
  FAppTarget := nil;
  FAppAccept := False;
  if C = nil then Exit;
  LP := C.ScreenToClient(Mouse.CursorPos);
  Acc := False;
  TCBControlAccess(C).DragOver(Self, LP.X, LP.Y, dsDragLeave, Acc);
end;

{ AControl が TCBookmark 自身か、その中の部品か }
function TCBookmark.IsOwnPart(AControl: TControl): Boolean;
var
  P: TControl;
begin
  Result := False;
  P := AControl;
  while P <> nil do
  begin
    if P = Self then Exit(True);
    P := P.Parent;
  end;
end;

{ アプリの外へ出せる項目か（URL と、リンク先があるファイル） }
function TCBookmark.CanOleDrag(AItem: TCBookmarkItem): Boolean;
begin
  Result := (AItem <> nil) and IsInTree(AItem) and
    ((AItem.FKind = bkUrl) or ((AItem.FKind = bkFile) and FileExists(AItem.FLocation)));
end;

{ ファイルのシェルのデータ（エクスプローラーと同じ）を作る。作れなければ nil }
function CBGetShellDataObject(AWnd: HWND; const APath: string): IUnknown;
var
  Full, Last: PItemIDList;
  Parent: IShellFolder;
  W: UnicodeString;
  Obj: Pointer;
begin
  Result := nil;
  W := UTF8Decode(ExcludeTrailingPathDelimiter(APath));
  Full := CBILCreateFromPathW(PWideChar(W));
  if Full = nil then Exit;
  try
    Last := nil;
    if Failed(CBSHBindToParent(Full, IID_IShellFolder, Parent, Last)) or (Parent = nil) then Exit;
    Obj := nil;
    if Succeeded(Parent.GetUIObjectOf(AWnd, 1, Last, IID_CBDataObject, nil, Obj)) and (Obj <> nil) then
    begin
      Result := IUnknown(Obj);         { GetUIObjectOf が AddRef 済み。Result に入れた分で1つ多くなるので戻す }
      IUnknown(Obj)._Release;
    end;
  finally
    CoTaskMemFree(Full);
  end;
end;

{ アプリの外へ出た：部品の中のドラッグを終え、OLE のドラッグを始める（落とす・取りやめるまで待つ）。
  URL はブラウザと同じ形（「名前.url」と URL の文字。コピー・リンク）、ファイルはシェルのデータ（リンクだけ）。
  TCBookmark のデータは変えない }
procedure TCBookmark.StartOleDrag;
var
  It: TCBookmarkItem;
  UrlData: ICBDataObject;
  ShellData: IUnknown;
  Eff: DWORD;
begin
  It := FDragItem;
  { 部品の中のドラッグを終える（移動はしない） }
  FDragActive := False;
  FDragArmed := False;
  FDropOk := False;
  FTree.MouseCapture := False;
  FTree.HideIndicator;
  EndDragTimer;
  Screen.Cursor := crDefault;
  FOleDragging := True;
  try
    Eff := 0;
    if It.FKind = bkUrl then
    begin
      UrlData := TCBookmarkUrlData.Create(It.FName, It.FLocation);
      CBSHDoDragDrop(FTree.Handle, Pointer(UrlData), nil, CBDropEffectCopy or CBDropEffectLink, Eff);
    end
    else
    begin
      ShellData := CBGetShellDataObject(FTree.Handle, It.FLocation);
      if ShellData <> nil then
        CBSHDoDragDrop(FTree.Handle, Pointer(ShellData), nil, CBDropEffectLink, Eff);   { リンクだけ＝ショートカットを作る }
    end;
  finally
    FOleDragging := False;
    FDragItem := nil;
  end;
end;

{ ドラッグ中：X・Y（ツリーの座標）から落とす位置を決め、線・枠とカーソルを出す。
  落とせる位置を覚えておき、離したときはこの位置へ入れる（見えている位置と同じにするため） }
procedure TCBookmark.UpdateInternalDrag(X, Y: Integer);
var
  T: TCBookmarkItem;
  DP: TCBookmarkDropPos;
begin
  FDropOk := False;
  if (X >= 0) and (Y >= 0) and (X < FTree.ClientWidth) and (Y < FTree.ClientHeight) and
     CalcDrop(X, Y, T, DP) and CanDropItem(FDragItem, T, DP) then
  begin
    FDropOk := True;
    FDropTargetItem := T;
    FDropPos := DP;
    FTree.ShowIndicator(T, DP);
    Screen.Cursor := crDrag;
  end
  else
  begin
    FTree.HideIndicator;
    Screen.Cursor := crNoDrop;         { 落とせない（ツリーの外・自分の配下） }
  end;
end;

{ ドラッグを終える。ADrop=True なら移す、False（Esc）なら取りやめ }
procedure TCBookmark.EndInternalDrag(ADrop: Boolean);
var
  C: TControl;
  LP: TPoint;
begin
  FDragActive := False;
  FDragArmed := False;
  FTree.MouseCapture := False;
  Screen.Cursor := crDefault;
  if not ADrop then FDropOk := False;
  { 同じアプリの部品の上で離した：受けると答えていれば OnDragDrop を呼ぶ。
    呼んでいる間も DragItem で項目を取り出せる（FinishInternalDrop の前に呼ぶ） }
  if FAppTarget <> nil then
  begin
    if ADrop and FAppAccept then
    begin
      C := FAppTarget;
      FAppTarget := nil;
      FAppAccept := False;
      FDropOk := False;
      try
        LP := C.ScreenToClient(Mouse.CursorPos);
        TCBControlAccess(C).DragDrop(Self, LP.X, LP.Y);
      except
        on E: Exception do Application.HandleException(E);
      end;
    end
    else
      LeaveAppTarget;
  end;
  FinishInternalDrop;
end;

{ ドラッグの項目を、最後に線・枠を出した位置へ移す（離したときに1回だけ行う） }
procedure TCBookmark.FinishInternalDrop;
var
  D: TCBookmarkItem;
begin
  D := FDragItem;
  FDragItem := nil;
  FTree.HideIndicator;
  EndDragTimer;
  if (D = nil) or not FDropOk then Exit;
  FDropOk := False;
  if (FDropTargetItem <> nil) and not IsInTree(FDropTargetItem) then Exit;
  DoDropItem(D, FDropTargetItem, FDropPos);
end;

var
  GFmtName: UnicodeString;

initialization
  GLiveBookmarks := TFPList.Create;
  CBOleInitialize(nil);                   { D&D の受け取り（RegisterDragDrop）に必要。すでに済んでいれば何もしない }
  GFmtName := 'UniformResourceLocatorW';
  GCfUrlW := CBRegisterClipboardFormatW(PWideChar(GFmtName));
  GFmtName := 'FileGroupDescriptorW';
  GCfFileGroupW := CBRegisterClipboardFormatW(PWideChar(GFmtName));
  GFmtName := 'FileContents';
  GCfFileContents := CBRegisterClipboardFormatW(PWideChar(GFmtName));
  GFmtName := 'UniformResourceLocator';
  GCfUrlA := CBRegisterClipboardFormatW(PWideChar(GFmtName));

finalization
  FreeAndNil(GLiveBookmarks);

end.
