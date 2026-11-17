{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
unit fpsvg.fonts.provider;

{ svg の文字（フォント）の部品を、持たない版。
  Lazarus 付属の同名のユニット（components\svgimage\fcl-svg）は、Windows では fpsvg.gdi を使うが、
  fpsvg.gdi は FPC 3.2.2 でコンパイルできない（FindClose の型が合わない）。
  freetype に切り替える方法（-dSVGFREETYPE）は、freetype.dll が無いと exe が起動しない。
  そこで、同名のこのユニットを source に置き、検索パスの先頭にして、付属のものの代わりに使う。
  ・図形・パスの svg は、そのまま描ける
  ・svg の中の「文字」は、描かれない（フォントの提供元が無い＝ nil。付属のコードが想定している動き）
  設計書：docs\TCImage_Design.md 3 章 }

{$mode objfpc}{$H+}

interface

uses
  fpsvg.types;

{ この版は、フォントの提供元が無いことを示す }
function SVGPlatformFontEngine: String;
{ いつも nil（文字は描かれない） }
function SVGPlatformFontProvider: ISVGFontProvider;

implementation

function SVGPlatformFontEngine: String;
begin
  Result := '';
end;

function SVGPlatformFontProvider: ISVGFontProvider;
begin
  Result := nil;
end;

end.
