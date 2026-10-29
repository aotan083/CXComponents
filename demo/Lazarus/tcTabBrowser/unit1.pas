unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, uCTabBrowser;

type

  { TForm1 }

  TForm1 = class(TForm)
    CTabBrowser1: TCTabBrowser;
    StatusBar1: TStatusBar;
    procedure FormCreate(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

const
  s1 = 'https://www.yahoo.co.jp/';
  s2 = 'https://www.youtube.com/?app=desktop&hl=ja';
  s3 = 'https://gemini.google.com/app';


procedure TForm1.FormCreate(Sender: TObject);
begin
  CTabBrowser1.Align := alClient;

  CTabBrowser1.Add( s1 );  // Yahoo検索
  CTabBrowser1.Add( s2 );  // Youtube
  CTabBrowser1.Add( s3 );  // gemini
end;

end.

