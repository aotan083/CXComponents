{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ uCExpandPanel
  タイトルバー付きの伸縮するパネル（TCRollout）と、それを複数並べる入れ物（TCExpandPanel）。
  タイトルバー右側のボタンは Buttons に登録する（TCRolloutButton）。

  設計書：docs\TCExpandPanel_Design.md
 }
unit uCExpandPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Math,
  LCLType, LCLIntf, LCLProc, LMessages,
  Controls, Graphics, GraphType, Forms, Menus, ImgList, ExtCtrls,
  uCXLang;

type
  TCRollout = class;
  TCExpandPanel = class;

  { タイトルバーの位置（伸縮する向きも決める） }
  TCRolloutHeaderPosition = (hpTop, hpBottom, hpLeft, hpRight);
  { 入れ物の中でパネルを並べる向き }
  TCExpandOrientation = (eoVertical, eoHorizontal);
  { ボタンをいつも出すか、タイトルバーにマウスが乗ったときだけ出すか }
  TCRolloutButtonsShow = (bsAlways, bsHover);

  TCRolloutButtonEvent = procedure(Sender: TObject; Index: Integer) of object;
  TCRolloutExpandingEvent = procedure(Sender: TObject; var Allow: Boolean) of object;

  { TCRolloutButton
    タイトルバー右側のボタン 1 つ分の定義 }

  TCRolloutButton = class(TCollectionItem)
  private
    FImageIndex: TImageIndex;
    FHint: string;
    FDropDownMenu: TPopupMenu;
    FEnabled: Boolean;
    FVisible: Boolean;
    procedure SetImageIndex(AValue: TImageIndex);
    procedure SetHint(const AValue: string);
    procedure SetDropDownMenu(AValue: TPopupMenu);
    procedure SetEnabled(AValue: Boolean);
    procedure SetVisible(AValue: Boolean);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
  published
    property ImageIndex: TImageIndex read FImageIndex write SetImageIndex default -1;
    property Hint: string read FHint write SetHint;
    property DropDownMenu: TPopupMenu read FDropDownMenu write SetDropDownMenu;
    property Enabled: Boolean read FEnabled write SetEnabled default True;
    property Visible: Boolean read FVisible write SetVisible default True;
  end;

  { TCRolloutButtons }

  TCRolloutButtons = class(TOwnedCollection)
  private
    FRollout: TCRollout;
    function GetItem(Index: Integer): TCRolloutButton;
    procedure SetItem(Index: Integer; AValue: TCRolloutButton);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(AOwner: TCRollout);
    property Items[Index: Integer]: TCRolloutButton read GetItem write SetItem; default;
    property Rollout: TCRollout read FRollout;
  end;

  { TCRollout
    伸縮する 1 つのパネル。タイトルバー（矢印・Caption・ボタン）と、部品を置ける中身を持つ。
    単体でも、TCExpandPanel の中でも使える。 }

  TCRollout = class(TCustomControl)
  private
    FExpanded: Boolean;
    FHeaderPosition: TCRolloutHeaderPosition;
    FHeaderSize: Integer;
    FExpandedSize: Integer;
    FFill: Boolean;
    FShowArrow: Boolean;
    FImages: TCustomImageList;
    FImageChangeLink: TChangeLink;
    FImagesWidth: Integer;
    FButtons: TCRolloutButtons;
    FButtonsShow: TCRolloutButtonsShow;
    FAnimated: Boolean;
    FAnimationTime: Integer;
    FOpenT: Double;            // 開き具合（0 = 閉じている、1 = 開いている）
    FAnimTimer: TTimer;
    FAnimStart: QWord;
    FAnimFrom: Double;
    FSizing: Boolean;          // 自分で大きさを変えている（SetBounds で ExpandedSize を覚えない）
    FManaged: Boolean;         // 入れ物が配置している
    FHotHeader: Boolean;
    FHotButton: Integer;
    FDownButton: Integer;
    FDownHeader: Boolean;
    FMenuOpen: Boolean;
    FDesignerPressLeft: Boolean;
    FOnExpanding: TCRolloutExpandingEvent;
    FOnExpand: TNotifyEvent;
    FOnCollapse: TNotifyEvent;
    FOnButtonClick: TCRolloutButtonEvent;
    function GetExpandPanel: TCExpandPanel;
    procedure SetExpanded(AValue: Boolean);
    procedure SetHeaderPosition(AValue: TCRolloutHeaderPosition);
    procedure SetHeaderSize(AValue: Integer);
    procedure SetExpandedSize(AValue: Integer);
    procedure SetFill(AValue: Boolean);
    procedure SetShowArrow(AValue: Boolean);
    procedure SetImages(AValue: TCustomImageList);
    procedure SetImagesWidth(AValue: Integer);
    procedure SetButtons(AValue: TCRolloutButtons);
    procedure SetButtonsShow(AValue: TCRolloutButtonsShow);
    procedure SetAnimationTime(AValue: Integer);
    procedure ImageListChange(Sender: TObject);
    procedure ButtonsChanged;
    procedure LayoutChanged;
    function EventsEnabled: Boolean;
    // 実効の向きと大きさ
    function EffectivePosition: TCRolloutHeaderPosition;
    function IsVerticalHeader: Boolean;
    function HeaderThickness: Integer;
    function AxisSize: Integer;
    function LayoutSize(AFull: Integer): Integer;
    function CurrentSize: Integer;
    function OpenTarget: Double;
    function Animating: Boolean;
    function HeaderRect: TRect;
    procedure ApplyOwnSize;
    procedure SetBoundsManaged(ALeft, ATop, AWidth, AHeight: Integer);
    // アニメーション
    procedure StartOpen;
    procedure AnimTimerTick(Sender: TObject);
    procedure OpenChanged;
    // タイトルバーの部品の位置
    function ButtonSize: Integer;
    function ButtonRect(Index: Integer): TRect;
    function ButtonsShown: Boolean;
    function ButtonAt(X, Y: Integer): Integer;
    function ArrowRect: TRect;
    function TextRect: TRect;
    // マウス
    procedure SetHot(AIndex: Integer);
    procedure SetHeaderHot(AValue: Boolean);
    procedure ClickButton(AIndex: Integer);
    procedure PaintArrow(const R: TRect; ADir: Integer);
  protected
    procedure SetParent(NewParent: TWinControl); override;
    procedure SetBounds(ALeft, ATop, AWidth, AHeight: Integer); override;
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure TextChanged; override;
    procedure AdjustClientRect(var ARect: TRect); override;
    procedure DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
      const AXProportion, AYProportion: Double); override;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure CMHintShow(var Message: TLMessage); message CM_HINTSHOW;
    procedure CMDesignHitTest(var Message: TCMDesignHitTest); message CM_DESIGNHITTEST;
    procedure CMEnabledChanged(var Message: TLMessage); message CM_ENABLEDCHANGED;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    property ExpandPanel: TCExpandPanel read GetExpandPanel;
  published
    property Caption;
    property Expanded: Boolean read FExpanded write SetExpanded default True;
    property HeaderPosition: TCRolloutHeaderPosition read FHeaderPosition
      write SetHeaderPosition default hpTop;
    property HeaderSize: Integer read FHeaderSize write SetHeaderSize default 24;
    property ExpandedSize: Integer read FExpandedSize write SetExpandedSize default 150;
    property Fill: Boolean read FFill write SetFill default False;
    property ShowArrow: Boolean read FShowArrow write SetShowArrow default True;
    property Images: TCustomImageList read FImages write SetImages;
    property ImagesWidth: Integer read FImagesWidth write SetImagesWidth default 0;
    property Buttons: TCRolloutButtons read FButtons write SetButtons;
    property ButtonsShow: TCRolloutButtonsShow read FButtonsShow write SetButtonsShow
      default bsAlways;
    property Animated: Boolean read FAnimated write FAnimated default True;
    property AnimationTime: Integer read FAnimationTime write SetAnimationTime default 150;
    property OnExpanding: TCRolloutExpandingEvent read FOnExpanding write FOnExpanding;
    property OnExpand: TNotifyEvent read FOnExpand write FOnExpand;
    property OnCollapse: TNotifyEvent read FOnCollapse write FOnCollapse;
    property OnButtonClick: TCRolloutButtonEvent read FOnButtonClick write FOnButtonClick;
    property Align;
    property Anchors;
    property BorderSpacing;
    property Color;
    property Constraints;
    property Enabled;
    property Font;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property Visible;
  end;

  { TCExpandPanel
    TCRollout を複数並べる入れ物。AddPanel で追加する。 }

  TCExpandPanel = class(TCustomControl)
  private
    FPanels: TFPList;
    FOrientation: TCExpandOrientation;
    FMultiple: Boolean;
    FSpacing: Integer;
    FScrollable: Boolean;
    FScrollPos: Integer;
    FContentLength: Integer;
    FViewLength: Integer;
    FInLayout: Boolean;
    FBarVisible: Boolean;
    function GetPanel(Index: Integer): TCRollout;
    function GetPanelCount: Integer;
    procedure SetOrientation(AValue: TCExpandOrientation);
    procedure SetMultiple(AValue: Boolean);
    procedure SetSpacing(AValue: Integer);
    procedure SetScrollable(AValue: Boolean);
    procedure AddRollout(ARollout: TCRollout);
    procedure RemoveRollout(ARollout: TCRollout);
    procedure RolloutToggled(ARollout: TCRollout);
    procedure LayoutChanged;
    procedure LayoutPanels;
    procedure UpdateScrollBar(L, C: Integer);
    procedure ScrollTo(APos: Integer);
    procedure HandleScroll(ACode: Integer);
    function ScrollBarKind: Integer;
    procedure WMVScroll(var Msg: TLMVScroll); message LM_VSCROLL;
    procedure WMHScroll(var Msg: TLMHScroll); message LM_HSCROLL;
  protected
    procedure InsertControl(AControl: TControl; Index: Integer); override;
    procedure AlignControls(AControl: TControl; var RemainingClientRect: TRect); override;
    procedure CreateWnd; override;
    procedure Loaded; override;
    procedure DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
      const AXProportion, AYProportion: Double); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
    procedure Paint; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure AddPanel(ARollout: TCRollout);
    procedure InsertPanel(Index: Integer; ARollout: TCRollout);
    procedure RemovePanel(ARollout: TCRollout);
    procedure MovePanel(CurIndex, NewIndex: Integer);
    function IndexOfPanel(ARollout: TCRollout): Integer;
    property Panels[Index: Integer]: TCRollout read GetPanel;
    property PanelCount: Integer read GetPanelCount;
  published
    property Orientation: TCExpandOrientation read FOrientation write SetOrientation
      default eoVertical;
    property Multiple: Boolean read FMultiple write SetMultiple default True;
    property Spacing: Integer read FSpacing write SetSpacing default 0;
    property Scrollable: Boolean read FScrollable write SetScrollable default True;
    property Align;
    property Anchors;
    property BorderSpacing;
    property Color;
    property Constraints;
    property Enabled;
    property Font;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property ShowHint;
    property Visible;
  end;

implementation

const
  { 100% のときの大きさ。描くたびに Scale96ToFont で拡大する }
  cButtonInset96 = 2;
  cButtonGap96 = 2;
  cEdgePad96 = 4;
  cTextPad96 = 6;
  cArrowSize96 = 8;
  cButtonRadius96 = 4;
  cFillMin96 = 60;
  cScrollLine96 = 24;
  cAnimInterval = 15;

{ ---- TCRolloutButton ---- }

constructor TCRolloutButton.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FImageIndex := -1;
  FEnabled := True;
  FVisible := True;
end;

procedure TCRolloutButton.Assign(Source: TPersistent);
begin
  if Source is TCRolloutButton then
  begin
    FImageIndex := TCRolloutButton(Source).FImageIndex;
    FHint := TCRolloutButton(Source).FHint;
    FDropDownMenu := TCRolloutButton(Source).FDropDownMenu;
    FEnabled := TCRolloutButton(Source).FEnabled;
    FVisible := TCRolloutButton(Source).FVisible;
    Changed(False);
  end
  else
    inherited Assign(Source);
end;

function TCRolloutButton.GetDisplayName: string;
begin
  if FHint <> '' then
    Result := FHint
  else
    Result := 'Button ' + IntToStr(Index);
end;

procedure TCRolloutButton.SetImageIndex(AValue: TImageIndex);
begin
  if FImageIndex = AValue then Exit;
  FImageIndex := AValue;
  Changed(False);
end;

procedure TCRolloutButton.SetHint(const AValue: string);
begin
  if FHint = AValue then Exit;
  FHint := AValue;
  Changed(False);
end;

procedure TCRolloutButton.SetDropDownMenu(AValue: TPopupMenu);
begin
  if FDropDownMenu = AValue then Exit;
  FDropDownMenu := AValue;
  // メニューが消えたとき、TCRollout が知らせを受けて nil にする
  if (AValue <> nil) and (Collection is TCRolloutButtons) and
     (TCRolloutButtons(Collection).Rollout <> nil) then
    AValue.FreeNotification(TCRolloutButtons(Collection).Rollout);
  Changed(False);
end;

procedure TCRolloutButton.SetEnabled(AValue: Boolean);
begin
  if FEnabled = AValue then Exit;
  FEnabled := AValue;
  Changed(False);
end;

procedure TCRolloutButton.SetVisible(AValue: Boolean);
begin
  if FVisible = AValue then Exit;
  FVisible := AValue;
  Changed(False);
end;

{ ---- TCRolloutButtons ---- }

constructor TCRolloutButtons.Create(AOwner: TCRollout);
begin
  inherited Create(AOwner, TCRolloutButton);
  FRollout := AOwner;
end;

function TCRolloutButtons.GetItem(Index: Integer): TCRolloutButton;
begin
  Result := TCRolloutButton(inherited Items[Index]);
end;

procedure TCRolloutButtons.SetItem(Index: Integer; AValue: TCRolloutButton);
begin
  inherited Items[Index] := AValue;
end;

procedure TCRolloutButtons.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if FRollout <> nil then
    FRollout.ButtonsChanged;
end;

{ ---- TCRollout ---- }

constructor TCRollout.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FExpanded := True;
  FHeaderPosition := hpTop;
  FHeaderSize := 24;
  FExpandedSize := 150;
  FFill := False;
  FShowArrow := True;
  FImagesWidth := 0;
  FImageChangeLink := TChangeLink.Create;
  FImageChangeLink.OnChange := @ImageListChange;
  FButtons := TCRolloutButtons.Create(Self);
  FButtonsShow := bsAlways;
  FAnimated := True;
  FAnimationTime := 150;
  FOpenT := 1;
  FAnimTimer := nil;
  FHotHeader := False;
  FHotButton := -1;
  FDownButton := -1;
  FDownHeader := False;
  FMenuOpen := False;
  // 中身に部品を置ける。ドラッグ中に外へ出てもマウスを受け取る
  ControlStyle := ControlStyle + [csAcceptsControls, csCaptureMouse, csClickEvents];
  ParentColor := False;
  Color := clBtnFace;
  Caption := '';
  Width := 200;
  Height := 150;
  Align := alNone;
  DoubleBuffered := True;
end;

destructor TCRollout.Destroy;
begin
  if FAnimTimer <> nil then
  begin
    FAnimTimer.Enabled := False;
    FreeAndNil(FAnimTimer);
  end;
  if FImages <> nil then
    FImages.UnRegisterChanges(FImageChangeLink);
  inherited Destroy;
  FreeAndNil(FButtons);
  FreeAndNil(FImageChangeLink);
end;

function TCRollout.GetExpandPanel: TCExpandPanel;
begin
  if Parent is TCExpandPanel then
    Result := TCExpandPanel(Parent)
  else
    Result := nil;
end;

function TCRollout.EventsEnabled: Boolean;
begin
  Result := ComponentState * [csLoading, csReading, csDesigning, csDestroying] = [];
end;

{ ---- 実効の向きと大きさ ---- }

{ 入れ物の中では、入れ物の並べる向きに合わない HeaderPosition は読み替える
  （プロパティの値は変えない） }
function TCRollout.EffectivePosition: TCRolloutHeaderPosition;
var
  P: TCExpandPanel;
begin
  Result := FHeaderPosition;
  P := ExpandPanel;
  if P = nil then Exit;
  if P.FOrientation = eoVertical then
  begin
    if Result in [hpLeft, hpRight] then Result := hpTop;
  end
  else
  begin
    if Result in [hpTop, hpBottom] then Result := hpLeft;
  end;
end;

function TCRollout.IsVerticalHeader: Boolean;
begin
  Result := EffectivePosition in [hpLeft, hpRight];
end;

function TCRollout.HeaderThickness: Integer;
begin
  Result := FHeaderSize;
end;

function TCRollout.AxisSize: Integer;
begin
  if IsVerticalHeader then Result := Width else Result := Height;
end;

function TCRollout.LayoutSize(AFull: Integer): Integer;
var
  H: Integer;
begin
  H := HeaderThickness;
  if AFull <= H then
    Result := H
  else
    Result := H + Round((AFull - H) * FOpenT);
end;

function TCRollout.CurrentSize: Integer;
begin
  Result := LayoutSize(FExpandedSize);
end;

function TCRollout.OpenTarget: Double;
begin
  if FExpanded then Result := 1 else Result := 0;
end;

function TCRollout.Animating: Boolean;
begin
  Result := (FAnimTimer <> nil) and FAnimTimer.Enabled;
end;

function TCRollout.HeaderRect: TRect;
var
  T: Integer;
begin
  T := HeaderThickness;
  case EffectivePosition of
    hpTop:    Result := Rect(0, 0, Width, T);
    hpBottom: Result := Rect(0, Height - T, Width, Height);
    hpLeft:   Result := Rect(0, 0, T, Height);
  else
    Result := Rect(Width - T, 0, Width, Height);
  end;
end;

{ 単体のとき、伸縮する向きの大きさを今の開き具合に合わせる。
  タイトルバーと反対側の辺を動かす（Align = alNone のとき、タイトルバー側の辺は動かさない） }
procedure TCRollout.ApplyOwnSize;
var
  S, NL, NT: Integer;
begin
  if (ExpandPanel <> nil) or (csLoading in ComponentState) or (csDestroying in ComponentState) then
    Exit;
  S := CurrentSize;
  if S = AxisSize then Exit;
  NL := Left;
  NT := Top;
  FSizing := True;
  try
    if IsVerticalHeader then
    begin
      if (Align = alNone) and (EffectivePosition = hpRight) then NL := Left + Width - S;
      SetBounds(NL, NT, S, Height);
    end
    else
    begin
      if (Align = alNone) and (EffectivePosition = hpBottom) then NT := Top + Height - S;
      SetBounds(NL, NT, Width, S);
    end;
  finally
    FSizing := False;
  end;
end;

procedure TCRollout.SetBoundsManaged(ALeft, ATop, AWidth, AHeight: Integer);
begin
  FManaged := True;
  try
    SetBounds(ALeft, ATop, AWidth, AHeight);
  finally
    FManaged := False;
  end;
end;

procedure TCRollout.SetBounds(ALeft, ATop, AWidth, AHeight: Integer);
var
  Axis: Integer;
begin
  if not (FSizing or FManaged or (csLoading in ComponentState) or
          (csDestroying in ComponentState) or Animating) then
  begin
    if IsVerticalHeader then Axis := AWidth else Axis := AHeight;
    if FExpanded then
      // 利用者が大きさを変えたら、開いたときの大きさとして覚える
      FExpandedSize := Max(Axis, HeaderThickness)
    else if Axis <> HeaderThickness then
    begin
      // 閉じているときは、伸縮する向きの大きさをタイトルバーの厚みに直す
      if IsVerticalHeader then AWidth := HeaderThickness else AHeight := HeaderThickness;
    end;
  end;
  inherited SetBounds(ALeft, ATop, AWidth, AHeight);
end;

procedure TCRollout.LayoutChanged;
begin
  if (csLoading in ComponentState) or (csDestroying in ComponentState) then Exit;
  if ExpandPanel <> nil then
    ExpandPanel.LayoutChanged
  else
    ApplyOwnSize;
  ReAlign;
  Invalidate;
end;

procedure TCRollout.Loaded;
begin
  inherited Loaded;
  FOpenT := OpenTarget;
  if ExpandPanel = nil then
    ApplyOwnSize
  else
    ExpandPanel.LayoutChanged;
end;

procedure TCRollout.SetParent(NewParent: TWinControl);
var
  Old: TWinControl;
begin
  if NewParent = Parent then
  begin
    inherited SetParent(NewParent);
    Exit;
  end;
  Old := Parent;
  if Old is TCExpandPanel then
    TCExpandPanel(Old).RemoveRollout(Self);
  inherited SetParent(NewParent);
  if NewParent is TCExpandPanel then
    TCExpandPanel(NewParent).AddRollout(Self)
  else if not (csLoading in ComponentState) then
    ApplyOwnSize;
end;

{ ---- プロパティの読み書き ---- }

procedure TCRollout.SetExpanded(AValue: Boolean);
var
  Allow: Boolean;
begin
  if FExpanded = AValue then Exit;
  if csLoading in ComponentState then
  begin
    FExpanded := AValue;
    FOpenT := OpenTarget;
    Exit;
  end;
  if EventsEnabled and Assigned(FOnExpanding) then
  begin
    Allow := True;
    FOnExpanding(Self, Allow);
    if not Allow then Exit;
  end;
  FExpanded := AValue;
  StartOpen;
  if ExpandPanel <> nil then
    ExpandPanel.RolloutToggled(Self);
  Invalidate;
  if EventsEnabled then
  begin
    if FExpanded then
    begin
      if Assigned(FOnExpand) then FOnExpand(Self);
    end
    else if Assigned(FOnCollapse) then
      FOnCollapse(Self);
  end;
end;

procedure TCRollout.SetHeaderPosition(AValue: TCRolloutHeaderPosition);
begin
  if FHeaderPosition = AValue then Exit;
  FHeaderPosition := AValue;
  LayoutChanged;
end;

procedure TCRollout.SetHeaderSize(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  if FHeaderSize = AValue then Exit;
  FHeaderSize := AValue;
  LayoutChanged;
end;

procedure TCRollout.SetExpandedSize(AValue: Integer);
begin
  if AValue < FHeaderSize then AValue := FHeaderSize;
  if FExpandedSize = AValue then Exit;
  FExpandedSize := AValue;
  LayoutChanged;
end;

procedure TCRollout.SetFill(AValue: Boolean);
begin
  if FFill = AValue then Exit;
  FFill := AValue;
  if ExpandPanel <> nil then
    ExpandPanel.LayoutChanged;
end;

procedure TCRollout.SetShowArrow(AValue: Boolean);
begin
  if FShowArrow = AValue then Exit;
  FShowArrow := AValue;
  Invalidate;
end;

procedure TCRollout.SetImages(AValue: TCustomImageList);
begin
  if FImages = AValue then Exit;
  if FImages <> nil then
  begin
    FImages.UnRegisterChanges(FImageChangeLink);
    FImages.RemoveFreeNotification(Self);
  end;
  FImages := AValue;
  if FImages <> nil then
  begin
    FImages.FreeNotification(Self);
    FImages.RegisterChanges(FImageChangeLink);
  end;
  Invalidate;
end;

procedure TCRollout.SetImagesWidth(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  if FImagesWidth = AValue then Exit;
  FImagesWidth := AValue;
  Invalidate;
end;

procedure TCRollout.SetButtons(AValue: TCRolloutButtons);
begin
  FButtons.Assign(AValue);
end;

procedure TCRollout.SetButtonsShow(AValue: TCRolloutButtonsShow);
begin
  if FButtonsShow = AValue then Exit;
  FButtonsShow := AValue;
  Invalidate;
end;

procedure TCRollout.SetAnimationTime(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  FAnimationTime := AValue;
end;

procedure TCRollout.ImageListChange(Sender: TObject);
begin
  Invalidate;
end;

procedure TCRollout.ButtonsChanged;
begin
  Invalidate;
end;

procedure TCRollout.Notification(AComponent: TComponent; Operation: TOperation);
var
  I: Integer;
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then Exit;
  if AComponent = FImages then
  begin
    FImages := nil;
    Invalidate;
  end;
  if FButtons <> nil then
    for I := 0 to FButtons.Count - 1 do
      if FButtons.Items[I].FDropDownMenu = AComponent then
        FButtons.Items[I].FDropDownMenu := nil;
end;

procedure TCRollout.TextChanged;
begin
  inherited TextChanged;
  Invalidate;
end;

procedure TCRollout.CMEnabledChanged(var Message: TLMessage);
begin
  inherited CMEnabledChanged(Message);
  Invalidate;
end;

{ 表示スケールが変わったとき、タイトルバーの厚みと、開いたときの大きさを拡大する。
  開いている単体のパネルの大きさは、LCL が Width・Height を拡大するときに SetBounds で
  ExpandedSize に入るので、ここでは拡大しない }
procedure TCRollout.DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
  const AXProportion, AYProportion: Double);
var
  Prop: Double;
begin
  inherited DoAutoAdjustLayout(AMode, AXProportion, AYProportion);
  if AMode in [lapAutoAdjustWithoutHorizontalScrolling, lapAutoAdjustForDPI] then
  begin
    if IsVerticalHeader then Prop := AXProportion else Prop := AYProportion;
    FHeaderSize := Round(FHeaderSize * Prop);
    if not FExpanded then
      FExpandedSize := Round(FExpandedSize * Prop);
  end;
end;

{ 中身の領域：タイトルバーの分を除く }
procedure TCRollout.AdjustClientRect(var ARect: TRect);
var
  T: Integer;
begin
  inherited AdjustClientRect(ARect);
  T := HeaderThickness;
  case EffectivePosition of
    hpTop:    Inc(ARect.Top, T);
    hpBottom: Dec(ARect.Bottom, T);
    hpLeft:   Inc(ARect.Left, T);
  else
    Dec(ARect.Right, T);
  end;
  if ARect.Bottom < ARect.Top then ARect.Bottom := ARect.Top;
  if ARect.Right < ARect.Left then ARect.Right := ARect.Left;
end;

{ ---- アニメーション ---- }

{ 開き具合 FOpenT を目標（OpenTarget）へ動かし始める。
  アニメーションしない条件のときは、すぐ目標にする }
procedure TCRollout.StartOpen;
begin
  if FOpenT = OpenTarget then
  begin
    if (FAnimTimer <> nil) then FAnimTimer.Enabled := False;
    Exit;
  end;
  if (not FAnimated) or (FAnimationTime <= 0) or (csDesigning in ComponentState) or
     (ComponentState * [csLoading, csDestroying] <> []) or
     (not HandleAllocated) or (not IsVisible) then
  begin
    if FAnimTimer <> nil then FAnimTimer.Enabled := False;
    FOpenT := OpenTarget;
    OpenChanged;
    Exit;
  end;
  FAnimFrom := FOpenT;
  FAnimStart := GetTickCount64;
  if FAnimTimer = nil then
  begin
    FAnimTimer := TTimer.Create(nil);
    FAnimTimer.Enabled := False;
    FAnimTimer.Interval := cAnimInterval;
    FAnimTimer.OnTimer := @AnimTimerTick;
  end;
  FAnimTimer.Enabled := True;
end;

procedure TCRollout.AnimTimerTick(Sender: TObject);
var
  Prog, E, Target: Double;
begin
  Target := OpenTarget;
  if FAnimationTime <= 0 then
    Prog := 1
  else
    Prog := (GetTickCount64 - FAnimStart) / FAnimationTime;
  if Prog > 1 then Prog := 1;
  E := Prog * Prog * (3 - 2 * Prog);
  FOpenT := FAnimFrom + (Target - FAnimFrom) * E;
  if Prog >= 1 then
  begin
    FOpenT := Target;
    FAnimTimer.Enabled := False;
  end;
  OpenChanged;
end;

procedure TCRollout.OpenChanged;
begin
  if ExpandPanel <> nil then
    ExpandPanel.LayoutChanged
  else
  begin
    ApplyOwnSize;
    ReAlign;
  end;
  Invalidate;
end;

{ ---- タイトルバーの部品の位置 ---- }

function TCRollout.ButtonSize: Integer;
begin
  Result := HeaderThickness - 2 * Scale96ToFont(cButtonInset96);
  if Result < 0 then Result := 0;
end;

function TCRollout.ArrowRect: TRect;
var
  H: TRect;
  A, EP: Integer;
begin
  Result := Rect(0, 0, 0, 0);
  if not FShowArrow then Exit;
  H := HeaderRect;
  A := Scale96ToFont(cArrowSize96);
  EP := Scale96ToFont(cEdgePad96);
  if not IsVerticalHeader then
    Result := Rect(H.Left + EP, H.Top + (H.Bottom - H.Top - A) div 2,
      H.Left + EP + A, H.Top + (H.Bottom - H.Top - A) div 2 + A)
  else
    Result := Rect(H.Left + (H.Right - H.Left - A) div 2, H.Top + EP,
      H.Left + (H.Right - H.Left - A) div 2 + A, H.Top + EP + A);
end;

{ ボタン Index の枠。出さないボタン・範囲外は空 }
function TCRollout.ButtonRect(Index: Integer): TRect;
var
  I, S, G, Pos: Integer;
  H, AR: TRect;
begin
  Result := Rect(0, 0, 0, 0);
  if (Index < 0) or (Index >= FButtons.Count) then Exit;
  if not FButtons.Items[Index].Visible then Exit;
  S := ButtonSize;
  if S <= 0 then Exit;
  G := Scale96ToFont(cButtonGap96);
  H := HeaderRect;
  if not IsVerticalHeader then
  begin
    // 見出しの右端から、番号の大きいボタンを順に左へ並べる
    Pos := H.Right - Scale96ToFont(cEdgePad96);
    for I := FButtons.Count - 1 downto Index do
      if FButtons.Items[I].Visible then
      begin
        Dec(Pos, S);
        if I = Index then
        begin
          Result := Rect(Pos, H.Top + (H.Bottom - H.Top - S) div 2, Pos + S,
            H.Top + (H.Bottom - H.Top - S) div 2 + S);
          Exit;
        end;
        Dec(Pos, G);
      end;
  end
  else
  begin
    // 矢印の下から、番号の小さいボタンを順に下へ並べる
    Pos := H.Top + Scale96ToFont(cEdgePad96);
    AR := ArrowRect;
    if AR.Bottom > AR.Top then
      Pos := AR.Bottom + Scale96ToFont(cTextPad96);
    for I := 0 to Index do
      if FButtons.Items[I].Visible then
      begin
        if I = Index then
        begin
          Result := Rect(H.Left + (H.Right - H.Left - S) div 2, Pos,
            H.Left + (H.Right - H.Left - S) div 2 + S, Pos + S);
          Exit;
        end;
        Inc(Pos, S + G);
      end;
  end;
end;

{ ボタンを描く・押せるか }
function TCRollout.ButtonsShown: Boolean;
begin
  Result := (csDesigning in ComponentState) or (FButtonsShow = bsAlways) or
    FHotHeader or FMenuOpen or (FDownButton >= 0);
end;

function TCRollout.ButtonAt(X, Y: Integer): Integer;
var
  I: Integer;
  R: TRect;
  P: TPoint;
begin
  Result := -1;
  if not ButtonsShown then Exit;
  P := Point(X, Y);
  for I := 0 to FButtons.Count - 1 do
  begin
    R := ButtonRect(I);
    if (R.Right > R.Left) and PtInRect(R, P) then
    begin
      Result := I;
      Exit;
    end;
  end;
end;

{ 文字の範囲：矢印とボタンを除いた部分（ボタンの場所は出さないときも空けておく） }
function TCRollout.TextRect: TRect;
var
  H, AR, BR: TRect;
  I, TP, EP: Integer;
begin
  H := HeaderRect;
  TP := Scale96ToFont(cTextPad96);
  EP := Scale96ToFont(cEdgePad96);
  AR := ArrowRect;
  Result := H;
  if not IsVerticalHeader then
  begin
    Result.Left := H.Left + EP;
    if AR.Right > AR.Left then Result.Left := AR.Right + TP;
    Result.Right := H.Right - EP;
    for I := 0 to FButtons.Count - 1 do
    begin
      BR := ButtonRect(I);
      if (BR.Right > BR.Left) and (BR.Left - TP < Result.Right) then
        Result.Right := BR.Left - TP;
    end;
  end
  else
  begin
    Result.Top := H.Top + EP;
    if AR.Bottom > AR.Top then Result.Top := AR.Bottom + TP;
    Result.Bottom := H.Bottom - EP;
    for I := 0 to FButtons.Count - 1 do
    begin
      BR := ButtonRect(I);
      if (BR.Bottom > BR.Top) and (BR.Bottom + TP > Result.Top) then
        Result.Top := BR.Bottom + TP;
    end;
  end;
end;

{ ---- 描画 ---- }

{ 矢印（山形）。ADir：0 = 下、1 = 右、2 = 上、3 = 左 }
procedure TCRollout.PaintArrow(const R: TRect; ADir: Integer);
var
  CX, CY, A, H: Integer;
  P1, P2, P3: TPoint;
begin
  CX := (R.Left + R.Right) div 2;
  CY := (R.Top + R.Bottom) div 2;
  A := (R.Right - R.Left) div 2;
  H := A div 2;
  case ADir of
    0: begin P1 := Point(CX - A, CY - H); P2 := Point(CX, CY + H); P3 := Point(CX + A, CY - H); end;
    1: begin P1 := Point(CX - H, CY - A); P2 := Point(CX + H, CY); P3 := Point(CX - H, CY + A); end;
    2: begin P1 := Point(CX - A, CY + H); P2 := Point(CX, CY - H); P3 := Point(CX + A, CY + H); end;
  else
    begin P1 := Point(CX + H, CY - A); P2 := Point(CX - H, CY); P3 := Point(CX + H, CY + A); end;
  end;
  Canvas.Polyline([P1, P2, P3]);
end;

procedure TCRollout.Paint;
var
  H, R, TR, Clip: TRect;
  I, Dir, TH, X, Y, Rad: Integer;
  TS: TTextStyle;
  Res: TScaledImageListResolution;
  Bmp: TBitmap;
  Item: TCRolloutButton;
  IX, IY: Integer;
  Open: Boolean;
begin
  // 中身の背景
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(Rect(0, 0, Width, Height));
  // タイトルバーの背景
  H := HeaderRect;
  Canvas.Brush.Color := clBtnFace;
  Canvas.FillRect(H);
  // 開いているとき、中身側の辺に線を引く
  Open := FExpanded or (FOpenT > 0);
  if Open then
  begin
    Canvas.Pen.Style := psSolid;
    Canvas.Pen.Color := clBtnShadow;
    Canvas.Pen.Width := 1;
    case EffectivePosition of
      hpTop:    Canvas.Line(H.Left, H.Bottom - 1, H.Right, H.Bottom - 1);
      hpBottom: Canvas.Line(H.Left, H.Top, H.Right, H.Top);
      hpLeft:   Canvas.Line(H.Right - 1, H.Top, H.Right - 1, H.Bottom);
    else
      Canvas.Line(H.Left, H.Top, H.Left, H.Bottom);
    end;
  end;
  // 矢印
  R := ArrowRect;
  if R.Right > R.Left then
  begin
    Canvas.Pen.Style := psSolid;
    Canvas.Pen.Color := clBtnText;
    Canvas.Pen.Width := Max(1, Scale96ToFont(1));
    Canvas.Brush.Style := bsClear;
    if FExpanded then
      case EffectivePosition of
        hpTop: Dir := 0;
        hpBottom: Dir := 2;
        hpLeft: Dir := 1;
      else
        Dir := 3;
      end
    else
      case EffectivePosition of
        hpTop, hpBottom: Dir := 1;
      else
        Dir := 0;
      end;
    PaintArrow(R, Dir);
    Canvas.Brush.Style := bsSolid;
  end;
  // 文字
  TR := TextRect;
  if (TR.Right > TR.Left) and (TR.Bottom > TR.Top) and (Caption <> '') then
  begin
    Canvas.Font := Font;
    Canvas.Font.Color := clBtnText;
    Canvas.Brush.Style := bsClear;
    if not IsVerticalHeader then
    begin
      TS := Canvas.TextStyle;
      TS.Layout := tlCenter;
      TS.SingleLine := True;
      TS.EndEllipsis := True;
      TS.Clipping := True;
      TS.Opaque := False;
      Canvas.TextRect(TR, TR.Left, TR.Top, Caption, TS);
    end
    else
    begin
      // 縦のタイトルバー：文字を回転して描く。範囲からはみ出す部分は切る
      TH := Canvas.TextHeight('Ag');
      Clip := TR;
      Canvas.ClipRect := Clip;
      Canvas.Clipping := True;
      // 回転した文字は ClearType だと色がにじむので、グレースケールの滑らかさにする
      Canvas.Font.Quality := fqAntialiased;
      if EffectivePosition = hpLeft then
      begin
        Canvas.Font.Orientation := 900;   // 下から上へ読む
        X := (HeaderRect.Left + HeaderRect.Right - TH) div 2;
        Y := TR.Bottom;
      end
      else
      begin
        Canvas.Font.Orientation := 2700;  // 上から下へ読む
        X := (HeaderRect.Left + HeaderRect.Right + TH) div 2;
        Y := TR.Top;
      end;
      Canvas.TextOut(X, Y, Caption);
      Canvas.Clipping := False;
      Canvas.Font.Orientation := 0;
    end;
    Canvas.Brush.Style := bsSolid;
  end;
  // ボタン
  if ButtonsShown and (FButtons.Count > 0) then
  begin
    Rad := Scale96ToFont(cButtonRadius96);
    if Assigned(FImages) then
      Res := FImages.ResolutionForPPI[FImagesWidth, Font.PixelsPerInch, 1];
    for I := 0 to FButtons.Count - 1 do
    begin
      Item := FButtons.Items[I];
      R := ButtonRect(I);
      if R.Right <= R.Left then Continue;
      if (I = FHotButton) and Enabled and Item.Enabled then
      begin
        Canvas.Pen.Style := psClear;
        Canvas.Brush.Style := bsSolid;
        if I = FDownButton then
          Canvas.Brush.Color := clBtnShadow
        else
          Canvas.Brush.Color := clBtnHighlight;
        Canvas.RoundRect(R, Rad, Rad);
      end;
      if Assigned(FImages) and (Item.ImageIndex >= 0) and (Item.ImageIndex < FImages.Count) then
      begin
        IX := R.Left + (R.Right - R.Left - Res.Width) div 2;
        IY := R.Top + (R.Bottom - R.Top - Res.Height) div 2;
        if Enabled and Item.Enabled then
          Res.Draw(Canvas, IX, IY, Item.ImageIndex, True)
        else
        begin
          Bmp := TBitmap.Create;
          try
            Res.GetBitmap(Item.ImageIndex, Bmp, gdeDisabled);
            Canvas.Draw(IX, IY, Bmp);
          finally
            Bmp.Free;
          end;
        end;
      end;
    end;
    Canvas.Pen.Style := psSolid;
    Canvas.Brush.Style := bsSolid;
  end;
end;

{ ---- マウス ---- }

procedure TCRollout.SetHot(AIndex: Integer);
begin
  if FHotButton = AIndex then Exit;
  if AIndex >= 0 then
    Application.CancelHint;
  FHotButton := AIndex;
  Invalidate;
end;

procedure TCRollout.SetHeaderHot(AValue: Boolean);
begin
  if FHotHeader = AValue then Exit;
  FHotHeader := AValue;
  if FButtonsShow = bsHover then
    Invalidate;
end;

procedure TCRollout.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  FDownButton := -1;
  FDownHeader := False;
  if PtInRect(HeaderRect, Point(X, Y)) then
  begin
    FDownButton := ButtonAt(X, Y);
    FDownHeader := FDownButton < 0;
    Invalidate;
  end;
end;

procedure TCRollout.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  SetHeaderHot(PtInRect(HeaderRect, Point(X, Y)));
  SetHot(ButtonAt(X, Y));
end;

procedure TCRollout.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  D: Integer;
  DH: Boolean;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  D := FDownButton;
  DH := FDownHeader;
  FDownButton := -1;
  FDownHeader := False;
  if D >= 0 then
  begin
    if (D < FButtons.Count) and PtInRect(ButtonRect(D), Point(X, Y)) and
       FButtons.Items[D].Enabled and Enabled then
      ClickButton(D);
  end
  else if DH and PtInRect(HeaderRect, Point(X, Y)) and (ButtonAt(X, Y) < 0) and
          (Enabled or (csDesigning in ComponentState)) then
  begin
    Expanded := not Expanded;
    if csDesigning in ComponentState then
      OwnerFormDesignerModified(Self);
  end;
  // デザイナは、この MouseUp の後に押下中の状態を残す（CMDesignHitTest 参照）
  if (csDesigning in ComponentState) and ((D >= 0) or DH) then
    FDesignerPressLeft := True;
  Invalidate;
end;

procedure TCRollout.MouseLeave;
begin
  inherited MouseLeave;
  SetHeaderHot(False);
  SetHot(-1);
end;

{ ボタンを押したとき：OnButtonClick のあと、DropDownMenu があれば出す }
procedure TCRollout.ClickButton(AIndex: Integer);
var
  M: TPopupMenu;
  R: TRect;
  Pt: TPoint;
begin
  if csDesigning in ComponentState then Exit;
  if Assigned(FOnButtonClick) then
    FOnButtonClick(Self, AIndex);
  if (AIndex < 0) or (AIndex >= FButtons.Count) then Exit;
  M := FButtons.Items[AIndex].DropDownMenu;
  if M = nil then Exit;
  R := ButtonRect(AIndex);
  if IsVerticalHeader then
    Pt := ClientToScreen(Point(R.Right, R.Top))
  else
    Pt := ClientToScreen(Point(R.Left, R.Bottom));
  M.PopupComponent := Self;
  FMenuOpen := True;
  try
    M.PopUp(Pt.X, Pt.Y);
  finally
    FMenuOpen := False;
    FHotButton := -1;
    FHotHeader := PtInRect(HeaderRect, ScreenToClient(Mouse.CursorPos));
    Invalidate;
  end;
end;

{ ヒント：マウスの下のボタンに Hint があれば、それを出す }
procedure TCRollout.CMHintShow(var Message: TLMessage);
var
  Info: PHintInfo;
  I: Integer;
begin
  inherited CMHintShow(Message);
  Info := TCMHintShow(Message).HintInfo;
  if Info = nil then Exit;
  I := ButtonAt(Info^.CursorPos.X, Info^.CursorPos.Y);
  if (I >= 0) and (FButtons.Items[I].Hint <> '') then
  begin
    Info^.HintStr := FButtons.Items[I].Hint;
    Info^.CursorRect := ButtonRect(I);
  end;
end;

{ 設計時：マウス操作を渡す場所。TCSideBar と同じ考え方（uCSideBar の CMDesignHitTest 参照）。
  見出しの中（ボタンを含む）は 1（パネルが受け取る）、ほかは 0（デザイナが部品を選ぶ） }
procedure TCRollout.CMDesignHitTest(var Message: TCMDesignHitTest);
const
  cMouseButtons = MK_LBUTTON or MK_RBUTTON or MK_MBUTTON;
var
  ButtonsDown: Boolean;
begin
  ButtonsDown := (Message.Keys and cMouseButtons) <> 0;
  if ButtonsDown then
    FDesignerPressLeft := False;
  if (FDownButton >= 0) or FDownHeader then
    Message.Result := 1
  else if FDesignerPressLeft and not ButtonsDown then
    Message.Result := 1
  else if PtInRect(HeaderRect, Point(Message.XPos, Message.YPos)) then
    Message.Result := 1
  else
    Message.Result := 0;
end;

{ ---- TCExpandPanel ---- }

constructor TCExpandPanel.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FPanels := TFPList.Create;
  FOrientation := eoVertical;
  FMultiple := True;
  FSpacing := 0;
  FScrollable := True;
  FScrollPos := 0;
  ControlStyle := ControlStyle + [csAcceptsControls];
  ParentColor := False;
  Color := clBtnFace;
  Width := 200;
  Height := 300;
end;

destructor TCExpandPanel.Destroy;
begin
  inherited Destroy;       // 子のパネルの親が外れ、RemoveRollout が呼ばれる
  FreeAndNil(FPanels);
end;

function TCExpandPanel.GetPanel(Index: Integer): TCRollout;
begin
  Result := TCRollout(FPanels[Index]);
end;

function TCExpandPanel.GetPanelCount: Integer;
begin
  Result := FPanels.Count;
end;

function TCExpandPanel.IndexOfPanel(ARollout: TCRollout): Integer;
begin
  Result := FPanels.IndexOf(ARollout);
end;

procedure TCExpandPanel.AddPanel(ARollout: TCRollout);
begin
  if ARollout = nil then
    raise EArgumentException.Create('ARollout = nil');
  if FPanels.IndexOf(ARollout) >= 0 then Exit;
  ARollout.Parent := Self;     // SetParent を通って AddRollout が呼ばれる
end;

procedure TCExpandPanel.InsertPanel(Index: Integer; ARollout: TCRollout);
begin
  AddPanel(ARollout);
  if (Index >= 0) and (Index < FPanels.Count - 1) then
    MovePanel(FPanels.Count - 1, Index);
end;

procedure TCExpandPanel.RemovePanel(ARollout: TCRollout);
begin
  if (ARollout <> nil) and (FPanels.IndexOf(ARollout) >= 0) then
    ARollout.Parent := nil;    // RemoveRollout が呼ばれる。ARollout は解放しない
end;

procedure TCExpandPanel.MovePanel(CurIndex, NewIndex: Integer);
var
  R: TCRollout;
  NewControlIndex: Integer;
begin
  if (CurIndex < 0) or (CurIndex >= FPanels.Count) or
     (NewIndex < 0) or (NewIndex >= FPanels.Count) or (CurIndex = NewIndex) then Exit;
  R := TCRollout(FPanels[CurIndex]);
  // FPanels の順と子の順（.lfm に保存される順）を同じにする
  NewControlIndex := GetControlIndex(TCRollout(FPanels[NewIndex]));
  FPanels.Move(CurIndex, NewIndex);
  SetControlIndex(R, NewControlIndex);
  LayoutChanged;
end;

procedure TCExpandPanel.AddRollout(ARollout: TCRollout);
begin
  if (FPanels = nil) or (FPanels.IndexOf(ARollout) >= 0) then Exit;
  FPanels.Add(ARollout);
  ARollout.Align := alNone;
  LayoutChanged;
end;

procedure TCExpandPanel.RemoveRollout(ARollout: TCRollout);
begin
  if (FPanels = nil) or (FPanels.IndexOf(ARollout) < 0) then Exit;
  FPanels.Remove(ARollout);
  LayoutChanged;
end;

procedure TCExpandPanel.InsertControl(AControl: TControl; Index: Integer);
begin
  if not (AControl is TCRollout) then
    raise EInvalidOperation.Create(CXT(sEpErrChild));
  inherited InsertControl(AControl, Index);
end;

{ ---- 開閉の連動 ---- }

procedure TCExpandPanel.RolloutToggled(ARollout: TCRollout);
var
  I: Integer;
  P: TCRollout;
begin
  if (not FMultiple) and ARollout.Expanded then
    for I := 0 to FPanels.Count - 1 do
    begin
      P := TCRollout(FPanels[I]);
      if (P <> ARollout) and P.Expanded then
        P.Expanded := False;
    end;
  LayoutChanged;
end;

{ ---- プロパティの読み書き ---- }

procedure TCExpandPanel.SetOrientation(AValue: TCExpandOrientation);
var
  I: Integer;
begin
  if FOrientation = AValue then Exit;
  FOrientation := AValue;
  FScrollPos := 0;
  // パネルの実効の向きが変わるので、大きさを今の向きに合わせ直す
  for I := 0 to FPanels.Count - 1 do
    TCRollout(FPanels[I]).Invalidate;
  LayoutChanged;
end;

procedure TCExpandPanel.SetMultiple(AValue: Boolean);
var
  I: Integer;
  P, First: TCRollout;
begin
  if FMultiple = AValue then Exit;
  FMultiple := AValue;
  if not FMultiple then
  begin
    First := nil;
    for I := 0 to FPanels.Count - 1 do
    begin
      P := TCRollout(FPanels[I]);
      if P.Expanded then
      begin
        if First = nil then
          First := P
        else
          P.Expanded := False;
      end;
    end;
  end;
end;

procedure TCExpandPanel.SetSpacing(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  if FSpacing = AValue then Exit;
  FSpacing := AValue;
  LayoutChanged;
end;

procedure TCExpandPanel.SetScrollable(AValue: Boolean);
begin
  if FScrollable = AValue then Exit;
  FScrollable := AValue;
  if not FScrollable then FScrollPos := 0;
  LayoutChanged;
end;

procedure TCExpandPanel.CreateWnd;
begin
  inherited CreateWnd;
  FBarVisible := False;
  LayoutChanged;
end;

procedure TCExpandPanel.Loaded;
begin
  inherited Loaded;
  LayoutChanged;
end;

procedure TCExpandPanel.DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
  const AXProportion, AYProportion: Double);
begin
  inherited DoAutoAdjustLayout(AMode, AXProportion, AYProportion);
  if AMode in [lapAutoAdjustWithoutHorizontalScrolling, lapAutoAdjustForDPI] then
  begin
    if FOrientation = eoVertical then
      FSpacing := Round(FSpacing * AYProportion)
    else
      FSpacing := Round(FSpacing * AXProportion);
  end;
end;

procedure TCExpandPanel.Paint;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
end;

{ ---- 配置 ---- }

procedure TCExpandPanel.AlignControls(AControl: TControl; var RemainingClientRect: TRect);
begin
  // パネルは自分で置く（inherited は呼ばない）
  LayoutPanels;
end;

procedure TCExpandPanel.LayoutChanged;
begin
  if ComponentState * [csLoading, csDestroying] <> [] then Exit;
  LayoutPanels;
  Invalidate;
end;

{ 表示しているパネルを FPanels の順に、軸方向に並べる（設計書 6.3） }
procedure TCExpandPanel.LayoutPanels;
var
  V: array of TCRollout;
  Sizes: array of Integer;
  N, I, L, K, Fixed, Pool, B, C, Cross, Pos, HS, FillMin: Integer;
  Vert: Boolean;
  R: TCRollout;
begin
  if FInLayout or (FPanels = nil) or (ComponentState * [csLoading, csDestroying] <> []) then
    Exit;
  FInLayout := True;
  try
    SetLength(V, FPanels.Count);
    N := 0;
    for I := 0 to FPanels.Count - 1 do
    begin
      R := TCRollout(FPanels[I]);
      if R.Visible then
      begin
        V[N] := R;
        Inc(N);
      end;
    end;
    SetLength(V, N);
    Vert := FOrientation = eoVertical;
    if Vert then L := ClientHeight else L := ClientWidth;
    FViewLength := L;
    if N = 0 then
    begin
      FContentLength := 0;
      UpdateScrollBar(L, 0);
      Exit;
    end;
    SetLength(Sizes, N);
    // 3. Fill でないパネルの大きさ。Fill のパネルはタイトルバーの分だけ先に数える
    Fixed := 0;
    K := 0;
    for I := 0 to N - 1 do
    begin
      R := V[I];
      if R.Fill then
      begin
        Inc(Fixed, R.HeaderThickness);
        if R.Expanded or (R.FOpenT > 0) then Inc(K);
      end
      else
      begin
        Sizes[I] := R.CurrentSize;
        Inc(Fixed, Sizes[I]);
      end;
    end;
    // 4. Fill のパネルが、余りを分け合う
    Pool := L - Fixed - FSpacing * (N - 1);
    FillMin := Scale96ToFont(cFillMin96);
    if K > 0 then B := Max(Pool div K, FillMin) else B := 0;
    for I := 0 to N - 1 do
    begin
      R := V[I];
      if not R.Fill then Continue;
      HS := R.HeaderThickness;
      if R.Expanded or (R.FOpenT > 0) then
        Sizes[I] := HS + Round(B * R.FOpenT)
      else
        Sizes[I] := HS;
    end;
    // 5. 全体の長さ
    C := FSpacing * (N - 1);
    for I := 0 to N - 1 do Inc(C, Sizes[I]);
    FContentLength := C;
    // 6. スクロールバー（出し入れで、交差する向きの大きさが変わる）
    UpdateScrollBar(L, C);
    if Vert then Cross := ClientWidth else Cross := ClientHeight;
    // 7. 並べる
    Pos := -FScrollPos;
    for I := 0 to N - 1 do
    begin
      if Vert then
        V[I].SetBoundsManaged(0, Pos, Cross, Sizes[I])
      else
        V[I].SetBoundsManaged(Pos, 0, Sizes[I], Cross);
      Inc(Pos, Sizes[I] + FSpacing);
    end;
  finally
    FInLayout := False;
  end;
end;

{ ---- スクロール ---- }

function TCExpandPanel.ScrollBarKind: Integer;
begin
  if FOrientation = eoVertical then Result := SB_VERT else Result := SB_HORZ;
end;

{ L：入れ物の軸方向の長さ、C：パネルを並べた長さ }
procedure TCExpandPanel.UpdateScrollBar(L, C: Integer);
var
  SI: TScrollInfo;
  Bar, Other: Integer;
  NeedBar: Boolean;
begin
  NeedBar := FScrollable and (L > 0) and (C > L);
  if NeedBar then
    FScrollPos := EnsureRange(FScrollPos, 0, C - L)
  else
    FScrollPos := 0;
  if not HandleAllocated then Exit;
  Bar := ScrollBarKind;
  if FOrientation = eoVertical then Other := SB_HORZ else Other := SB_VERT;
  ShowScrollBar(Handle, Other, False);
  if NeedBar then
  begin
    FillChar(SI, SizeOf(SI), 0);
    SI.cbSize := SizeOf(SI);
    SI.fMask := SIF_RANGE or SIF_PAGE or SIF_POS;
    SI.nMin := 0;
    SI.nMax := C - 1;
    SI.nPage := L;
    SI.nPos := FScrollPos;
    if not FBarVisible then
    begin
      ShowScrollBar(Handle, Bar, True);
      FBarVisible := True;
    end;
    SetScrollInfo(Handle, Bar, SI, True);
  end
  else if FBarVisible then
  begin
    ShowScrollBar(Handle, Bar, False);
    FBarVisible := False;
  end;
end;

procedure TCExpandPanel.ScrollTo(APos: Integer);
begin
  APos := EnsureRange(APos, 0, Max(0, FContentLength - FViewLength));
  if APos = FScrollPos then Exit;
  FScrollPos := APos;
  LayoutPanels;
  Invalidate;
end;

procedure TCExpandPanel.HandleScroll(ACode: Integer);
var
  SI: TScrollInfo;
  Line: Integer;
begin
  Line := Scale96ToFont(cScrollLine96);
  case ACode of
    SB_LINEUP:   ScrollTo(FScrollPos - Line);
    SB_LINEDOWN: ScrollTo(FScrollPos + Line);
    SB_PAGEUP:   ScrollTo(FScrollPos - FViewLength);
    SB_PAGEDOWN: ScrollTo(FScrollPos + FViewLength);
    SB_TOP:      ScrollTo(0);
    SB_BOTTOM:   ScrollTo(MaxInt div 2);
    SB_THUMBTRACK, SB_THUMBPOSITION:
      begin
        FillChar(SI, SizeOf(SI), 0);
        SI.cbSize := SizeOf(SI);
        SI.fMask := SIF_TRACKPOS;
        if GetScrollInfo(Handle, ScrollBarKind, SI) then
          ScrollTo(SI.nTrackPos);
      end;
  end;
end;

procedure TCExpandPanel.WMVScroll(var Msg: TLMVScroll);
begin
  if FOrientation = eoVertical then
    HandleScroll(Msg.ScrollCode);
end;

procedure TCExpandPanel.WMHScroll(var Msg: TLMHScroll);
begin
  if FOrientation = eoHorizontal then
    HandleScroll(Msg.ScrollCode);
end;

{ マウスホイール：縦の入れ物はホイール、横の入れ物は Shift + ホイールでスクロールする。
  パネルの上の部品（TMemo など）が先にホイールを受け取るので、部品の上では動かさない }
function TCExpandPanel.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
var
  Step: Integer;
begin
  Result := False;
  if FScrollable and FBarVisible and
     (((FOrientation = eoVertical) and not (ssShift in Shift)) or
      ((FOrientation = eoHorizontal) and (ssShift in Shift))) then
  begin
    Step := Scale96ToFont(cScrollLine96) * 3;
    ScrollTo(FScrollPos - (WheelDelta * Step) div 120);
    Result := True;
    Exit;
  end;
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
end;

initialization
  // .lfm からパネルを読み込めるようにする
  RegisterClass(TCRollout);

end.
