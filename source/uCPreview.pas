{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ TCPreview - TCsEditor の本文をプレビュー（Markdown は文書、それ以外は色分けしたコード）として表示し、
  印刷（PDF 保存）する部品（TCPreview_Design.md）。
  ・中身は TCMonacoEditor のプレビュー（TCMMarkdownPreview・preview\preview.html）をそのまま使う。
  ・つなぎ方は、TCsEditor の Preview プロパティでこの部品を選ぶ。1 つの TCPreview を複数の TCsEditor から選べる。
  ・表示するのは「表示元」（最後にフォーカスされた TCsEditor）の見えているタブ。
  ・表示・非表示は TCsEditor の ShowPreview（Ctrl+Shift+V）。この部品の Visible を直接変えても同じ。 }
unit uCPreview;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, ExtCtrls, Forms, Dialogs,
  ucmdpreview, CMonacoPreview, uCmonacos;

type
  { アプリが uCPreview だけを uses すれば済むように、型と値を出し直す（uCmonacos と同じやり方） }
  TCMColorScheme = uCmonacos.TCMColorScheme;
  TCMSyncScroll = CMonacoPreview.TCMSyncScroll;

const
  csEditor = uCmonacos.csEditor;
  csGitHub = uCmonacos.csGitHub;
  ssNone = CMonacoPreview.ssNone;
  ssEditorToPreview = CMonacoPreview.ssEditorToPreview;
  ssBoth = CMonacoPreview.ssBoth;

type

  { TCPreview }

  TCPreview = class(TCustomPanel)
  private
    FPreview: TCMMarkdownPreview;        { 中の部品。実行時だけ作る（4.1） }
    FSource: TComponent;                 { 表示元の TCsEditor（3章） }
    FTimer: TTimer;                      { 入力が止まるのを待つ（5.2） }
    FSplitter: TSplitter;
    FFontSize: Integer;
    FColorScheme: TCMColorScheme;
    FBackColorLight, FBackColorDark: TColor;
    FTextColorLight, FTextColorDark: TColor;
    FLinkColorLight, FLinkColorDark: TColor;
    FBreakOnNewline: Boolean;
    FAllowRemoteImages: Boolean;
    FSyncScroll: TCMSyncScroll;
    FDelayMs: Integer;
    FPreviewPath: string;
    FDirty: Boolean;                     { 隠れている間に変わった。表示したときに作り直す（5.1） }
    FShownForPrint: Boolean;             { 印刷のために出した（5.4） }
    FSuppressUntil: QWord;               { エディタからのスクロールの知らせを抑える時刻（5.3） }
    FOpenQueue: TStringList;             { 開く .md の名前（5.5） }
    FErrQueue: TStringList;              { 出すエラー（5.5） }
    FOnOpenMarkdown: TCMOpenMarkdownEvent;
    FOnError: TCMPreviewErrorEvent;
    procedure ApplyAll;
    procedure SetSplitter(AValue: TSplitter);
    procedure SetFontSize(AValue: Integer);
    procedure SetColorScheme(AValue: TCMColorScheme);
    procedure SetBackColorLight(AValue: TColor);
    procedure SetBackColorDark(AValue: TColor);
    procedure SetTextColorLight(AValue: TColor);
    procedure SetTextColorDark(AValue: TColor);
    procedure SetLinkColorLight(AValue: TColor);
    procedure SetLinkColorDark(AValue: TColor);
    procedure SetBreakOnNewline(AValue: Boolean);
    procedure SetAllowRemoteImages(AValue: Boolean);
    procedure SetDelayMs(AValue: Integer);
    procedure SetPreviewPath(const AValue: string);
    function GetReady: Boolean;
    procedure TimerTick(Sender: TObject);
    procedure InnerScrollLine(Sender: TObject; Line: Double);
    procedure InnerOpenMarkdown(Sender: TObject; const AFileName: string);
    procedure InnerError(Sender: TObject; const AMessage: string);
    procedure InnerPrintKey(Sender: TObject);
    procedure InnerAfterPrint(Sender: TObject);
    procedure InnerFontSizeChange(Sender: TObject);
    procedure AsyncOpenMarkdown(Data: PtrInt);
    procedure AsyncShowError(Data: PtrInt);
    procedure PlaceSplitter;
    procedure ApplySplitterColor;
  protected
    procedure Loaded; override;
    procedure Paint; override;
    procedure VisibleChanged; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { 表示元にする。違う表示元なら、すぐに Refresh（3.2） }
    procedure SetSource(ASource: TComponent);
    { 本文が変わった。表示元なら DelayMs 待って Refresh }
    procedure SourceChanged(ASource: TComponent);
    { タブの切り替え・言語やファイル名・配色が変わった。表示元なら、すぐに Refresh }
    procedure SourceSwitched(ASource: TComponent);
    { 表示している先頭の行が変わった。表示元なら、プレビューも合わせる（5.3） }
    procedure SourceScrolled(ASource: TComponent; ALine: Double);
    { TCsEditor の Preview から外された。表示元なら空にする }
    procedure SourceRemoved(ASource: TComponent);
    { その TCsEditor を表示元にして印刷する（5.4） }
    procedure PrintFor(ASource: TComponent);
    { 今の表示元で印刷する。表示元が無ければ何もしない }
    procedure Print;
    { 表示元の見えているタブで、作り直す（5.1） }
    procedure Refresh; reintroduce;
    property Source: TComponent read FSource;
    property Ready: Boolean read GetReady;
  published
    property Splitter: TSplitter read FSplitter write SetSplitter;
    property FontSize: Integer read FFontSize write SetFontSize default 16;
    property ColorScheme: TCMColorScheme read FColorScheme write SetColorScheme default csEditor;
    property BackColorLight: TColor read FBackColorLight write SetBackColorLight default DefPreviewBackColorLight;
    property BackColorDark: TColor read FBackColorDark write SetBackColorDark default DefPreviewBackColorDark;
    property TextColorLight: TColor read FTextColorLight write SetTextColorLight default DefPreviewTextColorLight;
    property TextColorDark: TColor read FTextColorDark write SetTextColorDark default DefPreviewTextColorDark;
    property LinkColorLight: TColor read FLinkColorLight write SetLinkColorLight default DefPreviewLinkColorLight;
    property LinkColorDark: TColor read FLinkColorDark write SetLinkColorDark default DefPreviewLinkColorDark;
    property BreakOnNewline: Boolean read FBreakOnNewline write SetBreakOnNewline default False;
    property AllowRemoteImages: Boolean read FAllowRemoteImages write SetAllowRemoteImages default False;
    property SyncScroll: TCMSyncScroll read FSyncScroll write FSyncScroll default ssBoth;
    property DelayMs: Integer read FDelayMs write SetDelayMs default 300;
    property PreviewPath: string read FPreviewPath write SetPreviewPath;
    property OnOpenMarkdown: TCMOpenMarkdownEvent read FOnOpenMarkdown write FOnOpenMarkdown;
    property OnError: TCMPreviewErrorEvent read FOnError write FOnError;
    property Align;
    property Anchors;
    property BorderSpacing;
    property Constraints;
    property Enabled;
    property Visible;
    property TabOrder;
    property TabStop;
  end;

implementation

uses
  LCLIntf, uCsEditor;

var
  GShownErrors: TStringList = nil;   { 既定のエラー表示で、表示済みのメッセージ（同じものは 1 回だけ） }

const
  ThemeNames: array[TCMTheme] of string = ('auto', 'vs', 'vs-dark');

{ ---------- 作る・壊す ---------- }

constructor TCPreview.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csSetCaption, csAcceptsControls];
  SetTextBuf('');
  BevelOuter := bvNone;
  BevelInner := bvNone;
  Width := 500;
  Height := 300;

  FFontSize := 16;
  FColorScheme := csEditor;
  FBackColorLight := DefPreviewBackColorLight;
  FBackColorDark := DefPreviewBackColorDark;
  FTextColorLight := DefPreviewTextColorLight;
  FTextColorDark := DefPreviewTextColorDark;
  FLinkColorLight := DefPreviewLinkColorLight;
  FLinkColorDark := DefPreviewLinkColorDark;
  FSyncScroll := ssBoth;
  FDelayMs := 300;
  FOpenQueue := TStringList.Create;
  FErrQueue := TStringList.Create;

  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := FDelayMs;
  FTimer.OnTimer := @TimerTick;

  { 中の部品は実行時だけ作る（設計時は WebView2 を起動しない）。
    WebView2 は、中の部品が初めて表示されたときに作られる }
  if not (csDesigning in ComponentState) then
  begin
    FPreview := TCMMarkdownPreview.Create(Self);
    FPreview.Parent := Self;
    FPreview.Align := alClient;
    FPreview.OnScrollLine := @InnerScrollLine;
    FPreview.OnOpenMarkdown := @InnerOpenMarkdown;
    FPreview.OnError := @InnerError;
    FPreview.OnPrintKey := @InnerPrintKey;
    FPreview.OnAfterPrint := @InnerAfterPrint;
    FPreview.OnFontSizeChange := @InnerFontSizeChange;
    ApplyAll;
  end;
end;

destructor TCPreview.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  if FSource <> nil then FSource.RemoveFreeNotification(Self);
  FSource := nil;
  FreeAndNil(FOpenQueue);
  FreeAndNil(FErrQueue);
  inherited Destroy;
end;

procedure TCPreview.Loaded;
begin
  inherited Loaded;
  ApplyAll;
  ApplySplitterColor;
end;

procedure TCPreview.Paint;
begin
  inherited Paint;
  if not (csDesigning in ComponentState) then Exit;
  { 設計時：薄い枠と部品の名前（TCMonacoEditor と同じ見た目） }
  Canvas.Pen.Color := clGrayText;
  Canvas.Pen.Style := psDash;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(0, 0, Width, Height);
  Canvas.Font.Color := clGrayText;
  Canvas.TextOut(8, 8, Name + ' : TCPreview');
end;

procedure TCPreview.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then Exit;
  if AComponent = FSplitter then
    FSplitter := nil
  else if AComponent = FSource then
  begin
    { 表示元が壊された：空にする }
    FSource := nil;
    FTimer.Enabled := False;
    if (FPreview <> nil) and not (csDestroying in ComponentState) then FPreview.Clear;
  end;
end;

{ 設定を中の部品へまとめて渡す（中の部品ができる前も F… に持っている） }
procedure TCPreview.ApplyAll;
begin
  if FPreview = nil then Exit;
  FPreview.FontSize := FFontSize;
  if FColorScheme = csGitHub then FPreview.ColorScheme := 'github' else FPreview.ColorScheme := 'editor';
  FPreview.BackColorLight := CMColorToHex(FBackColorLight, DefPreviewBackColorLight);
  FPreview.BackColorDark := CMColorToHex(FBackColorDark, DefPreviewBackColorDark);
  FPreview.TextColorLight := CMColorToHex(FTextColorLight, DefPreviewTextColorLight);
  FPreview.TextColorDark := CMColorToHex(FTextColorDark, DefPreviewTextColorDark);
  FPreview.LinkColorLight := CMColorToHex(FLinkColorLight, DefPreviewLinkColorLight);
  FPreview.LinkColorDark := CMColorToHex(FLinkColorDark, DefPreviewLinkColorDark);
  FPreview.BreakOnNewline := FBreakOnNewline;
  FPreview.AllowRemoteImages := FAllowRemoteImages;
  FPreview.ResourcePath := FPreviewPath;
end;

{ ---------- 表示・非表示と境目（4.4） ---------- }

{ 境目をプレビューの隣に並べ直す（LCL の TSplitter は、隣の部品を位置で決めるため） }
procedure TCPreview.PlaceSplitter;
begin
  if FSplitter = nil then Exit;
  case Align of
    alRight: FSplitter.Left := Left - FSplitter.Width;
    alLeft: FSplitter.Left := Left + Width;
    alBottom: FSplitter.Top := Top - FSplitter.Height;
    alTop: FSplitter.Top := Top + Height;
  end;
end;

{ 境目の色を、表示元の Theme に合わせる（TCMonacoEditor の中の境目と同じ色。4.4） }
procedure TCPreview.ApplySplitterColor;
var
  Dark: Boolean;
begin
  if (FSplitter = nil) or (csDesigning in ComponentState) then Exit;
  if FSource is TCsEditor then Dark := TCsEditor(FSource).IsDarkTheme else Dark := CsOsIsDark;
  if Dark then FSplitter.Color := TColor($2B2B2B) else FSplitter.Color := TColor($E5E5E5);
end;

procedure TCPreview.VisibleChanged;
begin
  inherited VisibleChanged;
  if csLoading in ComponentState then Exit;
  if FSplitter <> nil then
  begin
    if Visible then PlaceSplitter;
    FSplitter.Visible := Visible;
  end;
  { 表示したとき、隠れている間の変更を反映する }
  if Visible and (FSource <> nil) and not (csDesigning in ComponentState) then Refresh;
end;

procedure TCPreview.SetSplitter(AValue: TSplitter);
begin
  if FSplitter = AValue then Exit;
  if FSplitter <> nil then FSplitter.RemoveFreeNotification(Self);
  FSplitter := AValue;
  if FSplitter <> nil then
  begin
    FSplitter.FreeNotification(Self);
    if not (csLoading in ComponentState) then FSplitter.Visible := Visible;
    ApplySplitterColor;
  end;
end;

{ ---------- 表示元とのやり取り（3.2） ---------- }

procedure TCPreview.SetSource(ASource: TComponent);
begin
  if ASource = FSource then Exit;
  if FSource <> nil then FSource.RemoveFreeNotification(Self);
  FSource := ASource;
  if FSource <> nil then FSource.FreeNotification(Self);
  ApplySplitterColor;
  Refresh;
end;

procedure TCPreview.SourceChanged(ASource: TComponent);
begin
  if (ASource = nil) or (ASource <> FSource) then Exit;   { 表示元でない TCsEditor からの知らせは無視する }
  FTimer.Enabled := False;
  if FDelayMs <= 0 then
    Refresh
  else
    FTimer.Enabled := True;                           { 入力が続く間は待つ }
end;

procedure TCPreview.SourceSwitched(ASource: TComponent);
begin
  if (ASource = nil) or (ASource <> FSource) then Exit;
  ApplySplitterColor;                                 { 配色を変えたときも来る }
  Refresh;
end;

procedure TCPreview.SourceScrolled(ASource: TComponent; ALine: Double);
begin
  if (ASource = nil) or (ASource <> FSource) or (FPreview = nil) then Exit;
  if FSyncScroll = ssNone then Exit;
  if GetTickCount64 < FSuppressUntil then Exit;      { プレビューから動かした直後は、跳ね返りを抑える }
  if not Visible then Exit;
  FPreview.SetTopLine(ALine);
end;

procedure TCPreview.SourceRemoved(ASource: TComponent);
begin
  if (ASource = nil) or (ASource <> FSource) then Exit;
  FSource.RemoveFreeNotification(Self);
  FSource := nil;
  FTimer.Enabled := False;
  if FPreview <> nil then FPreview.Clear;
end;

{ ---------- 作り直す（5.1） ---------- }

procedure TCPreview.Refresh;
var
  E: TCsEditor;
  T: string;
begin
  FTimer.Enabled := False;
  if FPreview = nil then Exit;
  if FSource = nil then
  begin
    FPreview.Clear;
    Exit;
  end;
  if not Visible then
  begin
    FDirty := True;                                   { 表示したときに作り直す }
    Exit;
  end;
  FDirty := False;
  E := TCsEditor(FSource);
  if FPreview.Theme <> ThemeNames[E.Theme] then FPreview.Theme := ThemeNames[E.Theme];
  { 印刷の PDF の名前：タブの名前から拡張子を外す（abc.md → abc、無題 → 無題） }
  T := E.Caption;
  if ChangeFileExt(T, '') <> '' then T := ChangeFileExt(T, '');
  FPreview.DocTitle := T;
  if SameText(E.Language, 'markdown') then
    FPreview.ShowMarkdown(E.Text, ExtractFilePath(E.FileName))
  else
    FPreview.ShowCode(E.Text, E.Language);
  FPreview.SetTopLine(E.TopLine);
end;

procedure TCPreview.TimerTick(Sender: TObject);
begin
  Refresh;
end;

{ ---------- スクロール（5.3） ---------- }

procedure TCPreview.InnerScrollLine(Sender: TObject; Line: Double);
begin
  if (FSyncScroll <> ssBoth) or (FSource = nil) then Exit;
  TCsEditor(FSource).ScrollToLine(Line);
  FSuppressUntil := GetTickCount64 + 300;            { エディタからの知らせを 300 ミリ秒抑える }
end;

{ ---------- 印刷（5.4） ---------- }

procedure TCPreview.PrintFor(ASource: TComponent);
begin
  SetSource(ASource);
  if FPreview = nil then Exit;
  if not Visible then
  begin
    FShownForPrint := True;                          { 印刷の間だけ出す }
    Visible := True;
  end;
  Refresh;
  FPreview.Print;
end;

procedure TCPreview.Print;
begin
  if FSource <> nil then PrintFor(FSource);
end;

procedure TCPreview.InnerPrintKey(Sender: TObject);
begin
  Print;
end;

procedure TCPreview.InnerAfterPrint(Sender: TObject);
begin
  if FShownForPrint then
  begin
    FShownForPrint := False;
    Visible := False;
  end;
end;

{ ---------- ファイルを開く・エラー（5.5） ---------- }

procedure TCPreview.InnerOpenMarkdown(Sender: TObject; const AFileName: string);
begin
  { 中の部品の知らせの途中でダイアログを出さないよう、あとで行う }
  FOpenQueue.Add(AFileName);
  Application.QueueAsyncCall(@AsyncOpenMarkdown, 0);
end;

procedure TCPreview.AsyncOpenMarkdown(Data: PtrInt);
var
  FN: string;
begin
  while (FOpenQueue <> nil) and (FOpenQueue.Count > 0) do
  begin
    FN := FOpenQueue[0];
    FOpenQueue.Delete(0);
    if Assigned(FOnOpenMarkdown) then
      FOnOpenMarkdown(Self, FN)
    else if FSource <> nil then
      try
        TCsEditor(FSource).OpenFile(FN);             { MultiDocument に従う }
      except
        on E: Exception do InnerError(Self, FN + ': ' + E.Message);
      end;
  end;
end;

procedure TCPreview.InnerError(Sender: TObject; const AMessage: string);
begin
  if Assigned(FOnError) then
  begin
    FOnError(Self, AMessage);
    Exit;
  end;
  FErrQueue.Add(AMessage);
  Application.QueueAsyncCall(@AsyncShowError, 0);
end;

procedure TCPreview.AsyncShowError(Data: PtrInt);
var
  S: string;
begin
  while (FErrQueue <> nil) and (FErrQueue.Count > 0) do
  begin
    S := FErrQueue[0];
    FErrQueue.Delete(0);
    if GShownErrors.IndexOf(S) >= 0 then Continue;  { 同じメッセージは 1 回だけ }
    GShownErrors.Add(S);
    MessageDlg(S, mtError, [mbOK], 0);
  end;
end;

{ ---------- フォント（5.6） ---------- }

procedure TCPreview.InnerFontSizeChange(Sender: TObject);
begin
  if FPreview <> nil then FFontSize := FPreview.FontSize;   { オブジェクトインスペクタの値とずれないように }
end;

{ ---------- プロパティ ---------- }

function TCPreview.GetReady: Boolean;
begin
  Result := (FPreview <> nil) and FPreview.Ready;
end;

procedure TCPreview.SetFontSize(AValue: Integer);
begin
  if AValue < 8 then AValue := 8;
  if AValue > 48 then AValue := 48;
  FFontSize := AValue;
  if FPreview <> nil then FPreview.FontSize := AValue;
end;

procedure TCPreview.SetColorScheme(AValue: TCMColorScheme);
begin
  FColorScheme := AValue;
  ApplyAll;
end;

procedure TCPreview.SetBackColorLight(AValue: TColor);
begin
  FBackColorLight := AValue;
  ApplyAll;
end;

procedure TCPreview.SetBackColorDark(AValue: TColor);
begin
  FBackColorDark := AValue;
  ApplyAll;
end;

procedure TCPreview.SetTextColorLight(AValue: TColor);
begin
  FTextColorLight := AValue;
  ApplyAll;
end;

procedure TCPreview.SetTextColorDark(AValue: TColor);
begin
  FTextColorDark := AValue;
  ApplyAll;
end;

procedure TCPreview.SetLinkColorLight(AValue: TColor);
begin
  FLinkColorLight := AValue;
  ApplyAll;
end;

procedure TCPreview.SetLinkColorDark(AValue: TColor);
begin
  FLinkColorDark := AValue;
  ApplyAll;
end;

procedure TCPreview.SetBreakOnNewline(AValue: Boolean);
begin
  FBreakOnNewline := AValue;
  if FPreview <> nil then FPreview.BreakOnNewline := AValue;
end;

procedure TCPreview.SetAllowRemoteImages(AValue: Boolean);
begin
  FAllowRemoteImages := AValue;
  if FPreview <> nil then FPreview.AllowRemoteImages := AValue;
end;

procedure TCPreview.SetDelayMs(AValue: Integer);
begin
  FDelayMs := AValue;
  if AValue > 0 then FTimer.Interval := AValue;
end;

procedure TCPreview.SetPreviewPath(const AValue: string);
begin
  FPreviewPath := AValue;
  if FPreview <> nil then FPreview.ResourcePath := AValue;
end;

initialization
  GShownErrors := TStringList.Create;

finalization
  FreeAndNil(GShownErrors);

end.
