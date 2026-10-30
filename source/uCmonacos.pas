{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ TCMonacoEditor - フォームに貼るだけで使える、Monaco エディタの複合部品
  環境: Lazarus 4.8 / FPC 3.2.2 / Windows 11 x64 / WebView4Delphi / ATFlatControls

  中身: タブ（ATTabs）・Monaco エディタ（TCMMonacoView）・スプリッター・Markdown プレビュー
        （TCMMarkdownPreview）・検索・置換・印刷。中の部品は見せない。

  【使い方】コードは書かない。
  1. EXE の隣に WebView2.ini（必ず置く）を置く。WebView2 の準備は部品が自分で行う（.lpr には何も書かない）
  2. フォームに TCMonacoEditor を貼る。設定はすべてオブジェクトインスペクタで行う
  3. EXE の隣に WebView2Loader.dll、monaco\、preview\ を置く

  ・イベントは、未設定でも既定の動作をする（OnError=メッセージ表示、OnNeedFileName=保存ダイアログ、
    OnQueryClose=ConfirmOnFormClose に従う）。
  ・1つのフォームに何個でも貼れる。イベントの Sender は、必ずこの TCMonacoEditor。
  ・フォームを閉じるとき、未保存の文書を自動で確認する（フォームの OnCloseQuery に自動で連結する）。
  ・見えているタブは Ed.〜（Text・Save・FileName など）、裏のタブは Ed.Pages[n].〜 で触る。
    Pages[n] にあるものは、すべて Ed にも同じ名前である。タブは常に 1 枚以上ある。
  ・【2.15】Theme・ColorScheme はオブジェクトインスペクタで選択、色は TColor（色ダイアログ）で指定する。
    中の部品（TCMMonacoView・TCMMarkdownPreview）は今までどおり文字列で受けるので、
    この部品の中で 'auto'・'vs'・'vs-dark'、'editor'・'github'、'#RRGGBB' に変換して渡す。
  ・【2.20】TabTearOff = True なら、タブをウィンドウの外へ落とすと、同じ EXE をもう 1 つ起動してそのタブを開く
    （タブの分離。設計書 4.11）。受け渡しは一時ファイルと環境変数 CM_TEAROFF。
  ・【2.21】TabTearOff の既定は True。同じ EXE の別のウィンドウのエディタへ落とすと、そのエディタに新しいタブで開く
    （タブの結合。設計書 4.11.6）。受け渡しは一時ファイルと WM_COPYDATA。 }
unit uCmonacos;

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils, Controls, Forms, ExtCtrls, Graphics, Dialogs, Menus,
  LCLType, ActnList, Registry, ShellApi,
  ATTabs, ucmmonacoview, ucmdpreview, CMonacoTabs, CMonacoPreview, CMonacoFindDlg;

type
  { アプリ側が ucmonacos だけを uses すれば済むように、よく使う型を再公開する }
  TCMEncoding = ucmmonacoview.TCMEncoding;
  TCMFindOption = ucmmonacoview.TCMFindOption;
  TCMFindOptions = ucmmonacoview.TCMFindOptions;
  TCMSyncScroll = CMonacoPreview.TCMSyncScroll;
  TCMTabImageEvent = CMonacoTabs.TCMTabImageEvent;

const
  ceUTF8 = ucmmonacoview.ceUTF8;
  ceUTF8BOM = ucmmonacoview.ceUTF8BOM;
  ceUTF16LE = ucmmonacoview.ceUTF16LE;
  ceUTF16BE = ucmmonacoview.ceUTF16BE;
  ceCP932 = ucmmonacoview.ceCP932;
  foMatchCase = ucmmonacoview.foMatchCase;
  foWholeWord = ucmmonacoview.foWholeWord;
  foLoop = ucmmonacoview.foLoop;
  ssNone = CMonacoPreview.ssNone;
  ssEditorToPreview = CMonacoPreview.ssEditorToPreview;
  ssBoth = CMonacoPreview.ssBoth;

  { 【2.15】色の既定値。TColor は内部が 青・緑・赤 の順（$00BBGGRR）。
    property の default で使うため interface に置く }
  DefHitColorLight = TColor($0058EEFF);          { #FFEE58 }
  DefHitColorDark = TColor($0008667D);           { #7D6608 }
  DefCursorLineColorLight = TColor($00FFF2EA);   { #EAF2FF }
  DefCursorLineColorDark = TColor($003C312C);    { #2C313C }
  DefPreviewBackColorLight = TColor($00FEFFFF);  { #FFFFFE }
  DefPreviewBackColorDark = TColor($001E1E1E);   { #1E1E1E }
  DefPreviewTextColorLight = TColor($00000000);  { #000000 }
  DefPreviewTextColorDark = TColor($00D4D4D4);   { #D4D4D4 }
  DefPreviewLinkColorLight = TColor($00B16A00);  { #006AB1 }
  DefPreviewLinkColorDark = TColor($00FF9437);   { #3794FF }

type
  { 【2.15】テーマ。ctAuto=OS に合わせる / ctLight=ライトで固定 / ctDark=ダークで固定 }
  TCMTheme = (ctAuto, ctLight, ctDark);
  { 【2.15】プレビューの配色の組。csEditor=エディタと同じ配色 / csGitHub=GitHub 風 }
  TCMColorScheme = (csEditor, csGitHub);
  { 【2.13】選択範囲の色の組 }
  TCMSelectionColorStyle = (scStandard, scBlue, scAmber, scPurple, scCustom);
  { 【2.20】タブがウィンドウの外へ落とされた。Index はそのタブの番号、X・Y は落とした画面の位置。
    TearOff は、来たときは TabTearOff の値（何も入っていない無題が 1 枚だけなら False）。False にすると部品は分離も結合もしない }
  TCMTabDragOutEvent = procedure(Sender: TObject; Index, X, Y: Integer; var TearOff: Boolean) of object;

  TCMFormHook = class;
  TCMonacoEditor = class;

  { TCMPage : 1 つのページ（タブ）。Ed.Pages[n] で取り出す。見えているタブは Ed.〜 でも同じことができる。
    作るのはエディタ側。アプリ側で Create・Free しない。
    表示していないページに使っても、表示は切り替わらない。
    並べ替えても同じタブを指す。閉じたあとは、読む値は空、操作は何もしない（Close は False） }
  TCMPage = class
  private
    FOwner: TCMonacoEditor;
    FId: Integer;
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
    function GetLineCount: Integer;
  public
    constructor Create(AOwner: TCMonacoEditor; AId: Integer);
    procedure Clear;                                      { 内容を空にして無題にする（変更は聞かずに捨てる） }
    { 【段階3】Save・SaveAs・LoadFromFile は、できたら True。キャンセル・失敗・別のタブで開いているファイルなら False }
    function LoadFromFile(const AFileName: string): Boolean;   { 内容を捨てて読み込む（聞かない）。別のタブで開いていれば読み込まずエラー }
    function Save: Boolean;                                    { 上書き保存（無題なら、切り替えずに保存先を聞く） }
    function SaveAs(const AFileName: string = ''): Boolean;    { 名前を付けて保存（省略するとダイアログ） }
    function Close(Force: Boolean = False): Boolean;      { 閉じる（変更があれば聞く）。閉じなかったら False }
    property Caption: string read GetCaption;             { タブのタイトル（' *' は含まない。無題は '無題'） }
    property FileName: string read GetFileName;           { フルパス。無題は '' }
    property Modified: Boolean read GetModified;          { 保存していない変更があるか（タブの ' *'） }
    property Encoding: TCMEncoding read GetEncoding write SetEncoding;
    property Language: string read GetLanguage write SetLanguage;
    { 【段階3】本文。代入すると内容だけ置き換え、' *' が付く（ファイル名はそのまま。Undo の履歴は消える） }
    property Text: string read GetText write SetText;
    { 【段階6】行数。Text から数える。空の文書は 1、最後が改行なら後ろの空の行も数える。閉じたページは 0 }
    property LineCount: Integer read GetLineCount;
  end;

  { TCMonacoEditor }

  TCMonacoEditor = class(TCustomPanel)
  private
    FMonaco: TCMMonacoView;
    FPreview: TCMMarkdownPreview;
    FSplitter: TSplitter;
    FTabs: TATTabs;
    FTabBinder: TCMTabBinder;
    FPreviewBinder: TCMPreviewBinder;
    FHook: TCMFormHook;
    FPrivateFindDlg: TCMFindDialog;     { フォーム以外に置かれたときの予備 }
    FInnerOpenDlg: TOpenDialog;
    FInnerSaveDlg: TSaveDialog;
    FErrQueue: TStringList;
    FPages: TList;          { 【段階2】作った TCMPage（エディタを壊すときに解放） }
    FDesignMode: Boolean;
    FLastDir: string;
    FPendingShortcut: TComponent;
    FFocusPending: Boolean;       { 【2.11】SetFocus を予約済み }
    FMnuMinimap: TMenuItem;
    FMnuPreview: TMenuItem;
    FPrintTempPreview: Boolean;   { 【段階5】印刷のために、プレビューを一時的に表示した }
    FTabFlat: Boolean;
    FTabSeparator: Boolean;
    FOsDark: Boolean;
    FOsDarkKnown: Boolean;
    FSelectionColorStyle: TCMSelectionColorStyle;   { 【2.13】 }
    FLineDelimiters: string;      { 【2.13】LineWords の区切り文字 }
    FLineSkipEmpty: Boolean;      { 【2.13】空の単語を入れない }
    FLineQuoteChar: Char;         { 【2.13】引用符。#0 なら解釈しない }
    FLineWords: TStringList;      { 【2.13】LineWords の結果（読んだときに分ける） }
    FLineWordsSeq: Cardinal;      { 【2.13】分けたときの view.CursorLineSeq }
    FLineWordsKey: string;        { 【2.13】分けたときの設定 }
    FLineWordsValid: Boolean;

    { 【2.15】テーマ・配色の組・色（選んだ値をそのまま持つ。中の部品へは文字列に変換して渡す） }
    FTheme: TCMTheme;
    FColorScheme: TCMColorScheme;
    FHitColorLight, FHitColorDark: TColor;
    FCursorLineColorLight, FCursorLineColorDark: TColor;
    FSelectionColorLight, FSelectionColorDark: TColor;
    FPreviewBackColorLight, FPreviewBackColorDark: TColor;
    FPreviewTextColorLight, FPreviewTextColorDark: TColor;
    FPreviewLinkColorLight, FPreviewLinkColorDark: TColor;

    FMultiDocument: Boolean;
    FConfirmOnFormClose: Boolean;
    FShowPreview: Boolean;
    FPreviewWidth: Integer;
    FOpenDialog: TOpenDialog;
    FSaveDialog: TSaveDialog;
    FFindDialog: TCMFindDialog;

    FOnReady: TNotifyEvent;
    FOnChange: TNotifyEvent;
    FOnCursorChange: TCMCursorEvent;
    FOnModeChange: TCMModeEvent;
    FOnSave: TCMSaveEvent;
    FOnModifiedChange: TNotifyEvent;
    FOnActiveChange: TNotifyEvent;
    FOnDocListChange: TNotifyEvent;
    FOnDocumentChange: TCMDocIndexEvent;
    FOnQueryClose: TCMQueryCloseEvent;
    FOnNeedFileName: TCMNeedFileNameEvent;
    FOnFileDrop: TCMFileDropEvent;
    FOnOpenMarkdown: TCMOpenMarkdownEvent;
    FOnToggleMaximize: TNotifyEvent;
    FOnFontSizeChange: TNotifyEvent;
    FOnLineNumbersChange: TNotifyEvent;
    FOnFindDone: TCMFindDoneEvent;
    FOnReplaceAllDone: TCMReplaceAllDoneEvent;
    FOnPopup: TNotifyEvent;
    FTabIcons: Boolean;
    FTabImages: TImageList;
    FSysImages: TImageList;          { Windows のアイコン（拡張子ごとに 1 回だけ取り出して使い回す） }
    FSysIconExts: TStringList;       { 拡張子 → FSysImages の番号 }
    FOnGetTabImageIndex: TCMTabImageEvent;
    FOnError: TCMErrorEvent;
    { 【2.20】タブの分離 }
    FTabTearOff: Boolean;
    FOnTabDragOut: TCMTabDragOutEvent;
    FTearOffPending: Boolean;      { 分離で起動され、このエディタが受け取った（準備ができたらタブを作る） }
    FTearOffHead: TStringList;     { 受け取った一時ファイルの見出し（名前=値） }
    FTearOffBody: string;          { 受け取った一時ファイルの本文 }
    FMergeQueue: TStringList;      { 【2.21】結合で受け取った一時ファイル（AsyncMerge でタブを作る） }

    { 中の部品からの通知（Sender を Self に差し替えて、利用者のイベントへ渡す） }
    procedure MonacoReady(Sender: TObject);
    procedure MonacoChange(Sender: TObject);
    procedure MonacoCursorChange(Sender: TObject; Line, Column: Integer);
    procedure MonacoModeChange(Sender: TObject; IsOverwrite: Boolean);
    procedure MonacoSave(Sender: TObject; const AFileName: string);
    procedure MonacoModifiedChange(Sender: TObject);
    procedure MonacoActiveChange(Sender: TObject);
    procedure MonacoDocListChange(Sender: TObject);
    procedure MonacoDocumentChange(Sender: TObject; Index: Integer);
    procedure MonacoQueryClose(Sender: TObject; Index: Integer; var CanClose: Boolean);
    procedure MonacoNeedFileName(Sender: TObject; var AFileName: string; var Cancel: Boolean);
    procedure MonacoFileDrop(Sender: TObject; Files: TStrings; var Handled: Boolean);
    procedure MonacoToggleMaximize(Sender: TObject);
    procedure MonacoFontSizeChange(Sender: TObject);
    procedure MonacoLineNumbersChange(Sender: TObject);
    procedure MonacoFindRequest(Sender: TObject; const InitialText: string);
    procedure MonacoFindDone(Sender: TObject; Found: Boolean);
    procedure MonacoReplaceAllDone(Sender: TObject; Count: Integer);
    procedure MonacoPopup(Sender: TObject);
    procedure MonacoError(Sender: TObject; const AMessage: string);
    procedure MonacoGotFocus(Sender: TObject);
    procedure MonacoTogglePreview(Sender: TObject);
    procedure MonacoAccelKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MonacoOsThemeChange(Sender: TObject; IsDark: Boolean);
    procedure SetTabFlat(AValue: Boolean);
    procedure SetTabSeparator(AValue: Boolean);
    procedure ApplyTabShape;
    procedure ApplyTabIcons;
    function SystemIconIndex(const AFileName: string): Integer;
    procedure BinderGetImageIndex(Sender: TObject; Index: Integer; const AFileName: string;
      var ImageIndex: Integer);
    { 【2.20】タブの分離（設計書 4.11.2・4.11.3） }
    procedure BinderTabDragOut(Sender: TObject; Index, X, Y: Integer);
    function TearOffName: string;
    function SendTearOff(AIndex, X, Y: Integer): Boolean;
    function TryClaimTearOff: Boolean;
    procedure MoveFormToTearOff;
    procedure ApplyTearOff;
    { 【2.21】タブの結合（設計書 4.11.6） }
    function MakeTearOffFile(AIndex, X, Y: Integer; out AFile: string): Boolean;
    function TryMerge(AIndex, X, Y: Integer): Boolean;
    procedure AsyncMerge(Data: PtrInt);
    procedure AsyncBringFront(Data: PtrInt);
    procedure SetTabIcons(AValue: Boolean);
    procedure SetTabImages(AValue: TImageList);
    procedure PreviewError(Sender: TObject; const AMessage: string);
    procedure PreviewOpenMarkdown(Sender: TObject; const AFileName: string);
    procedure SplitterMoved(Sender: TObject);
    procedure AddViewMenuItems;
    procedure MenuMinimapClick(Sender: TObject);
    procedure MenuPreviewClick(Sender: TObject);
    procedure PreviewAfterPrint(Sender: TObject);

    procedure DoError(const AMessage: string);
    procedure AsyncShowError(Data: PtrInt);
    procedure DoQueryClose(AIndex: Integer; var CanClose: Boolean);
    function AskSaveFileName(AIndex: Integer; var AFileName: string): Boolean;
    function OpenWithDialog: Integer;   { 【2.16】開くダイアログで選んだファイルを開く（OpenFile の名前を省略したとき） }
    function DefaultExtFor(const ALanguage: string): string;
    function QueryCurrent: Boolean;   { 【2.9】MultiDocument = False：0 番の文書に変更があれば聞く。続けてよければ True }
    procedure UpdatePreview;
    procedure ApplyThemeColors;
    function IsDarkTheme: Boolean;
    function IsBuiltinKey(Key: Word; Shift: TShiftState): Boolean;
    function FindFormShortcut(Key: Word; Shift: TShiftState): TComponent;
    procedure AsyncRunShortcut(Data: PtrInt);
    procedure AsyncSetFocus(Data: PtrInt);   { 【2.11】SetFocus の本体（今の処理が終わってから行う） }
    procedure AsyncPrint(Data: PtrInt);   { 【2.8】Ctrl+P。キーの通知の途中ではなく、そのあとで印刷する }
    procedure PreviewPrintKey(Sender: TObject);   { 【2.8】プレビューで Ctrl+P }
    function CurrentFindDialog(ACreate: Boolean): TCMFindDialog;
    procedure RegisterWithForm;

    { プロパティ（中の部品へ中継） }
    procedure SetMultiDocument(AValue: Boolean);
    procedure SetShowPreview(AValue: Boolean);
    procedure SetPreviewWidth(AValue: Integer);
    procedure SetOpenDialog(AValue: TOpenDialog);
    procedure SetSaveDialog(AValue: TSaveDialog);
    procedure SetFindDialog(AValue: TCMFindDialog);
    function GetSplitterResizeStyle: TResizeStyle;
    procedure SetSplitterResizeStyle(AValue: TResizeStyle);
    function GetSplitterWidth: Integer;
    procedure SetSplitterWidth(AValue: Integer);

    function GetWordWrap: Boolean;
    procedure SetWordWrap(AValue: Boolean);
    function GetLineNumbers: Boolean;
    procedure SetLineNumbers(AValue: Boolean);
    function GetFontSize: Integer;
    procedure SetFontSize(AValue: Integer);
    function GetTabSize: Integer;
    procedure SetTabSize(AValue: Integer);
    function GetTheme: TCMTheme;                         { 【2.15】 }
    procedure SetTheme(AValue: TCMTheme);
    function GetReadOnly: Boolean;
    procedure SetReadOnly(AValue: Boolean);
    function GetJapaneseUI: Boolean;
    procedure SetJapaneseUI(AValue: Boolean);
    function GetDefaultLanguage: string;
    procedure SetDefaultLanguage(const AValue: string);
    function GetAutoLanguage: Boolean;
    procedure SetAutoLanguage(AValue: Boolean);
    function GetOpenDroppedFiles: Boolean;
    procedure SetOpenDroppedFiles(AValue: Boolean);
    function GetQuotePrefix: string;
    procedure SetQuotePrefix(const AValue: string);
    procedure SetHitColorLight(AValue: TColor);          { 【2.15】色は TColor }
    procedure SetHitColorDark(AValue: TColor);
    procedure SetCursorLineColorLight(AValue: TColor);
    procedure SetCursorLineColorDark(AValue: TColor);
    procedure SetSelectionColorStyle(AValue: TCMSelectionColorStyle);   { 【2.13】 }
    procedure SetSelectionColorLight(AValue: TColor);
    procedure SetSelectionColorDark(AValue: TColor);
    function IsSelColorStored: Boolean;
    function GetLineText: string;                                       { 【2.13】 }
    function GetLineWords: TStrings;
    function GetMonacoPath: string;
    procedure SetMonacoPath(const AValue: string);
    function GetFolding: Boolean;
    procedure SetFolding(AValue: Boolean);
    function GetMatchBrackets: Boolean;
    procedure SetMatchBrackets(AValue: Boolean);
    function GetOccurrencesHighlight: Boolean;
    procedure SetOccurrencesHighlight(AValue: Boolean);
    function GetMinimap: Boolean;
    procedure SetMinimap(AValue: Boolean);

    function GetPreviewFontSize: Integer;
    procedure SetPreviewFontSize(AValue: Integer);
    procedure SetColorScheme(AValue: TCMColorScheme);   { 【2.15】 }
    procedure SetPreviewBackColorLight(AValue: TColor);  { 【2.15】色は TColor }
    procedure SetPreviewBackColorDark(AValue: TColor);
    procedure SetPreviewTextColorLight(AValue: TColor);
    procedure SetPreviewTextColorDark(AValue: TColor);
    procedure SetPreviewLinkColorLight(AValue: TColor);
    procedure SetPreviewLinkColorDark(AValue: TColor);
    function GetBreakOnNewline: Boolean;
    procedure SetBreakOnNewline(AValue: Boolean);
    function GetAllowRemoteImages: Boolean;
    procedure SetAllowRemoteImages(AValue: Boolean);
    function GetSyncScroll: TCMSyncScroll;
    procedure SetSyncScroll(AValue: TCMSyncScroll);
    function GetPreviewDelayMs: Integer;
    procedure SetPreviewDelayMs(AValue: Integer);
    function GetPreviewPath: string;
    procedure SetPreviewPath(const AValue: string);

    { 実行時のみ }
    function GetDocumentCount: Integer;
    function GetActiveIndex: Integer;
    procedure SetActiveIndex(AValue: Integer);
    function GetSearchText: string;
    procedure SetSearchText(const AValue: string);
    function GetReplaceText: string;
    procedure SetReplaceText(const AValue: string);
    function GetSearchOptions: TCMFindOptions;
    procedure SetSearchOptions(AValue: TCMFindOptions);
    function GetTopLine: Double;
    function GetReady: Boolean;
    function GetPage(AIndex: Integer): TCMPage;
    function CurPage: TCMPage;        { 【2.9】見えているタブのページ（タブは常に 1 枚以上あるので nil にならない） }
    { 【2.9】見えているタブの情報（中身は CurPage の同じ名前） }
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
    function GetSelText: string;
    procedure SetSelText(const AValue: string);
    function GetSelStart: Integer;
    function GetSelLength: Integer;
    function GetCanUndo: Boolean;
    function GetCanRedo: Boolean;   { 【2.17】 }
    { 【段階2】ページの操作の本体（TCMPage から呼ぶ。番号は存在するものだけ渡す） }
    function AskPageFileName(AIndex: Integer; var AFileName: string): Boolean;
    function PageSave(AIndex: Integer): Boolean;
    function PageSaveAs(AIndex: Integer; const AFileName: string): Boolean;
    function PageLoad(AIndex: Integer; const AFileName: string): Boolean;
    procedure PageClear(AIndex: Integer);
    function PageClose(AIndex: Integer; Force: Boolean): Boolean;
  protected
    procedure CreateWnd; override;
    procedure Loaded; override;
    procedure Paint; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    { ショートカット用のキー。override して inherited を呼ぶと OnKeyDown が呼ばれる（TWinControl と同じ） }
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetFocus; override;

    { ---- 文書 ---- }
    { 新しいタブで開く。MultiDocument=False なら中身を入れ替える（変更があれば聞く）。
      【2.16】名前を省略すると開くダイアログを出す（OpenDialog、未設定なら内蔵のもの）。キャンセルなら -1 }
    function OpenFile(const AFileName: string = ''): Integer;
    procedure SaveAll;
    function CloseAll(Force: Boolean = False): Boolean;
    { ---- 見えているタブの中身とファイル（【2.9】Pages[n] の同じ名前と同じ動き。対象は見えているタブ） ---- }
    function LoadFromFile(const AFileName: string): Boolean;   { 内容を捨てて読み込む（聞かない） }
    function Save: Boolean;                                    { 上書き保存（無題なら名前を聞く） }
    function SaveAs(const AFileName: string = ''): Boolean;    { 名前を付けて保存（省略するとダイアログ） }
    procedure Clear;                                           { 空にして無題にする（聞かない） }
    function Close(Force: Boolean = False): Boolean;           { 閉じる（変更があれば聞く）。最後の 1 枚は空の無題が残る }
    { ---- タブの集まり ---- }
    function NewPage: Integer;                                     { 新規（空の無題のタブ）。MultiDocument=False なら中身を空にする（変更があれば聞く） }
    function FindPage(const AFileName: string): Integer;           { そのファイルを開いているページの番号。なければ -1 }
    procedure MovePage(AFromIndex, AToIndex: Integer);             { ページの並べ替え }
    { フォームを閉じるときの確認。未保存の文書を確認するが、閉じはしない。キャンセルされたら False }
    function CanCloseAll: Boolean;

    { ---- カーソル・選択・編集 ---- }
    procedure SetCursorPos(ALine, AColumn: Integer);
    procedure GetCursorPos(out ALine, AColumn: Integer);
    procedure SetSelection(AStartLine, AStartCol, AEndLine, AEndCol: Integer);
    procedure DeleteToEnd;      { 【段階6】カーソル位置から末尾までを削除（選択は無視）。Undo 1回分 }
    procedure DeleteToStart;    { 【段階6】カーソル位置から先頭までを削除（選択は無視）。Undo 1回分 }
    procedure DuplicateLine;    { 【2.16】カーソル行（選択した行）を複製して下へ（Shift+F10 と同じ）。Undo 1回分 }
    procedure Undo;
    procedure Redo;
    procedure Cut;
    procedure Copy;
    procedure Paste;
    procedure SelectAll;
    procedure ToggleOverwrite;

    { ---- 検索・置換・印刷 ---- }
    procedure Find(const S: string; AOptions: TCMFindOptions; AForward: Boolean = True);
    procedure FindNext;
    procedure FindPrev;
    procedure Replace(const S, R: string; AOptions: TCMFindOptions);
    procedure ReplaceAll(const S, R: string; AOptions: TCMFindOptions);
    procedure ShowFindDialog(const InitialText: string = '');
    function CanPrint: Boolean;
    procedure Print;

    { ---- 実行時のみのプロパティ ---- }
    property PageCount: Integer read GetDocumentCount;      { タブ（ページ）の数 }
    property Pages[AIndex: Integer]: TCMPage read GetPage;  { 【段階2】i 番目のページ（0 から）。範囲外は例外 }
    { 【段階6】選択（表示中のページだけ。Pages[i] には置かない） }
    property SelText: string read GetSelText write SetSelText;   { 選択中の文字列。代入で置き換え（未選択なら挿入、'' なら削除） }
    property SelStart: Integer read GetSelStart;                 { 選択の開始位置（未選択ならカーソル位置）。0 始まり、UTF-16 }
    property SelLength: Integer read GetSelLength;               { 選択の長さ。0 なら未選択 }
    property CanUndo: Boolean read GetCanUndo;                   { Undo できるか }
    property CanRedo: Boolean read GetCanRedo;                   { 【2.17】Redo（やり直し）できるか。CanUndo と同じく、操作の直後は一瞬古いことがある }
    { 【2.9】見えているタブの情報（Pages[n] の同じ名前と同じ）。Text・Caption は TControl のものを隠す }
    property Text: string read GetEdText write SetEdText;            { 本文 }
    property Caption: string read GetEdCaption;                      { タブのタイトル（' *' は含まない。無題は '無題'） }
    property FileName: string read GetEdFileName;                    { フルパス。無題は '' }
    property Modified: Boolean read GetEdModified;                   { 保存していない変更があるか（タブの ' *'） }
    property Encoding: TCMEncoding read GetEdEncoding write SetEdEncoding;
    property Language: string read GetEdLanguage write SetEdLanguage;
    property LineCount: Integer read GetEdLineCount;                 { 行数 }
    { 【2.13】カーソル行 }
    property LineText: string read GetLineText;                      { カーソル行の文字列（改行なし） }
    property LineWords: TStrings read GetLineWords;                  { カーソル行の単語（0 から）。読んだときに分ける。Free しない }
    property LineDelimiters: string read FLineDelimiters write FLineDelimiters;   { 区切り文字（1 文字ずつ）。既定 半角空白・全角空白・タブ・カンマ・読点 }
    property LineSkipEmpty: Boolean read FLineSkipEmpty write FLineSkipEmpty;     { 既定 True：空の単語を入れない }
    property LineQuoteChar: Char read FLineQuoteChar write FLineQuoteChar;        { 既定 '"'。#0 なら引用符を解釈しない }
    property ActiveIndex: Integer read GetActiveIndex write SetActiveIndex;
    property SearchText: string read GetSearchText write SetSearchText;
    property ReplaceText: string read GetReplaceText write SetReplaceText;
    property SearchOptions: TCMFindOptions read GetSearchOptions write SetSearchOptions;
    property TopLine: Double read GetTopLine;
    property Ready: Boolean read GetReady;
    { 中の部品（上級者向け。オブジェクトインスペクタには出さない） }
    property Monaco: TCMMonacoView read FMonaco;
    property Preview: TCMMarkdownPreview read FPreview;
  published
    { 全体 }
    property MultiDocument: Boolean read FMultiDocument write SetMultiDocument default True;
    property ConfirmOnFormClose: Boolean read FConfirmOnFormClose write FConfirmOnFormClose default True;
    { 【2.20】True：タブをウィンドウの外へ落とすと、同じ EXE をもう 1 つ起動して、そのタブを開く。
      【2.21】既定は True。同じ EXE の別のウィンドウのエディタへ落とすと、そこに新しいタブで開く（結合）。
      False なら、分離も結合もしない（ほかのウィンドウから落とされたタブも受けない） }
    property TabTearOff: Boolean read FTabTearOff write FTabTearOff default True;
    property OpenDialog: TOpenDialog read FOpenDialog write SetOpenDialog;
    property SaveDialog: TSaveDialog read FSaveDialog write SetSaveDialog;
    property FindDialog: TCMFindDialog read FFindDialog write SetFindDialog;

    { タブ }
    property TabFlat: Boolean read FTabFlat write SetTabFlat default True;               { True=四角 / False=台形 }
    property TabSeparator: Boolean read FTabSeparator write SetTabSeparator default False;   { 選択していないタブの間の区切り線（TabFlat=True のときだけ） }
    property TabIcons: Boolean read FTabIcons write SetTabIcons default True;        { タブにアイコンを出す }
    property TabImages: TImageList read FTabImages write SetTabImages;               { 未設定なら Windows のアイコンを自動で出す }

    { エディタ }
    property WordWrap: Boolean read GetWordWrap write SetWordWrap default True;
    property LineNumbers: Boolean read GetLineNumbers write SetLineNumbers default False;
    property FontSize: Integer read GetFontSize write SetFontSize default 14;
    property TabSize: Integer read GetTabSize write SetTabSize default 4;
    property Folding: Boolean read GetFolding write SetFolding default True;
    property MatchBrackets: Boolean read GetMatchBrackets write SetMatchBrackets default True;
    property OccurrencesHighlight: Boolean read GetOccurrencesHighlight write SetOccurrencesHighlight default True;
    property Minimap: Boolean read GetMinimap write SetMinimap default False;
    property Theme: TCMTheme read GetTheme write SetTheme default ctAuto;     { 【2.15】ctAuto=OS に合わせる / ctLight / ctDark }
    property ReadOnly: Boolean read GetReadOnly write SetReadOnly default False;
    property JapaneseUI: Boolean read GetJapaneseUI write SetJapaneseUI default True;
    property DefaultLanguage: string read GetDefaultLanguage write SetDefaultLanguage;
    property AutoLanguage: Boolean read GetAutoLanguage write SetAutoLanguage default True;
    property OpenDroppedFiles: Boolean read GetOpenDroppedFiles write SetOpenDroppedFiles default True;
    property QuotePrefix: string read GetQuotePrefix write SetQuotePrefix;
    { 【2.15】色は TColor（色の一覧・色ダイアログで選ぶ） }
    property HitColorLight: TColor read FHitColorLight write SetHitColorLight default DefHitColorLight;
    property HitColorDark: TColor read FHitColorDark write SetHitColorDark default DefHitColorDark;
    property CursorLineColorLight: TColor read FCursorLineColorLight write SetCursorLineColorLight default DefCursorLineColorLight;
    property CursorLineColorDark: TColor read FCursorLineColorDark write SetCursorLineColorDark default DefCursorLineColorDark;
    property SelectionColorStyle: TCMSelectionColorStyle read FSelectionColorStyle write SetSelectionColorStyle default scStandard;   { 【2.13】 }
    property SelectionColorLight: TColor read FSelectionColorLight write SetSelectionColorLight stored IsSelColorStored;
    property SelectionColorDark: TColor read FSelectionColorDark write SetSelectionColorDark stored IsSelColorStored;
    property MonacoPath: string read GetMonacoPath write SetMonacoPath;

    { プレビュー }
    property ShowPreview: Boolean read FShowPreview write SetShowPreview default False;
    property PreviewWidth: Integer read FPreviewWidth write SetPreviewWidth default 500;
    property SplitterResizeStyle: TResizeStyle read GetSplitterResizeStyle write SetSplitterResizeStyle default rsLine;
    property SplitterWidth: Integer read GetSplitterWidth write SetSplitterWidth default 5;
    property PreviewFontSize: Integer read GetPreviewFontSize write SetPreviewFontSize default 16;
    property ColorScheme: TCMColorScheme read FColorScheme write SetColorScheme default csEditor;   { 【2.15】 }
    property PreviewBackColorLight: TColor read FPreviewBackColorLight write SetPreviewBackColorLight default DefPreviewBackColorLight;
    property PreviewBackColorDark: TColor read FPreviewBackColorDark write SetPreviewBackColorDark default DefPreviewBackColorDark;
    property PreviewTextColorLight: TColor read FPreviewTextColorLight write SetPreviewTextColorLight default DefPreviewTextColorLight;
    property PreviewTextColorDark: TColor read FPreviewTextColorDark write SetPreviewTextColorDark default DefPreviewTextColorDark;
    property PreviewLinkColorLight: TColor read FPreviewLinkColorLight write SetPreviewLinkColorLight default DefPreviewLinkColorLight;
    property PreviewLinkColorDark: TColor read FPreviewLinkColorDark write SetPreviewLinkColorDark default DefPreviewLinkColorDark;
    property BreakOnNewline: Boolean read GetBreakOnNewline write SetBreakOnNewline default False;
    property AllowRemoteImages: Boolean read GetAllowRemoteImages write SetAllowRemoteImages default False;
    property SyncScroll: TCMSyncScroll read GetSyncScroll write SetSyncScroll default ssBoth;
    property PreviewDelayMs: Integer read GetPreviewDelayMs write SetPreviewDelayMs default 300;
    property PreviewPath: string read GetPreviewPath write SetPreviewPath;

    { 配置 }
    property Align;
    property Anchors;
    property BorderSpacing;
    property Constraints;
    property Enabled;
    property Visible;
    property TabOrder;
    property TabStop;

    { イベント（Sender は必ずこの TCMonacoEditor） }
    property OnReady: TNotifyEvent read FOnReady write FOnReady;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnCursorChange: TCMCursorEvent read FOnCursorChange write FOnCursorChange;
    property OnModeChange: TCMModeEvent read FOnModeChange write FOnModeChange;
    property OnSave: TCMSaveEvent read FOnSave write FOnSave;
    property OnModifiedChange: TNotifyEvent read FOnModifiedChange write FOnModifiedChange;
    property OnActiveChange: TNotifyEvent read FOnActiveChange write FOnActiveChange;
    property OnDocListChange: TNotifyEvent read FOnDocListChange write FOnDocListChange;
    property OnDocumentChange: TCMDocIndexEvent read FOnDocumentChange write FOnDocumentChange;
    property OnQueryClose: TCMQueryCloseEvent read FOnQueryClose write FOnQueryClose;
    property OnNeedFileName: TCMNeedFileNameEvent read FOnNeedFileName write FOnNeedFileName;
    property OnFileDrop: TCMFileDropEvent read FOnFileDrop write FOnFileDrop;
    property OnOpenMarkdown: TCMOpenMarkdownEvent read FOnOpenMarkdown write FOnOpenMarkdown;
    property OnToggleMaximize: TNotifyEvent read FOnToggleMaximize write FOnToggleMaximize;
    property OnFontSizeChange: TNotifyEvent read FOnFontSizeChange write FOnFontSizeChange;
    property OnLineNumbersChange: TNotifyEvent read FOnLineNumbersChange write FOnLineNumbersChange;
    property OnFindDone: TCMFindDoneEvent read FOnFindDone write FOnFindDone;
    property OnReplaceAllDone: TCMReplaceAllDoneEvent read FOnReplaceAllDone write FOnReplaceAllDone;
    property OnPopup: TNotifyEvent read FOnPopup write FOnPopup;
    property OnGetTabImageIndex: TCMTabImageEvent read FOnGetTabImageIndex write FOnGetTabImageIndex;   { TabImages を設定したときだけ }
    property OnTabDragOut: TCMTabDragOutEvent read FOnTabDragOut write FOnTabDragOut;   { 【2.20】タブがウィンドウの外へ落とされた }
    property OnError: TCMErrorEvent read FOnError write FOnError;
    property OnKeyDown;
  end;

  { TCMFormHook : フォームごとに1つ。エディタの一覧、最後にフォーカスされたエディタ、
    共有の検索・置換ダイアログを持ち、フォームの OnCloseQuery に連結する（内部用） }

  TCMFormHook = class(TComponent)
  private
    FForm: TForm;
    FEditors: TFPList;
    FActive: TCMonacoEditor;
    FFindDialog: TCMFindDialog;
    FOldCloseQuery: TCloseQueryEvent;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor CreateFor(AForm: TForm);
    destructor Destroy; override;
    procedure AddEditor(AEditor: TCMonacoEditor);
    procedure RemoveEditor(AEditor: TCMonacoEditor);
    procedure SetActive(AEditor: TCMonacoEditor);
    function ActiveEditor: TCMonacoEditor;
    function SharedFindDialog: TCMFindDialog;
  end;

{ フォームで最後にフォーカスされたエディタ。まだどれもフォーカスされていなければ、最初のエディタ。無ければ nil }
function CMActiveEditor(AForm: TCustomForm): TCMonacoEditor;

{ 【2.13】1 行を単語に分ける。Dest は Clear してから入れる。
  Delims：区切り文字（UTF-8 の 1 文字ずつ）。SkipEmpty：空の単語を入れない。
  Quote：引用符（半角 1 文字）。#0・半角以外・区切り文字に含まれる場合は、引用符を解釈しない }
procedure CMSplitLine(const S, Delims: string; SkipEmpty: Boolean; Quote: Char; Dest: TStrings);

{ 【2.15】TColor を '#RRGGBB'（中の部品・JavaScript が受ける形）にする。
  clDefault・clNone なら ADefault を使う。システム色（clWindow など）は、今の実際の色にする。
  TColor は内部が 青・緑・赤 の順なので、赤・緑・青 の順に並べ替える }
function CMColorToHex(AColor, ADefault: TColor): string;

implementation

uses LazUTF8, StrUtils;

const
  { 【2.13】選択範囲の色の組（暗い配色・明るい配色）。【2.15】TColor（$00BBGGRR）にした。scCustom は使わない }
  SelStyleDark: array[TCMSelectionColorStyle] of TColor =
    (TColor($00784F26), TColor($009E5A0E), TColor($00004E6B), TColor($00822D5A), clNone);
    { #264F78, #0E5A9E, #6B4E00, #5A2D82 }
  SelStyleLight: array[TCMSelectionColorStyle] of TColor =
    (TColor($00FFD6AD), TColor($00FFB67F), TColor($004FD5FF), TColor($00FFA3C5), clNone);
    { #ADD6FF, #7FB6FF, #FFD54F, #C5A3FF }
  { 【2.15】Theme を中の部品の文字列にする }
  ThemeNames: array[TCMTheme] of string = ('auto', 'vs', 'vs-dark');

function CMColorToHex(AColor, ADefault: TColor): string;
var
  C: TColor;
begin
  if (AColor = clDefault) or (AColor = clNone) then AColor := ADefault;
  C := ColorToRGB(AColor);                    { システム色を実際の色にする }
  Result := Format('#%.2X%.2X%.2X', [Red(C), Green(C), Blue(C)]);
end;

procedure CMSplitLine(const S, Delims: string; SkipEmpty: Boolean; Quote: Char; Dest: TStrings);
var
  DL: array of string;          { 区切り文字（1 文字ずつ） }
  First: set of Char;           { 区切り文字の先頭のバイト }
  N, I, J, K, L, Start: Integer;
  UseQuote: Boolean;
  W: string;

  function DelimLen(P: Integer): Integer;   { P から区切り文字が始まっていれば、そのバイト数。なければ 0 }
  var
    Q: Integer;
  begin
    Result := 0;
    if not (S[P] in First) then Exit;
    for Q := 0 to High(DL) do
      if (P + Length(DL[Q]) - 1 <= N) and (CompareByte(S[P], DL[Q][1], Length(DL[Q])) = 0) then
        Exit(Length(DL[Q]));
  end;

  procedure AddWord(const AWord: string);
  begin
    if SkipEmpty and (AWord = '') then Exit;
    Dest.Add(AWord);
  end;

begin
  Dest.BeginUpdate;
  try
    Dest.Clear;
    N := Length(S);
    if N = 0 then Exit;                       { 空の行は 0 個 }

    { 区切り文字を 1 文字ずつに分ける }
    SetLength(DL, 0);
    First := [];
    I := 1;
    while I <= Length(Delims) do
    begin
      L := UTF8CodepointSize(@Delims[I]);
      if L < 1 then L := 1;
      if I + L - 1 > Length(Delims) then L := Length(Delims) - I + 1;
      SetLength(DL, Length(DL) + 1);
      DL[High(DL)] := Copy(Delims, I, L);
      Include(First, Delims[I]);
      Inc(I, L);
    end;
    UseQuote := (Quote <> #0) and (Ord(Quote) < 128) and (Pos(Quote, Delims) = 0);

    I := 1;
    while True do
    begin
      { 1 つの単語を読む }
      if UseQuote and (I <= N) and (S[I] = Quote) then
      begin
        W := '';
        Inc(I);
        while True do
        begin
          J := I;
          while (J <= N) and (S[J] <> Quote) do Inc(J);
          if J > N then                       { 閉じる引用符がない：行の最後まで }
          begin
            W := W + Copy(S, I, N - I + 1);
            I := N + 1;
            Break;
          end;
          W := W + Copy(S, I, J - I);
          if (J < N) and (S[J + 1] = Quote) then   { 引用符が 2 つ続く：引用符 1 つ }
          begin
            W := W + Quote;
            I := J + 2;
          end
          else
          begin
            I := J + 1;                       { 閉じる引用符 }
            Break;
          end;
        end;
        { 閉じる引用符のあとから次の区切りまでは、同じ単語に付ける }
        Start := I;
        while (I <= N) and (DelimLen(I) = 0) do Inc(I);
        if I > Start then W := W + Copy(S, Start, I - Start);
      end
      else
      begin
        Start := I;
        while (I <= N) and (DelimLen(I) = 0) do Inc(I);
        W := Copy(S, Start, I - Start);
      end;
      AddWord(W);

      if I > N then Break;                    { 行の最後 }
      K := DelimLen(I);
      Inc(I, K);                              { 区切りを飛ばす }
      if I > N then                           { 行の最後が区切り }
      begin
        AddWord('');
        Break;
      end;
    end;
  finally
    Dest.EndUpdate;
  end;
end;

var
  GShownErrors: TStringList = nil;    { 既定のエラー表示で、表示済みのメッセージ（同じものは1回だけ） }
  { 【2.21】タブの結合（設計書 4.11.6） }
  GEditors: TFPList = nil;            { 実行時のエディタの一覧（結合で、受けるエディタを探す） }
  GReceiverWnd: HWND = 0;             { 受け口（プロセスに 1 つ） }
  GReceiverClassOk: Boolean = False;

procedure EnsureReceiver; forward;    { 【2.21】受け口を作る（本体は「タブの結合」の所） }

{ ---------- フォームごとの連結 ---------- }

function FindHook(AForm: TCustomForm; ACreate: Boolean): TCMFormHook;
var
  I: Integer;
begin
  Result := nil;
  if AForm = nil then Exit;
  for I := 0 to AForm.ComponentCount - 1 do
    if AForm.Components[I] is TCMFormHook then
      Exit(TCMFormHook(AForm.Components[I]));
  if ACreate and (AForm is TForm) then
    Result := TCMFormHook.CreateFor(TForm(AForm));
end;

function CMActiveEditor(AForm: TCustomForm): TCMonacoEditor;
var
  H: TCMFormHook;
begin
  Result := nil;
  H := FindHook(AForm, False);
  if H <> nil then Result := H.ActiveEditor;
end;

constructor TCMFormHook.CreateFor(AForm: TForm);
begin
  inherited Create(AForm);
  FForm := AForm;
  FEditors := TFPList.Create;
  FOldCloseQuery := FForm.OnCloseQuery;      { 設計時に設定された OnCloseQuery も、そのまま呼ぶ }
  FForm.OnCloseQuery := @FormCloseQuery;
end;

destructor TCMFormHook.Destroy;
var
  M: TCloseQueryEvent;
begin
  if (FForm <> nil) and not (csDestroying in FForm.ComponentState) then
  begin
    M := FForm.OnCloseQuery;
    if TMethod(M).Data = Pointer(Self) then
      FForm.OnCloseQuery := FOldCloseQuery;
  end;
  FreeAndNil(FEditors);
  inherited Destroy;      { エディタには opRemove が通知され、エディタ側の参照は nil になる }
end;

procedure TCMFormHook.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then Exit;
  if AComponent is TCMonacoEditor then
  begin
    if FEditors <> nil then FEditors.Remove(AComponent);
    if AComponent = FActive then FActive := nil;
  end
  else if AComponent = FFindDialog then
    FFindDialog := nil;
end;

procedure TCMFormHook.AddEditor(AEditor: TCMonacoEditor);
begin
  if FEditors.IndexOf(AEditor) >= 0 then Exit;
  FEditors.Add(AEditor);
  AEditor.FreeNotification(Self);
end;

procedure TCMFormHook.RemoveEditor(AEditor: TCMonacoEditor);
begin
  if FEditors <> nil then FEditors.Remove(AEditor);
  if FActive = AEditor then FActive := nil;
  AEditor.RemoveFreeNotification(Self);
end;

procedure TCMFormHook.SetActive(AEditor: TCMonacoEditor);
begin
  FActive := AEditor;
end;

function TCMFormHook.ActiveEditor: TCMonacoEditor;
begin
  Result := FActive;
  if (Result = nil) and (FEditors.Count > 0) then
    Result := TCMonacoEditor(FEditors[0]);
end;

function TCMFormHook.SharedFindDialog: TCMFindDialog;
begin
  if FFindDialog = nil then
  begin
    FFindDialog := TCMFindDialog.Create(Self);
    FFindDialog.FreeNotification(Self);
  end;
  Result := FFindDialog;
end;

procedure TCMFormHook.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  I: Integer;
begin
  if Assigned(FOldCloseQuery) then FOldCloseQuery(Sender, CanClose);
  if not CanClose then Exit;
  { 1つでもキャンセルされたら、その時点で中止（残りは確認しない） }
  for I := 0 to FEditors.Count - 1 do
    if not TCMonacoEditor(FEditors[I]).CanCloseAll then
    begin
      CanClose := False;
      Exit;
    end;
end;

{ ---------- TCMonacoEditor : 生成 ---------- }

constructor TCMonacoEditor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csSetCaption, csAcceptsControls];
  SetTextBuf('');                 { パネルの見出しは使わない }
  BevelOuter := bvNone;
  BevelInner := bvNone;
  Width := 500;
  Height := 300;
  TabStop := True;
  ParentColor := False;

  FMultiDocument := True;
  FConfirmOnFormClose := True;
  FShowPreview := False;
  FPreviewWidth := 500;
  FErrQueue := TStringList.Create;
  FPages := TList.Create;
  FSelectionColorStyle := scStandard;     { 【2.13】 }
  FLineDelimiters := ' ' + '　' + #9 + ',' + '、';   { 【2.14】半角スペース・全角スペース・タブ・カンマ・読点 }
  FLineSkipEmpty := True;
  FLineQuoteChar := '"';
  FLineWords := TStringList.Create;
  FTearOffHead := TStringList.Create;     { 【2.20】 }
  FMergeQueue := TStringList.Create;      { 【2.21】 }
  FTabTearOff := True;                    { 【2.21】既定は分離・結合する }

  { 【2.15】テーマ・配色の組・色の既定値。中の部品の既定値と同じ色なので、中の部品へは送らない }
  FTheme := ctAuto;
  FColorScheme := csEditor;
  FHitColorLight := DefHitColorLight;
  FHitColorDark := DefHitColorDark;
  FCursorLineColorLight := DefCursorLineColorLight;
  FCursorLineColorDark := DefCursorLineColorDark;
  FSelectionColorLight := SelStyleLight[scStandard];
  FSelectionColorDark := SelStyleDark[scStandard];
  FPreviewBackColorLight := DefPreviewBackColorLight;
  FPreviewBackColorDark := DefPreviewBackColorDark;
  FPreviewTextColorLight := DefPreviewTextColorLight;
  FPreviewTextColorDark := DefPreviewTextColorDark;
  FPreviewLinkColorLight := DefPreviewLinkColorLight;
  FPreviewLinkColorDark := DefPreviewLinkColorDark;

  { 中の部品（Owner は Self。フォームには保存されない） }
  FTabs := TATTabs.Create(Self);
  FTabs.Parent := Self;
  FTabs.Align := alTop;
  FTabFlat := True;
  FTabSeparator := False;
  FTabIcons := True;
  FSysImages := TImageList.Create(Self);
  FSysImages.Width := 16;
  FSysImages.Height := 16;
  FSysIconExts := TStringList.Create;
  FSysIconExts.Sorted := True;
  FTabs.OptShowFlatMouseOver := True;      { マウスを乗せたタブだけ、色を変える }

  FMonaco := TCMMonacoView.Create(Self);
  FMonaco.Parent := Self;
  FMonaco.Align := alClient;

  FPreview := TCMMarkdownPreview.Create(Self);
  FPreview.Visible := False;              { 表示されるまで WebView2 を作らない }
  FPreview.Parent := Self;
  FPreview.Width := FPreviewWidth;
  FPreview.Align := alRight;

  FSplitter := TSplitter.Create(Self);
  FSplitter.Visible := False;
  FSplitter.Parent := Self;
  FSplitter.Align := alRight;
  FSplitter.Width := 5;
  FSplitter.ResizeStyle := rsLine;
  FSplitter.MinSize := 100;
  FSplitter.OnMoved := @SplitterMoved;

  { 中の部品のイベントを、先に自分へつなぐ（このあと Binder が連結して使う） }
  FMonaco.OnReady := @MonacoReady;
  FMonaco.OnChange := @MonacoChange;
  FMonaco.OnCursorChange := @MonacoCursorChange;
  FMonaco.OnModeChange := @MonacoModeChange;
  FMonaco.OnSave := @MonacoSave;
  FMonaco.OnModifiedChange := @MonacoModifiedChange;
  FMonaco.OnActiveChange := @MonacoActiveChange;
  FMonaco.OnDocListChange := @MonacoDocListChange;
  FMonaco.OnDocumentChange := @MonacoDocumentChange;
  FMonaco.OnQueryClose := @MonacoQueryClose;
  FMonaco.OnNeedFileName := @MonacoNeedFileName;
  FMonaco.OnFileDrop := @MonacoFileDrop;
  FMonaco.OnToggleMaximize := @MonacoToggleMaximize;
  FMonaco.OnFontSizeChange := @MonacoFontSizeChange;
  FMonaco.OnLineNumbersChange := @MonacoLineNumbersChange;
  FMonaco.OnFindRequest := @MonacoFindRequest;
  FMonaco.OnFindDone := @MonacoFindDone;
  FMonaco.OnReplaceAllDone := @MonacoReplaceAllDone;
  FMonaco.OnPopup := @MonacoPopup;
  FMonaco.OnError := @MonacoError;
  FMonaco.OnGotFocus := @MonacoGotFocus;
  FMonaco.OnTogglePreview := @MonacoTogglePreview;
  FMonaco.OnAccelKeyDown := @MonacoAccelKeyDown;
  FMonaco.OnOsThemeChange := @MonacoOsThemeChange;
  FPreview.OnError := @PreviewError;
  FPreview.OnAfterPrint := @PreviewAfterPrint;
  FPreview.OnPrintKey := @PreviewPrintKey;   { 【2.8】 }
  FPreview.OnOpenMarkdown := @PreviewOpenMarkdown;   { 先に設定しておくと、Binder は上書きしない }

  { タブとプレビューの連携（内部） }
  FTabBinder := TCMTabBinder.Create(Self);
  FTabBinder.ConfirmClose := False;                 { 未保存の確認は、この部品が行う }
  FTabBinder.OnGetImageIndex := @BinderGetImageIndex;
  FTabBinder.OnDragOut := @BinderTabDragOut;        { 【2.20】タブの分離 }
  FTabBinder.Attach(FMonaco, FTabs);
  FPreviewBinder := TCMPreviewBinder.Create(Self);
  FPreviewBinder.Attach(FMonaco, FPreview);

  AddViewMenuItems;               { 右クリックメニューの末尾：ミニマップ・プレビューの切り替え }
  ApplyTabShape;
  ApplyTabIcons;

  ApplyThemeColors;
end;

destructor TCMonacoEditor.Destroy;
var
  I: Integer;
begin
  Application.RemoveAsyncCalls(Self);
  if FHook <> nil then FHook.RemoveEditor(Self);
  FErrQueue.Free;
  FreeAndNil(FLineWords);                 { 【2.13】 }
  FreeAndNil(FTearOffHead);               { 【2.20】 }
  if GEditors <> nil then GEditors.Remove(Self);   { 【2.21】結合の受け口から外す }
  FreeAndNil(FMergeQueue);                { 【2.21】 }
  if FPages <> nil then
    for I := 0 to FPages.Count - 1 do TCMPage(FPages[I]).Free;
  FreeAndNil(FPages);
  FreeAndNil(FSysIconExts);
  inherited Destroy;
end;

procedure TCMonacoEditor.Loaded;
begin
  inherited Loaded;
  ApplyThemeColors;
  { 【2.20】.lfm から作ったエディタ：分離で起動されたなら、ここで受け取り、フォームを落とした位置に出す
    （フォームが表示される前なので、最初からその位置に出る）。タブは準備ができてから作る（MonacoReady） }
  if TryClaimTearOff then MoveFormToTearOff;
end;

procedure TCMonacoEditor.CreateWnd;
begin
  inherited CreateWnd;
  FDesignMode := CMIsDesigning(Self);
  if FDesignMode then
  begin
    { 設計時は WebView2 を起動しない。中の部品を隠し、枠と部品名だけを描く }
    FTabs.Visible := False;
    FMonaco.Visible := False;
    FSplitter.Visible := False;
    FPreview.Visible := False;
    Exit;
  end;
  FTabs.Visible := FMultiDocument;
  RegisterWithForm;
  UpdatePreview;
  { 【2.21】結合の受け口に加える（実行時だけ。受け口はプロセスに 1 つ。初めてのときに作る） }
  if (GEditors <> nil) and (GEditors.IndexOf(Self) < 0) then GEditors.Add(Self);
  EnsureReceiver;
end;

procedure TCMonacoEditor.Paint;
var
  S: string;
begin
  inherited Paint;
  if not FDesignMode and not (csDesigning in ComponentState) then Exit;
  Canvas.Pen.Color := clGrayText;
  Canvas.Pen.Style := psDash;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(0, 0, Width, Height);
  S := Name + ' : TCMonacoEditor';
  Canvas.Font.Color := clGrayText;
  Canvas.TextOut(8, 8, S);
end;

procedure TCMonacoEditor.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then Exit;
  if AComponent = FOpenDialog then FOpenDialog := nil
  else if AComponent = FSaveDialog then FSaveDialog := nil
  else if AComponent = FFindDialog then FFindDialog := nil
  else if AComponent = FTabImages then
  begin
    FTabImages := nil;
    if not (csDestroying in ComponentState) then ApplyTabIcons;
  end
  else if AComponent = FHook then FHook := nil;
end;

procedure TCMonacoEditor.RegisterWithForm;
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

procedure TCMonacoEditor.SetFocus;
begin
  { 【2.11】その場では移さず、今の処理（ボタンのクリック、OnKeyDown・OnReady などの WebView2 の知らせ）が
    終わってから移す。途中で移すと、IME の状態が乱れて入力できなくなるため（タブのクリックと同じ作り） }
  if FFocusPending then Exit;
  FFocusPending := True;
  Application.QueueAsyncCall(@AsyncSetFocus, 0);
end;

procedure TCMonacoEditor.AsyncSetFocus(Data: PtrInt);
begin
  FFocusPending := False;
  if not CanFocus then Exit;                   { 見えない・無効なら何もしない（例外にしない） }
  if FMonaco.CanFocus then FMonaco.SetFocus else inherited SetFocus;
end;

{ ---------- 配色 ---------- }

function TCMonacoEditor.IsDarkTheme: Boolean;
var
  R: TRegistry;
begin
  { 【2.15】Theme は列挙型。ctDark・ctLight は固定、ctAuto は OS に従う }
  if FTheme = ctDark then Exit(True);
  if FTheme = ctLight then Exit(False);
  { ctAuto : OS の設定に従う。実行中に変わったら、editor.html からの通知（FOsDark）を使う }
  if FOsDarkKnown then Exit(FOsDark);
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

procedure TCMonacoEditor.ApplyThemeColors;
var
  CBar, COver, CActive, CFont, CFontActive, CLine, CSplit: TColor;
begin
  { Windows 11 のエクスプローラーに合わせた配色（仮の値。実機で調整する）。どれも灰色なので RGB/BGR の違いはない }
  if IsDarkTheme then
  begin
    CBar := TColor($2B2B2B);
    COver := TColor($383838);
    CActive := TColor($1E1E1E);            { エディタの背景と同じ（タブと本文がつながって見える） }
    CFont := TColor($C5C5C5);
    CFontActive := TColor($FFFFFF);
    CLine := TColor($3A3A3A);
    CSplit := TColor($2B2B2B);
  end
  else
  begin
    CBar := TColor($F0F0F0);
    COver := TColor($E5E5E5);
    CActive := TColor($FFFFFF);
    CFont := TColor($5C5C5C);
    CFontActive := TColor($000000);
    CLine := TColor($D9D9D9);
    CSplit := TColor($E5E5E5);
  end;

  Color := CActive;                       { 起動直後に見える背景。ダークで白く光らない }
  FSplitter.Color := CSplit;

  FTabs.ColorBg := CBar;
  FTabs.ColorTabPassive := CBar;
  FTabs.ColorTabOver := COver;
  FTabs.ColorTabActive := CActive;        { 台形（TabFlat=False）のとき }
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
  FTabs.ColorActiveMark := CActive;       { 色付きの線（アクセント）は出さない：背景と同じ色にして見えなくする }
  { フラット表示でも、選択中・マウスを乗せたタブを、タブごとの色で塗る }
  if FTabBinder <> nil then FTabBinder.SetTabColors(CActive, COver);
  FTabs.Invalidate;
  Invalidate;
end;

procedure TCMonacoEditor.MonacoOsThemeChange(Sender: TObject; IsDark: Boolean);
begin
  FOsDark := IsDark;
  FOsDarkKnown := True;
  ApplyThemeColors;      { Theme=ctLight/ctDark のときは、IsDarkTheme が固定値を返すので変わらない }
end;

{ ---------- タブの形 ---------- }

procedure TCMonacoEditor.ApplyTabShape;
begin
  FTabs.OptShowFlat := FTabFlat;
  FTabs.OptShowFlatSepar := FTabSeparator;
  FTabs.Invalidate;
end;

{ ---------- タブのアイコン ---------- }

function TCMonacoEditor.SystemIconIndex(const AFileName: string): Integer;
var
  Ext: string;
  Info: TSHFileInfoW;
  Ico: TIcon;
  I: Integer;
begin
  { 拡張子から、エクスプローラーと同じアイコンを取り出す。無題（拡張子なし）は、テキストの汎用アイコン }
  Ext := LowerCase(ExtractFileExt(AFileName));
  if Ext = '' then Ext := '.txt';
  I := FSysIconExts.IndexOf(Ext);
  if I >= 0 then Exit(PtrInt(FSysIconExts.Objects[I]));
  Result := -1;
  FillChar(Info, SizeOf(Info), 0);
  { SHGFI_USEFILEATTRIBUTES：ファイルが存在しなくても、拡張子だけで取得する }
  if (SHGetFileInfoW(PWideChar(UnicodeString('x' + Ext)), FILE_ATTRIBUTE_NORMAL, Info, SizeOf(Info),
      SHGFI_ICON or SHGFI_SMALLICON or SHGFI_USEFILEATTRIBUTES) <> 0) and (Info.hIcon <> 0) then
  begin
    Ico := TIcon.Create;
    try
      Ico.Handle := Info.hIcon;      { TIcon が解放する }
      Result := FSysImages.AddIcon(Ico);
    finally
      Ico.Free;
    end;
  end;
  FSysIconExts.AddObject(Ext, TObject(PtrInt(Result)));
end;

procedure TCMonacoEditor.BinderGetImageIndex(Sender: TObject; Index: Integer;
  const AFileName: string; var ImageIndex: Integer);
begin
  ImageIndex := -1;
  if not FTabIcons or (FSysIconExts = nil) or (csDestroying in ComponentState) then Exit;
  if FTabImages <> nil then
  begin
    ImageIndex := 0;                                       { 未設定なら 0 番 }
    if Assigned(FOnGetTabImageIndex) then FOnGetTabImageIndex(Self, Index, AFileName, ImageIndex);
  end
  else
    ImageIndex := SystemIconIndex(AFileName);
end;

procedure TCMonacoEditor.ApplyTabIcons;
begin
  if not FTabIcons then
    FTabs.Images := nil
  else if FTabImages <> nil then
    FTabs.Images := FTabImages
  else
    FTabs.Images := FSysImages;
  if FTabBinder <> nil then FTabBinder.Refresh;
end;

procedure TCMonacoEditor.SetTabIcons(AValue: Boolean);
begin
  FTabIcons := AValue;
  ApplyTabIcons;
end;

procedure TCMonacoEditor.SetTabImages(AValue: TImageList);
begin
  if FTabImages = AValue then Exit;
  if FTabImages <> nil then FTabImages.RemoveFreeNotification(Self);
  FTabImages := AValue;
  if FTabImages <> nil then FTabImages.FreeNotification(Self);
  ApplyTabIcons;
end;

procedure TCMonacoEditor.SetTabFlat(AValue: Boolean);
begin
  FTabFlat := AValue;
  ApplyTabShape;
end;

procedure TCMonacoEditor.SetTabSeparator(AValue: Boolean);
begin
  FTabSeparator := AValue;
  ApplyTabShape;
end;

{ ---------- エラー ---------- }

procedure TCMonacoEditor.DoError(const AMessage: string);
begin
  if Assigned(FOnError) then
  begin
    FOnError(Self, AMessage);
    Exit;
  end;
  if FDesignMode then Exit;
  { WebView2 の通知の途中でダイアログを出さないよう、あとで表示する }
  FErrQueue.Add(AMessage);
  Application.QueueAsyncCall(@AsyncShowError, 0);
end;

procedure TCMonacoEditor.AsyncShowError(Data: PtrInt);
var
  S: string;
begin
  while FErrQueue.Count > 0 do
  begin
    S := FErrQueue[0];
    FErrQueue.Delete(0);
    if GShownErrors.IndexOf(S) >= 0 then Continue;   { 同じメッセージは1回だけ }
    GShownErrors.Add(S);
    MessageDlg(S, mtError, [mbOK], 0);
  end;
end;

procedure TCMonacoEditor.MonacoError(Sender: TObject; const AMessage: string);
begin
  DoError(AMessage);
end;

procedure TCMonacoEditor.PreviewError(Sender: TObject; const AMessage: string);
begin
  DoError(AMessage);
end;

{ ---------- 未保存の確認 ---------- }

procedure TCMonacoEditor.DoQueryClose(AIndex: Integer; var CanClose: Boolean);
begin
  CanClose := True;
  if Assigned(FOnQueryClose) then
    FOnQueryClose(Self, AIndex, CanClose)
  else if FConfirmOnFormClose then
    case MessageDlg('未保存の変更',
        FMonaco.DocumentTitle[AIndex] + ' は変更されています。' + LineEnding +
        '保存しますか？（いいえ = 保存せずに閉じる）',
        mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
      mrYes:
        begin
          FMonaco.SaveDocument(AIndex);
          CanClose := not FMonaco.DocumentModified[AIndex];   { 保存されなければ閉じない }
        end;
      mrNo: CanClose := True;
    else
      CanClose := False;
    end;
  { ConfirmOnFormClose = False でイベントも無ければ、確認せずに破棄（CanClose = True のまま） }
end;

procedure TCMonacoEditor.MonacoQueryClose(Sender: TObject; Index: Integer; var CanClose: Boolean);
begin
  DoQueryClose(Index, CanClose);
end;

function TCMonacoEditor.CanCloseAll: Boolean;
var
  I: Integer;
  C: Boolean;
begin
  Result := True;
  for I := 0 to FMonaco.DocumentCount - 1 do
    if FMonaco.DocumentModified[I] then
    begin
      C := True;
      DoQueryClose(I, C);
      if not C then Exit(False);
    end;
end;

{ ---------- 保存ダイアログ ---------- }

function TCMonacoEditor.DefaultExtFor(const ALanguage: string): string;
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
  { 【段階5】追加 }
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

function TCMonacoEditor.AskSaveFileName(AIndex: Integer; var AFileName: string): Boolean;
var
  Dlg: TSaveDialog;
  L, Dir: string;
begin
  if FSaveDialog <> nil then
    Dlg := FSaveDialog                      { 利用者が選んだダイアログは、設定をそのまま使う }
  else
  begin
    if FInnerSaveDlg = nil then
    begin
      FInnerSaveDlg := TSaveDialog.Create(Self);
      FInnerSaveDlg.Filter := 'Markdown (*.md;*.markdown)|*.md;*.markdown|' +
        'テキスト (*.txt)|*.txt|すべてのファイル (*.*)|*.*';
      FInnerSaveDlg.Options := FInnerSaveDlg.Options + [ofOverwritePrompt, ofPathMustExist];
    end;
    Dlg := FInnerSaveDlg;
    L := LowerCase(FMonaco.DocumentLanguage[AIndex]);            { 保存するページの言語・フォルダ・名前を使う }
    Dlg.DefaultExt := DefaultExtFor(L);
    if L = 'markdown' then Dlg.FilterIndex := 1
    else if L = 'plaintext' then Dlg.FilterIndex := 2
    else Dlg.FilterIndex := 3;
    Dir := ExtractFilePath(FMonaco.DocumentFileName[AIndex]);
    if Dir = '' then Dir := FLastDir;
    Dlg.InitialDir := Dir;
    Dlg.FileName := ExtractFileName(FMonaco.DocumentFileName[AIndex]);
  end;
  Result := Dlg.Execute;
  if Result then
  begin
    AFileName := Dlg.FileName;
    FLastDir := ExtractFilePath(AFileName);
  end;
end;

procedure TCMonacoEditor.MonacoNeedFileName(Sender: TObject; var AFileName: string;
  var Cancel: Boolean);
begin
  if Assigned(FOnNeedFileName) then
    FOnNeedFileName(Self, AFileName, Cancel)
  else
    Cancel := not AskSaveFileName(FMonaco.ActiveIndex, AFileName);   { 内部（Ctrl+S など）は、表示中のページを保存する }
end;

{ ---------- 文書 ---------- }

function TCMonacoEditor.QueryCurrent: Boolean;
var
  C: Boolean;
begin
  { 【2.9】MultiDocument = False：タブは入れ替えず、0 番の中身を入れ替える。その前の確認（閉じはしない） }
  Result := True;
  if FMonaco.DocumentModified[0] then
  begin
    C := True;
    DoQueryClose(0, C);
    Result := C;
  end;
end;

function TCMonacoEditor.OpenFile(const AFileName: string): Integer;
var
  I: Integer;
begin
  { 【2.16】名前を省略したら、開くダイアログで選ばせる }
  if AFileName = '' then Exit(OpenWithDialog);
  if FMultiDocument then Exit(FMonaco.OpenFile(AFileName));
  { 【2.9】MultiDocument = False：タブは入れ替えず、0 番に読み込む }
  I := FMonaco.FindDocument(AFileName);
  if I >= 0 then Exit(I);                     { 同じファイルを開いている }
  if not QueryCurrent then Exit(-1);
  FMonaco.LoadDocument(0, AFileName);         { 読めなければ例外（何も変わらない） }
  Result := 0;
end;


{ 【2.16】開くダイアログで選んだファイルを開く。
  ・ダイアログは OpenDialog に設定したもの（設定はそのまま使う）。未設定なら内蔵のもの
  ・内蔵のダイアログは、フィルタは保存と同じ。初期フォルダは見えているタブのフォルダ（無題なら前回のフォルダ）。
    タブあり（MultiDocument = True）なら複数選択できる
  ・選んだファイルは、名前を指定したときと同じ OpenFile で 1 つずつ開く。タブなし（False）は最初の 1 つだけ
  ・読めないファイルは例外にせず OnError で知らせ、残りを続ける
  ・戻り値は最後に開いたタブの番号。キャンセル・1 つも開けなかったときは -1 }
function TCMonacoEditor.OpenWithDialog: Integer;
var
  Dlg: TOpenDialog;
  Dir: string;
  Files: TStringList;
  I, R: Integer;
begin
  Result := -1;
  if FOpenDialog <> nil then
    Dlg := FOpenDialog                      { 利用者が選んだダイアログは、設定をそのまま使う }
  else
  begin
    if FInnerOpenDlg = nil then
    begin
      FInnerOpenDlg := TOpenDialog.Create(Self);
      FInnerOpenDlg.Filter := 'Markdown (*.md;*.markdown)|*.md;*.markdown|' +
        'テキスト (*.txt)|*.txt|すべてのファイル (*.*)|*.*';
      FInnerOpenDlg.Options := FInnerOpenDlg.Options + [ofFileMustExist, ofPathMustExist];
    end;
    Dlg := FInnerOpenDlg;
    if FMultiDocument then
      Dlg.Options := Dlg.Options + [ofAllowMultiSelect]
    else
      Dlg.Options := Dlg.Options - [ofAllowMultiSelect];
    Dir := ExtractFilePath(FMonaco.DocumentFileName[FMonaco.ActiveIndex]);
    if Dir = '' then Dir := FLastDir;
    Dlg.InitialDir := Dir;
    Dlg.FileName := '';
  end;
  if not Dlg.Execute then Exit;             { キャンセル：何もしない }

  Files := TStringList.Create;
  try
    if (ofAllowMultiSelect in Dlg.Options) and (Dlg.Files.Count > 0) then
      Files.Assign(Dlg.Files)
    else
      Files.Add(Dlg.FileName);
    if not FMultiDocument then
      while Files.Count > 1 do Files.Delete(Files.Count - 1);   { タブなしは最初の 1 つだけ }
    for I := 0 to Files.Count - 1 do
    begin
      if Files[I] = '' then Continue;       { 名前が空だと OpenFile がまたダイアログを出すので飛ばす }
      try
        R := OpenFile(Files[I]);            { 同じファイルを開いていれば切り替えるだけ。タブなしは変更があれば聞く }
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

procedure TCMonacoEditor.SaveAll;
begin
  FMonaco.SaveAll;
end;

function TCMonacoEditor.CloseAll(Force: Boolean): Boolean;
begin
  { 【2.9】閉じ終わると空の無題が 1 枚残る（view が保証）。MultiDocument = False は中身を空にする }
  if FMultiDocument then
    Result := FMonaco.CloseAll(Force)
  else
    Result := PageClose(0, Force);
end;

{ ---------- ページの集まり ---------- }

function TCMonacoEditor.NewPage: Integer;
begin
  if FMultiDocument then Exit(FMonaco.AddDocument(''));
  { 【2.9】MultiDocument = False：タブは入れ替えず、0 番を空にする（変更があれば聞く） }
  if not QueryCurrent then Exit(-1);
  FMonaco.ClearDocument(0);
  Result := 0;
end;

function TCMonacoEditor.FindPage(const AFileName: string): Integer;
begin
  Result := FMonaco.FindDocument(AFileName);
end;

procedure TCMonacoEditor.MovePage(AFromIndex, AToIndex: Integer);
begin
  FMonaco.MoveDocument(AFromIndex, AToIndex);
end;

{ ---------- Pages[n] と、見えているタブ ---------- }

function TCMonacoEditor.GetPage(AIndex: Integer): TCMPage;
var
  I, Id: Integer;
begin
  if (AIndex < 0) or (AIndex >= FMonaco.DocumentCount) then
    raise EListError.CreateFmt('Pages[%d]: ページの番号が範囲外です（ページの数 %d）',
      [AIndex, FMonaco.DocumentCount]);
  Id := FMonaco.DocumentId(AIndex);
  for I := 0 to FPages.Count - 1 do
    if TCMPage(FPages[I]).FId = Id then Exit(TCMPage(FPages[I]));
  Result := TCMPage.Create(Self, Id);       { 1 つのタブにつき 1 つだけ作る }
  FPages.Add(Result);
end;

function TCMonacoEditor.CurPage: TCMPage;
begin
  Result := GetPage(FMonaco.ActiveIndex);
end;

function TCMonacoEditor.GetEdText: string; begin Result := CurPage.Text; end;
procedure TCMonacoEditor.SetEdText(const AValue: string); begin CurPage.Text := AValue; end;
function TCMonacoEditor.GetEdCaption: string; begin Result := CurPage.Caption; end;
function TCMonacoEditor.GetEdFileName: string; begin Result := CurPage.FileName; end;
function TCMonacoEditor.GetEdModified: Boolean; begin Result := CurPage.Modified; end;
function TCMonacoEditor.GetEdEncoding: TCMEncoding; begin Result := CurPage.Encoding; end;
procedure TCMonacoEditor.SetEdEncoding(AValue: TCMEncoding); begin CurPage.Encoding := AValue; end;
function TCMonacoEditor.GetEdLanguage: string; begin Result := CurPage.Language; end;
procedure TCMonacoEditor.SetEdLanguage(const AValue: string); begin CurPage.Language := AValue; end;
function TCMonacoEditor.GetEdLineCount: Integer; begin Result := CurPage.LineCount; end;

function TCMonacoEditor.LoadFromFile(const AFileName: string): Boolean; begin Result := CurPage.LoadFromFile(AFileName); end;
function TCMonacoEditor.Save: Boolean; begin Result := CurPage.Save; end;
function TCMonacoEditor.SaveAs(const AFileName: string): Boolean; begin Result := CurPage.SaveAs(AFileName); end;
procedure TCMonacoEditor.Clear; begin CurPage.Clear; end;
function TCMonacoEditor.Close(Force: Boolean): Boolean; begin Result := CurPage.Close(Force); end;

function TCMonacoEditor.AskPageFileName(AIndex: Integer; var AFileName: string): Boolean;
var
  Cancel: Boolean;
begin
  Cancel := False;
  if Assigned(FOnNeedFileName) then
    FOnNeedFileName(Self, AFileName, Cancel)
  else
    Cancel := not AskSaveFileName(AIndex, AFileName);
  Result := (not Cancel) and (AFileName <> '');
end;

function TCMonacoEditor.PageSave(AIndex: Integer): Boolean;
var
  N: string;
begin
  Result := False;
  N := FMonaco.DocumentFileName[AIndex];
  if N = '' then
    Exit(PageSaveAs(AIndex, ''));               { 無題：切り替えずに保存先を聞く }
  try
    FMonaco.SaveDocumentTo(AIndex, '');
    Result := True;
  except
    on E: Exception do DoError(N + ': ' + E.Message);   { ' *' は残る }
  end;
end;

function TCMonacoEditor.PageSaveAs(AIndex: Integer; const AFileName: string): Boolean;
var
  N: string;
  I: Integer;
begin
  Result := False;
  N := AFileName;
  if (N = '') and not AskPageFileName(AIndex, N) then Exit;   { キャンセル：何も書かない（' *' は残る） }
  { 別のページで開いているファイルの名前なら、保存しない（1 ファイル＝1 タブを崩さない） }
  I := FMonaco.FindDocument(N);
  if (I >= 0) and (I <> AIndex) then
  begin
    DoError('そのファイルは別のタブで開いています: ' + N);
    Exit;
  end;
  try
    FMonaco.SaveDocumentTo(AIndex, N);          { 名前を指定したときは、聞かずに上書きする }
    Result := True;
  except
    on E: Exception do DoError(N + ': ' + E.Message);
  end;
end;

function TCMonacoEditor.PageLoad(AIndex: Integer; const AFileName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if not FileExists(AFileName) then
  begin
    DoError('ファイルが見つかりません: ' + AFileName);   { 何も変えない }
    Exit;
  end;
  { 別のページで開いていれば、読み込まない（同じファイルを 2 つのタブで開かない。表示も切り替えない） }
  I := FMonaco.FindDocument(AFileName);
  if (I >= 0) and (I <> AIndex) then
  begin
    DoError('そのファイルは別のタブで開いています: ' + AFileName);
    Exit;
  end;
  try
    FMonaco.LoadDocument(AIndex, AFileName);   { 変更は聞かずに捨てる。読めなければ例外（何も変わらない） }
    Result := True;
  except
    on E: Exception do DoError(AFileName + ': ' + E.Message);
  end;
end;

procedure TCMonacoEditor.PageClear(AIndex: Integer);
begin
  FMonaco.ClearDocument(AIndex);
end;

function TCMonacoEditor.PageClose(AIndex: Integer; Force: Boolean): Boolean;
begin
  if not FMultiDocument then
  begin
    { 【2.9】MultiDocument = False：閉じずに中身を空にする（タブは 1 枚のまま） }
    if (not Force) and not QueryCurrent then Exit(False);
    FMonaco.ClearDocument(0);
    Exit(True);
  end;
  Result := FMonaco.CloseDocument(AIndex, Force);   { 最後の 1 枚なら、view が空の無題を残す }
end;

{ ---------- TCMPage ---------- }

constructor TCMPage.Create(AOwner: TCMonacoEditor; AId: Integer);
begin
  inherited Create;
  FOwner := AOwner;
  FId := AId;
end;

function TCMPage.GetIndex: Integer;
begin
  Result := FOwner.FMonaco.IndexOfId(FId);   { 閉じていれば -1 }
end;

function TCMPage.GetCaption: string;
var
  I: Integer;
begin
  I := GetIndex;
  if I >= 0 then Result := FOwner.FMonaco.DocumentTitle[I] else Result := '';
end;

function TCMPage.GetFileName: string;
var
  I: Integer;
begin
  I := GetIndex;
  if I >= 0 then Result := FOwner.FMonaco.DocumentFileName[I] else Result := '';
end;

function TCMPage.GetModified: Boolean;
var
  I: Integer;
begin
  I := GetIndex;
  Result := (I >= 0) and FOwner.FMonaco.DocumentModified[I];
end;

function TCMPage.GetEncoding: TCMEncoding;
var
  I: Integer;
begin
  I := GetIndex;
  if I >= 0 then Result := FOwner.FMonaco.DocumentEncoding[I] else Result := ceUTF8;
end;

procedure TCMPage.SetEncoding(AValue: TCMEncoding);
var
  I: Integer;
begin
  I := GetIndex;
  if I >= 0 then FOwner.FMonaco.DocumentEncoding[I] := AValue;
end;

function TCMPage.GetLanguage: string;
var
  I: Integer;
begin
  I := GetIndex;
  if I >= 0 then Result := FOwner.FMonaco.DocumentLanguage[I] else Result := '';
end;

procedure TCMPage.SetLanguage(const AValue: string);
var
  I: Integer;
begin
  I := GetIndex;
  if I >= 0 then FOwner.FMonaco.DocumentLanguage[I] := AValue;
end;

procedure TCMPage.Clear;
var
  I: Integer;
begin
  I := GetIndex;
  if I >= 0 then FOwner.PageClear(I);
end;

function TCMPage.LoadFromFile(const AFileName: string): Boolean;
var
  I: Integer;
begin
  I := GetIndex;
  Result := (I >= 0) and FOwner.PageLoad(I, AFileName);
end;

function TCMPage.Save: Boolean;
var
  I: Integer;
begin
  I := GetIndex;
  Result := (I >= 0) and FOwner.PageSave(I);
end;

function TCMPage.SaveAs(const AFileName: string): Boolean;
var
  I: Integer;
begin
  I := GetIndex;
  Result := (I >= 0) and FOwner.PageSaveAs(I, AFileName);
end;

function TCMPage.GetText: string;
var
  I: Integer;
begin
  I := GetIndex;
  if I >= 0 then Result := FOwner.FMonaco.DocumentText[I] else Result := '';
end;

function TCMPage.GetLineCount: Integer;
var
  S: string;
  I, N: Integer;
begin
  if GetIndex < 0 then Exit(0);
  S := GetText;
  N := 1;
  I := 1;
  while I <= Length(S) do
  begin
    if S[I] = #13 then
    begin
      Inc(N);
      if (I < Length(S)) and (S[I + 1] = #10) then Inc(I);
    end
    else if S[I] = #10 then
      Inc(N);
    Inc(I);
  end;
  Result := N;
end;

procedure TCMPage.SetText(const AValue: string);
var
  I: Integer;
begin
  I := GetIndex;
  if I >= 0 then FOwner.FMonaco.DocumentText[I] := AValue;
end;

function TCMPage.Close(Force: Boolean): Boolean;
var
  I: Integer;
begin
  I := GetIndex;
  Result := (I >= 0) and FOwner.PageClose(I, Force);
end;

{ ---------- 【2.20】タブの分離（設計書 4.11） ---------- }

const
  TearOffMark = 'CMTEAROFF1';     { 一時ファイルの 1 行目（目印） }
  TearOffEnv = 'CM_TEAROFF';      { 一時ファイルの場所を渡す環境変数 }
  CM_CREATE_UNICODE_ENVIRONMENT = $00000400;

var
  GTearOffRead: Boolean = False;     { 環境変数を読んだ（1 回だけ読む） }
  GTearOffFile: string = '';         { 分離で起動されたときの一時ファイル。普通の起動なら '' }
  GTearOffClaimed: Boolean = False;  { どれかのエディタが受け取った（1 回だけ受ける） }

{ 分離で起動されたときの一時ファイルの場所。普通の起動なら ''。
  最初に呼ばれたときに 1 回だけ環境変数 CM_TEAROFF を読み、すぐに消す
  （この EXE がさらに別の EXE を起動しても引き継がないように） }
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

{ 一時ファイルを書く（UTF-8）。1 行目が目印、空の行までが見出し（名前=値）、その後ろの全部が本文 }
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

{ 一時ファイルを読む。形が違う（1 行目が目印でない・空の行がない）・読めないときは False }
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
  { 1 行目（目印） }
  P := Pos(#13#10, S);
  if (P = 0) or (Copy(S, 1, P - 1) <> TearOffMark) then Exit;
  Inc(P, 2);
  { 空の行までが見出し }
  while True do
  begin
    Q := PosEx(#13#10, S, P);
    if Q = 0 then Exit;                     { 空の行がない }
    if Q = P then Break;                    { 空の行 }
    AHead.Add(Copy(S, P, Q - P));
    P := Q + 2;
  end;
  ABody := Copy(S, P + 2, MaxInt);
  Result := True;
end;

{ 受け取るエディタを見分ける名前（フォームの Name.エディタの Name） }
function TCMonacoEditor.TearOffName: string;
begin
  if Owner <> nil then Result := Owner.Name + '.' + Name else Result := Name;
end;

{ タブがウィンドウの外へ落とされた（binder がドラッグの処理のあとで呼ぶ）。
  TearOff の初めの値を決めて OnTabDragOut を呼び、True のままなら分離する }
procedure TCMonacoEditor.BinderTabDragOut(Sender: TObject; Index, X, Y: Integer);
var
  TearOff: Boolean;
  Id: Integer;
begin
  if (Index < 0) or (Index >= FMonaco.DocumentCount) then Exit;
  Id := FMonaco.DocumentId(Index);       { イベントの中でタブが並べ替え・閉じられても、同じタブを指すように }
  TearOff := FTabTearOff;
  { 何も入っていない無題が 1 枚だけなら、分離しても意味がないので、初めの値は False }
  if (FMonaco.DocumentCount = 1) and (FMonaco.DocumentFileName[Index] = '') and
     (FMonaco.DocumentText[Index] = '') then
    TearOff := False;
  if Assigned(FOnTabDragOut) then FOnTabDragOut(Self, Index, X, Y, TearOff);
  if not TearOff then Exit;
  Index := FMonaco.IndexOfId(Id);
  if Index < 0 then Exit;                { イベントの中で閉じられた }
  SendTearOff(Index, X, Y);
end;

{ ---------- 【2.21】タブの結合（設計書 4.11.6） ---------- }

const
  CM_HWND_MESSAGE = HWND(-3);                       { メッセージ専用のウィンドウの親 }
  CM_GA_ROOT = 2;                                   { GetAncestor：一番外（トップレベル）のウィンドウ }
  CM_PROCESS_QUERY_LIMITED_INFORMATION = $1000;
  CM_SMTO_ABORTIFHUNG = $0002;
  CM_MERGE_MAGIC = $434D544F;                       { WM_COPYDATA の dwData（'CMTO'） }
  CM_MERGE_TIMEOUT = 3000;                          { 返事を待つ時間（ミリ秒） }
  ReceiverClassName = 'CMTearOffReceiver';

{ FPC の Windows ユニットで、版によって宣言が無い・引数の形が違うものは、ここで宣言する }
function CMGetAncestor(AWnd: HWND; AFlags: UINT): HWND; stdcall;
  external 'user32.dll' name 'GetAncestor';
function CMFindWindowExW(AParent, AChildAfter: HWND; AClass, AWindow: PWideChar): HWND; stdcall;
  external 'user32.dll' name 'FindWindowExW';
function CMSendMessageTimeoutW(AWnd: HWND; AMsg: UINT; AWParam: WPARAM; ALParam: LPARAM;
  AFlags, ATimeout: UINT; AResult: PPtrUInt): LRESULT; stdcall;
  external 'user32.dll' name 'SendMessageTimeoutW';
function CMAllowSetForegroundWindow(AProcessId: DWORD): BOOL; stdcall;
  external 'user32.dll' name 'AllowSetForegroundWindow';
function CMQueryFullProcessImageNameW(AProcess: THandle; AFlags: DWORD; AExeName: PWideChar;
  var ASize: DWORD): BOOL; stdcall; external 'kernel32.dll' name 'QueryFullProcessImageNameW';

{ プロセスの EXE のフルパス。取れなければ '' }
function ProcessExePath(APid: DWORD): string;
var
  H: THandle;
  Buf: array[0..32767] of WideChar;
  N: DWORD;
begin
  Result := '';
  H := Windows.OpenProcess(CM_PROCESS_QUERY_LIMITED_INFORMATION, False, APid);
  if H = 0 then Exit;
  try
    N := Length(Buf);
    if CMQueryFullProcessImageNameW(H, 0, @Buf[0], N) then
      Result := UTF8Encode(UnicodeString(PWideChar(@Buf[0])));
  finally
    Windows.CloseHandle(H);
  end;
end;

{ 画面の位置 (X, Y) の下が「同じ EXE の別のウィンドウ」なら、そのプロセスの受け口を返す。違えば 0。
  APid には、そのプロセスの ID を入れる }
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
  Root := CMGetAncestor(W, CM_GA_ROOT);
  if Root = 0 then Root := W;
  Windows.GetWindowThreadProcessId(Root, @APid);
  if (APid = 0) or (APid = Windows.GetCurrentProcessId) then Exit;
  { 同じ EXE か（フルパスを、大文字小文字を区別せずに比べる） }
  MyPath := ProcessExePath(Windows.GetCurrentProcessId);
  Path := ProcessExePath(APid);
  if (MyPath = '') or (Path = '') or not SameText(MyPath, Path) then Exit;
  { そのプロセスの受け口を探す（メッセージ専用のウィンドウを、クラス名で順に） }
  W := 0;
  repeat
    W := CMFindWindowExW(CM_HWND_MESSAGE, W, PWideChar(UnicodeString(ReceiverClassName)), nil);
    if W = 0 then Break;
    Pid := 0;
    Windows.GetWindowThreadProcessId(W, @Pid);
    if Pid = APid then Exit(W);
  until False;
end;

{ 受け口のウィンドウ手続き。WM_COPYDATA（dwData = 'CMTO'）で「一時ファイル #10 X #10 Y」を受ける。
  返事：1＝受け取った（あとでタブを作る） 2＝同じファイルを開いている（そのタブに切り替えた） 0＝受け取らない。
  送る側が返事を待っているので、ここではダイアログを出さず、待たず、タブも作らない（AsyncMerge で後から作る） }
function ReceiverWndProc(AWnd: HWND; AMsg: UINT; AWParam: WPARAM; ALParam: LPARAM): LRESULT; stdcall;
var
  CDS: PCopyDataStruct;
  U: UnicodeString;
  Parts: TStringList;
  Head: TStringList;
  Body, FN, FileN: string;
  X, Y, I, Idx: Integer;
  E, Target: TCMonacoEditor;
  P: TPoint;
  Root: HWND;
begin
  if AMsg <> WM_COPYDATA then Exit(Windows.DefWindowProcW(AWnd, AMsg, AWParam, ALParam));
  Result := 0;
  CDS := PCopyDataStruct(ALParam);
  if (CDS = nil) or (CDS^.dwData <> CM_MERGE_MAGIC) or (CDS^.lpData = nil) then Exit;
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

      { 受けるエディタ：見えていて、(X, Y) がその範囲の中にあり、ほかのウィンドウに隠れていないもの }
      Target := nil;
      Root := CMGetAncestor(Windows.WindowFromPoint(Point(X, Y)), CM_GA_ROOT);
      for I := 0 to GEditors.Count - 1 do
      begin
        E := TCMonacoEditor(GEditors[I]);
        if (csDestroying in E.ComponentState) or not E.Showing or not E.HandleAllocated then Continue;
        P := E.ScreenToClient(Point(X, Y));
        if not PtInRect(E.ClientRect, P) then Continue;
        if CMGetAncestor(E.Handle, CM_GA_ROOT) <> Root then Continue;
        Target := E;
        Break;
      end;
      if Target = nil then Exit;                                   { エディタの上ではない }
      if not Target.FTabTearOff or not Target.FMultiDocument then Exit;

      { 同じファイルを開いていれば、結合しない。そのタブに切り替え、ウィンドウを前に出す }
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

      { 受け取る。タブは返事のあとで作る }
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

{ 受け口を作る（プロセスに 1 つ。設計時は作らない。CreateWnd の実行時の分岐からだけ呼ぶ） }
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
  GReceiverWnd := Windows.CreateWindowExW(0, PWideChar(UnicodeString(ReceiverClassName)), nil, 0,
    0, 0, 0, 0, CM_HWND_MESSAGE, 0, System.HInstance, nil);
end;

{ 一時ファイル（4.11.4 の形）を書く。書けなければ OnError で知らせて False }
function TCMonacoEditor.MakeTearOffFile(AIndex, X, Y: Integer; out AFile: string): Boolean;
var
  Head: TStringList;
begin
  Result := False;
  AFile := GetTempFileName(GetTempDir, 'cmt');
  Head := TStringList.Create;
  try
    Head.Add('Editor=' + TearOffName);
    Head.Add('FileName=' + FMonaco.DocumentFileName[AIndex]);
    Head.Add('Encoding=' + IntToStr(Ord(FMonaco.DocumentEncoding[AIndex])));
    Head.Add('Language=' + FMonaco.DocumentLanguage[AIndex]);
    Head.Add('Modified=' + IntToStr(Ord(FMonaco.DocumentModified[AIndex])));
    Head.Add('X=' + IntToStr(X));
    Head.Add('Y=' + IntToStr(Y));
    try
      WriteTearOffFile(AFile, Head, FMonaco.DocumentText[AIndex]);   { 本文は写し（入力の直後は約 0.1 秒古いことがある） }
      Result := True;
    except
      on E: Exception do
      begin
        DeleteFile(AFile);
        DoError('別のウィンドウで開けませんでした: ' + E.Message);
      end;
    end;
  finally
    Head.Free;
  end;
end;

{ 結合を試す。落とした先が同じ EXE の別のウィンドウで、受け口があれば送って True（結果に関わらず、分離はしない）。
  同じ EXE でない・受け口が無ければ False（分離へ進む） }
function TCMonacoEditor.TryMerge(AIndex, X, Y: Integer): Boolean;
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
  if not MakeTearOffFile(AIndex, X, Y, FN) then Exit;
  U := UTF8Decode(FN + #10 + IntToStr(X) + #10 + IntToStr(Y));
  FillChar(CDS, SizeOf(CDS), 0);
  CDS.dwData := CM_MERGE_MAGIC;
  CDS.cbData := (Length(U) + 1) * SizeOf(WideChar);
  CDS.lpData := PWideChar(U);
  CMAllowSetForegroundWindow(Pid);       { 相手がウィンドウを前に出せるように }
  Res := 0;
  if CMSendMessageTimeoutW(Recv, WM_COPYDATA, 0, LPARAM(@CDS), CM_SMTO_ABORTIFHUNG,
       CM_MERGE_TIMEOUT, @Res) = 0 then
  begin
    { 送れない（相手が管理者として動いている）・3 秒で返事が無い：元のタブは残す }
    DeleteFile(FN);
    DoError('ほかのウィンドウへ移せませんでした');
    Exit;
  end;
  case Res of
    1: PageClose(AIndex, True);          { 相手が受け取った（一時ファイルは相手が消す） }
  else
    DeleteFile(FN);                      { 2＝相手は同じファイルを開いている／0＝受け取らない：元のタブは残す }
  end;
end;

{ 結合で受け取った一時ファイルから、新しいタブを作る（受け口の返事のあとで呼ばれる） }
procedure TCMonacoEditor.AsyncMerge(Data: PtrInt);
var
  FN, FileN, Body: string;
  Head: TStringList;
  I, N: Integer;
  Pg: TCMPage;
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
        { ファイルがある：新しいタブで開く。保存していない編集があったなら、その本文に置き換える（' *' が付く） }
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
        { 無題、ファイルが消えている、開けなかった：新しい無題のタブに本文を入れる }
        I := NewPage;
        if I < 0 then Continue;
        GetPage(I).Text := Body;
      end;
      Pg := GetPage(I);
      N := StrToIntDef(Head.Values['Encoding'], Ord(ceUTF8));
      if (N >= Ord(Low(TCMEncoding))) and (N <= Ord(High(TCMEncoding))) then
        Pg.Encoding := TCMEncoding(N);
      if Head.Values['Language'] <> '' then Pg.Language := Head.Values['Language'];
      if I <> FMonaco.ActiveIndex then FMonaco.ActiveIndex := I;
      DeleteFile(FN);                    { 読み終わってから消す }
    end;
  finally
    Head.Free;
  end;
  AsyncBringFront(0);
end;

{ このエディタのフォームを前に出す }
procedure TCMonacoEditor.AsyncBringFront(Data: PtrInt);
var
  F: TCustomForm;
begin
  F := GetParentForm(Self);
  if F = nil then Exit;
  if F.WindowState = wsMinimized then F.WindowState := wsNormal;
  F.BringToFront;
  if F.HandleAllocated then Windows.SetForegroundWindow(F.Handle);
end;

{ 送る：一時ファイルを書き、自分の EXE を CM_TEAROFF=一時ファイル の環境で起動し、元のタブを閉じる。
  起動に失敗したら、一時ファイルを消し、タブは残して OnError で知らせる }
function TCMonacoEditor.SendTearOff(AIndex, X, Y: Integer): Boolean;
var
  FN: string;
  EnvBlock, Cmd, Exe: UnicodeString;
  P, Env: PWideChar;
  Entry: UnicodeString;
  SI: Windows.TStartupInfoW;      { ShellApi にも同じ名前があるので、Windows のものを使う }
  ProcInfo: TProcessInformation;
  Ok: Boolean;
  Err: DWORD;
begin
  Result := False;
  { 【2.21】落とした先が同じ EXE の別のウィンドウで、受け口があれば結合する（ここで終わり） }
  if TryMerge(AIndex, X, Y) then Exit(True);
  { 1. 一時ファイルを書く }
  if not MakeTearOffFile(AIndex, X, Y, FN) then Exit;

  { 2. 環境変数の写しを作る：今の環境変数すべて（CM_TEAROFF は除く）＋ CM_TEAROFF=一時ファイル。
       起動する新しい EXE にだけ渡る（レジストリにも書かず、ほかには影響しない） }
  EnvBlock := '';
  Env := Windows.GetEnvironmentStringsW;
  if Env <> nil then
  try
    P := Env;
    while P^ <> #0 do
    begin
      Entry := P;
      { CM_TEAROFF= で始まるものは除く（名前は英字なので、英字の大文字小文字だけ区別しない） }
      if not SameText(UTF8Encode(System.Copy(Entry, 1, Length(TearOffEnv) + 1)), TearOffEnv + '=') then
        EnvBlock := EnvBlock + Entry + #0;
      Inc(P, Length(Entry) + 1);
    end;
  finally
    Windows.FreeEnvironmentStringsW(Env);
  end;
  EnvBlock := EnvBlock + UnicodeString(TearOffEnv) + '=' + UTF8Decode(FN) + #0 + #0;

  { 3. 自分の EXE を起動する（起動パラメータは付けない。終わるのは待たない） }
  Exe := UTF8Decode(Application.ExeName);
  Cmd := '"' + Exe + '"';
  UniqueString(Cmd);                      { CreateProcessW は、コマンドラインを書き換えることがある }
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  FillChar(ProcInfo, SizeOf(ProcInfo), 0);
  Ok := Windows.CreateProcessW(PWideChar(Exe), PWideChar(Cmd), nil, nil, False,
    CM_CREATE_UNICODE_ENVIRONMENT, PWideChar(EnvBlock), nil, SI, ProcInfo);
  if not Ok then
  begin
    Err := Windows.GetLastError;
    DeleteFile(FN);
    DoError('別のウィンドウで開けませんでした: ' + SysErrorMessage(Err));
    Exit;                                 { タブは閉じずに残す }
  end;
  Windows.CloseHandle(ProcInfo.hThread);
  Windows.CloseHandle(ProcInfo.hProcess);

  { 4. 起動できたら、聞かずに閉じる（本文は一時ファイルに残っている）。最後の 1 枚なら空の無題が残る }
  PageClose(AIndex, True);
  Result := True;
end;

{ 受ける：分離で起動され、一時ファイルの Editor が自分の名前と同じなら受け取る（1 回だけ）。
  受け取ったら一時ファイルの中身を覚えて True。タブは準備ができてから作る（ApplyTearOff） }
function TCMonacoEditor.TryClaimTearOff: Boolean;
var
  FN: string;
begin
  Result := False;
  if FTearOffPending then Exit(True);
  if not FTabTearOff or GTearOffClaimed then Exit;
  if (csDesigning in ComponentState) or CMIsDesigning(Self) then Exit;
  FN := TearOffFile;
  if (FN = '') or not FileExists(FN) then Exit;
  if not ReadTearOffFile(FN, FTearOffHead, FTearOffBody) then Exit;   { 形が違う：普通の起動（ファイルは消さない） }
  if FTearOffHead.Values['Editor'] <> TearOffName then
  begin
    FTearOffHead.Clear;
    FTearOffBody := '';
    Exit;                                 { 名前が違う：ほかのエディタが受ける }
  end;
  GTearOffClaimed := True;
  FTearOffPending := True;
  Result := True;
end;

{ 受け取ったエディタのフォームを、タブを落とした位置に出す。画面からはみ出すなら、作業領域に収まるように寄せる }
procedure TCMonacoEditor.MoveFormToTearOff;
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
  F.Position := poDesigned;               { 表示するときに中央などへ動かされないように }
  F.Left := X;
  F.Top := Y;
end;

{ 受け取った一時ファイルから、0 番（起動直後の無題）にタブを作る。そのあと一時ファイルを消す }
procedure TCMonacoEditor.ApplyTearOff;
var
  FN, FileN: string;
  Pg: TCMPage;
  N: Integer;
begin
  FTearOffPending := False;
  if FMonaco.DocumentCount = 0 then Exit;
  Pg := GetPage(0);
  FileN := FTearOffHead.Values['FileName'];
  if (FileN <> '') and FileExists(FileN) then
  begin
    { ファイルがある：読み込む。保存していない編集があったなら、その本文に置き換える（' *' が付く） }
    if PageLoad(0, FileN) then
    begin
      if FTearOffHead.Values['Modified'] = '1' then Pg.Text := FTearOffBody;
    end
    else
      Pg.Text := FTearOffBody;            { 読めなかった：無題のまま本文を入れる }
  end
  else
    Pg.Text := FTearOffBody;              { 無題、またはファイルが消えている：無題のまま本文を入れる }
  N := StrToIntDef(FTearOffHead.Values['Encoding'], Ord(ceUTF8));
  if (N >= Ord(Low(TCMEncoding))) and (N <= Ord(High(TCMEncoding))) then
    Pg.Encoding := TCMEncoding(N);
  if FTearOffHead.Values['Language'] <> '' then Pg.Language := FTearOffHead.Values['Language'];
  FN := TearOffFile;
  if FN <> '' then DeleteFile(FN);        { 読み終わってから消す }
  FTearOffHead.Clear;
  FTearOffBody := '';
end;

procedure TCMonacoEditor.MonacoFileDrop(Sender: TObject; Files: TStrings; var Handled: Boolean);
var
  I: Integer;
begin
  if Assigned(FOnFileDrop) then FOnFileDrop(Self, Files, Handled);
  if Handled or FMultiDocument then Exit;       { タブありなら、中の部品が新しいタブで開く }
  Handled := True;
  if not FMonaco.OpenDroppedFiles then Exit;
  for I := 0 to Files.Count - 1 do               { 1ファイルのみ：最初のファイルで置き換える }
    if FileExists(Files[I]) then
    begin
      try
        OpenFile(Files[I]);
      except
        on E: Exception do DoError(Files[I] + ': ' + E.Message);
      end;
      Exit;
    end;
end;

procedure TCMonacoEditor.PreviewOpenMarkdown(Sender: TObject; const AFileName: string);
begin
  if Assigned(FOnOpenMarkdown) then
    FOnOpenMarkdown(Self, AFileName)
  else
    try
      OpenFile(AFileName);
    except
      on E: Exception do DoError(AFileName + ': ' + E.Message);
    end;
end;

{ ---------- プレビュー ---------- }

procedure TCMonacoEditor.UpdatePreview;
var
  V: Boolean;
begin
  if FDesignMode or (csDesigning in ComponentState) then Exit;
  { 【段階5】Markdown 以外のタブでも出す（色分けしたコード） }
  V := FShowPreview and (FMonaco.DocumentCount > 0) and (FMonaco.ActiveIndex >= 0);
  if V = FPreview.Visible then Exit;
  DisableAlign;
  try
    if V then
    begin
      { 右端にプレビュー、その左にスプリッター、の順になるよう Left を決めてから表示する }
      FPreview.Width := FPreviewWidth;
      FPreview.Left := Width + 100;
      FSplitter.Left := Width + 50;
      FPreview.Visible := True;
      FSplitter.Visible := True;
    end
    else
    begin
      FSplitter.Visible := False;
      FPreview.Visible := False;
    end;
  finally
    EnableAlign;
  end;
end;

procedure TCMonacoEditor.SplitterMoved(Sender: TObject);
begin
  FPreviewWidth := FPreview.Width;
end;

procedure TCMonacoEditor.MonacoTogglePreview(Sender: TObject);
begin
  FPrintTempPreview := False;              { 人が切り替えたら、印刷後に自動で隠さない }
  ShowPreview := not ShowPreview;          { 【段階5】どの言語のタブでも切り替える }
end;

function TCMonacoEditor.CanPrint: Boolean;
begin
  { 【段階5】ページがあれば印刷できる（プレビューの表示・非表示、言語に関係しない） }
  Result := (FMonaco.DocumentCount > 0) and (FMonaco.ActiveIndex >= 0);
end;

procedure TCMonacoEditor.Print;
begin
  if not CanPrint then
  begin
    DoError('印刷するページがありません');
    Exit;
  end;
  { 【段階5】プレビューを出していなければ、印刷の間だけ表示する（印刷ダイアログが閉じたら隠す） }
  if not FShowPreview then
  begin
    ShowPreview := True;
    FPrintTempPreview := True;
  end;
  FPreviewBinder.Refresh;                  { 最新の内容にしてから印刷する }
  FPreview.Print;                          { 準備ができたら印刷ダイアログを出す }
end;

procedure TCMonacoEditor.AsyncPrint(Data: PtrInt);
begin
  Print;
end;

procedure TCMonacoEditor.PreviewPrintKey(Sender: TObject);
begin
  Application.QueueAsyncCall(@AsyncPrint, 0);
end;

procedure TCMonacoEditor.PreviewAfterPrint(Sender: TObject);
begin
  if FPrintTempPreview then
  begin
    FPrintTempPreview := False;
    ShowPreview := False;
  end;
end;

{ ---------- 検索・置換 ---------- }

function TCMonacoEditor.CurrentFindDialog(ACreate: Boolean): TCMFindDialog;
begin
  if FFindDialog <> nil then Exit(FFindDialog);
  if FHook <> nil then
  begin
    if ACreate then Exit(FHook.SharedFindDialog);
    Exit(FHook.FFindDialog);
  end;
  if (FPrivateFindDlg = nil) and ACreate then
    FPrivateFindDlg := TCMFindDialog.Create(Self);
  Result := FPrivateFindDlg;
end;

procedure TCMonacoEditor.ShowFindDialog(const InitialText: string);
begin
  CurrentFindDialog(True).ShowFor(FMonaco, InitialText);
end;

procedure TCMonacoEditor.MonacoFindRequest(Sender: TObject; const InitialText: string);
begin
  ShowFindDialog(InitialText);
end;

procedure TCMonacoEditor.MonacoFindDone(Sender: TObject; Found: Boolean);
var
  D: TCMFindDialog;
begin
  D := CurrentFindDialog(False);
  if D <> nil then D.NotifyFindDone(FMonaco, Found);
  if Assigned(FOnFindDone) then FOnFindDone(Self, Found);
end;

procedure TCMonacoEditor.MonacoReplaceAllDone(Sender: TObject; Count: Integer);
var
  D: TCMFindDialog;
begin
  D := CurrentFindDialog(False);
  if D <> nil then D.NotifyReplaceAllDone(FMonaco, Count);
  if Assigned(FOnReplaceAllDone) then FOnReplaceAllDone(Self, Count);
end;

procedure TCMonacoEditor.MonacoGotFocus(Sender: TObject);
var
  D: TCMFindDialog;
begin
  if FHook <> nil then FHook.SetActive(Self);
  D := CurrentFindDialog(False);
  if D = nil then Exit;
  { 検索語は全エディタで共通。F5 / Shift+F5 でも、ダイアログの検索語を使う }
  if D.SearchText <> '' then
  begin
    FMonaco.SearchText := D.SearchText;
    FMonaco.SearchOptions := D.Options;
  end;
  if D.IsShowing then D.Target := FMonaco;   { 開いたまま別のエディタをクリックしたら、対象を切り替える }
end;

procedure TCMonacoEditor.Find(const S: string; AOptions: TCMFindOptions; AForward: Boolean);
begin
  FMonaco.Find(S, AOptions, AForward);
end;

procedure TCMonacoEditor.FindNext;
begin
  FMonaco.FindNext;
end;

procedure TCMonacoEditor.FindPrev;
begin
  FMonaco.FindPrev;
end;

procedure TCMonacoEditor.Replace(const S, R: string; AOptions: TCMFindOptions);
begin
  FMonaco.Replace(S, R, AOptions);
end;

procedure TCMonacoEditor.ReplaceAll(const S, R: string; AOptions: TCMFindOptions);
begin
  FMonaco.ReplaceAll(S, R, AOptions);
end;

{ ---------- キー ---------- }

procedure TCMonacoEditor.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);     { OnKeyDown を呼ぶ }
end;

function TCMonacoEditor.IsBuiltinKey(Key: Word; Shift: TShiftState): Boolean;
var
  M: TShiftState;
begin
  { 内蔵のショートカットと、編集の基本操作。これらはフォームのショートカットより優先する }
  M := Shift * [ssShift, ssCtrl, ssAlt];
  Result := False;
  if M = [ssCtrl] then
    case Key of
      VK_S, VK_F, VK_H, VK_A, VK_Z, VK_Y, VK_X, VK_C, VK_V, VK_P: Result := True;   { VK_P は【2.8】 }
    end
  else if M = [ssCtrl, ssShift] then
    case Key of
      VK_V, VK_Z: Result := True;
    end
  else if M = [ssShift] then
    case Key of
      VK_F5, VK_F10: Result := True;
    end
  else if M = [] then
    case Key of
      VK_F5, VK_F11, VK_F12, VK_INSERT: Result := True;
    end;
end;

function TCMonacoEditor.FindFormShortcut(Key: Word; Shift: TShiftState): TComponent;
var
  F: TCustomForm;
  SC: TShortCut;
  I, J: Integer;
  AL: TCustomActionList;
begin
  Result := nil;
  F := GetParentForm(Self);
  if F = nil then Exit;
  SC := ShortCut(Key, Shift);
  { メニュー }
  if (F is TForm) and (TForm(F).Menu <> nil) then
  begin
    Result := TForm(F).Menu.FindItem(SC, fkShortCut);
    if Result <> nil then Exit;
  end;
  { ActionList }
  for I := 0 to F.ComponentCount - 1 do
    if F.Components[I] is TCustomActionList then
    begin
      AL := TCustomActionList(F.Components[I]);
      for J := 0 to AL.ActionCount - 1 do
        if (AL.Actions[J] is TCustomAction) and (TCustomAction(AL.Actions[J]).ShortCut = SC) then
          Exit(AL.Actions[J]);
    end;
end;

procedure TCMonacoEditor.AsyncRunShortcut(Data: PtrInt);
var
  C: TComponent;
begin
  { WebView2 のキー通知の途中ではなく、あとで実行する（ダイアログを出すアクションがあるため） }
  C := FPendingShortcut;
  FPendingShortcut := nil;
  if C is TMenuItem then
  begin
    if TMenuItem(C).Enabled then TMenuItem(C).Click;
  end
  else if C is TCustomAction then
  begin
    TCustomAction(C).Update;
    if TCustomAction(C).Enabled then TCustomAction(C).Execute;
  end;
end;

procedure TCMonacoEditor.MonacoAccelKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  { 1. KeyDown（継承した部品の override）→ 2. inherited の中で OnKeyDown }
  KeyDown(Key, Shift);
  if Key = 0 then Exit;                         { Monaco には渡さない }
  { 【2.8】内蔵：Ctrl+P で印刷（Print と同じ）。フォームのショートカットより優先する。
    WebView2 の印刷（エディタの画面がそのまま印刷される）は動かさない }
  if (Key = VK_P) and (Shift * [ssCtrl, ssShift, ssAlt] = [ssCtrl]) then
  begin
    Application.QueueAsyncCall(@AsyncPrint, 0);
    Key := 0;
    Exit;
  end;
  { 内蔵：Ctrl+Shift+M でミニマップを切り替える }
  if (Key = VK_M) and (Shift * [ssCtrl, ssShift, ssAlt] = [ssCtrl, ssShift]) then
  begin
    Minimap := not Minimap;
    Key := 0;
    Exit;
  end;
  { 内蔵：Ctrl+Tab / Ctrl+Shift+Tab でタブを切り替える（MultiDocument = False のときは何もしない）。
    フォーカスはエディタに残ったままなので、マウスに触らずにそのまま編集できる }
  if (Key = VK_TAB) and (Shift * [ssCtrl, ssAlt] = [ssCtrl]) then
  begin
    if FMultiDocument and (FMonaco.DocumentCount > 1) then
    begin
      if ssShift in Shift then
        FMonaco.ActiveIndex := (FMonaco.ActiveIndex - 1 + FMonaco.DocumentCount) mod FMonaco.DocumentCount
      else
        FMonaco.ActiveIndex := (FMonaco.ActiveIndex + 1) mod FMonaco.DocumentCount;
    end;
    Key := 0;
    Exit;
  end;
  { 3. 内蔵のショートカットなら、そのまま Monaco へ }
  if IsBuiltinKey(Key, Shift) then Exit;
  { 4. フォームのメニュー・ActionList のショートカット。実行したら Monaco には渡さない }
  FPendingShortcut := FindFormShortcut(Key, Shift);
  if FPendingShortcut <> nil then
  begin
    Application.QueueAsyncCall(@AsyncRunShortcut, 0);
    Key := 0;
    Exit;
  end;
  { 【段階5】Ctrl+Shift+P は止める（WebView2 の「システムのダイアログで印刷」で、エディタの画面が印刷されるのを防ぐ） }
  if (Key = VK_P) and (Shift * [ssCtrl, ssShift, ssAlt] = [ssCtrl, ssShift]) then
  begin
    Key := 0;
    Exit;
  end;
  { 5. どれにも該当しなければ、そのまま Monaco へ }
end;

{ ---------- 中の部品からの通知の中継 ---------- }

procedure TCMonacoEditor.MonacoReady(Sender: TObject);
begin
  { 【2.20】コードで作ったエディタは Loaded が呼ばれないので、ここで受け取る（フォームは表示の後で動く） }
  if not FTearOffPending and TryClaimTearOff then MoveFormToTearOff;
  { 【2.20】受け取っていれば、利用者の OnReady の前にタブを作る }
  if FTearOffPending then ApplyTearOff;
  if Assigned(FOnReady) then FOnReady(Self);
end;

procedure TCMonacoEditor.MonacoChange(Sender: TObject);
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TCMonacoEditor.MonacoCursorChange(Sender: TObject; Line, Column: Integer);
begin
  if Assigned(FOnCursorChange) then FOnCursorChange(Self, Line, Column);
end;

procedure TCMonacoEditor.MonacoModeChange(Sender: TObject; IsOverwrite: Boolean);
begin
  if Assigned(FOnModeChange) then FOnModeChange(Self, IsOverwrite);
end;

procedure TCMonacoEditor.MonacoSave(Sender: TObject; const AFileName: string);
begin
  if AFileName <> '' then FLastDir := ExtractFilePath(AFileName);
  if Assigned(FOnSave) then FOnSave(Self, AFileName);
end;

procedure TCMonacoEditor.MonacoModifiedChange(Sender: TObject);
begin
  if Assigned(FOnModifiedChange) then FOnModifiedChange(Self);
end;

procedure TCMonacoEditor.MonacoActiveChange(Sender: TObject);
var
  D: TCMFindDialog;
begin
  UpdatePreview;
  D := CurrentFindDialog(False);
  if (D <> nil) and (D.Target = FMonaco) then D.UpdateCaption;
  if Assigned(FOnActiveChange) then FOnActiveChange(Self);
end;

procedure TCMonacoEditor.MonacoDocListChange(Sender: TObject);
begin
  UpdatePreview;
  if Assigned(FOnDocListChange) then FOnDocListChange(Self);
end;

procedure TCMonacoEditor.MonacoDocumentChange(Sender: TObject; Index: Integer);
var
  D: TCMFindDialog;
begin
  if Index = FMonaco.ActiveIndex then
  begin
    UpdatePreview;                               { 言語が markdown に変わった場合など }
    D := CurrentFindDialog(False);
    if (D <> nil) and (D.Target = FMonaco) then D.UpdateCaption;
  end;
  if Assigned(FOnDocumentChange) then FOnDocumentChange(Self, Index);
end;

procedure TCMonacoEditor.MonacoToggleMaximize(Sender: TObject);
begin
  if Assigned(FOnToggleMaximize) then FOnToggleMaximize(Self);
end;

procedure TCMonacoEditor.MonacoFontSizeChange(Sender: TObject);
begin
  if Assigned(FOnFontSizeChange) then FOnFontSizeChange(Self);
end;

procedure TCMonacoEditor.MonacoLineNumbersChange(Sender: TObject);
begin
  if Assigned(FOnLineNumbersChange) then FOnLineNumbersChange(Self);
end;

procedure TCMonacoEditor.MonacoPopup(Sender: TObject);
begin
  { チェックは、メニューを開くたびに今の値で付ける（キーで切り替えた場合も一致する） }
  if FMnuMinimap <> nil then FMnuMinimap.Checked := FMonaco.Minimap;
  if FMnuPreview <> nil then
  begin
    FMnuPreview.Checked := FShowPreview;
    FMnuPreview.Enabled := True;               { 【段階5】どの言語のタブでも使える }
  end;
  if Assigned(FOnPopup) then FOnPopup(Self);
end;

{ ---------- 右クリックメニュー：表示の切り替え ---------- }

procedure TCMonacoEditor.AddViewMenuItems;
var
  PM: TPopupMenu;
  MI: TMenuItem;
begin
  PM := FMonaco.PopupMenu;
  if PM = nil then Exit;
  { TCMMenuItem ではなく TMenuItem にする（選択の有無による表示切り替えの対象外＝常に表示） }
  MI := TMenuItem.Create(PM);
  MI.Caption := '-';
  PM.Items.Add(MI);

  FMnuMinimap := TMenuItem.Create(PM);
  FMnuMinimap.Caption := 'ミニマップ';
  FMnuMinimap.ShortCut := ShortCut(VK_M, [ssCtrl, ssShift]);   { 表示用。キーの処理は MonacoAccelKeyDown }
  FMnuMinimap.OnClick := @MenuMinimapClick;
  PM.Items.Add(FMnuMinimap);

  FMnuPreview := TMenuItem.Create(PM);
  FMnuPreview.Caption := 'プレビュー';
  FMnuPreview.ShortCut := ShortCut(VK_V, [ssCtrl, ssShift]);   { 表示用。キーの処理は editor.html }
  FMnuPreview.OnClick := @MenuPreviewClick;
  PM.Items.Add(FMnuPreview);
end;

procedure TCMonacoEditor.MenuMinimapClick(Sender: TObject);
begin
  Minimap := not Minimap;
end;

procedure TCMonacoEditor.MenuPreviewClick(Sender: TObject);
begin
  FPrintTempPreview := False;
  ShowPreview := not ShowPreview;          { Ctrl+Shift+V と同じ（【段階5】どの言語のタブでも） }
end;

{ ---------- プロパティ：全体 ---------- }

procedure TCMonacoEditor.SetMultiDocument(AValue: Boolean);
begin
  { 設計時（と、コードで生成した直後）のみ変更できる。実行時の変更は無視する }
  if (csLoading in ComponentState) or (csDesigning in ComponentState) or not HandleAllocated then
    FMultiDocument := AValue;
end;

procedure TCMonacoEditor.SetShowPreview(AValue: Boolean);
begin
  FShowPreview := AValue;
  if not (csLoading in ComponentState) then UpdatePreview;
end;

procedure TCMonacoEditor.SetPreviewWidth(AValue: Integer);
begin
  if AValue < 50 then AValue := 50;
  FPreviewWidth := AValue;
  if FPreview.Visible then FPreview.Width := AValue;
end;

procedure TCMonacoEditor.SetOpenDialog(AValue: TOpenDialog);
begin
  if FOpenDialog = AValue then Exit;
  if FOpenDialog <> nil then FOpenDialog.RemoveFreeNotification(Self);
  FOpenDialog := AValue;
  if FOpenDialog <> nil then FOpenDialog.FreeNotification(Self);
end;

procedure TCMonacoEditor.SetSaveDialog(AValue: TSaveDialog);
begin
  if FSaveDialog = AValue then Exit;
  if FSaveDialog <> nil then FSaveDialog.RemoveFreeNotification(Self);
  FSaveDialog := AValue;
  if FSaveDialog <> nil then FSaveDialog.FreeNotification(Self);
end;

procedure TCMonacoEditor.SetFindDialog(AValue: TCMFindDialog);
begin
  if FFindDialog = AValue then Exit;
  if FFindDialog <> nil then FFindDialog.RemoveFreeNotification(Self);
  FFindDialog := AValue;
  if FFindDialog <> nil then FFindDialog.FreeNotification(Self);
end;

function TCMonacoEditor.GetSplitterResizeStyle: TResizeStyle;
begin
  Result := FSplitter.ResizeStyle;
end;

procedure TCMonacoEditor.SetSplitterResizeStyle(AValue: TResizeStyle);
begin
  FSplitter.ResizeStyle := AValue;
end;

function TCMonacoEditor.GetSplitterWidth: Integer;
begin
  Result := FSplitter.Width;
end;

procedure TCMonacoEditor.SetSplitterWidth(AValue: Integer);
begin
  if AValue < 1 then AValue := 1;
  FSplitter.Width := AValue;
end;

{ ---------- プロパティ：エディタ（中継） ---------- }

function TCMonacoEditor.GetWordWrap: Boolean; begin Result := FMonaco.WordWrap; end;
procedure TCMonacoEditor.SetWordWrap(AValue: Boolean); begin FMonaco.WordWrap := AValue; end;
function TCMonacoEditor.GetLineNumbers: Boolean; begin Result := FMonaco.LineNumbers; end;
procedure TCMonacoEditor.SetLineNumbers(AValue: Boolean); begin FMonaco.LineNumbers := AValue; end;
function TCMonacoEditor.GetFontSize: Integer; begin Result := FMonaco.FontSize; end;
procedure TCMonacoEditor.SetFontSize(AValue: Integer); begin FMonaco.FontSize := AValue; end;
function TCMonacoEditor.GetTabSize: Integer; begin Result := FMonaco.TabSize; end;
procedure TCMonacoEditor.SetTabSize(AValue: Integer); begin FMonaco.TabSize := AValue; end;

{ 【2.15】Theme は列挙型。中の部品へは 'auto'・'vs'・'vs-dark' で渡す }
function TCMonacoEditor.GetTheme: TCMTheme; begin Result := FTheme; end;

procedure TCMonacoEditor.SetTheme(AValue: TCMTheme);
begin
  FTheme := AValue;
  FMonaco.Theme := ThemeNames[AValue];   { プレビューは、Binder がエディタに合わせる }
  FPreviewBinder.Refresh;
  ApplyThemeColors;
end;

function TCMonacoEditor.GetReadOnly: Boolean; begin Result := FMonaco.ReadOnly; end;
procedure TCMonacoEditor.SetReadOnly(AValue: Boolean); begin FMonaco.ReadOnly := AValue; end;
function TCMonacoEditor.GetJapaneseUI: Boolean; begin Result := FMonaco.JapaneseUI; end;
procedure TCMonacoEditor.SetJapaneseUI(AValue: Boolean); begin FMonaco.JapaneseUI := AValue; end;
function TCMonacoEditor.GetDefaultLanguage: string; begin Result := FMonaco.DefaultLanguage; end;
procedure TCMonacoEditor.SetDefaultLanguage(const AValue: string); begin FMonaco.DefaultLanguage := AValue; end;
function TCMonacoEditor.GetAutoLanguage: Boolean; begin Result := FMonaco.AutoLanguage; end;
procedure TCMonacoEditor.SetAutoLanguage(AValue: Boolean); begin FMonaco.AutoLanguage := AValue; end;
function TCMonacoEditor.GetOpenDroppedFiles: Boolean; begin Result := FMonaco.OpenDroppedFiles; end;
procedure TCMonacoEditor.SetOpenDroppedFiles(AValue: Boolean); begin FMonaco.OpenDroppedFiles := AValue; end;
function TCMonacoEditor.GetQuotePrefix: string; begin Result := FMonaco.QuotePrefix; end;
procedure TCMonacoEditor.SetQuotePrefix(const AValue: string); begin FMonaco.QuotePrefix := AValue; end;

{ 【2.15】エディタの色。選んだ TColor を持ち、中の部品へは '#RRGGBB' で渡す }
procedure TCMonacoEditor.SetHitColorLight(AValue: TColor);
begin
  FHitColorLight := AValue;
  FMonaco.HitColorLight := CMColorToHex(AValue, DefHitColorLight);
end;

procedure TCMonacoEditor.SetHitColorDark(AValue: TColor);
begin
  FHitColorDark := AValue;
  FMonaco.HitColorDark := CMColorToHex(AValue, DefHitColorDark);
end;

procedure TCMonacoEditor.SetCursorLineColorLight(AValue: TColor);
begin
  FCursorLineColorLight := AValue;
  FMonaco.CursorLineColorLight := CMColorToHex(AValue, DefCursorLineColorLight);
end;

procedure TCMonacoEditor.SetCursorLineColorDark(AValue: TColor);
begin
  FCursorLineColorDark := AValue;
  FMonaco.CursorLineColorDark := CMColorToHex(AValue, DefCursorLineColorDark);
end;

{ 【2.13】選択範囲の色。【2.15】TColor にした }
procedure TCMonacoEditor.SetSelectionColorStyle(AValue: TCMSelectionColorStyle);
begin
  FSelectionColorStyle := AValue;
  if AValue = scCustom then Exit;         { 色は変えない }
  FSelectionColorDark := SelStyleDark[AValue];
  FSelectionColorLight := SelStyleLight[AValue];
  FMonaco.SelectionColorDark := CMColorToHex(FSelectionColorDark, SelStyleDark[scStandard]);
  FMonaco.SelectionColorLight := CMColorToHex(FSelectionColorLight, SelStyleLight[scStandard]);
end;

procedure TCMonacoEditor.SetSelectionColorLight(AValue: TColor);
begin
  FSelectionColorLight := AValue;
  FMonaco.SelectionColorLight := CMColorToHex(AValue, SelStyleLight[scStandard]);
  if not (csLoading in ComponentState) then FSelectionColorStyle := scCustom;
end;

procedure TCMonacoEditor.SetSelectionColorDark(AValue: TColor);
begin
  FSelectionColorDark := AValue;
  FMonaco.SelectionColorDark := CMColorToHex(AValue, SelStyleDark[scStandard]);
  if not (csLoading in ComponentState) then FSelectionColorStyle := scCustom;
end;

function TCMonacoEditor.IsSelColorStored: Boolean; begin Result := FSelectionColorStyle = scCustom; end;

{ 【2.13】カーソル行 }
function TCMonacoEditor.GetLineText: string; begin Result := FMonaco.CursorLineText; end;
function TCMonacoEditor.GetLineWords: TStrings;
var
  Key: string;
begin
  Key := FLineDelimiters + #0 + BoolToStr(FLineSkipEmpty, True) + #0 + FLineQuoteChar;
  if not (FLineWordsValid and (FLineWordsSeq = FMonaco.CursorLineSeq) and (FLineWordsKey = Key)) then
  begin
    CMSplitLine(FMonaco.CursorLineText, FLineDelimiters, FLineSkipEmpty, FLineQuoteChar, FLineWords);
    FLineWordsSeq := FMonaco.CursorLineSeq;
    FLineWordsKey := Key;
    FLineWordsValid := True;
  end;
  Result := FLineWords;
end;
function TCMonacoEditor.GetMonacoPath: string; begin Result := FMonaco.ResourcePath; end;
procedure TCMonacoEditor.SetMonacoPath(const AValue: string); begin FMonaco.ResourcePath := AValue; end;
function TCMonacoEditor.GetFolding: Boolean; begin Result := FMonaco.Folding; end;
procedure TCMonacoEditor.SetFolding(AValue: Boolean); begin FMonaco.Folding := AValue; end;
function TCMonacoEditor.GetMatchBrackets: Boolean; begin Result := FMonaco.MatchBrackets; end;
procedure TCMonacoEditor.SetMatchBrackets(AValue: Boolean); begin FMonaco.MatchBrackets := AValue; end;
function TCMonacoEditor.GetOccurrencesHighlight: Boolean; begin Result := FMonaco.OccurrencesHighlight; end;
procedure TCMonacoEditor.SetOccurrencesHighlight(AValue: Boolean); begin FMonaco.OccurrencesHighlight := AValue; end;
function TCMonacoEditor.GetMinimap: Boolean; begin Result := FMonaco.Minimap; end;
procedure TCMonacoEditor.SetMinimap(AValue: Boolean); begin FMonaco.Minimap := AValue; end;

{ ---------- プロパティ：プレビュー（中継） ---------- }

function TCMonacoEditor.GetPreviewFontSize: Integer; begin Result := FPreview.FontSize; end;
procedure TCMonacoEditor.SetPreviewFontSize(AValue: Integer); begin FPreview.FontSize := AValue; end;

{ 【2.15】配色の組は列挙型。中の部品へは 'editor'・'github' で渡す }
procedure TCMonacoEditor.SetColorScheme(AValue: TCMColorScheme);
begin
  FColorScheme := AValue;
  if AValue = csGitHub then FPreview.ColorScheme := 'github' else FPreview.ColorScheme := 'editor';
end;

{ 【2.15】プレビューの色。選んだ TColor を持ち、中の部品へは '#RRGGBB' で渡す }
procedure TCMonacoEditor.SetPreviewBackColorLight(AValue: TColor);
begin
  FPreviewBackColorLight := AValue;
  FPreview.BackColorLight := CMColorToHex(AValue, DefPreviewBackColorLight);
end;

procedure TCMonacoEditor.SetPreviewBackColorDark(AValue: TColor);
begin
  FPreviewBackColorDark := AValue;
  FPreview.BackColorDark := CMColorToHex(AValue, DefPreviewBackColorDark);
end;

procedure TCMonacoEditor.SetPreviewTextColorLight(AValue: TColor);
begin
  FPreviewTextColorLight := AValue;
  FPreview.TextColorLight := CMColorToHex(AValue, DefPreviewTextColorLight);
end;

procedure TCMonacoEditor.SetPreviewTextColorDark(AValue: TColor);
begin
  FPreviewTextColorDark := AValue;
  FPreview.TextColorDark := CMColorToHex(AValue, DefPreviewTextColorDark);
end;

procedure TCMonacoEditor.SetPreviewLinkColorLight(AValue: TColor);
begin
  FPreviewLinkColorLight := AValue;
  FPreview.LinkColorLight := CMColorToHex(AValue, DefPreviewLinkColorLight);
end;

procedure TCMonacoEditor.SetPreviewLinkColorDark(AValue: TColor);
begin
  FPreviewLinkColorDark := AValue;
  FPreview.LinkColorDark := CMColorToHex(AValue, DefPreviewLinkColorDark);
end;

function TCMonacoEditor.GetBreakOnNewline: Boolean; begin Result := FPreview.BreakOnNewline; end;
procedure TCMonacoEditor.SetBreakOnNewline(AValue: Boolean); begin FPreview.BreakOnNewline := AValue; end;
function TCMonacoEditor.GetAllowRemoteImages: Boolean; begin Result := FPreview.AllowRemoteImages; end;
procedure TCMonacoEditor.SetAllowRemoteImages(AValue: Boolean); begin FPreview.AllowRemoteImages := AValue; end;
function TCMonacoEditor.GetSyncScroll: TCMSyncScroll; begin Result := FPreviewBinder.SyncScroll; end;
procedure TCMonacoEditor.SetSyncScroll(AValue: TCMSyncScroll); begin FPreviewBinder.SyncScroll := AValue; end;
function TCMonacoEditor.GetPreviewDelayMs: Integer; begin Result := FPreviewBinder.DelayMs; end;
procedure TCMonacoEditor.SetPreviewDelayMs(AValue: Integer); begin FPreviewBinder.DelayMs := AValue; end;
function TCMonacoEditor.GetPreviewPath: string; begin Result := FPreview.ResourcePath; end;
procedure TCMonacoEditor.SetPreviewPath(const AValue: string); begin FPreview.ResourcePath := AValue; end;

{ ---------- 実行時のみのプロパティ（中継） ---------- }

function TCMonacoEditor.GetDocumentCount: Integer; begin Result := FMonaco.DocumentCount; end;
function TCMonacoEditor.GetActiveIndex: Integer; begin Result := FMonaco.ActiveIndex; end;
procedure TCMonacoEditor.SetActiveIndex(AValue: Integer); begin FMonaco.ActiveIndex := AValue; end;
function TCMonacoEditor.GetSearchText: string; begin Result := FMonaco.SearchText; end;
procedure TCMonacoEditor.SetSearchText(const AValue: string); begin FMonaco.SearchText := AValue; end;
function TCMonacoEditor.GetReplaceText: string; begin Result := FMonaco.ReplaceText; end;
procedure TCMonacoEditor.SetReplaceText(const AValue: string); begin FMonaco.ReplaceText := AValue; end;
function TCMonacoEditor.GetSearchOptions: TCMFindOptions; begin Result := FMonaco.SearchOptions; end;
procedure TCMonacoEditor.SetSearchOptions(AValue: TCMFindOptions); begin FMonaco.SearchOptions := AValue; end;
function TCMonacoEditor.GetTopLine: Double; begin Result := FMonaco.TopLine; end;
function TCMonacoEditor.GetReady: Boolean; begin Result := FMonaco.Ready; end;

{ ---------- カーソル・選択・編集（中継） ---------- }

procedure TCMonacoEditor.SetCursorPos(ALine, AColumn: Integer); begin FMonaco.SetCursorPos(ALine, AColumn); end;
procedure TCMonacoEditor.GetCursorPos(out ALine, AColumn: Integer); begin FMonaco.GetCursorPos(ALine, AColumn); end;
procedure TCMonacoEditor.SetSelection(AStartLine, AStartCol, AEndLine, AEndCol: Integer);
begin
  FMonaco.SetSelection(AStartLine, AStartCol, AEndLine, AEndCol);
end;
function TCMonacoEditor.GetSelText: string; begin Result := FMonaco.GetSelectedText; end;
procedure TCMonacoEditor.SetSelText(const AValue: string); begin FMonaco.SetSelText(AValue); end;
function TCMonacoEditor.GetSelStart: Integer; begin Result := FMonaco.SelStart; end;
function TCMonacoEditor.GetSelLength: Integer; begin Result := FMonaco.SelLength; end;
function TCMonacoEditor.GetCanUndo: Boolean; begin Result := FMonaco.CanUndo; end;
function TCMonacoEditor.GetCanRedo: Boolean; begin Result := FMonaco.CanRedo; end;   { 【2.17】 }
procedure TCMonacoEditor.DeleteToEnd; begin FMonaco.DeleteToEnd; end;
procedure TCMonacoEditor.DeleteToStart; begin FMonaco.DeleteToStart; end;
procedure TCMonacoEditor.DuplicateLine; begin FMonaco.DuplicateLine; end;   { 【2.16】ReadOnly の判定は中の部品が行う }
procedure TCMonacoEditor.Undo; begin FMonaco.Undo; end;
procedure TCMonacoEditor.Redo; begin FMonaco.Redo; end;
procedure TCMonacoEditor.Cut; begin FMonaco.Cut; end;
procedure TCMonacoEditor.Copy; begin FMonaco.Copy; end;
procedure TCMonacoEditor.Paste; begin FMonaco.Paste; end;
procedure TCMonacoEditor.SelectAll; begin FMonaco.SelectAll; end;
procedure TCMonacoEditor.ToggleOverwrite; begin FMonaco.ToggleOverwrite; end;

initialization
  GShownErrors := TStringList.Create;

  GEditors := TFPList.Create;          { 【2.21】 }

finalization
  FreeAndNil(GShownErrors);
  if GReceiverWnd <> 0 then Windows.DestroyWindow(GReceiverWnd);   { 【2.21】 }
  GReceiverWnd := 0;
  FreeAndNil(GEditors);

end.
