unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, PairSplitter,
  CFileTree, csynedit, uCmonacos, uCsEditor, uCTabBrowser;

type

  { TForm1 }

  TForm1 = class(TForm)
    CFileTree1: TCFileTree;
    CsEditor1: TCsEditor;
    CTabBrowser1: TCTabBrowser;
    PairSplitter1: TPairSplitter;
    PairSplitterSide1: TPairSplitterSide;
    PairSplitterSide2: TPairSplitterSide;
    Splitter1: TSplitter;
  private

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

end.

