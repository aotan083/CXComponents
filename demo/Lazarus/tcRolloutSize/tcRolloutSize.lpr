{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ tcRolloutSize - TCExpandPanel の中の TCRollout の大きさ（Height・ExpandedSize）が、どう決まるかを確かめるアプリ
  結果は、EXE の隣の result.txt に書いて、すぐ終わる。 }
program tcRolloutSize;

{$mode objfpc}{$H+}

uses
  Interfaces, Classes, Forms, Controls, SysUtils, uCExpandPanel;

var
  F: TForm;
  EP: TCExpandPanel;
  R1, R2: TCRollout;
  Log: TStringList;

procedure Settle;
begin
  Application.ProcessMessages;
  Application.ProcessMessages;
end;

procedure Show(const S: string);
begin
  Log.Add(Format('%-46s R1.Height=%d R1.ExpandedSize=%d | R2.Height=%d R2.ExpandedSize=%d',
    [S, R1.Height, R1.ExpandedSize, R2.Height, R2.ExpandedSize]));
end;

begin
  Log := TStringList.Create;
  Application.Initialize;
  Application.CreateForm(TForm, F);
  F.SetBounds(50, 50, 400, 900);
  EP := TCExpandPanel.Create(F);
  EP.Parent := F;
  EP.Align := alClient;
  R1 := TCRollout.Create(F);
  R1.Caption := 'R1';
  EP.AddPanel(R1);
  R2 := TCRollout.Create(F);
  R2.Caption := 'R2';
  EP.AddPanel(R2);
  F.Show;
  Settle;
  Show('1. 初期（Fill=False）');

  R1.Height := 300;
  Settle;
  Show('2. R1.Height := 300');

  R1.ExpandedSize := 200;
  Settle;
  Show('3. R1.ExpandedSize := 200');

  R1.SetBounds(R1.Left, R1.Top, R1.Width, 350);
  Settle;
  Show('4. R1.SetBounds(..., Height=350)（ドラッグ相当）');

  R2.Fill := True;
  Settle;
  Show('5. R2.Fill := True');

  R2.Height := 120;
  Settle;
  Show('6. R2.Height := 120（Fill=True のパネル）');

  R1.Height := 180;
  Settle;
  Show('7. R1.Height := 180（もう片方が Fill=True）');

  R1.Expanded := False;
  Settle;
  Show('8. R1.Expanded := False');
  R1.Height := 300;
  Settle;
  Show('9. R1.Height := 300（閉じているパネル）');

  Log.SaveToFile(ExtractFilePath(ParamStr(0)) + 'result.txt');
  Log.Free;
end.
