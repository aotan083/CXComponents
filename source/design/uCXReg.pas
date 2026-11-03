{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ uCXReg
  CX パレットの設計時用ユニット（設計時パッケージ cxdsgn に入れる）。
  ・コンポーネントパレット [CX] へ部品を登録する：TCTreeView・TCListView・TCSynEdit・TCTabBrowser・
    TCMonacoEditor・TCMFindDialog・TCCheckListBox・TCGroupBox・TCCheckGroupBox・TCsEditor・TCsFindDialog・TCPreview
    （TCSideBar は uCSideBarReg、TCPageControl・TCTitleBar は uCPageControl_reg、
      TCBookmark は uCbookmark_reg が登録する）
  ・アクションリストエディタの [CX] カテゴリへ、TCMonacoEditor 用のアクション（25 個）を登録する
  ・アクションリストエディタの [CX TCsEditor] カテゴリへ、TCsEditor 用のアクション（25 個）を登録する
  ・コンポーネントパレットのアイコン（cx_icons.lrs・cchecklistbox_icon.lrs・cgroupbox_icon.lrs・
    ccheckgroupbox_icon.lrs・cseditor_icon.lrs）を読み込む
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
  uCGroupBox, uCCheckGroupBox,                // TCGroupBox・TCCheckGroupBox
  uCsEditor, uCPreview;                       // TCsEditor・TCsFindDialog・アクション・TCPreview


procedure Register;

implementation

procedure Register;
begin
  // パレット [CX] へ部品を登録する。
  // IDE は、クラス名と同じ名前のリソース（24px）と、末尾 _150（36px）・_200（48px）の
  // リソースを、表示スケールに合わせて選んでアイコンにする。
  RegisterComponents('CX', [TCTreeView, TCListView, TCSynEdit, TCTabBrowser,
    TCMonacoEditor, TCMFindDialog, TCCheckListBox, TCGroupBox, TCCheckGroupBox,
    TCsEditor, TCsFindDialog, TCPreview]);

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

  // TCsEditor のアクション25個は、カテゴリ [CX TCsEditor] に分ける（同じ表示名が並ばないように）。
  // 並び順は TCsEditor_Design.md 11章の表のとおり
  RegisterActions('CX TCsEditor', [
    TCsEditorNew, TCsEditorOpen, TCsEditorSave,                         // 1〜3
    TCsEditorSaveAs, TCsEditorClose, TCsEditorPrint,                    // 4〜6
    TCsEditorSaveAll, TCsEditorCloseAll,                                // 7〜8
    TCsEditorUndo, TCsEditorRedo,                                       // 9〜10
    TCsEditorCut, TCsEditorCopy, TCsEditorPaste, TCsEditorSelectAll,    // 11〜14
    TCsEditorDuplicateLine, TCsEditorDeleteToEnd, TCsEditorDeleteToStart, // 15〜17
    TCsEditorFind, TCsEditorFindNext, TCsEditorFindPrev,                // 18〜20
    TCsEditorMinimap, TCsEditorPreview, TCsEditorLineNumbers,           // 21〜23
    TCsEditorWordWrap, TCsEditorRemoteImages], nil);                    // 24〜25
end;

initialization
  // パレット用アイコン（24/36/48px の PNG）をリソースとして読み込む。
  // TCMFindDialog は cx_icons.lrs から外し、cseditor_icon.lrs に入れた（同じ名前のリソースを 2 つ持たない）
  {$I cx_icons.lrs}
  {$I cchecklistbox_icon.lrs}
  {$I cgroupbox_icon.lrs}         // TCGroupBox の 24/36/48px
  {$I ccheckgroupbox_icon.lrs}    // TCCheckGroupBox の 24/36/48px
  {$I cseditor_icon.lrs}         // TCsEditor・TCPreview・TCsFindDialog・TCMFindDialog（A→B の絵）の 24/36/48px

end.
