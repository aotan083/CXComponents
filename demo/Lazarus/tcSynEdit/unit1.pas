unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, csynedit;

type

  { TForm1 }

  TForm1 = class(TForm)
    CSynEdit1: TCSynEdit;
    StatusBar1: TStatusBar;
    procedure CSynEdit1CaretChangeEvent(Sender: TObject; var iX, iY: Integer);
    procedure CSynEdit1InsModeChangeEvent(Sender: TObject; var bMode: Boolean);
    procedure CSynEdit1ModifiedChangeEvent(Sender: TObject; var bModified: Boolean);
  private

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.CSynEdit1CaretChangeEvent(Sender: TObject; var iX, iY: Integer);
var
  s: String;
begin
  s := Format( '%d:%d', [iX, iY] );
  StatusBar1.Panels[ 2 ].Text := s;
end;

procedure TForm1.CSynEdit1InsModeChangeEvent(Sender: TObject; var bMode: Boolean);
var
  s: String;
begin
  s := '';
  Case bMode of
    True  : s := '挿入';
    False : s := '上書';
  end;
  StatusBar1.Panels[ 1 ].Text := s;
end;

procedure TForm1.CSynEdit1ModifiedChangeEvent(Sender: TObject; var bModified: Boolean);
var
  s: String;
begin
  s := '';
  Case bModified of
    True  : s := '変更';
    False : s := '';
  end;
  StatusBar1.Panels[ 0 ].Text := s;

  if bModified then
    Caption := '* ' + CSynEdit1.DisplayTitle
  else
    Caption := CSynEdit1.DisplayTitle;
end;

end.

