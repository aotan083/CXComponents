{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ TCMFindDialog - TCMonacoEditor 用の検索・置換ダイアログ（非表示の部品。TOpenDialog と同じ扱い）

  ・通常は、フォームに貼る必要はない。FindDialog を設定しない TCMonacoEditor は、
    フォームに1つだけの、内蔵の共有ダイアログを自動で使う。
  ・自分で制御したいときだけ、パレットからフォームに1つ貼り、各エディタの FindDialog プロパティで選ぶ。
    複数のエディタが、同じダイアログを選べる。
  ・対象は、Ctrl+F を押したエディタ。開いたまま別のエディタをクリックすると、対象が切り替わる。
  ・ダイアログの位置、検索語、置換語、履歴、オプションは、このダイアログを使う全エディタで共通。
  ・画面は、コードだけで作る（.lfm は不要）。 }
unit CMonacoFindDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ucmmonacoview;

type
  TCMFindDialog = class;

  { TCMFindForm : ダイアログの画面（内部用） }

  TCMFindForm = class(TForm)
  private
    FDlg: TCMFindDialog;
    FCmbFind, FCmbReplace: TComboBox;
    FChkCase, FChkWord, FChkLoop: TCheckBox;
    FLblStatus: TLabel;
    FShownOnce: Boolean;
    function AddLabel(const ACaption: string; X, Y: Integer): TLabel;
    function AddButton(const ACaption: string; Y: Integer; AClick: TNotifyEvent): TButton;
    function AddCheck(const ACaption: string; Y: Integer): TCheckBox;
    function GetOptions: TCMFindOptions;
    procedure SetOptions(AValue: TCMFindOptions);
    procedure RefreshHistory;
    function Prepare: Boolean;
    procedure NextClick(Sender: TObject);
    procedure PrevClick(Sender: TObject);
    procedure ReplaceClick(Sender: TObject);
    procedure ReplaceAllClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
  public
    constructor CreateFor(ADlg: TCMFindDialog);
  end;

  { TCMFindDialog }

  TCMFindDialog = class(TComponent)
  private
    FForm: TCMFindForm;
    FTarget: TCMMonacoView;
    FFindHistory, FReplaceHistory: TStringList;
    FSearchText, FReplaceText: string;
    FOptions: TCMFindOptions;
    function GetForm: TCMFindForm;
    procedure SetTarget(AValue: TCMMonacoView);
    procedure AddHistory(AList: TStringList; const S: string);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { 対象のエディタでダイアログを開く。InitialText が空なら、前回の検索語を使う }
    procedure ShowFor(AEditor: TCMMonacoView; const InitialText: string = '');
    procedure CloseDialog;
    function IsShowing: Boolean;
    { タイトル（対象のファイル名）を更新する }
    procedure UpdateCaption;
    { エディタからの結果の通知（TCMonacoEditor が呼ぶ） }
    procedure NotifyFindDone(AEditor: TCMMonacoView; Found: Boolean);
    procedure NotifyReplaceAllDone(AEditor: TCMMonacoView; Count: Integer);

    property Target: TCMMonacoView read FTarget write SetTarget;
    property SearchText: string read FSearchText;           { 直前の検索語（全エディタで共通） }
    property ReplaceText: string read FReplaceText;
    property Options: TCMFindOptions read FOptions;
    property FindHistory: TStringList read FFindHistory;
    property ReplaceHistory: TStringList read FReplaceHistory;
  end;

implementation

const
  MAX_HISTORY = 30;

{ ---------- TCMFindForm ---------- }

constructor TCMFindForm.CreateFor(ADlg: TCMFindDialog);
begin
  inherited CreateNew(ADlg);
  FDlg := ADlg;

  Caption := '検索・置換';
  BorderStyle := bsDialog;
  ClientWidth := 470;
  ClientHeight := 190;
  Position := poDesigned;

  AddLabel('検索(&F):', 12, 16);
  FCmbFind := TComboBox.Create(Self);
  FCmbFind.Parent := Self;
  FCmbFind.SetBounds(80, 12, 250, 24);

  AddLabel('置換(&R):', 12, 52);
  FCmbReplace := TComboBox.Create(Self);
  FCmbReplace.Parent := Self;
  FCmbReplace.SetBounds(80, 48, 250, 24);

  FChkCase := AddCheck('大文字小文字を区別する(&C)', 88);
  FChkWord := AddCheck('単語単位で検索(&W)', 112);
  FChkLoop := AddCheck('ループ検索(&L)', 136);
  SetOptions(FDlg.Options);

  AddButton('次を検索(&N)', 10, @NextClick).Default := True;
  AddButton('前を検索(&P)', 42, @PrevClick);
  AddButton('置換(&E)', 74, @ReplaceClick);
  AddButton('すべて置換(&A)', 106, @ReplaceAllClick);
  AddButton('閉じる', 146, @CloseClick).Cancel := True;

  FLblStatus := AddLabel('', 80, 166);
end;

function TCMFindForm.AddLabel(const ACaption: string; X, Y: Integer): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := Self;
  Result.Caption := ACaption;
  Result.SetBounds(X, Y, 60, 16);
  Result.AutoSize := True;
end;

function TCMFindForm.AddButton(const ACaption: string; Y: Integer; AClick: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := Self;
  Result.Caption := ACaption;
  Result.SetBounds(345, Y, 115, 28);
  Result.OnClick := AClick;
end;

function TCMFindForm.AddCheck(const ACaption: string; Y: Integer): TCheckBox;
begin
  Result := TCheckBox.Create(Self);
  Result.Parent := Self;
  Result.Caption := ACaption;
  Result.SetBounds(80, Y, 250, 20);
end;

function TCMFindForm.GetOptions: TCMFindOptions;
begin
  Result := [];
  if FChkCase.Checked then Include(Result, foMatchCase);
  if FChkWord.Checked then Include(Result, foWholeWord);
  if FChkLoop.Checked then Include(Result, foLoop);
end;

procedure TCMFindForm.SetOptions(AValue: TCMFindOptions);
begin
  FChkCase.Checked := foMatchCase in AValue;
  FChkWord.Checked := foWholeWord in AValue;
  FChkLoop.Checked := foLoop in AValue;
end;

procedure TCMFindForm.RefreshHistory;
var
  F, R: string;
begin
  F := FCmbFind.Text;
  R := FCmbReplace.Text;
  FCmbFind.Items.Assign(FDlg.FindHistory);
  FCmbReplace.Items.Assign(FDlg.ReplaceHistory);
  FCmbFind.Text := F;
  FCmbReplace.Text := R;
end;

function TCMFindForm.Prepare: Boolean;
begin
  Result := (FDlg.Target <> nil) and (FCmbFind.Text <> '');
  if not Result then Exit;
  { 検索語・置換語・オプションは、ダイアログ側で覚える（全エディタで共通） }
  FDlg.FSearchText := FCmbFind.Text;
  FDlg.FReplaceText := FCmbReplace.Text;
  FDlg.FOptions := GetOptions;
  FDlg.AddHistory(FDlg.FindHistory, FCmbFind.Text);
  if FCmbReplace.Text <> '' then FDlg.AddHistory(FDlg.ReplaceHistory, FCmbReplace.Text);
  RefreshHistory;
  FLblStatus.Caption := '';
end;

procedure TCMFindForm.NextClick(Sender: TObject);
begin
  if Prepare then FDlg.Target.Find(FDlg.SearchText, FDlg.Options, True);
end;

procedure TCMFindForm.PrevClick(Sender: TObject);
begin
  if Prepare then FDlg.Target.Find(FDlg.SearchText, FDlg.Options, False);
end;

procedure TCMFindForm.ReplaceClick(Sender: TObject);
begin
  if Prepare then FDlg.Target.Replace(FDlg.SearchText, FDlg.ReplaceText, FDlg.Options);
end;

procedure TCMFindForm.ReplaceAllClick(Sender: TObject);
begin
  if Prepare then FDlg.Target.ReplaceAll(FDlg.SearchText, FDlg.ReplaceText, FDlg.Options);
end;

procedure TCMFindForm.CloseClick(Sender: TObject);
begin
  Close;
end;

{ ---------- TCMFindDialog ---------- }

constructor TCMFindDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FFindHistory := TStringList.Create;
  FReplaceHistory := TStringList.Create;
  FOptions := [foLoop];
end;

destructor TCMFindDialog.Destroy;
begin
  SetTarget(nil);
  FFindHistory.Free;
  FReplaceHistory.Free;
  inherited Destroy;       { FForm は Owner(Self) が解放する }
end;

procedure TCMFindDialog.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then Exit;
  if AComponent = FTarget then
  begin
    FTarget := nil;
    if (FForm <> nil) and not (csDestroying in ComponentState) then UpdateCaption;
  end
  else if AComponent = FForm then
    FForm := nil;
end;

function TCMFindDialog.GetForm: TCMFindForm;
begin
  if FForm = nil then
  begin
    FForm := TCMFindForm.CreateFor(Self);
    FForm.FreeNotification(Self);
  end;
  Result := FForm;
end;

procedure TCMFindDialog.SetTarget(AValue: TCMMonacoView);
begin
  if FTarget = AValue then Exit;
  if FTarget <> nil then FTarget.RemoveFreeNotification(Self);
  FTarget := AValue;
  if FTarget <> nil then FTarget.FreeNotification(Self);
  if FForm <> nil then UpdateCaption;
end;

procedure TCMFindDialog.AddHistory(AList: TStringList; const S: string);
var
  I: Integer;
begin
  if S = '' then Exit;
  I := AList.IndexOf(S);
  if I >= 0 then AList.Delete(I);
  AList.Insert(0, S);
  while AList.Count > MAX_HISTORY do AList.Delete(AList.Count - 1);
end;

procedure TCMFindDialog.UpdateCaption;
var
  S: string;
begin
  if FForm = nil then Exit;
  S := '検索・置換';
  if (FTarget <> nil) and (FTarget.DocumentCount > 0) and (FTarget.ActiveIndex >= 0) then
    S := S + ' - ' + FTarget.DocumentTitle[FTarget.ActiveIndex];
  FForm.Caption := S;
end;

procedure TCMFindDialog.ShowFor(AEditor: TCMMonacoView; const InitialText: string);
var
  F: TCMFindForm;
  PF: TCustomForm;
begin
  SetTarget(AEditor);
  F := GetForm;
  if InitialText <> '' then
    F.FCmbFind.Text := InitialText
  else if F.FCmbFind.Text = '' then
    F.FCmbFind.Text := FSearchText;
  F.RefreshHistory;
  F.FLblStatus.Caption := '';
  UpdateCaption;

  PF := nil;
  if AEditor <> nil then PF := GetParentForm(AEditor);
  if PF <> nil then
  begin
    F.PopupMode := pmExplicit;
    F.PopupParent := PF;
  end;
  if not F.FShownOnce then
  begin
    { 初回は、エディタのあるフォームの中央。2回目以降は、前回の位置のまま（全エディタで共通） }
    F.Position := poDesigned;
    if PF <> nil then
    begin
      F.Left := PF.Left + (PF.Width - F.Width) div 2;
      F.Top := PF.Top + (PF.Height - F.Height) div 2;
    end
    else
      F.Position := poScreenCenter;
  end;
  F.Show;
  F.FShownOnce := True;
  F.FCmbFind.SetFocus;
  F.FCmbFind.SelectAll;
end;

procedure TCMFindDialog.CloseDialog;
begin
  if FForm <> nil then FForm.Close;
end;

function TCMFindDialog.IsShowing: Boolean;
begin
  Result := (FForm <> nil) and FForm.Visible;
end;

procedure TCMFindDialog.NotifyFindDone(AEditor: TCMMonacoView; Found: Boolean);
begin
  if (FForm = nil) or (AEditor <> FTarget) then Exit;
  if Found then
    FForm.FLblStatus.Caption := ''
  else
    FForm.FLblStatus.Caption := '見つかりません';
end;

procedure TCMFindDialog.NotifyReplaceAllDone(AEditor: TCMMonacoView; Count: Integer);
begin
  if (FForm = nil) or (AEditor <> FTarget) then Exit;
  FForm.FLblStatus.Caption := Format('%d 件置換しました', [Count]);
end;

end.
