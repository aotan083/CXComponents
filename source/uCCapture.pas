{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
unit uCCapture;

{ TCCapture - デスクトップの画面を取り込み（キャプチャー）、画像ファイルに保存する部品（画面を持たない）。
  設計書：docs\TCCapture_Design.md
  ・取り込む範囲：デスクトップ全体（複数モニターを含む）・アクティブなウィンドウ・任意の長方形
  ・取り込んだ絵と、ファイルの読み書きは、TCImage（uCImages）を使う
  ・SaveToFile は、保存先のフォルダーが無ければ作り、拡張子の形式に変換して書く（bmp → jpg など） }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Math, Windows, Graphics, Controls, Forms,
  uCImages, uCXLang;

type
  { 取り込む範囲の種類 }
  TCCaptureArea = (caDesktop, caActiveWindow, caRegion);

  { 取り込みのエラー }
  ECCaptureError = class(Exception);

  { TCCapture }
  TCCapture = class(TComponent)
  private
    FImage: TCImage;
    FArea: TCCaptureArea;
    FRegion: TRect;
    FIncludeCursor: Boolean;
    FDelay: Integer;
    FJpegQuality: Integer;
    FFileName: string;
    FOnCaptured: TNotifyEvent;
    FOnSaved: TNotifyEvent;
    function GetEmpty: Boolean;
    procedure SetDelay(AValue: Integer);
    procedure SetJpegQuality(AValue: Integer);
    function GetRegionPart(AIndex: Integer): Integer;
    procedure SetRegionPart(AIndex: Integer; AValue: Integer);
    procedure WaitDelay;
    function VirtualScreen: TRect;
    function ActiveWindowRect: TRect;
    function ClipRegion(const ARect: TRect): TRect;
    procedure CaptureRect(const ARect: TRect);
    procedure DrawCursor(ABitmap: TBitmap; const ARect: TRect);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { Area の設定で取り込む。Delay を待ってから取り込み、Image に入れる }
    procedure Capture;
    { Area を変えずに、デスクトップ全体・アクティブなウィンドウ・指定の範囲を取り込む }
    procedure CaptureDesktop;
    procedure CaptureActiveWindow;
    procedure CaptureRegion(X, Y, X1, Y1: Integer);
    { Image を保存する。保存先のフォルダーが無ければ作る。拡張子の形式に変換して書く }
    procedure SaveToFile(const AFileName: string);
    { 画像ファイルを Image に読む（bmp・jpg・png・svg・tif・ico） }
    procedure LoadFromFile(const AFileName: string);
    procedure Clear;
    { Image の絵を、別の TCImage に写す }
    procedure CopyTo(ATarget: TCImage);
    { 取り込んだ絵（読み込んだ絵もここ）。部品が作り、部品が壊す }
    property Image: TCImage read FImage;
    { Area = caRegion のときの範囲（Left=X, Top=Y, Right=X1, Bottom=Y1） }
    property Region: TRect read FRegion write FRegion;
    property FileName: string read FFileName;
    property Empty: Boolean read GetEmpty;
  published
    property Area: TCCaptureArea read FArea write FArea default caDesktop;
    property RegionLeft: Integer index 0 read GetRegionPart write SetRegionPart default 0;
    property RegionTop: Integer index 1 read GetRegionPart write SetRegionPart default 0;
    property RegionRight: Integer index 2 read GetRegionPart write SetRegionPart default 0;
    property RegionBottom: Integer index 3 read GetRegionPart write SetRegionPart default 0;
    property IncludeCursor: Boolean read FIncludeCursor write FIncludeCursor default False;
    { 取り込む前に待つ時間（ミリ秒） }
    property Delay: Integer read FDelay write SetDelay default 0;
    { jpg で保存するときの画質（1〜100） }
    property JpegQuality: Integer read FJpegQuality write SetJpegQuality default 90;
    property OnCaptured: TNotifyEvent read FOnCaptured write FOnCaptured;
    property OnSaved: TNotifyEvent read FOnSaved write FOnSaved;
  end;

implementation

const
  CAPTUREBLT_FLAG = $40000000;   { 半透明のウィンドウも含めて写す }
  DWMWA_EXTENDED_FRAME_BOUNDS = 9;

type
  TDwmGetWindowAttribute = function(hwnd: HWND; dwAttribute: DWORD;
    pvAttribute: Pointer; cbAttribute: DWORD): LongInt; stdcall;

{ ---------------------------------------------------------------------------
  TCCapture
  --------------------------------------------------------------------------- }

constructor TCCapture.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FImage := TCImage.Create(nil);
  FArea := caDesktop;
  FJpegQuality := 90;
end;

destructor TCCapture.Destroy;
begin
  FImage.Free;
  inherited Destroy;
end;

function TCCapture.GetEmpty: Boolean;
begin
  Result := (FImage.Picture.Graphic = nil) or FImage.Picture.Graphic.Empty;
end;

procedure TCCapture.SetDelay(AValue: Integer);
begin
  FDelay := Max(0, AValue);
end;

procedure TCCapture.SetJpegQuality(AValue: Integer);
begin
  FJpegQuality := EnsureRange(AValue, 1, 100);
end;

function TCCapture.GetRegionPart(AIndex: Integer): Integer;
begin
  case AIndex of
    0: Result := FRegion.Left;
    1: Result := FRegion.Top;
    2: Result := FRegion.Right;
  else
    Result := FRegion.Bottom;
  end;
end;

procedure TCCapture.SetRegionPart(AIndex: Integer; AValue: Integer);
begin
  case AIndex of
    0: FRegion.Left := AValue;
    1: FRegion.Top := AValue;
    2: FRegion.Right := AValue;
  else
    FRegion.Bottom := AValue;
  end;
end;

{ Delay の間待つ。待つ間も、画面の処理は進める }
procedure TCCapture.WaitDelay;
var
  T0: QWord;
begin
  if FDelay <= 0 then Exit;
  T0 := GetTickCount64;
  while GetTickCount64 - T0 < QWord(FDelay) do
  begin
    Application.ProcessMessages;
    Sleep(10);
  end;
end;

{ 全モニターを含む仮想画面 }
function TCCapture.VirtualScreen: TRect;
begin
  Result.Left := GetSystemMetrics(SM_XVIRTUALSCREEN);
  Result.Top := GetSystemMetrics(SM_YVIRTUALSCREEN);
  Result.Right := Result.Left + GetSystemMetrics(SM_CXVIRTUALSCREEN);
  Result.Bottom := Result.Top + GetSystemMetrics(SM_CYVIRTUALSCREEN);
end;

{ アクティブなウィンドウの、見える範囲（影を除いた枠。取れなければ GetWindowRect） }
function TCCapture.ActiveWindowRect: TRect;
var
  H: HWND;
  Lib: HMODULE;
  Fn: TDwmGetWindowAttribute;
  R: TRect;
  Got: Boolean;
begin
  H := GetForegroundWindow;
  if (H = 0) or IsIconic(H) or not IsWindowVisible(H) then
    raise ECCaptureError.Create(CXT(sCapNoWindow));
  Got := False;
  Lib := LoadLibrary('dwmapi.dll');
  if Lib <> 0 then
  begin
    try
      Pointer(Fn) := GetProcAddress(Lib, 'DwmGetWindowAttribute');
      if Fn <> nil then
        Got := Fn(H, DWMWA_EXTENDED_FRAME_BOUNDS, @R, SizeOf(R)) = 0;
    finally
      FreeLibrary(Lib);
    end;
  end;
  if not Got then
    if not GetWindowRect(H, R) then
      raise ECCaptureError.Create(CXT(sCapNoWindow));
  Result := R;
end;

{ 範囲を仮想画面に収める。重ならない・大きさが 0 なら ECCaptureError }
function TCCapture.ClipRegion(const ARect: TRect): TRect;
var
  R, V: TRect;
  T: Integer;
begin
  R := ARect;
  if R.Left > R.Right then begin T := R.Left; R.Left := R.Right; R.Right := T; end;
  if R.Top > R.Bottom then begin T := R.Top; R.Top := R.Bottom; R.Bottom := T; end;
  V := VirtualScreen;
  if not IntersectRect(Result, R, V) or IsRectEmpty(Result) then
    raise ECCaptureError.Create(CXT(sCapBadRegion));
end;

{ マウスカーソルを、範囲内の位置に描き込む }
procedure TCCapture.DrawCursor(ABitmap: TBitmap; const ARect: TRect);
var
  CI: TCursorInfo;
  II: TIconInfo;
  HotX, HotY: Integer;
begin
  CI.cbSize := SizeOf(CI);
  if not GetCursorInfo(CI) then Exit;
  if (CI.flags and 1) = 0   { CURSOR_SHOWING } then Exit;
  HotX := 0; HotY := 0;
  if GetIconInfo(CI.hCursor, @II) then
  begin
    HotX := II.xHotspot;
    HotY := II.yHotspot;
    if II.hbmMask <> 0 then DeleteObject(II.hbmMask);
    if II.hbmColor <> 0 then DeleteObject(II.hbmColor);
  end;
  { 範囲の外のカーソルは描かない }
  if (CI.ptScreenPos.x < ARect.Left) or (CI.ptScreenPos.x >= ARect.Right) or
     (CI.ptScreenPos.y < ARect.Top) or (CI.ptScreenPos.y >= ARect.Bottom) then Exit;
  DrawIconEx(ABitmap.Canvas.Handle,
    CI.ptScreenPos.x - ARect.Left - HotX, CI.ptScreenPos.y - ARect.Top - HotY,
    CI.hCursor, 0, 0, 0, 0, DI_NORMAL);
end;

{ 画面の指定の範囲を、Image に取り込む（範囲は、仮想画面の中） }
procedure TCCapture.CaptureRect(const ARect: TRect);
var
  DC: HDC;
  Bmp: TBitmap;
  W, H: Integer;
begin
  W := ARect.Right - ARect.Left;
  H := ARect.Bottom - ARect.Top;
  Bmp := TBitmap.Create;
  try
    Bmp.PixelFormat := pf24bit;      { 24 ビット（画面にはアルファが無い） }
    Bmp.SetSize(W, H);
    DC := GetDC(0);
    if DC = 0 then
      raise ECCaptureError.Create(CXT(sCapFailed));
    try
      if not BitBlt(Bmp.Canvas.Handle, 0, 0, W, H, DC, ARect.Left, ARect.Top,
        SRCCOPY or CAPTUREBLT_FLAG) then
        raise ECCaptureError.Create(CXT(sCapFailed));
    finally
      ReleaseDC(0, DC);
    end;
    if FIncludeCursor then
      DrawCursor(Bmp, ARect);
    FImage.LoadFromBitmap(Bmp);
    FFileName := '';
  finally
    Bmp.Free;
  end;
  if Assigned(FOnCaptured) then FOnCaptured(Self);
end;

procedure TCCapture.Capture;
begin
  case FArea of
    caDesktop: CaptureDesktop;
    caActiveWindow: CaptureActiveWindow;
  else
    CaptureRegion(FRegion.Left, FRegion.Top, FRegion.Right, FRegion.Bottom);
  end;
end;

procedure TCCapture.CaptureDesktop;
begin
  WaitDelay;
  CaptureRect(VirtualScreen);
end;

procedure TCCapture.CaptureActiveWindow;
begin
  WaitDelay;
  { 待ったあとに、アクティブなウィンドウを決める }
  CaptureRect(ClipRegion(ActiveWindowRect));
end;

procedure TCCapture.CaptureRegion(X, Y, X1, Y1: Integer);
var
  R: TRect;
begin
  WaitDelay;
  R.Left := X; R.Top := Y; R.Right := X1; R.Bottom := Y1;   { Windows の RECT 型と名前が重なるので、Rect() は使わない }
  CaptureRect(ClipRegion(R));
end;

procedure TCCapture.SaveToFile(const AFileName: string);
var
  Dir: string;
begin
  if Empty then
    raise ECCaptureError.Create(CXT(sCapEmpty));
  { 保存先のフォルダーが無ければ、途中の階層も含めて作る }
  Dir := ExtractFilePath(ExpandFileName(AFileName));
  if (Dir <> '') and not DirectoryExists(Dir) then
    if not ForceDirectories(Dir) then
      raise ECCaptureError.CreateFmt(CXT(sCapNoFolder), [Dir]);
  FImage.SaveToFile(AFileName, FJpegQuality);   { 変換と書き込みは TCImage が行う }
  FFileName := AFileName;
  if Assigned(FOnSaved) then FOnSaved(Self);
end;

procedure TCCapture.LoadFromFile(const AFileName: string);
begin
  FImage.LoadFromFile(AFileName);
  FFileName := AFileName;
end;

procedure TCCapture.Clear;
begin
  FImage.Picture.Clear;
  FFileName := '';
end;

procedure TCCapture.CopyTo(ATarget: TCImage);
begin
  if ATarget = nil then Exit;
  ATarget.Picture.Assign(FImage.Picture);
end;

end.
