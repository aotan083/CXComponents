{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ ============================================================================
  uCPageControl  -  TCPageControl（ブラウザ風のタブコントロール）

  設計書: docs\TCPageControl_Design.md
  パッケージ: cx（実行時）

  ・TCPageControl  … タブコントロール本体（ページの集まり）。名前は TPageControl に合わせる。
  ・TCTabSheet     … タブ 1 枚分のページ。名前は TTabSheet に合わせる。
  ・TCTabStrip     … タブ列の描画と操作（内部用）。TCTitleBar に載せ替えられる。
  ・TCTabListPopup … ［∨］で開くタブ一覧（内部用）。

  マウス・キーで操作されたときの処理は、TCPageControl の protected メソッド
  （DoTabClick など）にまとめ、タブ列はそれを呼ぶだけにする。
  ============================================================================ }
unit uCPageControl;

{$mode objfpc}{$H+}

interface

uses
  {$IFDEF WINDOWS}Windows,{$ENDIF} // Windows は先に書く（RECT・POINT が Types の Rect・Point を隠さないように）
  Classes, SysUtils, Types, Math, Controls, Graphics, Forms, StdCtrls, ExtCtrls,
  Menus, ComCtrls, ImgList, LCLType, LCLIntf, LMessages, LCLProc,
  uCTitleBar;

type
  TCPageControl = class;
  TCTabStrip = class;

  { タブの形 }
  TCTabShape = (tsRectangle, tsRounded);

  { 右クリックメニューの標準項目 }
  TCTabMenuItem  = (tmiNew, tmiClose, tmiRename);
  TCTabMenuItems = set of TCTabMenuItem;

  { TCTabSheet }

  TCTabSheet = class(TCustomControl)
  private
    FImageIndex: TImageIndex;
    FTabVisible: Boolean;
    FOnShow: TNotifyEvent;
    FOnHide: TNotifyEvent;
    function GetPageControl: TCPageControl;
    function GetPageIndex: Integer;
    function GetTabIndex: Integer;
    procedure SetImageIndex(AValue: TImageIndex);
    procedure SetPageControl(AValue: TCPageControl);
    procedure SetPageIndex(AValue: Integer);
    procedure SetTabVisible(AValue: Boolean);
    procedure CMTextChanged(var Message: TLMessage); message CM_TEXTCHANGED;
    procedure CMVisibleChanged(var Message: TLMessage); message CM_VISIBLECHANGED;
  protected
    procedure SetParent(NewParent: TWinControl); override;
    procedure Paint; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    function IsControlVisible: Boolean; override;
    function HandleObjectShouldBeVisible: Boolean; override;
    procedure RefreshShowing;
    property PageControl: TCPageControl read GetPageControl write SetPageControl;
    property TabIndex: Integer read GetTabIndex;
  published
    property Caption;
    property Color default clWindow;
    property ImageIndex: TImageIndex read FImageIndex write SetImageIndex default -1;
    property PageIndex: Integer read GetPageIndex write SetPageIndex stored False;
    property TabVisible: Boolean read FTabVisible write SetTabVisible default True;
    property Left stored False;
    property Top stored False;
    property Width stored False;
    property Height stored False;
    property BorderWidth;
    property ChildSizing;
    property ClientHeight;
    property ClientWidth;
    property Enabled;
    property Font;
    property ParentColor default False;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property OnContextPopup;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnHide: TNotifyEvent read FOnHide write FOnHide;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnResize;
    property OnShow: TNotifyEvent read FOnShow write FOnShow;
    property OnStartDrag;
  end;

  { イベントの型 }
  TCNewPageEvent    = procedure(Sender: TObject; APage: TCTabSheet) of object;
  TCPageCloseEvent  = procedure(Sender: TObject; APage: TCTabSheet; var CanClose: Boolean) of object;
  TCPageRenameEvent = procedure(Sender: TObject; APage: TCTabSheet; var ACaption: string;
    var CanRename: Boolean) of object;
  TCPageMovedEvent  = procedure(Sender: TObject; APage: TCTabSheet; AOldIndex, ANewIndex: Integer) of object;

  { タブ列の上の場所の種類 }
  TCStripHitKind = (shNone, shTab, shTabClose, shPrev, shNext, shAdd, shList);

  TCStripHit = record
    Kind: TCStripHitKind;
    Page: TCTabSheet;
  end;

  { タブ 1 つの配置 }
  TCStripTab = record
    Page: TCTabSheet;
    Left, Width: Integer;   // スクロール前の、タブ列の中での位置
  end;

  { TCTabStrip（タブ列。内部用） }

  TCTabStrip = class(TCustomControl, ICTitleBarDragArea, ICTitleBarDesignHit)
  private
    FPageControl: TCPageControl;
    FTabs: array of TCStripTab;
    FTotalWidth: Integer;
    FScrollPos: Integer;
    FOverflow: Boolean;
    FViewRect, FPrevRect, FNextRect, FAddRect, FListRect: TRect;
    FTabTop, FTabBottom: Integer;
    FHot: TCStripHit;
    FDown: TCStripHit;
    FRepeatTimer: TTimer;
    FRepeatDir: Integer;
    // ドラッグ
    FDragPage: TCTabSheet;
    FDragStartX: Integer;
    FDragging: Boolean;
    FDropIndex: Integer;     // 落とす位置（表示しているタブの並びでの番号）
    FDragMouseX: Integer;
    FDragTimer: TTimer;
    // その場編集
    FEdit: TEdit;
    FEditPage: TCTabSheet;
    FEditEnding: Boolean;
    // タブ一覧
    FListClosedTick: QWord;
    function S96(AValue: Integer): Integer;
    function TabHeightPx: Integer;
    function TextWidthPx(const AText: string): Integer;
    function IconWidthPx: Integer;
    function TabWidthFor(APage: TCTabSheet): Integer;
    function TabScreenRect(AIndex: Integer): TRect;
    function TabCloseRect(const ATabRect: TRect): TRect;
    function IndexOfStripTab(APage: TCTabSheet): Integer;
    function HitTest(const P: TPoint): TCStripHit;
    function SameHit(const A, B: TCStripHit): Boolean;
    function MaxScroll: Integer;
    function BackColor: TColor;
    procedure SetScrollPos(AValue: Integer);
    procedure ScrollStep(ADir: Integer);
    procedure RepeatTimerTick(Sender: TObject);
    procedure DragTimerTick(Sender: TObject);
    procedure DragKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure CancelDrag;
    procedure FinishDrag(const P: TPoint);
    function DropIndexAt(X: Integer): Integer;
    procedure DrawSymbol(const R: TRect; ACode: Cardinal; AColor: TColor; ASizePx: Integer);
    procedure DrawShape(const R: TRect; AColor: TColor);
    procedure PaintTab(AIndex: Integer);
    procedure PaintButton(const R: TRect; AKind: TCStripHitKind; ACode: Cardinal; AEnabled: Boolean);
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditExit(Sender: TObject);
    procedure FreeEditAsync(Data: PtrInt);
  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure DoContextPopup(MousePos: TPoint; var Handled: Boolean); override;
  public
    constructor Create(AOwner: TCPageControl); reintroduce;
    destructor Destroy; override;
    procedure LayoutTabs;
    procedure EnsureVisible(APage: TCTabSheet);
    procedure PageRemoved(APage: TCTabSheet);
    procedure BeginEdit(APage: TCTabSheet);
    procedure EndEdit;
    function EditText: string;
    function IsEditing: Boolean;
    function TabRectOf(APage: TCTabSheet): TRect;
    function VisibleTabAt(const P: TPoint): Integer;
    function ListButtonScreenRect: TRect;
    procedure ListClosed;
    { ICTitleBarDragArea }
    function IsDragArea(const P: TPoint): Boolean;
    { ICTitleBarDesignHit }
    function DesignHitTest(const P: TPoint): Boolean;
    procedure DesignMouseDown(Button: TMouseButton; Shift: TShiftState; const P: TPoint);
    property PageControl: TCPageControl read FPageControl;
  end;

  { TCPageControl }

  TCPageControl = class(TCustomControl)
  private
    FPages: TFPList;
    FPageIndex: Integer;
    FStrip: TCTabStrip;
    FTitleBar: TCTitleBar;
    FImages: TCustomImageList;
    FImagesWidth: Integer;
    FImageChangeLink: TChangeLink;
    FTabPosition: TTabPosition;
    FTabHeight: Smallint;
    FTabWidth: Smallint;
    FTabMaxWidth: Integer;
    FTabShape: TCTabShape;
    FOptions: TCTabControlOptions;
    FShowTabListButton: Boolean;
    FNewPageCaption: string;
    FTabMenuItems: TCTabMenuItems;
    FTabPopupMenu: TPopupMenu;
    FTabListPopupMenu: TPopupMenu;
    FPopupPage: TCTabSheet;
    FMenu: TPopupMenu;            // 右クリックで出すメニュー（毎回作り直す）
    FListPopup: TCustomForm;      // タブ一覧
    FClearing: Boolean;
    FKeyHandlerAdded: Boolean;
    FOnChange: TNotifyEvent;
    FOnChanging: TTabChangingEvent;
    FOnGetImageIndex: TTabGetImageEvent;
    FOnNewPage: TCNewPageEvent;
    FOnPageClose: TCPageCloseEvent;
    FOnPageRename: TCPageRenameEvent;
    FOnPageMoved: TCPageMovedEvent;
    function GetActivePage: TCTabSheet;
    function GetPage(Index: Integer): TCTabSheet;
    function GetPageCount: Integer;
    function IsNewPageCaptionStored: Boolean;
    function TabHeightIsStored: Boolean;
    function TabWidthIsStored: Boolean;
    procedure SetActivePage(AValue: TCTabSheet);
    procedure SetActivePageIndex(AValue: Integer);
    procedure SetImages(AValue: TCustomImageList);
    procedure SetImagesWidth(AValue: Integer);
    procedure SetNewPageCaption(const AValue: string);
    procedure SetOptions(AValue: TCTabControlOptions);
    procedure SetShowTabListButton(AValue: Boolean);
    procedure SetTabHeight(AValue: Smallint);
    procedure SetTabMaxWidth(AValue: Integer);
    procedure SetTabPopupMenu(AValue: TPopupMenu);
    procedure SetTabListPopupMenu(AValue: TPopupMenu);
    procedure SetTabPosition(AValue: TTabPosition);
    procedure SetTabShape(AValue: TCTabShape);
    procedure SetTabWidth(AValue: Smallint);
    procedure SetTitleBar(AValue: TCTitleBar);
    procedure ImageListChange(Sender: TObject);
    procedure UpdateStripPlace;
    procedure UpdateDesignerFlags;
    procedure ShowCurrentPage(AOldIndex: Integer);
    procedure InternalSetPageIndex(AValue: Integer);
    procedure UserSelectPage(APage: TCTabSheet);
    procedure ClosePageByUser(APage: TCTabSheet);
    function FindVisibleNear(AIndex: Integer): Integer;
    procedure KeyDownBefore(Sender: TObject; var Key: Word; Shift: TShiftState);
    function IsKeyTarget(AFocused: TObject): Boolean;
    procedure MenuNewClick(Sender: TObject);
    procedure MenuCloseClick(Sender: TObject);
    procedure MenuRenameClick(Sender: TObject);
    procedure MenuAppItemClick(Sender: TObject);
    procedure CopyMenuItems(ASource, ADest: TMenuItem);
    procedure CMDesignHitTest(var Message: TCMDesignHitTest); message CM_DESIGNHITTEST;
    procedure CMFontChanged(var Message: TLMessage); message CM_FONTCHANGED;
    procedure CMColorChanged(var Message: TLMessage); message CM_COLORCHANGED;
  protected
    { 操作を受けたときの処理（自動テストから直接呼ぶ） }
    procedure DoTabClick(APage: TCTabSheet); virtual;
    procedure DoAddButtonClick; virtual;
    procedure DoCloseButtonClick(APage: TCTabSheet); virtual;
    procedure DoMenuNewClick; virtual;
    procedure DoMenuCloseClick(APage: TCTabSheet); virtual;
    procedure DoMenuRenameClick(APage: TCTabSheet); virtual;
    procedure DoAppMenuItemClick(AItem: TMenuItem; APage: TCTabSheet); virtual;
    procedure DoTabListItemClick(APage: TCTabSheet); virtual;
    procedure DoTabListCloseClick(APage: TCTabSheet); virtual;
    procedure DoEditCaptionConfirm(const AText: string); virtual;
    procedure DoEditCaptionCancel; virtual;
    { 内部 }
    function CanChange: Boolean; virtual;
    procedure Change; virtual;
    procedure InsertPage(APage: TCTabSheet);
    procedure RemovePage(APage: TCTabSheet);
    procedure MovePage(APage: TCTabSheet; ANewIndex: Integer);
    procedure PageChanged;
    function GetImageIndex(APageIndex: Integer): Integer;
    procedure ShowTabList;
    procedure ShowTabMenu(APage: TCTabSheet; const AScreenPos: TPoint);
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
      const AXProportion, AYProportion: Double); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    function AddTabSheet: TCTabSheet;
    procedure Clear;
    function IndexOf(APage: TPersistent): Integer;
    function FindNextPage(CurPage: TCTabSheet; GoForward, CheckTabVisible: Boolean): TCTabSheet;
    procedure SelectNextPage(GoForward: Boolean);
    procedure SelectNextPage(GoForward: Boolean; CheckTabVisible: Boolean);
    function IndexOfTabAt(X, Y: Integer): Integer;
    function IndexOfTabAt(P: TPoint): Integer;
    function IndexOfPageAt(X, Y: Integer): Integer;
    function IndexOfPageAt(P: TPoint): Integer;
    function TabRect(AIndex: Integer): TRect;
    procedure EditPageCaption(APage: TCTabSheet);
    property ActivePageIndex: Integer read FPageIndex write SetActivePageIndex;
    property PageCount: Integer read GetPageCount;
    property Pages[Index: Integer]: TCTabSheet read GetPage;
    property PopupPage: TCTabSheet read FPopupPage;
    property TabStrip: TCTabStrip read FStrip;
  published
    property ActivePage: TCTabSheet read GetActivePage write SetActivePage;
    property TabIndex: Integer read FPageIndex write SetActivePageIndex default -1;
    property Images: TCustomImageList read FImages write SetImages;
    property ImagesWidth: Integer read FImagesWidth write SetImagesWidth default 0;
    property TabPosition: TTabPosition read FTabPosition write SetTabPosition default tpTop;
    property TabHeight: Smallint read FTabHeight write SetTabHeight stored TabHeightIsStored;
    property TabWidth: Smallint read FTabWidth write SetTabWidth stored TabWidthIsStored;
    property TabMaxWidth: Integer read FTabMaxWidth write SetTabMaxWidth default 240;
    property TabShape: TCTabShape read FTabShape write SetTabShape default tsRectangle;
    property Options: TCTabControlOptions read FOptions write SetOptions
      default [nboShowCloseButtons, nboShowAddTabButton, nboKeyboardTabSwitch];
    property ShowTabListButton: Boolean read FShowTabListButton write SetShowTabListButton default True;
    property NewPageCaption: string read FNewPageCaption write SetNewPageCaption stored IsNewPageCaptionStored;
    property TabMenuItems: TCTabMenuItems read FTabMenuItems write FTabMenuItems
      default [tmiNew, tmiClose, tmiRename];
    property TabPopupMenu: TPopupMenu read FTabPopupMenu write SetTabPopupMenu;
    property TabListPopupMenu: TPopupMenu read FTabListPopupMenu write SetTabListPopupMenu;
    property TitleBar: TCTitleBar read FTitleBar write SetTitleBar;
    property Color default clBtnFace;
    property Align;
    property Anchors;
    property BorderSpacing;
    property BiDiMode;
    property Constraints;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property ParentBiDiMode;
    property ParentColor default False;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnChanging: TTabChangingEvent read FOnChanging write FOnChanging;
    property OnGetImageIndex: TTabGetImageEvent read FOnGetImageIndex write FOnGetImageIndex;
    property OnNewPage: TCNewPageEvent read FOnNewPage write FOnNewPage;
    property OnPageClose: TCPageCloseEvent read FOnPageClose write FOnPageClose;
    property OnPageRename: TCPageRenameEvent read FOnPageRename write FOnPageRename;
    property OnPageMoved: TCPageMovedEvent read FOnPageMoved write FOnPageMoved;
    property OnContextPopup;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnResize;
    property OnStartDrag;
  end;

resourcestring
  rsCTabNew = '新しいタブ';
  rsCTabClose = 'タブを閉じる';
  rsCTabRename = 'タブ名の変更';
  rsCTabNewPageCaption = '新しいタブ';
  rsCTabCannotHaveParent = '%s の親にできるのは TCPageControl だけです（%s は指定できません）';

implementation

const
  // 96dpi 時の大きさ
  CPC_PAD        = 8;    // タブの左右の余白
  CPC_ICON_GAP   = 4;    // アイコンと文字の間
  CPC_CLOSE_SIZE = 16;   // ［×］の領域
  CPC_CLOSE_HIT  = 20;   // ［×］の押せる範囲
  CPC_CLOSE_GAP  = 4;    // 文字と［×］の間
  CPC_TAB_MIN    = 60;   // タブの最小幅
  CPC_ARROW_W    = 24;   // ［◀］［▶］の幅
  CPC_BUTTON_W   = 28;   // ［＋］［∨］の幅
  CPC_TAB_GAP    = 2;    // タブ同士の間隔
  CPC_RADIUS     = 6;    // 角丸の半径
  CPC_TAB_H      = 28;   // 単体時の既定のタブの高さ
  CPC_TITLE_GAP  = 6;    // タイトルバー内でのタブの高さ＝タイトルバーの高さ−6
  CPC_SYMBOL     = 10;   // 記号の字の高さ
  CPC_SYMBOL_S   = 8;    // ［×］の記号の字の高さ
  CPC_LIST_W     = 300;  // タブ一覧の幅
  CPC_LIST_ROW   = 28;   // タブ一覧の 1 行の高さ
  CPC_AUTOSCROLL = 20;   // ドラッグ中の自動スクロールが始まる端からの距離

  SYM_LEFT  = $E76B;
  SYM_RIGHT = $E76C;
  SYM_ADD   = $E710;
  SYM_DOWN  = $E70D;
  SYM_CLOSE = $E8BB;

type
  { タブ一覧の 1 行 }
  TCListRowKind = (lrMenu, lrSeparator, lrTab);
  TCListRow = record
    Kind: TCListRowKind;
    Item: TMenuItem;
    Page: TCTabSheet;
  end;

  TCTabListPopup = class;

  { タブ一覧の中身（行を描く） }
  TCTabListView = class(TCustomControl)
  private
    FPopup: TCTabListPopup;
    FHotRow: Integer;
    FHotClose: Boolean;
    function RowHeight: Integer;
    function RowAt(Y: Integer): Integer;
    function CloseRect(ARow: Integer): TRect;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
  end;

  { TCTabListPopup }
  TCTabListPopup = class(TCustomForm)
  private
    FPageControl: TCPageControl;
    FScroll: TScrollBox;
    FView: TCTabListView;
    FRows: array of TCListRow;
    procedure BuildRows;
    procedure UpdateSize;
    procedure PopupDeactivate(Sender: TObject);
    procedure PopupKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ScrollResize(Sender: TObject);
    procedure FitViewWidth;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure DoShow; override;
  public
    constructor CreatePopup(APageControl: TCPageControl);
    procedure ShowAt(const AScreenRight, AScreenTop: Integer);
    procedure RowClicked(ARow: Integer; AClose: Boolean);
    procedure ClosePopup;
  end;

{ ===========================================================================
  TCTabSheet
  =========================================================================== }

constructor TCTabSheet.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  // 部品を置けるのはページだけ。設計時にページを動かしたり大きさを変えたりできない
  ControlStyle := ControlStyle + [csAcceptsControls, csDesignFixedBounds, csNoDesignVisible, csNoFocus];
  FImageIndex := -1;
  FTabVisible := True;
  Color := clWindow;
  ParentColor := False;
  Align := alClient;
  Caption := '';
  Visible := False;
end;

destructor TCTabSheet.Destroy;
begin
  // 所属している TCPageControl から外す
  if Parent is TCPageControl then
    Parent := nil;
  inherited Destroy;
end;

function TCTabSheet.GetPageControl: TCPageControl;
begin
  if Parent is TCPageControl then
    Result := TCPageControl(Parent)
  else
    Result := nil;
end;

procedure TCTabSheet.SetPageControl(AValue: TCPageControl);
begin
  Parent := AValue;
end;

function TCTabSheet.GetPageIndex: Integer;
begin
  if Parent is TCPageControl then
    Result := TCPageControl(Parent).IndexOf(Self)
  else
    Result := -1;
end;

procedure TCTabSheet.SetPageIndex(AValue: Integer);
begin
  // 並べ替え（OnPageMoved は出さない）
  if Parent is TCPageControl then
    TCPageControl(Parent).MovePage(Self, AValue);
end;

{ 表示しているタブだけで数えた番号 }
function TCTabSheet.GetTabIndex: Integer;
var
  PC: TCPageControl;
  I: Integer;
begin
  Result := -1;
  PC := PageControl;
  if (PC = nil) or not FTabVisible then
    Exit;
  Result := 0;
  for I := 0 to PC.PageCount - 1 do
  begin
    if PC.Pages[I] = Self then
      Exit;
    if PC.Pages[I].TabVisible then
      Inc(Result);
  end;
  Result := -1;
end;

procedure TCTabSheet.SetImageIndex(AValue: TImageIndex);
begin
  if FImageIndex = AValue then
    Exit;
  FImageIndex := AValue;
  if PageControl <> nil then
    PageControl.PageChanged;
end;

procedure TCTabSheet.SetTabVisible(AValue: Boolean);
var
  PC: TCPageControl;
  Idx, NewIdx: Integer;
begin
  if FTabVisible = AValue then
    Exit;
  FTabVisible := AValue;
  PC := PageControl;
  if PC = nil then
    Exit;
  if not (csDesigning in ComponentState) and not (csLoading in ComponentState) then
  begin
    Idx := PageIndex;
    if (not AValue) and (PC.ActivePageIndex = Idx) then
    begin
      // 表示中のタブを隠したら、近くの表示しているタブに切り替える（LCL と同じ）
      NewIdx := PC.FindVisibleNear(Idx);
      if NewIdx <> Idx then
      begin
        PC.InternalSetPageIndex(NewIdx);
        PC.Change;
      end;
    end
    else if AValue and (PC.ActivePageIndex < 0) then
    begin
      PC.InternalSetPageIndex(Idx);
      PC.Change;
    end;
  end;
  PC.PageChanged;
end;

procedure TCTabSheet.SetParent(NewParent: TWinControl);
var
  OldParent: TWinControl;
begin
  if NewParent = Parent then
    Exit;
  if (NewParent <> nil) and not (NewParent is TCPageControl) then
    raise EInvalidOperation.CreateFmt(rsCTabCannotHaveParent, [ClassName, NewParent.ClassName]);
  OldParent := Parent;
  if OldParent is TCPageControl then
    TCPageControl(OldParent).RemovePage(Self);
  inherited SetParent(NewParent);
  if NewParent is TCPageControl then
    TCPageControl(NewParent).InsertPage(Self);
end;

{ 表示中のページのときだけ見える（LCL の TCustomPage と同じ。設計時の切り替えにも効く） }
function TCTabSheet.IsControlVisible: Boolean;
begin
  Result := inherited IsControlVisible;
  if Result and (Parent is TCPageControl) then
    Result := TCPageControl(Parent).ActivePage = Self;
end;

function TCTabSheet.HandleObjectShouldBeVisible: Boolean;
begin
  Result := inherited HandleObjectShouldBeVisible;
  if Result and (Parent is TCPageControl) then
    Result := TCPageControl(Parent).ActivePage = Self;
end;

{ 表示するかどうかを確かめ直させる（表示中のページが変わった後に呼ぶ） }
procedure TCTabSheet.RefreshShowing;
begin
  if csDestroying in ComponentState then
    Exit;
  UpdateControlState;
  Invalidate;
end;

procedure TCTabSheet.Paint;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
end;

{ 表示したページで OnShow、隠れたページで OnHide（LCL の TCustomPage と同じ） }
procedure TCTabSheet.CMVisibleChanged(var Message: TLMessage);
begin
  inherited;
  if Visible then
  begin
    if Assigned(FOnShow) then
      FOnShow(Self);
  end
  else if Assigned(FOnHide) then
    FOnHide(Self);
end;

procedure TCTabSheet.CMTextChanged(var Message: TLMessage);
begin
  inherited;
  if PageControl <> nil then
    PageControl.PageChanged;
end;

{ ===========================================================================
  TCTabStrip
  =========================================================================== }

constructor TCTabStrip.Create(AOwner: TCPageControl);
begin
  inherited Create(AOwner);
  FPageControl := AOwner;
  ControlStyle := ControlStyle - [csAcceptsControls, csSetCaption] + [csNoDesignSelectable];
  DoubleBuffered := True;
  FScrollPos := 0;
  FDropIndex := -1;
  FRepeatTimer := TTimer.Create(Self);
  FRepeatTimer.Enabled := False;
  FRepeatTimer.OnTimer := @RepeatTimerTick;
  FDragTimer := TTimer.Create(Self);
  FDragTimer.Enabled := False;
  FDragTimer.Interval := 50;
  FDragTimer.OnTimer := @DragTimerTick;
  SetSubComponent(True);
end;

destructor TCTabStrip.Destroy;
begin
  if FDragging then
    Application.RemoveOnKeyDownBeforeHandler(@DragKeyDown);
  Application.RemoveAsyncCalls(Self);
  inherited Destroy;
end;

procedure TCTabStrip.CreateWnd;
begin
  inherited CreateWnd;
  // タイトルバーに載せたとき、空き部分で HTTRANSPARENT を返すようにする
  CTitleBarHookChild(Self, True);
  LayoutTabs;
end;

procedure TCTabStrip.DestroyWnd;
begin
  CTitleBarHookChild(Self, False);
  inherited DestroyWnd;
end;

function TCTabStrip.S96(AValue: Integer): Integer;
begin
  Result := CXScale96(FPageControl, AValue);
end;

{ タブの高さ }
function TCTabStrip.TabHeightPx: Integer;
begin
  if FPageControl.TabHeight > 0 then
    Result := FPageControl.TabHeight
  else if Parent is TCTitleBar then
    Result := Parent.ClientHeight - S96(CPC_TITLE_GAP)
  else
    Result := S96(CPC_TAB_H);
  if Result < 1 then
    Result := 1;
end;

function TCTabStrip.TextWidthPx(const AText: string): Integer;
var
  Bmp: TBitmap;
begin
  if AText = '' then
    Exit(0);
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(1, 1);
    Bmp.Canvas.Font.Assign(FPageControl.Font);
    Result := Bmp.Canvas.TextWidth(AText);
  finally
    Bmp.Free;
  end;
end;

function TCTabStrip.IconWidthPx: Integer;
var
  PC: TCPageControl;
begin
  PC := FPageControl;
  if PC.Images = nil then
    Exit(0);
  Result := PC.Images.ResolutionForPPI[PC.ImagesWidth, PC.Font.PixelsPerInch,
    PC.GetCanvasScaleFactor].Width;
end;

{ タブ 1 つの幅 }
function TCTabStrip.TabWidthFor(APage: TCTabSheet): Integer;
var
  PC: TCPageControl;
  MaxW, MinW: Integer;
begin
  PC := FPageControl;
  if PC.TabWidth > 0 then
    Exit(PC.TabWidth);
  Result := S96(CPC_PAD) * 2 + TextWidthPx(APage.Caption);
  if (PC.Images <> nil) and (PC.GetImageIndex(APage.PageIndex) >= 0) then
    Inc(Result, IconWidthPx + S96(CPC_ICON_GAP));
  if nboShowCloseButtons in PC.Options then
    Inc(Result, S96(CPC_CLOSE_GAP) + S96(CPC_CLOSE_SIZE));
  MinW := S96(CPC_TAB_MIN);
  MaxW := S96(PC.TabMaxWidth);
  if MaxW < MinW then
    MaxW := MinW;
  Result := EnsureRange(Result, MinW, MaxW);
end;

{ タブの配置を計算し直す }
procedure TCTabStrip.LayoutTabs;
var
  PC: TCPageControl;
  I, N, X, Avail, Right, ListW, AddW, ArrowW, H: Integer;
  Pg: TCTabSheet;
begin
  PC := FPageControl;
  if PC = nil then
    Exit;
  // 単体時のタブ列の高さ
  if not (Parent is TCTitleBar) then
  begin
    H := TabHeightPx;
    if Height <> H then
      Height := H;
  end;
  N := 0;
  SetLength(FTabs, PC.PageCount);
  X := 0;
  for I := 0 to PC.PageCount - 1 do
  begin
    Pg := PC.Pages[I];
    if not (Pg.TabVisible or (csDesigning in PC.ComponentState)) then
      Continue;
    FTabs[N].Page := Pg;
    FTabs[N].Left := X;
    FTabs[N].Width := TabWidthFor(Pg);
    Inc(X, FTabs[N].Width + S96(CPC_TAB_GAP));
    Inc(N);
  end;
  SetLength(FTabs, N);
  if N > 0 then
    FTotalWidth := X - S96(CPC_TAB_GAP)
  else
    FTotalWidth := 0;

  // タブの縦の位置：タイトルバー内は下端にそろえる
  if Parent is TCTitleBar then
  begin
    FTabBottom := ClientHeight;
    FTabTop := FTabBottom - TabHeightPx;
    if FTabTop < 0 then
      FTabTop := 0;
  end
  else
  begin
    FTabTop := 0;
    FTabBottom := ClientHeight;
  end;

  if PC.ShowTabListButton then ListW := S96(CPC_BUTTON_W) else ListW := 0;
  if nboShowAddTabButton in PC.Options then AddW := S96(CPC_BUTTON_W) else AddW := 0;
  ArrowW := S96(CPC_ARROW_W);
  Right := ClientWidth - ListW;
  Avail := Right - AddW;
  FOverflow := FTotalWidth > Avail;
  if FOverflow then
  begin
    // [◀][タブ][▶][＋] … [∨]
    FPrevRect := Rect(0, FTabTop, ArrowW, FTabBottom);
    FViewRect := Rect(ArrowW, FTabTop, Max(ArrowW, Avail - ArrowW), FTabBottom);
    FNextRect := Rect(FViewRect.Right, FTabTop, FViewRect.Right + ArrowW, FTabBottom);
    if AddW > 0 then
      FAddRect := Rect(FNextRect.Right, FTabTop, FNextRect.Right + AddW, FTabBottom)
    else
      FAddRect := Rect(0, 0, 0, 0);
  end
  else
  begin
    FPrevRect := Rect(0, 0, 0, 0);
    FNextRect := Rect(0, 0, 0, 0);
    FViewRect := Rect(0, FTabTop, FTotalWidth, FTabBottom);
    if AddW > 0 then
      FAddRect := Rect(FTotalWidth, FTabTop, FTotalWidth + AddW, FTabBottom)
    else
      FAddRect := Rect(0, 0, 0, 0);
  end;
  if ListW > 0 then
    FListRect := Rect(ClientWidth - ListW, FTabTop, ClientWidth, FTabBottom)
  else
    FListRect := Rect(0, 0, 0, 0);
  SetScrollPos(FScrollPos);
  if FEdit <> nil then
    BeginEdit(FEditPage);
  Invalidate;
end;

function TCTabStrip.MaxScroll: Integer;
begin
  Result := FTotalWidth - (FViewRect.Right - FViewRect.Left);
  if (Result < 0) or not FOverflow then
    Result := 0;
end;

procedure TCTabStrip.SetScrollPos(AValue: Integer);
begin
  AValue := EnsureRange(AValue, 0, MaxScroll);
  if FScrollPos = AValue then
    Exit;
  FScrollPos := AValue;
  Invalidate;
end;

{ ［◀］［▶］で 1 枚分ずつ }
procedure TCTabStrip.ScrollStep(ADir: Integer);
var
  I, ViewW: Integer;
begin
  ViewW := FViewRect.Right - FViewRect.Left;
  if ADir > 0 then
  begin
    for I := 0 to High(FTabs) do
      if FTabs[I].Left + FTabs[I].Width > FScrollPos + ViewW then
      begin
        SetScrollPos(FTabs[I].Left + FTabs[I].Width - ViewW);
        Exit;
      end;
  end
  else
  begin
    for I := High(FTabs) downto 0 do
      if FTabs[I].Left < FScrollPos then
      begin
        SetScrollPos(FTabs[I].Left);
        Exit;
      end;
  end;
end;

procedure TCTabStrip.EnsureVisible(APage: TCTabSheet);
var
  I, ViewW: Integer;
begin
  I := IndexOfStripTab(APage);
  if I < 0 then
    Exit;
  ViewW := FViewRect.Right - FViewRect.Left;
  if FTabs[I].Left < FScrollPos then
    SetScrollPos(FTabs[I].Left)
  else if FTabs[I].Left + FTabs[I].Width > FScrollPos + ViewW then
    SetScrollPos(FTabs[I].Left + FTabs[I].Width - ViewW);
end;

function TCTabStrip.IndexOfStripTab(APage: TCTabSheet): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FTabs) do
    if FTabs[I].Page = APage then
      Exit(I);
  Result := -1;
end;

{ 表示上のタブの位置（スクロール後、タブ列の座標）。見えていなければ空。 }
function TCTabStrip.TabScreenRect(AIndex: Integer): TRect;
begin
  Result := Rect(FViewRect.Left + FTabs[AIndex].Left - FScrollPos, FTabTop,
    FViewRect.Left + FTabs[AIndex].Left - FScrollPos + FTabs[AIndex].Width, FTabBottom);
end;

function TCTabStrip.TabRectOf(APage: TCTabSheet): TRect;
var
  I: Integer;
  R: TRect;
begin
  Result := Rect(0, 0, 0, 0);
  I := IndexOfStripTab(APage);
  if I < 0 then
    Exit;
  R := TabScreenRect(I);
  if (R.Right <= FViewRect.Left) or (R.Left >= FViewRect.Right) then
    Exit;
  Result := R;
end;

function TCTabStrip.TabCloseRect(const ATabRect: TRect): TRect;
var
  Hit, CY: Integer;
begin
  Hit := S96(CPC_CLOSE_HIT);
  CY := (ATabRect.Top + ATabRect.Bottom) div 2;
  Result.Right := ATabRect.Right - S96(CPC_PAD) + (Hit - S96(CPC_CLOSE_SIZE)) div 2;
  Result.Left := Result.Right - Hit;
  Result.Top := CY - Hit div 2;
  Result.Bottom := Result.Top + Hit;
end;

function TCTabStrip.VisibleTabAt(const P: TPoint): Integer;
var
  I: Integer;
  R: TRect;
begin
  Result := -1;
  if not PtInRect(FViewRect, P) then
    Exit;
  for I := 0 to High(FTabs) do
  begin
    R := TabScreenRect(I);
    if PtInRect(R, P) then
      Exit(I);
  end;
end;

function TCTabStrip.HitTest(const P: TPoint): TCStripHit;
var
  I: Integer;
  R: TRect;
begin
  Result.Kind := shNone;
  Result.Page := nil;
  if FOverflow and PtInRect(FPrevRect, P) then
    Result.Kind := shPrev
  else if FOverflow and PtInRect(FNextRect, P) then
    Result.Kind := shNext
  else if PtInRect(FAddRect, P) then
    Result.Kind := shAdd
  else if PtInRect(FListRect, P) then
    Result.Kind := shList
  else
  begin
    I := VisibleTabAt(P);
    if (I >= 0) and (FPageControl.IndexOf(FTabs[I].Page) >= 0) then
    begin
      Result.Page := FTabs[I].Page;
      R := TabScreenRect(I);
      if (nboShowCloseButtons in FPageControl.Options) and PtInRect(TabCloseRect(R), P) then
        Result.Kind := shTabClose
      else
        Result.Kind := shTab;
    end;
  end;
end;

function TCTabStrip.SameHit(const A, B: TCStripHit): Boolean;
begin
  Result := (A.Kind = B.Kind) and (A.Page = B.Page);
end;

{ 空き部分か（ICTitleBarDragArea） }
function TCTabStrip.IsDragArea(const P: TPoint): Boolean;
begin
  if FDragging or (FEdit <> nil) then
    Exit(False);
  Result := HitTest(P).Kind = shNone;
end;

{ 設計時にクリックを受ける場所：タブと［◀▶］ }
function TCTabStrip.DesignHitTest(const P: TPoint): Boolean;
begin
  Result := HitTest(P).Kind in [shTab, shTabClose, shPrev, shNext];
end;

procedure TCTabStrip.DesignMouseDown(Button: TMouseButton; Shift: TShiftState; const P: TPoint);
var
  H: TCStripHit;
begin
  if Button <> mbLeft then
    Exit;
  H := HitTest(P);
  case H.Kind of
    shTab, shTabClose:
      FPageControl.DoTabClick(H.Page);
    shPrev:
      ScrollStep(-1);
    shNext:
      ScrollStep(1);
  end;
end;

function TCTabStrip.BackColor: TColor;
begin
  if Parent is TCTitleBar then
    Result := TCTitleBar(Parent).Color
  else
    Result := FPageControl.Color;
end;

procedure TCTabStrip.DrawSymbol(const R: TRect; ACode: Cardinal; AColor: TColor; ASizePx: Integer);
var
  FontName: string;
  TS: TTextStyle;
  CX, CY, S: Integer;
begin
  FontName := CXSymbolFontName;
  if FontName <> '' then
  begin
    CXSetSymbolFont(Canvas, FontName, ASizePx, AColor);
    TS := Canvas.TextStyle;
    TS.Alignment := taCenter;
    TS.Layout := tlCenter;
    TS.SingleLine := True;
    TS.Opaque := False;
    TS.Clipping := True;
    Canvas.Brush.Style := bsClear;
    Canvas.TextRect(R, R.Left, R.Top, CXSymbol(ACode), TS);
    Exit;
  end;
  // 記号の字が無いときは線で描く
  S := ASizePx div 2;
  CX := (R.Left + R.Right) div 2;
  CY := (R.Top + R.Bottom) div 2;
  Canvas.Pen.Color := AColor;
  Canvas.Pen.Width := 1;
  case ACode of
    SYM_LEFT:
      begin
        Canvas.Line(CX + S div 2, CY - S, CX - S div 2, CY);
        Canvas.Line(CX - S div 2, CY, CX + S div 2, CY + S);
      end;
    SYM_RIGHT:
      begin
        Canvas.Line(CX - S div 2, CY - S, CX + S div 2, CY);
        Canvas.Line(CX + S div 2, CY, CX - S div 2, CY + S);
      end;
    SYM_ADD:
      begin
        Canvas.Line(CX - S, CY, CX + S + 1, CY);
        Canvas.Line(CX, CY - S, CX, CY + S + 1);
      end;
    SYM_DOWN:
      begin
        Canvas.Line(CX - S, CY - S div 2, CX, CY + S div 2);
        Canvas.Line(CX, CY + S div 2, CX + S + 1, CY - S div 2 - 1);
      end;
  else
    Canvas.Line(CX - S, CY - S, CX + S + 1, CY + S + 1);
    Canvas.Line(CX - S, CY + S, CX + S + 1, CY - S - 1);
  end;
end;

{ タブの形で塗る（TabShape） }
procedure TCTabStrip.DrawShape(const R: TRect; AColor: TColor);
var
  Rad: Integer;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := AColor;
  Canvas.Pen.Style := psClear;
  if FPageControl.TabShape = tsRounded then
  begin
    Rad := S96(CPC_RADIUS);
    Canvas.RoundRect(R.Left, R.Top, R.Right + 1, R.Bottom + 1, Rad * 2, Rad * 2);
    // タブの角は、ページの側だけ四角にする（上のタブなら下側）
    if (FPageControl.TabPosition = tpBottom) and not (Parent is TCTitleBar) then
      Canvas.FillRect(Rect(R.Left, R.Top, R.Right, Min(R.Bottom, R.Top + Rad)))
    else
      Canvas.FillRect(Rect(R.Left, Max(R.Top, R.Bottom - Rad), R.Right, R.Bottom));
  end
  else
    Canvas.FillRect(R);
  Canvas.Pen.Style := psSolid;
end;

procedure TCTabStrip.PaintTab(AIndex: Integer);
var
  PC: TCPageControl;
  Pg: TCTabSheet;
  R, TR, CR, CloseBg: TRect;
  Active, Hot, Down: Boolean;
  Bg, Fg: TColor;
  X, Img, IW, IH: Integer;
  TS: TTextStyle;
  Res: TScaledImageListResolution;
begin
  PC := FPageControl;
  Pg := FTabs[AIndex].Page;
  R := TabScreenRect(AIndex);
  Active := Pg = PC.ActivePage;
  Hot := (FHot.Kind = shTab) and (FHot.Page = Pg);
  Down := (FDown.Kind = shTab) and (FDown.Page = Pg);
  // 背景
  if Active then
    Bg := clWindow
  else if Down then
    Bg := CXBlendColor(BackColor, clBtnText, 20)
  else if Hot or ((FHot.Kind = shTabClose) and (FHot.Page = Pg)) then
    Bg := CXBlendColor(BackColor, clBtnText, 10)
  else
    Bg := clNone;
  if Bg <> clNone then
    DrawShape(R, Bg);
  if Active then
    Fg := clWindowText
  else
    Fg := clBtnText;
  if not Pg.TabVisible then
    Fg := clGrayText;  // 設計時の隠れたタブ
  if (PC.Font.Color <> clDefault) and (PC.Font.Color <> clWindowText) then
    Fg := PC.Font.Color;

  X := R.Left + S96(CPC_PAD);
  // アイコン
  Img := PC.GetImageIndex(Pg.PageIndex);
  if (PC.Images <> nil) and (Img >= 0) then
  begin
    Res := PC.Images.ResolutionForPPI[PC.ImagesWidth, PC.Font.PixelsPerInch,
      PC.GetCanvasScaleFactor];
    IW := Res.Width;
    IH := Res.Height;
    Res.Draw(Canvas, X, (R.Top + R.Bottom - IH) div 2, Img, PC.Enabled);
    Inc(X, IW + S96(CPC_ICON_GAP));
  end;
  // 文字
  TR := Rect(X, R.Top, R.Right - S96(CPC_PAD), R.Bottom);
  if nboShowCloseButtons in PC.Options then
    Dec(TR.Right, S96(CPC_CLOSE_SIZE) + S96(CPC_CLOSE_GAP));
  if (TR.Right > TR.Left) and not ((FEdit <> nil) and (FEditPage = Pg)) then
  begin
    Canvas.Font.Assign(PC.Font);
    Canvas.Font.Color := Fg;
    TS := Canvas.TextStyle;
    TS.Alignment := taLeftJustify;
    TS.Layout := tlCenter;
    TS.SingleLine := True;
    TS.EndEllipsis := True;
    TS.Clipping := True;
    TS.Opaque := False;
    Canvas.Brush.Style := bsClear;
    Canvas.TextRect(TR, TR.Left, TR.Top, Pg.Caption, TS);
  end;
  // ［×］
  if nboShowCloseButtons in PC.Options then
  begin
    CR := TabCloseRect(R);
    if (FHot.Kind = shTabClose) and (FHot.Page = Pg) then
    begin
      CloseBg := Rect(0, 0, S96(CPC_CLOSE_SIZE), S96(CPC_CLOSE_SIZE));
      Types.OffsetRect(CloseBg, (CR.Left + CR.Right - S96(CPC_CLOSE_SIZE)) div 2,
        (CR.Top + CR.Bottom - S96(CPC_CLOSE_SIZE)) div 2);
      if Bg = clNone then
        DrawShape(CloseBg, CXBlendColor(BackColor, clBtnText, 20))
      else
        DrawShape(CloseBg, CXBlendColor(Bg, clBtnText, 20));
    end;
    DrawSymbol(CR, SYM_CLOSE, Fg, S96(CPC_SYMBOL_S));
  end;
end;

procedure TCTabStrip.PaintButton(const R: TRect; AKind: TCStripHitKind; ACode: Cardinal;
  AEnabled: Boolean);
var
  Fg: TColor;
begin
  if (R.Right <= R.Left) then
    Exit;
  if AEnabled and not (csDesigning in FPageControl.ComponentState) then
  begin
    if FDown.Kind = AKind then
      DrawShape(R, CXBlendColor(BackColor, clBtnText, 20))
    else if FHot.Kind = AKind then
      DrawShape(R, CXBlendColor(BackColor, clBtnText, 10));
  end;
  if AEnabled then
    Fg := clBtnText
  else
    Fg := clGrayText;
  DrawSymbol(R, ACode, Fg, S96(CPC_SYMBOL));
end;

procedure TCTabStrip.Paint;
var
  I, X: Integer;
  R: TRect;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := BackColor;
  Canvas.FillRect(ClientRect);
  // タブ（見える範囲だけ）
  Canvas.ClipRect := FViewRect;
  Canvas.Clipping := True;
  for I := 0 to High(FTabs) do
  begin
    if FPageControl.IndexOf(FTabs[I].Page) < 0 then
      Continue;  // もう無いページ
    R := TabScreenRect(I);
    if (R.Right <= FViewRect.Left) or (R.Left >= FViewRect.Right) then
      Continue;
    PaintTab(I);
  end;
  Canvas.Clipping := False;
  // ボタン
  if FOverflow then
  begin
    PaintButton(FPrevRect, shPrev, SYM_LEFT, FScrollPos > 0);
    PaintButton(FNextRect, shNext, SYM_RIGHT, FScrollPos < MaxScroll);
  end;
  if nboShowAddTabButton in FPageControl.Options then
    PaintButton(FAddRect, shAdd, SYM_ADD, True);
  if FPageControl.ShowTabListButton then
    PaintButton(FListRect, shList, SYM_DOWN, True);
  // ドラッグ中の縦線
  if FDragging and (FDropIndex >= 0) then
  begin
    if FDropIndex < Length(FTabs) then
      X := TabScreenRect(FDropIndex).Left - S96(CPC_TAB_GAP) div 2
    else if Length(FTabs) > 0 then
      X := TabScreenRect(High(FTabs)).Right + S96(CPC_TAB_GAP) div 2
    else
      X := FViewRect.Left;
    X := EnsureRange(X, FViewRect.Left, FViewRect.Right - 1);
    Canvas.Brush.Color := clHighlight;
    Canvas.FillRect(Rect(X - 1, FTabTop, X + 1, FTabBottom));
  end;
end;

procedure TCTabStrip.Resize;
begin
  inherited Resize;
  LayoutTabs;
  // 幅が変わったら、表示中のタブが見える位置にする
  if FPageControl.ActivePage <> nil then
    EnsureVisible(FPageControl.ActivePage);
end;

procedure TCTabStrip.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  H: TCStripHit;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or (csDesigning in FPageControl.ComponentState) then
    Exit;
  if FEdit <> nil then
    FPageControl.DoEditCaptionConfirm(FEdit.Text);
  H := HitTest(Point(X, Y));
  FDown := H;
  case H.Kind of
    shTab:
      begin
        // 押した時点で表示中にする。取りやめられたらドラッグもしない
        FPageControl.DoTabClick(H.Page);
        if FPageControl.ActivePage = H.Page then
        begin
          FDragPage := H.Page;
          FDragStartX := X;
          FDragging := False;
        end;
      end;
    shPrev, shNext:
      begin
        if H.Kind = shPrev then FRepeatDir := -1 else FRepeatDir := 1;
        ScrollStep(FRepeatDir);
        FRepeatTimer.Interval := 400;
        FRepeatTimer.Enabled := True;
      end;
    shList:
      begin
        FDown.Kind := shNone;
        // 一覧が閉じた直後の押下は、閉じる操作として扱う（開き直さない）
        if GetTickCount64 - FListClosedTick > 300 then
          FPageControl.ShowTabList;
      end;
  end;
  Invalidate;
end;

procedure TCTabStrip.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  H: TCStripHit;
begin
  inherited MouseMove(Shift, X, Y);
  if csDesigning in FPageControl.ComponentState then
    Exit;
  if FDragPage <> nil then
  begin
    if not FDragging and (Abs(X - FDragStartX) >= Mouse.DragThreshold) then
    begin
      FDragging := True;
      Application.AddOnKeyDownBeforeHandler(@DragKeyDown);
      FDragTimer.Enabled := True;
    end;
    if FDragging then
    begin
      FDragMouseX := X;
      FDropIndex := DropIndexAt(X);
      Invalidate;
      Exit;
    end;
  end;
  H := HitTest(Point(X, Y));
  if (FDown.Kind <> shNone) and not SameHit(H, FDown) then
    H.Kind := shNone;
  if not SameHit(H, FHot) then
  begin
    FHot := H;
    Invalidate;
  end;
end;

procedure TCTabStrip.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  H, Down: TCStripHit;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if csDesigning in FPageControl.ComponentState then
    Exit;
  FRepeatTimer.Enabled := False;
  if Button <> mbLeft then
    Exit;
  if FDragging then
  begin
    FinishDrag(Point(X, Y));
    Exit;
  end;
  FDragPage := nil;
  Down := FDown;
  FDown.Kind := shNone;
  FDown.Page := nil;
  H := HitTest(Point(X, Y));
  // 押して、同じ場所で離したときだけ動く
  if SameHit(H, Down) then
    case H.Kind of
      shTabClose: FPageControl.DoCloseButtonClick(H.Page);
      shAdd: FPageControl.DoAddButtonClick;
    end;
  Invalidate;
end;

procedure TCTabStrip.MouseLeave;
begin
  inherited MouseLeave;
  if FHot.Kind <> shNone then
  begin
    FHot.Kind := shNone;
    FHot.Page := nil;
    Invalidate;
  end;
end;

function TCTabStrip.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if Result then
    Exit;
  // タブ列の上でマウスホイールを回すとスクロールする
  if FOverflow then
  begin
    if WheelDelta > 0 then
      ScrollStep(-1)
    else
      ScrollStep(1);
  end;
  Result := True;
end;

procedure TCTabStrip.DoContextPopup(MousePos: TPoint; var Handled: Boolean);
var
  H: TCStripHit;
  P: TPoint;
begin
  if csDesigning in FPageControl.ComponentState then
  begin
    inherited DoContextPopup(MousePos, Handled);
    Exit;
  end;
  if (MousePos.X < 0) and (MousePos.Y < 0) then
    MousePos := Point(ClientWidth div 2, ClientHeight div 2);
  H := HitTest(MousePos);
  P := ClientToScreen(MousePos);
  if H.Kind in [shTab, shTabClose] then
    FPageControl.ShowTabMenu(H.Page, P)
  else if H.Kind = shNone then
    FPageControl.ShowTabMenu(nil, P);
  Handled := True;
end;

procedure TCTabStrip.RepeatTimerTick(Sender: TObject);
begin
  FRepeatTimer.Interval := 100;
  ScrollStep(FRepeatDir);
end;

{ ドラッグ中、タブ列の左右の端に近づくと自動でスクロールする }
procedure TCTabStrip.DragTimerTick(Sender: TObject);
var
  Step: Integer;
begin
  if not FDragging then
  begin
    FDragTimer.Enabled := False;
    Exit;
  end;
  Step := S96(10);
  if FDragMouseX < FViewRect.Left + S96(CPC_AUTOSCROLL) then
    SetScrollPos(FScrollPos - Step)
  else if FDragMouseX > FViewRect.Right - S96(CPC_AUTOSCROLL) then
    SetScrollPos(FScrollPos + Step)
  else
    Exit;
  FDropIndex := DropIndexAt(FDragMouseX);
  Invalidate;
end;

{ 落とす位置（表示しているタブの並びでの、挿入する前の番号）。末尾なら Length(FTabs)。 }
function TCTabStrip.DropIndexAt(X: Integer): Integer;
var
  I: Integer;
  R: TRect;
begin
  for I := 0 to High(FTabs) do
  begin
    R := TabScreenRect(I);
    if X < (R.Left + R.Right) div 2 then
      Exit(I);
  end;
  Result := Length(FTabs);
end;

procedure TCTabStrip.DragKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if FDragging and (Key = VK_ESCAPE) then
  begin
    Key := 0;
    CancelDrag;
  end;
end;

procedure TCTabStrip.CancelDrag;
begin
  if FDragging then
    Application.RemoveOnKeyDownBeforeHandler(@DragKeyDown);
  FDragging := False;
  FDragPage := nil;
  FDropIndex := -1;
  FDragTimer.Enabled := False;
  FDown.Kind := shNone;
  FDown.Page := nil;
  MouseCapture := False;
  Invalidate;
end;

procedure TCTabStrip.FinishDrag(const P: TPoint);
var
  Pg: TCTabSheet;
  OldIdx, NewIdx, Drop: Integer;
begin
  Pg := FDragPage;
  Drop := FDropIndex;
  CancelDrag;
  // タブ列の外では落とせない
  if (Pg = nil) or not PtInRect(ClientRect, P) or (Drop < 0) then
    Exit;
  OldIdx := Pg.PageIndex;
  // 表示しているタブの並びの番号を、ページの番号に直す
  if Drop < Length(FTabs) then
    NewIdx := FTabs[Drop].Page.PageIndex
  else
    NewIdx := FPageControl.PageCount;
  if NewIdx > OldIdx then
    Dec(NewIdx);
  if NewIdx = OldIdx then
    Exit;
  FPageControl.MovePage(Pg, NewIdx);
  if Assigned(FPageControl.OnPageMoved) then
    FPageControl.OnPageMoved(FPageControl, Pg, OldIdx, NewIdx);
end;

procedure TCTabStrip.PageRemoved(APage: TCTabSheet);
begin
  if FHot.Page = APage then
  begin
    FHot.Kind := shNone;
    FHot.Page := nil;
  end;
  if FDown.Page = APage then
  begin
    FDown.Kind := shNone;
    FDown.Page := nil;
  end;
  if FDragPage = APage then
    CancelDrag;
  if FEditPage = APage then
    EndEdit;
end;

{ その場編集 }
procedure TCTabStrip.BeginEdit(APage: TCTabSheet);
var
  I, X: Integer;
  R: TRect;
  PC: TCPageControl;
begin
  PC := FPageControl;
  I := IndexOfStripTab(APage);
  if I < 0 then
    Exit;
  R := TabScreenRect(I);
  X := R.Left + S96(CPC_PAD);
  if (PC.Images <> nil) and (PC.GetImageIndex(APage.PageIndex) >= 0) then
    Inc(X, IconWidthPx + S96(CPC_ICON_GAP));
  R.Left := X;
  R.Right := R.Right - S96(CPC_PAD);
  if nboShowCloseButtons in PC.Options then
    Dec(R.Right, S96(CPC_CLOSE_SIZE) + S96(CPC_CLOSE_GAP));
  if R.Right - R.Left < S96(40) then
    R.Right := R.Left + S96(40);
  if FEdit = nil then
  begin
    FEdit := TEdit.Create(Self);
    FEdit.BorderStyle := bsSingle;
    FEdit.OnKeyDown := @EditKeyDown;
    FEdit.OnExit := @EditExit;
    FEdit.Parent := Self;
    FEditPage := APage;
    FEdit.Text := APage.Caption;
    FEditEnding := False;
  end;
  FEdit.Font.Assign(PC.Font);
  FEdit.SetBounds(R.Left, (R.Top + R.Bottom - FEdit.Height) div 2, R.Right - R.Left, FEdit.Height);
  FEdit.Visible := True;
  if FEdit.CanFocus then
  begin
    FEdit.SetFocus;
    FEdit.SelectAll;
  end;
  Invalidate;
end;

procedure TCTabStrip.EndEdit;
begin
  if FEdit = nil then
    Exit;
  FEditEnding := True;
  FEdit.OnExit := nil;
  FEdit.OnKeyDown := nil;
  FEdit.Visible := False;
  FEditPage := nil;
  // 自分のイベントの中から呼ばれることがあるので、後で破棄する
  Application.QueueAsyncCall(@FreeEditAsync, PtrInt(FEdit));
  FEdit := nil;
  Invalidate;
end;

procedure TCTabStrip.FreeEditAsync(Data: PtrInt);
begin
  TObject(Data).Free;
end;

function TCTabStrip.EditText: string;
begin
  if FEdit <> nil then
    Result := FEdit.Text
  else
    Result := '';
end;

function TCTabStrip.IsEditing: Boolean;
begin
  Result := FEdit <> nil;
end;

procedure TCTabStrip.EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_RETURN:
      begin
        Key := 0;
        FPageControl.DoEditCaptionConfirm(FEdit.Text);
      end;
    VK_ESCAPE:
      begin
        Key := 0;
        FPageControl.DoEditCaptionCancel;
      end;
  end;
end;

procedure TCTabStrip.EditExit(Sender: TObject);
begin
  if (FEdit <> nil) and not FEditEnding then
    FPageControl.DoEditCaptionConfirm(FEdit.Text);
end;

function TCTabStrip.ListButtonScreenRect: TRect;
begin
  Result.TopLeft := ClientToScreen(FListRect.TopLeft);
  Result.BottomRight := ClientToScreen(FListRect.BottomRight);
end;

procedure TCTabStrip.ListClosed;
begin
  FListClosedTick := GetTickCount64;
end;

{ ===========================================================================
  TCTabListView / TCTabListPopup
  =========================================================================== }

function TCTabListView.RowHeight: Integer;
begin
  Result := CXScale96(FPopup.FPageControl, CPC_LIST_ROW);
end;

function TCTabListView.RowAt(Y: Integer): Integer;
begin
  Result := Y div RowHeight;
  if (Result < 0) or (Result > High(FPopup.FRows)) then
    Result := -1;
end;

function TCTabListView.CloseRect(ARow: Integer): TRect;
var
  S: Integer;
begin
  S := CXScale96(FPopup.FPageControl, CPC_CLOSE_HIT);
  Result := Rect(ClientWidth - S - CXScale96(FPopup.FPageControl, 4), ARow * RowHeight,
    ClientWidth - CXScale96(FPopup.FPageControl, 4), (ARow + 1) * RowHeight);
end;

procedure TCTabListView.Paint;
var
  I, X, RH, Img: Integer;
  R, TR, CR: TRect;
  Row: TCListRow;
  PC: TCPageControl;
  TS: TTextStyle;
  Res: TScaledImageListResolution;
  Fg: TColor;
  FontName: string;
begin
  PC := FPopup.FPageControl;
  RH := RowHeight;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clWindow;
  Canvas.FillRect(ClientRect);
  for I := 0 to High(FPopup.FRows) do
  begin
    Row := FPopup.FRows[I];
    R := Rect(0, I * RH, ClientWidth, (I + 1) * RH);
    if Row.Kind = lrSeparator then
    begin
      Canvas.Pen.Color := clBtnShadow;
      Canvas.Line(R.Left + CXScale96(PC, 8), (R.Top + R.Bottom) div 2,
        R.Right - CXScale96(PC, 8), (R.Top + R.Bottom) div 2);
      Continue;
    end;
    if (I = FHotRow) and not ((Row.Kind = lrMenu) and not Row.Item.Enabled) then
    begin
      Canvas.Brush.Color := CXBlendColor(clWindow, clWindowText, 10);
      Canvas.FillRect(R);
    end;
    X := R.Left + CXScale96(PC, CPC_PAD);
    Fg := clWindowText;
    Canvas.Font.Assign(PC.Font);
    Canvas.Font.Style := [];
    if Row.Kind = lrMenu then
    begin
      if not Row.Item.Enabled then
        Fg := clGrayText;
      TR := Rect(X, R.Top, R.Right - CXScale96(PC, CPC_PAD), R.Bottom);
      Canvas.Font.Color := Fg;
      TS := Canvas.TextStyle;
      TS.Alignment := taLeftJustify;
      TS.Layout := tlCenter;
      TS.SingleLine := True;
      TS.EndEllipsis := True;
      TS.Clipping := True;
      TS.Opaque := False;
      Canvas.Brush.Style := bsClear;
      Canvas.TextRect(TR, TR.Left, TR.Top, StripHotkey(Row.Item.Caption), TS);
      Canvas.Brush.Style := bsSolid;
      Continue;
    end;
    // タブの行：アイコン＋キャプション＋［×］。表示中のタブは太字
    Img := PC.GetImageIndex(Row.Page.PageIndex);
    if (PC.Images <> nil) and (Img >= 0) then
    begin
      Res := PC.Images.ResolutionForPPI[PC.ImagesWidth, PC.Font.PixelsPerInch,
        PC.GetCanvasScaleFactor];
      Res.Draw(Canvas, X, (R.Top + R.Bottom - Res.Height) div 2, Img, True);
      Inc(X, Res.Width + CXScale96(PC, CPC_ICON_GAP));
    end;
    CR := CloseRect(I);
    TR := Rect(X, R.Top, CR.Left - CXScale96(PC, CPC_CLOSE_GAP), R.Bottom);
    if Row.Page = PC.ActivePage then
      Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := Fg;
    TS := Canvas.TextStyle;
    TS.Alignment := taLeftJustify;
    TS.Layout := tlCenter;
    TS.SingleLine := True;
    TS.EndEllipsis := True;
    TS.Clipping := True;
    TS.Opaque := False;
    Canvas.Brush.Style := bsClear;
    Canvas.TextRect(TR, TR.Left, TR.Top, Row.Page.Caption, TS);
    Canvas.Brush.Style := bsSolid;
    if (I = FHotRow) and FHotClose then
    begin
      Canvas.Brush.Color := CXBlendColor(clWindow, clWindowText, 20);
      Canvas.FillRect(CR);
    end;
    FontName := CXSymbolFontName;
    if FontName <> '' then
    begin
      CXSetSymbolFont(Canvas, FontName, CXScale96(PC, CPC_SYMBOL_S), Fg);
      TS.Alignment := taCenter;
      TS.EndEllipsis := False;
      Canvas.Brush.Style := bsClear;
      Canvas.TextRect(CR, CR.Left, CR.Top, CXSymbol(SYM_CLOSE), TS);
      Canvas.Brush.Style := bsSolid;
    end
    else
    begin
      Canvas.Pen.Color := Fg;
      X := (CR.Left + CR.Right) div 2;
      Img := (CR.Top + CR.Bottom) div 2;
      RH := CXScale96(PC, 4);
      Canvas.Line(X - RH, Img - RH, X + RH + 1, Img + RH + 1);
      Canvas.Line(X - RH, Img + RH, X + RH + 1, Img - RH - 1);
      RH := RowHeight;
    end;
  end;
end;

procedure TCTabListView.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  R: Integer;
  C: Boolean;
begin
  inherited MouseMove(Shift, X, Y);
  R := RowAt(Y);
  C := (R >= 0) and (FPopup.FRows[R].Kind = lrTab) and PtInRect(CloseRect(R), Point(X, Y));
  if (R <> FHotRow) or (C <> FHotClose) then
  begin
    FHotRow := R;
    FHotClose := C;
    Invalidate;
  end;
end;

procedure TCTabListView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  R: Integer;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button <> mbLeft then
    Exit;
  R := RowAt(Y);
  if R < 0 then
    Exit;
  FPopup.RowClicked(R, (FPopup.FRows[R].Kind = lrTab) and PtInRect(CloseRect(R), Point(X, Y)));
end;

procedure TCTabListView.MouseLeave;
begin
  inherited MouseLeave;
  FHotRow := -1;
  FHotClose := False;
  Invalidate;
end;

constructor TCTabListPopup.CreatePopup(APageControl: TCPageControl);
begin
  inherited CreateNew(nil);
  FPageControl := APageControl;
  BorderStyle := bsNone;
  ShowInTaskBar := stNever;
  FormStyle := fsStayOnTop;
  KeyPreview := True;
  // 枠線は、フォームの BorderWidth（1px）と Color で描く。スクロールボックス自体には枠を付けない
  Color := clBtnShadow;
  BorderWidth := 1;
  OnDeactivate := @PopupDeactivate;
  OnKeyDown := @PopupKeyDown;
  FScroll := TScrollBox.Create(Self);
  FScroll.Parent := Self;
  FScroll.Align := alClient;
  FScroll.BorderStyle := bsNone;
  FScroll.OnResize := @ScrollResize;
  FScroll.HorzScrollBar.Visible := False;
  FScroll.VertScrollBar.Tracking := True;
  FScroll.Color := clWindow;
  FView := TCTabListView.Create(Self);
  FView.FPopup := Self;
  FView.FHotRow := -1;
  FView.Parent := FScroll;
  FView.Left := 0;
  FView.Top := 0;
end;

procedure TCTabListPopup.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  {$IFDEF WINDOWS}
  Params.Style := Params.Style or WS_POPUP;
  Params.ExStyle := Params.ExStyle or WS_EX_TOOLWINDOW;
  if (FPageControl <> nil) then
    Params.WndParent := GetParentForm(FPageControl).Handle;
  {$ENDIF}
end;

procedure TCTabListPopup.DoShow;
{$IFDEF WINDOWS}
type
  TDwmSetWindowAttribute = function(AWnd: HWND; dwAttribute: DWORD; pvAttribute: Pointer;
    cbAttribute: DWORD): HRESULT; stdcall;
var
  Lib: HMODULE;
  P: TDwmSetWindowAttribute;
  Pref: DWORD;
{$ENDIF}
begin
  inherited DoShow;
  // 初めて開くときは、出す前の時点では窓の幅が反映されていないので、出した後に合わせ直す
  UpdateSize;
  {$IFDEF WINDOWS}
  // Windows 11 では角を丸くする（Windows 10 は指定が無いので四角のまま）
  Lib := LoadLibrary('dwmapi.dll');
  if Lib <> 0 then
  begin
    Pointer(P) := GetProcAddress(Lib, 'DwmSetWindowAttribute');
    if Assigned(P) then
    begin
      Pref := 2; // DWMWCP_ROUND
      P(Handle, 33 {DWMWA_WINDOW_CORNER_PREFERENCE}, @Pref, SizeOf(Pref));
    end;
    FreeLibrary(Lib);
  end;
  {$ENDIF}
end;

{ 行を作る：TabListPopupMenu の項目 → 区切り線 → すべてのタブ }
procedure TCTabListPopup.BuildRows;
var
  I, N: Integer;
  PC: TCPageControl;
  Item: TMenuItem;
begin
  PC := FPageControl;
  SetLength(FRows, 0);
  N := 0;
  if PC.TabListPopupMenu <> nil then
  begin
    if Assigned(PC.TabListPopupMenu.OnPopup) then
      PC.TabListPopupMenu.OnPopup(PC.TabListPopupMenu);
    for I := 0 to PC.TabListPopupMenu.Items.Count - 1 do
    begin
      Item := PC.TabListPopupMenu.Items[I];
      // サブメニューを持つ項目は表示しない（1 段のみ）
      if (not Item.Visible) or (Item.Count > 0) then
        Continue;
      SetLength(FRows, N + 1);
      if Item.IsLine then
        FRows[N].Kind := lrSeparator
      else
        FRows[N].Kind := lrMenu;
      FRows[N].Item := Item;
      FRows[N].Page := nil;
      Inc(N);
    end;
    if N > 0 then
    begin
      SetLength(FRows, N + 1);
      FRows[N].Kind := lrSeparator;
      FRows[N].Item := nil;
      FRows[N].Page := nil;
      Inc(N);
    end;
  end;
  for I := 0 to PC.PageCount - 1 do
  begin
    if not PC.Pages[I].TabVisible then
      Continue;
    SetLength(FRows, N + 1);
    FRows[N].Kind := lrTab;
    FRows[N].Item := nil;
    FRows[N].Page := PC.Pages[I];
    Inc(N);
  end;
end;

{ 一覧の大きさ：幅 300（96dpi 時）、高さは行の数に合わせる（枠線の分を含める）。
  画面に入りきらないときだけ縦スクロールする。 }
procedure TCTabListPopup.UpdateSize;
var
  W, H, Content, Frame: Integer;
  Mon: TMonitor;
  WA: TRect;
begin
  W := CXScale96(FPageControl, CPC_LIST_W);
  Content := Length(FRows) * FView.RowHeight;
  Frame := BorderWidth * 2;
  H := Content + Frame;
  Mon := Screen.MonitorFromPoint(Point(Left, Top));
  if Mon <> nil then
    WA := Mon.WorkareaRect
  else
    WA := Screen.WorkAreaRect;
  if Top + H > WA.Bottom then
    H := Max(FView.RowHeight + Frame, WA.Bottom - Top);
  ClientWidth := W;
  ClientHeight := H;
  FView.Height := Content;
  FitViewWidth;
end;

{ 行の幅を、スクロールボックスの中の幅に合わせる（縦スクロールバーが出ていればその分を除く） }
procedure TCTabListPopup.FitViewWidth;
var
  W: Integer;
begin
  W := ClientWidth - BorderWidth * 2;
  if FView.Height > ClientHeight - BorderWidth * 2 then
    Dec(W, GetSystemMetrics(SM_CXVSCROLL));
  if W < 1 then
    W := 1;
  FView.SetBounds(0, 0, W, FView.Height);
  FView.Invalidate;
end;

procedure TCTabListPopup.ScrollResize(Sender: TObject);
begin
  FitViewWidth;
end;

procedure TCTabListPopup.ShowAt(const AScreenRight, AScreenTop: Integer);
var
  Mon: TMonitor;
  WA: TRect;
  L: Integer;
begin
  BuildRows;
  L := AScreenRight - CXScale96(FPageControl, CPC_LIST_W);
  Mon := Screen.MonitorFromPoint(Point(AScreenRight, AScreenTop));
  if Mon <> nil then
    WA := Mon.WorkareaRect
  else
    WA := Screen.WorkAreaRect;
  if L < WA.Left then
    L := WA.Left;
  Left := L;
  Top := AScreenTop;
  UpdateSize;
  Show;
end;

procedure TCTabListPopup.RowClicked(ARow: Integer; AClose: Boolean);
var
  Row: TCListRow;
begin
  Row := FRows[ARow];
  case Row.Kind of
    lrMenu:
      if Row.Item.Enabled then
      begin
        ClosePopup;
        Row.Item.Click;
      end;
    lrTab:
      if AClose then
      begin
        // 一覧は閉じずに残し、行を減らす
        FPageControl.DoTabListCloseClick(Row.Page);
        BuildRows;
        FView.FHotRow := -1;
        if Length(FRows) = 0 then
          ClosePopup
        else
          UpdateSize;
      end
      else
      begin
        ClosePopup;
        FPageControl.DoTabListItemClick(Row.Page);
      end;
  end;
end;

procedure TCTabListPopup.ClosePopup;
begin
  if Visible then
  begin
    Hide;
    FPageControl.FStrip.ListClosed;
  end;
end;

procedure TCTabListPopup.PopupDeactivate(Sender: TObject);
begin
  ClosePopup;
end;

procedure TCTabListPopup.PopupKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    Key := 0;
    ClosePopup;
  end;
end;

{ ===========================================================================
  TCPageControl
  =========================================================================== }

constructor TCPageControl.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  // TCPageControl 自体には部品を置けない（置いた部品は表示中のページに入る）
  ControlStyle := ControlStyle - [csAcceptsControls, csSetCaption];
  FPages := TFPList.Create;
  FPageIndex := -1;
  FTabPosition := tpTop;
  FTabMaxWidth := 240;
  FTabShape := tsRectangle;
  FOptions := [nboShowCloseButtons, nboShowAddTabButton, nboKeyboardTabSwitch];
  FShowTabListButton := True;
  FNewPageCaption := rsCTabNewPageCaption;
  FTabMenuItems := [tmiNew, tmiClose, tmiRename];
  FImageChangeLink := TChangeLink.Create;
  FImageChangeLink.OnChange := @ImageListChange;
  Color := clBtnFace;
  ParentColor := False;
  TabStop := True;
  FStrip := TCTabStrip.Create(Self);
  FStrip.Align := alTop;
  FStrip.Parent := Self;
  with GetControlClassDefaultSize do
    SetInitialBounds(0, 0, CX, CY);
  if not (csDesigning in ComponentState) then
  begin
    Application.AddOnKeyDownBeforeHandler(@KeyDownBefore);
    FKeyHandlerAdded := True;
  end;
end;

destructor TCPageControl.Destroy;
var
  I: Integer;
begin
  if FKeyHandlerAdded then
    Application.RemoveOnKeyDownBeforeHandler(@KeyDownBefore);
  FreeAndNil(FListPopup);
  // ページを破棄する（LCL の TCustomTabControl と同じ）
  FClearing := True;
  for I := FPages.Count - 1 downto 0 do
    TCTabSheet(FPages[I]).Free;
  FreeAndNil(FPages);
  if (FStrip <> nil) and (FStrip.Parent <> Self) then
    FStrip.Parent := nil;
  FreeAndNil(FImageChangeLink);
  inherited Destroy;
end;

class function TCPageControl.GetControlClassDefaultSize: TSize;
begin
  Result.CX := 300;
  Result.CY := 200;
end;

function TCPageControl.GetPage(Index: Integer): TCTabSheet;
begin
  Result := TCTabSheet(FPages[Index]);
end;

function TCPageControl.GetPageCount: Integer;
begin
  if FPages = nil then
    Result := 0
  else
    Result := FPages.Count;
end;

function TCPageControl.GetActivePage: TCTabSheet;
begin
  if (FPageIndex >= 0) and (FPageIndex < PageCount) then
    Result := Pages[FPageIndex]
  else
    Result := nil;
end;

procedure TCPageControl.SetActivePage(AValue: TCTabSheet);
begin
  if (AValue <> nil) and (AValue.PageControl <> Self) then
    Exit;
  SetActivePageIndex(IndexOf(AValue));
end;

{ コードで表示ページを変える。nboDoChangeOnSetIndex のときだけ OnChanging・OnChange を出す。 }
procedure TCPageControl.SetActivePageIndex(AValue: Integer);
begin
  if (AValue < -1) or (AValue >= PageCount) then
    Exit;
  if FPageIndex = AValue then
    Exit;
  if csLoading in ComponentState then
  begin
    FPageIndex := AValue;
    Exit;
  end;
  if (nboDoChangeOnSetIndex in FOptions) and not CanChange then
    Exit;
  InternalSetPageIndex(AValue);
  if ([csDesigning, csLoading, csDestroying] * ComponentState = [])
    and (nboDoChangeOnSetIndex in FOptions) then
    Change;
end;

function TCPageControl.IsNewPageCaptionStored: Boolean;
begin
  Result := FNewPageCaption <> rsCTabNewPageCaption;
end;

function TCPageControl.TabHeightIsStored: Boolean;
begin
  Result := FTabHeight > 0;
end;

function TCPageControl.TabWidthIsStored: Boolean;
begin
  Result := FTabWidth > 0;
end;

procedure TCPageControl.SetImages(AValue: TCustomImageList);
begin
  if FImages = AValue then
    Exit;
  if FImages <> nil then
  begin
    FImages.UnRegisterChanges(FImageChangeLink);
    FImages.RemoveFreeNotification(Self);
  end;
  FImages := AValue;
  if FImages <> nil then
  begin
    FImages.RegisterChanges(FImageChangeLink);
    FImages.FreeNotification(Self);
  end;
  PageChanged;
end;

procedure TCPageControl.SetImagesWidth(AValue: Integer);
begin
  if FImagesWidth = AValue then
    Exit;
  FImagesWidth := AValue;
  PageChanged;
end;

procedure TCPageControl.ImageListChange(Sender: TObject);
begin
  PageChanged;
end;

procedure TCPageControl.SetNewPageCaption(const AValue: string);
begin
  FNewPageCaption := AValue;
end;

procedure TCPageControl.SetOptions(AValue: TCTabControlOptions);
begin
  if FOptions = AValue then
    Exit;
  FOptions := AValue;
  PageChanged;
end;

procedure TCPageControl.SetShowTabListButton(AValue: Boolean);
begin
  if FShowTabListButton = AValue then
    Exit;
  FShowTabListButton := AValue;
  PageChanged;
end;

procedure TCPageControl.SetTabHeight(AValue: Smallint);
begin
  if AValue < 0 then
    AValue := 0;
  if FTabHeight = AValue then
    Exit;
  FTabHeight := AValue;
  PageChanged;
end;

procedure TCPageControl.SetTabWidth(AValue: Smallint);
begin
  if AValue < 0 then
    AValue := 0;
  if FTabWidth = AValue then
    Exit;
  FTabWidth := AValue;
  PageChanged;
end;

procedure TCPageControl.SetTabMaxWidth(AValue: Integer);
begin
  if AValue < 1 then
    AValue := 1;
  if FTabMaxWidth = AValue then
    Exit;
  FTabMaxWidth := AValue;
  PageChanged;
end;

procedure TCPageControl.SetTabShape(AValue: TCTabShape);
begin
  if FTabShape = AValue then
    Exit;
  FTabShape := AValue;
  PageChanged;
end;

procedure TCPageControl.SetTabPosition(AValue: TTabPosition);
begin
  if FTabPosition = AValue then
    Exit;
  FTabPosition := AValue;
  UpdateStripPlace;
end;

procedure TCPageControl.SetTabPopupMenu(AValue: TPopupMenu);
begin
  if FTabPopupMenu = AValue then
    Exit;
  if FTabPopupMenu <> nil then
    FTabPopupMenu.RemoveFreeNotification(Self);
  FTabPopupMenu := AValue;
  if FTabPopupMenu <> nil then
    FTabPopupMenu.FreeNotification(Self);
end;

procedure TCPageControl.SetTabListPopupMenu(AValue: TPopupMenu);
begin
  if FTabListPopupMenu = AValue then
    Exit;
  if FTabListPopupMenu <> nil then
    FTabListPopupMenu.RemoveFreeNotification(Self);
  FTabListPopupMenu := AValue;
  if FTabListPopupMenu <> nil then
    FTabListPopupMenu.FreeNotification(Self);
end;

{ タイトルバーとの結び付け }
procedure TCPageControl.SetTitleBar(AValue: TCTitleBar);
var
  I: Integer;
  C: TControl;
begin
  if FTitleBar = AValue then
    Exit;
  if FTitleBar <> nil then
    FTitleBar.RemoveFreeNotification(Self);
  if AValue <> nil then
  begin
    // 1 つのタイトルバーに結び付けられる TCPageControl は 1 つだけ。前の結び付けを解除する
    for I := AValue.ControlCount - 1 downto 0 do
    begin
      C := AValue.Controls[I];
      if (C is TCTabStrip) and (TCTabStrip(C).PageControl <> Self) then
        TCTabStrip(C).PageControl.TitleBar := nil;
    end;
    AValue.FreeNotification(Self);
  end;
  FTitleBar := AValue;
  UpdateStripPlace;
end;

{ タブ列を置く場所（単体時は上か下、TitleBar 指定時はタイトルバーの中） }
procedure TCPageControl.UpdateStripPlace;
var
  OldParent: TWinControl;
begin
  if (FStrip = nil) or (csDestroying in ComponentState) then
    Exit;
  OldParent := FStrip.Parent;
  if (FTitleBar <> nil) and not (csDestroying in FTitleBar.ComponentState) then
  begin
    FStrip.Align := alNone;
    FStrip.Parent := FTitleBar;
    FTitleBar.ReAlign;
  end
  else
  begin
    FStrip.Parent := Self;
    if FTabPosition = tpBottom then
      FStrip.Align := alBottom
    else
      FStrip.Align := alTop;
  end;
  if (OldParent is TCTitleBar) and (OldParent <> FStrip.Parent) then
    OldParent.ReAlign;
  FStrip.Visible := True;
  FStrip.LayoutTabs;
  FStrip.Invalidate;
  // タブ列の置き場所が変わったら、自分を並べ直し、描き直し、ページの表示を確かめ直す（D-19）
  if OldParent <> FStrip.Parent then
  begin
    ReAlign;
    Invalidate;
    ShowCurrentPage(-1);
  end;
end;

procedure TCPageControl.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then
    Exit;
  if AComponent = FImages then
    SetImages(nil)
  else if AComponent = FTabPopupMenu then
    FTabPopupMenu := nil
  else if AComponent = FTabListPopupMenu then
    FTabListPopupMenu := nil
  else if AComponent = FTitleBar then
  begin
    FTitleBar := nil;
    UpdateStripPlace;
  end;
end;

{ .lfm にはページを並び順に書く（PageIndex は保存しないため） }
procedure TCPageControl.GetChildren(Proc: TGetChildProc; Root: TComponent);
var
  I: Integer;
begin
  for I := 0 to PageCount - 1 do
    if Pages[I].Owner = Root then
      Proc(Pages[I]);
end;

procedure TCPageControl.Loaded;
begin
  inherited Loaded;
  if (FPageIndex < 0) and (PageCount > 0) then
    FPageIndex := 0;
  if FPageIndex >= PageCount then
    FPageIndex := PageCount - 1;
  UpdateDesignerFlags;
  ShowCurrentPage(-1);
  UpdateStripPlace;
end;

{ ページがあるときはページが全面を覆う。表示中のページが無い（0 枚など）ときは、
  ページの場所を、ページがあるときと同じ clWindow で塗る（部品の範囲が分かるように） }
procedure TCPageControl.Paint;
begin
  Canvas.Brush.Style := bsSolid;
  if ActivePage = nil then
    Canvas.Brush.Color := clWindow
  else
    Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
end;

function TCPageControl.IndexOf(APage: TPersistent): Integer;
begin
  if FPages = nil then
    Exit(-1);
  Result := FPages.IndexOf(APage);
end;

procedure TCPageControl.InsertPage(APage: TCTabSheet);
begin
  if FPages.IndexOf(APage) >= 0 then
    Exit;
  FPages.Add(APage);
  // 最初のページは表示中にする（LCL と同じ）
  if FPageIndex < 0 then
  begin
    FPageIndex := FPages.Count - 1;
    if not (csLoading in ComponentState) then
      ShowCurrentPage(-1);
  end;
  UpdateDesignerFlags;
  PageChanged;
end;

{ ページを外す（ページの Free・Parent := nil から呼ばれる）。表示中なら近くのページに切り替え、OnChange を出す。 }
procedure TCPageControl.RemovePage(APage: TCTabSheet);
var
  Idx, NewIdx: Integer;
  WasActive: Boolean;
begin
  if FPages = nil then
    Exit;
  Idx := FPages.IndexOf(APage);
  if Idx < 0 then
    Exit;
  if FStrip <> nil then
    FStrip.PageRemoved(APage);
  if FPopupPage = APage then
    FPopupPage := nil;
  WasActive := Idx = FPageIndex;
  FPages.Delete(Idx);
  if csDestroying in ComponentState then
    Exit;
  // タブ列が消えたページを覚えたまま描いたり調べたりしないよう、すぐに並びを作り直す
  if FStrip <> nil then
    FStrip.LayoutTabs;
  if WasActive then
  begin
    if FClearing then
      NewIdx := -1
    else
      NewIdx := FindVisibleNear(Idx);
    FPageIndex := -1;
    if NewIdx >= 0 then
      InternalSetPageIndex(NewIdx)
    else
      InternalSetPageIndex(-1);
    if not FClearing and ([csLoading, csDesigning] * ComponentState = []) then
      Change;
  end
  else if FPageIndex > Idx then
    Dec(FPageIndex);
  UpdateDesignerFlags;
  PageChanged;
  if ActivePage = nil then
    Invalidate;
end;

{ 右隣の表示しているタブ（無ければ左隣）。AIndex は外したページがあった位置、または隠したページの位置。 }
function TCPageControl.FindVisibleNear(AIndex: Integer): Integer;
var
  I: Integer;
begin
  for I := AIndex to PageCount - 1 do
    if Pages[I].TabVisible then
      Exit(I);
  for I := Min(AIndex, PageCount) - 1 downto 0 do
    if Pages[I].TabVisible then
      Exit(I);
  Result := -1;
end;

procedure TCPageControl.MovePage(APage: TCTabSheet; ANewIndex: Integer);
var
  OldIdx: Integer;
  Active: TCTabSheet;
begin
  OldIdx := IndexOf(APage);
  if OldIdx < 0 then
    Exit;
  ANewIndex := EnsureRange(ANewIndex, 0, PageCount - 1);
  if ANewIndex = OldIdx then
    Exit;
  Active := ActivePage;
  FPages.Move(OldIdx, ANewIndex);
  FPageIndex := IndexOf(Active);
  UpdateDesignerFlags;
  PageChanged;
  if csDesigning in ComponentState then
    OwnerFormDesignerModified(Self);
end;

{ 表示中のページを変える（イベントは出さない） }
procedure TCPageControl.InternalSetPageIndex(AValue: Integer);
var
  Old: Integer;
begin
  Old := FPageIndex;
  FPageIndex := AValue;
  UpdateDesignerFlags;
  if not (csLoading in ComponentState) then
    ShowCurrentPage(Old);
  if (FStrip <> nil) and (ActivePage <> nil) then
  begin
    FStrip.LayoutTabs;
    FStrip.EnsureVisible(ActivePage);
  end;
  if FStrip <> nil then
    FStrip.Invalidate;
  if FListPopup <> nil then
    FListPopup.Invalidate;
end;

{ 表示中でないページは Visible := False（LCL の ShowCurrentPage と同じ） }
procedure TCPageControl.ShowCurrentPage(AOldIndex: Integer);
var
  I: Integer;
  Cur, OldPg: TCTabSheet;
  F: TCustomForm;
  HadFocus: Boolean;
  C: TWinControl;
begin
  Cur := ActivePage;
  if (AOldIndex >= 0) and (AOldIndex < PageCount) then
    OldPg := Pages[AOldIndex]
  else
    OldPg := nil;
  HadFocus := False;
  F := GetParentForm(Self);
  if (OldPg <> nil) and (F <> nil) and (F.ActiveControl <> nil) then
    HadFocus := OldPg.ContainsControl(F.ActiveControl);
  if Cur <> nil then
    Cur.Visible := True;
  // 前のページの部品にフォーカスがあったら、新しいページに移す
  if HadFocus and (Cur <> nil) and (Cur <> OldPg) and Cur.Enabled
    and not (csDesigning in ComponentState) then
  begin
    C := Cur.FindNextControl(nil, True, True, False);
    if (C <> nil) and C.CanFocus then
      C.SetFocus
    else if CanFocus then
      SetFocus;
  end;
  for I := 0 to PageCount - 1 do
    if Pages[I] <> Cur then
      Pages[I].Visible := False;
  for I := 0 to PageCount - 1 do
    Pages[I].RefreshShowing;
end;

{ 設計画面には表示中のページだけを出す（LCL の UpdateDesignerFlags と同じ） }
procedure TCPageControl.UpdateDesignerFlags;
var
  I: Integer;
begin
  for I := 0 to PageCount - 1 do
    if I = FPageIndex then
      Pages[I].ControlStyle := Pages[I].ControlStyle - [csNoDesignVisible]
    else
      Pages[I].ControlStyle := Pages[I].ControlStyle + [csNoDesignVisible];
end;

function TCPageControl.CanChange: Boolean;
begin
  Result := True;
  if ([csDesigning, csDestroying] * ComponentState = []) and Assigned(FOnChanging) then
    FOnChanging(Self, Result);
end;

procedure TCPageControl.Change;
begin
  if ([csLoading, csDestroying] * ComponentState <> []) then
    Exit;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

{ ページの表示に関わる変化（キャプション・アイコン・設定）。タブの配置を計算し直す。 }
procedure TCPageControl.PageChanged;
begin
  if (FStrip = nil) or (csDestroying in ComponentState) then
    Exit;
  FStrip.LayoutTabs;
  if FListPopup <> nil then
    FListPopup.Invalidate;
end;

function TCPageControl.GetImageIndex(APageIndex: Integer): Integer;
begin
  if (APageIndex < 0) or (APageIndex >= PageCount) then
    Exit(-1);
  Result := Pages[APageIndex].ImageIndex;
  if Assigned(FOnGetImageIndex) then
    FOnGetImageIndex(Self, APageIndex, Result);
end;

{ 画面の操作でページを表示する（OnChanging・OnChange を出す） }
procedure TCPageControl.UserSelectPage(APage: TCTabSheet);
var
  Idx: Integer;
  F: TCustomForm;
begin
  Idx := IndexOf(APage);
  if (Idx < 0) or (Idx = FPageIndex) then
    Exit;
  if csDesigning in ComponentState then
  begin
    InternalSetPageIndex(Idx);
    // 表示したページを選んだ状態にする（LCL の TPageControl と同じ）
    F := GetParentForm(Self);
    if (F <> nil) and (F.Designer <> nil) then
    begin
      F.Designer.SelectOnlyThisComponent(ActivePage);
      // 選択の印はデザイナーがフォームを描くときに描き足すので、フォーム全体を描き直させ、
      // 前のページの部品の印が残らないようにする
      F.Invalidate;
      {$IFDEF WINDOWS}
      if F.HandleAllocated then
        RedrawWindow(F.Handle, nil, 0, RDW_INVALIDATE or RDW_ERASE or RDW_ALLCHILDREN);
      {$ENDIF}
    end;
    OwnerFormDesignerModified(Self);
    Exit;
  end;
  if not CanChange then
    Exit;
  InternalSetPageIndex(Idx);
  Change;
end;

{ 画面の操作でページを閉じる：OnPageClose → Free }
procedure TCPageControl.ClosePageByUser(APage: TCTabSheet);
var
  CanClose: Boolean;
begin
  if (APage = nil) or (IndexOf(APage) < 0) then
    Exit;
  CanClose := True;
  if Assigned(FOnPageClose) then
    FOnPageClose(Self, APage, CanClose);
  if not CanClose then
    Exit;
  APage.Free;
end;

{ ---- 操作を受けたときの処理 ---- }

procedure TCPageControl.DoTabClick(APage: TCTabSheet);
begin
  UserSelectPage(APage);
end;

procedure TCPageControl.DoAddButtonClick;
var
  Pg: TCTabSheet;
  NewOwner: TComponent;
begin
  // 5.5.1：末尾に作り、表示中にし、見える位置までスクロールし、OnNewPage を出す
  if not CanChange then
    Exit;
  NewOwner := Owner;
  if NewOwner = nil then
    NewOwner := Self;
  Pg := TCTabSheet.Create(NewOwner);
  Pg.Caption := FNewPageCaption;
  Pg.Parent := Self;
  if IndexOf(Pg) <> FPageIndex then
    InternalSetPageIndex(IndexOf(Pg));
  if FStrip <> nil then
    FStrip.EnsureVisible(Pg);
  Change;
  if Assigned(FOnNewPage) then
    FOnNewPage(Self, Pg);
end;

procedure TCPageControl.DoCloseButtonClick(APage: TCTabSheet);
begin
  ClosePageByUser(APage);
end;

procedure TCPageControl.DoMenuNewClick;
begin
  DoAddButtonClick;
end;

procedure TCPageControl.DoMenuCloseClick(APage: TCTabSheet);
begin
  ClosePageByUser(APage);
end;

procedure TCPageControl.DoMenuRenameClick(APage: TCTabSheet);
begin
  EditPageCaption(APage);
end;

procedure TCPageControl.DoAppMenuItemClick(AItem: TMenuItem; APage: TCTabSheet);
begin
  if AItem = nil then
    Exit;
  FPopupPage := APage;
  AItem.Click;
end;

procedure TCPageControl.DoTabListItemClick(APage: TCTabSheet);
begin
  UserSelectPage(APage);
end;

procedure TCPageControl.DoTabListCloseClick(APage: TCTabSheet);
begin
  ClosePageByUser(APage);
end;

{ その場編集の確定。空文字は取りやめと同じ。 }
procedure TCPageControl.DoEditCaptionConfirm(const AText: string);
var
  Pg: TCTabSheet;
  S: string;
  CanRename: Boolean;
begin
  if (FStrip = nil) or not FStrip.IsEditing then
    Exit;
  Pg := FStrip.FEditPage;
  FStrip.EndEdit;
  if (Pg = nil) or (AText = '') then
    Exit;
  S := AText;
  CanRename := True;
  if Assigned(FOnPageRename) then
    FOnPageRename(Self, Pg, S, CanRename);
  if CanRename and (S <> '') then
    Pg.Caption := S;
end;

procedure TCPageControl.DoEditCaptionCancel;
begin
  if FStrip <> nil then
    FStrip.EndEdit;
end;

{ ---- 公開メソッド ---- }

function TCPageControl.AddTabSheet: TCTabSheet;
var
  NewOwner: TComponent;
begin
  NewOwner := Owner;
  if NewOwner = nil then
    NewOwner := Self;
  Result := TCTabSheet.Create(NewOwner);
  Result.Caption := FNewPageCaption;
  Result.Parent := Self;
end;

procedure TCPageControl.Clear;
var
  I: Integer;
  HadActive: Boolean;
begin
  HadActive := FPageIndex >= 0;
  FClearing := True;
  try
    for I := PageCount - 1 downto 0 do
      Pages[I].Free;
  finally
    FClearing := False;
  end;
  FPageIndex := -1;
  PageChanged;
  if HadActive and ([csLoading, csDesigning, csDestroying] * ComponentState = []) then
    Change;
end;

function TCPageControl.FindNextPage(CurPage: TCTabSheet; GoForward,
  CheckTabVisible: Boolean): TCTabSheet;
var
  I, StartIdx, N: Integer;
begin
  Result := nil;
  N := PageCount;
  if N = 0 then
    Exit;
  StartIdx := IndexOf(CurPage);
  if StartIdx < 0 then
  begin
    if GoForward then StartIdx := N - 1 else StartIdx := 0;
  end;
  I := StartIdx;
  repeat
    if GoForward then
      I := (I + 1) mod N
    else
      I := (I + N - 1) mod N;
    if (not CheckTabVisible) or Pages[I].TabVisible then
      Exit(Pages[I]);
  until I = StartIdx;
end;

procedure TCPageControl.SelectNextPage(GoForward: Boolean);
begin
  SelectNextPage(GoForward, True);
end;

procedure TCPageControl.SelectNextPage(GoForward: Boolean; CheckTabVisible: Boolean);
var
  Pg: TCTabSheet;
begin
  Pg := FindNextPage(ActivePage, GoForward, CheckTabVisible);
  if (Pg <> nil) and (Pg <> ActivePage) then
    ActivePage := Pg;
end;

{ 座標はタブ列を持つ部品（単体なら自分、TitleBar 指定時は TCTitleBar）の座標 }
function TCPageControl.IndexOfTabAt(X, Y: Integer): Integer;
begin
  Result := IndexOfTabAt(Point(X, Y));
end;

function TCPageControl.IndexOfTabAt(P: TPoint): Integer;
var
  I: Integer;
begin
  Result := -1;
  if FStrip = nil then
    Exit;
  I := FStrip.VisibleTabAt(Point(P.X - FStrip.Left, P.Y - FStrip.Top));
  if I < 0 then
    Exit;
  Result := FStrip.FTabs[I].Page.TabIndex;
end;

function TCPageControl.IndexOfPageAt(X, Y: Integer): Integer;
begin
  Result := IndexOfPageAt(Point(X, Y));
end;

function TCPageControl.IndexOfPageAt(P: TPoint): Integer;
var
  I: Integer;
begin
  Result := -1;
  if FStrip = nil then
    Exit;
  I := FStrip.VisibleTabAt(Point(P.X - FStrip.Left, P.Y - FStrip.Top));
  if I < 0 then
    Exit;
  Result := FStrip.FTabs[I].Page.PageIndex;
end;

{ AIndex はページの番号。見えていないタブは空の矩形。 }
function TCPageControl.TabRect(AIndex: Integer): TRect;
begin
  Result := Rect(0, 0, 0, 0);
  if (FStrip = nil) or (AIndex < 0) or (AIndex >= PageCount) then
    Exit;
  Result := FStrip.TabRectOf(Pages[AIndex]);
  if (Result.Right > Result.Left) then
    Types.OffsetRect(Result, FStrip.Left, FStrip.Top);
end;

procedure TCPageControl.EditPageCaption(APage: TCTabSheet);
begin
  if (APage = nil) or (IndexOf(APage) < 0) or not APage.TabVisible then
    Exit;
  if FStrip.IsEditing then
    DoEditCaptionConfirm(FStrip.EditText);
  FStrip.EnsureVisible(APage);
  FStrip.BeginEdit(APage);
end;

{ ---- 右クリックメニュー ---- }

procedure TCPageControl.ShowTabMenu(APage: TCTabSheet; const AScreenPos: TPoint);
var
  Item: TMenuItem;
  HasStd: Boolean;
begin
  FPopupPage := APage;
  if FMenu = nil then
    FMenu := TPopupMenu.Create(Self);
  FMenu.Items.Clear;
  HasStd := False;
  if tmiNew in FTabMenuItems then
  begin
    Item := TMenuItem.Create(FMenu);
    Item.Caption := rsCTabNew;
    Item.OnClick := @MenuNewClick;
    FMenu.Items.Add(Item);
    HasStd := True;
  end;
  if APage <> nil then
  begin
    if tmiClose in FTabMenuItems then
    begin
      Item := TMenuItem.Create(FMenu);
      Item.Caption := rsCTabClose;
      Item.OnClick := @MenuCloseClick;
      FMenu.Items.Add(Item);
      HasStd := True;
    end;
    if tmiRename in FTabMenuItems then
    begin
      Item := TMenuItem.Create(FMenu);
      Item.Caption := rsCTabRename;
      Item.OnClick := @MenuRenameClick;
      FMenu.Items.Add(Item);
      HasStd := True;
    end;
  end;
  if (FTabPopupMenu <> nil) and (FTabPopupMenu.Items.Count > 0) then
  begin
    // アプリが項目の状態を変えられるよう、元のメニューの OnPopup を先に呼ぶ
    if Assigned(FTabPopupMenu.OnPopup) then
      FTabPopupMenu.OnPopup(FTabPopupMenu);
    if HasStd then
    begin
      Item := TMenuItem.Create(FMenu);
      Item.Caption := cLineCaption;
      FMenu.Items.Add(Item);
    end;
    FMenu.Images := FTabPopupMenu.Images;
    CopyMenuItems(FTabPopupMenu.Items, FMenu.Items);
  end
  else
    FMenu.Images := nil;
  if FMenu.Items.Count = 0 then
    Exit;
  FMenu.PopupComponent := Self;
  FMenu.Popup(AScreenPos.X, AScreenPos.Y);
end;

{ アプリのメニューの写しを作る。写しを押すと、元の項目の Click を呼ぶ }
procedure TCPageControl.CopyMenuItems(ASource, ADest: TMenuItem);
var
  I: Integer;
  Src, Dst: TMenuItem;
begin
  for I := 0 to ASource.Count - 1 do
  begin
    Src := ASource.Items[I];
    Dst := TMenuItem.Create(FMenu);
    Dst.Caption := Src.Caption;
    Dst.Enabled := Src.Enabled;
    Dst.Visible := Src.Visible;
    Dst.Checked := Src.Checked;
    Dst.RadioItem := Src.RadioItem;
    Dst.GroupIndex := Src.GroupIndex;
    Dst.ImageIndex := Src.ImageIndex;
    Dst.ShortCut := Src.ShortCut;
    Dst.Hint := Src.Hint;
    Dst.Default := Src.Default;
    Dst.Tag := PtrInt(Src);
    if Src.Count > 0 then
      CopyMenuItems(Src, Dst)
    else if not Src.IsLine then
      Dst.OnClick := @MenuAppItemClick;
    ADest.Add(Dst);
  end;
end;

procedure TCPageControl.MenuNewClick(Sender: TObject);
begin
  DoMenuNewClick;
end;

procedure TCPageControl.MenuCloseClick(Sender: TObject);
begin
  DoMenuCloseClick(FPopupPage);
end;

procedure TCPageControl.MenuRenameClick(Sender: TObject);
begin
  DoMenuRenameClick(FPopupPage);
end;

procedure TCPageControl.MenuAppItemClick(Sender: TObject);
begin
  DoAppMenuItemClick(TMenuItem(PtrInt(TMenuItem(Sender).Tag)), FPopupPage);
end;

{ ---- タブ一覧 ---- }

procedure TCPageControl.ShowTabList;
var
  R: TRect;
begin
  if csDesigning in ComponentState then
    Exit;
  if FListPopup = nil then
    FListPopup := TCTabListPopup.CreatePopup(Self);
  if FListPopup.Visible then
  begin
    TCTabListPopup(FListPopup).ClosePopup;
    Exit;
  end;
  R := FStrip.ListButtonScreenRect;
  TCTabListPopup(FListPopup).ShowAt(R.Right, R.Bottom);
end;

{ ---- キーボード ---- }

{ この TCPageControl が Ctrl+Tab を受けるか。フォーカスのある部品を含む TCPageControl を優先し、
  どれにも含まれないときは、フォームの中で最初の TCPageControl が受ける。 }
function TCPageControl.IsKeyTarget(AFocused: TObject): Boolean;
var
  F: TCustomForm;
  I: Integer;
  C: TComponent;
begin
  Result := False;
  if not (Visible and Enabled) then
    Exit;
  if not (AFocused is TControl) then
    Exit;
  F := GetParentForm(Self);
  if (F = nil) or (GetParentForm(TControl(AFocused)) <> F) then
    Exit;
  if ContainsControl(TControl(AFocused)) then
    Exit(True);
  // ほかの TCPageControl に含まれていれば、そちらが受ける
  C := TControl(AFocused);
  while C is TControl do
  begin
    if (C is TCPageControl) and (C <> Self) then
      Exit(False);
    C := TControl(C).Parent;
  end;
  for I := 0 to F.ComponentCount - 1 do
    if (F.Components[I] is TCPageControl) and TCPageControl(F.Components[I]).Visible then
      Exit(F.Components[I] = Self);
  Result := True;
end;

type
  TWinControlAccess = class(TWinControl);

{ キーの順番：Form.OnKeyDown（KeyPreview のとき）→ タブの切り替え → フォーカスのある部品 }
procedure TCPageControl.KeyDownBefore(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  F: TCustomForm;
  Pg: TCTabSheet;
  Fwd: Boolean;
begin
  if not (nboKeyboardTabSwitch in FOptions) then
    Exit;
  if (Key <> VK_TAB) or not ((Shift = [ssCtrl]) or (Shift = [ssCtrl, ssShift])) then
    Exit;
  if PageCount = 0 then
    Exit;
  if not IsKeyTarget(Sender) then
    Exit;
  F := GetParentForm(Self);
  // 1. Form.OnKeyDown を先に呼ぶ（LCL はこの後、Key が 0 なら何もしない）
  if (F <> nil) and F.KeyPreview then
  begin
    TWinControlAccess(TWinControl(F)).KeyDown(Key, Shift);
    if Key = 0 then
      Exit;
  end;
  // 2. タブの切り替え
  Fwd := not (ssShift in Shift);
  Pg := FindNextPage(ActivePage, Fwd, True);
  Key := 0;
  if (Pg <> nil) and (Pg <> ActivePage) then
    UserSelectPage(Pg);
end;

{ ---- 設計時 ---- }

procedure TCPageControl.CMDesignHitTest(var Message: TCMDesignHitTest);
var
  P: TPoint;
begin
  Message.Result := 0;
  if (FStrip = nil) or (FStrip.Parent <> Self) then
    Exit;
  P := Point(Message.XPos, Message.YPos);
  if PtInRect(FStrip.BoundsRect, P) and
    FStrip.DesignHitTest(Point(P.X - FStrip.Left, P.Y - FStrip.Top)) then
    Message.Result := 1;
end;

procedure TCPageControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (csDesigning in ComponentState) and (FStrip <> nil) and (FStrip.Parent = Self)
    and PtInRect(FStrip.BoundsRect, Point(X, Y)) then
  begin
    FStrip.DesignMouseDown(Button, Shift, Point(X - FStrip.Left, Y - FStrip.Top));
    Exit;
  end;
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TCPageControl.CMFontChanged(var Message: TLMessage);
begin
  inherited;
  PageChanged;
end;

procedure TCPageControl.CMColorChanged(var Message: TLMessage);
begin
  inherited;
  if FStrip <> nil then
    FStrip.Invalidate;
  Invalidate;
end;

procedure TCPageControl.DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
  const AXProportion, AYProportion: Double);
begin
  inherited DoAutoAdjustLayout(AMode, AXProportion, AYProportion);
  if AMode in [lapAutoAdjustWithoutHorizontalScrolling, lapAutoAdjustForDPI] then
  begin
    // TabHeight・TabWidth は LCL と同じく倍率に合わせる（TabMaxWidth は 96dpi 基準のまま）
    if TabHeightIsStored then
      FTabHeight := Round(FTabHeight * AYProportion);
    if TabWidthIsStored then
      FTabWidth := Round(FTabWidth * AXProportion);
    PageChanged;
  end;
end;

initialization
  RegisterClass(TCTabSheet);

end.
