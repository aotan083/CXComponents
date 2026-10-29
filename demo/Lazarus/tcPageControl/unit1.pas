unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, ExtCtrls,
  StdCtrls, Buttons, uCTitleBar, uCSideBar, uCPageControl, uCCheckGroupBox,
  uCTabBrowser, csynedit;

type

  { TForm1 }

  TForm1 = class(TForm)
    CPageControl1: TCPageControl;
    CSynEdit1: TCSynEdit;
    CTabBrowser1: TCTabBrowser;
    CTabSheet1: TCTabSheet;
    CTabSheet2: TCTabSheet;
    CTitleBar1: TCTitleBar;
    Edit1: TEdit;
    ImageList1: TImageList;
    Panel1: TPanel;
    SpeedButton1: TSpeedButton;
    StatusBar1: TStatusBar;
    procedure FormCreate(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
 CPageControl1.Align := alClient;
 CTabBrowser1.Align := alClient;
 CSynEdit1.Align := alClient;

 Edit1.Text := 'https://www.yahoo.co.jp/';
end;

procedure TForm1.SpeedButton1Click(Sender: TObject);
var
  s: String;
begin
  s := Edit1.Text;
  s := Trim( s );
  if Length( s ) < 1 then
    Exit;

  CTabBrowser1.Add( s );
end;

end.

