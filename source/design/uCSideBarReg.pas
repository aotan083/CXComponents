{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ uCSideBarReg
  TCSideBar の設計時用ユニット（設計時パッケージ cxdsgn に入れる）。
  ・コンポーネントパレット [CX] への登録
  ・IDE で TCSideBar を右クリックしたときのメニュー（コンポーネントエディタ）
  ・コンポーネントパレットのアイコン（csidebar_icon.lrs）

  設計書：docs\TCSideBar_Design.md }
unit uCSideBarReg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, ComponentEditors, PropEdits, uCSideBar;

type

  { TCSideBarEditor
    右クリックメニュー「ページの追加」「ページの削除」「上へ移動」「下へ移動」。
    LCL の TTabControlComponentEditor と同じ方式で、デザイナにページの追加・削除を知らせる。
    TCSideBar と TCSideBarPage の両方に登録する。アイコンで開閉すると開いたページが選ばれるため、
    ページを選んだ状態で右クリックしても同じメニューを出す（LCL の TPageComponentEditor と同じ考え方）。
    どちらから呼ばれても、操作するのはサイドバーと、その開いているページ。 }

  TCSideBarEditor = class(TComponentEditor)
  private
    function SideBar: TCSideBar;
    procedure DoAddPage;
    procedure DoDeletePage;
    procedure DoMovePage(Delta: Integer);
  public
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
  end;

procedure Register;

implementation

const
  cVerbAddPage = 0;
  cVerbDeletePage = 1;
  cVerbMoveUp = 2;
  cVerbMoveDown = 3;

resourcestring
  rsCSideBarAddPage = 'ページの追加';
  rsCSideBarDeletePage = 'ページの削除';
  rsCSideBarMoveUp = '上へ移動';
  rsCSideBarMoveDown = '下へ移動';

{ 設計時に、指定した部品だけを IDE で選んだ状態にする（uCSideBar から呼ばれる） }
procedure DesignSelect(AComponent: TComponent);
begin
  if GlobalDesignHook <> nil then
    GlobalDesignHook.SelectOnlyThis(AComponent);
end;

procedure Register;
begin
  CSideBarDesignSelect := @DesignSelect;
  RegisterComponents('CX', [TCSideBar]);
  // ページはパレットに出さない（TCSideBar の右クリックメニューで追加する）
  RegisterNoIcon([TCSideBarPage]);
  RegisterComponentEditor(TCSideBar, TCSideBarEditor);
  RegisterComponentEditor(TCSideBarPage, TCSideBarEditor);
end;

{ TCSideBarEditor }

{ 操作するサイドバー：TCSideBar ならそれ自身、TCSideBarPage ならその親のサイドバー }
function TCSideBarEditor.SideBar: TCSideBar;
begin
  if GetComponent is TCSideBarPage then
    Result := TCSideBarPage(GetComponent).SideBar
  else
    Result := TCSideBar(GetComponent);
end;

{ ページの追加：末尾に追加して開く
  ・Owner はサイドバーの Owner（フォーム）。.lfm にはフォームの部品として保存される
  ・Name は Designer.CreateUniqueComponentName で付ける（CSideBarPage1、CSideBarPage2…）
  ・Caption には Name と同じ文字を入れる（LCL と同じ）
  ・最後にデザイナへ追加を知らせ（PersistentAdded）、変更を知らせる（Modified） }
procedure TCSideBarEditor.DoAddPage;
var
  Hook: TPropertyEditorHook;
  SB: TCSideBar;
  NewOwner: TComponent;
  NewPage: TCSideBarPage;
  NewName: string;
begin
  Hook := nil;
  if not GetHook(Hook) then Exit;
  SB := SideBar;
  if SB = nil then Exit;
  NewOwner := SB.Owner;
  if NewOwner = nil then
    NewOwner := SB;
  NewPage := TCSideBarPage.Create(NewOwner);
  NewName := GetDesigner.CreateUniqueComponentName(NewPage.ClassName);
  NewPage.Name := NewName;
  NewPage.Caption := NewName;
  NewPage.Parent := SB;          // ここで SB のページ一覧の末尾に入る
  SB.ActivePage := NewPage;      // 設計時なのでイベントは呼ばれない
  Hook.PersistentAdded(NewPage, True);
  Modified;
end;

{ ページの削除：開いているページを削除する。
  削除するとこのエディタ自身が解放されることがあるため、この後は何もしない }
procedure TCSideBarEditor.DoDeletePage;
var
  Hook: TPropertyEditorHook;
  P: TCSideBarPage;
begin
  if SideBar = nil then Exit;
  P := SideBar.ActivePage;
  if P = nil then Exit;
  Hook := nil;
  if not GetHook(Hook) then Exit;
  Hook.DeletePersistent(TPersistent(P));
end;

{ 上へ移動（Delta = -1）・下へ移動（Delta = +1）：開いているページの順番を変える }
procedure TCSideBarEditor.DoMovePage(Delta: Integer);
var
  SB: TCSideBar;
  Cur, NewIndex: Integer;
begin
  SB := SideBar;
  if SB = nil then Exit;
  Cur := SB.ActivePageIndex;
  if Cur < 0 then Exit;
  NewIndex := Cur + Delta;
  if (NewIndex < 0) or (NewIndex >= SB.PageCount) then Exit;
  SB.MovePage(Cur, NewIndex);
  Modified;
end;

procedure TCSideBarEditor.ExecuteVerb(Index: Integer);
begin
  case Index of
    cVerbAddPage:    DoAddPage;
    cVerbDeletePage: DoDeletePage;   // エディタ自身が解放されることがある
    cVerbMoveUp:     DoMovePage(-1);
    cVerbMoveDown:   DoMovePage(1);
  end;
end;

function TCSideBarEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    cVerbAddPage:    Result := rsCSideBarAddPage;
    cVerbDeletePage: Result := rsCSideBarDeletePage;
    cVerbMoveUp:     Result := rsCSideBarMoveUp;
    cVerbMoveDown:   Result := rsCSideBarMoveDown;
  else
    Result := '';
  end;
end;

function TCSideBarEditor.GetVerbCount: Integer;
begin
  Result := 4;
end;

initialization
  // コンポーネントパレットのアイコン。
  // リソース名はクラス名と同じ（TCSideBar、TCSideBar_150、TCSideBar_200）で、IDE が表示スケールに合わせて選ぶ
  {$I csidebar_icon.lrs}

end.
