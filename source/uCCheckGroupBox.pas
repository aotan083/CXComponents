{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ uCCheckGroupBox
  TCCheckGroupBox：見出しにチェックボックスを持つ TCGroupBox（実行時パッケージ cx）。
  ・Checked を False にすると、内側の部品をすべて無効（Enabled=False）にする
  ・Checked を True に戻すと、各部品を無効にする前の Enabled に戻す（もともと無効だった部品は無効のまま）
  ・本体の Enabled=False のときも、チェックボックスを含めて全部無効にする
  ・チェックボックスは部品の内部に持ち、.lfm には保存しない。設計時に選択・移動もできない
  ・チェックボックスは四角だけを表示し、見出しの文字は本体が TCGroupBox と同じ描き方で描く
    （ダーク表示でも、ネイティブのチェックボックスの文字色に左右されないように）。
    見出しの文字をクリックしてもチェックが切り替わる
  ・設計時（フォームデザイナ上）は内側の部品の Enabled を変えない（変えると .lfm に保存されてしまうため）
  設計書：docs\TCGroupBox_Design.md }
unit uCCheckGroupBox;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, StdCtrls, LMessages, uCGroupBox;

type

  // 無効にした部品と、無効にする前の Enabled の記録
  TCCGBSavedItem = record
    Control: TControl;
    Enabled: Boolean;
  end;

  { TCCheckGroupBox }

  TCCheckGroupBox = class(TCGroupBox)
  private
    FCheckBox: TCheckBox;          // 見出しのチェックボックス（Owner = Self なので .lfm には保存されない）
    FChecked: Boolean;
    FOnChange: TNotifyEvent;
    FSyncing: Boolean;             // Checked → チェックボックスへ反映している間 True（再入を防ぐ）
    FPlacing: Boolean;             // チェックボックスの位置を直している間 True（再入を防ぐ）
    FInnerDisabled: Boolean;       // 内側の部品を無効にしている間 True
    FDownInText: Boolean;          // 見出しの文字の中で左ボタンが押されている間 True
    FSaved: array of TCCGBSavedItem;
    FSavedCount: Integer;
    procedure SetChecked(AValue: Boolean);
    procedure CheckBoxChange(Sender: TObject);
    procedure CheckBoxResize(Sender: TObject);
    procedure CheckBoxFocusChange(Sender: TObject);
    procedure SyncCheckBox;
    procedure UpdateCheckBoxBounds;
    procedure UpdateInnerEnabled;
    procedure DisableTree(AParent: TWinControl);
    procedure DisableOne(AControl: TControl);
    function IsSaved(AControl: TControl): Boolean;
    procedure RestoreAll;
    procedure CMCheckEnabledChanged(var Message: TLMessage); message CM_ENABLEDCHANGED;
    procedure CMCheckControlChange(var Message: TLMessage); message CM_CONTROLCHANGE;
  protected
    function GetCaptionHeight: Integer; override;
    function GetCaptionGapWidth: Integer; override;
    procedure PaintCaption(const ARect: TRect); override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure FontChanged(Sender: TObject); override;
    procedure Resize; override;
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    // 見出しの文字を置く範囲（チェックボックスの右に 4px 空けた位置。右から左のときは左側）
    function CaptionTextRect: TRect;
    procedure DoChange; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Checked: Boolean read FChecked write SetChecked default True;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

const
  CCGB_CHECK_SPACE = 4;  // チェックボックスと見出しの文字の間（96dpi 時の値）

{ TCCheckGroupBox }

constructor TCCheckGroupBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FChecked := True;
  FSavedCount := 0;

  // 見出しのチェックボックスを作る。
  // Owner が Self（フォームではない）ので .lfm には書かれない。設計時は選択できないようにする
  FCheckBox := TCheckBox.Create(Self);
  FCheckBox.ControlStyle := FCheckBox.ControlStyle + [csNoDesignSelectable];
  FCheckBox.AutoSize := True;
  FCheckBox.ParentFont := True;
  FCheckBox.ParentColor := True;
  FCheckBox.TabStop := True;
  FCheckBox.Checked := True;
  FCheckBox.Caption := '';         // 四角だけ。見出しの文字は本体が描く
  FCheckBox.Parent := Self;
  FCheckBox.TabOrder := 0;
  FCheckBox.OnChange := @CheckBoxChange;
  FCheckBox.OnResize := @CheckBoxResize;
  FCheckBox.OnEnter := @CheckBoxFocusChange;   // フォーカス枠を描き直すため
  FCheckBox.OnExit := @CheckBoxFocusChange;
  UpdateCheckBoxBounds;
end;

destructor TCCheckGroupBox.Destroy;
begin
  // 記録は破棄するだけ（FreeNotification は TComponent.Destroy が外す）
  FSavedCount := 0;
  SetLength(FSaved, 0);
  inherited Destroy;
end;

function TCCheckGroupBox.GetCaptionHeight: Integer;
begin
  // 見出しの高さは、文字の高さとチェックボックスの高さの大きいほう
  Result := inherited GetCaptionHeight;
  if (FCheckBox <> nil) and (FCheckBox.Height > Result) then
    Result := FCheckBox.Height;
end;

function TCCheckGroupBox.GetCaptionGapWidth: Integer;
begin
  // 枠の上辺は、チェックボックスの幅（Caption があれば ＋ 間 4px ＋ 文字の幅）だけ切る
  if FCheckBox = nil then
    Exit(inherited GetCaptionGapWidth);
  Result := FCheckBox.Width;
  if Caption <> '' then
    Inc(Result, ScaleValue(CCGB_CHECK_SPACE) + MeasureTextWidth(Caption));
end;

function TCCheckGroupBox.CaptionTextRect: TRect;
var
  CBW, TW, L: Integer;
begin
  // 見出しの文字の範囲：上 0〜下 見出しの高さ、横は文字の幅。Caption が空なら幅 0
  if FCheckBox <> nil then CBW := FCheckBox.Width else CBW := 0;
  if Caption = '' then TW := 0 else TW := MeasureTextWidth(Caption);
  if UseRightToLeftAlignment then
  begin
    // 右端から：9px → チェックボックス → 4px → 文字
    L := Width - ScaleValue(CGB_CAPTION_LEFT) - CBW - ScaleValue(CCGB_CHECK_SPACE) - TW;
  end
  else
  begin
    // 左端から：9px → チェックボックス → 4px → 文字
    L := ScaleValue(CGB_CAPTION_LEFT) + CBW + ScaleValue(CCGB_CHECK_SPACE);
  end;
  Result := Rect(L, 0, L + TW, GetCaptionHeight);
end;

procedure TCCheckGroupBox.PaintCaption(const ARect: TRect);
var
  R: TRect;
begin
  // チェックボックスの横に見出しの文字を描く（TCGroupBox と同じ文字色・描き方）
  if Caption = '' then Exit;
  R := CaptionTextRect;
  DrawCaptionText(R, Caption);
  // チェックボックスにフォーカスがあるときは、文字の周りにフォーカス枠を描く
  // （チェックボックスに文字がないため、ネイティブのフォーカス枠の代わり）
  if (FCheckBox <> nil) and FCheckBox.Focused then
  begin
    InflateRect(R, 1, 1);
    Canvas.DrawFocusRect(R);
  end;
end;

procedure TCCheckGroupBox.CheckBoxFocusChange(Sender: TObject);
begin
  Invalidate;
end;

procedure TCCheckGroupBox.RealSetText(const AValue: TCaption);
begin
  inherited RealSetText(AValue);
  // 見出しの文字は本体が描くので、チェックボックスには入れない。
  // 枠を切る幅が変わるので、位置を直して描き直す
  UpdateCheckBoxBounds;
  Invalidate;
end;

procedure TCCheckGroupBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  // 見出しの文字の中で左ボタンを押したかを覚える（離したときに判定する）
  FDownInText := (Button = mbLeft) and PtInRect(CaptionTextRect, Point(X, Y));
end;

procedure TCCheckGroupBox.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Hit: Boolean;
begin
  inherited MouseUp(Button, Shift, X, Y);
  // 見出しの文字の中で押して、中で離したら、チェックボックスを押したのと同じにする
  // （Checked・OnChange・内側の有効／無効は CheckBoxChange 経由で処理される）。
  // 本体が無効のとき、設計時のときは何もしない
  Hit := FDownInText and (Button = mbLeft) and PtInRect(CaptionTextRect, Point(X, Y));
  FDownInText := False;
  if (not Hit) or (FCheckBox = nil) or (not IsEnabled) or (csDesigning in ComponentState) then
    Exit;
  FCheckBox.Checked := not FCheckBox.Checked;
  if FCheckBox.CanFocus then
    FCheckBox.SetFocus;
end;

procedure TCCheckGroupBox.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  UpdateCheckBoxBounds;
end;

procedure TCCheckGroupBox.Resize;
begin
  inherited Resize;
  // 右から左の表示では、チェックボックスを右端からの位置に置くため、幅が変わったら置き直す
  UpdateCheckBoxBounds;
end;

procedure TCCheckGroupBox.CheckBoxResize(Sender: TObject);
begin
  // チェックボックスの大きさが変わると、見出しの高さ・枠を切る幅が変わる
  UpdateCheckBoxBounds;
  ReAlign;
  Invalidate;
end;

procedure TCCheckGroupBox.UpdateCheckBoxBounds;
var
  Off, T: Integer;
begin
  if (FCheckBox = nil) or FPlacing then Exit;
  FPlacing := True;
  try
    // チェックボックスは見出しの位置（左から 9px、見出しの高さの上下中央）に置く。
    // 位置は親（Self）に対する固定の座標。Anchors を [akLeft, akTop] 以外にしているのは、
    // ChildSizing.Layout を使ったとき、並べ替えの対象から外すため
    // （LCL は Align=alNone かつ Anchors=[akLeft,akTop] の部品だけを並べ替える）
    Off := ScaleValue(CGB_CAPTION_LEFT);
    T := (GetCaptionHeight - FCheckBox.Height) div 2;
    if UseRightToLeftAlignment then
    begin
      FCheckBox.Anchors := [akTop, akRight];
      FCheckBox.SetBounds(Width - Off - FCheckBox.Width, T, FCheckBox.Width, FCheckBox.Height);
    end
    else
    begin
      FCheckBox.Anchors := [akTop];
      FCheckBox.SetBounds(Off, T, FCheckBox.Width, FCheckBox.Height);
    end;
  finally
    FPlacing := False;
  end;
end;

procedure TCCheckGroupBox.SetChecked(AValue: Boolean);
begin
  if FChecked = AValue then Exit;
  FChecked := AValue;
  SyncCheckBox;
  UpdateInnerEnabled;
  // 読み込み中（.lfm から値を入れているとき）はイベントを出さない
  if not (csLoading in ComponentState) then
    DoChange;
end;

procedure TCCheckGroupBox.SyncCheckBox;
begin
  // Checked の値をチェックボックスの表示に入れる（CheckBoxChange から SetChecked へ戻らないようにする）
  if FCheckBox = nil then Exit;
  FSyncing := True;
  try
    FCheckBox.Checked := FChecked;
  finally
    FSyncing := False;
  end;
end;

procedure TCCheckGroupBox.CheckBoxChange(Sender: TObject);
begin
  // 画面でチェックボックスが押されたとき、本体の Checked を同じ値にする
  if FSyncing then Exit;
  SetChecked(FCheckBox.Checked);
end;

procedure TCCheckGroupBox.DoChange;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TCCheckGroupBox.UpdateInnerEnabled;
var
  NeedDisable: Boolean;
begin
  // 読み込み中は Loaded で、設計時は .lfm に Enabled=False が残らないよう、何もしない
  if [csLoading, csDesigning, csDestroying] * ComponentState <> [] then Exit;

  // 無効にすべき状態 = 本体が無効、またはチェックが外れている
  NeedDisable := not (Enabled and FChecked);
  if NeedDisable and not FInnerDisabled then
  begin
    FInnerDisabled := True;
    DisableTree(Self);
  end
  else if (not NeedDisable) and FInnerDisabled then
  begin
    RestoreAll;
    FInnerDisabled := False;
  end;
end;

procedure TCCheckGroupBox.DisableTree(AParent: TWinControl);
var
  I: Integer;
  C: TControl;
begin
  // AParent の中の部品を順に無効にする（見出しのチェックボックスは除く）
  for I := 0 to AParent.ControlCount - 1 do
  begin
    C := AParent.Controls[I];
    if C = FCheckBox then Continue;
    DisableOne(C);
    // 入れ物（ほかの部品を置ける部品）なら中もたどる。
    // TCCheckGroupBox は自分の Enabled の変化で中を処理するのでたどらない。
    // 入れ物でない部品（複合部品など）は、その部品の Enabled だけを変える
    if (C is TWinControl) and not (C is TCCheckGroupBox)
      and (csAcceptsControls in C.ControlStyle) then
      DisableTree(TWinControl(C));
  end;
end;

procedure TCCheckGroupBox.DisableOne(AControl: TControl);
begin
  if IsSaved(AControl) then Exit;
  // 元の Enabled を記録してから無効にする。部品が破棄されたら記録から外せるよう通知を受ける
  if FSavedCount >= Length(FSaved) then
    SetLength(FSaved, FSavedCount * 2 + 8);
  FSaved[FSavedCount].Control := AControl;
  FSaved[FSavedCount].Enabled := AControl.Enabled;
  Inc(FSavedCount);
  AControl.FreeNotification(Self);
  AControl.Enabled := False;
end;

function TCCheckGroupBox.IsSaved(AControl: TControl): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FSavedCount - 1 do
    if FSaved[I].Control = AControl then Exit(True);
end;

procedure TCCheckGroupBox.RestoreAll;
var
  I: Integer;
  C: TControl;
begin
  // 記録を後ろから順に、元の Enabled に戻す（中の部品から先に戻す）
  for I := FSavedCount - 1 downto 0 do
  begin
    C := FSaved[I].Control;
    if C = nil then Continue;   // 無効にしている間に破棄された部品
    C.Enabled := FSaved[I].Enabled;
    C.RemoveFreeNotification(Self);
  end;
  FSavedCount := 0;
  SetLength(FSaved, 0);
end;

procedure TCCheckGroupBox.CMCheckEnabledChanged(var Message: TLMessage);
begin
  inherited;
  // 本体の Enabled にチェックボックスを合わせ、内側の部品の有効／無効を判定し直す
  if FCheckBox <> nil then
    FCheckBox.Enabled := Enabled;
  UpdateInnerEnabled;
end;

procedure TCCheckGroupBox.CMCheckControlChange(var Message: TLMessage);
var
  C: TControl;
begin
  inherited;
  // 内側を無効にしている間に、直下へ部品が追加されたら、その部品も記録して無効にする
  if FInnerDisabled and (Message.LParam <> 0) then
  begin
    C := TControl(Message.WParam);
    if (C <> nil) and (C <> FCheckBox) then
      DisableOne(C);
  end;
end;

procedure TCCheckGroupBox.Notification(AComponent: TComponent; Operation: TOperation);
var
  I: Integer;
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then Exit;
  if AComponent = FCheckBox then
    FCheckBox := nil;
  // 記録した部品が破棄されたら、記録から外す（戻すときに触らない）
  for I := 0 to FSavedCount - 1 do
    if FSaved[I].Control = AComponent then
      FSaved[I].Control := nil;
end;

procedure TCCheckGroupBox.GetChildren(Proc: TGetChildProc; Root: TComponent);
var
  I: Integer;
  C: TControl;
begin
  // .lfm（ストリーム）へ書く子から、見出しのチェックボックスを除く
  // （本体自身をストリームの起点にしたときも、チェックボックスが書かれないようにする）
  for I := 0 to ControlCount - 1 do
  begin
    C := Controls[I];
    if (C <> FCheckBox) and (C.Owner = Root) then
      Proc(C);
  end;
end;

procedure TCCheckGroupBox.Loaded;
begin
  inherited Loaded;
  // 子の部品がすべて読み込まれてから、チェックボックスの表示と内側の有効／無効を合わせる
  SyncCheckBox;
  UpdateCheckBoxBounds;
  UpdateInnerEnabled;
end;

end.
