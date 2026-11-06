{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ TCFileTree の登録（設計時パッケージ cxdsgn に入れる）
  設計書: docs\TCFileTree_Design.md
  パレットのアイコンは cfiletree_icon.lrs（tcfiletree・tcfiletree_150・tcfiletree_200 の PNG）。
  Lazarus のパレットは、クラス名と同じ名前のリソース（150%・200% は _150・_200 付き）を探して表示する。
  TargetEditor・SideEditor は、型が TControl なので、そのままではフォームの部品がすべて選択肢に出る。
  実行時に受け付ける TCMonacoEditor・TCsEditor（もう一方が決まっていれば、同じ種類）だけを出す
  プロパティエディタを登録する。 }
unit uCFileTreeReg;

{$mode objfpc}{$H+}

interface

uses
  Classes, TypInfo, Controls, LResources, PropEdits, ObjInspStrConsts,
  CFileTree, uCmonacos, uCsEditor;

type
  { TargetEditor・SideEditor の選択肢を、受け付けるエディタだけにする }
  TCFileTreeEditorProperty = class(TComponentPropertyEditor)
  public
    procedure GetValues(Proc: TGetStrProc); override;
  end;

procedure Register;

implementation

{ 選択肢：なし、と、フォームにある TCMonacoEditor・TCsEditor。
  TargetEditor と SideEditor は同じ種類だけ（片方が決まっていれば、その種類だけ）出す }
procedure TCFileTreeEditorProperty.GetValues(Proc: TGetStrProc);
var
  Tree: TCFileTree;
  Other: TControl;
begin
  Proc(oisNone);
  if PropertyHook = nil then Exit;
  Other := nil;
  if GetComponent(0) is TCFileTree then
  begin
    Tree := TCFileTree(GetComponent(0));
    if GetName = 'TargetEditor' then Other := Tree.SideEditor else Other := Tree.TargetEditor;
  end;
  if (Other = nil) or (Other is TCMonacoEditor) then
    PropertyHook.GetComponentNames(GetTypeData(TypeInfo(TCMonacoEditor)), Proc);
  if (Other = nil) or (Other is TCsEditor) then
    PropertyHook.GetComponentNames(GetTypeData(TypeInfo(TCsEditor)), Proc);
end;

{ コンポーネントパレットの CX ページに TCFileTree を登録する }
procedure Register;
begin
  RegisterComponents('CX', [TCFileTree]);
  RegisterPropertyEditor(TypeInfo(TControl), TCFileTree, 'TargetEditor', TCFileTreeEditorProperty);
  RegisterPropertyEditor(TypeInfo(TControl), TCFileTree, 'SideEditor', TCFileTreeEditorProperty);
end;

initialization
  { パレットのアイコンを読み込む }
  {$I cfiletree_icon.lrs}

end.
