{ tcEditorPreview - TCsEditor・TCPreview の設計時の設定と、実行時の状態を調べる確認用。
  フォームには、右から順に TCPreview（alRight）・TSplitter（alRight）・TCsEditor（alClient）を置き、
  TCsEditor.Preview = TCPreview にしてある。TCsEditor.Theme = ctLight。
  実行すると、起動時の状態を result.txt に書く（引数 /show なら、開いたままにする）。 }
unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  uCsEditor, uCPreview;

type
  TForm1 = class(TForm)
    CPreview1: TCPreview;
    CsEditor1: TCsEditor;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

procedure TForm1.FormCreate(Sender: TObject);
begin
end;

procedure TForm1.FormShow(Sender: TObject);
var
  L: TStringList;
begin
  if SameText(ParamStr(1), '/show') then Exit;
  Application.ProcessMessages;
  L := TStringList.Create;
  try
    L.Add(Format('CPreview1: Align=%d Visible=%s Width=%d Left=%d', [Ord(CPreview1.Align), BoolToStr(CPreview1.Visible, True), CPreview1.Width, CPreview1.Left]));
    L.Add(Format('CsEditor1: Align=%d Left=%d Width=%d', [Ord(CsEditor1.Align), CsEditor1.Left, CsEditor1.Width]));
    L.Add(Format('CsEditor1.ShowPreview=%s Theme=%d', [BoolToStr(CsEditor1.ShowPreview, True), Ord(CsEditor1.Theme)]));
    L.Add(Format('CsEditor1.IsDarkTheme=%s', [BoolToStr(CsEditor1.IsDarkTheme, True)]));
    L.Add(Format('CsEditor1.Color=$%x（ctDark なら $1E1E1E、ctLight なら $FFFFFF）', [Integer(CsEditor1.Color)]));
    L.SaveToFile(ExtractFilePath(ParamStr(0)) + 'result.txt');
  finally
    L.Free;
  end;
  Close;
end;

end.
