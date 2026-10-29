{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
unit CShellNotify;

{
  シェルの変更通知（SHChangeNotifyRegister）の共通部品。
  TCListView / TCTreeView から使う。

  使い方：
    1. ShellNotifyRegisterPath / ShellNotifyRegisterSpecial で登録（戻り値の ID を保持）
    2. コントロールの WndProc で WM_CSHELLNOTIFY を受け取り、ShellNotifyDecode で内容を取り出す
    3. ShellNotifyDeregister で解除（DestroyWnd と破棄時）
}

{$mode objfpc}{$H+}
{$WARN 4055 OFF} // 順序型⇔ポインターの変換（Win32 API の引数のため意図的）

interface

uses
  Windows, SysUtils, ActiveX;

const
  // 通知を受け取るウィンドウメッセージ
  WM_CSHELLNOTIFY = WM_USER + $5A1;

  // 監視するイベント（SHCNE_*）
  CSHCNE_RENAMEITEM    = $00000001;
  CSHCNE_CREATE        = $00000002;
  CSHCNE_DELETE        = $00000004;
  CSHCNE_MKDIR         = $00000008;
  CSHCNE_RMDIR         = $00000010;
  CSHCNE_MEDIAINSERTED = $00000020;
  CSHCNE_MEDIAREMOVED  = $00000040;
  CSHCNE_DRIVEREMOVED  = $00000080;
  CSHCNE_DRIVEADD      = $00000100;
  CSHCNE_ATTRIBUTES    = $00000800;
  CSHCNE_UPDATEDIR     = $00001000;
  CSHCNE_UPDATEITEM    = $00002000;
  CSHCNE_RENAMEFOLDER  = $00020000;

  // ドライブの追加・取り外し系
  CSHCNE_DRIVEEVENTS = CSHCNE_MEDIAINSERTED or CSHCNE_MEDIAREMOVED or
                       CSHCNE_DRIVEREMOVED or CSHCNE_DRIVEADD;

  // 特殊フォルダー
  CCSIDL_DRIVES = $0011; // PC（全ドライブ）

// フォルダーのパスを指定して登録する。失敗時は 0。
function ShellNotifyRegisterPath(AWnd: HWND; const APath: string;
  ARecursive: Boolean; AEvents: LongInt): ULONG;
// 特殊フォルダー（CCSIDL_DRIVES 等）を指定して登録する。失敗時は 0。
function ShellNotifyRegisterSpecial(AWnd: HWND; ACSIDL: Integer;
  ARecursive: Boolean; AEvents: LongInt): ULONG;
// 登録を解除し、ID を 0 に戻す
procedure ShellNotifyDeregister(var AID: ULONG);
// WM_CSHELLNOTIFY の wParam/lParam から、イベントと対象パス（最大2つ）を取り出す。
// パスに変換できない項目（仮想フォルダー等）は空文字になる。
function ShellNotifyDecode(AWParam: WPARAM; ALParam: LPARAM;
  out AEvent: LongInt; out APath1, APath2: string): Boolean;

implementation

type
  TSHChangeNotifyEntry = record
    pidl: PItemIDList;
    fRecursive: BOOL;
  end;
  PSHChangeNotifyEntry = ^TSHChangeNotifyEntry;

  TPIDLPair = array[0..1] of PItemIDList;
  PPIDLPair = ^TPIDLPair;

const
  SHCNRF_InterruptLevel = $0001; // ファイルシステムレベルの変更（他アプリによる変更も含む）
  SHCNRF_ShellLevel     = $0002; // シェル経由の変更
  SHCNRF_NewDelivery    = $8000; // 共有メモリ経由で受け取る（Lock/Unlock で取り出す）

// FPC 側の宣言と型が食い違わないよう、ここで名前付きで独自に宣言する
function _SHChangeNotifyRegister(hwnd: HWND; fSources: Integer; fEvents: LongInt;
  wMsg: UINT; cEntries: Integer; pshcne: PSHChangeNotifyEntry): ULONG; stdcall;
  external 'shell32.dll' name 'SHChangeNotifyRegister';
function _SHChangeNotifyDeregister(ulID: ULONG): BOOL; stdcall;
  external 'shell32.dll' name 'SHChangeNotifyDeregister';
function _SHChangeNotification_Lock(hChange: THandle; dwProcId: DWORD;
  out pppidl: PPIDLPair; out plEvent: LongInt): THandle; stdcall;
  external 'shell32.dll' name 'SHChangeNotification_Lock';
function _SHChangeNotification_Unlock(hLock: THandle): BOOL; stdcall;
  external 'shell32.dll' name 'SHChangeNotification_Unlock';
function _ILCreateFromPathW(pszPath: PWideChar): PItemIDList; stdcall;
  external 'shell32.dll' name 'ILCreateFromPathW';
function _SHGetPathFromIDListW(pidl: PItemIDList; pszPath: PWideChar): BOOL; stdcall;
  external 'shell32.dll' name 'SHGetPathFromIDListW';
function _SHGetPathFromIDListEx(pidl: PItemIDList; pszPath: PWideChar; cchPath: DWORD;
  uOpts: DWORD): BOOL; stdcall;
  external 'shell32.dll' name 'SHGetPathFromIDListEx';
function _SHGetSpecialFolderLocation(hwndOwner: HWND; nFolder: Integer;
  out ppidl: PItemIDList): HRESULT; stdcall;
  external 'shell32.dll' name 'SHGetSpecialFolderLocation';

function RegisterPIDL(AWnd: HWND; APIDL: PItemIDList; ARecursive: Boolean;
  AEvents: LongInt): ULONG;
var
  Entry: TSHChangeNotifyEntry;
begin
  Result := 0;
  if (AWnd = 0) or (APIDL = nil) then Exit;
  Entry.pidl := APIDL;
  Entry.fRecursive := ARecursive;
  // 登録数は必ず1件にする（複数件を1回で登録すると解除が正しく動かないため）
  Result := _SHChangeNotifyRegister(AWnd,
    SHCNRF_InterruptLevel or SHCNRF_ShellLevel or SHCNRF_NewDelivery,
    AEvents, WM_CSHELLNOTIFY, 1, @Entry);
end;

function ShellNotifyRegisterPath(AWnd: HWND; const APath: string;
  ARecursive: Boolean; AEvents: LongInt): ULONG;
var
  WPath: UnicodeString;
  PIDL: PItemIDList;
begin
  Result := 0;
  if APath = '' then Exit;
  WPath := UnicodeString(APath);
  PIDL := _ILCreateFromPathW(PWideChar(WPath));
  if PIDL = nil then Exit;
  try
    // 登録時に PIDL は複製されるため、登録後に解放してよい
    Result := RegisterPIDL(AWnd, PIDL, ARecursive, AEvents);
  finally
    CoTaskMemFree(PIDL);
  end;
end;

function ShellNotifyRegisterSpecial(AWnd: HWND; ACSIDL: Integer;
  ARecursive: Boolean; AEvents: LongInt): ULONG;
var
  PIDL: PItemIDList;
begin
  Result := 0;
  PIDL := nil;
  if Failed(_SHGetSpecialFolderLocation(AWnd, ACSIDL, PIDL)) or (PIDL = nil) then Exit;
  try
    Result := RegisterPIDL(AWnd, PIDL, ARecursive, AEvents);
  finally
    CoTaskMemFree(PIDL);
  end;
end;

procedure ShellNotifyDeregister(var AID: ULONG);
begin
  if AID <> 0 then
  begin
    _SHChangeNotifyDeregister(AID);
    AID := 0;
  end;
end;

function PIDLToPath(APIDL: PItemIDList): string;
const
  GPFIDL_DEFAULT = 0;
var
  Buf: UnicodeString;
begin
  Result := '';
  if APIDL = nil then Exit;
  // 260 文字を超えるパスにも対応するため、十分な長さのバッファで取得する
  Buf := '';
  SetLength(Buf, 32768);
  if _SHGetPathFromIDListEx(APIDL, PWideChar(Buf), Length(Buf), GPFIDL_DEFAULT) then
    Result := String(UnicodeString(PWideChar(Buf)));
end;

function ShellNotifyDecode(AWParam: WPARAM; ALParam: LPARAM;
  out AEvent: LongInt; out APath1, APath2: string): Boolean;
var
  Lock: THandle;
  PIDLs: PPIDLPair;
begin
  Result := False;
  AEvent := 0;
  APath1 := '';
  APath2 := '';
  PIDLs := nil;

  Lock := _SHChangeNotification_Lock(THandle(AWParam), DWORD(ALParam), PIDLs, AEvent);
  if Lock = 0 then Exit;
  try
    if PIDLs <> nil then
    begin
      APath1 := PIDLToPath(PIDLs^[0]);
      APath2 := PIDLToPath(PIDLs^[1]);
    end;
    Result := True;
  finally
    _SHChangeNotification_Unlock(Lock);
  end;
end;

end.
