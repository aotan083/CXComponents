{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ uCSplitter
  TCSplitter：TSplitter と同じ使い方で、マウスを乗せたとき・ドラッグ中に、色の付いた線を出す分割線（実行時パッケージ cx）。
  ・分割の仕組み（ResizeAnchor・ResizeStyle・MinSize・OnMoved など）は TSplitter のまま
  ・線の色は HighlightColor（既定は clHighlight。テーマ・ダーク表示に追従する）
  ・カーソルは SplitCursor で変えられる（既定は TSplitter と同じ）
  ・OnMouseEnter・OnMouseLeave・OnMouseMove・OnMouseDown・OnMouseUp を、オブジェクトインスペクタに出す
  同じユニットに TCPairSplitter（TPairSplitter と同じ使い方で、側ごとに隠せる・青い線の分割）も入っている。
  設計書：docs\TCSplitter_Design.md・docs\TCPairSplitter_Design.md }
unit uCSplitter;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Math, Controls, ExtCtrls, Graphics, LCLType, LCLIntf, LCLProc, LMessages;

const
  cLineWidth96 = 2;     // 線の太さ（96dpi のときの値）

type

  { TCSplitter }

  TCSplitter = class(TSplitter)
  private
    FHighlightColor: TColor;
    FSplitCursor: TCursor;
    FHot: Boolean;          // マウスが乗っている
    FDragging: Boolean;     // 左ボタンを押して、ドラッグ中
    procedure SetHighlightColor(AValue: TColor);
    procedure SetSplitCursor(AValue: TCursor);
  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure CaptureChanged; override;
    procedure UpdateCursor; override;
  public
    constructor Create(TheOwner: TComponent); override;
  published
    property HighlightColor: TColor read FHighlightColor write SetHighlightColor default clHighlight;
    property SplitCursor: TCursor read FSplitCursor write SetSplitCursor default crDefault;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseDown;
    property OnMouseUp;
  end;

  { ---------- TCPairSplitter ---------- }

  TCPairSplitterType = (cpsHorizontal, cpsVertical);

  TCPairSplitter = class;

  { TCPairSplitterSide：TCPairSplitter の 2 つの側（Side1・Side2）。この上に部品を置く。
    Visible := False（Hide）で隠すと、もう片方が全体に広がる。Visible := True（Show）で元に戻る。
    両方を隠すことはできない（後から隠そうとした側は隠れない） }
  TCPairSplitterSide = class(TCustomPanel)
  private
    function GetSplitter: TCPairSplitter;
  protected
    procedure SetParent(AParent: TWinControl); override;
    procedure SetVisible(Value: Boolean); override;
    procedure Paint; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    property Splitter: TCPairSplitter read GetSplitter;
  published
    property ChildSizing;
    property Color;
    property Constraints;
    property Cursor;
    property Enabled;
    property ParentColor;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property Visible;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnResize;
  end;

  { TCPairSplitter：TPairSplitter と同じ使い方の、2 つの側とその間の境目。
    ・側ごとに隠せる（TCPairSplitterSide）。隠すと、もう片方が全体に広がり、出すと元に戻る
    ・境目は、マウスを乗せたとき・ドラッグ中に、HighlightColor の青い線を出す（TCSplitter と同じ）
    ・設計時も、境目をドラッグして Position を変えられる }
  TCPairSplitter = class(TCustomControl)
  private
    FSides: array[0..1] of TCPairSplitterSide;
    FSplitterType: TCPairSplitterType;
    FPosition: Integer;               // 側 1 の幅（縦なら高さ）。隠している間も覚えておく
    FSplitterWidth: Integer;          // 境目の太さ
    FHighlightColor: TColor;
    FSplitCursor: TCursor;
    FOnMoved: TNotifyEvent;
    FNoCreateSides: Boolean;
    FHot: Boolean;
    FDragging: Boolean;
    FDragStartAxis: Integer;
    FDragStartPos: Integer;
    FLayouting: Boolean;
    FDesignerPressLeft: Boolean;      // 設計時：境目が MouseUp を処理した後、デザイナが押下中の状態を残している
    function GetSide(Index: Integer): TCPairSplitterSide;
    function GetPosition: Integer;
    procedure SetPosition(AValue: Integer);
    procedure SetSplitterType(AValue: TCPairSplitterType);
    procedure SetSplitterWidth(AValue: Integer);
    procedure SetHighlightColor(AValue: TColor);
    procedure SetSplitCursor(AValue: TCursor);
    function Total: Integer;                       // 分ける向きの全体の大きさ
    function BarSize: Integer;                     // 境目の太さ（表示スケール済み）
    function BarShown: Boolean;                    // 境目を出すか（2 つの側が見えているとき）
    function ClampPos(AValue: Integer): Integer;   // 側 1 の大きさを、範囲に収める
    function BarRect: TRect;
    function Axis(X, Y: Integer): Integer;
    procedure SetHot(AValue: Boolean);
  protected
    procedure AddSide(ASide: TCPairSplitterSide);
    procedure RemoveSide(ASide: TCPairSplitterSide);
    function OtherSideHidden(ASide: TCPairSplitterSide): Boolean;
    procedure CreateSides;
    procedure ApplyLayout;
    procedure CreateWnd; override;
    procedure Loaded; override;
    procedure Resize; override;
    procedure Paint; override;
    procedure DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
      const AXProportion, AYProportion: Double); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure CaptureChanged; override;
    procedure CMDesignHitTest(var Message: TCMDesignHitTest); message CM_DESIGNHITTEST;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    function ChildClassAllowed(ChildClass: TClass): Boolean; override;
    property Sides[Index: Integer]: TCPairSplitterSide read GetSide;
    property Side1: TCPairSplitterSide index 0 read GetSide;
    property Side2: TCPairSplitterSide index 1 read GetSide;
  published
    property Align;
    property Anchors;
    property BorderSpacing;
    property Color default clBtnFace;
    property Constraints;
    property Enabled;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property Visible;
    property SplitterType: TCPairSplitterType read FSplitterType write SetSplitterType default cpsHorizontal;
    property Position: Integer read GetPosition write SetPosition;
    property SplitterWidth: Integer read FSplitterWidth write SetSplitterWidth default 5;
    property HighlightColor: TColor read FHighlightColor write SetHighlightColor default clHighlight;
    property SplitCursor: TCursor read FSplitCursor write FSplitCursor default crDefault;
    property OnMoved: TNotifyEvent read FOnMoved write FOnMoved;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnResize;
    property OnChangeBounds;
  end;

implementation

uses
  uCXLang;

{ TCSplitter }

constructor TCSplitter.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FHighlightColor := clHighlight;
  FSplitCursor := crDefault;
  FHot := False;
  FDragging := False;
end;

procedure TCSplitter.SetHighlightColor(AValue: TColor);
begin
  if FHighlightColor = AValue then Exit;
  FHighlightColor := AValue;
  Invalidate;
end;

procedure TCSplitter.SetSplitCursor(AValue: TCursor);
begin
  if FSplitCursor = AValue then Exit;
  FSplitCursor := AValue;
  UpdateCursor;
end;

{ カーソル：使えないときは標準、SplitCursor があればそれ、なければ TSplitter と同じ（向きで決まる） }
procedure TCSplitter.UpdateCursor;
begin
  if not Enabled then
    Cursor := crDefault
  else if FSplitCursor <> crDefault then
    Cursor := FSplitCursor
  else
    inherited UpdateCursor;
end;

procedure TCSplitter.MouseEnter;
begin
  inherited MouseEnter;
  if (csDesigning in ComponentState) or not Enabled then Exit;
  if not FHot then
  begin
    FHot := True;
    Invalidate;
  end;
end;

procedure TCSplitter.MouseLeave;
begin
  inherited MouseLeave;
  if FHot then
  begin
    FHot := False;
    Invalidate;
  end;
end;

procedure TCSplitter.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = mbLeft) and Enabled and not (csDesigning in ComponentState) then
  begin
    FDragging := True;
    Invalidate;
  end;
end;

procedure TCSplitter.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button = mbLeft) and FDragging then
  begin
    FDragging := False;
    Invalidate;
  end;
end;

{ マウスアップが届かないまま、キャプチャが外れたとき、線が残らないようにする }
procedure TCSplitter.CaptureChanged;
begin
  inherited CaptureChanged;
  if FDragging and not MouseCapture then
  begin
    FDragging := False;
    Invalidate;
  end;
end;

procedure TCSplitter.Paint;
var
  T, M: Integer;
begin
  inherited Paint;              // TSplitter の見た目（OnPaint があればそれ）
  if (csDesigning in ComponentState) or not Enabled then Exit;
  if not (FHot or FDragging) then Exit;
  T := Max(1, Scale96ToFont(cLineWidth96));
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := CXSplitLineColor(FHighlightColor);
  if ResizeAnchor in [akLeft, akRight] then
  begin
    M := (Width - T) div 2;                       // 縦の線（左右に分割）
    Canvas.FillRect(Rect(M, 0, M + T, Height));
  end
  else
  begin
    M := (Height - T) div 2;                      // 横の線（上下に分割）
    Canvas.FillRect(Rect(0, M, Width, M + T));
  end;
end;

{ ================================================================== }
{ TCPairSplitterSide                                                 }
{ ================================================================== }

constructor TCPairSplitterSide.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  ControlStyle := ControlStyle - [csSetCaption] + [csAcceptsControls];
  SetTextBuf('');
  BevelOuter := bvNone;
  BevelInner := bvNone;
end;

destructor TCPairSplitterSide.Destroy;
begin
  { 壊れる前に、親の境目の側の一覧から外す（設計時に消したときは、境目が新しい側を作り直す） }
  if (Parent is TCPairSplitter) then
    TCPairSplitter(Parent).RemoveSide(Self);
  inherited Destroy;
end;

function TCPairSplitterSide.GetSplitter: TCPairSplitter;
begin
  if Parent is TCPairSplitter then
    Result := TCPairSplitter(Parent)
  else
    Result := nil;
end;

{ 親が変わったら、境目の側の一覧に入れる・外す（TPairSplitterSide と同じ） }
procedure TCPairSplitterSide.SetParent(AParent: TWinControl);
var
  OldSplitter: TCPairSplitter;
  Deleting: Boolean;
begin
  CheckNewParent(AParent);
  OldSplitter := Splitter;
  if OldSplitter <> nil then
  begin
    OldSplitter.RemoveSide(Self);
    Deleting := (csDestroying in OldSplitter.ComponentState) or (wcfDesignerDeleting in FWinControlFlags);
  end
  else
    Deleting := False;
  inherited SetParent(AParent);
  if (not Deleting) and (Splitter <> nil) then
    Splitter.AddSide(Self);
end;

{ 隠す・出す。もう片方がすでに隠れているときは、隠さない（両方は隠せない）。
  変わったら、境目が並べ直す（隠した側の分、もう片方が広がる） }
procedure TCPairSplitterSide.SetVisible(Value: Boolean);
var
  S: TCPairSplitter;
begin
  S := Splitter;
  if (not Value) and (S <> nil) and not (csLoading in ComponentState) and not (csLoading in S.ComponentState)
    and S.OtherSideHidden(Self) then
    Exit;
  inherited SetVisible(Value);
  if S <> nil then S.ApplyLayout;
end;

{ 設計時：点線の枠（TPairSplitterSide と同じ見た目） }
procedure TCPairSplitterSide.Paint;
begin
  inherited Paint;
  if csDesigning in ComponentState then
  begin
    Canvas.Pen.Style := psDash;
    Canvas.Pen.Color := clGrayText;
    Canvas.Brush.Style := bsClear;
    Canvas.Rectangle(0, 0, Width, Height);
  end;
end;

{ ================================================================== }
{ TCPairSplitter                                                     }
{ ================================================================== }

constructor TCPairSplitter.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  ControlStyle := ControlStyle - [csAcceptsControls] + [csCaptureMouse, csClickEvents];
  FSplitterType := cpsHorizontal;
  FPosition := 45;
  FSplitterWidth := 5;
  FHighlightColor := clHighlight;
  FSplitCursor := crDefault;
  Color := clBtnFace;
  with GetControlClassDefaultSize do
    SetInitialBounds(0, 0, CX, CY);
  { 実行時は、すぐに側を作る。設計時は、窓ができるとき（CreateWnd）に作る }
  if not (csDesigning in ComponentState) then
    CreateSides;
end;

destructor TCPairSplitter.Destroy;
begin
  FNoCreateSides := True;
  inherited Destroy;
end;

class function TCPairSplitter.GetControlClassDefaultSize: TSize;
begin
  Result.CX := 90;
  Result.CY := 90;
end;

function TCPairSplitter.ChildClassAllowed(ChildClass: TClass): Boolean;
begin
  Result := ChildClass.InheritsFrom(TCPairSplitterSide);
end;

function TCPairSplitter.GetSide(Index: Integer): TCPairSplitterSide;
begin
  if (Index < 0) or (Index > 1) then
    raise EListError.Create('TCPairSplitter.Sides: Index out of bounds');
  Result := FSides[Index];
end;

procedure TCPairSplitter.AddSide(ASide: TCPairSplitterSide);
var
  I: Integer;
begin
  if ASide = nil then Exit;
  for I := 0 to 1 do
    if FSides[I] = ASide then Exit;
  for I := 0 to 1 do
    if FSides[I] = nil then
    begin
      FSides[I] := ASide;
      ApplyLayout;
      Exit;
    end;
  raise EInvalidOperation.Create('TCPairSplitter: 側は 2 つまでです');
end;

procedure TCPairSplitter.RemoveSide(ASide: TCPairSplitterSide);
var
  I: Integer;
begin
  if ASide = nil then Exit;
  for I := 0 to 1 do
    if FSides[I] = ASide then FSides[I] := nil;
  { 設計時に側を消したら、新しい側を作る（TPairSplitter と同じ） }
  if (ComponentState * [csDesigning, csDestroying] = [csDesigning])
    and not (wcfDesignerDeleting in FWinControlFlags) then
    CreateSides;
end;

{ もう片方の側が隠れているか（隠そうとしている側が、最後に見えている側かを知るため） }
function TCPairSplitter.OtherSideHidden(ASide: TCPairSplitterSide): Boolean;
var
  Other: TCPairSplitterSide;
begin
  if ASide = FSides[0] then Other := FSides[1] else Other := FSides[0];
  Result := (Other <> nil) and not Other.Visible;
end;

{ 足りない側を作る。側は、境目の Owner が持つ（フォームに保存して読み込めるように） }
procedure TCPairSplitter.CreateSides;
var
  Side: TCPairSplitterSide;
  I: Integer;
begin
  if FNoCreateSides or (ComponentState * [csLoading, csDestroying] <> []) or
    ((Owner <> nil) and (csLoading in Owner.ComponentState)) then Exit;
  for I := 0 to 1 do
    if FSides[I] = nil then
    begin
      Side := TCPairSplitterSide.Create(Owner);
      Side.Parent := Self;
    end;
end;

procedure TCPairSplitter.CreateWnd;
begin
  CreateSides;
  inherited CreateWnd;
  ApplyLayout;
end;

procedure TCPairSplitter.Loaded;
begin
  inherited Loaded;
  CreateSides;
  ApplyLayout;
end;

procedure TCPairSplitter.Resize;
begin
  inherited Resize;
  ApplyLayout;
end;

{ 分ける向きの全体の大きさ }
function TCPairSplitter.Total: Integer;
begin
  if FSplitterType = cpsHorizontal then Result := ClientWidth else Result := ClientHeight;
end;

function TCPairSplitter.BarSize: Integer;
begin
  Result := Max(1, Scale96ToFont(FSplitterWidth));
end;

{ 境目は、2 つの側が両方見えているときだけ出す }
function TCPairSplitter.BarShown: Boolean;
begin
  Result := (FSides[0] <> nil) and (FSides[1] <> nil) and FSides[0].Visible and FSides[1].Visible;
end;

{ 側 1 の大きさを範囲に収める：下限は側 1 の Constraints（最小 1）、上限は、全体 − 境目 − 側 2 の下限 }
function TCPairSplitter.ClampPos(AValue: Integer): Integer;
var
  Min1, Min2, MaxP: Integer;
begin
  if FSplitterType = cpsHorizontal then
  begin
    Min1 := Max(1, FSides[0].Constraints.MinWidth);
    Min2 := Max(1, FSides[1].Constraints.MinWidth);
  end
  else
  begin
    Min1 := Max(1, FSides[0].Constraints.MinHeight);
    Min2 := Max(1, FSides[1].Constraints.MinHeight);
  end;
  MaxP := Total - BarSize - Min2;
  Result := AValue;
  if Result < Min1 then Result := Min1;
  if Result > MaxP then Result := MaxP;
  if Result < 0 then Result := 0;
end;

function TCPairSplitter.BarRect: TRect;
var
  P: Integer;
begin
  if not BarShown then Exit(Rect(0, 0, 0, 0));
  P := ClampPos(FPosition);
  if FSplitterType = cpsHorizontal then
    Result := Rect(P, 0, P + BarSize, ClientHeight)
  else
    Result := Rect(0, P, ClientWidth, P + BarSize);
end;

function TCPairSplitter.Axis(X, Y: Integer): Integer;
begin
  if FSplitterType = cpsHorizontal then Result := X else Result := Y;
end;

{ 2 つの側を並べる。
  ・両方見える：側 1 は Position の大きさ、側 2 は境目の後ろの残り全部
  ・片方だけ見える：見えている側が全体
  側の位置と大きさは、境目が決める（Align は使わない） }
procedure TCPairSplitter.ApplyLayout;
var
  W, H, P, B: Integer;
  V1, V2: Boolean;
begin
  if FLayouting or (FSides[0] = nil) or (FSides[1] = nil) then Exit;
  if ComponentState * [csLoading, csDestroying] <> [] then Exit;
  FLayouting := True;
  try
    W := ClientWidth;
    H := ClientHeight;
    V1 := FSides[0].Visible;
    V2 := FSides[1].Visible;
    if V1 and V2 then
    begin
      P := ClampPos(FPosition);
      B := BarSize;
      if FSplitterType = cpsHorizontal then
      begin
        FSides[0].SetBounds(0, 0, P, H);
        FSides[1].SetBounds(P + B, 0, Max(0, W - P - B), H);
      end
      else
      begin
        FSides[0].SetBounds(0, 0, W, P);
        FSides[1].SetBounds(0, P + B, W, Max(0, H - P - B));
      end;
    end
    else if V1 then
      FSides[0].SetBounds(0, 0, W, H)
    else if V2 then
      FSides[1].SetBounds(0, 0, W, H);
  finally
    FLayouting := False;
  end;
  Invalidate;
end;

function TCPairSplitter.GetPosition: Integer;
begin
  Result := FPosition;
end;

procedure TCPairSplitter.SetPosition(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  if FPosition = AValue then Exit;
  FPosition := AValue;
  ApplyLayout;
end;

procedure TCPairSplitter.SetSplitterType(AValue: TCPairSplitterType);
begin
  if FSplitterType = AValue then Exit;
  FSplitterType := AValue;
  ApplyLayout;
end;

procedure TCPairSplitter.SetSplitterWidth(AValue: Integer);
begin
  if AValue < 1 then AValue := 1;
  if FSplitterWidth = AValue then Exit;
  FSplitterWidth := AValue;
  ApplyLayout;
end;

procedure TCPairSplitter.SetHighlightColor(AValue: TColor);
begin
  if FHighlightColor = AValue then Exit;
  FHighlightColor := AValue;
  Invalidate;
end;

procedure TCPairSplitter.SetSplitCursor(AValue: TCursor);
begin
  FSplitCursor := AValue;
end;

{ 表示スケール：Position・SplitterWidth を拡大する（分ける向きに合わせて X か Y の倍率） }
procedure TCPairSplitter.DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
  const AXProportion, AYProportion: Double);
begin
  inherited DoAutoAdjustLayout(AMode, AXProportion, AYProportion);
  if AMode in [lapAutoAdjustWithoutHorizontalScrolling, lapAutoAdjustForDPI] then
  begin
    if FSplitterType = cpsHorizontal then
      FPosition := Round(FPosition * AXProportion)
    else
      FPosition := Round(FPosition * AYProportion);
    ApplyLayout;
  end;
end;

{ ---- 描画 ---- }

{ 境目の背景を Color で塗り、中央に線を引く。
  実行時にマウスを乗せたとき・ドラッグ中は、HighlightColor の太い線（TCSplitter と同じ）。それ以外は 1px の clBtnShadow の線 }
procedure TCPairSplitter.Paint;
var
  R: TRect;
  T, M: Integer;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
  R := BarRect;
  if R.Right <= R.Left then Exit;
  if (FHot or FDragging) and not (csDesigning in ComponentState) then
  begin
    T := Max(1, Scale96ToFont(cLineWidth96));
    Canvas.Brush.Color := CXSplitLineColor(FHighlightColor);
    if FSplitterType = cpsHorizontal then
    begin
      M := R.Left + (R.Right - R.Left - T) div 2;
      Canvas.FillRect(Rect(M, R.Top, M + T, R.Bottom));
    end
    else
    begin
      M := R.Top + (R.Bottom - R.Top - T) div 2;
      Canvas.FillRect(Rect(R.Left, M, R.Right, M + T));
    end;
  end
  else
  begin
    Canvas.Pen.Style := psSolid;
    Canvas.Pen.Color := clBtnShadow;
    Canvas.Pen.Width := 1;
    if FSplitterType = cpsHorizontal then
    begin
      M := (R.Left + R.Right) div 2;
      Canvas.Line(M, R.Top, M, R.Bottom);
    end
    else
    begin
      M := (R.Top + R.Bottom) div 2;
      Canvas.Line(R.Left, M, R.Right, M);
    end;
  end;
end;

{ ---- マウス（境目のドラッグ） ---- }

procedure TCPairSplitter.SetHot(AValue: Boolean);
begin
  if FHot = AValue then Exit;
  FHot := AValue;
  Invalidate;
end;

procedure TCPairSplitter.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not PtInRect(BarRect, Point(X, Y)) then Exit;
  FDragging := True;
  MouseCapture := True;           // 設計時はデザイナが MouseDown を直接呼ぶので、キャプチャしておく
  FDragStartAxis := Axis(X, Y);
  FDragStartPos := ClampPos(FPosition);
  Invalidate;
end;

procedure TCPairSplitter.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  NewPos: Integer;
  Cur: TCursor;
begin
  inherited MouseMove(Shift, X, Y);
  if FDragging then
  begin
    NewPos := ClampPos(FDragStartPos + (Axis(X, Y) - FDragStartAxis));
    if NewPos <> FPosition then
    begin
      FPosition := NewPos;
      ApplyLayout;
    end;
    Exit;
  end;
  if PtInRect(BarRect, Point(X, Y)) then
  begin
    SetHot(True);
    if FSplitCursor <> crDefault then
      Cur := FSplitCursor
    else if FSplitterType = cpsHorizontal then
      Cur := crHSplit
    else
      Cur := crVSplit;
    Cursor := Cur;
  end
  else
  begin
    SetHot(False);
    Cursor := crDefault;
  end;
end;

{ ドラッグ終了：位置が変わっていたら、実行時は OnMoved、設計時はデザイナに変更を知らせる（.lfm に Position を保存） }
procedure TCPairSplitter.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Moved: Boolean;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button <> mbLeft) or not FDragging then Exit;
  FDragging := False;
  MouseCapture := False;
  Moved := ClampPos(FPosition) <> FDragStartPos;
  Invalidate;
  if csDesigning in ComponentState then
  begin
    if Moved then OwnerFormDesignerModified(Self);
    FDesignerPressLeft := True;      // デザイナは、この MouseUp の後に押下中の状態を残す（CMDesignHitTest 参照）
  end
  else if Moved and Assigned(FOnMoved) then
    FOnMoved(Self);
end;

procedure TCPairSplitter.MouseLeave;
begin
  inherited MouseLeave;
  if not FDragging then
  begin
    SetHot(False);
    Cursor := crDefault;
  end;
end;

{ ボタンを押したままキャプチャが外れた（ドラッグ中に Alt+Tab など）：ドラッグをやめる（位置はそのまま） }
procedure TCPairSplitter.CaptureChanged;
begin
  inherited CaptureChanged;
  if FDragging and not MouseCapture and (GetKeyState(VK_LBUTTON) < 0) then
  begin
    FDragging := False;
    Invalidate;
  end;
end;

{ 設計時に、マウス操作を境目に渡す場所。TCSideBar と同じ決まり（TCSideBar の CMDesignHitTest の説明を参照）：
  ドラッグ中は、どこでも 1。ドラッグを終えた後、次にボタンが押されるまでの、ボタンを押していない移動も 1
  （デザイナに渡さないことで、残っている押下中の状態から範囲選択の枠を出させない）。それ以外は、境目の上なら 1、
  そうでなければ 0（デザイナが部品を選ぶ） }
procedure TCPairSplitter.CMDesignHitTest(var Message: TCMDesignHitTest);
const
  cMouseButtons = MK_LBUTTON or MK_RBUTTON or MK_MBUTTON;
var
  ButtonsDown: Boolean;
begin
  ButtonsDown := (Message.Keys and cMouseButtons) <> 0;
  if ButtonsDown then FDesignerPressLeft := False;
  if FDragging then
    Message.Result := 1
  else if FDesignerPressLeft and not ButtonsDown then
    Message.Result := 1
  else if PtInRect(BarRect, Point(Message.XPos, Message.YPos)) then
    Message.Result := 1
  else
    Message.Result := 0;
end;

initialization
  { .lfm から TCPairSplitterSide を読み込めるようにする }
  RegisterClass(TCPairSplitterSide);

end.
