{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
unit CShellDragDrop;

{
  D&D の共通部品（ドロップ先の判定とログ）。
  TCListView / TCTreeView から使う。

  第2段階で、ドラッグの受け渡しはすべて OLE に統一した。
    - 送り側 … CShellOleDrag.pas（シェルのデータで OLE のドラッグを開始）
    - 受け側 … CShellOleDrop.pas（シェルのドロップ先へ処理を転送）
  このユニットは、次の2つだけを受け持つ。
    1. アプリ内から始めたドラッグの情報（ドラッグ中の項目のパス）の保持
    2. 禁止判定（自分自身・配下へのドロップ、同じフォルダーへの移動）… 強調表示の可否に使う
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Windows, Controls;

type
  TCDropEffect = (cdeNone, cdeCopy, cdeMove);

// --- 動作ログ（不具合調査用） ---
var
  // True にすると、D&D の動作を %TEMP%\cshell_dd.log に追記する（既定 False）
  ShellDragTrace: Boolean = False;
procedure ShellDragLog(const AMsg: string);

// --- アプリ内から始めたドラッグの情報 ---
// ドラッグ開始時に、ドラッグ元コントロールとドラッグする項目のパスを登録する
procedure ShellDragBegin(ASource: TControl; APaths: TStrings);
// ドラッグ終了時に呼ぶ
procedure ShellDragEnd;
// ドラッグ元のコントロールが破棄されるときに呼ぶ
procedure ShellDragAbandon(ASource: TControl);
// アプリ内から始めたドラッグが進行中か
function ShellDragIsActive: Boolean;
// ドラッグ中の項目のパス（ShellDragIsActive のときのみ有効）
function ShellDragPaths: TStrings;

// --- ドロップ先の判定 ---
// 現在押されている修飾キー（Ctrl / Shift）
function ShellDragKeyState: TShiftState;
// ドラッグ中の項目を ATargetFolder（フォルダーまたは ZIP）へドロップしたときの動作を決める。
// エクスプローラーと同じ：Ctrl でコピー、Shift で移動、どちらもなければ同じドライブなら移動・別ドライブならコピー。
// 禁止（cdeNone）：ドライブ自体、自分自身・自分の配下へ、同じフォルダーへの移動
function ShellDecideDropEffect(APaths: TStrings; const ATargetFolder: string;
  AShift: TShiftState): TCDropEffect;

implementation

var
  GDragSource: TControl = nil;
  GDragPaths: TStringList = nil;

procedure ShellDragLog(const AMsg: string);
var
  F: TextFile;
  FileName: string;
begin
  if not ShellDragTrace then Exit;
  try
    FileName := IncludeTrailingPathDelimiter(GetTempDir) + 'cshell_dd.log';
    AssignFile(F, FileName);
    if FileExists(FileName) then
      Append(F)
    else
      Rewrite(F);
    try
      WriteLn(F, FormatDateTime('hh:nn:ss.zzz', Now) + ' ' + AMsg);
    finally
      CloseFile(F);
    end;
  except
    // ログ出力の失敗で動作を止めない
  end;
end;

function NormPath(const P: string): string;
begin
  Result := ExcludeTrailingPathDelimiter(P);
end;

function IsDriveRoot(const P: string): Boolean;
var
  X: string;
begin
  X := NormPath(P);
  Result := (X <> '') and SameText(X, ExtractFileDrive(P));
end;

// ---------------------------------------------------------------
// アプリ内から始めたドラッグの情報
// ---------------------------------------------------------------

procedure ShellDragBegin(ASource: TControl; APaths: TStrings);
begin
  ShellDragEnd;
  if (ASource = nil) or (APaths = nil) or (APaths.Count = 0) then Exit;
  if GDragPaths = nil then
    GDragPaths := TStringList.Create;
  GDragPaths.Assign(APaths);
  GDragSource := ASource;
  ShellDragLog('Begin: source=' + ASource.ClassName + ' count=' + IntToStr(APaths.Count) +
    ' first=' + APaths[0]);
end;

procedure ShellDragEnd;
begin
  if GDragSource <> nil then
    ShellDragLog('End');
  GDragSource := nil;
  if GDragPaths <> nil then
    GDragPaths.Clear;
end;

procedure ShellDragAbandon(ASource: TControl);
begin
  if (ASource <> nil) and (GDragSource = ASource) then
    ShellDragEnd;
end;

function ShellDragIsActive: Boolean;
begin
  Result := (GDragSource <> nil) and (GDragPaths <> nil) and (GDragPaths.Count > 0);
end;

function ShellDragPaths: TStrings;
begin
  Result := GDragPaths;
end;

// ---------------------------------------------------------------
// ドロップ先の判定
// ---------------------------------------------------------------

function ShellDragKeyState: TShiftState;
begin
  Result := [];
  if GetKeyState(VK_CONTROL) < 0 then Include(Result, ssCtrl);
  if GetKeyState(VK_SHIFT) < 0 then Include(Result, ssShift);
end;

function ShellDecideDropEffect(APaths: TStrings; const ATargetFolder: string;
  AShift: TShiftState): TCDropEffect;
var
  Target, Src, SrcParent: string;
  i: Integer;
  AllSameFolder, IsZip: Boolean;
begin
  Result := cdeNone;
  if (APaths = nil) or (APaths.Count = 0) then Exit;
  Target := NormPath(ATargetFolder);
  if Target = '' then Exit;

  // ドロップ先はフォルダー、または ZIP ファイル（ZIP への追加）
  IsZip := (not DirectoryExists(ATargetFolder)) and SameText(ExtractFileExt(Target), '.zip') and
           FileExists(Target);
  if not IsZip and not DirectoryExists(ATargetFolder) then Exit;

  // 1. 修飾キーとドライブで、コピーか移動かを決める
  if ssCtrl in AShift then
    Result := cdeCopy
  else if ssShift in AShift then
    Result := cdeMove
  else if SameText(ExtractFileDrive(APaths[0]), ExtractFileDrive(ATargetFolder)) then
    Result := cdeMove
  else
    Result := cdeCopy;

  // 2. 禁止判定
  AllSameFolder := True;
  for i := 0 to APaths.Count - 1 do
  begin
    Src := NormPath(APaths[i]);
    // ドライブ自体は動かせない
    if IsDriveRoot(APaths[i]) then Exit(cdeNone);
    // 自分自身の上（ZIP を自分自身へ、を含む）
    if SameText(Src, Target) then Exit(cdeNone);
    // 自分の配下へ
    if SameText(Copy(Target, 1, Length(Src) + 1), Src + PathDelim) then Exit(cdeNone);

    SrcParent := NormPath(ExtractFileDir(Src));
    if not SameText(SrcParent, Target) then
      AllSameFolder := False;
  end;

  // 同じフォルダーへの移動は何も起きないので禁止（コピーは「〜 - コピー」になるので可）
  if (not IsZip) and AllSameFolder and (Result = cdeMove) then
    Result := cdeNone;
end;

finalization
  FreeAndNil(GDragPaths);

end.
