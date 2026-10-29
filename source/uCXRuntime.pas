{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ uCXRuntime - CX の WebView2 部品（TCTabBrowser・TCMonacoEditor）が共通で使う、
  実行時のファイルの場所を決める関数と、WebView2 の準備（TCTabBrowser_Design.md 9章）
  環境: Lazarus 4.8 / FPC 3.2.2 / Windows 11 x64

  EXE と同じフォルダーの WebView2.ini（必ず置く）の [WebView2] セクションを読む。

    [WebView2]
    LoaderDllPath=..\WebView2Loader.dll   ← WebView2Loader.dll のファイル（空なら EXE の隣）
    UserDataFolder=..\WebView2Data        ← WebView2 のユーザーデータ（空なら EXE の隣の WebView2Data）
    MonacoFolder=..\monaco                ← editor.html と vs があるフォルダー（空なら EXE の隣の monaco）
    PreviewFolder=..\preview              ← preview.html と lib があるフォルダー（空なら EXE の隣の preview）

  ・相対パスは EXE のフォルダーから数える。絶対パスも書ける。
  ・ini は、最初に使うときに 1 回だけ読む（実行中に書き換えても、次の起動まで効かない）。
  ・CXStartWebView2 は、アプリの中で最初の 1 回だけ GlobalWebView2Loader を作って起動する。
    2 回目からは、できているローダーの状態を返す（どの部品から呼んでも同じローダーを使う）。

  initialization・finalization は持たない。
  理由: このユニットは cx パッケージに入り、IDE にも組み込まれる。uses に入れただけで
  ファイルを読んだり何かを作ったりしないようにするため（部品が実行時に呼んだときだけ動く）。
  GlobalWebView2Loader は、WebView4Delphi の uWVLoader の finalization が解放する。 }
unit uCXRuntime;

{$mode objfpc}{$H+}

interface

{ WebView2.ini の [WebView2] セクションから、AKey の値を返す。無ければ ''（前後の空白は除く） }
function CXRuntimeIniValue(const AKey: string): string;

{ 相対パスを、EXE のフォルダーから数えた絶対パスにする。'..' も取り除く。'' なら '' }
function CXFullPath(const APath: string): string;

{ monaco・preview フォルダーの場所を決める。
  ① AProperty（MonacoPath・PreviewPath）が空でなければ、その場所
  ② 空なら、WebView2.ini の AIniKey（MonacoFolder・PreviewFolder）が空でなければ、その場所
  ③ それも空なら、EXE のフォルダー ＋ ADefaultName（'monaco'・'preview'）
  最後の '\' は付けない }
function CXResolveRuntimeDir(const AProperty, AIniKey, ADefaultName: string): string;

{ WebView2 を準備する（GlobalWebView2Loader を作って StartWebView2 する）。
  ・すでにローダーがあれば、作らずに状態だけ返す（初期化に失敗していれば False と、そのエラーの文）
  ・EXE の隣に WebView2.ini が無ければ False（AError に「WebView2.ini が見つかりません: 場所」）
  ・WebView2Loader.dll の場所は ini の LoaderDllPath、ユーザーデータは UserDataFolder
  ・エラーはメッセージ箱を出さず、AError で返す（呼んだ部品が OnError・例外で知らせる）
  ・True でも、既定の環境の作成は非同期で続く（Initialized になるまで待つのは呼んだ側） }
function CXStartWebView2(out AError: string): Boolean;

implementation

uses
  Classes, SysUtils, IniFiles, uWVLoader;

const
  INI_NAME = 'WebView2.ini';
  INI_SECTION = 'WebView2';

var
  { ini を読んだか（読むのは最初の 1 回だけ） }
  GIniLoaded: Boolean = False;
  { [WebView2] セクションの中身を「キー=値」の行で覚えておく（文字列なので解放は要らない） }
  GIniText: string = '';

{ EXE のフォルダー（最後に '\' が付く） }
function ExeDir: string;
begin
  Result := ExtractFilePath(ParamStr(0));
end;

{ 最初に呼ばれたときだけ、WebView2.ini の [WebView2] セクションを読んで GIniText に覚える }
procedure LoadIni;
var
  FileName: string;
  Ini: TIniFile;
  Values: TStringList;
begin
  if GIniLoaded then Exit;
  GIniLoaded := True;
  GIniText := '';
  FileName := ExeDir + INI_NAME;
  if not FileExists(FileName) then Exit;   { ini が無い：どのキーも空 }
  Values := TStringList.Create;
  try
    try
      Ini := TIniFile.Create(FileName);
      try
        Ini.ReadSectionValues(INI_SECTION, Values);
      finally
        Ini.Free;
      end;
      GIniText := Values.Text;
    except
      GIniText := '';                      { 読めない：どのキーも空（例外は出さない） }
    end;
  finally
    Values.Free;
  end;
end;

function CXRuntimeIniValue(const AKey: string): string;
var
  Values: TStringList;
begin
  LoadIni;
  Result := '';
  if GIniText = '' then Exit;
  { 覚えておいた「キー=値」の行から、キーの値を探す（キーの大文字・小文字は区別しない） }
  Values := TStringList.Create;
  try
    Values.Text := GIniText;
    Result := Trim(Values.Values[AKey]);
  finally
    Values.Free;
  end;
end;

function CXFullPath(const APath: string): string;
begin
  if APath = '' then Exit('');
  { ドライブ名（C: や \\サーバー）が無ければ、EXE のフォルダーの後ろにつなぐ }
  if ExtractFileDrive(APath) = '' then
    Result := ExeDir + APath
  else
    Result := APath;
  { '..' を取り除いた絶対パスにする（例 C:\app\bin\..\monaco → C:\app\monaco） }
  Result := ExpandFileName(Result);
end;

function CXResolveRuntimeDir(const AProperty, AIniKey, ADefaultName: string): string;
var
  S: string;
begin
  if AProperty <> '' then
    Result := CXFullPath(AProperty)                 { ① プロパティ }
  else
  begin
    S := CXRuntimeIniValue(AIniKey);
    if S <> '' then
      Result := CXFullPath(S)                       { ② WebView2.ini }
    else
      Result := ExeDir + ADefaultName;              { ③ EXE の隣 }
  end;
  Result := ExcludeTrailingPathDelimiter(Result);
end;

function CXStartWebView2(out AError: string): Boolean;
var
  IniName, S: string;
begin
  AError := '';

  { 1. すでにローダーがある（ほかの部品が先に作った）：作らずに状態を返す }
  if Assigned(GlobalWebView2Loader) then
  begin
    if GlobalWebView2Loader.InitializationError then
    begin
      AError := UTF8Encode(UnicodeString(GlobalWebView2Loader.ErrorMessage));
      Exit(False);
    end;
    Exit(True);
  end;

  { 2. WebView2.ini は必ず置く。無ければ作らずに失敗を返す }
  IniName := ExeDir + INI_NAME;
  if not FileExists(IniName) then
  begin
    AError := 'WebView2.ini が見つかりません: ' + IniName;
    Exit(False);
  end;

  { 3. ローダーを作り、ini の場所を設定して起動する。
       失敗してもローダーは残す（次に呼ばれたときも、同じエラーを 1 で返す） }
  GlobalWebView2Loader := TWVLoader.Create(nil);
  GlobalWebView2Loader.ShowMessageDlg := False;          { エラーの箱は出さず、AError で返す }
  S := CXRuntimeIniValue('LoaderDllPath');
  if S <> '' then
    GlobalWebView2Loader.LoaderDllPath := CXFullPath(S);  { 空なら設定しない（EXE の隣の dll） }
  S := CXRuntimeIniValue('UserDataFolder');
  if S = '' then S := 'WebView2Data';
  GlobalWebView2Loader.UserDataFolder := CXFullPath(S);
  if not GlobalWebView2Loader.StartWebView2 then
  begin
    AError := UTF8Encode(UnicodeString(GlobalWebView2Loader.ErrorMessage));
    if AError = '' then AError := 'WebView2 を起動できません';
    Exit(False);
  end;
  Result := True;
end;

end.
