unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, uCmonacos, ucmmonacoview;

type

  { TForm1 }

  TForm1 = class(TForm)
    CMonacoEditor1: TCMonacoEditor;
    StatusBar1: TStatusBar;

      procedure CMonacoEditor1CursorChange(Sender: TObject; Line, Column: Integer);
      procedure CMonacoEditor1ModeChange(Sender: TObject; IsOverwrite: Boolean);
      procedure CMonacoEditor1ModifiedChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
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
  CMonacoEditor1.Align := alClient;
end;

procedure TForm1.CMonacoEditor1CursorChange(Sender: TObject; Line, Column: Integer);
var
  s: String;
begin
  s := Format( '%d:%d', [Column, Line] );
  StatusBar1.Panels[ 1 ].Text := s;
end;

procedure TForm1.CMonacoEditor1ModeChange(Sender: TObject; IsOverwrite: Boolean);
var
  s: String;
begin
  Case IsOverwrite of
    True : s := '上書';
    False: s := '挿入';
  end;
  StatusBar1.Panels[ 2 ].Text := s;
end;

procedure TForm1.CMonacoEditor1ModifiedChange(Sender: TObject);
begin
  if CMonacoEditor1.Modified then
    Caption := CMonacoEditor1.FileName + '(*)'
  else
    Caption := CMonacoEditor1.FileName;
end;

end.

