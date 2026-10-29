unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, ExtCtrls,
  uCbookmark, uCmonacos, uCTabBrowser;

type

  { TForm1 }

  TForm1 = class(TForm)
    CBookmark1: TCBookmark;
    CMonacoEditor1: TCMonacoEditor;
    CTabBrowser1: TCTabBrowser;
    Panel1: TPanel;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    StatusBar1: TStatusBar;
  private

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

end.

