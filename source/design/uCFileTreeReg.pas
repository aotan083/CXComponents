{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ TCFileTree の登録（設計時パッケージ cxdsgn に入れる）
  設計書: docs\TCFileTree_Design.md
  パレットのアイコンは cfiletree_icon.lrs（tcfiletree・tcfiletree_150・tcfiletree_200 の PNG）。
  Lazarus のパレットは、クラス名と同じ名前のリソース（150%・200% は _150・_200 付き）を探して表示する }
unit uCFileTreeReg;

{$mode objfpc}{$H+}

interface

uses
  Classes, LResources, CFileTree;

procedure Register;

implementation

{ コンポーネントパレットの CX ページに TCFileTree を登録する }
procedure Register;
begin
  RegisterComponents('CX', [TCFileTree]);
end;

initialization
  { パレットのアイコンを読み込む }
  {$I cfiletree_icon.lrs}

end.
