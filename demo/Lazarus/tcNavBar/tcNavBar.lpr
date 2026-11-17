{ tcNavBar - TCAddressBar・TCSearchBox を、TCTreeView・TCListView と組み合わせて、目で見て・手で操作して確認する見本。
  左：TCTreeView、右上：アドレスバーと検索ボックス、右：TCListView、下：状態表示。
  確認すること：パンくずの移動・「>」の一覧・「…」・入力モード（Ctrl+L・Alt+D・F4）・戻る/進む/上へ/更新・最近の場所、
  検索（Enter・Esc・×・虫眼鏡のメニュー・部分一致/ワイルドカード/正規表現）。 }
program tcNavBar;

{$mode objfpc}{$H+}

uses
  Interfaces, Classes, SysUtils, Forms, Controls, ExtCtrls, StdCtrls, CTreeView, CListView, uCAddressBar,
  uCSearchBox, uCFindFile, uCXLang;

type
  TMainForm = class(TForm)
  public
    Tree: TCTreeView;
    List: TCListView;
    Addr: TCAddressBar;
    Search: TCSearchBox;
    Status: TLabel;
    Top1: TPanel;
    procedure OnNavigated(Sender: TObject; const APath: string);
    procedure OnFinished(Sender: TObject; AFound: Integer; AReason: TCFindStopReason);
    procedure OnSearchError(Sender: TObject; const AMessage: string);
    procedure OnAddrError(Sender: TObject; const AMessage: string);
    procedure OnFolder(Sender: TObject);
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
  end;

constructor TMainForm.CreateNew(AOwner: TComponent; Num: Integer);
begin
  inherited CreateNew(AOwner, Num);
  Caption := 'tcNavBar - TCAddressBar / TCSearchBox';
  SetBounds(100, 100, 1000, 600);
  Tree := TCTreeView.Create(Self);
  Tree.Parent := Self;
  Tree.Align := alLeft;
  Tree.Width := 240;
  with TSplitter.Create(Self) do
  begin
    Parent := Self;
    Align := alLeft;
    Left := 245;
  end;
  Status := TLabel.Create(Self);
  Status.Parent := Self;
  Status.Align := alBottom;
  Status.Caption := '';
  Top1 := TPanel.Create(Self);
  Top1.Parent := Self;
  Top1.Align := alTop;
  Top1.Height := 38;
  Top1.BevelOuter := bvNone;
  Search := TCSearchBox.Create(Self);
  Search.Parent := Top1;
  Search.Align := alRight;
  Search.Width := 280;
  Addr := TCAddressBar.Create(Self);
  Addr.Parent := Top1;
  Addr.Align := alClient;
  List := TCListView.Create(Self);
  List.Parent := Self;
  List.Align := alClient;
  Tree.ShellListView := List;
  Addr.ListView := List;
  Addr.TreeView := Tree;
  Search.ListView := List;
  Search.TreeView := Tree;
  Addr.OnNavigated := @OnNavigated;
  Addr.OnError := @OnAddrError;
  Search.OnSearchFinished := @OnFinished;
  Search.OnSearchError := @OnSearchError;
  List.OnFolderChanged := @OnFolder;
  Tree.Path := 'C:\';
  List.NavigateTo('C:\');
end;

procedure TMainForm.OnNavigated(Sender: TObject; const APath: string);
begin
  Status.Caption := '移動：' + APath;
end;

procedure TMainForm.OnFolder(Sender: TObject);
begin
  Status.Caption := 'フォルダー：' + List.Root + '   結果の表示：' + BoolToStr(List.ResultsMode, True);
end;

procedure TMainForm.OnFinished(Sender: TObject; AFound: Integer; AReason: TCFindStopReason);
begin
  Status.Caption := Format('検索が終わりました：%d 件（理由 %d）', [AFound, Ord(AReason)]);
end;

procedure TMainForm.OnSearchError(Sender: TObject; const AMessage: string);
begin
  Status.Caption := 'エラー：' + AMessage;
end;

procedure TMainForm.OnAddrError(Sender: TObject; const AMessage: string);
begin
  Status.Caption := 'エラー：' + AMessage;
end;

var
  F: TMainForm;
begin
  Application.Initialize;
  F := TMainForm.CreateNew(Application);
  F.ShowModal;
end.
