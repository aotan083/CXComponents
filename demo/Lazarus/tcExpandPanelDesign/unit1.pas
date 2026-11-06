{ tcExpandPanelDesign - TCExpandPanel の設計時の確認用。
  フォームに TCSideBar → ページ → TCExpandPanel（alClient）→ TCRollout 3 つ（TCBookmark・TCFileTree・TCSynEdit が alClient）を置いてある。
  確認すること：
  1. 3 つ目のパネルが、下まで余りを埋めている。
  2. パネルとパネルの間の細い隙間（点線）を、マウスで上下に引くと、隣と分け合って大きさが変わる。
  3. 引いたあとフォームを保存すると、ExpandedSize が .lfm に入る。
  実行（F9）して、サイドバーの高さを変えても、同じ動きになる。 }
unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, uCSideBar,
  uCExpandPanel, uCbookmark, CFileTree, csynedit, uCmonacos, uCsEditor,
  uCPreview, uCSplitter;

type

  { TForm1 }

  TForm1 = class(TForm)
    CBookmark1: TCBookmark;
    CExpandPanel1: TCExpandPanel;
    CFileTree1: TCFileTree;
    CRollout1: TCRollout;
    CRollout2: TCRollout;
    CRollout3: TCRollout;
    CsEditor1: TCsEditor;
    CsEditor2: TCsEditor;
    CSideBar1: TCSideBar;
    CSideBarPage1: TCSideBarPage;
    CSideBarPage2: TCSideBarPage;
    CPreview1: TCPreview;
  private
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

end.
