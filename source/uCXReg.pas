{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ uCXReg
  CX パレットの設計時用ユニット（設計時パッケージ cxdsgn に入れる）。
  ・コンポーネントパレット [CX] へ部品を登録する：TCTreeView・TCListView・TCSynEdit・TCTabBrowser・
    TCMonacoEditor・TCMFindDialog・TCCheckListBox・TCGroupBox・TCCheckGroupBox
    （TCSideBar は uCSideBarReg、TCPageControl・TCTitleBar は uCPageControl_reg、
      TCBookmark は uCbookmark_reg が登録する）
  ・アクションリストエディタの [CX] カテゴリへ、TCMonacoEditor 用のアクション（25 個）を登録する
  ・コンポーネントパレットのアイコン（cx_icons.lrs・cchecklistbox_icon.lrs・cgroupbox_icon.lrs・
    ccheckgroupbox_icon.lrs）を読み込む
  部品の中身は実行時パッケージ cx にあり、ここでは登録だけを行う。 }
unit uCXReg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, ActnList,
  CTreeView, CListView,                       // TCTreeView・TCListView
  cSynEdit,                                   // TCSynEdit
  uCTabBrowser,                               // TCTabBrowser
  uCmonacos, CMonacoFindDlg, CMonacoActions,  // TCMonacoEditor・TCMFindDialog・アクション
  CCheckListBox,                              // TCCheckListBox
  uCGroupBox, uCCheckGroupBox;                // TCGroupBox・TCCheckGroupBox


procedure Register;

implementation

procedure Register;
begin
  // パレット [CX] へ部品を登録する。
  // IDE は、クラス名と同じ名前のリソース（24px）と、末尾 _150（36px）・_200（48px）の
  // リソースを、表示スケールに合わせて選んでアイコンにする。
  RegisterComponents('CX', [TCTreeView, TCListView, TCSynEdit, TCTabBrowser,
    TCMonacoEditor, TCMFindDialog, TCCheckListBox, TCGroupBox, TCCheckGroupBox]);

  // アクションリストエディタの [CX] カテゴリへ、エディタ操作のアクション25個を登録する
  // （アクションはパレットに出ないため、アイコンは持たない）
  // 並び順は TCMonacoEditor_Usage.md の標準アクションの表のとおり
  RegisterActions('CX', [
    TCMEditorNew, TCMEditorOpen, TCMEditorSave,                         // 1〜3
    TCMEditorSaveAs, TCMEditorClose, TCMEditorPrint,                    // 4〜6
    TCMEditorSaveAll, TCMEditorCloseAll,                                // 7〜8  すべて保存・すべて閉じる
    TCMEditorUndo, TCMEditorRedo,                                       // 9〜10 元に戻す・やり直し
    TCMEditorCut, TCMEditorCopy, TCMEditorPaste, TCMEditorSelectAll,    // 11〜14
    TCMEditorDuplicateLine, TCMEditorDeleteToEnd, TCMEditorDeleteToStart, // 15〜17
    TCMEditorFind, TCMEditorFindNext, TCMEditorFindPrev,                // 18〜20 検索
    TCMEditorMinimap, TCMEditorPreview, TCMEditorLineNumbers,           // 21〜23 切り替え（チェック付き）
    TCMEditorWordWrap, TCMEditorRemoteImages], nil);                    // 24〜25 切り替え（チェック付き）
end;

initialization
  // パレット用アイコン（6部品 × 24/36/48px の PNG）をリソースとして読み込む
  {$I cx_icons.lrs}
  {$I cchecklistbox_icon.lrs}
  {$I cgroupbox_icon.lrs}         // TCGroupBox の 24/36/48px
  {$I ccheckgroupbox_icon.lrs}    // TCCheckGroupBox の 24/36/48px

end.
