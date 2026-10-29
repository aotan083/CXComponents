unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, ExtCtrls,
  StdCtrls, Buttons,

  LCLType,

  uCSideBar,
  CListView,
  CTreeView,
  uCTabBrowser,
  uCmmonacoview,
  uCmonacos;

type

  { TForm1 }

  TForm1 = class(TForm)
    CListView1: TCListView;
    cm1: TCMonacoEditor;
    CSideBar1: TCSideBar;
    CSideBarPage1: TCSideBarPage;
    CSideBarPage2: TCSideBarPage;
    CTabBrowser1: TCTabBrowser;
    CTreeView1: TCTreeView;
    Edit1: TEdit;
    ImageList1: TImageList;
    Panel1: TPanel;
    SpeedButton1: TSpeedButton;
    Splitter1: TSplitter;
    StatusBar1: TStatusBar;
    procedure CListView1DblClick(Sender: TObject);
    procedure cm1Change(Sender: TObject);
    procedure Edit1KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormCreate(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
  private
    procedure DoOpen;
  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin

// ShowMessage(CXResolveRuntimeDir('', 'MonacoFolder', 'monaco'));

 CTabBrowser1.Align := alClient;
 cm1.Align := alClient;
 Edit1.Text := 'https://www.yahoo.co.jp/';
end;

procedure TForm1.SpeedButton1Click(Sender: TObject);
begin
  DoOpen;
end;

procedure TForm1.Edit1KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    DoOpen;
    Key := 0;
    Exit;
  end;
end;

procedure TForm1.CListView1DblClick(Sender: TObject);
var
  Path: string;
begin
  // OnDblClick を設定すると、部品のダブルクリックの動きは行わない。フォルダーへの移動も自分で書く
  Path := CListView1.GetSelectedFilePath;
  if Path = '' then
    Exit;

  if DirectoryExists(Path) then
     CListView1.NavigateTo(Path)
  else
    cm1.OpenFile( Path );
end;

procedure TForm1.cm1Change(Sender: TObject);
begin

end;

procedure TForm1.DoOpen;
var
  s: String;
  n: Integer;
begin
 s := Edit1.Text;
 s := Trim( s );
 if Length( s ) < 1 then
   Exit;

 n := CTabBrowser1.Add( s );
 if n < 1 then
   SpeedButton1.ImageIndex := 4
 else
   SpeedButton1.ImageIndex := 5;
end;




































end.

