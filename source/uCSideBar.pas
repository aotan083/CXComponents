{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ uCSideBar
  Edge のサイドバーのような「アイコン列＋開閉するパネル＋スプリッター」を
  1 つにまとめたコンポーネント（TCSideBar）と、そのページ（TCSideBarPage）。

  設計書：docs\TCSideBar_Design.md
 }
unit uCSideBar;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types,
  LCLType, LCLIntf, LCLProc, LMessages,
  Controls, Graphics, GraphType, Forms, Menus, ImgList, ExtCtrls, Themes;

type
  TCSideBar = class;

  { ページのイベントの型 }
  TCSideBarPageEvent = procedure(Sender: TObject; Index: Integer) of object;
  TCSideBarChangingEvent = procedure(Sender: TObject; Index: Integer;
    var Allow: Boolean) of object;

  { 設計時に、IDE で選ぶ部品を変える手続き（設計時パッケージ uCSideBarReg が設定する）。
    実行時パッケージは IDE の機能（IDEIntf）を使えないため、手続きを受け取って呼ぶ }
  TCSideBarDesignSelectProc = procedure(AComponent: TComponent);

  { TCSideBarPage
    1 ページ分のパネル。アプリ側のコントロールをこの上に置く。
    親は必ず TCSideBar。親が決まった時点で TCSideBar のページ一覧に入る。 }

  TCSideBarPage = class(TCustomControl)
  private
    FImageIndex: TImageIndex;
    FPanelWidth: Integer;
    FPageVisible: Boolean;
    FShortCut: TShortCut;
    function GetSideBar: TCSideBar;
    procedure SetImageIndex(const AValue: TImageIndex);
    procedure SetPanelWidth(AValue: Integer);
    procedure SetPageVisible(const AValue: Boolean);
    procedure SetActiveState(AActive: Boolean);
  protected
    procedure SetParent(NewParent: TWinControl); override;
    procedure TextChanged; override;
    procedure CMHitTest(var Message: TCMHitTest); message CM_HITTEST;
    procedure CMEnabledChanged(var Message: TLMessage); message CM_ENABLEDCHANGED;
    procedure DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
      const AXProportion, AYProportion: Double); override;
  public
    constructor Create(TheOwner: TComponent); override;
    property SideBar: TCSideBar read GetSideBar;
  published
    property Caption;
    property ImageIndex: TImageIndex read FImageIndex write SetImageIndex default -1;
    property PanelWidth: Integer read FPanelWidth write SetPanelWidth default 250;
    property PageVisible: Boolean read FPageVisible write SetPageVisible default True;
    property Enabled;
    property ShortCut: TShortCut read FShortCut write FShortCut default 0;
    property Color;
    property Font;
    property ParentFont;
    property PopupMenu;
    property ShowHint;
    property ParentShowHint;
  end;

  { TCSideBar
    アイコン列・ヘッダー・スプリッターは自前で描画する。
    ページは子コントロール（TCSideBarPage）として持ち、開いているページだけ表示する。 }

  TCSideBar = class(TCustomControl)
  private
    FPages: TFPList;                  // ページの順番
    FActivePage: TCSideBarPage;
    FImages: TCustomImageList;
    FImageChangeLink: TChangeLink;
    FImagesWidth: Integer;
    FIconBarWidth: Integer;
    FMinPanelWidth: Integer;
    FMaxPanelWidth: Integer;
    FSplitterWidth: Integer;
    FResizeStyle: TResizeStyle;
    FShowHeader: Boolean;             // ヘッダー（Caption と [×]）を出すか
    FShowCloseButton: Boolean;
    FIconPopupMenu: TPopupMenu;
    FOnPageChanging: TCSideBarChangingEvent;
    FOnPageOpen: TCSideBarPageEvent;
    FOnPageClose: TCSideBarPageEvent;
    FOnPanelResize: TNotifyEvent;
    // マウスの状態
    FHotPage: TCSideBarPage;          // マウスが乗っているアイコンのページ
    FHotClose: Boolean;               // マウスが [×] に乗っている
    FDownPage: TCSideBarPage;         // 左ボタンを押したアイコンのページ
    FDownClose: Boolean;              // 左ボタンを [×] で押した
    // スプリッターのドラッグ
    FDragging: Boolean;
    FDragStartX: Integer;
    FDragStartWidth: Integer;
    FDragWidth: Integer;
    FRubberBand: HWND;
    FKeyHandlerAdded: Boolean;
    // 設計時：サイドバーが MouseUp を処理した後、デザイナが押下中の状態を残している（CMDesignHitTest 参照）
    FDesignerPressLeft: Boolean;
    function GetActivePageIndex: Integer;
    function GetPage(Index: Integer): TCSideBarPage;
    function GetPageCount: Integer;
    procedure SetActivePage(AValue: TCSideBarPage);
    procedure SetActivePageIndex(AValue: Integer);
    procedure SetIconBarWidth(AValue: Integer);
    procedure SetIconPopupMenu(AValue: TPopupMenu);
    procedure SetImages(AValue: TCustomImageList);
    procedure SetImagesWidth(AValue: Integer);
    procedure SetMaxPanelWidth(AValue: Integer);
    procedure SetMinPanelWidth(AValue: Integer);
    procedure SetShowHeader(AValue: Boolean);
    procedure SetShowCloseButton(AValue: Boolean);
    procedure SetSplitterWidth(AValue: Integer);
    procedure ImageListChange(Sender: TObject);
    procedure AppKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    // 状態の判定
    function EventsEnabled: Boolean;
    function IconShown(APage: TCSideBarPage): Boolean;
    function CanOpenPage(APage: TCSideBarPage): Boolean;
    // 大きさと位置
    function HeaderHeight: Integer;
    function CloseButtonSize: Integer;
    function HeaderRect: TRect;
    function CloseButtonRect: TRect;
    function SplitterRect: TRect;
    function IconRect(APage: TCSideBarPage): TRect;
    function PageAtIcon(X, Y: Integer): TCSideBarPage;
    function InCloseButton(X, Y: Integer): Boolean;
    function InSplitter(X, Y: Integer): Boolean;
    function ClampPanelWidth(AValue: Integer): Integer;
    // 開閉
    function ChangeActivePage(NewPage: TCSideBarPage): Boolean;
    procedure SetActivePageSilently(NewPage: TCSideBarPage);
    procedure UserTogglePage(APage: TCSideBarPage);
    procedure UpdatePageVisibility;
    procedure LayoutChanged;
    // スプリッター
    procedure BeginSplitterDrag(X: Integer);
    procedure MoveSplitterDrag(X: Integer);
    procedure EndSplitterDrag(X: Integer);
    procedure UpdateRubberBand;
    procedure CancelSplitterDrag;
    procedure SetHot(APage: TCSideBarPage; AClose: Boolean);
    // 描画
    procedure PaintIcons;
    procedure PaintHeader;
    procedure PaintSplitter;
  protected
    // TCSideBarPage から呼ばれる
    procedure AddPage(APage: TCSideBarPage);
    procedure RemovePage(APage: TCSideBarPage);
    procedure PageChanged(APage: TCSideBarPage);
    procedure PageVisibleChanged(APage: TCSideBarPage);
    procedure PanelWidthChanged(APage: TCSideBarPage);

    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure AdjustClientRect(var ARect: TRect); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: Integer;
      WithThemeSpace: Boolean); override;
    procedure DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
      const AXProportion, AYProportion: Double); override;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure CaptureChanged; override;
    procedure DoContextPopup(MousePos: TPoint; var Handled: Boolean); override;
    procedure CMHintShow(var Message: TLMessage); message CM_HINTSHOW;
    procedure CMDesignHitTest(var Message: TCMDesignHitTest); message CM_DESIGNHITTEST;
    procedure CMEnabledChanged(var Message: TLMessage); message CM_ENABLEDCHANGED;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure OpenPage(Index: Integer);
    procedure ClosePage;
    // コンポーネントエディタの「上へ移動」「下へ移動」で使う
    procedure MovePage(CurIndex, NewIndex: Integer);
    property Pages[Index: Integer]: TCSideBarPage read GetPage;
    property PageCount: Integer read GetPageCount;
    property ActivePageIndex: Integer read GetActivePageIndex write SetActivePageIndex;
  published
    property ActivePage: TCSideBarPage read FActivePage write SetActivePage;
    property Images: TCustomImageList read FImages write SetImages;
    property ImagesWidth: Integer read FImagesWidth write SetImagesWidth default 0;
    property IconBarWidth: Integer read FIconBarWidth write SetIconBarWidth default 40;
    property MinPanelWidth: Integer read FMinPanelWidth write SetMinPanelWidth default 150;
    property MaxPanelWidth: Integer read FMaxPanelWidth write SetMaxPanelWidth default 600;
    property SplitterWidth: Integer read FSplitterWidth write SetSplitterWidth default 8;
    property ResizeStyle: TResizeStyle read FResizeStyle write FResizeStyle default rsLine;
    property ShowHeader: Boolean read FShowHeader write SetShowHeader default True;
    property ShowCloseButton: Boolean read FShowCloseButton write SetShowCloseButton default True;
    property IconPopupMenu: TPopupMenu read FIconPopupMenu write SetIconPopupMenu;
    property OnPageChanging: TCSideBarChangingEvent read FOnPageChanging write FOnPageChanging;
    property OnPageOpen: TCSideBarPageEvent read FOnPageOpen write FOnPageOpen;
    property OnPageClose: TCSideBarPageEvent read FOnPageClose write FOnPageClose;
    property OnPanelResize: TNotifyEvent read FOnPanelResize write FOnPanelResize;
    property Align default alLeft;
    property Anchors;
    property BorderSpacing;
    property Constraints;
    property Enabled;
    property Font;
    property ParentFont;
    property ParentShowHint;
    property ShowHint;
    property Visible;
  end;

var
  CSideBarDesignSelect: TCSideBarDesignSelectProc = nil;

implementation

const
  // 100% のときの大きさ。描画のたびに Scale96ToFont で拡大する
  cHeaderHeight96 = 32;
  cCloseButton96 = 20;
  cIconInset96 = 4;       // アイコンの枠とハイライトの間の余白
  cIconRadius96 = 6;      // ハイライトの角の丸み
  cTextPadding96 = 8;     // ヘッダーの文字の左右の余白

resourcestring
  rsCSideBarPageParent = 'TCSideBarPage は TCSideBar の上にだけ置けます';

{ TCSideBarPage }

constructor TCSideBarPage.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FImageIndex := -1;
  FPanelWidth := 250;
  FPageVisible := True;
  FShortCut := 0;
  // TCustomPage と同じ ControlStyle
  //  csAcceptsControls  ：ページの上に部品を置ける
  //  csDesignFixedBounds：設計時にページを動かしたり大きさを変えたりできない
  //  csNoDesignVisible  ：設計時も表示しない（開いたときに SetActiveState で外す）
  //  csNoFocus          ：ページ自体はフォーカスを受けない
  ControlStyle := ControlStyle + [csAcceptsControls, csDesignFixedBounds,
    csNoDesignVisible, csNoFocus];
  // ページは TCSideBar のクライアント領域（ヘッダーがあればその下）いっぱいに置く
  Align := alClient;
  ParentColor := False;
  Color := clBtnFace;
  Caption := '';
  // 開いているページだけ表示する。親に入った時点では閉じた状態
  Visible := False;
end;

function TCSideBarPage.GetSideBar: TCSideBar;
begin
  if Parent is TCSideBar then
    Result := TCSideBar(Parent)
  else
    Result := nil;
end;

procedure TCSideBarPage.SetImageIndex(const AValue: TImageIndex);
begin
  if FImageIndex = AValue then Exit;
  FImageIndex := AValue;
  if SideBar <> nil then
    SideBar.PageChanged(Self);
end;

procedure TCSideBarPage.SetPanelWidth(AValue: Integer);
begin
  if AValue < 0 then
    AValue := 0;
  if FPanelWidth = AValue then Exit;
  FPanelWidth := AValue;
  // 開いているページなら、サイドバーの幅を計算し直す
  if SideBar <> nil then
    SideBar.PanelWidthChanged(Self);
end;

procedure TCSideBarPage.SetPageVisible(const AValue: Boolean);
begin
  if FPageVisible = AValue then Exit;
  FPageVisible := AValue;
  // アイコンの並びを描き直す。実行時に開いているページを隠したら閉じる
  if SideBar <> nil then
    SideBar.PageVisibleChanged(Self);
end;

{ 開いているページかどうかを切り替える。
  LCL の TCustomTabControl.UpdateDesignerFlags と同じく、
  開いているページだけ csNoDesignVisible を外し、閉じているページには付ける。
  設計時、デザイナは csNoDesignVisible のある部品を「その場所にない」として扱うため、
  開いているページから外さないと、置いた部品がページではなくフォームに入ってしまう。
  ・閉じるとき：先にフラグを付けてから Visible := False（設計時も非表示が反映される）
  ・開くとき：フラグを外して Visible := True。設計時はこれだけでは表示が更新されないため、
    UpdateControlState で表示を反映する }
procedure TCSideBarPage.SetActiveState(AActive: Boolean);
begin
  if AActive then
  begin
    ControlStyle := ControlStyle - [csNoDesignVisible];
    Visible := True;
  end
  else
  begin
    ControlStyle := ControlStyle + [csNoDesignVisible];
    Visible := False;
  end;
  if csDesigning in ComponentState then
    UpdateControlState;
end;

{ 親の付け替え
  TCustomPage.SetParent と同じ方式。
  ・親が TCSideBar になったとき、そのページ一覧の末尾に入れる（.lfm の読み込み順も保たれる）
  ・親が外れたとき（ページの破棄時もここを通る）、ページ一覧から外す }
procedure TCSideBarPage.SetParent(NewParent: TWinControl);
var
  OldParent: TWinControl;
begin
  if NewParent = Parent then Exit;
  if (NewParent <> nil) and not (NewParent is TCSideBar) then
    raise EInvalidOperation.Create(rsCSideBarPageParent);
  OldParent := Parent;
  if OldParent is TCSideBar then
    TCSideBar(OldParent).RemovePage(Self);
  inherited SetParent(NewParent);
  if NewParent is TCSideBar then
    TCSideBar(NewParent).AddPage(Self);
end;

procedure TCSideBarPage.TextChanged;
begin
  inherited TextChanged;
  // Caption はヘッダーとヒントに使うので、サイドバーを描き直す
  if SideBar <> nil then
    SideBar.PageChanged(Self);
end;

{ 開いていないページはマウスを受けない（TCustomPage.CMHitTest と同じ） }
procedure TCSideBarPage.CMHitTest(var Message: TCMHitTest);
begin
  if (SideBar <> nil) and (SideBar.ActivePage <> Self) then
    Message.Result := 0
  else
    inherited CMHitTest(Message);
end;

procedure TCSideBarPage.CMEnabledChanged(var Message: TLMessage);
begin
  inherited CMEnabledChanged(Message);
  // アイコンを灰色にする／戻すため、サイドバーを描き直す
  if SideBar <> nil then
    SideBar.PageChanged(Self);
end;

{ 表示スケールが変わったとき、PanelWidth を拡大する
  LCL は子にも AutoAdjustLayout を呼ぶので、ページの幅はページ側で拡大する }
procedure TCSideBarPage.DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
  const AXProportion, AYProportion: Double);
begin
  inherited DoAutoAdjustLayout(AMode, AXProportion, AYProportion);
  if AMode in [lapAutoAdjustWithoutHorizontalScrolling, lapAutoAdjustForDPI] then
    PanelWidth := Round(FPanelWidth * AXProportion);
end;

{ TCSideBar }

constructor TCSideBar.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FPages := TFPList.Create;
  FImageChangeLink := TChangeLink.Create;
  FImageChangeLink.OnChange := @ImageListChange;
  FImagesWidth := 0;
  FIconBarWidth := 40;
  FMinPanelWidth := 150;
  FMaxPanelWidth := 600;
  FSplitterWidth := 8;
  FResizeStyle := rsLine;
  FShowHeader := True;
  FShowCloseButton := True;
  FRubberBand := 0;
  // 部品はページの上にだけ置けるようにする（サイドバー自身には置けない）。
  // csCaptureMouse：スプリッターのドラッグ中、外へ出てもマウスを受け取る
  ControlStyle := ControlStyle - [csAcceptsControls] + [csCaptureMouse, csClickEvents];
  Color := clBtnFace;
  Align := alLeft;
  // 幅はサイドバーが自分で決める。AutoSize は公開しない
  AutoSize := True;
  // ショートカットキーの受け取り。設計時は登録しない
  if not (csDesigning in ComponentState) and Assigned(Application) then
  begin
    Application.AddOnKeyDownHandler(@AppKeyDown, False);
    FKeyHandlerAdded := True;
  end;
end;

destructor TCSideBar.Destroy;
begin
  if FKeyHandlerAdded and Assigned(Application) then
    Application.RemoveOnKeyDownHandler(@AppKeyDown);
  FKeyHandlerAdded := False;
  if FRubberBand <> 0 then
  begin
    DestroyRubberBand(FRubberBand);
    FRubberBand := 0;
  end;
  // inherited の中で子のページの親が外れ、RemovePage が呼ばれるので、
  // FPages は inherited の後で解放する
  inherited Destroy;
  FreeAndNil(FImageChangeLink);
  FreeAndNil(FPages);
end;

{ ---- 状態の判定 ---- }

{ イベントを呼んでよいか。読み込み中・設計時・破棄中は呼ばない }
function TCSideBar.EventsEnabled: Boolean;
begin
  Result := ComponentState * [csLoading, csReading, csDesigning, csDestroying] = [];
end;

{ アイコン列にアイコンを出すか。設計時は PageVisible に関係なく出す }
function TCSideBar.IconShown(APage: TCSideBarPage): Boolean;
begin
  Result := (APage <> nil) and ((csDesigning in ComponentState) or APage.PageVisible);
end;

{ そのページを開けるか。実行時は PageVisible と Enabled が True のときだけ }
function TCSideBar.CanOpenPage(APage: TCSideBarPage): Boolean;
begin
  if APage = nil then
    Exit(False);
  if csDesigning in ComponentState then
    Exit(True);
  Result := APage.PageVisible and APage.Enabled;
end;

{ ---- 大きさと位置 ---- }

function TCSideBar.HeaderHeight: Integer;
begin
  Result := Scale96ToFont(cHeaderHeight96);
end;

function TCSideBar.CloseButtonSize: Integer;
begin
  Result := Scale96ToFont(cCloseButton96);
end;

{ ヘッダー：アイコン列の右からスプリッターの左まで、上端から HeaderHeight の高さ。
  閉じているとき、または ShowHeader=False のときはヘッダーがない（空の領域を返す） }
function TCSideBar.HeaderRect: TRect;
begin
  if (FActivePage = nil) or not FShowHeader then
    Exit(Rect(0, 0, 0, 0));
  Result := Rect(FIconBarWidth, 0, ClientWidth - FSplitterWidth, HeaderHeight);
  if Result.Right < Result.Left then
    Result.Right := Result.Left;
end;

{ [×]：ヘッダーの右端に、縦の中央にそろえて置く。
  ヘッダーがないとき（閉じている、ShowHeader=False）と ShowCloseButton=False のときは、
  空の領域を返す。これで [×] のクリック判定とハイライトも起きない }
function TCSideBar.CloseButtonRect: TRect;
var
  H: TRect;
  S, M: Integer;
begin
  if (FActivePage = nil) or not FShowHeader or not FShowCloseButton then
    Exit(Rect(0, 0, 0, 0));
  H := HeaderRect;
  S := CloseButtonSize;
  M := (H.Bottom - H.Top - S) div 2;
  Result := Rect(H.Right - M - S, H.Top + M, H.Right - M, H.Top + M + S);
  if Result.Left < H.Left then
    Result.Left := H.Left;
end;

{ スプリッター：パネルの右端 SplitterWidth の幅（閉じているときはない）。
  ShowHeader に関係なく、上端から下端まで }
function TCSideBar.SplitterRect: TRect;
begin
  if FActivePage = nil then
    Exit(Rect(0, 0, 0, 0));
  Result := Rect(ClientWidth - FSplitterWidth, 0, ClientWidth, ClientHeight);
end;

{ アイコンの枠：アイコン列の上から、表示するアイコンを IconBarWidth の正方形で並べる }
function TCSideBar.IconRect(APage: TCSideBarPage): TRect;
var
  I, Row: Integer;
  P: TCSideBarPage;
begin
  Result := Rect(0, 0, 0, 0);
  if not IconShown(APage) then Exit;
  Row := 0;
  for I := 0 to FPages.Count - 1 do
  begin
    P := TCSideBarPage(FPages[I]);
    if not IconShown(P) then Continue;
    if P = APage then
    begin
      Result := Rect(0, Row * FIconBarWidth, FIconBarWidth, (Row + 1) * FIconBarWidth);
      Exit;
    end;
    Inc(Row);
  end;
end;

{ 座標の下にあるアイコンのページを返す。アイコンがなければ nil }
function TCSideBar.PageAtIcon(X, Y: Integer): TCSideBarPage;
var
  I, Row, Target: Integer;
  P: TCSideBarPage;
begin
  Result := nil;
  if (FIconBarWidth <= 0) or (X < 0) or (X >= FIconBarWidth) or (Y < 0) then Exit;
  Target := Y div FIconBarWidth;
  Row := 0;
  for I := 0 to FPages.Count - 1 do
  begin
    P := TCSideBarPage(FPages[I]);
    if not IconShown(P) then Continue;
    if Row = Target then
      Exit(P);
    Inc(Row);
  end;
end;

function TCSideBar.InCloseButton(X, Y: Integer): Boolean;
begin
  Result := PtInRect(CloseButtonRect, Point(X, Y));
end;

function TCSideBar.InSplitter(X, Y: Integer): Boolean;
begin
  Result := PtInRect(SplitterRect, Point(X, Y));
end;

{ ドラッグで変えられる幅の範囲に収める。MaxPanelWidth = 0 は上限なし }
function TCSideBar.ClampPanelWidth(AValue: Integer): Integer;
begin
  Result := AValue;
  if Result < FMinPanelWidth then
    Result := FMinPanelWidth;
  if (FMaxPanelWidth > 0) and (Result > FMaxPanelWidth) then
    Result := FMaxPanelWidth;
  if Result < 0 then
    Result := 0;
end;

{ ---- プロパティ ---- }

function TCSideBar.GetPage(Index: Integer): TCSideBarPage;
begin
  // 範囲外なら TFPList が EListError を出す
  Result := TCSideBarPage(FPages[Index]);
end;

function TCSideBar.GetPageCount: Integer;
begin
  Result := FPages.Count;
end;

function TCSideBar.GetActivePageIndex: Integer;
begin
  if FActivePage = nil then
    Result := -1
  else
    Result := FPages.IndexOf(FActivePage);
end;

{ ActivePageIndex：範囲外の値は例外を出さずに何もしない（LCL の PageIndex と同じ） }
procedure TCSideBar.SetActivePageIndex(AValue: Integer);
begin
  if (AValue < -1) or (AValue >= FPages.Count) then Exit;
  if AValue = -1 then
    ChangeActivePage(nil)
  else
    ChangeActivePage(TCSideBarPage(FPages[AValue]));
end;

{ ActivePage：.lfm の読み込み中は値を持つだけにし、Loaded で表示を決める }
procedure TCSideBar.SetActivePage(AValue: TCSideBarPage);
begin
  if csLoading in ComponentState then
  begin
    FActivePage := AValue;
    Exit;
  end;
  if (AValue <> nil) and (FPages.IndexOf(AValue) < 0) then Exit;  // 別のサイドバーのページ
  ChangeActivePage(AValue);
end;

procedure TCSideBar.SetIconBarWidth(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  if FIconBarWidth = AValue then Exit;
  FIconBarWidth := AValue;
  LayoutChanged;
end;

procedure TCSideBar.SetIconPopupMenu(AValue: TPopupMenu);
begin
  if FIconPopupMenu = AValue then Exit;
  if FIconPopupMenu <> nil then
    FIconPopupMenu.RemoveFreeNotification(Self);
  FIconPopupMenu := AValue;
  if FIconPopupMenu <> nil then
    FIconPopupMenu.FreeNotification(Self);
end;

procedure TCSideBar.SetImages(AValue: TCustomImageList);
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

{ ImagesWidth は 100% のときの値のまま持つ。拡大は ImageList に任せる }
procedure TCSideBar.SetImagesWidth(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  if FImagesWidth = AValue then Exit;
  FImagesWidth := AValue;
  Invalidate;
end;

procedure TCSideBar.SetMaxPanelWidth(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  FMaxPanelWidth := AValue;
end;

procedure TCSideBar.SetMinPanelWidth(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  FMinPanelWidth := AValue;
end;

{ ShowHeader：ヘッダー（Caption と [×]）を出すか。
  変えると、クライアント領域の上端が変わる（AdjustClientRect）ので、LayoutChanged でページを並べ直して描き直す。
  サイドバーの幅は変わらず、イベントも呼ばない。
  [×] がなくなるときに、マウスが乗っていた・押していた状態が残らないよう消しておく }
procedure TCSideBar.SetShowHeader(AValue: Boolean);
begin
  if FShowHeader = AValue then Exit;
  FShowHeader := AValue;
  FHotClose := False;
  FDownClose := False;
  LayoutChanged;
end;

{ ShowCloseButton：[×] を出すか。ShowHeader=False のときは値に関係なく出ない（CloseButtonRect） }
procedure TCSideBar.SetShowCloseButton(AValue: Boolean);
begin
  if FShowCloseButton = AValue then Exit;
  FShowCloseButton := AValue;
  Invalidate;
end;

procedure TCSideBar.SetSplitterWidth(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  if FSplitterWidth = AValue then Exit;
  FSplitterWidth := AValue;
  LayoutChanged;
end;

procedure TCSideBar.ImageListChange(Sender: TObject);
begin
  Invalidate;
end;

{ ---- ページ一覧の管理（TCSideBarPage から呼ばれる） ---- }

procedure TCSideBar.AddPage(APage: TCSideBarPage);
begin
  if FPages.IndexOf(APage) >= 0 then Exit;
  FPages.Add(APage);
  APage.SetActiveState(APage = FActivePage);
  if not (csLoading in ComponentState) then
    Invalidate;
end;

{ ページ一覧から外す。開いていたページなら、イベントを呼ばずに閉じた状態にする }
procedure TCSideBar.RemovePage(APage: TCSideBarPage);
var
  Idx: Integer;
begin
  if FPages = nil then Exit;
  Idx := FPages.IndexOf(APage);
  if Idx < 0 then Exit;
  FPages.Delete(Idx);
  if FHotPage = APage then FHotPage := nil;
  if FDownPage = APage then FDownPage := nil;
  if FActivePage = APage then
  begin
    FActivePage := nil;
    if FDragging then
    begin
      FDragging := False;
      if FRubberBand <> 0 then
      begin
        DestroyRubberBand(FRubberBand);
        FRubberBand := 0;
      end;
    end;
  end;
  if not (csDestroying in ComponentState) then
    LayoutChanged;
end;

procedure TCSideBar.PageChanged(APage: TCSideBarPage);
begin
  Invalidate;
end;

{ PageVisible が変わった。実行時に開いているページが隠されたら、イベントなしで閉じる }
procedure TCSideBar.PageVisibleChanged(APage: TCSideBarPage);
begin
  if not (csDesigning in ComponentState) and not APage.PageVisible
    and (FActivePage = APage) then
    SetActivePageSilently(nil)
  else
    Invalidate;
end;

procedure TCSideBar.PanelWidthChanged(APage: TCSideBarPage);
begin
  if APage = FActivePage then
    LayoutChanged;
end;

{ ---- 開閉 ---- }

{ 開くページを NewPage にする（nil なら閉じる）。
  イベントを呼べる状態なら、6.3 の順番でイベントを呼ぶ。
  開閉の途中で幅が 2 回変わらないよう、終わるまで自動サイズ調整を止める。
  戻り値：状態が変わったら True }
function TCSideBar.ChangeActivePage(NewPage: TCSideBarPage): Boolean;
var
  Allow: Boolean;
  OldPage: TCSideBarPage;
  OldIndex: Integer;
begin
  Result := False;
  if NewPage = FActivePage then Exit;
  if (NewPage <> nil) and not CanOpenPage(NewPage) then Exit;

  if not EventsEnabled then
  begin
    SetActivePageSilently(NewPage);
    Exit(True);
  end;

  // 1. 開く・切り替える・閉じる前（閉じるときは -1）
  Allow := True;
  if Assigned(FOnPageChanging) then
  begin
    if NewPage = nil then
      FOnPageChanging(Self, -1, Allow)
    else
      FOnPageChanging(Self, FPages.IndexOf(NewPage), Allow);
  end;
  if not Allow then Exit;
  // イベントの中で状態が変えられていたら、何もしない
  if NewPage = FActivePage then Exit;
  if (NewPage <> nil) and (FPages.IndexOf(NewPage) < 0) then Exit;

  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TCSideBar.ChangeActivePage'){$ENDIF};
  try
    // 2. 開いていたページを非表示にして OnPageClose
    OldPage := FActivePage;
    if OldPage <> nil then
    begin
      OldIndex := FPages.IndexOf(OldPage);
      FActivePage := nil;
      OldPage.SetActiveState(False);
      if Assigned(FOnPageClose) then
        FOnPageClose(Self, OldIndex);
    end;
    // 3. 新しいページを表示して OnPageOpen
    if (NewPage <> nil) and (FPages.IndexOf(NewPage) >= 0) and (FActivePage = nil) then
    begin
      FActivePage := NewPage;
      NewPage.SetActiveState(True);
      LayoutChanged;
      if Assigned(FOnPageOpen) then
        FOnPageOpen(Self, FPages.IndexOf(NewPage));
    end;
    LayoutChanged;
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TCSideBar.ChangeActivePage'){$ENDIF};
  end;
  Result := True;
end;

{ イベントを呼ばずに開くページを変える（読み込み・設計時・ページを隠したときなど） }
procedure TCSideBar.SetActivePageSilently(NewPage: TCSideBarPage);
begin
  if NewPage = FActivePage then Exit;
  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TCSideBar.SetActivePageSilently'){$ENDIF};
  try
    if FActivePage <> nil then
      FActivePage.SetActiveState(False);
    FActivePage := NewPage;
    if FActivePage <> nil then
      FActivePage.SetActiveState(True);
    LayoutChanged;
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TCSideBar.SetActivePageSilently'){$ENDIF};
  end;
end;

{ アイコンのクリック・ショートカットキーと同じ動き：開いていれば閉じ、閉じていれば開く。
  設計時は、開閉の状態を .lfm に保存するためデザイナに変更を知らせる }
procedure TCSideBar.UserTogglePage(APage: TCSideBarPage);
var
  DidChange: Boolean;
begin
  if APage = FActivePage then
    DidChange := ChangeActivePage(nil)
  else
    DidChange := ChangeActivePage(APage);
  if DidChange and (csDesigning in ComponentState) then
  begin
    OwnerFormDesignerModified(Self);
    // 開いたページ（閉じたときはサイドバー）を IDE で選んだ状態にする。
    // 選んだままにすると、隠れたページの部品の選択枠が、開いたページの上に残って見えるため
    //（LCL のページの右クリックメニュー「ページの表示」と同じ動き）
    if Assigned(CSideBarDesignSelect) then
    begin
      if FActivePage <> nil then
        CSideBarDesignSelect(FActivePage)
      else
        CSideBarDesignSelect(Self);
    end;
  end;
end;

{ 開いているページだけ表示する }
procedure TCSideBar.UpdatePageVisibility;
var
  I: Integer;
  P: TCSideBarPage;
begin
  for I := 0 to FPages.Count - 1 do
  begin
    P := TCSideBarPage(FPages[I]);
    P.SetActiveState(P = FActivePage);
  end;
end;

{ 幅・クライアント領域が変わったとき：幅を計算し直し、ページを並べ直して描き直す }
procedure TCSideBar.LayoutChanged;
begin
  if csDestroying in ComponentState then Exit;
  InvalidatePreferredSize;
  AdjustSize;
  ReAlign;
  Invalidate;
end;

procedure TCSideBar.OpenPage(Index: Integer);
var
  P: TCSideBarPage;
begin
  // 範囲外なら TFPList が EListError を出す
  P := TCSideBarPage(FPages[Index]);
  ChangeActivePage(P);
end;

procedure TCSideBar.ClosePage;
begin
  ChangeActivePage(nil);
end;

{ ページの順番を変える。
  FPages の順番と子の順番（Controls）を同じにして、.lfm にもこの順番で保存されるようにする。
  TCustomTabControl の TNBPages.Move と同じ方式 }
procedure TCSideBar.MovePage(CurIndex, NewIndex: Integer);
var
  P: TCSideBarPage;
  NewControlIndex: Integer;
begin
  if (CurIndex < 0) or (CurIndex >= FPages.Count) then Exit;
  if (NewIndex < 0) or (NewIndex >= FPages.Count) then Exit;
  if CurIndex = NewIndex then Exit;
  P := TCSideBarPage(FPages[CurIndex]);
  // 移動先にいるページの子の番号に入れると、ほかのページが 1 つずつずれる
  NewControlIndex := GetControlIndex(TCSideBarPage(FPages[NewIndex]));
  FPages.Move(CurIndex, NewIndex);
  SetControlIndex(P, NewControlIndex);
  Invalidate;
end;

{ ---- LCL の仕組みの上書き ---- }

{ 読み込みが終わったら、ActivePage に従ってページの表示と幅を決める。イベントは呼ばない。
  ShowHeader も読み込み済みなので、LayoutChanged でページの上端も決まる }
procedure TCSideBar.Loaded;
begin
  inherited Loaded;
  if (FActivePage <> nil) and
     ((FPages.IndexOf(FActivePage) < 0) or not CanOpenPage(FActivePage)) then
    FActivePage := nil;
  UpdatePageVisibility;
  LayoutChanged;
end;

procedure TCSideBar.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    if AComponent = FImages then
    begin
      FImages := nil;
      Invalidate;
    end;
    if AComponent = FIconPopupMenu then
      FIconPopupMenu := nil;
  end;
end;

{ クライアント領域から、アイコン列・ヘッダー・スプリッターを除く。
  ページは Align = alClient なので、残った領域いっぱいに置かれる。
  ・ShowHeader=True：ヘッダーの高さを除くので、ページはヘッダーの下から始まる
  ・ShowHeader=False：ヘッダーの高さを除かないので、ページはパネルの上端から始まる }
procedure TCSideBar.AdjustClientRect(var ARect: TRect);
begin
  inherited AdjustClientRect(ARect);
  Inc(ARect.Left, FIconBarWidth);
  if FActivePage <> nil then
  begin
    if FShowHeader then
      Inc(ARect.Top, HeaderHeight);
    Dec(ARect.Right, FSplitterWidth);
  end;
  if ARect.Right < ARect.Left then
    ARect.Right := ARect.Left;
  if ARect.Bottom < ARect.Top then
    ARect.Bottom := ARect.Top;
end;

{ サイドバーの幅。AutoSize により、この幅が使われる。高さは Align に任せる。
  ShowHeader には関係しない }
procedure TCSideBar.CalculatePreferredSize(var PreferredWidth,
  PreferredHeight: Integer; WithThemeSpace: Boolean);
begin
  PreferredWidth := FIconBarWidth;
  if FActivePage <> nil then
    Inc(PreferredWidth, FActivePage.PanelWidth + FSplitterWidth);
  if PreferredWidth <= 0 then
    PreferredWidth := 1;   // 0 以下は「未指定」と扱われるため
  PreferredHeight := 0;
end;

{ 表示スケールが変わったとき、幅のプロパティを拡大する。
  PanelWidth はページ側、ImagesWidth は ImageList 側で扱う }
procedure TCSideBar.DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
  const AXProportion, AYProportion: Double);
begin
  inherited DoAutoAdjustLayout(AMode, AXProportion, AYProportion);
  if AMode in [lapAutoAdjustWithoutHorizontalScrolling, lapAutoAdjustForDPI] then
  begin
    FIconBarWidth := Round(FIconBarWidth * AXProportion);
    FMinPanelWidth := Round(FMinPanelWidth * AXProportion);
    if FMaxPanelWidth > 0 then
      FMaxPanelWidth := Round(FMaxPanelWidth * AXProportion);
    FSplitterWidth := Round(FSplitterWidth * AXProportion);
    LayoutChanged;
  end;
end;

{ ---- 描画 ---- }

{ 背景、アイコン列を描き、開いているときはヘッダー（ShowHeader=True のときだけ）とスプリッターを描く }
procedure TCSideBar.Paint;
begin
  // 全体の背景
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clBtnFace;
  Canvas.FillRect(ClientRect);
  PaintIcons;
  if FActivePage <> nil then
  begin
    if FShowHeader then
      PaintHeader;
    PaintSplitter;
  end;
end;

{ アイコン列：表示するページのアイコンを上から並べる。
  開いているページは clHighlight の枠の角丸、マウスが乗っているアイコンは clBtnHighlight の角丸。
  アイコンがない（Images が nil、ImageIndex が -1）ときは枠の中に何も描かない }
procedure TCSideBar.PaintIcons;
var
  I, Inset, Radius, IX, IY: Integer;
  P: TCSideBarPage;
  R, HR: TRect;
  Res: TScaledImageListResolution;
  HasImages: Boolean;
  DisabledBmp: TBitmap;
begin
  if FIconBarWidth <= 0 then Exit;
  Inset := Scale96ToFont(cIconInset96);
  Radius := Scale96ToFont(cIconRadius96);
  HasImages := Assigned(FImages);
  if HasImages then
    // ImagesWidth は 100% の値。Font.PixelsPerInch に合う画像を ImageList が選ぶ
    Res := FImages.ResolutionForPPI[FImagesWidth, Font.PixelsPerInch, 1];
  for I := 0 to FPages.Count - 1 do
  begin
    P := TCSideBarPage(FPages[I]);
    if not IconShown(P) then Continue;
    R := IconRect(P);
    HR := Rect(R.Left + Inset, R.Top + Inset, R.Right - Inset, R.Bottom - Inset);
    // ハイライト
    if (P = FHotPage) and Enabled and P.Enabled then
    begin
      Canvas.Pen.Style := psClear;
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := clBtnHighlight;
      Canvas.RoundRect(HR, Radius, Radius);
    end;
    if P = FActivePage then
    begin
      Canvas.Pen.Style := psSolid;
      Canvas.Pen.Color := clHighlight;
      Canvas.Pen.Width := 1;
      Canvas.Brush.Style := bsClear;
      Canvas.RoundRect(HR, Radius, Radius);
    end;
    // アイコン（枠の中央）。無効なページ・無効なサイドバーは灰色で描く
    if HasImages and (P.ImageIndex >= 0) and (P.ImageIndex < FImages.Count) then
    begin
      IX := R.Left + (R.Right - R.Left - Res.Width) div 2;
      IY := R.Top + (R.Bottom - R.Top - Res.Height) div 2;
      if Enabled and P.Enabled then
        Res.Draw(Canvas, IX, IY, P.ImageIndex, True)
      else
      begin
        // 無効なアイコンは、LCL 共通の灰色化（GetBitmap に gdeDisabled を渡す）で作った画像を描く。
        // Res.Draw(…, False) は Windows では画像リストの ILS_SATURATE に任せるため、
        // 画像の形式によっては色が変わらない。LCL 自身も拡大描画のときはこの方法を使っている
        DisabledBmp := TBitmap.Create;
        try
          Res.GetBitmap(P.ImageIndex, DisabledBmp, gdeDisabled);
          Canvas.Draw(IX, IY, DisabledBmp);
        finally
          DisabledBmp.Free;
        end;
      end;
    end;
  end;
  Canvas.Pen.Style := psSolid;
  Canvas.Brush.Style := bsSolid;
end;

{ ヘッダー：左に Caption、右に [×]（ShowCloseButton のとき）。
  Paint から ShowHeader=True のときだけ呼ばれる }
procedure TCSideBar.PaintHeader;
var
  H, C, TR: TRect;
  TS: TTextStyle;
  Pad, M: Integer;
begin
  H := HeaderRect;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clBtnFace;
  Canvas.FillRect(H);

  Pad := Scale96ToFont(cTextPadding96);
  TR := Rect(H.Left + Pad, H.Top, H.Right - Pad, H.Bottom);
  C := CloseButtonRect;
  if FShowCloseButton and (C.Right > C.Left) then
    TR.Right := C.Left - Pad div 2;
  if TR.Right > TR.Left then
  begin
    Canvas.Font := Font;
    Canvas.Font.Color := clBtnText;
    TS := Canvas.TextStyle;
    TS.Layout := tlCenter;
    TS.SingleLine := True;
    TS.EndEllipsis := True;
    TS.Clipping := True;
    TS.Opaque := False;
    Canvas.Brush.Style := bsClear;
    Canvas.TextRect(TR, TR.Left, TR.Top, FActivePage.Caption, TS);
    Canvas.Brush.Style := bsSolid;
  end;

  // [×]：マウスが乗っているときは背景を clBtnHighlight にし、× を 2 本の線で描く
  if FShowCloseButton and (C.Right > C.Left) then
  begin
    if FHotClose then
    begin
      Canvas.Brush.Color := clBtnHighlight;
      Canvas.FillRect(C);
    end;
    M := (C.Right - C.Left) div 4;
    Canvas.Pen.Style := psSolid;
    Canvas.Pen.Color := clBtnText;
    Canvas.Pen.Width := Scale96ToFont(1);
    if Canvas.Pen.Width < 1 then Canvas.Pen.Width := 1;
    Canvas.Line(C.Left + M, C.Top + M, C.Right - M, C.Bottom - M);
    Canvas.Line(C.Right - M - 1, C.Top + M, C.Left + M - 1, C.Bottom - M);
    Canvas.Pen.Width := 1;
  end;
end;

{ スプリッター：中央に clBtnShadow の縦線 }
procedure TCSideBar.PaintSplitter;
var
  S: TRect;
  X: Integer;
begin
  S := SplitterRect;
  if S.Right <= S.Left then Exit;
  X := (S.Left + S.Right) div 2;
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Color := clBtnShadow;
  Canvas.Pen.Width := 1;
  Canvas.Line(X, S.Top, X, S.Bottom);
end;

{ ---- マウス ---- }

procedure TCSideBar.SetHot(APage: TCSideBarPage; AClose: Boolean);
begin
  if (APage = FHotPage) and (AClose = FHotClose) then Exit;
  // 別のアイコンに移ったら、ヒントを出し直せるように一度消す
  if (APage <> FHotPage) and Assigned(Application) then
    Application.CancelHint;
  FHotPage := APage;
  FHotClose := AClose;
  Invalidate;
end;

{ 左ボタンを押した場所を覚える：スプリッターならドラッグ開始、[×] なら押下中、アイコンならそのページ。
  ShowHeader=False のときは CloseButtonRect が空なので、[×] の押下にはならない }
procedure TCSideBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  FDownPage := nil;
  FDownClose := False;
  if InSplitter(X, Y) then
    BeginSplitterDrag(X)
  else if InCloseButton(X, Y) then
    FDownClose := True
  else
    FDownPage := PageAtIcon(X, Y);
end;

procedure TCSideBar.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FDragging then
  begin
    MoveSplitterDrag(X);
    Exit;
  end;
  SetHot(PageAtIcon(X, Y), InCloseButton(X, Y));
  if InSplitter(X, Y) then
    Cursor := crHSplit
  else
    Cursor := crDefault;
end;

{ 左ボタンを離したとき、押したときと同じ場所なら動かす }
procedure TCSideBar.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  P: TCSideBarPage;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  if FDragging then
  begin
    EndSplitterDrag(X);
    // デザイナは、この MouseUp の後に押下中の状態を残す（CMDesignHitTest 参照）
    if csDesigning in ComponentState then
      FDesignerPressLeft := True;
    Exit;
  end;
  if FDownClose then
  begin
    FDownClose := False;
    // [×]：閉じる
    if InCloseButton(X, Y) and (FActivePage <> nil) then
      ChangeActivePage(nil);
    Exit;
  end;
  P := FDownPage;
  FDownPage := nil;
  // デザイナは、この MouseUp の後に押下中の状態を残す（CMDesignHitTest 参照）
  if csDesigning in ComponentState then
    FDesignerPressLeft := True;
  // アイコン：開閉のトグル。無効なページは何もしない（設計時は開閉できる）
  if (P <> nil) and (PageAtIcon(X, Y) = P) and Enabled
    and ((csDesigning in ComponentState) or P.Enabled) then
    UserTogglePage(P);
end;

procedure TCSideBar.MouseLeave;
begin
  inherited MouseLeave;
  if not FDragging then
  begin
    SetHot(nil, False);
    Cursor := crDefault;
  end;
end;

{ 右クリック：アイコン列の上なら IconPopupMenu を出す。それ以外の場所では何も出さない。
  キーボードのメニューキー（MousePos.X = -1）も、アイコン列ではないので何も出さない }
procedure TCSideBar.DoContextPopup(MousePos: TPoint; var Handled: Boolean);
var
  SP: TPoint;
begin
  inherited DoContextPopup(MousePos, Handled);
  if Handled then Exit;
  Handled := True;
  if (MousePos.X >= 0) and (MousePos.X < FIconBarWidth) and (MousePos.Y >= 0)
    and Assigned(FIconPopupMenu) then
  begin
    FIconPopupMenu.PopupComponent := Self;
    SP := ClientToScreen(MousePos);
    FIconPopupMenu.Popup(SP.X, SP.Y);
  end;
end;

{ ヒント：マウスの下のアイコンのページの Caption を出す。
  CursorRect をアイコンの枠にすると、枠の外へ出たときに LCL が出し直す }
procedure TCSideBar.CMHintShow(var Message: TLMessage);
var
  Info: PHintInfo;
  P: TCSideBarPage;
begin
  inherited CMHintShow(Message);
  Info := TCMHintShow(Message).HintInfo;
  if Info = nil then Exit;
  P := PageAtIcon(Info^.CursorPos.X, Info^.CursorPos.Y);
  if (P <> nil) and (P.Caption <> '') then
  begin
    Info^.HintStr := P.Caption;
    Info^.CursorRect := IconRect(P);
  end
  else
    Info^.HintStr := '';
end;

{ 設計時に、マウス操作をサイドバーに渡す場所。
  デザイナは、マウスが押された・動いた・離されたたびにこのメッセージを送り、
  1 ならサイドバーの MouseDown・MouseMove・MouseUp を呼び、0 ならデザイナ自身が処理する。
  Lazarus のデザイナ（designer.pp）には次の動きがあるため、それに合わせて返す値を決める。
  ・サイドバーが MouseUp を処理すると、デザイナは自分の後片付け（押下中の部品を忘れる）をせずに終わる
  ・マウスが動いたとき、デザイナはボタンを押していなくても「左ボタンが押されている」として扱う
  この 2 つが重なると、アイコンをクリックした後、ボタンを押さずにマウスを動かしただけで、
  デザイナが「アイコンから引きずっている」と判断し、範囲選択の枠（青い枠）を出してしまう。
  返す値：
  ・アイコンを押してから離すまで、スプリッターのドラッグ中：どこでも 1（最後までサイドバーが受け取る）
  ・サイドバーが MouseUp を処理した後、次にボタンが押されるまでの、ボタンを押していない移動：1
    （デザイナに渡さないことで、残っている押下中の状態から枠を出させない）
  ・それ以外：アイコンとスプリッターの上なら 1、それ以外は 0（デザイナが部品を選ぶ） }
procedure TCSideBar.CMDesignHitTest(var Message: TCMDesignHitTest);
const
  cMouseButtons = MK_LBUTTON or MK_RBUTTON or MK_MBUTTON;
var
  X, Y: Integer;
  ButtonsDown: Boolean;
begin
  X := Message.XPos;
  Y := Message.YPos;
  ButtonsDown := (Message.Keys and cMouseButtons) <> 0;
  // 新しくボタンが押された：デザイナは押下中の状態を作り直すので、残りの状態はもうない
  if ButtonsDown then
    FDesignerPressLeft := False;
  if FDragging or (FDownPage <> nil) then
    Message.Result := 1
  else if FDesignerPressLeft and not ButtonsDown then
    Message.Result := 1
  else if (PageAtIcon(X, Y) <> nil) or InSplitter(X, Y) then
    Message.Result := 1
  else
    Message.Result := 0;
end;

procedure TCSideBar.CMEnabledChanged(var Message: TLMessage);
begin
  inherited CMEnabledChanged(Message);
  Invalidate;
end;

{ ---- スプリッターのドラッグ ---- }

procedure TCSideBar.BeginSplitterDrag(X: Integer);
var
  BandBrush: HBRUSH;
  R: TRect;
begin
  if FActivePage = nil then Exit;
  // 前のドラッグの線が何かの理由で残っていたら、先に消す（線のウィンドウが残り続けないように）
  if FRubberBand <> 0 then
  begin
    DestroyRubberBand(FRubberBand);
    FRubberBand := 0;
  end;
  FDragging := True;
  // マウスをキャプチャする。実行時はボタンを押したとき LCL がキャプチャ済みだが、
  // 設計時はデザイナが MouseDown を直接呼ぶためキャプチャされない。
  // キャプチャしないと、ボタンを離したときにマウスの下にあるドラッグ中の線（別ウィンドウ）が
  // MouseUp を受け取ってしまい、サイドバーに届かず線が残る
  MouseCapture := True;
  FDragStartX := X;
  FDragStartWidth := FActivePage.PanelWidth;
  FDragWidth := FDragStartWidth;
  // rsLine・rsPattern：TSplitter と同じく、別ウィンドウの線を出す（WebView2 の上にも出る）
  if FResizeStyle in [rsLine, rsPattern] then
  begin
    if FResizeStyle = rsLine then
      BandBrush := HBRUSH(GetStockObject(BLACK_BRUSH))
    else
      BandBrush := ThemeServices.DottedBrush;
    R := SplitterRect;
    R.TopLeft := ClientToScreen(R.TopLeft);
    R.BottomRight := ClientToScreen(R.BottomRight);
    FRubberBand := CreateRubberband(R, BandBrush);
  end;
end;

procedure TCSideBar.MoveSplitterDrag(X: Integer);
begin
  if FActivePage = nil then Exit;
  FDragWidth := ClampPanelWidth(FDragStartWidth + (X - FDragStartX));
  case FResizeStyle of
    rsUpdate:
      FActivePage.PanelWidth := FDragWidth;   // ドラッグ中も幅を変える
    rsLine, rsPattern:
      UpdateRubberBand;                       // 線だけ動かす
  else
    ;                                         // rsNone：何も描かない
  end;
end;

{ ドラッグ中の線を、今の幅の位置に動かす }
procedure TCSideBar.UpdateRubberBand;
var
  R: TRect;
begin
  if FRubberBand = 0 then Exit;
  R := SplitterRect;
  Types.OffsetRect(R, FDragWidth - FDragStartWidth, 0);
  R.TopLeft := ClientToScreen(R.TopLeft);
  R.BottomRight := ClientToScreen(R.BottomRight);
  SetRubberBandRect(FRubberBand, R);
end;

{ ドラッグの取りやめ：線を消し、幅をドラッグ前に戻す。OnPanelResize は呼ばない }
procedure TCSideBar.CancelSplitterDrag;
begin
  if not FDragging then Exit;
  FDragging := False;
  if FRubberBand <> 0 then
  begin
    DestroyRubberBand(FRubberBand);
    FRubberBand := 0;
  end;
  if (FActivePage <> nil) and (FActivePage.PanelWidth <> FDragStartWidth) then
    FActivePage.PanelWidth := FDragStartWidth;   // rsUpdate でドラッグ中に変えた幅を戻す
end;

{ マウスのキャプチャが外れた。
  ・ボタンを離したとき：LCL は MouseUp を呼ぶ前にキャプチャを外す。このときボタンはもう離されているので、
    何もしない（この後の MouseUp でドラッグを終える）
  ・ボタンを押したまま外れたとき（ドラッグ中に Alt+Tab で別のウィンドウへ切り替えた など）：
    MouseUp が届かず線が残るので、ドラッグを取りやめる }
procedure TCSideBar.CaptureChanged;
begin
  inherited CaptureChanged;
  if FDragging and not MouseCapture and (GetKeyState(VK_LBUTTON) < 0) then
    CancelSplitterDrag;
end;

{ ドラッグ終了：幅を決め、変わっていたら OnPanelResize を呼ぶ。
  設計時はイベントの代わりに、デザイナに変更を知らせる（.lfm に PanelWidth を保存するため） }
procedure TCSideBar.EndSplitterDrag(X: Integer);
var
  WidthChanged: Boolean;
begin
  FDragging := False;
  MouseCapture := False;   // FDragging を先に False にするので、CaptureChanged では何もしない
  if FRubberBand <> 0 then
  begin
    DestroyRubberBand(FRubberBand);
    FRubberBand := 0;
  end;
  if FActivePage = nil then Exit;
  FDragWidth := ClampPanelWidth(FDragStartWidth + (X - FDragStartX));
  FActivePage.PanelWidth := FDragWidth;
  WidthChanged := FActivePage.PanelWidth <> FDragStartWidth;
  if not WidthChanged then Exit;
  if csDesigning in ComponentState then
    OwnerFormDesignerModified(Self)
  else if EventsEnabled and Assigned(FOnPanelResize) then
    FOnPanelResize(Self);
end;

{ ---- ショートカットキー ----
  Application.AddOnKeyDownHandler で受け取る。届くのは、フォームの OnKeyDown（KeyPreview）、
  フォーカスのある部品、メニュー・ActionList のショートカットで使われなかったキーだけ。 }
procedure TCSideBar.AppKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  SC: TShortCut;
  I: Integer;
  P: TCSideBarPage;
  F: TCustomForm;
begin
  if Key = 0 then Exit;
  if not EventsEnabled then Exit;
  // サイドバーが置かれたフォームのキーだけ扱う（Sender はフォーカスのある部品）
  if not (Sender is TControl) then Exit;
  F := GetParentForm(Self);
  if (F = nil) or (GetParentForm(TControl(Sender)) <> F) then Exit;
  if not (Enabled and IsVisible) then Exit;
  SC := Menus.ShortCut(Key, Shift * [ssShift, ssAlt, ssCtrl]);
  if SC = 0 then Exit;
  for I := 0 to FPages.Count - 1 do
  begin
    P := TCSideBarPage(FPages[I]);
    if (P.ShortCut <> 0) and (P.ShortCut = SC) then
    begin
      // 隠れているページ・無効なページのキーは無視する（Key はそのまま）
      if P.PageVisible and P.Enabled then
      begin
        UserTogglePage(P);
        Key := 0;
      end;
      Exit;
    end;
  end;
end;

initialization
  // .lfm から TCSideBarPage を読み込めるようにする
  RegisterClass(TCSideBarPage);

end.
