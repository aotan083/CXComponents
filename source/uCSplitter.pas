{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ uCSplitter
  TCSplitter：TSplitter と同じ使い方で、マウスを乗せたとき・ドラッグ中に、色の付いた線を出す分割線（実行時パッケージ cx）。
  ・分割の仕組み（ResizeAnchor・ResizeStyle・MinSize・OnMoved など）は TSplitter のまま
  ・線の色は HighlightColor（既定は clHighlight。テーマ・ダーク表示に追従する）
  ・カーソルは SplitCursor で変えられる（既定は TSplitter と同じ）
  ・OnMouseEnter・OnMouseLeave・OnMouseMove・OnMouseDown・OnMouseUp を、オブジェクトインスペクタに出す
  設計書：docs\TCSplitter_Design.md }
unit uCSplitter;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Math, Controls, ExtCtrls, Graphics, LCLType, LMessages;

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

implementation

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
  Canvas.Brush.Color := FHighlightColor;
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

end.
