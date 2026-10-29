{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ ============================================================================
  uCTitleBar  -  TCTitleBar（フォームのタイトルバーの代わりになるパネル）

  設計書: docs\TCPageControl_Design.md
  パッケージ: cx（実行時）

  ・フォームに直接置くと、実行時にフォームのウィンドウを横取りし（SetWindowSubclass）、
    Windows のタイトルバーを取り除いて、その位置に自分を置く（Windows のみ）。
  ・右端に、最小化・最大化・閉じるボタンを自分で描く。
  ・何も置いていない場所は、Windows のタイトルバーと同じ扱いにする
    （ドラッグで移動、ダブルクリックで最大化、右クリックでシステムメニュー）。
  ・Windows 以外では、通常のパネルとして動く（ボタンは出さない）。
  ============================================================================ }
unit uCTitleBar;

{$mode objfpc}{$H+}

interface

uses
  {$IFDEF WINDOWS}Windows,{$ENDIF} // Windows は先に書く（RECT・POINT が Types の Rect・Point を隠さないように）
  Classes, SysUtils, Types, Controls, ExtCtrls, Graphics, Forms, LCLType,
  LCLIntf, LMessages, LCLProc;

type
  { タイトルバーの子部品（TCPageControl のタブ列）に問い合わせるための interface。
    P はその部品のクライアント座標。True を返した場所は「空き部分」として扱う。 }
  ICTitleBarDragArea = interface
    ['{6B0F3D2E-8A41-4C77-9E35-2B7C1D5A9F10}']
    function IsDragArea(const P: TPoint): Boolean;
  end;

  { 設計時に、タイトルバーの子部品（タブ列）へクリックを渡すための interface。
    P はその部品のクライアント座標。 }
  ICTitleBarDesignHit = interface
    ['{0E7C5B61-3F2A-4D8B-A1C9-58D6E4F2B370}']
    function DesignHitTest(const P: TPoint): Boolean;
    procedure DesignMouseDown(Button: TMouseButton; Shift: TShiftState; const P: TPoint);
  end;

  { 最小化・最大化・閉じるボタンの種類 }
  TCTitleButton = (ctbNone, ctbMinimize, ctbMaximize, ctbClose);

  { ボタンの状態（BorderIcons ごとの表示） }
  TCTitleButtonState = (ctsHidden, ctsDisabled, ctsEnabled);

  { TCTitleBar }

  TCTitleBar = class(TCustomPanel)
  private
    FHooked: Boolean;            // フォームに組み込んでいるか
    FHookedForm: TCustomForm;    // 組み込んだフォーム
    FHookedFormWnd: HWND;        // 組み込んだフォームのウィンドウ
    FSelfHooked: Boolean;        // 自分のウィンドウを横取りしているか（WM_NCHITTEST 用）
    FFormActive: Boolean;        // フォームがアクティブか（ボタン・文字の色）
    FHotButton: TCTitleButton;   // マウスが乗っているボタン
    FDownButton: TCTitleButton;  // 押しているボタン
    FCaptionRect: TRect;         // キャプションを描く領域
    FAligning: Boolean;          // AlignControls の中か（再入を防ぐ）
    FCaptionWidthAtPaint: Integer;
    function ButtonWidth: Integer;
    function ButtonsWidth: Integer;
    function ButtonRect(AButton: TCTitleButton): TRect;
    function ButtonAt(const P: TPoint): TCTitleButton;
    function ButtonState(AButton: TCTitleButton): TCTitleButtonState;
    function DisplayCaption: string;
    function CaptionWidthFor(const AText: string): Integer;
    function FormIsMaximized: Boolean;
    function DragChildAt(const P: TPoint; out AChild: TControl): Boolean;
    procedure SetHotButton(AValue: TCTitleButton);
    procedure PaintButtons;
    procedure PaintCaption;
    procedure AsyncRealign(Data: PtrInt);
    procedure CMDesignHitTest(var Message: TCMDesignHitTest); message CM_DESIGNHITTEST;
    procedure CMTextChanged(var Message: TLMessage); message CM_TEXTCHANGED;
    procedure CMFontChanged(var Message: TLMessage); message CM_FONTCHANGED;
    procedure CMColorChanged(var Message: TLMessage); message CM_COLORCHANGED;
    {$IFDEF WINDOWS}
    procedure HookForm;
    procedure UnhookForm;
    function CanHookForm: Boolean;
    {$ENDIF}
  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure SetAlign(Value: TAlign); override;
    procedure SetParent(NewParent: TWinControl); override;
    procedure AdjustClientRect(var ARect: TRect); override;
    procedure AlignControls(AControl: TControl; var RemainingClientRect: TRect); override;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    { 以下は uCTitleBar 内のウィンドウ横取りの処理から呼ぶ（アプリからは使わない） }
    procedure FormActivated(AActive: Boolean);
    procedure FormCaptionChanged;
    procedure FormStateChanged;
    procedure SetMaxButtonHot(AHot: Boolean);
    procedure SetMaxButtonDown(ADown: Boolean);
    function MaxButtonScreenRect: TRect;
    function ScreenPointInSelf(const AScreen: TPoint): Boolean;
    function IsDragPointScreen(const AScreen: TPoint): Boolean;
    property Hooked: Boolean read FHooked;
  published
    property Align default alTop;
    property Anchors;
    property BevelInner;
    property BevelOuter default bvNone;
    property BevelWidth;
    property BorderSpacing;
    property Caption;
    property Color default clBtnFace;
    property Constraints;
    property Enabled;
    property Font;
    property ParentColor default False;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
  end;

{ タイトルバーの子部品（タブ列）が、自分のウィンドウの WM_NCHITTEST を横取りして、
  空き部分で HTTRANSPARENT を返すようにする。子部品の CreateWnd・DestroyWnd から呼ぶ。 }
procedure CTitleBarHookChild(AChild: TWinControl; AHook: Boolean);

{ 色を混ぜる（APercent は AMix の割合 0～100）。タブ列の描画でも使う。 }
function CXBlendColor(ABase, AMix: TColor; APercent: Integer): TColor;

{ 記号の字（Segoe Fluent Icons、無ければ Segoe MDL2 Assets、どちらも無ければ ''） }
function CXSymbolFontName: string;

{ Unicode の記号 1 文字を UTF-8 の文字列にする }
function CXSymbol(ACode: Cardinal): string;

{ 記号を描く字を Canvas に設定する。部品の Font（大きさ・名前）を引き継がないよう、
  新しい TFont に名前と高さ（ピクセル）だけを入れてから写す。 }
procedure CXSetSymbolFont(ACanvas: TCanvas; const AName: string; AHeightPx: Integer; AColor: TColor);

{ 96dpi 基準の大きさを、部品のあるフォームの倍率に合わせる。フォームにまだ置かれていない
  （.lfm の読み込み中など）ときは、画面の倍率を使う（Scale96ToForm はそのとき例外になるため）。 }
function CXScale96(AControl: TControl; ASize: Integer): Integer;

resourcestring
  rsCTitleBarOnlyOne = 'TCTitleBar は1つのフォームに1つだけ置けます';

implementation

uses
  {$IFDEF WINDOWS}ShellApi,{$ENDIF}
  LazUTF8;

const
  // 96dpi 時の大きさ
  CTB_BUTTON_W   = 46;   // ボタン 1 つの幅
  CTB_CAPTION_PAD = 8;   // キャプションの左右の余白
  CTB_CAPTION_MAX = 200; // キャプションの最大幅
  CTB_SYMBOL_H   = 10;   // 記号の字の高さ
  CTB_DEFAULT_H  = 40;   // 既定の高さ

  // 記号の字のコード
  SYM_MINIMIZE = $E921;
  SYM_MAXIMIZE = $E922;
  SYM_RESTORE  = $E923;
  SYM_CLOSE    = $E8BB;

  CLOSE_HOT_COLOR = TColor($1C2BC4);  // #C42B1C（BGR で書く）

var
  GSymbolFontName: string = '';
  GSymbolFontChecked: Boolean = False;

function CXBlendColor(ABase, AMix: TColor; APercent: Integer): TColor;
var
  B, M: TColorRef;
  R, G, Bl: Integer;
begin
  B := ColorToRGB(ABase);
  M := ColorToRGB(AMix);
  R  := (Red(B)   * (100 - APercent) + Red(M)   * APercent) div 100;
  G  := (Green(B) * (100 - APercent) + Green(M) * APercent) div 100;
  Bl := (Blue(B)  * (100 - APercent) + Blue(M)  * APercent) div 100;
  Result := RGBToColor(R, G, Bl);
end;

function CXSymbolFontName: string;
begin
  if not GSymbolFontChecked then
  begin
    GSymbolFontChecked := True;
    GSymbolFontName := '';
    if Screen.Fonts.IndexOf('Segoe Fluent Icons') >= 0 then
      GSymbolFontName := 'Segoe Fluent Icons'
    else if Screen.Fonts.IndexOf('Segoe MDL2 Assets') >= 0 then
      GSymbolFontName := 'Segoe MDL2 Assets';
  end;
  Result := GSymbolFontName;
end;

function CXSymbol(ACode: Cardinal): string;
begin
  Result := UnicodeToUTF8(ACode);
end;

procedure CXSetSymbolFont(ACanvas: TCanvas; const AName: string; AHeightPx: Integer; AColor: TColor);
var
  F: TFont;
begin
  F := TFont.Create;
  try
    F.Name := AName;
    F.Style := [];
    F.Height := -AHeightPx;
    F.Color := AColor;
    ACanvas.Font.Assign(F);
  finally
    F.Free;
  end;
end;

function CXScale96(AControl: TControl; ASize: Integer): Integer;
var
  F: TCustomDesignControl;
begin
  F := nil;
  if AControl <> nil then
    F := GetParentDesignControl(AControl);
  if F <> nil then
    Result := MulDiv(ASize, F.PixelsPerInch, 96)
  else
    Result := MulDiv(ASize, Screen.PixelsPerInch, 96);
end;

{ ===========================================================================
  Windows のウィンドウ横取り
  =========================================================================== }
{$IFDEF WINDOWS}
type
  TSubclassProc = function(AWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM;
    uIdSubclass: UINT_PTR; dwRefData: DWORD_PTR): LRESULT; stdcall;
  TSetWindowSubclass = function(AWnd: HWND; pfnSubclass: TSubclassProc;
    uIdSubclass: UINT_PTR; dwRefData: DWORD_PTR): BOOL; stdcall;
  TRemoveWindowSubclass = function(AWnd: HWND; pfnSubclass: TSubclassProc;
    uIdSubclass: UINT_PTR): BOOL; stdcall;
  TDefSubclassProc = function(AWnd: HWND; uMsg: UINT; wParam: WPARAM;
    lParam: LPARAM): LRESULT; stdcall;
  TGetSystemMetricsForDpi = function(nIndex: Integer; dpi: UINT): Integer; stdcall;
  TGetDpiForWindow = function(AWnd: HWND): UINT; stdcall;

const
  SUBCLASS_ID_FORM  = $43544246; // 'CTBF'
  SUBCLASS_ID_SELF  = $43544253; // 'CTBS'
  SUBCLASS_ID_CHILD = $43544243; // 'CTBC'
  SM_CXPADDEDBORDER_ = 92;
  WM_NCMOUSELEAVE_ = $02A2;
  TME_NONCLIENT_ = $00000010;
  ABM_GETAUTOHIDEBAREX_ = $0000000B;

var
  GComCtl: HMODULE = 0;
  GUser32: HMODULE = 0;
  pSetWindowSubclass: TSetWindowSubclass = nil;
  pRemoveWindowSubclass: TRemoveWindowSubclass = nil;
  pDefSubclassProc: TDefSubclassProc = nil;
  pGetSystemMetricsForDpi: TGetSystemMetricsForDpi = nil;
  pGetDpiForWindow: TGetDpiForWindow = nil;
  GApiLoaded: Boolean = False;

{ comctl32 の SetWindowSubclass などを読み込む。名前で見つからなければ番号で探す。 }
function LoadSubclassApi: Boolean;
begin
  if not GApiLoaded then
  begin
    GApiLoaded := True;
    GComCtl := GetModuleHandle('comctl32.dll');
    if GComCtl = 0 then
      GComCtl := LoadLibrary('comctl32.dll');
    if GComCtl <> 0 then
    begin
      Pointer(pSetWindowSubclass) := GetProcAddress(GComCtl, 'SetWindowSubclass');
      if not Assigned(pSetWindowSubclass) then
        Pointer(pSetWindowSubclass) := GetProcAddress(GComCtl, PChar(PtrUInt(410)));
      Pointer(pRemoveWindowSubclass) := GetProcAddress(GComCtl, 'RemoveWindowSubclass');
      if not Assigned(pRemoveWindowSubclass) then
        Pointer(pRemoveWindowSubclass) := GetProcAddress(GComCtl, PChar(PtrUInt(412)));
      Pointer(pDefSubclassProc) := GetProcAddress(GComCtl, 'DefSubclassProc');
      if not Assigned(pDefSubclassProc) then
        Pointer(pDefSubclassProc) := GetProcAddress(GComCtl, PChar(PtrUInt(413)));
    end;
    GUser32 := GetModuleHandle('user32.dll');
    if GUser32 <> 0 then
    begin
      Pointer(pGetSystemMetricsForDpi) := GetProcAddress(GUser32, 'GetSystemMetricsForDpi');
      Pointer(pGetDpiForWindow) := GetProcAddress(GUser32, 'GetDpiForWindow');
    end;
  end;
  Result := Assigned(pSetWindowSubclass) and Assigned(pRemoveWindowSubclass)
    and Assigned(pDefSubclassProc);
end;

function WindowDpi(AWnd: HWND): UINT;
var
  DC: HDC;
begin
  Result := 0;
  if Assigned(pGetDpiForWindow) then
    Result := pGetDpiForWindow(AWnd);
  if Result = 0 then
  begin
    DC := GetDC(0);
    Result := GetDeviceCaps(DC, LOGPIXELSY);
    ReleaseDC(0, DC);
  end;
end;

function MetricForDpi(AIndex: Integer; ADpi: UINT): Integer;
begin
  if Assigned(pGetSystemMetricsForDpi) then
    Result := pGetSystemMetricsForDpi(AIndex, ADpi)
  else
    Result := GetSystemMetrics(AIndex);
end;

{ 枠の太さ（SM_CYFRAME＋SM_CXPADDEDBORDER）。最大化中の補正と、上端のサイズ変更の範囲に使う。 }
function FrameThickness(AWnd: HWND): Integer;
var
  Dpi: UINT;
begin
  Dpi := WindowDpi(AWnd);
  Result := MetricForDpi(SM_CYFRAME, Dpi) + MetricForDpi(SM_CXPADDEDBORDER_, Dpi);
end;

{ タスクバーを自動的に隠す設定のとき、最大化中にタスクバーを出せるよう、その辺を 1px 空ける。 }
procedure AdjustForAutoHideTaskbar(AWnd: HWND; var R: TRect);
var
  ABD: TAppBarData;
  Mon: HMONITOR;
  MI: TMonitorInfo;
  Edge: UINT;
begin
  FillChar(ABD, SizeOf(ABD), 0);
  ABD.cbSize := SizeOf(ABD);
  if (SHAppBarMessage(ABM_GETSTATE, @ABD) and ABS_AUTOHIDE) = 0 then
    Exit;
  Mon := MonitorFromWindow(AWnd, MONITOR_DEFAULTTONEAREST);
  FillChar(MI, SizeOf(MI), 0);
  MI.cbSize := SizeOf(MI);
  if not GetMonitorInfo(Mon, @MI) then
    Exit;
  for Edge := ABE_LEFT to ABE_BOTTOM do
  begin
    FillChar(ABD, SizeOf(ABD), 0);
    ABD.cbSize := SizeOf(ABD);
    ABD.uEdge := Edge;
    ABD.rc := MI.rcMonitor;
    if SHAppBarMessage(ABM_GETAUTOHIDEBAREX_, @ABD) <> 0 then
      case Edge of
        ABE_LEFT:   Inc(R.Left);
        ABE_TOP:    Inc(R.Top);
        ABE_RIGHT:  Dec(R.Right);
        ABE_BOTTOM: Dec(R.Bottom);
      end;
  end;
end;

{ 枠を計算し直させ、中身（クライアント領域）の大きさが変わったことを LCL に知らせる。
  SWP_FRAMECHANGED だけではウィンドウの大きさが変わらないため WM_SIZE が届かず、
  LCL が前の大きさのまま部品を並べて、下に余白が残る。 }
procedure FrameChanged(AWnd: HWND; AForm: TCustomForm);
var
  R: TRect;
  Kind: WPARAM;
begin
  SetWindowPos(AWnd, 0, 0, 0, 0, 0, SWP_FRAMECHANGED or SWP_NOMOVE or
    SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE);
  if (AForm = nil) or (csDestroying in AForm.ComponentState) then
    Exit;
  Windows.GetClientRect(AWnd, R);
  if IsZoomed(AWnd) then
    Kind := SIZE_MAXIMIZED
  else if IsIconic(AWnd) then
    Exit
  else
    Kind := SIZE_RESTORED;
  AForm.InvalidateClientRectCache(True);
  SendMessage(AWnd, WM_SIZE, Kind, MAKELPARAM(R.Right - R.Left, R.Bottom - R.Top));
  AForm.ReAlign;
end;

{ LCL が塗らない部分（Height より下・Width より右）を、フォームの色で塗る }
procedure FillFormRemainder(ADC: HDC; AWnd: HWND; AForm: TCustomForm);
var
  CR, R: TRect;
  Br: HBRUSH;
begin
  if csDestroying in AForm.ComponentState then
    Exit;
  Windows.GetClientRect(AWnd, CR);
  Br := HBRUSH(AForm.Brush.Reference.Handle);
  if CR.Bottom > AForm.Height then
  begin
    R := Rect(0, AForm.Height, CR.Right, CR.Bottom);
    Windows.FillRect(ADC, R, Br);
  end;
  if CR.Right > AForm.Width then
  begin
    R := Rect(AForm.Width, 0, CR.Right, CR.Bottom);
    Windows.FillRect(ADC, R, Br);
  end;
end;

function LParamToScreenPoint(L: LPARAM): TPoint;
begin
  Result.X := SmallInt(L and $FFFF);
  Result.Y := SmallInt((L shr 16) and $FFFF);
end;

{ フォームのウィンドウの横取り }
function FormSubclassProc(AWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM;
  uIdSubclass: UINT_PTR; dwRefData: DWORD_PTR): LRESULT; stdcall;
var
  Bar: TCTitleBar;
  Params: PNCCalcSizeParams;
  SaveTop: LongInt;
  P, LocalP: TPoint;
  Frame: Integer;
  BarRect: TRect;
  TME: TTrackMouseEvent;
  Other: HWND;
begin
  Bar := TCTitleBar(Pointer(dwRefData));
  case uMsg of
    WM_NCCALCSIZE:
      if wParam <> 0 then
      begin
        // 標準の計算をした後、上端を元の位置に戻す（タイトルバーの分を取り除き、左右下の枠は残す）
        Params := PNCCalcSizeParams(lParam);
        SaveTop := Params^.rgrc[0].Top;
        Result := pDefSubclassProc(AWnd, uMsg, wParam, lParam);
        Params^.rgrc[0].Top := SaveTop;
        if IsZoomed(AWnd) then
        begin
          // 最大化中は画面の外にはみ出す分（枠の太さ）だけ内側にする
          Inc(Params^.rgrc[0].Top, FrameThickness(AWnd));
          AdjustForAutoHideTaskbar(AWnd, Params^.rgrc[0]);
        end;
        Exit;
      end;

    WM_NCHITTEST:
      begin
        Result := pDefSubclassProc(AWnd, uMsg, wParam, lParam);
        // 左右下の枠などは標準の判定のまま
        if Result <> HTCLIENT then
          Exit;
        P := LParamToScreenPoint(lParam);
        if not Bar.ScreenPointInSelf(P) then
          Exit;
        // ここに来るのは、タイトルバー（またはタブ列）が HTTRANSPARENT を返した場所
        LocalP := Bar.ScreenToClient(P);
        if (not IsZoomed(AWnd)) and (Bar.FHookedForm.BorderStyle = bsSizeable) then
        begin
          Frame := FrameThickness(AWnd);
          if LocalP.Y < Frame then
          begin
            if LocalP.X < Frame * 2 then
              Exit(HTTOPLEFT)
            else if LocalP.X >= Bar.ClientWidth - Frame * 2 then
              Exit(HTTOPRIGHT)
            else
              Exit(HTTOP);
          end;
        end;
        BarRect := Bar.MaxButtonScreenRect;
        if (Bar.ButtonState(ctbMaximize) = ctsEnabled) and PtInRect(BarRect, P) then
          Exit(HTMAXBUTTON);
        Exit(HTCAPTION);
      end;

    WM_NCMOUSEMOVE:
      begin
        Bar.SetMaxButtonHot(wParam = HTMAXBUTTON);
        if wParam = HTMAXBUTTON then
        begin
          FillChar(TME, SizeOf(TME), 0);
          TME.cbSize := SizeOf(TME);
          TME.dwFlags := TME_LEAVE or TME_NONCLIENT_;
          TME.hwndTrack := AWnd;
          TrackMouseEvent(TME);
        end;
      end;

    WM_NCMOUSELEAVE_:
      begin
        Bar.SetMaxButtonHot(False);
        Bar.SetMaxButtonDown(False);
      end;

    WM_NCLBUTTONDOWN, WM_NCLBUTTONDBLCLK:
      if wParam = HTMAXBUTTON then
      begin
        // 標準の処理に渡さない（旧式のボタンが描かれるため）。自分で押した表示をする。
        Bar.SetMaxButtonDown(True);
        Exit(0);
      end;

    WM_NCLBUTTONUP:
      if wParam = HTMAXBUTTON then
      begin
        if Bar.FDownButton = ctbMaximize then
        begin
          Bar.SetMaxButtonDown(False);
          if IsZoomed(AWnd) then
            PostMessage(AWnd, WM_SYSCOMMAND, SC_RESTORE, 0)
          else
            PostMessage(AWnd, WM_SYSCOMMAND, SC_MAXIMIZE, 0);
        end;
        Exit(0);
      end
      else
        Bar.SetMaxButtonDown(False);

    WM_ACTIVATE:
      begin
        Result := pDefSubclassProc(AWnd, uMsg, wParam, lParam);
        if LoWord(wParam) = WA_INACTIVE then
        begin
          // フォームが持ち主になっている窓（タブ一覧など）へ移ったときは、アクティブのままに見せる
          Other := HWND(lParam);
          Bar.FormActivated((Other <> 0) and (GetWindow(Other, GW_OWNER) = AWnd));
        end
        else
          Bar.FormActivated(True);
        Exit;
      end;

    WM_SIZE:
      begin
        Result := pDefSubclassProc(AWnd, uMsg, wParam, lParam);
        Bar.FormStateChanged;
        Exit;
      end;

    WM_SETTEXT:
      begin
        Result := pDefSubclassProc(AWnd, uMsg, wParam, lParam);
        Bar.FormCaptionChanged;
        Exit;
      end;

    WM_ERASEBKGND:
      begin
        // LCL はフォームの背景を Rect(0, 0, Width, Height) だけ塗る。LCL の Height は
        // 「ウィンドウの高さ − 標準のタイトルバーと枠」なので、タイトルバーを取り除いた分だけ
        // 中身より小さく、下に塗られない帯が残る。LCL が塗った後に、残りをフォームの色で塗り足す。
        Result := pDefSubclassProc(AWnd, uMsg, wParam, lParam);
        if (Bar.FHookedForm <> nil) and (wParam <> 0) then
          FillFormRemainder(HDC(wParam), AWnd, Bar.FHookedForm);
        Exit;
      end;

    $02E0 {WM_DPICHANGED}:
      begin
        Result := pDefSubclassProc(AWnd, uMsg, wParam, lParam);
        FrameChanged(AWnd, Bar.FHookedForm);
        Exit;
      end;

    WM_NCDESTROY:
      begin
        pRemoveWindowSubclass(AWnd, @uCTitleBar.FormSubclassProc, uIdSubclass);
        Bar.FHooked := False;
        Bar.FHookedFormWnd := 0;
      end;
  end;
  Result := pDefSubclassProc(AWnd, uMsg, wParam, lParam);
end;

{ タイトルバー自身のウィンドウの横取り。空き部分で HTTRANSPARENT を返し、フォームに判定を任せる。 }
function SelfSubclassProc(AWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM;
  uIdSubclass: UINT_PTR; dwRefData: DWORD_PTR): LRESULT; stdcall;
var
  Bar: TCTitleBar;
begin
  Bar := TCTitleBar(Pointer(dwRefData));
  case uMsg of
    WM_NCHITTEST:
      if Bar.FHooked then
      begin
        if Bar.IsDragPointScreen(LParamToScreenPoint(lParam)) then
          Exit(HTTRANSPARENT);
        Exit(HTCLIENT);
      end;
    WM_NCDESTROY:
      begin
        pRemoveWindowSubclass(AWnd, @uCTitleBar.SelfSubclassProc, uIdSubclass);
        Bar.FSelfHooked := False;
      end;
  end;
  Result := pDefSubclassProc(AWnd, uMsg, wParam, lParam);
end;

{ タイトルバーの子部品（タブ列）のウィンドウの横取り }
function ChildSubclassProc(AWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM;
  uIdSubclass: UINT_PTR; dwRefData: DWORD_PTR): LRESULT; stdcall;
var
  Child: TWinControl;
  Area: ICTitleBarDragArea;
  P: TPoint;
begin
  Child := TWinControl(Pointer(dwRefData));
  case uMsg of
    WM_NCHITTEST:
      if (Child.Parent is TCTitleBar) and TCTitleBar(Child.Parent).Hooked
        and Supports(Child, ICTitleBarDragArea, Area) then
      begin
        P := Child.ScreenToClient(LParamToScreenPoint(lParam));
        if Area.IsDragArea(P) then
          Exit(HTTRANSPARENT);
      end;
    WM_NCDESTROY:
      pRemoveWindowSubclass(AWnd, @uCTitleBar.ChildSubclassProc, uIdSubclass);
  end;
  Result := pDefSubclassProc(AWnd, uMsg, wParam, lParam);
end;
{$ENDIF}

procedure CTitleBarHookChild(AChild: TWinControl; AHook: Boolean);
begin
  {$IFDEF WINDOWS}
  if (AChild = nil) or (csDesigning in AChild.ComponentState) then
    Exit;
  if not AChild.HandleAllocated then
    Exit;
  if not LoadSubclassApi then
    Exit;
  if AHook then
    pSetWindowSubclass(AChild.Handle, @ChildSubclassProc, SUBCLASS_ID_CHILD,
      DWORD_PTR(Pointer(AChild)))
  else
    pRemoveWindowSubclass(AChild.Handle, @ChildSubclassProc, SUBCLASS_ID_CHILD);
  {$ENDIF}
end;

{ ===========================================================================
  TCTitleBar
  =========================================================================== }

constructor TCTitleBar.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  ControlStyle := ControlStyle + [csAcceptsControls] - [csSetCaption];
  inherited Align := alTop;
  BevelOuter := bvNone;
  Color := clBtnFace;
  ParentColor := False;
  FFormActive := True;
  FHotButton := ctbNone;
  FDownButton := ctbNone;
  Caption := '';
  with GetControlClassDefaultSize do
    SetInitialBounds(0, 0, CX, CY);
end;

destructor TCTitleBar.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  inherited Destroy;
end;

class function TCTitleBar.GetControlClassDefaultSize: TSize;
begin
  Result.CX := 300;
  Result.CY := CTB_DEFAULT_H;
end;

procedure TCTitleBar.SetAlign(Value: TAlign);
begin
  // alTop に固定
  inherited SetAlign(alTop);
end;

{ ボタン 1 つの幅（96dpi で 46） }
function TCTitleBar.ButtonWidth: Integer;
begin
  Result := CXScale96(Self, CTB_BUTTON_W);
end;

{ 右端のボタン領域の幅。Windows 以外、または biSystemMenu が無いときは 0。 }
function TCTitleBar.ButtonsWidth: Integer;
var
  B: TCTitleButton;
  N: Integer;
begin
  Result := 0;
  {$IFDEF WINDOWS}
  N := 0;
  for B := ctbMinimize to ctbClose do
    if ButtonState(B) <> ctsHidden then
      Inc(N);
  Result := N * ButtonWidth;
  {$ENDIF}
end;

{ ボタンの状態（の表） }
function TCTitleBar.ButtonState(AButton: TCTitleButton): TCTitleButtonState;
var
  F: TCustomForm;
  Icons: TBorderIcons;
begin
  Result := ctsHidden;
  {$IFDEF WINDOWS}
  F := GetParentForm(Self);
  if (F = nil) or (Parent <> F) then
    Exit;
  if not (FHooked or (csDesigning in ComponentState)) then
    Exit;
  Icons := F.BorderIcons;
  if not (biSystemMenu in Icons) then
    Exit;
  case AButton of
    ctbClose:
      Result := ctsEnabled;
    ctbMinimize, ctbMaximize:
      begin
        if not ((biMinimize in Icons) or (biMaximize in Icons)) then
          Exit(ctsHidden);
        if (AButton = ctbMinimize) and (biMinimize in Icons) then
          Result := ctsEnabled
        else if (AButton = ctbMaximize) and (biMaximize in Icons) then
          Result := ctsEnabled
        else
          Result := ctsDisabled;
      end;
  end;
  {$ENDIF}
end;

{ ボタンの位置（自分のクライアント座標）。右から 閉じる・最大化・最小化 の順。 }
function TCTitleBar.ButtonRect(AButton: TCTitleButton): TRect;
var
  B: TCTitleButton;
  X: Integer;
begin
  Result := Rect(0, 0, 0, 0);
  if ButtonState(AButton) = ctsHidden then
    Exit;
  X := ClientWidth;
  for B := ctbClose downto ctbMinimize do
  begin
    if ButtonState(B) = ctsHidden then
      Continue;
    if B = AButton then
      Exit(Rect(X - ButtonWidth, 0, X, ClientHeight));
    Dec(X, ButtonWidth);
  end;
end;

function TCTitleBar.ButtonAt(const P: TPoint): TCTitleButton;
var
  B: TCTitleButton;
begin
  Result := ctbNone;
  for B := ctbMinimize to ctbClose do
    if (ButtonState(B) <> ctsHidden) and PtInRect(ButtonRect(B), P) then
      Exit(B);
end;

function TCTitleBar.MaxButtonScreenRect: TRect;
var
  R: TRect;
begin
  R := ButtonRect(ctbMaximize);
  Result.TopLeft := ClientToScreen(R.TopLeft);
  Result.BottomRight := ClientToScreen(R.BottomRight);
end;

function TCTitleBar.ScreenPointInSelf(const AScreen: TPoint): Boolean;
var
  P: TPoint;
begin
  P := ScreenToClient(AScreen);
  Result := PtInRect(Rect(0, 0, Width, Height), P);
end;

{ その点が「空き部分」か。ボタン（最大化を除く）と、ウィンドウを持たない子部品の上は False。
  最大化ボタンは True（フォームが HTMAXBUTTON を返す）。無効の最大化ボタンは False。 }
function TCTitleBar.IsDragPointScreen(const AScreen: TPoint): Boolean;
var
  P: TPoint;
  B: TCTitleButton;
  C: TControl;
begin
  P := ScreenToClient(AScreen);
  B := ButtonAt(P);
  if B = ctbMaximize then
    Exit(ButtonState(ctbMaximize) = ctsEnabled);
  if B <> ctbNone then
    Exit(False);
  if DragChildAt(P, C) then
    Exit(True);
  Result := C = nil;
end;

{ P にある子部品を探す。ウィンドウを持たない子部品があれば AChild に返して False。
  タブ列（ICTitleBarDragArea）なら、その判定を返す。 }
function TCTitleBar.DragChildAt(const P: TPoint; out AChild: TControl): Boolean;
var
  I: Integer;
  C: TControl;
  Area: ICTitleBarDragArea;
begin
  Result := False;
  AChild := nil;
  for I := ControlCount - 1 downto 0 do
  begin
    C := Controls[I];
    if not C.Visible then
      Continue;
    if not PtInRect(C.BoundsRect, P) then
      Continue;
    if Supports(C, ICTitleBarDragArea, Area) then
    begin
      Result := Area.IsDragArea(Point(P.X - C.Left, P.Y - C.Top));
      if not Result then
        AChild := C;
      Exit;
    end;
    AChild := C;
    Exit;
  end;
end;

function TCTitleBar.FormIsMaximized: Boolean;
var
  F: TCustomForm;
begin
  F := GetParentForm(Self);
  {$IFDEF WINDOWS}
  if (F <> nil) and F.HandleAllocated then
    Exit(IsZoomed(F.Handle));
  {$ENDIF}
  Result := (F <> nil) and (F.WindowState = wsMaximized);
end;

{ 表示するキャプション。Caption が空ならフォームの Caption。 }
function TCTitleBar.DisplayCaption: string;
var
  F: TCustomForm;
begin
  Result := Caption;
  if Result = '' then
  begin
    F := GetParentForm(Self);
    if (F <> nil) and (Parent = F) then
      Result := F.Caption;
  end;
end;

{ キャプションの幅。文字の幅＋左右の余白。上限 200。文字が無ければ 0。 }
function TCTitleBar.CaptionWidthFor(const AText: string): Integer;
var
  Bmp: TBitmap;
  TW: Integer;
begin
  if AText = '' then
    Exit(0);
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(1, 1);
    Bmp.Canvas.Font.Assign(Font);
    TW := Bmp.Canvas.TextWidth(AText);
  finally
    Bmp.Free;
  end;
  Result := TW + CXScale96(Self, CTB_CAPTION_PAD) * 2;
  if Result > CXScale96(Self, CTB_CAPTION_MAX) then
    Result := CXScale96(Self, CTB_CAPTION_MAX);
end;

procedure TCTitleBar.AdjustClientRect(var ARect: TRect);
begin
  inherited AdjustClientRect(ARect);
  // 右端のボタン領域を除く（alRight の部品はその左に並ぶ）
  Dec(ARect.Right, ButtonsWidth);
  if ARect.Right < ARect.Left then
    ARect.Right := ARect.Left;
end;

{ 子部品の配置。alLeft・alRight の部品を並べた後、残りにキャプションとタブ列を置く。 }
procedure TCTitleBar.AlignControls(AControl: TControl; var RemainingClientRect: TRect);
var
  CapW, I: Integer;
  C: TControl;
  Area: ICTitleBarDragArea;
  StripRect: TRect;
begin
  inherited AlignControls(AControl, RemainingClientRect);
  if FAligning then
    Exit;
  FAligning := True;
  try
    CapW := CaptionWidthFor(DisplayCaption);
    FCaptionWidthAtPaint := CapW;
    FCaptionRect := Rect(RemainingClientRect.Left, 0,
      RemainingClientRect.Left + CapW, ClientHeight);
    if FCaptionRect.Right > RemainingClientRect.Right then
      FCaptionRect.Right := RemainingClientRect.Right;
    StripRect := Rect(FCaptionRect.Right, 0, RemainingClientRect.Right, ClientHeight);
    if StripRect.Right < StripRect.Left then
      StripRect.Right := StripRect.Left;
    for I := 0 to ControlCount - 1 do
    begin
      C := Controls[I];
      if Supports(C, ICTitleBarDragArea, Area) then
        C.SetBounds(StripRect.Left, StripRect.Top,
          StripRect.Right - StripRect.Left, StripRect.Bottom - StripRect.Top);
    end;
  finally
    FAligning := False;
  end;
  Invalidate;
end;

procedure TCTitleBar.AsyncRealign(Data: PtrInt);
begin
  ReAlign;
  Invalidate;
end;

procedure TCTitleBar.PaintCaption;
var
  R: TRect;
  TS: TTextStyle;
  S: string;
begin
  S := DisplayCaption;
  if S = '' then
    Exit;
  // 設計時はフォームの Caption の変更が届かないので、描くたびに幅を確かめる
  if CaptionWidthFor(S) <> FCaptionWidthAtPaint then
    Application.QueueAsyncCall(@AsyncRealign, 0);
  R := FCaptionRect;
  InflateRect(R, -CXScale96(Self, CTB_CAPTION_PAD), 0);
  if R.Right <= R.Left then
    Exit;
  Canvas.Font.Assign(Font);
  if not (FFormActive or (csDesigning in ComponentState)) then
    Canvas.Font.Color := clGrayText
  else if (Font.Color = clDefault) or (Font.Color = clWindowText) then
    Canvas.Font.Color := clBtnText;
  TS := Canvas.TextStyle;
  TS.Alignment := taLeftJustify;
  TS.Layout := tlCenter;
  TS.SingleLine := True;
  TS.EndEllipsis := True;
  TS.Clipping := True;
  TS.Opaque := False;
  Canvas.Brush.Style := bsClear;
  Canvas.TextRect(R, R.Left, R.Top, S, TS);
end;

procedure TCTitleBar.PaintButtons;
var
  B: TCTitleButton;
  R: TRect;
  St: TCTitleButtonState;
  Bg, Fg: TColor;
  Code: Cardinal;
  FontName: string;
  TS: TTextStyle;
  Sz, CX, CY: Integer;
begin
  FontName := CXSymbolFontName;
  for B := ctbMinimize to ctbClose do
  begin
    St := ButtonState(B);
    if St = ctsHidden then
      Continue;
    R := ButtonRect(B);
    Bg := clNone;
    Fg := clBtnText;
    if not (FFormActive and not (csDesigning in ComponentState)) then
      Fg := clGrayText;
    if St = ctsDisabled then
      Fg := clGrayText
    else if not (csDesigning in ComponentState) then
    begin
      if B = ctbClose then
      begin
        if FDownButton = B then
        begin
          Bg := CXBlendColor(CLOSE_HOT_COLOR, clBlack, 20);
          Fg := clWhite;
        end
        else if FHotButton = B then
        begin
          Bg := CLOSE_HOT_COLOR;
          Fg := clWhite;
        end;
      end
      else if FDownButton = B then
        Bg := CXBlendColor(Color, clBtnText, 20)
      else if FHotButton = B then
        Bg := CXBlendColor(Color, clBtnText, 10);
    end;
    if Bg <> clNone then
    begin
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := Bg;
      Canvas.FillRect(R);
    end;
    case B of
      ctbMinimize: Code := SYM_MINIMIZE;
      ctbMaximize:
        if FormIsMaximized then Code := SYM_RESTORE else Code := SYM_MAXIMIZE;
    else
      Code := SYM_CLOSE;
    end;
    if FontName <> '' then
    begin
      CXSetSymbolFont(Canvas, FontName, CXScale96(Self, CTB_SYMBOL_H), Fg);
      TS := Canvas.TextStyle;
      TS.Alignment := taCenter;
      TS.Layout := tlCenter;
      TS.SingleLine := True;
      TS.Opaque := False;
      TS.Clipping := True;
      Canvas.Brush.Style := bsClear;
      Canvas.TextRect(R, R.Left, R.Top, CXSymbol(Code), TS);
    end
    else
    begin
      // 記号の字が無いときは線で描く
      Sz := CXScale96(Self, CTB_SYMBOL_H) div 2;
      CX := (R.Left + R.Right) div 2;
      CY := (R.Top + R.Bottom) div 2;
      Canvas.Pen.Color := Fg;
      Canvas.Pen.Width := 1;
      case B of
        ctbMinimize:
          Canvas.Line(CX - Sz, CY, CX + Sz, CY);
        ctbMaximize:
          begin
            Canvas.Brush.Style := bsClear;
            Canvas.Rectangle(CX - Sz, CY - Sz, CX + Sz, CY + Sz);
          end;
      else
        Canvas.Line(CX - Sz, CY - Sz, CX + Sz, CY + Sz);
        Canvas.Line(CX - Sz, CY + Sz - 1, CX + Sz, CY - Sz - 1);
      end;
    end;
  end;
end;

procedure TCTitleBar.Paint;
var
  R: TRect;
begin
  R := ClientRect;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(R);
  if BevelOuter <> bvNone then
    Canvas.Frame3D(R, BevelWidth, BevelOuter);
  PaintCaption;
  PaintButtons;
end;

procedure TCTitleBar.SetHotButton(AValue: TCTitleButton);
begin
  if FHotButton = AValue then
    Exit;
  FHotButton := AValue;
  Invalidate;
end;

procedure TCTitleBar.SetMaxButtonHot(AHot: Boolean);
begin
  if AHot then
    SetHotButton(ctbMaximize)
  else if FHotButton = ctbMaximize then
    SetHotButton(ctbNone);
end;

procedure TCTitleBar.SetMaxButtonDown(ADown: Boolean);
begin
  if ADown then
  begin
    if FDownButton <> ctbMaximize then
    begin
      FDownButton := ctbMaximize;
      Invalidate;
    end;
  end
  else if FDownButton = ctbMaximize then
  begin
    FDownButton := ctbNone;
    Invalidate;
  end;
end;

{ 最小化・閉じるボタンのマウス操作 }
procedure TCTitleBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  B: TCTitleButton;
  Area: ICTitleBarDesignHit;
  I: Integer;
  C: TControl;
  P: TPoint;
begin
  if csDesigning in ComponentState then
  begin
    // 設計時：タブ列にクリックを渡す
    P := Point(X, Y);
    for I := ControlCount - 1 downto 0 do
    begin
      C := Controls[I];
      if C.Visible and PtInRect(C.BoundsRect, P) and Supports(C, ICTitleBarDesignHit, Area) then
      begin
        Area.DesignMouseDown(Button, Shift, Point(X - C.Left, Y - C.Top));
        Exit;
      end;
    end;
    inherited MouseDown(Button, Shift, X, Y);
    Exit;
  end;
  if FHooked and (Button = mbLeft) then
  begin
    B := ButtonAt(Point(X, Y));
    if (B in [ctbMinimize, ctbClose]) and (ButtonState(B) = ctsEnabled) then
    begin
      FDownButton := B;
      Invalidate;
      Exit;
    end;
    if B <> ctbNone then
      Exit; // 無効のボタン
  end;
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TCTitleBar.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  B: TCTitleButton;
begin
  inherited MouseMove(Shift, X, Y);
  if not FHooked then
    Exit;
  B := ButtonAt(Point(X, Y));
  if (B <> ctbNone) and (ButtonState(B) <> ctsEnabled) then
    B := ctbNone;
  if (FDownButton <> ctbNone) and (B <> FDownButton) then
    B := ctbNone;
  SetHotButton(B);
end;

procedure TCTitleBar.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  B, Down: TCTitleButton;
  F: TCustomForm;
begin
  Down := FDownButton;
  if Down in [ctbMinimize, ctbClose] then
  begin
    FDownButton := ctbNone;
    Invalidate;
    B := ButtonAt(Point(X, Y));
    if (B = Down) and (Button = mbLeft) then
    begin
      F := GetParentForm(Self);
      {$IFDEF WINDOWS}
      if (F <> nil) and F.HandleAllocated then
      begin
        if B = ctbMinimize then
          PostMessage(F.Handle, WM_SYSCOMMAND, SC_MINIMIZE, 0)
        else
          PostMessage(F.Handle, WM_SYSCOMMAND, SC_CLOSE, 0);
      end;
      {$ENDIF}
    end;
    Exit;
  end;
  inherited MouseUp(Button, Shift, X, Y);
end;

procedure TCTitleBar.MouseLeave;
begin
  inherited MouseLeave;
  if FHotButton in [ctbMinimize, ctbClose] then
    SetHotButton(ctbNone);
end;

{ 設計時のクリック。タブ列のタブ・［◀▶］の上だけ 1 を返す。 }
procedure TCTitleBar.CMDesignHitTest(var Message: TCMDesignHitTest);
var
  I: Integer;
  C: TControl;
  P: TPoint;
  Area: ICTitleBarDesignHit;
begin
  Message.Result := 0;
  P := Point(Message.XPos, Message.YPos);
  for I := ControlCount - 1 downto 0 do
  begin
    C := Controls[I];
    if C.Visible and PtInRect(C.BoundsRect, P) and Supports(C, ICTitleBarDesignHit, Area) then
    begin
      if Area.DesignHitTest(Point(P.X - C.Left, P.Y - C.Top)) then
        Message.Result := 1;
      Exit;
    end;
  end;
end;

procedure TCTitleBar.CMTextChanged(var Message: TLMessage);
begin
  inherited;
  ReAlign;
  Invalidate;
end;

procedure TCTitleBar.CMFontChanged(var Message: TLMessage);
begin
  inherited;
  ReAlign;
  Invalidate;
end;

procedure TCTitleBar.CMColorChanged(var Message: TLMessage);
var
  I: Integer;
  Area: ICTitleBarDragArea;
begin
  inherited;
  // タブ列の背景はタイトルバーの Color
  for I := 0 to ControlCount - 1 do
    if Supports(Controls[I], ICTitleBarDragArea, Area) then
      Controls[I].Invalidate;
  Invalidate;
end;

procedure TCTitleBar.FormActivated(AActive: Boolean);
begin
  if FFormActive = AActive then
    Exit;
  FFormActive := AActive;
  Invalidate;
end;

procedure TCTitleBar.FormCaptionChanged;
begin
  if Caption = '' then
  begin
    ReAlign;
    Invalidate;
  end;
end;

procedure TCTitleBar.FormStateChanged;
begin
  // 最大化・元に戻すで、最大化ボタンの記号を切り替える
  Invalidate;
end;

{ AParent の中（子・孫…すべて）に、ASelf 以外の TCTitleBar があるか }
function HasOtherTitleBar(AParent: TWinControl; ASelf: TControl): Boolean;
var
  I: Integer;
  C: TControl;
begin
  Result := False;
  for I := 0 to AParent.ControlCount - 1 do
  begin
    C := AParent.Controls[I];
    if (C <> ASelf) and (C is TCTitleBar) then
      Exit(True);
    if (C is TWinControl) and HasOtherTitleBar(TWinControl(C), ASelf) then
      Exit(True);
  end;
end;

{ 設計時に、1つのフォームへ2つ目の TCTitleBar を置こうとしたら、例外を出して置くのをやめる。
  置き先がフォーム・TCTitleBar・パネルなどのどれでも、置き先のフォームの中のすべての部品を調べる
  （置き先がフォームのときだけだと、パレットで選んだまま TCTitleBar の上をクリックしたとき、中に置かれてしまうため）。
  フォームの .lfm を開いている途中（フォームが csLoading）は確かめない。2つ入った既存の .lfm も開けるようにするため。
  貼り付け（Ctrl+V）のときはフォームは読み込み中ではないので、確かめる。 }
procedure TCTitleBar.SetParent(NewParent: TWinControl);
var
  F: TCustomForm;
begin
  if (NewParent <> nil) and (NewParent <> Parent)
    and (csDesigning in NewParent.ComponentState) then
  begin
    F := GetParentForm(NewParent);
    if (F <> nil) and not (csLoading in F.ComponentState)
      and HasOtherTitleBar(F, Self) then
      raise EInvalidOperation.Create(rsCTitleBarOnlyOne);
  end;
  inherited SetParent(NewParent);
end;

{$IFDEF WINDOWS}
{ 組み込めるか：実行時、フォームに直接置かれ、BorderStyle が bsSizeable・bsSingle で、
  ほかの TCTitleBar がまだ組み込んでいない。 }
function TCTitleBar.CanHookForm: Boolean;
var
  F: TCustomForm;
  I: Integer;
begin
  Result := False;
  if csDesigning in ComponentState then
    Exit;
  if not (Parent is TCustomForm) then
    Exit;
  F := TCustomForm(Parent);
  if not (F.BorderStyle in [bsSizeable, bsSingle]) then
    Exit;
  if not F.HandleAllocated then
    Exit;
  for I := 0 to F.ControlCount - 1 do
    if (F.Controls[I] <> Self) and (F.Controls[I] is TCTitleBar)
      and TCTitleBar(F.Controls[I]).FHooked then
      Exit;
  Result := LoadSubclassApi;
end;

procedure TCTitleBar.HookForm;
begin
  if FHooked then
    Exit;
  if not CanHookForm then
    Exit;
  FHookedForm := TCustomForm(Parent);
  FHookedFormWnd := FHookedForm.Handle;
  if pSetWindowSubclass(FHookedFormWnd, @FormSubclassProc, SUBCLASS_ID_FORM,
    DWORD_PTR(Pointer(Self))) then
  begin
    FHooked := True;
    FFormActive := GetActiveWindow = FHookedFormWnd;
    // 枠を計算し直させ、LCL に中身の大きさの変化を知らせる
    FrameChanged(FHookedFormWnd, FHookedForm);
  end;
end;

procedure TCTitleBar.UnhookForm;
var
  Wnd: HWND;
  F: TCustomForm;
begin
  if not FHooked then
    Exit;
  FHooked := False;
  Wnd := FHookedFormWnd;
  F := FHookedForm;
  FHookedFormWnd := 0;
  FHookedForm := nil;
  if (Wnd <> 0) and IsWindow(Wnd) then
  begin
    pRemoveWindowSubclass(Wnd, @FormSubclassProc, SUBCLASS_ID_FORM);
    FrameChanged(Wnd, F);
  end;
end;
{$ENDIF}

procedure TCTitleBar.CreateWnd;
begin
  inherited CreateWnd;
  {$IFDEF WINDOWS}
  if not (csDesigning in ComponentState) and LoadSubclassApi then
  begin
    if pSetWindowSubclass(Handle, @SelfSubclassProc, SUBCLASS_ID_SELF,
      DWORD_PTR(Pointer(Self))) then
      FSelfHooked := True;
    HookForm;
    ReAlign;
  end;
  {$ENDIF}
end;

procedure TCTitleBar.DestroyWnd;
begin
  {$IFDEF WINDOWS}
  UnhookForm;
  if FSelfHooked and HandleAllocated then
  begin
    pRemoveWindowSubclass(Handle, @SelfSubclassProc, SUBCLASS_ID_SELF);
    FSelfHooked := False;
  end;
  {$ENDIF}
  inherited DestroyWnd;
end;

end.
