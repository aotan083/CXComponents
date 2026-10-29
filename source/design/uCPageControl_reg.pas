{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ ============================================================================
  uCPageControl_reg  -  TCPageControl・TCTitleBar の設計時の登録

  設計書: docs\TCPageControl_Design.md
  パッケージ: cxdsgn（設計時）

  ・パレット CX に TCTitleBar・TCPageControl を登録する（TCTabSheet は登録しない）。
  ・パレットのアイコンは cpagecontrol_icon.lrs（initialization 部で読み込む）。
  ・TCPageControl・TCTabSheet の右クリックメニュー（コンポーネントエディタ）：
      新しいページ／ページの削除／次のページ／前のページ
  ・オブジェクトインスペクタで選んだ部品のページを表示中にする（IDE は TTabSheet・TPage にしか
    これをしないため、GlobalDesignHook で選択の変化を受けて同じことをする）。
  ============================================================================ }
unit uCPageControl_reg;

{$mode objfpc}{$H+}

interface

uses
  {$IFDEF WINDOWS}Windows,{$ENDIF}
  Classes, SysUtils, Controls, Forms, LResources, ComponentEditors, PropEdits,
  uCTitleBar, uCPageControl;

type
  { TCPageControlEditor。TCPageControl とそのページの両方に使う。 }
  TCPageControlEditor = class(TComponentEditor)
  protected
    function GetPageControl: TCPageControl;
    procedure AddNewPage;
    procedure DeleteActivePage;
    procedure SelectNext(AForward: Boolean);
  public
    procedure Edit; override;
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
  end;

procedure Register;

resourcestring
  rsCPCNewPage  = '新しいページ';
  rsCPCDelPage  = 'ページの削除';
  rsCPCNextPage = '次のページ';
  rsCPCPrevPage = '前のページ';

implementation

type
  { 設計時に、選択が変わったら、選んだ部品のあるページを表示中にする }
  TCPageControlSelectionHandler = class
  public
    procedure SetSelection(const ASelection: TPersistentSelectionList);
  end;

var
  SelectionHandler: TCPageControlSelectionHandler = nil;

{ 選択の1つ目（TControl のとき）から親をたどり、TCTabSheet ならそのページを表示中にする。
  入れ子の TCPageControl は外側まですべて切り替える。消している途中の部品は触らない。
  .lfm の内容は変えない（「変更あり」の印は付けない。IDE の TPageControl の切り替えと同じ）。 }
procedure TCPageControlSelectionHandler.SetSelection(const ASelection: TPersistentSelectionList);
var
  C: TControl;
  PC: TCPageControl;
  Changed: Boolean;
  F: TCustomForm;
begin
  if (ASelection = nil) or (ASelection.Count = 0) or not (ASelection[0] is TControl) then
    Exit;
  C := TControl(ASelection[0]);
  if not (csDesigning in C.ComponentState) or (csDestroying in C.ComponentState) then
    Exit;
  Changed := False;
  while C <> nil do
  begin
    if csDestroying in C.ComponentState then
      Exit;
    if (C is TCTabSheet) and (C.Parent is TCPageControl) then
    begin
      PC := TCPageControl(C.Parent);
      if not (csDestroying in PC.ComponentState) and (PC.ActivePage <> C) then
      begin
        PC.ActivePage := TCTabSheet(C);
        Changed := True;
      end;
    end;
    C := C.Parent;
  end;
  if not Changed then
    Exit;
  // 前のページの部品の選択の印を残さないよう、フォーム全体（子部品も含む）を描き直させる
  F := GetParentForm(TControl(ASelection[0]));
  if F <> nil then
  begin
    F.Invalidate;
    {$IFDEF WINDOWS}
    if F.HandleAllocated then
      RedrawWindow(F.Handle, nil, 0, RDW_INVALIDATE or RDW_ERASE or RDW_ALLCHILDREN);
    {$ENDIF}
  end;
end;

{ 選んでいる部品が TCPageControl ならそれ、ページならその TCPageControl }
function TCPageControlEditor.GetPageControl: TCPageControl;
begin
  if Component is TCPageControl then
    Result := TCPageControl(Component)
  else if Component is TCTabSheet then
    Result := TCTabSheet(Component).PageControl
  else
    Result := nil;
end;

{ 新しいページを作り、表示中にする。名前は CTabSheet1、CTabSheet2…、キャプションは名前（LCL と同じ）。 }
procedure TCPageControlEditor.AddNewPage;
var
  PC: TCPageControl;
  Hook: TPropertyEditorHook;
  NewPage: TCTabSheet;
  NewName: string;
begin
  PC := GetPageControl;
  if PC = nil then
    Exit;
  Hook := nil;
  if not GetHook(Hook) then
    Exit;
  NewName := GetDesigner.CreateUniqueComponentName(TCTabSheet.ClassName);
  NewPage := TCTabSheet.Create(PC.Owner);
  NewPage.Name := NewName;
  NewPage.Caption := NewName;
  NewPage.Parent := PC;
  PC.ActivePage := NewPage;
  Hook.PersistentAdded(NewPage, True);
  Modified;
end;

{ 表示中のページを削除する }
procedure TCPageControlEditor.DeleteActivePage;
var
  PC: TCPageControl;
  Hook: TPropertyEditorHook;
  Page: TCTabSheet;
begin
  PC := GetPageControl;
  if (PC = nil) or (PC.ActivePage = nil) then
    Exit;
  Hook := nil;
  if not GetHook(Hook) then
    Exit;
  Page := PC.ActivePage;
  // 消すページを選んだまま削除すると、IDE が消えた部品を触るので、先に TCPageControl を選ぶ
  GetDesigner.SelectOnlyThisComponent(PC);
  // ページの右クリックで呼ばれたときは、このエディタ自身もページと一緒に IDE が破棄する。
  // そのため削除の後は、このエディタ（Self）の項目やメソッドに一切触れない（LCL の TNotebookComponentEditor と同じ）。
  // 「変更あり」の印は DeletePersistent の中で IDE が付ける。
  Hook.DeletePersistent(TPersistent(Page));
end;

{ 次（前）のページを表示する。端では反対側に回る。 }
procedure TCPageControlEditor.SelectNext(AForward: Boolean);
var
  PC: TCPageControl;
  Page: TCTabSheet;
begin
  PC := GetPageControl;
  if (PC = nil) or (PC.PageCount = 0) then
    Exit;
  Page := PC.FindNextPage(PC.ActivePage, AForward, False);
  if Page <> nil then
  begin
    PC.ActivePage := Page;
    GetDesigner.SelectOnlyThisComponent(Page);
    Modified;
  end;
end;

{ ダブルクリックでは何もしない（既定ではメニューの 1 番目「新しいページ」が動き、ページが増えてしまうため） }
procedure TCPageControlEditor.Edit;
begin
end;

procedure TCPageControlEditor.ExecuteVerb(Index: Integer);
begin
  case Index of
    0: AddNewPage;
    1: DeleteActivePage;
    2: SelectNext(True);
    3: SelectNext(False);
  end;
end;

function TCPageControlEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0: Result := rsCPCNewPage;
    1: Result := rsCPCDelPage;
    2: Result := rsCPCNextPage;
    3: Result := rsCPCPrevPage;
  else
    Result := '';
  end;
end;

function TCPageControlEditor.GetVerbCount: Integer;
begin
  Result := 4;
end;

procedure Register;
begin
  RegisterComponents('CX', [TCTitleBar, TCPageControl]);
  RegisterNoIcon([TCTabSheet]);
  RegisterComponentEditor(TCPageControl, TCPageControlEditor);
  RegisterComponentEditor(TCTabSheet, TCPageControlEditor);
  // オブジェクトインスペクタで選んだ部品のページを表示中にする
  if (SelectionHandler = nil) and (GlobalDesignHook <> nil) then
  begin
    SelectionHandler := TCPageControlSelectionHandler.Create;
    GlobalDesignHook.AddHandlerSetSelection(@SelectionHandler.SetSelection);
  end;
end;

initialization
  // パレットのアイコン：tctitlebar・tcpagecontrol（_150・_200 付き）
  {$I cpagecontrol_icon.lrs}

finalization
  // 選択の変化を受ける処理を外す（IDE の終了時は GlobalDesignHook が先に破棄されていることがある）
  if SelectionHandler <> nil then
  begin
    if GlobalDesignHook <> nil then
      GlobalDesignHook.RemoveHandlerSetSelection(@SelectionHandler.SetSelection);
    FreeAndNil(SelectionHandler);
  end;

end.
