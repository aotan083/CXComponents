{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ TCMTabBinder - TCMMonacoView（複数文書）と TCTabBar（タブ列）をつなぐ
  ※ 第2版から、TCMonacoEditor（ucmonacos.pas）が内部で使う部品になった。アプリから直接使う必要はない。

  使い方（フォーム側）:
    Binder := TCMTabBinder.Create(Self);
    Binder.Attach(Ed);            // TCTabBar を自動生成して Ed の上端に置く
    // フォームに置いた TCTabBar を使う場合: Binder.Attach(Ed, CTabBar1);
    FormCloseQuery:  CanClose := Binder.CloseAll;   // 未保存の確認をして全タブを閉じる

  ・タブの「+」で新規文書、「x」で閉じる（未保存なら確認）、ドラッグで並べ替え。
  ・変更ありのタブは名前の後ろに ' *' が付く。
  ・【2.20】タブを自分のアプリのウィンドウの外で離したら、OnDragOut で知らせる（タブの分離。設計書 4.11.1）。
    ほかのタブ列へタブだけを移すことはしない（文書を持たないタブだけが移り、対応が壊れるため）。
  ・未保存の確認は、Ed.OnQueryClose が未設定のときだけ標準ダイアログを使う。
  ・保存先が未定の文書は Ed.OnNeedFileName でファイル名を渡すこと（渡さないと保存されず閉じない）。 }
unit CMonacoTabs;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, Dialogs, Forms, uCPageControl, ucmmonacoview;

type
  { タブのアイコン（画像リストの番号）を決める。-1 でアイコンなし }
  TCMTabImageEvent = procedure(Sender: TObject; Index: Integer; const FileName: string;
    var ImageIndex: Integer) of object;

  { 【2.20】タブがアプリのウィンドウの外で離された。Index はそのタブの番号、X・Y は離した画面の位置 }
  TCMBinderDragOutEvent = procedure(Sender: TObject; Index, X, Y: Integer) of object;

  TCMTabBinder = class(TComponent)
  private
    FEditor: TCMMonacoView;
    FTabs: TCTabBar;
    FUpdating: Boolean;
    FFocusPending: Boolean;
    FFocusOnMouseUp: Boolean;
    FOldTabsMouseUp: TMouseEvent;
    FOnDragOut: TCMBinderDragOutEvent;   { 【2.20】 }
    FDragOutId: Integer;                 { 【2.20】外へ出したタブの文書の Id（並べ替えても変わらない） }
    FDragOutPos: TPoint;                 { 【2.20】離した画面の位置 }
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
    procedure ApplyTabColor(D: TCTabSheet);
    function ImageIndexFor(AIndex: Integer): Integer;

    procedure EditorDocListChange(Sender: TObject);
    procedure EditorDocumentChange(Sender: TObject; Index: Integer);
    procedure EditorActiveChange(Sender: TObject);
    procedure EditorQueryClose(Sender: TObject; Index: Integer; var CanClose: Boolean);

    procedure TabClick(Sender: TObject; AIndex: Integer);
    procedure TabPlusClick(Sender: TObject);
    procedure PageClose(Sender: TObject; APage: TCTabSheet; var CanClose: Boolean);
    procedure PageMoved(Sender: TObject; APage: TCTabSheet; AOldIndex, ANewIndex: Integer);
    procedure AsyncClose(Data: PtrInt);
    procedure AsyncFocus(Data: PtrInt);
    procedure FocusEditorLater;
    procedure TabsMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure TabDragOut(Sender: TObject; AIndex: Integer; const AScreenPos: TPoint; ATarget: TControl);   { 【2.20】 }
    procedure AsyncTabDragOut(Data: PtrInt);                          { 【2.20】 }
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Attach(AEditor: TCMMonacoView; ATabs: TCTabBar = nil);
    function CloseAll: Boolean;   { 未保存の確認をして全文書を閉じる。キャンセルされたら False }
    procedure Refresh;            { タブを作り直す（アイコンの設定を変えたときなど） }
    property OnGetImageIndex: TCMTabImageEvent read FOnGetImageIndex write FOnGetImageIndex;
    property Tabs: TCTabBar read FTabs;
    property Editor: TCMMonacoView read FEditor;
    property ConfirmClose: Boolean read FConfirmClose write FConfirmClose;
    { 【2.20】タブがアプリのウィンドウの外で離された（ドラッグの処理が終わってから呼ぶ） }
    property OnDragOut: TCMBinderDragOutEvent read FOnDragOut write FOnDragOut;
    { 選択中・マウスを乗せたタブの背景色を、全タブに設定する（フラット表示でも、選択中のタブを浮き上がらせるため） }
    procedure SetTabColors(AActive, AOver: TColor);
  end;

implementation

uses
  uCXLang,
  Windows;

const
  CM_GA_ROOT = 2;   { GetAncestor：一番外（トップレベル）のウィンドウ }

{ 【2.20】GetAncestor（user32）。FPC の Windows ユニットに無い版があるため、ここで宣言する }
function CMGetAncestor(AWnd: HWND; AFlags: UINT): HWND; stdcall; external 'user32.dll' name 'GetAncestor';

{ 【2.20】画面の位置 P が、自分のアプリのウィンドウの上ではないか。
  P の下のウィンドウの一番外（トップレベル）を調べ、自分のプロセスのものでなければ True。
  WebView2（エディタ・プレビュー）の中のウィンドウは自分のフォームの子なので、一番外は自分のフォームになり False。
  デスクトップ・ほかのアプリのウィンドウの上なら True }
function IsOutsideApp(const P: TPoint): Boolean;
var
  W, Root: HWND;
  Pid: DWORD;
begin
  W := Windows.WindowFromPoint(P);
  if W = 0 then Exit(True);
  Root := CMGetAncestor(W, CM_GA_ROOT);
  if Root = 0 then Root := W;
  Pid := 0;
  Windows.GetWindowThreadProcessId(Root, @Pid);
  Result := Pid <> Windows.GetCurrentProcessId;
end;

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
  if FTabs <> nil then
  begin
    FTabs.OnTabMouseUp := FOldTabsMouseUp;
    FTabs.OnTabDragOut := nil;
  end;
  inherited Destroy;
end;

procedure TCMTabBinder.Attach(AEditor: TCMMonacoView; ATabs: TCTabBar);
begin
  if AEditor = nil then
    raise Exception.Create(CXT(sErrTabBinder));
  FEditor := AEditor;
  if ATabs = nil then
  begin
    ATabs := TCTabBar.Create(Self);
    ATabs.Parent := AEditor.Parent;
    ATabs.Align := alTop;
  end;
  FTabs := ATabs;
  FTabs.TabStop := False;                  { タブ自体はキーボードのフォーカスを受け取らない }
  FOldTabsMouseUp := FTabs.OnTabMouseUp;
  FTabs.OnTabMouseUp := @TabsMouseUp;      { フォーカスは、マウスのボタンを離したあとでエディタへ戻す }
  { 【2.20】タブのドラッグを、タブ列の外で離したとき、アプリの外へ出したかを調べる（タブの分離）。
    ほかのタブ列へタブだけを移すことはしない（文書を持たないタブだけが移って、タブと文書の対応が壊れるため） }
  FTabs.OnTabDragOut := @TabDragOut;

  FTabs.OnTabClick := @TabClick;
  FTabs.OnTabPlusClick := @TabPlusClick;
  FTabs.OnPageClose := @PageClose;
  FTabs.OnPageMoved := @PageMoved;

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
  D: TCTabSheet;
begin
  if (FTabs = nil) or (FEditor = nil) then Exit;
  FUpdating := True;
  try
    FTabs.ClearTabs;
    for I := 0 to FEditor.DocumentCount - 1 do
    begin
      D := FTabs.AddTab(TabCaptionFor(I));   { 変更ありの印は、題名の「 *」で出す }
      D.Hint := FEditor.DocumentFileName[I];
      D.ImageIndex := ImageIndexFor(I);
      ApplyTabColor(D);
    end;
    if FEditor.ActiveIndex >= 0 then FTabs.TabIndex := FEditor.ActiveIndex;
  finally
    FUpdating := False;
  end;
  FTabs.Invalidate;
end;

procedure TCMTabBinder.ApplyTabColor(D: TCTabSheet);
begin
  if D = nil then Exit;
  { clNone（未設定）は、タブ列の指定に従う（clDefault） }
  if FColorActive = clNone then D.TabColorActive := clDefault else D.TabColorActive := FColorActive;
  if FColorOver = clNone then D.TabColorOver := clDefault else D.TabColorOver := FColorOver;
end;

procedure TCMTabBinder.SetTabColors(AActive, AOver: TColor);
var
  I: Integer;
begin
  FColorActive := AActive;
  FColorOver := AOver;
  if FTabs = nil then Exit;
  for I := 0 to FTabs.TabCount - 1 do
    ApplyTabColor(FTabs.Tabs[I]);
  FTabs.Invalidate;
end;

procedure TCMTabBinder.UpdateTab(AIndex: Integer);
var
  D: TCTabSheet;
begin
  if (FTabs = nil) or (AIndex < 0) or (AIndex >= FTabs.TabCount) then Exit;
  D := FTabs.Tabs[AIndex];
  D.Caption := TabCaptionFor(AIndex);
  D.Hint := FEditor.DocumentFileName[AIndex];
  D.ImageIndex := ImageIndexFor(AIndex);   { 名前を付けて保存で拡張子が変わったときも切り替わる }
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
  case MessageDlg(CXT(sUnsavedTitle),
      Format(CXT(sUnsavedLine1), [FEditor.DocumentTitle[Index]]) + LineEnding +
      CXT(sUnsavedLine2),
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

procedure TCMTabBinder.TabClick(Sender: TObject; AIndex: Integer);
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

{ ---------- 【2.20】タブを外へ出す（設計書 4.11.1） ---------- }

{ タブをドラッグして、タブ列の外で離したとき、TCTabBar が知らせる（Esc で取り消したときは来ない）。
  次をすべて満たすときだけ「アプリの外へ出した」とみなし、ドラッグの処理が終わってから OnDragOut で知らせる。
  ・タブが出ている（MultiDocument = False ならタブは隠れている）
  ・離した位置が、自分のアプリのウィンドウの上ではない（エディタ・プレビュー・別のフォームの上は除く） }
procedure TCMTabBinder.TabDragOut(Sender: TObject; AIndex: Integer; const AScreenPos: TPoint; ATarget: TControl);
begin
  if (FEditor = nil) or (FTabs = nil) then Exit;
  if not FTabs.Visible then Exit;
  if not Assigned(FOnDragOut) then Exit;
  if not IsOutsideApp(AScreenPos) then Exit;
  if (AIndex < 0) or (AIndex >= FEditor.DocumentCount) then Exit;
  FDragOutId := FEditor.DocumentId(AIndex);   { 並べ替えても変わらない Id で覚える }
  FDragOutPos := AScreenPos;
  { タブ列のドラッグの処理の途中でタブを閉じると、消えたタブを触るおそれがあるため、あとで知らせる }
  Application.QueueAsyncCall(@AsyncTabDragOut, 0);
end;
procedure TCMTabBinder.AsyncTabDragOut(Data: PtrInt);
var
  I: Integer;
begin
  if (FEditor = nil) or not Assigned(FOnDragOut) then Exit;
  I := FEditor.IndexOfId(FDragOutId);    { その間に閉じられていれば -1：何もしない }
  if I < 0 then Exit;
  FOnDragOut(Self, I, FDragOutPos.X, FDragOutPos.Y);
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

procedure TCMTabBinder.PageClose(Sender: TObject; APage: TCTabSheet; var CanClose: Boolean);
begin
  { タブの削除はエディタ側の閉じる処理 → タブ再構築で行う。確認ダイアログはマウス処理の外で出す }
  CanClose := False;
  Application.QueueAsyncCall(@AsyncClose, FTabs.IndexOf(APage));
end;

procedure TCMTabBinder.AsyncClose(Data: PtrInt);
begin
  if FEditor.CloseDocument(Data) and (FEditor.DocumentCount > 0) then
    FocusEditorLater;
end;

procedure TCMTabBinder.PageMoved(Sender: TObject; APage: TCTabSheet; AOldIndex, ANewIndex: Integer);
begin
  { タブ列は、もう並べ替えてある。エディタ側の並びを合わせる }
  if (AOldIndex < 0) or (ANewIndex < 0) then Exit;
  FUpdating := True;
  try
    FEditor.MoveDocument(AOldIndex, ANewIndex);
  finally
    FUpdating := False;
  end;
end;

end.