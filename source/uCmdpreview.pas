{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ TCMMarkdownPreview - WebView2 による Markdown プレビュー（内部の部品）
  ※ 第2版から、ucmonacos.pas の TCMonacoEditor（複合部品）の中に入る内部の部品になった。
  環境: Lazarus 4.8 / FPC 3.2.2 / Windows 11 x64 / WebView4Delphi

  【使い方】
  1. EXE の隣に WebView2.ini（必ず置く）と WebView2Loader.dll を置く。WebView2 の準備は、
     初めて表示されたときにこの部品が自分で行う（uCXRuntime の CXStartWebView2。.lpr には何も書かない）
  2. EXE の隣に preview\ フォルダ（preview.html と lib\）を置く
     別の場所に置くときは、ResourcePath か、WebView2.ini の PreviewFolder で指定する
     （ResourcePath が優先。相対パスは EXE のフォルダから数える。uCXRuntime.pas）
  3. Prev := TCMMarkdownPreview.Create(Self); Prev.Parent := Self; Prev.Align := alRight;
     Prev.ShowMarkdown('# 見出し', 'C:\docs');     // 本文と、画像の相対パスの基準フォルダ
     Prev.SetTopLine(12.5);                         // 同期スクロール（エディタの表示先頭行。小数可）
  エディタと自動でつなぐには、CMonacoPreview.pas の TCMPreviewBinder を使う。

  ・外部の画像（http）は、AllowRemoteImages := True にしない限り表示しない。
  ・リンクは、外部(http/https/mailto)なら既定のブラウザで開き、.md なら OnOpenMarkdown で通知する。
  ・印刷は Print（右クリックメニューの「印刷...」も同じ）。Edge と同じ印刷ダイアログを表示し、
    プリンター・PDF 保存・ページ指定などは、すべてダイアログに任せる。 }
unit ucmdpreview;

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils, Controls, Forms, ExtCtrls, Clipbrd, Menus, LCLIntf,
  uWVBrowser, uWVWindowParent, uWVLoader, uWVTypes, uWVTypeLibrary,
  uWVEvents, uWVCoreWebView2Args;

type
  TCMOpenMarkdownEvent = procedure(Sender: TObject; const AFileName: string) of object;
  TCMPreviewErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;
  TCMScrollLineEvent = procedure(Sender: TObject; Line: Double) of object;

  { TCMMarkdownPreview }

  TCMMarkdownPreview = class(TWinControl)
  private
    FBrowser: TWVBrowser;
    FWindowParent: TWVWindowParent;
    FInitTimer: TTimer;
    FBrowserCreated: Boolean;
    FReady: Boolean;
    FResourcePath: string;
    FTheme: string;
    FFontSize: Integer;
    FBreakOnNewline: Boolean;
    FAllowRemoteImages: Boolean;
    FHasContent: Boolean;
    FText: string;
    FCodeMode: Boolean;       { 【段階5】True = Markdown 以外（色分けしたコード） }
    FCodeLang: string;
    FDocTitle: string;        { 【段階5】ページのタイトル（印刷で PDF の名前になる） }
    FPrintPending: Boolean;   { 【段階5】印刷の準備中（準備ができたら印刷ダイアログを出す） }
    FOnAfterPrint: TNotifyEvent;
    FOnPrintKey: TNotifyEvent;   { 【2.8】 }
    FBaseDir: string;
    FTopLine: Double;
    FPopup: TPopupMenu;
    FMenuPos: TPoint;
    FMenuPending: Boolean;
    FPendingMd: TStringList;
    FOnReady: TNotifyEvent;
    FOnOpenMarkdown: TCMOpenMarkdownEvent;
    FOnError: TCMPreviewErrorEvent;
    FOnFontSizeChange: TNotifyEvent;
    FOnScrollLine: TCMScrollLineEvent;
    FMaxContentWidth: Integer;
    FContentPadding: Integer;
    FColorScheme: string;
    FBackColorLight, FBackColorDark: string;
    FTextColorLight, FTextColorDark: string;
    FLinkColorLight, FLinkColorDark: string;

    procedure BrowserAfterCreated(Sender: TObject);
    procedure BrowserInitError(Sender: TObject; aErrorCode: HRESULT; const aErrorMessage: wvstring);
    procedure BrowserAcceleratorKeyPressed(Sender: TObject; const aController: ICoreWebView2Controller;
      const aArgs: ICoreWebView2AcceleratorKeyPressedEventArgs);
    procedure BrowserWebMessageReceived(Sender: TObject; const aWebView: ICoreWebView2;
      const aArgs: ICoreWebView2WebMessageReceivedEventArgs);
    procedure InitTimerTick(Sender: TObject);
    procedure DoError(const AMessage: string);
    procedure SendCmd(const S: string);
    procedure SendOptions;
    procedure SendColors;
    procedure SendLayout;
    procedure SetMaxContentWidth(AValue: Integer);
    procedure SetContentPadding(AValue: Integer);
    procedure SetColorScheme(const AValue: string);
    procedure SetBackColorLight(const AValue: string);
    procedure SetBackColorDark(const AValue: string);
    procedure SetTextColorLight(const AValue: string);
    procedure SetTextColorDark(const AValue: string);
    procedure SetLinkColorLight(const AValue: string);
    procedure SetLinkColorDark(const AValue: string);
    procedure SendRender;
    procedure SendLine;
    procedure HandleMessage(const Msg: string);
    function GetResourceDir: string;
    procedure AsyncContextMenu(Data: PtrInt);
    procedure AsyncOpenMarkdown(Data: PtrInt);
    procedure AsyncShowPrintUI(Data: PtrInt);
    procedure MenuCopyClick(Sender: TObject);
    procedure MenuSelectAllClick(Sender: TObject);
    procedure MenuPrintClick(Sender: TObject);
    procedure AsyncPrintKey(Data: PtrInt);   { 【2.8】 }
    procedure SetTheme(const AValue: string);
    procedure SetFontSize(AValue: Integer);
    procedure SetBreakOnNewline(AValue: Boolean);
    procedure SetAllowRemoteImages(AValue: Boolean);
    procedure SetDocTitle(const AValue: string);
  protected
    procedure CreateWnd; override;
    procedure VisibleChanged; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ShowMarkdown(const AText, ABaseDir: string);   { 本文と、画像の相対パスの基準フォルダ }
    procedure ShowCode(const AText, ALanguage: string);      { 【段階5】Markdown 以外：色分けしたコードを行番号付きで表示する }
    procedure Clear;
    procedure SetTopLine(ALine: Double);                      { 同期スクロール。1 始まり、小数で行内の位置 }
    procedure CopySelection;
    procedure SelectAll;
    procedure OpenDevTools;
    procedure Print;                                          { 印刷ダイアログを表示する（準備ができていなければ、できてから出す） }

    property Ready: Boolean read FReady;
    property DocTitle: string read FDocTitle write SetDocTitle;   { 【段階5】印刷で PDF の名前になる（例 'abc'） }
    property TopLine: Double read FTopLine;
  published
    property ResourcePath: string read FResourcePath write FResourcePath;   { 空なら WebView2.ini の PreviewFolder、それも無ければ EXE隣の preview\（【2.19】） }
    property Theme: string read FTheme write SetTheme;                       { 'auto' / 'vs' / 'vs-dark' }
    property FontSize: Integer read FFontSize write SetFontSize default 16;
    property BreakOnNewline: Boolean read FBreakOnNewline write SetBreakOnNewline default False;
    property AllowRemoteImages: Boolean read FAllowRemoteImages write SetAllowRemoteImages default False;
    property MaxContentWidth: Integer read FMaxContentWidth write SetMaxContentWidth default 0;   { 本文の最大幅(px)。0=パネルの幅いっぱい（既定） }
    property ContentPadding: Integer read FContentPadding write SetContentPadding default 26;      { 本文の左右の余白(px) }
    property ColorScheme: string read FColorScheme write SetColorScheme;   { 'editor'=エディタと同じ配色（既定） / 'github'=GitHub 風 }
    property BackColorLight: string read FBackColorLight write SetBackColorLight;   { 'editor' のときの色 '#RRGGBB' }
    property BackColorDark: string read FBackColorDark write SetBackColorDark;
    property TextColorLight: string read FTextColorLight write SetTextColorLight;
    property TextColorDark: string read FTextColorDark write SetTextColorDark;
    property LinkColorLight: string read FLinkColorLight write SetLinkColorLight;
    property LinkColorDark: string read FLinkColorDark write SetLinkColorDark;
    property PopupMenu;
    property Align;
    property Anchors;
    property Enabled;
    property TabOrder;
    property TabStop;
    property Visible;

    property OnReady: TNotifyEvent read FOnReady write FOnReady;
    property OnOpenMarkdown: TCMOpenMarkdownEvent read FOnOpenMarkdown write FOnOpenMarkdown;
    property OnError: TCMPreviewErrorEvent read FOnError write FOnError;
    property OnFontSizeChange: TNotifyEvent read FOnFontSizeChange write FOnFontSizeChange;
    property OnPrintKey: TNotifyEvent read FOnPrintKey write FOnPrintKey;   { 【2.8】Ctrl+P が押された。未設定なら Print }
    property OnAfterPrint: TNotifyEvent read FOnAfterPrint write FOnAfterPrint;   { 【段階5】印刷ダイアログが閉じた（通知されない場合もある） }
    property OnScrollLine: TCMScrollLineEvent read FOnScrollLine write FOnScrollLine;   { ユーザーがプレビューをスクロールした（先頭の元の行番号）。同期スクロール用 }
  end;

implementation

uses
  uCXRuntime;   { preview フォルダの場所を決める（WebView2.ini の PreviewFolder）・WebView2 の準備 }

{ 設計時かどうか（複合部品の中に入れた場合も、親をたどって判定する） }
function InDesigner(AControl: TControl): Boolean;
var
  C: TControl;
begin
  Result := False;
  if (csDesigning in AControl.ComponentState) or
     ((AControl.Owner <> nil) and (csDesigning in AControl.Owner.ComponentState)) then Exit(True);
  C := AControl.Parent;
  while C <> nil do
  begin
    if csDesigning in C.ComponentState then Exit(True);
    C := C.Parent;
  end;
end;

const
  SEP = #1;
  VHOST = 'cmpreview.example';

function WVStr(const S: string): wvstring;
begin
  Result := UTF8Decode(S);
end;

function FromWV(const S: wvstring): string;
begin
  Result := UTF8Encode(UnicodeString(S));
end;

function FloatToJS(D: Double): string;
begin
  Str(D:0:3, Result);    { 小数点は、環境の設定に関係なく '.' }
end;

{ TCMMarkdownPreview }

constructor TCMMarkdownPreview.Create(AOwner: TComponent);
var
  MI: TMenuItem;
begin
  inherited Create(AOwner);
  Width := 400;
  Height := 300;
  TabStop := True;

  FTheme := 'auto';
  FFontSize := 16;
  FColorScheme := 'editor';
  FMaxContentWidth := 0;
  FContentPadding := 26;
  FBackColorLight := '#fffffe';
  FBackColorDark := '#1e1e1e';
  FTextColorLight := '#000000';
  FTextColorDark := '#d4d4d4';
  FLinkColorLight := '#006ab1';
  FLinkColorDark := '#3794ff';
  FTopLine := 1;
  FPendingMd := TStringList.Create;

  FWindowParent := TWVWindowParent.Create(Self);
  FWindowParent.Parent := Self;
  FWindowParent.Align := alClient;

  FBrowser := TWVBrowser.Create(Self);
  FBrowser.OnAfterCreated := @BrowserAfterCreated;
  FBrowser.OnInitializationError := @BrowserInitError;
  FBrowser.OnWebMessageReceived := @BrowserWebMessageReceived;
  FBrowser.AreBrowserAcceleratorKeysEnabled := False;
  FBrowser.OnAcceleratorKeyPressed := @BrowserAcceleratorKeyPressed;   { 【段階5】Ctrl+Shift+P を止める }
  FBrowser.ZoomControlEnabled := False;
  FBrowser.DevToolsEnabled := False;
  FBrowser.StatusBarEnabled := False;
  FWindowParent.Browser := FBrowser;

  FInitTimer := TTimer.Create(Self);
  FInitTimer.Enabled := False;
  FInitTimer.Interval := 100;
  FInitTimer.OnTimer := @InitTimerTick;

  FPopup := TPopupMenu.Create(Self);
  MI := TMenuItem.Create(FPopup);
  MI.Caption := 'コピー';
  MI.OnClick := @MenuCopyClick;
  FPopup.Items.Add(MI);
  MI := TMenuItem.Create(FPopup);
  MI.Caption := 'すべて選択';
  MI.OnClick := @MenuSelectAllClick;
  FPopup.Items.Add(MI);
  MI := TMenuItem.Create(FPopup);
  MI.Caption := '-';
  FPopup.Items.Add(MI);
  MI := TMenuItem.Create(FPopup);
  MI.Caption := '印刷...';
  MI.OnClick := @MenuPrintClick;
  FPopup.Items.Add(MI);
  PopupMenu := FPopup;
end;

destructor TCMMarkdownPreview.Destroy;
begin
  FInitTimer.Enabled := False;
  Application.RemoveAsyncCalls(Self);
  FPendingMd.Free;
  inherited Destroy;
end;

procedure TCMMarkdownPreview.CreateWnd;
begin
  inherited CreateWnd;
  if not InDesigner(Self) and not FBrowserCreated then
    FInitTimer.Enabled := True;
end;

procedure TCMMarkdownPreview.VisibleChanged;
begin
  inherited VisibleChanged;
  if InDesigner(Self) then Exit;
  if Visible then
  begin
    if not FBrowserCreated then
      FInitTimer.Enabled := True          { 初めて表示されたときに WebView2 を作る }
    else if FReady then
    begin
      { 再表示: 表示状態と大きさを WebView2 に伝え、最新の内容を描き直す }
      FBrowser.IsVisible := True;
      FWindowParent.UpdateSize;
      FBrowser.NotifyParentWindowPositionChanged;
      if FHasContent then SendRender;
      SendLine;
    end;
  end
  else if FReady then
    FBrowser.IsVisible := False;
end;

procedure TCMMarkdownPreview.InitTimerTick(Sender: TObject);
var
  Err: string;
begin
  if FBrowserCreated then
  begin
    FInitTimer.Enabled := False;
    Exit;
  end;
  if not Visible then
  begin
    FInitTimer.Enabled := False;          { 非表示の間は作らない（表示されたら VisibleChanged で再開） }
    Exit;
  end;
  if not Showing then Exit;               { 親がまだ表示されていない。次のタイマーで再確認 }
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

{ 【2.19】preview フォルダの場所を決める。
  ① ResourcePath（TCMonacoEditor.PreviewPath）が空でなければ、その場所
  ② 空なら、EXE の隣の WebView2.ini の PreviewFolder
  ③ それも無ければ、EXE の隣の preview
  相対パスは EXE のフォルダから数える（までは、起動したときの作業フォルダから数えていた） }
function TCMMarkdownPreview.GetResourceDir: string;
begin
  Result := CXResolveRuntimeDir(FResourcePath, 'PreviewFolder', 'preview');
end;

procedure TCMMarkdownPreview.BrowserAfterCreated(Sender: TObject);
var
  Dir: string;
  Drives: DWORD;
  I: Integer;
begin
  FWindowParent.UpdateSize;
  Dir := GetResourceDir;
  if not FileExists(Dir + PathDelim + 'preview.html') then
  begin
    DoError('preview.html が見つかりません: ' + Dir);
    Exit;
  end;
  FBrowser.SetVirtualHostNameToFolderMapping(WVStr(VHOST), WVStr(Dir),
    COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_ALLOW);

  { ローカルの画像を表示するため、各ドライブを仮想ホスト（cmdrive-c.example など）に割り当てる }
  Drives := GetLogicalDrives;
  for I := 0 to 25 do
    if (Drives and (DWORD(1) shl I)) <> 0 then
      FBrowser.SetVirtualHostNameToFolderMapping(
        WVStr('cmdrive-' + Chr(Ord('a') + I) + '.example'),
        WVStr(Chr(Ord('A') + I) + ':\'),
        COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_ALLOW);

  FBrowser.Navigate(WVStr('https://' + VHOST + '/preview.html'));
end;

procedure TCMMarkdownPreview.BrowserInitError(Sender: TObject; aErrorCode: HRESULT;
  const aErrorMessage: wvstring);
begin
  DoError(FromWV(aErrorMessage));
end;

procedure TCMMarkdownPreview.BrowserAcceleratorKeyPressed(Sender: TObject;
  const aController: ICoreWebView2Controller;
  const aArgs: ICoreWebView2AcceleratorKeyPressedEventArgs);
var
  Args: TCoreWebView2AcceleratorKeyPressedEventArgs;
begin
  { 【段階5】Ctrl+Shift+P（WebView2 の「システムのダイアログで印刷」）を止める。印刷は右クリックの「印刷...」か Print }
  Args := TCoreWebView2AcceleratorKeyPressedEventArgs.Create(aArgs);
  try
    if ((Args.KeyEventKind = COREWEBVIEW2_KEY_EVENT_KIND_KEY_DOWN) or
        (Args.KeyEventKind = COREWEBVIEW2_KEY_EVENT_KIND_SYSTEM_KEY_DOWN)) and
       (Args.VirtualKey = Ord('P')) and (GetKeyState(VK_CONTROL) < 0) and
       (GetKeyState(VK_SHIFT) < 0) and (GetKeyState(VK_MENU) >= 0) then
      Args.Handled := True
    { 【2.8】Ctrl+P は WebView2 の印刷（図がダークの色のまま）を止め、右クリックの「印刷...」と同じ印刷にする }
    else if (Args.KeyEventKind = COREWEBVIEW2_KEY_EVENT_KIND_KEY_DOWN) and
       (Args.VirtualKey = Ord('P')) and (GetKeyState(VK_CONTROL) < 0) and
       (GetKeyState(VK_SHIFT) >= 0) and (GetKeyState(VK_MENU) >= 0) then
    begin
      Args.Handled := True;
      Application.QueueAsyncCall(@AsyncPrintKey, 0);
    end;
  finally
    Args.Free;
  end;
end;

procedure TCMMarkdownPreview.BrowserWebMessageReceived(Sender: TObject; const aWebView: ICoreWebView2;
  const aArgs: ICoreWebView2WebMessageReceivedEventArgs);
var
  Args: TCoreWebView2WebMessageReceivedEventArgs;
  S: string;
begin
  Args := TCoreWebView2WebMessageReceivedEventArgs.Create(aArgs);
  try
    S := FromWV(Args.WebMessageAsString);
  finally
    Args.Free;
  end;
  HandleMessage(S);
end;

procedure TCMMarkdownPreview.DoError(const AMessage: string);
begin
  if Assigned(FOnError) then FOnError(Self, AMessage);
end;

procedure TCMMarkdownPreview.SendCmd(const S: string);
begin
  if FReady then FBrowser.PostWebMessageAsString(WVStr(S));
end;

procedure TCMMarkdownPreview.SendColors;
begin
  SendCmd('opt' + SEP + 'colors' + SEP + FColorScheme + SEP + FBackColorLight + SEP + FTextColorLight + SEP +
    FLinkColorLight + SEP + FBackColorDark + SEP + FTextColorDark + SEP + FLinkColorDark);
end;

procedure TCMMarkdownPreview.SetColorScheme(const AValue: string);
begin
  if AValue = 'github' then FColorScheme := 'github' else FColorScheme := 'editor';
  SendColors;
end;

procedure TCMMarkdownPreview.SetBackColorLight(const AValue: string);
begin
  FBackColorLight := AValue;
  SendColors;
end;

procedure TCMMarkdownPreview.SetBackColorDark(const AValue: string);
begin
  FBackColorDark := AValue;
  SendColors;
end;

procedure TCMMarkdownPreview.SetTextColorLight(const AValue: string);
begin
  FTextColorLight := AValue;
  SendColors;
end;

procedure TCMMarkdownPreview.SetTextColorDark(const AValue: string);
begin
  FTextColorDark := AValue;
  SendColors;
end;

procedure TCMMarkdownPreview.SetLinkColorLight(const AValue: string);
begin
  FLinkColorLight := AValue;
  SendColors;
end;

procedure TCMMarkdownPreview.SetLinkColorDark(const AValue: string);
begin
  FLinkColorDark := AValue;
  SendColors;
end;

procedure TCMMarkdownPreview.SendLayout;
begin
  SendCmd('opt' + SEP + 'layout' + SEP + IntToStr(FMaxContentWidth) + SEP + IntToStr(FContentPadding));
end;

procedure TCMMarkdownPreview.SetMaxContentWidth(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  if AValue > 4000 then AValue := 4000;
  FMaxContentWidth := AValue;
  SendLayout;
end;

procedure TCMMarkdownPreview.SetContentPadding(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  if AValue > 200 then AValue := 200;
  FContentPadding := AValue;
  SendLayout;
end;

procedure TCMMarkdownPreview.SendOptions;
begin
  SendColors;
  SendLayout;
  SendCmd('opt' + SEP + 'theme' + SEP + FTheme);
  SendCmd('opt' + SEP + 'fontsize' + SEP + IntToStr(FFontSize));
  if FBreakOnNewline then SendCmd('opt' + SEP + 'breaks' + SEP + '1') else SendCmd('opt' + SEP + 'breaks' + SEP + '0');
  if FAllowRemoteImages then SendCmd('opt' + SEP + 'remote' + SEP + '1') else SendCmd('opt' + SEP + 'remote' + SEP + '0');
end;

procedure TCMMarkdownPreview.SendRender;
begin
  if FCodeMode then
    SendCmd('code' + SEP + FCodeLang + SEP + FText)         { 【段階5】Markdown 以外 }
  else
    SendCmd('render' + SEP + FBaseDir + SEP + FText);
end;

procedure TCMMarkdownPreview.SendLine;
begin
  SendCmd('line' + SEP + FloatToJS(FTopLine));
end;

procedure TCMMarkdownPreview.HandleMessage(const Msg: string);
var
  P, Code: Integer;
  D: Double;
  Cmd, Arg: string;
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
    { 非表示で作ったあとに表示したときは、作成後にサイズ変更が起きないため、ここで大きさと表示状態を伝える }
    FBrowser.IsVisible := Visible;
    FWindowParent.UpdateSize;
    FBrowser.NotifyParentWindowPositionChanged;
    SendOptions;
    SendCmd('title' + SEP + FDocTitle);
    SendLine;
    if FHasContent then
    begin
      SendRender;
      SendLine;
    end;
    if Assigned(FOnReady) then FOnReady(Self);
    if FPrintPending then SendCmd('prepareprint');   { 【段階5】準備を待っていた印刷 }
  end
  else if Cmd = 'openurl' then
  begin
    if (Pos('http://', LowerCase(Arg)) = 1) or (Pos('https://', LowerCase(Arg)) = 1) or
       (Pos('mailto:', LowerCase(Arg)) = 1) then
      OpenURL(Arg);
  end
  else if Cmd = 'openmd' then
  begin
    Arg := StringReplace(Arg, '/', PathDelim, [rfReplaceAll]);
    if FileExists(Arg) then
    begin
      FPendingMd.Add(Arg);
      Application.QueueAsyncCall(@AsyncOpenMarkdown, 0);
    end;
  end
  else if Cmd = 'contextmenu' then
  begin
    { WebView2 のイベント内で直接メニューを出すと即閉じることがあるため、処理完了後に表示する }
    FMenuPos := Mouse.CursorPos;
    if not FMenuPending then
    begin
      FMenuPending := True;
      Application.QueueAsyncCall(@AsyncContextMenu, 0);
    end;
  end
  else if Cmd = 'copytext' then
  begin
    if Arg <> '' then Clipboard.AsText := Arg;
  end
  else if Cmd = 'scrollline' then
  begin
    Val(Arg, D, Code);
    if (Code = 0) and Assigned(FOnScrollLine) then FOnScrollLine(Self, D);
  end
  else if Cmd = 'fontsize' then
  begin
    FFontSize := StrToIntDef(Arg, FFontSize);
    if Assigned(FOnFontSizeChange) then FOnFontSizeChange(Self);
  end
  else if Cmd = 'printready' then
  begin
    { 【段階5】図を白背景用の色で描き終えた。WebView2 のイベントの外で印刷ダイアログを出す }
    if FPrintPending then
    begin
      FPrintPending := False;
      Application.QueueAsyncCall(@AsyncShowPrintUI, 0);
    end;
  end
  else if Cmd = 'afterprint' then
  begin
    if Assigned(FOnAfterPrint) then FOnAfterPrint(Self);
  end
  else if Cmd = 'error' then
    DoError(Arg);
end;

procedure TCMMarkdownPreview.AsyncContextMenu(Data: PtrInt);
begin
  FMenuPending := False;
  if PopupMenu <> nil then PopupMenu.PopUp(FMenuPos.X, FMenuPos.Y);
end;

procedure TCMMarkdownPreview.AsyncOpenMarkdown(Data: PtrInt);
var
  Files: TStringList;
  I: Integer;
begin
  if FPendingMd.Count = 0 then Exit;
  Files := TStringList.Create;
  try
    Files.Assign(FPendingMd);
    FPendingMd.Clear;
    if Assigned(FOnOpenMarkdown) then
      for I := 0 to Files.Count - 1 do
        FOnOpenMarkdown(Self, Files[I]);
  finally
    Files.Free;
  end;
end;

procedure TCMMarkdownPreview.MenuCopyClick(Sender: TObject);
begin
  CopySelection;
end;

procedure TCMMarkdownPreview.MenuSelectAllClick(Sender: TObject);
begin
  SelectAll;
end;

procedure TCMMarkdownPreview.MenuPrintClick(Sender: TObject);
begin
  Print;
end;

procedure TCMMarkdownPreview.AsyncPrintKey(Data: PtrInt);
begin
  if Assigned(FOnPrintKey) then FOnPrintKey(Self) else Print;
end;

{ ---------- 公開メソッド ---------- }

procedure TCMMarkdownPreview.ShowMarkdown(const AText, ABaseDir: string);
begin
  FCodeMode := False;
  FText := AText;
  FBaseDir := ExcludeTrailingPathDelimiter(ABaseDir);
  FHasContent := True;
  SendRender;
end;

procedure TCMMarkdownPreview.ShowCode(const AText, ALanguage: string);
begin
  FCodeMode := True;
  FCodeLang := ALanguage;
  FText := AText;
  FBaseDir := '';
  FHasContent := True;
  SendRender;
end;

procedure TCMMarkdownPreview.Clear;
begin
  FHasContent := False;
  FText := '';
  SendCmd('clear');
end;

procedure TCMMarkdownPreview.SetTopLine(ALine: Double);
begin
  if ALine < 1 then ALine := 1;
  FTopLine := ALine;
  SendLine;
end;

procedure TCMMarkdownPreview.CopySelection;
begin
  SendCmd('copy');
end;

procedure TCMMarkdownPreview.SelectAll;
begin
  SendCmd('selectall');
end;

procedure TCMMarkdownPreview.Print;
begin
  { 【段階5】すぐには出さず、JavaScript に印刷の準備（Mermaid の図を白背景用の色で描き直す）をさせ、
    'printready' が来てから印刷ダイアログを出す。準備前（WebView2 の起動中）なら、ready のあとで行う }
  FPrintPending := True;
  if FReady then SendCmd('prepareprint');
end;

procedure TCMMarkdownPreview.AsyncShowPrintUI(Data: PtrInt);
begin
  if not FReady then Exit;
  if not FBrowser.ShowPrintUI(False) then   { False = Edge と同じ印刷ダイアログ }
  begin
    SendCmd('printdone');
    DoError('印刷ダイアログを表示できませんでした');
  end;
end;

procedure TCMMarkdownPreview.OpenDevTools;
begin
  FBrowser.DevToolsEnabled := True;
  FBrowser.OpenDevToolsWindow;
end;

{ ---------- プロパティ ---------- }

procedure TCMMarkdownPreview.SetTheme(const AValue: string);
begin
  if (AValue = 'vs') or (AValue = 'vs-dark') then
    FTheme := AValue
  else
    FTheme := 'auto';
  SendCmd('opt' + SEP + 'theme' + SEP + FTheme);
end;

procedure TCMMarkdownPreview.SetFontSize(AValue: Integer);
begin
  if AValue < 8 then AValue := 8;
  if AValue > 48 then AValue := 48;
  FFontSize := AValue;
  SendCmd('opt' + SEP + 'fontsize' + SEP + IntToStr(AValue));
end;

procedure TCMMarkdownPreview.SetBreakOnNewline(AValue: Boolean);
begin
  FBreakOnNewline := AValue;
  if AValue then SendCmd('opt' + SEP + 'breaks' + SEP + '1') else SendCmd('opt' + SEP + 'breaks' + SEP + '0');
  if FHasContent then SendRender;
end;

procedure TCMMarkdownPreview.SetDocTitle(const AValue: string);
begin
  if AValue = FDocTitle then Exit;
  FDocTitle := AValue;
  SendCmd('title' + SEP + AValue);
end;

procedure TCMMarkdownPreview.SetAllowRemoteImages(AValue: Boolean);
begin
  FAllowRemoteImages := AValue;
  if AValue then SendCmd('opt' + SEP + 'remote' + SEP + '1') else SendCmd('opt' + SEP + 'remote' + SEP + '0');
  if FHasContent then SendRender;
end;

end.
