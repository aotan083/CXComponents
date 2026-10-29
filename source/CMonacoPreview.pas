{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ TCMPreviewBinder - TCMMonacoView と TCMMarkdownPreview をつなぐ
  ※ 第2版から、TCMonacoEditor（ucmonacos.pas）が内部で使う部品になった。アプリから直接使う必要はない。

  使い方（フォーム側）:
    PreviewBinder := TCMPreviewBinder.Create(Self);
    PreviewBinder.Attach(Ed, Prev);

  ・アクティブなタブの言語が markdown なら文書を、それ以外なら色分けしたコード（行番号付き）を表示する【段階5】。
    .md / .markdown のファイルは、開いたときに自動で markdown になる。
  ・編集後、DelayMs（既定 300ms）待ってから更新する。タブの切り替えは、すぐに更新する。
  ・スクロールの同期: SyncScroll（ssBoth=双方向（既定） / ssEditorToPreview=エディタからのみ / ssNone=なし）。
  ・プレビューの Theme は、エディタの Theme に合わせる（配色は、既定でエディタと同じ）。
  ・プレビュー内の .md へのリンクは、Prev.OnOpenMarkdown が未設定なら、エディタで開く。 }
unit CMonacoPreview;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ExtCtrls, ucmmonacoview, ucmdpreview;

type
  TCMSyncScroll = (ssNone, ssEditorToPreview, ssBoth);

  TCMPreviewBinder = class(TComponent)
  private
    FEditor: TCMMonacoView;
    FPreview: TCMMarkdownPreview;
    FTimer: TTimer;
    FDelayMs: Integer;
    FOldChange: TNotifyEvent;
    FOldActiveChange: TNotifyEvent;
    FOldDocListChange: TNotifyEvent;
    FOldDocumentChange: TCMDocIndexEvent;
    FOldScrollChange: TCMScrollEvent;
    FOldReady: TNotifyEvent;
    FOldScrollLine: TCMScrollLineEvent;
    FSyncScroll: TCMSyncScroll;

    procedure PreviewScrollLine(Sender: TObject; Line: Double);
    procedure SetDelayMs(AValue: Integer);
    procedure Schedule;
    procedure TimerTick(Sender: TObject);
    procedure EditorChange(Sender: TObject);
    procedure EditorActiveChange(Sender: TObject);
    procedure EditorDocListChange(Sender: TObject);
    procedure EditorDocumentChange(Sender: TObject; Index: Integer);
    procedure EditorScrollChange(Sender: TObject; TopLine: Double);
    procedure PreviewReady(Sender: TObject);
    procedure PreviewOpenMarkdown(Sender: TObject; const AFileName: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Attach(AEditor: TCMMonacoView; APreview: TCMMarkdownPreview);
    procedure Refresh;    { すぐに更新する }
    property DelayMs: Integer read FDelayMs write SetDelayMs;
    property SyncScroll: TCMSyncScroll read FSyncScroll write FSyncScroll;   { ssNone / ssEditorToPreview / ssBoth（既定） }
  end;

implementation

constructor TCMPreviewBinder.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDelayMs := 300;
  FSyncScroll := ssBoth;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := FDelayMs;
  FTimer.OnTimer := @TimerTick;
end;

destructor TCMPreviewBinder.Destroy;
begin
  FTimer.Enabled := False;
  if FEditor <> nil then
  begin
    FEditor.OnChange := FOldChange;
    FEditor.OnActiveChange := FOldActiveChange;
    FEditor.OnDocListChange := FOldDocListChange;
    FEditor.OnDocumentChange := FOldDocumentChange;
    FEditor.OnScrollChange := FOldScrollChange;
  end;
  if FPreview <> nil then
  begin
    FPreview.OnReady := FOldReady;
    FPreview.OnScrollLine := FOldScrollLine;
  end;
  inherited Destroy;
end;

procedure TCMPreviewBinder.Attach(AEditor: TCMMonacoView; APreview: TCMMarkdownPreview);
begin
  if (AEditor = nil) or (APreview = nil) then
    raise Exception.Create('TCMPreviewBinder.Attach: エディタまたはプレビューが nil です');
  FEditor := AEditor;
  FPreview := APreview;

  FOldChange := FEditor.OnChange;
  FOldActiveChange := FEditor.OnActiveChange;
  FOldDocListChange := FEditor.OnDocListChange;
  FOldDocumentChange := FEditor.OnDocumentChange;
  FOldScrollChange := FEditor.OnScrollChange;
  FEditor.OnChange := @EditorChange;
  FEditor.OnActiveChange := @EditorActiveChange;
  FEditor.OnDocListChange := @EditorDocListChange;
  FEditor.OnDocumentChange := @EditorDocumentChange;
  FEditor.OnScrollChange := @EditorScrollChange;

  FOldReady := FPreview.OnReady;
  FPreview.OnReady := @PreviewReady;
  FOldScrollLine := FPreview.OnScrollLine;
  FPreview.OnScrollLine := @PreviewScrollLine;
  if not Assigned(FPreview.OnOpenMarkdown) then
    FPreview.OnOpenMarkdown := @PreviewOpenMarkdown;

  Refresh;
end;

procedure TCMPreviewBinder.SetDelayMs(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  FDelayMs := AValue;
  FTimer.Interval := AValue;
end;

procedure TCMPreviewBinder.Refresh;
var
  T: string;
begin
  FTimer.Enabled := False;
  if (FEditor = nil) or (FPreview = nil) then Exit;
  if FPreview.Theme <> FEditor.Theme then FPreview.Theme := FEditor.Theme;   { エディタのテーマに合わせる }
  { 【段階5】印刷の PDF の名前：ページの名前から元の拡張子を外す（abc.md → abc、無題 → 無題） }
  if FEditor.ActiveIndex >= 0 then
  begin
    T := FEditor.DocumentTitle[FEditor.ActiveIndex];
    if ChangeFileExt(T, '') <> '' then T := ChangeFileExt(T, '');
    FPreview.DocTitle := T;
  end;
  if FEditor.ActiveIndex < 0 then
    FPreview.Clear
  else if SameText(FEditor.Language, 'markdown') then
    FPreview.ShowMarkdown(FEditor.Text, ExtractFilePath(FEditor.FileName))
  else
    FPreview.ShowCode(FEditor.Text, FEditor.Language);   { 【段階5】Markdown 以外は、色分けしたコード }
  FPreview.SetTopLine(FEditor.TopLine);
end;

procedure TCMPreviewBinder.Schedule;
begin
  FTimer.Enabled := False;
  if FDelayMs <= 0 then
    Refresh
  else
    FTimer.Enabled := True;
end;

procedure TCMPreviewBinder.TimerTick(Sender: TObject);
begin
  Refresh;
end;

procedure TCMPreviewBinder.EditorChange(Sender: TObject);
begin
  Schedule;
  if Assigned(FOldChange) then FOldChange(Sender);
end;

procedure TCMPreviewBinder.EditorActiveChange(Sender: TObject);
begin
  Refresh;
  if Assigned(FOldActiveChange) then FOldActiveChange(Sender);
end;

procedure TCMPreviewBinder.EditorDocListChange(Sender: TObject);
begin
  Refresh;
  if Assigned(FOldDocListChange) then FOldDocListChange(Sender);
end;

procedure TCMPreviewBinder.EditorDocumentChange(Sender: TObject; Index: Integer);
begin
  if Index = FEditor.ActiveIndex then Schedule;
  if Assigned(FOldDocumentChange) then FOldDocumentChange(Sender, Index);
end;

procedure TCMPreviewBinder.EditorScrollChange(Sender: TObject; TopLine: Double);
begin
  if FSyncScroll <> ssNone then FPreview.SetTopLine(TopLine);
  if Assigned(FOldScrollChange) then FOldScrollChange(Sender, TopLine);
end;

procedure TCMPreviewBinder.PreviewScrollLine(Sender: TObject; Line: Double);
begin
  if FSyncScroll = ssBoth then FEditor.ScrollToLine(Line);
  if Assigned(FOldScrollLine) then FOldScrollLine(Sender, Line);
end;

procedure TCMPreviewBinder.PreviewReady(Sender: TObject);
begin
  Refresh;
  if Assigned(FOldReady) then FOldReady(Sender);
end;

procedure TCMPreviewBinder.PreviewOpenMarkdown(Sender: TObject; const AFileName: string);
begin
  FEditor.OpenFile(AFileName);
end;

end.
