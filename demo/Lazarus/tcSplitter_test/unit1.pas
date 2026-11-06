unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, uCTabBrowser,
  uCSplitter, uCmonacos;

type

  { TForm1 }

  TForm1 = class(TForm)
    CMonacoEditor1: TCMonacoEditor;
    CSplitter1: TCSplitter;
    CTabBrowser1: TCTabBrowser;
  private

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

end.

