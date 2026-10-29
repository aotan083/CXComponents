{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ TCMTabBinder - TCMMonacoView（複数文書）と ATTabs（ATFlatControls）をつなぐ
  ※ 第2版から、TCMonacoEditor（ucmonacos.pas）が内部で使う部品になった。アプリから直接使う必要はない。

  使い方（フォーム側）:
    Binder := TCMTabBinder.Create(Self);
    Binder.Attach(Ed);            // ATTabs を自動生成して Ed の上端に置く
    // フォームに置いた TATTabs を使う場合: Binder.Attach(Ed, ATTabs1);
    FormCloseQuery:  CanClose := Binder.CloseAll;   // 未保存の確認をして全タブを閉じる

  ・タブの「+」で新規文書、「x」で閉じる（未保存なら確認）、ドラッグで並べ替え。
  ・変更ありのタブは名前の後ろに ' *' が付く。
  ・未保存の確認は、Ed.OnQueryClose が未設定のときだけ標準ダイアログを使う。
  ・保存先が未定の文書は Ed.OnNeedFileName でファイル名を渡すこと（渡さないと保存されず閉じない）。 }
unit CMonacoTabs;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, Dialogs, Forms, ATTabs, ucmmonacoview;

type
  { タブのアイコン（画像リストの番号）を決める。-1 でアイコンなし }
  TCMTabImageEvent = procedure(Sender: TObject; Index: Integer; const FileName: string;
    var ImageIndex: Integer) of object;

  TCMTabBinder = class(TComponent)
  private
    FEditor: TCMMonacoView;
    FTabs: TATTabs;
    FUpdating: Boolean;
    FDropHandled: Boolean;
    FFocusPending: Boolean;
    FFocusOnMouseUp: Boolean;
    FOldTabsMouseUp: TMouseEvent;
    FColorActive: TColor;
    FColorOver: TColor;
    FOnGetImageIndex: TCMTabImageEvent;
    FConfirmClose: Boolean;
    FOldDocListChange: TNotifyEvent;
    FOldDocumentChange: TCMDocIndexEvent;
    FOldActiveChange: TNotifyEvent;

    function TabCaptionFor(AIndex: Integer): string;
    procedure RebuildTabs;
    procedure UpdateTab(AIndex: Integer);
    procedure ApplyTabColor(D: TATTabData);
    function ImageIndexFor(AIndex: Integer): Integer;

    procedure EditorDocListChange(Sender: TObject);
    procedure EditorDocumentChange(Sender: TObject; Index: Integer);
    procedure EditorActiveChange(Sender: TObject);
    procedure EditorQueryClose(Sender: TObject; Index: Integer; var CanClose: Boolean);

    procedure TabClick(Sender: TObject);
    procedure TabPlusClick(Sender: TObject);
    procedure TabClose(Sender: TObject; ATabIndex: Integer; var ACanClose, ACanContinue: Boolean);
    procedure TabDropQuery(Sender: TObject; AIndexFrom, AIndexTo: Integer; var ACanDrop: Boolean);
    procedure TabMove(Sender: TObject; AIndexFrom, AIndexTo: Integer);
    procedure AsyncClose(Data: PtrInt);
    procedure AsyncFocus(Data: PtrInt);
    procedure FocusEditorLater;
    procedure TabsMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Attach(AEditor: TCMMonacoView; ATabs: TATTabs = nil);
    function CloseAll: Boolean;   { 未保存の確認をして全文書を閉じる。キャンセルされたら False }
    procedure Refresh;            { タブを作り直す（アイコンの設定を変えたときなど） }
    property OnGetImageIndex: TCMTabImageEvent read FOnGetImageIndex write FOnGetImageIndex;
    property Tabs: TATTabs read FTabs;
    property Editor: TCMMonacoView read FEditor;
    property ConfirmClose: Boolean read FConfirmClose write FConfirmClose;
    { 選択中・マウスを乗せたタブの背景色を、全タブに設定する（フラット表示でも、選択中のタブを浮き上がらせるため） }
    procedure SetTabColors(AActive, AOver: TColor);
  end;

implementation

constructor TCMTabBinder.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FConfirmClose := True;
  FColorActive := clNone;
  FColorOver := clNone;
end;

destructor TCMTabBinder.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  if FEditor <> nil then
  begin
    FEditor.OnDocListChange := FOldDocListChange;
    FEditor.OnDocumentChange := FOldDocumentChange;
    FEditor.OnActiveChange := FOldActiveChange;
  end;
  if FTabs <> nil then FTabs.OnMouseUp := FOldTabsMouseUp;
  inherited Destroy;
end;

procedure TCMTabBinder.Attach(AEditor: TCMMonacoView; ATabs: TATTabs);
begin
  if AEditor = nil then
    raise Exception.Create('TCMTabBinder.Attach: エディタが nil です');
  FEditor := AEditor;
  if ATabs = nil then
  begin
    ATabs := TATTabs.Create(Self);
    ATabs.Parent := AEditor.Parent;
    ATabs.Align := alTop;
  end;
  FTabs := ATabs;
  FTabs.OptShowPlusTab := True;
  FTabs.TabStop := False;                  { タブ自体はキーボードのフォーカスを受け取らない }
  FOldTabsMouseUp := FTabs.OnMouseUp;
  FTabs.OnMouseUp := @TabsMouseUp;         { フォーカスは、マウスのボタンを離したあとでエディタへ戻す }

  FTabs.OnTabClick := @TabClick;
  FTabs.OnTabPlusClick := @TabPlusClick;
  FTabs.OnTabClose := @TabClose;
  FTabs.OnTabDropQuery := @TabDropQuery;
  FTabs.OnTabMove := @TabMove;

  FOldDocListChange := FEditor.OnDocListChange;
  FOldDocumentChange := FEditor.OnDocumentChange;
  FOldActiveChange := FEditor.OnActiveChange;
  FEditor.OnDocListChange := @EditorDocListChange;
  FEditor.OnDocumentChange := @EditorDocumentChange;
  FEditor.OnActiveChange := @EditorActiveChange;
  if FConfirmClose and not Assigned(FEditor.OnQueryClose) then
    FEditor.OnQueryClose := @EditorQueryClose;

  RebuildTabs;
end;

{ ---------- タブ表示の同期 ---------- }

function TCMTabBinder.TabCaptionFor(AIndex: Integer): string;
begin
  Result := FEditor.DocumentTitle[AIndex];
  if FEditor.DocumentModified[AIndex] then Result := Result + ' *';
end;

procedure TCMTabBinder.RebuildTabs;
var
  I: Integer;
  D: TATTabData;
begin
  if (FTabs = nil) or (FEditor = nil) then Exit;
  FUpdating := True;
  try
    FTabs.Clear;
    for I := 0 to FEditor.DocumentCount - 1 do
    begin
      D := FTabs.AddTab(-1, TabCaptionFor(I), nil, FEditor.DocumentModified[I]);
      D.TabHint := FEditor.DocumentFileName[I];
      D.TabImageIndex := ImageIndexFor(I);
      ApplyTabColor(D);
    end;
    if FEditor.ActiveIndex >= 0 then FTabs.TabIndex := FEditor.ActiveIndex;
  finally
    FUpdating := False;
  end;
  FTabs.Invalidate;
end;

procedure TCMTabBinder.ApplyTabColor(D: TATTabData);
begin
  if D = nil then Exit;
  D.TabColorActive := FColorActive;
  D.TabColorOver := FColorOver;
end;

procedure TCMTabBinder.SetTabColors(AActive, AOver: TColor);
var
  I: Integer;
begin
  FColorActive := AActive;
  FColorOver := AOver;
  if FTabs = nil then Exit;
  FTabs.OptShowEntireColor := True;     { タブごとの色（TabColorActive / TabColorOver）を使う }
  for I := 0 to FTabs.TabCount - 1 do
    ApplyTabColor(FTabs.GetTabData(I));
  FTabs.Invalidate;
end;

procedure TCMTabBinder.UpdateTab(AIndex: Integer);
var
  D: TATTabData;
begin
  if (FTabs = nil) or (AIndex < 0) or (AIndex >= FTabs.TabCount) then Exit;
  D := FTabs.GetTabData(AIndex);
  if D = nil then Exit;
  D.TabCaption := TabCaptionFor(AIndex);
  D.TabModified := FEditor.DocumentModified[AIndex];
  D.TabHint := FEditor.DocumentFileName[AIndex];
  D.TabImageIndex := ImageIndexFor(AIndex);   { 名前を付けて保存で拡張子が変わったときも切り替わる }
  FTabs.Invalidate;
end;

function TCMTabBinder.ImageIndexFor(AIndex: Integer): Integer;
begin
  Result := -1;
  if Assigned(FOnGetImageIndex) then
    FOnGetImageIndex(Self, AIndex, FEditor.DocumentFileName[AIndex], Result);
end;

procedure TCMTabBinder.Refresh;
begin
  RebuildTabs;
end;

procedure TCMTabBinder.EditorDocListChange(Sender: TObject);
begin
  if not FUpdating then RebuildTabs;
  if Assigned(FOldDocListChange) then FOldDocListChange(Sender);
end;

procedure TCMTabBinder.EditorDocumentChange(Sender: TObject; Index: Integer);
begin
  if not FUpdating then UpdateTab(Index);
  if Assigned(FOldDocumentChange) then FOldDocumentChange(Sender, Index);
end;

procedure TCMTabBinder.EditorActiveChange(Sender: TObject);
begin
  if not FUpdating then
  begin
    FUpdating := True;
    try
      if FEditor.ActiveIndex >= 0 then FTabs.TabIndex := FEditor.ActiveIndex;
    finally
      FUpdating := False;
    end;
  end;
  if Assigned(FOldActiveChange) then FOldActiveChange(Sender);
end;

{ ---------- 未保存の確認 ---------- }

procedure TCMTabBinder.EditorQueryClose(Sender: TObject; Index: Integer; var CanClose: Boolean);
begin
  case MessageDlg('未保存の変更',
      FEditor.DocumentTitle[Index] + ' は変更されています。' + LineEnding +
      '保存しますか？（いいえ = 保存せずに閉じる）',
      mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
    mrYes:
      begin
        FEditor.SaveDocument(Index);
        CanClose := not FEditor.DocumentModified[Index];   { 保存されなければ閉じない }
      end;
    mrNo: CanClose := True;
  else
    CanClose := False;
  end;
end;

function TCMTabBinder.CloseAll: Boolean;
begin
  Result := FEditor.CloseAll(False);
end;

{ ---------- タブ操作 ---------- }

procedure TCMTabBinder.TabClick(Sender: TObject);
begin
  if FUpdating or (FEditor = nil) then Exit;
  FUpdating := True;
  try
    FEditor.ActiveIndex := FTabs.TabIndex;
  finally
    FUpdating := False;
  end;
  FFocusOnMouseUp := True;   { ここではまだボタンが押されたまま。離したあと（TabsMouseUp）でフォーカスを戻す }
end;

procedure TCMTabBinder.TabsMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  if Assigned(FOldTabsMouseUp) then FOldTabsMouseUp(Sender, Button, Shift, X, Y);
  if FFocusOnMouseUp then
  begin
    FFocusOnMouseUp := False;
    FocusEditorLater;
  end;
end;

procedure TCMTabBinder.FocusEditorLater;
begin
  { タブのマウス処理が終わってからフォーカスを移す（処理中に移すと IME の状態が乱れることがあるため） }
  if FFocusPending then Exit;
  FFocusPending := True;
  Application.QueueAsyncCall(@AsyncFocus, 0);
end;

procedure TCMTabBinder.AsyncFocus(Data: PtrInt);
begin
  FFocusPending := False;
  if (FEditor <> nil) and FEditor.Ready and FEditor.Visible then FEditor.SetFocus;
end;

procedure TCMTabBinder.TabPlusClick(Sender: TObject);
begin
  FEditor.AddDocument('');
  FFocusOnMouseUp := True;
end;

procedure TCMTabBinder.TabClose(Sender: TObject; ATabIndex: Integer;
  var ACanClose, ACanContinue: Boolean);
begin
  { タブの削除はエディタ側の閉じる処理 → タブ再構築で行う。確認ダイアログはマウス処理の外で出す }
  ACanClose := False;
  ACanContinue := False;
  Application.QueueAsyncCall(@AsyncClose, ATabIndex);
end;

procedure TCMTabBinder.AsyncClose(Data: PtrInt);
begin
  if FEditor.CloseDocument(Data) and (FEditor.DocumentCount > 0) then
    FocusEditorLater;
end;

procedure TCMTabBinder.TabDropQuery(Sender: TObject; AIndexFrom, AIndexTo: Integer;
  var ACanDrop: Boolean);
begin
  { ドラッグ完了前にエディタ側の並びを入れ替えておく（直後のタブ切り替えで正しい文書が選ばれる） }
  ACanDrop := True;
  FUpdating := True;
  try
    FEditor.MoveDocument(AIndexFrom, AIndexTo);
  finally
    FUpdating := False;
  end;
  FDropHandled := True;
end;

procedure TCMTabBinder.TabMove(Sender: TObject; AIndexFrom, AIndexTo: Integer);
begin
  if (AIndexFrom < 0) or (AIndexTo < 0) then Exit;   { 追加・削除は無視 }
  if FDropHandled then
  begin
    FDropHandled := False;
    Exit;
  end;
  FUpdating := True;
  try
    FEditor.MoveDocument(AIndexFrom, AIndexTo);
  finally
    FUpdating := False;
  end;
end;

end.
