{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ uCExpandPanelReg
  TCExpandPanel・TCRollout の設計時用ユニット（設計時パッケージ cxdsgn に入れる）。
  ・コンポーネントパレット [CX] への登録
  ・IDE で右クリックしたときのメニュー（コンポーネントエディタ）
  ・コンポーネントパレットのアイコン（cexpandpanel_icon.lrs）

  設計書：docs\TCExpandPanel_Design.md }
unit uCExpandPanelReg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, ComponentEditors, PropEdits, uCExpandPanel;

type

  { TCExpandPanelEditor
    右クリックメニュー「パネルの追加」「パネルの削除」「上へ移動」「下へ移動」。
    TCExpandPanel と TCRollout の両方に登録する。操作するのは、入れ物と、選んでいるパネル。 }

  TCExpandPanelEditor = class(TComponentEditor)
  private
    function Panel: TCExpandPanel;
    procedure DoAddPanel;
    procedure DoDeletePanel;
    procedure DoMovePanel(Delta: Integer);
  public
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
  end;

procedure Register;

implementation

const
  cVerbAddPanel = 0;
  cVerbDeletePanel = 1;
  cVerbMoveUp = 2;
  cVerbMoveDown = 3;

resourcestring
  rsCExpandPanelAdd = 'パネルの追加';
  rsCExpandPanelDelete = 'パネルの削除';
  rsCExpandPanelMoveUp = '上へ移動';
  rsCExpandPanelMoveDown = '下へ移動';

procedure Register;
begin
  RegisterComponents('CX', [TCExpandPanel, TCRollout]);
  RegisterComponentEditor(TCExpandPanel, TCExpandPanelEditor);
  RegisterComponentEditor(TCRollout, TCExpandPanelEditor);
end;

{ TCExpandPanelEditor }

{ 操作する入れ物：TCExpandPanel ならそれ自身、TCRollout ならその親の入れ物（なければ nil） }
function TCExpandPanelEditor.Panel: TCExpandPanel;
begin
  if GetComponent is TCRollout then
    Result := TCRollout(GetComponent).ExpandPanel
  else if GetComponent is TCExpandPanel then
    Result := TCExpandPanel(GetComponent)
  else
    Result := nil;
end;

{ パネルの追加：末尾に追加する。Owner は入れ物の Owner（フォーム） }
procedure TCExpandPanelEditor.DoAddPanel;
var
  Hook: TPropertyEditorHook;
  EP: TCExpandPanel;
  NewOwner: TComponent;
  NewPanel: TCRollout;
  NewName: string;
begin
  Hook := nil;
  if not GetHook(Hook) then Exit;
  EP := Panel;
  if EP = nil then Exit;
  NewOwner := EP.Owner;
  if NewOwner = nil then
    NewOwner := EP;
  NewPanel := TCRollout.Create(NewOwner);
  NewName := GetDesigner.CreateUniqueComponentName(NewPanel.ClassName);
  NewPanel.Name := NewName;
  NewPanel.Caption := NewName;
  EP.AddPanel(NewPanel);
  Hook.PersistentAdded(NewPanel, True);
  Modified;
end;

{ パネルの削除：選んでいる TCRollout が入れ物の中にあるときだけ。
  削除するとこのエディタ自身が解放されることがあるため、この後は何もしない }
procedure TCExpandPanelEditor.DoDeletePanel;
var
  Hook: TPropertyEditorHook;
  P: TPersistent;
begin
  if not (GetComponent is TCRollout) then Exit;
  if TCRollout(GetComponent).ExpandPanel = nil then Exit;
  Hook := nil;
  if not GetHook(Hook) then Exit;
  P := GetComponent;
  Hook.DeletePersistent(P);
end;

{ 上へ移動（Delta = -1）・下へ移動（Delta = +1）：選んでいる TCRollout の順番を変える }
procedure TCExpandPanelEditor.DoMovePanel(Delta: Integer);
var
  EP: TCExpandPanel;
  Cur, NewIndex: Integer;
begin
  if not (GetComponent is TCRollout) then Exit;
  EP := Panel;
  if EP = nil then Exit;
  Cur := EP.IndexOfPanel(TCRollout(GetComponent));
  if Cur < 0 then Exit;
  NewIndex := Cur + Delta;
  if (NewIndex < 0) or (NewIndex >= EP.PanelCount) then Exit;
  EP.MovePanel(Cur, NewIndex);
  Modified;
end;

procedure TCExpandPanelEditor.ExecuteVerb(Index: Integer);
begin
  case Index of
    cVerbAddPanel:    DoAddPanel;
    cVerbDeletePanel: DoDeletePanel;   // エディタ自身が解放されることがある
    cVerbMoveUp:      DoMovePanel(-1);
    cVerbMoveDown:    DoMovePanel(1);
  end;
end;

function TCExpandPanelEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    cVerbAddPanel:    Result := rsCExpandPanelAdd;
    cVerbDeletePanel: Result := rsCExpandPanelDelete;
    cVerbMoveUp:      Result := rsCExpandPanelMoveUp;
    cVerbMoveDown:    Result := rsCExpandPanelMoveDown;
  else
    Result := '';
  end;
end;

function TCExpandPanelEditor.GetVerbCount: Integer;
begin
  Result := 4;
end;

initialization
  // コンポーネントパレットのアイコン（リソース名はクラス名と同じ。_150・_200 は表示スケール用）
  {$I cexpandpanel_icon.lrs}

end.
