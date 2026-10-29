{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ TCBookmark の登録（設計時パッケージ cxdsgn に入れる）
  設計書: docs\TCBookmark_Design.md
  パレットのアイコンは cbookmark_icon.lrs（tcbookmark・tcbookmark_150・tcbookmark_200 の PNG）。
  Lazarus のパレットは、クラス名と同じ名前のリソース（150%・200% は _150・_200 付き）を探して表示する }
unit uCbookmark_reg;

{$mode objfpc}{$H+}

interface

uses
  Classes, LResources, uCbookmark;

procedure Register;

implementation

{ コンポーネントパレットの CX ページに TCBookmark を登録する }
procedure Register;
begin
  RegisterComponents('CX', [TCBookmark]);
end;

initialization
  { パレットのアイコン（14.1）を読み込む }
  {$I cbookmark_icon.lrs}

end.
