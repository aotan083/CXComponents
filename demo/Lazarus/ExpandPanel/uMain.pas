{ ExpandPanel 確認用アプリ
  TCExpandPanel・TCRollout の動作確認（設計書：docs\TCExpandPanel_Design.md）。
  フォームはコードで作る（.lfm なし）。
  引数 --selftest：自動チェックを行い、結果を selftest.log に、画面を shot_*.png に書いて終了する。 }
unit uMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, LCLType, LMessages, Graphics, Controls, Forms, StdCtrls,
  ExtCtrls, Menus, ImgList, Types,
  uCExpandPanel;

type
  TMainForm = class(TForm)
  private
    EP: TCExpandPanel;
    R1, R2, R3, R4: TCRollout;
    SideBottom, SideLeft: TCRollout;
    LB1, LB2, LB3: TListBox;
    Img: TImageList;
    Pop: TPopupMenu;
    Memo: TMemo;
    ChkMultiple, ChkAnimated, ChkHover, ChkScroll, ChkHorz: TCheckBox;
    BtnAdd, BtnRemove: TButton;
    Extra: TList;
    EvLog: TStringList;
    BlockExpand: Boolean;
    Results: TStringList;
    procedure AddBtn(R: TCRollout; AImage: Integer; const AHint: string; AMenu: TPopupMenu);
    procedure BuildImages;
    procedure BuildUI;
    procedure Log(const S: string);
    procedure RolloutExpanding(Sender: TObject; var Allow: Boolean);
    procedure RolloutExpand(Sender: TObject);
    procedure RolloutCollapse(Sender: TObject);
    procedure RolloutButtonClick(Sender: TObject; Index: Integer);
    procedure OptionChange(Sender: TObject);
    procedure AddClick(Sender: TObject);
    procedure RemoveClick(Sender: TObject);
    procedure MenuClick(Sender: TObject);
    // 自動チェック
    procedure SelfTestTimer(Sender: TObject);
    procedure Check(const AName: string; ACond: Boolean; const AInfo: string = '');
    procedure Pump(AMs: Integer);
    procedure Shot(const AName: string);
    procedure SimMove(C: TControl; X, Y: Integer);
    procedure SimClick(C: TControl; X, Y: Integer);
    procedure RunSelfTest;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainForm: TMainForm;

implementation

constructor TMainForm.Create(AOwner: TComponent);
var
  T: TTimer;
begin
  CreateNew(AOwner);
  Caption := 'ExpandPanel test';
  Width := 900;
  Height := 700;
  Position := poScreenCenter;
  Extra := TList.Create;
  EvLog := TStringList.Create;
  Results := TStringList.Create;
  BuildImages;
  BuildUI;
  if (ParamCount >= 1) and (ParamStr(1) = '--selftest') then
  begin
    T := TTimer.Create(Self);
    T.Interval := 800;
    T.OnTimer := @SelfTestTimer;
  end;
end;

destructor TMainForm.Destroy;
begin
  Extra.Free;
  EvLog.Free;
  Results.Free;
  inherited Destroy;
end;

procedure TMainForm.AddBtn(R: TCRollout; AImage: Integer; const AHint: string;
  AMenu: TPopupMenu);
var
  B: TCRolloutButton;
begin
  B := TCRolloutButton(R.Buttons.Add);
  B.ImageIndex := AImage;
  B.Hint := AHint;
  B.DropDownMenu := AMenu;
end;

procedure TMainForm.BuildImages;
var
  B: TBitmap;
  procedure NewBmp;
  begin
    B := TBitmap.Create;
    B.SetSize(16, 16);
    B.Canvas.Brush.Color := clFuchsia;
    B.Canvas.FillRect(0, 0, 16, 16);
    B.Canvas.Pen.Color := clBlack;
    B.Canvas.Pen.Width := 2;
  end;
begin
  Img := TImageList.Create(Self);
  Img.Width := 16;
  Img.Height := 16;
  // 0: ＋
  NewBmp;
  B.Canvas.Line(3, 8, 13, 8);
  B.Canvas.Line(8, 3, 8, 13);
  Img.AddMasked(B, clFuchsia);
  B.Free;
  // 1: フォルダー
  NewBmp;
  B.Canvas.Pen.Width := 1;
  B.Canvas.Brush.Color := clWhite;
  B.Canvas.Rectangle(2, 5, 14, 13);
  B.Canvas.Rectangle(2, 3, 7, 6);
  Img.AddMasked(B, clFuchsia);
  B.Free;
  // 2: …
  NewBmp;
  B.Canvas.Brush.Color := clBlack;
  B.Canvas.Pen.Width := 1;
  B.Canvas.Rectangle(2, 7, 5, 10);
  B.Canvas.Rectangle(7, 7, 10, 10);
  B.Canvas.Rectangle(12, 7, 15, 10);
  Img.AddMasked(B, clFuchsia);
  B.Free;
end;

procedure TMainForm.BuildUI;
var
  Right: TPanel;
  Lbl: TLabel;
  Btn: TButton;
  I: Integer;
  MI: TMenuItem;
begin
  Pop := TPopupMenu.Create(Self);
  for I := 1 to 2 do
  begin
    MI := TMenuItem.Create(Pop);
    MI.Caption := 'Initialize Template Directory ' + IntToStr(I);
    MI.OnClick := @MenuClick;
    Pop.Items.Add(MI);
  end;

  EP := TCExpandPanel.Create(Self);
  EP.Parent := Self;
  EP.Align := alLeft;
  EP.Width := 320;

  R1 := TCRollout.Create(Self);
  R1.Caption := '開いているエディター';
  R1.ExpandedSize := 90;
  EP.AddPanel(R1);
  LB1 := TListBox.Create(Self);
  LB1.Parent := R1;
  LB1.Align := alClient;
  LB1.Items.Add('cdb.py');
  LB1.Items.Add('main.pas');

  R2 := TCRollout.Create(Self);
  R2.Caption := 'ファイル';
  R2.Fill := True;
  EP.AddPanel(R2);
  LB2 := TListBox.Create(Self);
  LB2.Parent := R2;
  LB2.Align := alClient;
  for I := 1 to 30 do LB2.Items.Add('file ' + IntToStr(I));

  R3 := TCRollout.Create(Self);
  R3.Caption := 'アウトライン';
  R3.Fill := True;
  EP.AddPanel(R3);
  LB3 := TListBox.Create(Self);
  LB3.Parent := R3;
  LB3.Align := alClient;
  for I := 1 to 10 do LB3.Items.Add('symbol ' + IntToStr(I));

  R4 := TCRollout.Create(Self);
  R4.Caption := 'FPC Projects';
  R4.ExpandedSize := 120;
  R4.Images := Img;
  R4.ButtonsShow := bsHover;
  R4.ShowHint := True;
  AddBtn(R4, 0, 'New', nil);
  AddBtn(R4, 1, 'Open', nil);
  AddBtn(R4, 2, 'More', Pop);
  EP.AddPanel(R4);
  Lbl := TLabel.Create(Self);
  Lbl.Parent := R4;
  Lbl.Caption := 'No project files found.';
  Lbl.SetBounds(8, 34, 200, 20);
  Btn := TButton.Create(Self);
  Btn.Parent := R4;
  Btn.Caption := 'Create New Project';
  Btn.SetBounds(8, 64, 200, 28);

  for I := 0 to EP.PanelCount - 1 do
  begin
    EP.Panels[I].OnExpanding := @RolloutExpanding;
    EP.Panels[I].OnExpand := @RolloutExpand;
    EP.Panels[I].OnCollapse := @RolloutCollapse;
    EP.Panels[I].OnButtonClick := @RolloutButtonClick;
  end;

  // 右側：設定・単体のパネル・ログ
  Right := TPanel.Create(Self);
  Right.Parent := Self;
  Right.Align := alClient;
  Right.BevelOuter := bvNone;

  SideBottom := TCRollout.Create(Self);
  SideBottom.Parent := Right;
  SideBottom.Align := alBottom;
  SideBottom.HeaderPosition := hpBottom;
  SideBottom.Caption := '単体・下タイトル';
  SideBottom.ExpandedSize := 100;
  SideBottom.Images := Img;
  AddBtn(SideBottom, 0, 'add', nil);
  Lbl := TLabel.Create(Self);
  Lbl.Parent := SideBottom;
  Lbl.Caption := 'hpBottom の中身';
  Lbl.SetBounds(8, 8, 200, 20);

  SideLeft := TCRollout.Create(Self);
  SideLeft.Parent := Right;
  SideLeft.Align := alLeft;
  SideLeft.HeaderPosition := hpLeft;
  SideLeft.Caption := '単体・左タイトル';
  SideLeft.ExpandedSize := 160;
  SideLeft.Images := Img;
  AddBtn(SideLeft, 1, 'open', nil);
  Lbl := TLabel.Create(Self);
  Lbl.Parent := SideLeft;
  Lbl.Caption := 'hpLeft の中身';
  Lbl.SetBounds(8, 8, 120, 20);

  ChkMultiple := TCheckBox.Create(Self);
  ChkMultiple.Parent := Right;
  ChkMultiple.Caption := 'Multiple';
  ChkMultiple.Checked := True;
  ChkMultiple.SetBounds(200, 8, 120, 20);
  ChkAnimated := TCheckBox.Create(Self);
  ChkAnimated.Parent := Right;
  ChkAnimated.Caption := 'Animated';
  ChkAnimated.Checked := True;
  ChkAnimated.SetBounds(200, 32, 120, 20);
  ChkHover := TCheckBox.Create(Self);
  ChkHover.Parent := Right;
  ChkHover.Caption := 'ButtonsShow = bsHover';
  ChkHover.Checked := True;
  ChkHover.SetBounds(200, 56, 200, 20);
  ChkScroll := TCheckBox.Create(Self);
  ChkScroll.Parent := Right;
  ChkScroll.Caption := 'Scrollable';
  ChkScroll.Checked := True;
  ChkScroll.SetBounds(200, 80, 120, 20);
  ChkHorz := TCheckBox.Create(Self);
  ChkHorz.Parent := Right;
  ChkHorz.Caption := 'Orientation = Horizontal';
  ChkHorz.SetBounds(200, 104, 220, 20);
  ChkMultiple.OnChange := @OptionChange;
  ChkAnimated.OnChange := @OptionChange;
  ChkHover.OnChange := @OptionChange;
  ChkScroll.OnChange := @OptionChange;
  ChkHorz.OnChange := @OptionChange;

  BtnAdd := TButton.Create(Self);
  BtnAdd.Parent := Right;
  BtnAdd.Caption := 'パネルを追加';
  BtnAdd.SetBounds(200, 136, 120, 28);
  BtnAdd.OnClick := @AddClick;
  BtnRemove := TButton.Create(Self);
  BtnRemove.Parent := Right;
  BtnRemove.Caption := '追加分を削除';
  BtnRemove.SetBounds(330, 136, 120, 28);
  BtnRemove.OnClick := @RemoveClick;

  Memo := TMemo.Create(Self);
  Memo.Parent := Right;
  Memo.SetBounds(200, 176, 300, 200);
  Memo.Anchors := [akLeft, akTop, akRight];
  Memo.ScrollBars := ssAutoVertical;
end;

procedure TMainForm.Log(const S: string);
begin
  if Memo <> nil then
    Memo.Lines.Add(S);
  EvLog.Add(S);
end;

procedure TMainForm.RolloutExpanding(Sender: TObject; var Allow: Boolean);
begin
  Log('Expanding ' + (Sender as TCRollout).Caption);
  if BlockExpand then Allow := False;
end;

procedure TMainForm.RolloutExpand(Sender: TObject);
begin
  Log('Expand ' + (Sender as TCRollout).Caption);
end;

procedure TMainForm.RolloutCollapse(Sender: TObject);
begin
  Log('Collapse ' + (Sender as TCRollout).Caption);
end;

procedure TMainForm.RolloutButtonClick(Sender: TObject; Index: Integer);
begin
  Log('ButtonClick ' + (Sender as TCRollout).Caption + ' #' + IntToStr(Index));
end;

procedure TMainForm.MenuClick(Sender: TObject);
begin
  Log('Menu ' + (Sender as TMenuItem).Caption);
end;

procedure TMainForm.OptionChange(Sender: TObject);
begin
  EP.Multiple := ChkMultiple.Checked;
  R1.Animated := ChkAnimated.Checked;
  R2.Animated := ChkAnimated.Checked;
  R3.Animated := ChkAnimated.Checked;
  R4.Animated := ChkAnimated.Checked;
  if ChkHover.Checked then R4.ButtonsShow := bsHover else R4.ButtonsShow := bsAlways;
  EP.Scrollable := ChkScroll.Checked;
  if ChkHorz.Checked then
  begin
    EP.Orientation := eoHorizontal;
    EP.Align := alTop;
    EP.Height := 300;
  end
  else
  begin
    EP.Orientation := eoVertical;
    EP.Align := alLeft;
    EP.Width := 320;
  end;
end;

procedure TMainForm.AddClick(Sender: TObject);
var
  R: TCRollout;
begin
  R := TCRollout.Create(Self);
  R.Caption := 'Extra ' + IntToStr(Extra.Count + 1);
  R.ExpandedSize := 100;
  EP.AddPanel(R);
  Extra.Add(R);
end;

procedure TMainForm.RemoveClick(Sender: TObject);
begin
  while Extra.Count > 0 do
  begin
    TCRollout(Extra[Extra.Count - 1]).Free;
    Extra.Delete(Extra.Count - 1);
  end;
end;

{ ---- 自動チェック ---- }

procedure TMainForm.Check(const AName: string; ACond: Boolean; const AInfo: string);
begin
  if ACond then
    Results.Add('OK  ' + AName)
  else
    Results.Add('NG  ' + AName + '  ' + AInfo);
end;

procedure TMainForm.Pump(AMs: Integer);
var
  T0: QWord;
begin
  T0 := GetTickCount64;
  while GetTickCount64 - T0 < QWord(AMs) do
  begin
    Application.ProcessMessages;
    Sleep(5);
  end;
end;

procedure TMainForm.Shot(const AName: string);
var
  Bmp: TBitmap;
  Png: TPortableNetworkGraphic;
begin
  Bmp := GetFormImage;
  Png := TPortableNetworkGraphic.Create;
  try
    Png.Assign(Bmp);
    Png.SaveToFile(ExtractFilePath(ParamStr(0)) + 'shot_' + AName + '.png');
  finally
    Png.Free;
    Bmp.Free;
  end;
end;

procedure TMainForm.SimMove(C: TControl; X, Y: Integer);
begin
  C.Perform(LM_MOUSEMOVE, 0, (Y shl 16) or (X and $FFFF));
end;

procedure TMainForm.SimClick(C: TControl; X, Y: Integer);
begin
  SimMove(C, X, Y);
  C.Perform(LM_LBUTTONDOWN, 0, (Y shl 16) or (X and $FFFF));
  C.Perform(LM_LBUTTONUP, 0, (Y shl 16) or (X and $FFFF));
end;

procedure TMainForm.SelfTestTimer(Sender: TObject);
begin
  TTimer(Sender).Enabled := False;
  try
    RunSelfTest;
  except
    on E: Exception do
      Results.Add('EXC ' + E.ClassName + ': ' + E.Message);
  end;
  Results.SaveToFile(ExtractFilePath(ParamStr(0)) + 'selftest.log');
  Application.Terminate;
end;

procedure TMainForm.RunSelfTest;
var
  I, H, Y, E, Sum, TopBefore, Hd: Integer;
begin
  Hd := R1.HeaderSize;
  // ---- アニメーションなしで配置を確認 ----
  for I := 0 to EP.PanelCount - 1 do EP.Panels[I].Animated := False;
  Application.ProcessMessages;
  Shot('01_initial');
  H := EP.ClientHeight;
  Check('T1 R1 高さ=ExpandedSize', R1.Height = R1.ExpandedSize, 'H=' + IntToStr(R1.Height));
  Check('T1 R2 は R1 の直下', R2.Top = R1.Top + R1.Height, 'Top=' + IntToStr(R2.Top));
  Check('T1 R4 の下端=入れ物の高さ（Fill が余りを埋める）',
    R4.Top + R4.Height = H, 'bottom=' + IntToStr(R4.Top + R4.Height) + ' H=' + IntToStr(H));
  Check('T1 R2・R3 の高さがほぼ同じ', Abs(R2.Height - R3.Height) <= 1,
    IntToStr(R2.Height) + '/' + IntToStr(R3.Height));
  Check('T1 パネルの幅=入れ物の幅', R1.Width = EP.ClientWidth);

  // ---- 閉じる ----
  EvLog.Clear;
  R2.Expanded := False;
  Check('T2 R2 閉じると高さ=HeaderSize', R2.Height = Hd, IntToStr(R2.Height));
  Check('T2 R3 が広がる', R3.Height > R2.Height);
  Check('T2 R4 の下端が変わらない', R4.Top + R4.Height = H);
  Check('T2 イベント順', (EvLog.Count = 2) and (EvLog[0] = 'Expanding ファイル') and
    (EvLog[1] = 'Collapse ファイル'), EvLog.CommaText);
  Shot('02_collapsed');
  R2.Expanded := True;
  Check('T2 R2 開くと元に戻る', Abs(R2.Height - R3.Height) <= 1);

  // ---- OnExpanding で取りやめ ----
  BlockExpand := True;
  R1.Expanded := False;      // 閉じる操作も OnExpanding を通る
  Check('T3 Allow=False で取りやめ', R1.Expanded = True);
  BlockExpand := False;

  // ---- Multiple = False ----
  EP.Multiple := False;
  Check('T4 Multiple=False で開いているのは 1 つだけ',
    Ord(R1.Expanded) + Ord(R2.Expanded) + Ord(R3.Expanded) + Ord(R4.Expanded) = 1);
  R3.Expanded := True;
  Check('T4 R3 を開くと他が閉じる', R3.Expanded and (not R1.Expanded) and (not R2.Expanded) and
    (not R4.Expanded));
  EP.Multiple := True;
  R1.Expanded := True; R2.Expanded := True; R4.Expanded := True;

  // ---- ヘッダーをクリックして開閉（マウス操作の模擬）----
  Y := Hd div 2;
  SimClick(R1, 40, Y);
  Check('T5 ヘッダークリックで閉じる', not R1.Expanded);
  SimClick(R1, 40, Y);
  Check('T5 もう一度で開く', R1.Expanded);

  // ---- ボタンのクリック（bsHover：先にマウスを乗せる）----
  EvLog.Clear;
  SimMove(R4, 40, Y);
  Shot('03_hover_buttons');
  E := R4.Width - R4.Scale96ToFont(4);
  SimClick(R4, E - R4.Scale96ToFont(10) - R4.Scale96ToFont(22) * 2, Y);   // ボタン 0
  Check('T6 ボタン 0 を押すと OnButtonClick(0)',
    (EvLog.Count = 1) and (EvLog[0] = 'ButtonClick FPC Projects #0'), EvLog.CommaText);
  SimClick(R4, E - R4.Scale96ToFont(10) - R4.Scale96ToFont(22), Y);       // ボタン 1
  Check('T6 ボタン 1 を押すと OnButtonClick(1)',
    (EvLog.Count = 2) and (EvLog[1] = 'ButtonClick FPC Projects #1'), EvLog.CommaText);
  Check('T6 ボタンのあとヘッダーは開閉しない', R4.Expanded);
  R4.Perform(CM_MOUSELEAVE, 0, 0);

  // ---- スクロール ----
  EP.Scrollable := True;
  for I := 1 to 8 do AddClick(nil);
  for I := 0 to EP.PanelCount - 1 do EP.Panels[I].Animated := False;
  Application.ProcessMessages;
  Shot('04_many_panels');
  Check('T7 パネルが溢れる', EP.Panels[EP.PanelCount - 1].Top + EP.Panels[EP.PanelCount - 1].Height > EP.ClientHeight);
  TopBefore := R1.Top;
  EP.Perform(LM_VSCROLL, SB_BOTTOM, 0);
  Application.ProcessMessages;
  Check('T7 SB_BOTTOM で上へずれる', R1.Top < TopBefore, 'Top=' + IntToStr(R1.Top));
  Check('T7 最後のパネルの下端=入れ物の高さ',
    EP.Panels[EP.PanelCount - 1].Top + EP.Panels[EP.PanelCount - 1].Height = EP.ClientHeight,
    IntToStr(EP.Panels[EP.PanelCount - 1].Top + EP.Panels[EP.PanelCount - 1].Height));
  Shot('05_scrolled');
  EP.Perform(LM_VSCROLL, SB_TOP, 0);
  Application.ProcessMessages;
  Check('T7 SB_TOP で元に戻る', R1.Top = 0, 'Top=' + IntToStr(R1.Top));
  EP.Scrollable := False;
  Application.ProcessMessages;
  Check('T7 Scrollable=False で位置 0', R1.Top = 0);
  EP.Scrollable := True;
  RemoveClick(nil);
  Application.ProcessMessages;
  Check('T7 追加分を消すと元の配置', R4.Top + R4.Height = EP.ClientHeight);

  // ---- アニメーション ----
  R1.Animated := True;
  R1.AnimationTime := 300;
  R1.Expanded := False;
  Pump(120);
  Check('T8 アニメーション途中の大きさ', (R1.Height > Hd) and (R1.Height < R1.ExpandedSize),
    'H=' + IntToStr(R1.Height));
  Pump(500);
  Check('T8 アニメーション終了で閉じた大きさ', R1.Height = Hd, 'H=' + IntToStr(R1.Height));
  R1.Expanded := True;
  Pump(600);
  Check('T8 開いて元の大きさ', R1.Height = R1.ExpandedSize, 'H=' + IntToStr(R1.Height));
  Check('T8 ExpandedSize を壊していない', R1.ExpandedSize = 90, IntToStr(R1.ExpandedSize));

  // ---- 単体のパネル ----
  SideLeft.Animated := False;
  SideBottom.Animated := False;
  SideLeft.Expanded := False;
  Check('T9 hpLeft 単体を閉じると幅=HeaderSize', SideLeft.Width = SideLeft.HeaderSize,
    IntToStr(SideLeft.Width));
  SideLeft.Expanded := True;
  Check('T9 開くと幅=ExpandedSize', SideLeft.Width = SideLeft.ExpandedSize);
  SideBottom.Expanded := False;
  Check('T9 hpBottom 単体を閉じると高さ=HeaderSize', SideBottom.Height = SideBottom.HeaderSize,
    IntToStr(SideBottom.Height));
  SideBottom.Expanded := True;
  Check('T9 開くと高さ=ExpandedSize', SideBottom.Height = SideBottom.ExpandedSize);

  // ---- パネルの順番・削除 ----
  EP.MovePanel(0, 1);
  Check('T10 MovePanel', (EP.Panels[0] = R2) and (EP.Panels[1] = R1) and (R2.Top = 0));
  EP.MovePanel(1, 0);
  Check('T10 戻す', EP.Panels[0] = R1);
  EP.RemovePanel(R3);
  Check('T10 RemovePanel で入れ物から外れる', (EP.PanelCount = 3) and (R3.ExpandPanel = nil));
  EP.InsertPanel(2, R3);
  Check('T10 InsertPanel', (EP.PanelCount = 4) and (EP.Panels[2] = R3));

  // ---- 横並び ----
  EP.Orientation := eoHorizontal;
  EP.Align := alTop;
  EP.Height := 260;
  Application.ProcessMessages;
  Sum := 0;
  for I := 0 to EP.PanelCount - 1 do Sum := Sum + EP.Panels[I].Width;
  Check('T11 横並びの幅の合計=入れ物の幅（Fill が埋める）', Sum = EP.ClientWidth,
    IntToStr(Sum) + ' / ' + IntToStr(EP.ClientWidth));
  Check('T11 パネルの高さ=入れ物の高さ', R1.Height = EP.ClientHeight);
  Shot('06_horizontal');
  EP.Orientation := eoVertical;
  EP.Align := alLeft;
  EP.Width := 320;
  Application.ProcessMessages;
  Check('T11 縦に戻す', R4.Top + R4.Height = EP.ClientHeight);
  Shot('07_final');
  EvLog.Clear;
end;

end.
