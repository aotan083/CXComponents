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
  Classes, SysUtils, Types, Math, Controls, Graphics, ExtCtrls, Forms, Dialogs, LCLType, LCLProc, LMessages,
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

  TCPreview = class;

  { TCPreviewGrip
    TCPreview の内側の端（Align が alRight なら左端）にある、幅を変えるための細い帯。
    マウスを乗せたとき・ドラッグ中に青い線（TCSplitter と同じ見た目）を出し、TCPreview の幅（上下なら高さ）を変える。
    アプリが TSplitter を別に置かなくても、TCPreview の大きさを変えられる。 }
  TCPreviewGrip = class(TCustomControl)
  private
    FHot: Boolean;
    FDragging: Boolean;
    FStartPos: Integer;       { ドラッグを始めたときのマウスの位置（画面。軸方向） }
    FStartSize: Integer;      { ドラッグを始めたときの TCPreview の大きさ（軸方向） }
    function Panel: TCPreview;
    function AxisPos: Integer;
  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure CaptureChanged; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { TCPreview }

  TCPreview = class(TCustomPanel)
  private
    FPreview: TCMMarkdownPreview;        { 中の部品。実行時だけ作る（4.1） }
    FSource: TComponent;                 { 表示元の TCsEditor（3章） }
    FTimer: TTimer;                      { 入力が止まるのを待つ（5.2） }
    FSplitter: TSplitter;
    FGrip: TCPreviewGrip;                { 内側の端の、幅を変える帯（実行時だけ） }
    FAllowResize: Boolean;
    FHighlightColor: TColor;             { 幅を変える帯の青い線の色 }
    { 設計時：フォームデザイナの上で、帯をドラッグして大きさを変える（実行時は FGrip が行う） }
    FDesignHot: Boolean;
    FDesignDragging: Boolean;
    FDesignStartPos: Integer;
    FDesignStartSize: Integer;
    FDesignerPressLeft: Boolean;
    FShowRequested: Boolean;             { TCsEditor が、ShowPreview = True で出すよう求めた }
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
    procedure SetAllowResize(AValue: Boolean);
    procedure SetHighlightColor(AValue: TColor);
    procedure UpdateGrip;
    function DesignGripRect: TRect;
    function DesignAxisPos: Integer;
  protected
    procedure Loaded; override;
    procedure SetAlign(Value: TAlign); override;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure CMDesignHitTest(var Message: TCMDesignHitTest); message CM_DESIGNHITTEST;
    procedure VisibleChanged; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { TCsEditor の ShowPreview = True による、起動時に出す求め。出さない求めしかなければ、起動時は隠れる }
    procedure RequestShow;
    { 境目の色（表示元の Theme に合わせる。ダーク #2B2B2B、ライト #E5E5E5） }
    function GripColor: TColor;
    { 帯をドラッグしたときの、新しい大きさ。AStartSize：ドラッグを始めたときの大きさ（Align が alLeft・alRight なら幅、
      alTop・alBottom なら高さ）、ADelta：マウスが動いた量（画面。右・下が正）。alRight・alBottom は、
      帯が内側（左・上）にあるので、左（上）へ動かす（ADelta が負）と大きくなる。
      小さい方の限界は 100px（表示スケールで換算）、大きい方の限界は、親のクライアント領域から 100px 残した大きさ }
    function CalcDragSize(AStartSize, ADelta: Integer): Integer;
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
    property AllowResize: Boolean read FAllowResize write SetAllowResize default True;
    property HighlightColor: TColor read FHighlightColor write SetHighlightColor default clHighlight;
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
  LCLIntf, uCsEditor, uCXLang;

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
  FAllowResize := True;
  FHighlightColor := clHighlight;
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
    { 幅を変える帯（実行時だけ）。Align に合わせて端に置く }
    FGrip := TCPreviewGrip.Create(Self);
    FGrip.Parent := Self;
    UpdateGrip;
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
  UpdateGrip;
  { 実行時は、既定では隠して始める。TCsEditor の ShowPreview = True で出すよう求められたときだけ出す
    （求めが先に届いていても、後から来ても同じになる）。設計時の Visible は、そのまま保つ }
  if not (csDesigning in ComponentState) and not FShowRequested and Visible then
  begin
    Visible := False;
    if FSplitter <> nil then FSplitter.Visible := False;
  end;
end;

{ TCsEditor（ShowPreview = True）から、起動時に出す求め }
procedure TCPreview.RequestShow;
begin
  FShowRequested := True;
  if not Visible then Visible := True;
end;

{ 幅を変える帯の背景色：表示元の Theme に合わせる（境目と同じ色。4.4） }
function TCPreview.GripColor: TColor;
var
  Dark: Boolean;
begin
  if FSource is TCsEditor then Dark := TCsEditor(FSource).IsDarkTheme else Dark := CsOsIsDark;
  if Dark then Result := TColor($2B2B2B) else Result := TColor($E5E5E5);
end;

procedure TCPreview.SetAlign(Value: TAlign);
begin
  inherited SetAlign(Value);
  UpdateGrip;
end;

procedure TCPreview.SetAllowResize(AValue: Boolean);
begin
  if FAllowResize = AValue then Exit;
  FAllowResize := AValue;
  UpdateGrip;
end;

{ 幅を変える帯を、Align に合わせて端（alRight なら左端）に置く。
  使うのは、実行時で、AllowResize が True、Align が上下左右のどれかで、Splitter（アプリが置いた境目）が無いとき }
procedure TCPreview.UpdateGrip;
var
  Sz: Integer;
begin
  if FGrip = nil then Exit;
  Sz := Scale96ToFont(5);
  case Align of
    alRight: begin FGrip.Align := alLeft; FGrip.Width := Sz; FGrip.Cursor := crHSplit; end;
    alLeft: begin FGrip.Align := alRight; FGrip.Width := Sz; FGrip.Cursor := crHSplit; end;
    alBottom: begin FGrip.Align := alTop; FGrip.Height := Sz; FGrip.Cursor := crVSplit; end;
    alTop: begin FGrip.Align := alBottom; FGrip.Height := Sz; FGrip.Cursor := crVSplit; end;
  end;
  FGrip.Visible := FAllowResize and (FSplitter = nil) and (Align in [alLeft, alRight, alTop, alBottom]);
  FGrip.Invalidate;
end;

procedure TCPreview.SetHighlightColor(AValue: TColor);
begin
  if FHighlightColor = AValue then Exit;
  FHighlightColor := AValue;
  if FGrip <> nil then FGrip.Invalidate;
  Invalidate;
end;

function TCPreview.CalcDragSize(AStartSize, ADelta: Integer): Integer;
var
  MinSz, MaxSz, ParentSz: Integer;
begin
  if Align in [alRight, alBottom] then Result := AStartSize - ADelta else Result := AStartSize + ADelta;
  MinSz := Scale96ToFont(100);
  if Parent <> nil then
  begin
    if Align in [alLeft, alRight] then ParentSz := Parent.ClientWidth else ParentSz := Parent.ClientHeight;
    MaxSz := Max(MinSz, ParentSz - Scale96ToFont(100));
  end
  else MaxSz := MaxInt;
  Result := Max(MinSz, Min(Result, MaxSz));
end;

{ ---------- 設計時：帯のドラッグ ---------- }

{ 帯の場所（クライアント座標）。使えないとき（AllowResize が False・境目がある・Align が上下左右でない）は空 }
function TCPreview.DesignGripRect: TRect;
var
  Sz: Integer;
begin
  Result := Rect(0, 0, 0, 0);
  if not FAllowResize or (FSplitter <> nil) then Exit;
  Sz := Scale96ToFont(5);
  case Align of
    alRight: Result := Rect(0, 0, Sz, Height);
    alLeft: Result := Rect(Width - Sz, 0, Width, Height);
    alBottom: Result := Rect(0, 0, Width, Sz);
    alTop: Result := Rect(0, Height - Sz, Width, Height);
  end;
end;

function TCPreview.DesignAxisPos: Integer;
begin
  if Align in [alLeft, alRight] then Result := Mouse.CursorPos.X else Result := Mouse.CursorPos.Y;
end;

procedure TCPreview.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if not (csDesigning in ComponentState) or (Button <> mbLeft) then Exit;
  if PtInRect(DesignGripRect, Point(X, Y)) then
  begin
    FDesignDragging := True;
    MouseCapture := True;      { デザイナは MouseDown を直接呼ぶので、キャプチャしておく }
    FDesignStartPos := DesignAxisPos;
    if Align in [alLeft, alRight] then FDesignStartSize := Width else FDesignStartSize := Height;
    Invalidate;
  end;
end;

procedure TCPreview.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Hot: Boolean;
  NewSize: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if not (csDesigning in ComponentState) then Exit;
  if FDesignDragging then
  begin
    NewSize := CalcDragSize(FDesignStartSize, DesignAxisPos - FDesignStartPos);
    if Align in [alLeft, alRight] then Width := NewSize else Height := NewSize;
    Exit;
  end;
  Hot := PtInRect(DesignGripRect, Point(X, Y));
  if Hot <> FDesignHot then
  begin
    FDesignHot := Hot;
    Invalidate;
  end;
  if Hot then
  begin
    if Align in [alLeft, alRight] then Cursor := crHSplit else Cursor := crVSplit;
  end
  else Cursor := crDefault;
end;

procedure TCPreview.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if not (csDesigning in ComponentState) then Exit;
  if (Button = mbLeft) and FDesignDragging then
  begin
    FDesignDragging := False;
    MouseCapture := False;
    Invalidate;
    OwnerFormDesignerModified(Self);        { .lfm に Width・Height を保存するため }
    FDesignerPressLeft := True;             { デザイナは、この MouseUp の後に押下中の状態を残す（CMDesignHitTest 参照） }
  end;
end;

procedure TCPreview.MouseLeave;
begin
  inherited MouseLeave;
  if FDesignHot then
  begin
    FDesignHot := False;
    Invalidate;
  end;
end;

{ 設計時に、マウス操作を渡す場所。TCSideBar と同じ決まり（TCSideBar の CMDesignHitTest の説明を参照）：
  帯のドラッグ中は、どこでも 1。ドラッグを終えた後、次にボタンが押されるまでの、ボタンを押していない移動も 1
  （デザイナに渡さないことで、残っている押下中の状態から範囲選択の枠を出させない）。それ以外は、帯の上なら 1、
  そうでなければ 0（デザイナが部品を選ぶ） }
procedure TCPreview.CMDesignHitTest(var Message: TCMDesignHitTest);
const
  cMouseButtons = MK_LBUTTON or MK_RBUTTON or MK_MBUTTON;
var
  ButtonsDown: Boolean;
begin
  ButtonsDown := (Message.Keys and cMouseButtons) <> 0;
  if ButtonsDown then FDesignerPressLeft := False;
  if FDesignDragging then
    Message.Result := 1
  else if FDesignerPressLeft and not ButtonsDown then
    Message.Result := 1
  else if PtInRect(DesignGripRect, Point(Message.XPos, Message.YPos)) then
    Message.Result := 1
  else
    Message.Result := 0;
end;

procedure TCPreview.Paint;
var
  G: TRect;
  T: Integer;
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
  { 設計時：幅を変える帯の中央に、HighlightColor の線（ドラッグできる場所と、実行時の線の色が分かる） }
  G := DesignGripRect;
  if G.Right > G.Left then
  begin
    T := Max(1, Scale96ToFont(2));
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := CXSplitLineColor(FHighlightColor);
    if Align in [alLeft, alRight] then
      Canvas.FillRect(Rect(G.Left + (G.Right - G.Left - T) div 2, G.Top, G.Left + (G.Right - G.Left - T) div 2 + T, G.Bottom))
    else
      Canvas.FillRect(Rect(G.Left, G.Top + (G.Bottom - G.Top - T) div 2, G.Right, G.Top + (G.Bottom - G.Top - T) div 2 + T));
  end;
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
  FPreview.BackColorDark := CMColorToHex(CMDarkBackColor(FBackColorDark), DefPreviewBackColorDark);
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
  UpdateGrip;
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

{ ---------- TCPreviewGrip（内側の端の、幅を変える帯） ---------- }

constructor TCPreviewGrip.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csCaptureMouse, csNoDesignSelectable] - [csAcceptsControls];
  TabStop := False;
  Visible := False;
end;

function TCPreviewGrip.Panel: TCPreview;
begin
  Result := TCPreview(Parent);
end;

{ マウスの位置（画面。TCPreview の軸方向）。帯は TCPreview の大きさで動くので、帯の座標ではなく画面の座標を使う }
function TCPreviewGrip.AxisPos: Integer;
begin
  if Panel.Align in [alLeft, alRight] then Result := Mouse.CursorPos.X else Result := Mouse.CursorPos.Y;
end;

procedure TCPreviewGrip.Paint;
var
  T, M: Integer;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := Panel.GripColor;
  Canvas.FillRect(ClientRect);
  if FHot or FDragging then
  begin
    T := Max(1, Scale96ToFont(2));
    Canvas.Brush.Color := CXSplitLineColor(Panel.HighlightColor);  { TCSplitter と同じ青い線（色は HighlightColor） }
    if Panel.Align in [alLeft, alRight] then
    begin
      M := (Width - T) div 2;
      Canvas.FillRect(Rect(M, 0, M + T, Height));
    end
    else
    begin
      M := (Height - T) div 2;
      Canvas.FillRect(Rect(0, M, Width, M + T));
    end;
  end;
end;

procedure TCPreviewGrip.MouseEnter;
begin
  inherited MouseEnter;
  if not FHot then
  begin
    FHot := True;
    Invalidate;
  end;
end;

procedure TCPreviewGrip.MouseLeave;
begin
  inherited MouseLeave;
  if FHot then
  begin
    FHot := False;
    Invalidate;
  end;
end;

procedure TCPreviewGrip.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  FDragging := True;
  MouseCapture := True;
  FStartPos := AxisPos;
  if Panel.Align in [alLeft, alRight] then FStartSize := Panel.Width else FStartSize := Panel.Height;
  Invalidate;
end;

{ ドラッグ中：マウスの動いた分だけ、TCPreview の大きさを変える。
  alRight・alBottom は、帯が内側（左・上）にあるので、左（上）へ動かすと大きくなる。小さい方の限界は 100px（表示スケールで換算）、
  大きい方の限界は、親のクライアント領域から、ほかの部品のために 100px 残した大きさ }
procedure TCPreviewGrip.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  NewSize: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if not FDragging then Exit;
  NewSize := Panel.CalcDragSize(FStartSize, AxisPos - FStartPos);
  if Panel.Align in [alLeft, alRight] then Panel.Width := NewSize else Panel.Height := NewSize;
end;

procedure TCPreviewGrip.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button = mbLeft) and FDragging then
  begin
    FDragging := False;
    MouseCapture := False;
    Invalidate;
  end;
end;

procedure TCPreviewGrip.CaptureChanged;
begin
  inherited CaptureChanged;
  if FDragging and not MouseCapture then
  begin
    FDragging := False;
    Invalidate;
  end;
end;

initialization
  GShownErrors := TStringList.Create;

finalization
  FreeAndNil(GShownErrors);

end.
