{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ CMonaco の標準アクション（TCMonacoEditor 用）。【2.18】25 個

  使い方: フォームに TActionList を貼り、アクションリストエディタの「標準アクションを追加」から
          CMonaco のアクションを追加して、メニュー項目やボタンの Action プロパティで選ぶ。コードは不要。
  ・対象は、フォームで最後にフォーカスされたエディタ（まだどれもフォーカスされていなければ、最初のエディタ）。
  ・実行できないときは、自動で無効（灰色）になる。
  ・OnExecute を設定すると、標準の動作の代わりにそちらが呼ばれる（TAction と同じ）。
  ・【2.18】切り替えのアクション（ミニマップ・プレビュー・行番号・折り返し・ネットの画像）は、
    今の状態に合わせてチェック（Checked）も自動で付け直す。OnUpdate を設定すると、そちらが優先する。
  ・【2.18】表示名・ショートカットは追加したあとで変えてよい。エディタの中で押したキーは内蔵の動作が先に動く
    （動作は同じなので、ショートカットはメニューの表示として働く）。 }
unit CMonacoActions;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, ActnList, Menus, LCLType, uCmonacos;

type

  { TCMEditorAction : CMonaco の標準アクションの基底 }

  TCMEditorAction = class(TAction)
  protected
    function TargetEditor: TCMonacoEditor;
    function CanRun(AEditor: TCMonacoEditor): Boolean; virtual;
    procedure Run(AEditor: TCMonacoEditor); virtual; abstract;
  public
    constructor Create(AOwner: TComponent); override;
    function Execute: Boolean; override;
    function Update: Boolean; override;
  end;

  TCMEditorNew = class(TCMEditorAction)
  protected
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TCMEditorOpen = class(TCMEditorAction)
  protected
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TCMEditorSave = class(TCMEditorAction)
  protected
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TCMEditorSaveAs = class(TCMEditorAction)
  protected
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TCMEditorClose = class(TCMEditorAction)
  protected
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TCMEditorPrint = class(TCMEditorAction)
  protected
    function CanRun(AEditor: TCMonacoEditor): Boolean; override;
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { ---------- 【2.18】追加のアクション ---------- }

  { 7. すべて保存（変更のあるタブがあるときだけ有効） }
  TCMEditorSaveAll = class(TCMEditorAction)
  protected
    function CanRun(AEditor: TCMonacoEditor): Boolean; override;
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { 8. すべて閉じる }
  TCMEditorCloseAll = class(TCMEditorAction)
  protected
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { 9. 元に戻す（CanUndo のときだけ有効） }
  TCMEditorUndo = class(TCMEditorAction)
  protected
    function CanRun(AEditor: TCMonacoEditor): Boolean; override;
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { 10. やり直し（CanRedo のときだけ有効） }
  TCMEditorRedo = class(TCMEditorAction)
  protected
    function CanRun(AEditor: TCMonacoEditor): Boolean; override;
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { 11. 切り取り（選択があり、読み取り専用でないときだけ有効） }
  TCMEditorCut = class(TCMEditorAction)
  protected
    function CanRun(AEditor: TCMonacoEditor): Boolean; override;
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { 12. コピー（選択があるときだけ有効） }
  TCMEditorCopy = class(TCMEditorAction)
  protected
    function CanRun(AEditor: TCMonacoEditor): Boolean; override;
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { 13. 貼り付け（クリップボードに文字があり、読み取り専用でないときだけ有効） }
  TCMEditorPaste = class(TCMEditorAction)
  protected
    function CanRun(AEditor: TCMonacoEditor): Boolean; override;
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { 14. すべて選択 }
  TCMEditorSelectAll = class(TCMEditorAction)
  protected
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { 15. 行の複製（読み取り専用でないときだけ有効） }
  TCMEditorDuplicateLine = class(TCMEditorAction)
  protected
    function CanRun(AEditor: TCMonacoEditor): Boolean; override;
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { 16. 末尾まで削除（読み取り専用でないときだけ有効） }
  TCMEditorDeleteToEnd = class(TCMEditorAction)
  protected
    function CanRun(AEditor: TCMonacoEditor): Boolean; override;
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { 17. 先頭まで削除（読み取り専用でないときだけ有効） }
  TCMEditorDeleteToStart = class(TCMEditorAction)
  protected
    function CanRun(AEditor: TCMonacoEditor): Boolean; override;
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { 18. 検索・置換ダイアログを開く }
  TCMEditorFind = class(TCMEditorAction)
  protected
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { 19. 次を検索 }
  TCMEditorFindNext = class(TCMEditorAction)
  protected
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { 20. 前を検索 }
  TCMEditorFindPrev = class(TCMEditorAction)
  protected
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { ---------- 【2.18】切り替えのアクション ---------- }

  { TCMEditorToggleAction : 切り替えのアクションの基底。
    実行すると値を反転し（SetValue(not GetValue)）、Update でチェックを今の値に合わせる。
    子クラスは GetValue（今の値を読む）と SetValue（値を書く）だけを書く }
  TCMEditorToggleAction = class(TCMEditorAction)
  protected
    function GetValue(AEditor: TCMonacoEditor): Boolean; virtual; abstract;
    procedure SetValue(AEditor: TCMonacoEditor; AValue: Boolean); virtual; abstract;
    procedure Run(AEditor: TCMonacoEditor); override;
  public
    function Update: Boolean; override;
  end;

  { 21. ミニマップ }
  TCMEditorMinimap = class(TCMEditorToggleAction)
  protected
    function GetValue(AEditor: TCMonacoEditor): Boolean; override;
    procedure SetValue(AEditor: TCMonacoEditor; AValue: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { 22. プレビュー }
  TCMEditorPreview = class(TCMEditorToggleAction)
  protected
    function GetValue(AEditor: TCMonacoEditor): Boolean; override;
    procedure SetValue(AEditor: TCMonacoEditor; AValue: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { 23. 行番号 }
  TCMEditorLineNumbers = class(TCMEditorToggleAction)
  protected
    function GetValue(AEditor: TCMonacoEditor): Boolean; override;
    procedure SetValue(AEditor: TCMonacoEditor; AValue: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { 24. 折り返し }
  TCMEditorWordWrap = class(TCMEditorToggleAction)
  protected
    function GetValue(AEditor: TCMonacoEditor): Boolean; override;
    procedure SetValue(AEditor: TCMonacoEditor; AValue: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { 25. ネットの画像を表示 }
  TCMEditorRemoteImages = class(TCMEditorToggleAction)
  protected
    function GetValue(AEditor: TCMonacoEditor): Boolean; override;
    procedure SetValue(AEditor: TCMonacoEditor; AValue: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

uses
  Dialogs, Clipbrd, LCLIntf;   { 【2.18】Clipbrd・LCLIntf は貼り付けの判定（クリップボードに文字があるか）に使う }

{ ---------- TCMEditorAction ---------- }

constructor TCMEditorAction.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DisableIfNoHandler := False;     { OnExecute が無くても、標準の動作で有効にする }
end;

function TCMEditorAction.TargetEditor: TCMonacoEditor;
var
  C: TComponent;
begin
  Result := nil;
  { ActionList の Owner（フォーム）をたどる }
  C := ActionList;
  if C <> nil then C := C.Owner;
  while (C <> nil) and not (C is TCustomForm) do C := C.Owner;
  if C <> nil then Result := CMActiveEditor(TCustomForm(C));
end;

function TCMEditorAction.CanRun(AEditor: TCMonacoEditor): Boolean;
begin
  Result := AEditor <> nil;
end;

function TCMEditorAction.Execute: Boolean;
var
  E: TCMonacoEditor;
begin
  Result := inherited Execute;      { OnExecute が設定されていれば、そちらを使う }
  if Result then Exit;
  E := TargetEditor;
  if CanRun(E) then
  begin
    Run(E);
    Result := True;
  end;
end;

function TCMEditorAction.Update: Boolean;
begin
  Result := inherited Update;       { OnUpdate が設定されていれば、そちらを使う }
  if Result then Exit;
  Enabled := CanRun(TargetEditor);
  Result := True;
end;

{ ---------- 各アクション ---------- }

constructor TCMEditorNew.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '新規(&N)';
  Hint := '新しい文書';
  ShortCut := Menus.ShortCut(VK_N, [ssCtrl]);
end;

procedure TCMEditorNew.Run(AEditor: TCMonacoEditor);
begin
  AEditor.NewPage;
end;

constructor TCMEditorOpen.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '開く(&O)...';
  Hint := 'ファイルを開く';
  ShortCut := Menus.ShortCut(VK_O, [ssCtrl]);
end;

procedure TCMEditorOpen.Run(AEditor: TCMonacoEditor);
var
  Dlg: TOpenDialog;
  Own: Boolean;
  I: Integer;
begin
  Dlg := AEditor.OpenDialog;
  Own := Dlg = nil;
  if Own then
  begin
    Dlg := TOpenDialog.Create(nil);
    Dlg.Filter := 'Markdown (*.md;*.markdown)|*.md;*.markdown|' +
      'テキスト (*.txt)|*.txt|すべてのファイル (*.*)|*.*';
    Dlg.FilterIndex := 3;
    Dlg.InitialDir := ExtractFilePath(AEditor.FileName);
    if AEditor.MultiDocument then Dlg.Options := Dlg.Options + [ofAllowMultiSelect];
  end;
  try
    if not Dlg.Execute then Exit;
    if AEditor.MultiDocument and (Dlg.Files.Count > 1) then
    begin
      for I := 0 to Dlg.Files.Count - 1 do AEditor.OpenFile(Dlg.Files[I]);
    end
    else
      AEditor.OpenFile(Dlg.FileName);
  finally
    if Own then Dlg.Free;
  end;
end;

constructor TCMEditorSave.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '上書き保存(&S)';
  Hint := '上書き保存';
  ShortCut := Menus.ShortCut(VK_S, [ssCtrl]);
end;

procedure TCMEditorSave.Run(AEditor: TCMonacoEditor);
begin
  AEditor.Save;
end;

constructor TCMEditorSaveAs.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '名前を付けて保存(&A)...';
  Hint := '名前を付けて保存';
end;

procedure TCMEditorSaveAs.Run(AEditor: TCMonacoEditor);
begin
  AEditor.SaveAs;
end;

constructor TCMEditorClose.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '閉じる(&C)';
  Hint := '文書を閉じる';
  ShortCut := Menus.ShortCut(VK_W, [ssCtrl]);
end;

procedure TCMEditorClose.Run(AEditor: TCMonacoEditor);
begin
  { 【2.9】MultiDocument = False のときは、確認して中身を空にする（Close の中で行う） }
  AEditor.Close;
end;

constructor TCMEditorPrint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '印刷(&P)...';
  Hint := 'プレビューを印刷（PDF として保存もできる）';
  ShortCut := Menus.ShortCut(VK_P, [ssCtrl]);
end;

function TCMEditorPrint.CanRun(AEditor: TCMonacoEditor): Boolean;
begin
  Result := (AEditor <> nil) and AEditor.CanPrint;
end;

procedure TCMEditorPrint.Run(AEditor: TCMonacoEditor);
begin
  AEditor.Print;
end;

{ ---------- 【2.18】追加のアクション ---------- }

{ 7. すべて保存 }
constructor TCMEditorSaveAll.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'すべて保存(&L)';
  Hint := '変更のあるタブをすべて保存';
  ShortCut := Menus.ShortCut(VK_S, [ssCtrl, ssShift]);
end;

function TCMEditorSaveAll.CanRun(AEditor: TCMonacoEditor): Boolean;
var
  I: Integer;
begin
  { 変更のあるタブが 1 つでもあれば有効 }
  Result := False;
  if AEditor = nil then Exit;
  for I := 0 to AEditor.PageCount - 1 do
    if AEditor.Pages[I].Modified then Exit(True);
end;

procedure TCMEditorSaveAll.Run(AEditor: TCMonacoEditor);
begin
  AEditor.SaveAll;
end;

{ 8. すべて閉じる }
constructor TCMEditorCloseAll.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'すべて閉じる(&E)';
  Hint := 'すべての文書を閉じる';
end;

procedure TCMEditorCloseAll.Run(AEditor: TCMonacoEditor);
begin
  AEditor.CloseAll;      { 変更があれば確認する。閉じ終わると空の無題が 1 枚残る }
end;

{ 9. 元に戻す }
constructor TCMEditorUndo.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '元に戻す(&U)';
  Hint := '元に戻す';
  ShortCut := Menus.ShortCut(VK_Z, [ssCtrl]);
end;

function TCMEditorUndo.CanRun(AEditor: TCMonacoEditor): Boolean;
begin
  Result := (AEditor <> nil) and AEditor.CanUndo;
end;

procedure TCMEditorUndo.Run(AEditor: TCMonacoEditor);
begin
  AEditor.Undo;
end;

{ 10. やり直し }
constructor TCMEditorRedo.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'やり直し(&R)';
  Hint := 'やり直し';
  ShortCut := Menus.ShortCut(VK_Y, [ssCtrl]);
end;

function TCMEditorRedo.CanRun(AEditor: TCMonacoEditor): Boolean;
begin
  Result := (AEditor <> nil) and AEditor.CanRedo;
end;

procedure TCMEditorRedo.Run(AEditor: TCMonacoEditor);
begin
  AEditor.Redo;
end;

{ 11. 切り取り }
constructor TCMEditorCut.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '切り取り(&T)';
  Hint := '切り取り';
  ShortCut := Menus.ShortCut(VK_X, [ssCtrl]);
end;

function TCMEditorCut.CanRun(AEditor: TCMonacoEditor): Boolean;
begin
  Result := (AEditor <> nil) and (AEditor.SelLength > 0) and not AEditor.ReadOnly;
end;

procedure TCMEditorCut.Run(AEditor: TCMonacoEditor);
begin
  AEditor.Cut;
end;

{ 12. コピー }
constructor TCMEditorCopy.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'コピー(&C)';
  Hint := 'コピー';
  ShortCut := Menus.ShortCut(VK_C, [ssCtrl]);
end;

function TCMEditorCopy.CanRun(AEditor: TCMonacoEditor): Boolean;
begin
  Result := (AEditor <> nil) and (AEditor.SelLength > 0);
end;

procedure TCMEditorCopy.Run(AEditor: TCMonacoEditor);
begin
  AEditor.Copy;
end;

{ 13. 貼り付け }
constructor TCMEditorPaste.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '貼り付け(&P)';
  Hint := '貼り付け';
  ShortCut := Menus.ShortCut(VK_V, [ssCtrl]);
end;

function TCMEditorPaste.CanRun(AEditor: TCMonacoEditor): Boolean;
begin
  { クリップボードの中身は取り出さず、文字があるかだけを調べる（Update は暇なときに何度も呼ばれるため） }
  Result := (AEditor <> nil) and not AEditor.ReadOnly and
    Clipboard.HasFormat(PredefinedClipboardFormat(pcfText));
end;

procedure TCMEditorPaste.Run(AEditor: TCMonacoEditor);
begin
  AEditor.Paste;
end;

{ 14. すべて選択 }
constructor TCMEditorSelectAll.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'すべて選択(&A)';
  Hint := 'すべて選択';
  ShortCut := Menus.ShortCut(VK_A, [ssCtrl]);
end;

procedure TCMEditorSelectAll.Run(AEditor: TCMonacoEditor);
begin
  AEditor.SelectAll;
end;

{ 15. 行の複製 }
constructor TCMEditorDuplicateLine.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '行の複製(&D)';
  Hint := 'カーソル行を複製して下へ';
  ShortCut := Menus.ShortCut(VK_F10, [ssShift]);
end;

function TCMEditorDuplicateLine.CanRun(AEditor: TCMonacoEditor): Boolean;
begin
  Result := (AEditor <> nil) and not AEditor.ReadOnly;
end;

procedure TCMEditorDuplicateLine.Run(AEditor: TCMonacoEditor);
begin
  AEditor.DuplicateLine;
end;

{ 16. 末尾まで削除 }
constructor TCMEditorDeleteToEnd.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '末尾まで削除';
  Hint := 'カーソル位置から文書の末尾まで削除';
end;

function TCMEditorDeleteToEnd.CanRun(AEditor: TCMonacoEditor): Boolean;
begin
  Result := (AEditor <> nil) and not AEditor.ReadOnly;
end;

procedure TCMEditorDeleteToEnd.Run(AEditor: TCMonacoEditor);
begin
  AEditor.DeleteToEnd;
end;

{ 17. 先頭まで削除 }
constructor TCMEditorDeleteToStart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '先頭まで削除';
  Hint := 'カーソル位置から文書の先頭まで削除';
end;

function TCMEditorDeleteToStart.CanRun(AEditor: TCMonacoEditor): Boolean;
begin
  Result := (AEditor <> nil) and not AEditor.ReadOnly;
end;

procedure TCMEditorDeleteToStart.Run(AEditor: TCMonacoEditor);
begin
  AEditor.DeleteToStart;
end;

{ 18. 検索・置換 }
constructor TCMEditorFind.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '検索・置換(&F)...';
  Hint := '検索・置換ダイアログを開く';
  ShortCut := Menus.ShortCut(VK_F, [ssCtrl]);
end;

procedure TCMEditorFind.Run(AEditor: TCMonacoEditor);
begin
  AEditor.ShowFindDialog;
end;

{ 19. 次を検索 }
constructor TCMEditorFindNext.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '次を検索(&N)';
  Hint := '直前の検索語で次を検索';
  ShortCut := Menus.ShortCut(VK_F5, []);
end;

procedure TCMEditorFindNext.Run(AEditor: TCMonacoEditor);
begin
  AEditor.FindNext;      { 検索語がなければ検索ダイアログを開く }
end;

{ 20. 前を検索 }
constructor TCMEditorFindPrev.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '前を検索(&V)';
  Hint := '直前の検索語で前を検索';
  ShortCut := Menus.ShortCut(VK_F5, [ssShift]);
end;

procedure TCMEditorFindPrev.Run(AEditor: TCMonacoEditor);
begin
  AEditor.FindPrev;
end;

{ ---------- 【2.18】切り替えのアクション ---------- }

procedure TCMEditorToggleAction.Run(AEditor: TCMonacoEditor);
begin
  SetValue(AEditor, not GetValue(AEditor));   { 今の値を反転する }
end;

function TCMEditorToggleAction.Update: Boolean;
var
  E: TCMonacoEditor;
begin
  Result := inherited Update;        { 有効・無効（OnUpdate が設定されていれば、そちらを使う） }
  if Assigned(OnUpdate) then Exit;   { 利用者の OnUpdate を優先し、チェックは触らない }
  E := TargetEditor;
  Checked := (E <> nil) and GetValue(E);   { チェックを今の値に合わせる（キーで切り替えた場合も一致する） }
end;

{ 21. ミニマップ }
constructor TCMEditorMinimap.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'ミニマップ(&M)';
  Hint := 'ミニマップの表示・非表示';
  ShortCut := Menus.ShortCut(VK_M, [ssCtrl, ssShift]);
end;

function TCMEditorMinimap.GetValue(AEditor: TCMonacoEditor): Boolean;
begin
  Result := AEditor.Minimap;
end;

procedure TCMEditorMinimap.SetValue(AEditor: TCMonacoEditor; AValue: Boolean);
begin
  AEditor.Minimap := AValue;
end;

{ 22. プレビュー }
constructor TCMEditorPreview.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'プレビュー(&V)';
  Hint := 'プレビューの表示・非表示';
  ShortCut := Menus.ShortCut(VK_V, [ssCtrl, ssShift]);
end;

function TCMEditorPreview.GetValue(AEditor: TCMonacoEditor): Boolean;
begin
  Result := AEditor.ShowPreview;
end;

procedure TCMEditorPreview.SetValue(AEditor: TCMonacoEditor; AValue: Boolean);
begin
  AEditor.ShowPreview := AValue;
end;

{ 23. 行番号 }
constructor TCMEditorLineNumbers.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '行番号(&L)';
  Hint := '行番号の表示・非表示';
  ShortCut := Menus.ShortCut(VK_F11, []);
end;

function TCMEditorLineNumbers.GetValue(AEditor: TCMonacoEditor): Boolean;
begin
  Result := AEditor.LineNumbers;
end;

procedure TCMEditorLineNumbers.SetValue(AEditor: TCMonacoEditor; AValue: Boolean);
begin
  AEditor.LineNumbers := AValue;
end;

{ 24. 折り返し }
constructor TCMEditorWordWrap.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '折り返し(&W)';
  Hint := '折り返し表示の切り替え';
end;

function TCMEditorWordWrap.GetValue(AEditor: TCMonacoEditor): Boolean;
begin
  Result := AEditor.WordWrap;
end;

procedure TCMEditorWordWrap.SetValue(AEditor: TCMonacoEditor; AValue: Boolean);
begin
  AEditor.WordWrap := AValue;
end;

{ 25. ネットの画像を表示 }
constructor TCMEditorRemoteImages.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'ネットの画像を表示(&I)';
  Hint := 'プレビューで、ネット（http）の画像を表示するか';
end;

function TCMEditorRemoteImages.GetValue(AEditor: TCMonacoEditor): Boolean;
begin
  Result := AEditor.AllowRemoteImages;
end;

procedure TCMEditorRemoteImages.SetValue(AEditor: TCMonacoEditor; AValue: Boolean);
begin
  AEditor.AllowRemoteImages := AValue;
end;

end.
