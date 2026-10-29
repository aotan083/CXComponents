unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, ExtCtrls,
  CTreeView, CListView;

type

  { TForm1 }

  TForm1 = class(TForm)
    CListView1: TCListView;
    CTreeView1: TCTreeView;
    Splitter1: TSplitter;
    StatusBar1: TStatusBar;
  private

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

end.

