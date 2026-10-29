{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ uCGroupBox
  TCGroupBox：TGroupBox と同じ見た目・使い方のグループボックス（実行時パッケージ cx）。
  標準の TGroupBox は Windows のネイティブ部品で、内側の標準部品が消えることがある。
  TCGroupBox は LCL が描く TCustomPanel を元にし、枠と見出しを自分で描くことで、この不具合をなくす。
  ・実行時の見た目は TGroupBox に合わせる。Windows でテーマが使えるときは、TGroupBox と同じ
    テーマの部品（tbGroupBoxNormal／tbGroupBoxDisabled）で枠と見出しを描く。
    それ以外（Linux など）は 1px の線（clBtnShadow）で枠を描く。どちらも見出しは枠の上辺を切って描く
  ・子の部品が使う領域（Align・ChildSizing）は、枠と見出しの内側にする
  ・色はシステム色・テーマの色だけを使う（ダーク／ライトのテーマ追従を MetaDarkStyle 等に任せる）
  ・TCCheckGroupBox が見出しを差し替えられるよう、見出しの高さ・幅・描画を virtual にしている
  設計書：docs\TCGroupBox_Design.md }
unit uCGroupBox;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, ExtCtrls, Graphics, Forms, LCLType, LCLIntf, LMessages, Themes;

type

  { TCGroupBox }

  TCGroupBox = class(TCustomPanel)
  protected
    // 派生クラス（TCCheckGroupBox）が同じメッセージを受けて inherited で呼べるよう protected にする
    procedure CMTextChanged(var Message: TLMessage); message CM_TEXTCHANGED;
    procedure CMEnabledChanged(var Message: TLMessage); message CM_ENABLEDCHANGED;
    procedure CMColorChanged(var Message: TLMessage); message CM_COLORCHANGED;
    // 96dpi 基準の寸法を、置かれているフォームの表示スケールに換算する。
    // フォームに置かれていない（親がない）ときは画面の表示スケールで換算する。
    function ScaleValue(AValue: Integer): Integer;
    // Font で文字列を描いたときの高さ・幅を測る（ハンドルがなくても測れるよう、共用のビットマップで測る）
    function MeasureTextHeight(const AText: string): Integer;
    function MeasureTextWidth(const AText: string): Integer;
    // 見出しの高さ。Caption が空でも同じ高さを返す（見出しの有無で中の配置が動かないように）
    function GetCaptionHeight: Integer; virtual;
    // 枠の上辺を切る幅（前後の余白 2px は含まない）。0 なら上辺を切らない
    function GetCaptionGapWidth: Integer; virtual;
    // 見出しの描画。ARect は見出し文字を置く範囲（前後の余白を除いた範囲）
    procedure PaintCaption(const ARect: TRect); virtual;
    // 見出しの文字を、TGroupBox と同じ文字色・描き方で ARect に描く（TCCheckGroupBox も使う共通処理）
    procedure DrawCaptionText(const ARect: TRect; const AText: string);
    // Windows でテーマが使えるとき True（枠・見出しをテーマの部品で描く）
    function UseThemeDrawing: Boolean;
    // 見出し文字の左端（BiDiMode が右から左なら右寄せの位置）
    function GetCaptionLeft: Integer;
    procedure Paint; override;
    procedure FontChanged(Sender: TObject); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure AdjustClientRect(var ARect: TRect); override;
  published
    property Align;
    property Anchors;
    property AutoSize;
    property BidiMode;
    property BorderSpacing;
    property Caption;
    property ChildSizing;
    property ClientHeight;
    property ClientWidth;
    property Color;
    property Constraints;
    property DockSite;
    property DoubleBuffered;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property ParentBackground;
    property ParentBidiMode;
    property ParentColor;
    property ParentDoubleBuffered;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnChangeBounds;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDockDrop;
    property OnDockOver;
    property OnDragOver;
    property OnEndDock;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnGetSiteInfo;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnResize;
    property OnStartDock;
    property OnStartDrag;
    property OnUnDock;
    property OnUTF8KeyPress;
  end;

const
  // 寸法（96dpi 時の値。使うときは ScaleValue で換算する）
  CGB_CAPTION_LEFT = 9;  // 見出しの左端（枠の左端から。TGroupBox に合わせる）
  CGB_CAPTION_PAD  = 2;  // 見出しの前後に空ける幅（この幅も枠線を切る）
  CGB_INNER_MARGIN = 2;  // 子の部品が使う領域の、左・右・下の余白と、見出しの下の余白

implementation

var
  // 文字の寸法を測るための共用ビットマップ（ハンドルのない部品でも測れるように使う）
  MeasureBitmap: TBitmap = nil;

function GetMeasureCanvas(AFont: TFont): TCanvas;
begin
  if MeasureBitmap = nil then
  begin
    MeasureBitmap := TBitmap.Create;
    MeasureBitmap.SetSize(1, 1);
  end;
  Result := MeasureBitmap.Canvas;
  Result.Font.Assign(AFont);
end;

{ TCGroupBox }

constructor TCGroupBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  // TCustomPanel の立体枠は使わない（枠は Paint で自分で描く）
  BevelOuter := bvNone;
  BevelInner := bvNone;
  // TGroupBox と同じ既定の大きさ
  SetInitialBounds(0, 0, 185, 105);
  ParentColor := True;
end;

function TCGroupBox.ScaleValue(AValue: Integer): Integer;
var
  F: TCustomDesignControl;
begin
  F := GetParentDesignControl(Self);
  if F <> nil then
    Result := MulDiv(AValue, F.PixelsPerInch, 96)
  else
    Result := MulDiv(AValue, Screen.PixelsPerInch, 96);
end;

function TCGroupBox.MeasureTextHeight(const AText: string): Integer;
begin
  Result := GetMeasureCanvas(Font).TextHeight(AText);
end;

function TCGroupBox.MeasureTextWidth(const AText: string): Integer;
begin
  Result := GetMeasureCanvas(Font).TextWidth(AText);
end;

function TCGroupBox.GetCaptionHeight: Integer;
begin
  // 'Wg' で上下に出る文字を含めた高さを取る。Caption の中身にはよらない
  Result := MeasureTextHeight('Wg');
end;

function TCGroupBox.GetCaptionGapWidth: Integer;
begin
  if Caption = '' then
    Result := 0
  else
    Result := MeasureTextWidth(Caption);
end;

function TCGroupBox.GetCaptionLeft: Integer;
begin
  if UseRightToLeftAlignment then
    Result := Width - ScaleValue(CGB_CAPTION_LEFT) - GetCaptionGapWidth
  else
    Result := ScaleValue(CGB_CAPTION_LEFT);
end;

procedure TCGroupBox.AdjustClientRect(var ARect: TRect);
var
  M: Integer;
begin
  inherited AdjustClientRect(ARect);
  // 子の部品の領域を、見出しの下と枠の内側にする
  M := ScaleValue(CGB_INNER_MARGIN);
  Inc(ARect.Top, GetCaptionHeight + M);
  Inc(ARect.Left, M);
  Dec(ARect.Right, M);
  Dec(ARect.Bottom, M);
end;

function TCGroupBox.UseThemeDrawing: Boolean;
begin
  {$IFDEF MSWINDOWS}
  Result := ThemeServices.ThemesEnabled;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

procedure TCGroupBox.DrawCaptionText(const ARect: TRect; const AText: string);
var
  FC: TColor;
  TH: Integer;
  Det: TThemedElementDetails;
begin
  if AText = '' then Exit;
  Canvas.Font.Assign(Font);
  Canvas.Brush.Style := bsClear;
  if UseThemeDrawing and (Font.Color = clDefault) then
  begin
    // テーマの文字色で描く（TGroupBox の見出しと同じ部品。ダーク表示では MetaDarkStyle の色になる）
    if IsEnabled then
      Det := ThemeServices.GetElementDetails(tbGroupBoxNormal)
    else
      Det := ThemeServices.GetElementDetails(tbGroupBoxDisabled);
    ThemeServices.DrawText(Canvas, Det, AText, ARect,
      DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX, 0);
  end
  else
  begin
    // 文字色：有効なら Font.Color（既定色なら部品の既定の文字色）、無効なら灰色
    if IsEnabled then
    begin
      FC := Font.Color;
      if FC = clDefault then
        FC := GetDefaultColor(dctFont);
    end
    else
      FC := clGrayText;
    Canvas.Font.Color := FC;
    // 範囲の中で、上下の中央に描く
    TH := Canvas.TextHeight('Wg');
    Canvas.TextOut(ARect.Left, ARect.Top + (ARect.Bottom - ARect.Top - TH) div 2, AText);
  end;
end;

procedure TCGroupBox.PaintCaption(const ARect: TRect);
begin
  DrawCaptionText(ARect, Caption);
end;

procedure TCGroupBox.Paint;
var
  CH, Gap, Pad, TL, LineY, SavedDC: Integer;
  GapRect: TRect;
  DC: HDC;
  Det: TThemedElementDetails;
begin
  // 背景：部品の色（親の色を使う設定なら親の色）で全面を塗る
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := GetColorResolvingParent;
  Canvas.FillRect(0, 0, Width, Height);

  // 見出しの範囲（文字＋前後の余白）。この範囲で枠の上辺を切る
  CH := GetCaptionHeight;
  LineY := CH div 2;
  Gap := GetCaptionGapWidth;
  Pad := ScaleValue(CGB_CAPTION_PAD);
  TL := GetCaptionLeft;
  GapRect := Rect(TL - Pad, 0, TL + Gap + Pad, CH);

  if UseThemeDrawing then
  begin
    // 枠：TGroupBox と同じテーマの部品で描く。見出しの範囲は切り抜いて描かない
    // （SaveDC／RestoreDC で切り抜きを戻し、ほかの描画に残さない）
    DC := Canvas.Handle;
    SavedDC := SaveDC(DC);
    try
      if Gap > 0 then
        ExcludeClipRect(DC, GapRect.Left, GapRect.Top, GapRect.Right, GapRect.Bottom);
      if IsEnabled then
        Det := ThemeServices.GetElementDetails(tbGroupBoxNormal)
      else
        Det := ThemeServices.GetElementDetails(tbGroupBoxDisabled);
      ThemeServices.DrawElement(DC, Det, Rect(0, LineY, Width, Height));
    finally
      RestoreDC(DC, SavedDC);
    end;
  end
  else
  begin
    // 枠：1px、clBtnShadow、角は直角。見出しの範囲を背景色で塗って上辺を切る
    Canvas.Pen.Style := psSolid;
    Canvas.Pen.Width := 1;
    Canvas.Pen.Color := clBtnShadow;
    Canvas.Brush.Style := bsClear;
    Canvas.Rectangle(0, LineY, Width, Height);
    if Gap > 0 then
    begin
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := GetColorResolvingParent;
      Canvas.FillRect(GapRect);
    end;
  end;

  // 見出し：文字を置く範囲に描く
  if Gap > 0 then
    PaintCaption(Rect(TL, 0, TL + Gap, CH));
end;

procedure TCGroupBox.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  // 文字の大きさが変わると見出しの高さが変わるので、子の配置からやり直す
  InvalidatePreferredSize;
  ReAlign;
  Invalidate;
end;

procedure TCGroupBox.CMTextChanged(var Message: TLMessage);
begin
  inherited;
  // 見出しの高さは Caption によらないので、描き直すだけ
  Invalidate;
end;

procedure TCGroupBox.CMEnabledChanged(var Message: TLMessage);
begin
  inherited;
  // 見出しの文字色が変わるので描き直す
  Invalidate;
end;

procedure TCGroupBox.CMColorChanged(var Message: TLMessage);
begin
  inherited;
  Invalidate;
end;

finalization
  FreeAndNil(MeasureBitmap);

end.
