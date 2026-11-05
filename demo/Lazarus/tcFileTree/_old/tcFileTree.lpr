{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ tcFileTree - TCFileTree の動作を確かめるアプリ（テスト仕様: docs\test_docs\TCFileTree_Test.md）
  環境: Lazarus 4.8 / FPC 3.2.2 / Windows 11 x64

  引数なし：画面を出す（手で確かめる）
    左 … TCFileTree（RootPath は EXE の隣の data）
    右 … TCMonacoEditor（TargetEditor）・TCMonacoEditor（SideEditor）・TCTabBrowser（TargetBrowser）
    下 … 記録（TMemo）
  引数 /auto：自動で確かめて、EXE の隣の tcFileTree_auto.log に書いて終わる（終了コード＝FAIL の数）
    ・並び順、根より上が無いこと、隠しファイル、外からの作成・削除・名前の変更が表示に出ること
    ・NewFolder の作る先
    ・Windows のメニュー（IContextMenu）の「新規作成」「送る」が、フォルダー・ファイルで出るか、
      「新規作成」でフォルダーを作ると、選んだフォルダーの中にできるか（親にできないか）
  起動するたびに、EXE の隣の data を作り直す。EXE の隣に WebView2.ini が要る（TCMonacoEditor）。 }
program tcFileTreeApp;   // プログラム名を tcFileTree にすると、クラス名 TCFileTree と同じ識別子になってしまう

{$mode objfpc}{$H+}

uses
  Interfaces, Classes, Forms, Controls, ComCtrls, ExtCtrls, StdCtrls, SysUtils, FileUtil,
  Windows, ShlObj, ActiveX,
  uCmonacos, uCTabBrowser, uCXLang, CFileTree, CShellMenu;

type
  { IContextMenu2（独自宣言。「送る」「新規作成」の中身をシェルに作らせるため） }
  ITestCM2 = interface(IContextMenu)
    ['{000214F4-0000-0000-C000-000000000046}']
    function HandleMenuMsg(uMsg: UINT; WParam: WPARAM; LParam: LPARAM): HResult; stdcall;
  end;

  { IShellExtInit（独自宣言。標準の「新規作成」ハンドラーに、作る先のフォルダーを教えるため） }
  IShellExtInitX = interface(IUnknown)
    ['{000214E8-0000-0000-C000-000000000046}']
    function Initialize(pidlFolder: PItemIDList; pdtobj: Pointer; hkeyProgID: HKEY): HResult; stdcall;
  end;

  { 自動テストを進める }
  TRunner = class
    Step: Integer;
    Wait: Integer;
    MState: Integer;
    procedure Tick(Sender: TObject);
    procedure MTick(Sender: TObject);
  end;

var
  ExeDir, DataDir, LogFile: string;
  AutoMode: Boolean;
  Tree: TCFileTree;
  F: TForm;
  LogMemo: TMemo;
  Runner: TRunner;
  Timer, MTimer: TTimer;
  Fails: Integer;
  LogLines: TStringList;
  GDataBefore, GDir1Before: string;   // 手順をまたいで覚える（Tick の局所変数は、呼ぶたびに空になる）

procedure Log(const S: string);
begin
  LogLines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + S);
  if LogMemo <> nil then LogMemo.Lines.Add(S);
  if AutoMode then LogLines.SaveToFile(LogFile);   // 途中で止まっても、そこまでが残るように
end;

procedure Check(const AName: string; AOk: Boolean; const ADetail: string = '');
begin
  if AOk then
    Log('PASS  ' + AName + '  ' + ADetail)
  else
  begin
    Inc(Fails);
    Log('FAIL  ' + AName + '  ' + ADetail);
  end;
end;

procedure MakeFile(const AFileName, AText: string);
var
  T: TextFile;
begin
  AssignFile(T, AFileName);
  Rewrite(T);
  WriteLn(T, AText);
  CloseFile(T);
end;

{ テスト用のフォルダーを、毎回同じ中身で作り直す }
procedure MakeTestData;
var
  FS: TFileStream;
  B: array[0..15] of Byte;
begin
  if DirectoryExists(DataDir) then DeleteDirectory(DataDir, False, True);
  ForceDirectories(DataDir + 'dir1');
  ForceDirectories(DataDir + 'dir2');
  ForceDirectories(DataDir + 'dir10');
  MakeFile(DataDir + 'dir1\inner.txt', 'inner');
  MakeFile(DataDir + 'a.txt', 'a');
  MakeFile(DataDir + 'b.txt', 'b');
  MakeFile(DataDir + '日本語.txt', 'nihongo');
  MakeFile(DataDir + 'sample.url', '[InternetShortcut]' + LineEnding + 'URL=https://example.com/');
  MakeFile(DataDir + 'hidden.txt', 'hidden');
  SetFileAttributesW(PWideChar(UnicodeString(DataDir + 'hidden.txt')), FILE_ATTRIBUTE_HIDDEN);
  FillChar(B, SizeOf(B), 0);
  B[0] := Ord('A');
  FS := TFileStream.Create(DataDir + 'bin.dat', fmCreate);
  try
    FS.Write(B[0], SizeOf(B));
  finally
    FS.Free;
  end;
end;

{ 根の直下の子の名前を、並びのまま集める }
function RootChildren: string;
var
  R, C: TTreeNode;
begin
  Result := '';
  R := Tree.Items.GetFirstNode;
  if R = nil then Exit;
  C := R.GetFirstChild;
  while C <> nil do
  begin
    if Result <> '' then Result := Result + ',';
    Result := Result + C.Text;
    C := C.GetNextSibling;
  end;
end;

{ 根（data）からの相対パスのノードを、読み込み済みの中から探す }
function FindNode(const ARelPath: string): TTreeNode;
var
  N, C: TTreeNode;
  Rest, Part: string;
  P: Integer;
begin
  Result := nil;
  N := Tree.Items.GetFirstNode;
  Rest := ARelPath;
  while (N <> nil) and (Rest <> '') do
  begin
    P := Pos('\', Rest);
    if P = 0 then begin Part := Rest; Rest := ''; end
    else begin Part := Copy(Rest, 1, P - 1); Rest := Copy(Rest, P + 1, MaxInt); end;
    C := N.GetFirstChild;
    while (C <> nil) and (CompareText(C.Text, Part) <> 0) do C := C.GetNextSibling;
    N := C;
  end;
  Result := N;
end;

procedure Pump(AMs: Integer);
var
  T: QWord;
begin
  T := GetTickCount64;
  while GetTickCount64 - T < QWord(AMs) do
  begin
    Application.ProcessMessages;
    Sleep(10);
  end;
end;

{ ノードが現れるまで最大 AMaxMs 待つ。現れるまでの ms（現れなければ -1）。通知が届くまでの遅れを測る }
function WaitForNode(const ARelPath: string; AMaxMs: Integer): Integer;
var
  T: QWord;
begin
  T := GetTickCount64;
  while GetTickCount64 - T < QWord(AMaxMs) do
  begin
    if FindNode(ARelPath) <> nil then Exit(Integer(GetTickCount64 - T));
    Application.ProcessMessages;
    Sleep(20);
  end;
  Result := -1;
end;

{ ---------- Windows のメニュー（IContextMenu）の確認 ---------- }

function MenuText(HM: HMENU; Idx: Integer; out ASub: HMENU; out AId: UINT): string;
var
  MI: MENUITEMINFOW;
  Buf: array[0..255] of WideChar;
begin
  Result := '';
  ASub := 0;
  AId := 0;
  FillChar(MI, SizeOf(MI), 0);
  FillChar(Buf, SizeOf(Buf), 0);
  MI.cbSize := SizeOf(MI);
  MI.fMask := MIIM_STRING or MIIM_SUBMENU or MIIM_ID or MIIM_FTYPE;
  MI.dwTypeData := @Buf[0];
  MI.cch := Length(Buf) - 1;
  if GetMenuItemInfoW(HM, Idx, True, @MI) then
  begin
    Result := UTF8Encode(UnicodeString(PWideChar(@Buf[0])));
    ASub := MI.hSubMenu;
    AId := MI.wID;
  end;
end;

function GetPIDL(const APath: string): PItemIDList;
var
  Desk: IShellFolder;
  Eaten, Attr: ULONG;
  W: WideString;
begin
  Result := nil;
  Attr := 0;
  if Succeeded(SHGetDesktopFolder(Desk)) then
  begin
    W := WideString(APath);
    Desk.ParseDisplayName(0, nil, PWideChar(W), Eaten, Result, Attr);
  end;
end;

{ APath の項目の IContextMenu を作り（部品の「windows メニュー」と同じ作り方）、メニューの上の階層と、
  「新規作成」「送る」の中身を記録する。
  ACreateInNew = True のとき、「新規作成」の中の「フォルダー」を実行する（作業フォルダーは AWorkDir） }
procedure ProbeMenu(const ALabel, APath, AWorkDir: string; ACreateInNew: Boolean;
  ABackground: Boolean = False);
var
  ParentPIDL, Full, Child: PItemIDList;
  Desk: IShellFolder;
  ParentFolder, SubFolder: IShellFolder;
  CM: IContextMenu;
  CM2: ITestCM2;
  HM, Sub, Sub2, NewSub: HMENU;
  I, J, N, NewFolderId: Integer;
  S, S2: string;
  Id, Id2: UINT;
  FoundNew, FoundSend: Boolean;
begin
  Log('--- ' + ALabel + ' : ' + APath);
  ParentPIDL := GetPIDL(ExtractFilePath(ExcludeTrailingPathDelimiter(APath)));
  Full := GetPIDL(APath);
  if (ParentPIDL = nil) or (Full = nil) then
  begin
    Check(ALabel + ' PIDL', False);
    Exit;
  end;
  try
    SHGetDesktopFolder(Desk);
    if Failed(Desk.BindToObject(ParentPIDL, nil, IID_IShellFolder, Pointer(ParentFolder))) then
    begin
      Check(ALabel + ' BindToObject', False);
      Exit;
    end;
    Child := ILFindLastID(Full);
    if ABackground then
    begin
      // フォルダー自身の「背景」のメニュー（エクスプローラーで、フォルダーの中の空白を右クリックしたときのメニュー）
      if Failed(ParentFolder.BindToObject(Child, nil, IID_IShellFolder, Pointer(SubFolder))) or
         Failed(SubFolder.CreateViewObject(F.Handle, IID_IContextMenu, Pointer(CM))) then
      begin
        Check(ALabel + ' CreateViewObject', False);
        Exit;
      end;
    end
    else if Failed(ParentFolder.GetUIObjectOf(0, 1, Child, IID_IContextMenu, nil, Pointer(CM))) then
    begin
      Check(ALabel + ' GetUIObjectOf', False);
      Exit;
    end;
    HM := CreatePopupMenu;
    try
      CM.QueryContextMenu(HM, 0, 1, $7FFF, CMF_NORMAL);
      CM.QueryInterface(ITestCM2, CM2);
      FoundNew := False;
      FoundSend := False;
      NewSub := 0;
      N := GetMenuItemCount(HM);
      S2 := '';
      for I := 0 to N - 1 do
      begin
        S := MenuText(HM, I, Sub, Id);
        if S = '' then Continue;
        S2 := S2 + '[' + S + ']';
        if Sub <> 0 then
        begin
          // サブメニューの中身は、開くときにシェルが作る（IContextMenu2）
          if CM2 <> nil then CM2.HandleMenuMsg(WM_INITMENUPOPUP, WPARAM(Sub), LPARAM(I and $FFFF));
          if (Pos('送る', S) > 0) or (Pos('Send to', S) > 0) then
          begin
            FoundSend := True;
            Log('  送る のサブメニュー項目数 = ' + IntToStr(GetMenuItemCount(Sub)));
          end;
          if (Pos('新規作成', S) > 0) or (Pos('New', S) = 1) then
          begin
            FoundNew := True;
            NewSub := Sub;
            Log('  新規作成 のサブメニュー項目数 = ' + IntToStr(GetMenuItemCount(Sub)));
            for J := 0 to GetMenuItemCount(Sub) - 1 do
            begin
              S := MenuText(Sub, J, Sub2, Id2);
              Log('    新規作成/' + IntToStr(J) + ' id=' + IntToStr(Id2) + ' [' + S + ']');
            end;
          end;
        end;
      end;
      Log('  上の階層: ' + S2);
      Log('  送る=' + BoolToStr(FoundSend, True) + '  新規作成=' + BoolToStr(FoundNew, True));
      if ACreateInNew and (NewSub <> 0) then
      begin
        // 「新規作成」の中の、フォルダーの項目を実行する
        NewFolderId := -1;
        for J := 0 to GetMenuItemCount(NewSub) - 1 do
        begin
          S := MenuText(NewSub, J, Sub2, Id2);
          if (Pos('フォルダ', S) > 0) or (Pos('older', S) > 0) then
          begin
            NewFolderId := Integer(Id2);
            Break;
          end;
        end;
        if NewFolderId >= 0 then
        begin
          Log('  「新規作成/フォルダー」を実行する  id=' + IntToStr(NewFolderId) + '  作業フォルダー=' + AWorkDir);
          Log('  ShellInvokeMenuCommand = ' +
            BoolToStr(ShellInvokeMenuCommand(CM, F.Handle, UINT(NewFolderId) - 1, AWorkDir), True));
        end
        else
          Log('  「新規作成」の中に、フォルダーの項目が見つからない');
      end;
    finally
      DestroyMenu(HM);
    end;
  finally
    CoTaskMemFree(Full);
    CoTaskMemFree(ParentPIDL);
  end;
end;

{ 標準の「新規作成」ハンドラー（CNewMenu）を、フォルダーを指定して作り、その中の「フォルダー」を実行する。
  項目メニューに「新規作成」を差し込む方法が使えるかを確かめる }
procedure ProbeNewMenu(const AFolder: string);
const
  CLSID_NewMenu: TGUID = '{D969A300-E7FF-11D0-A93B-00A0C90F2719}';
  IID_ShellExtInit: TGUID = '{000214E8-0000-0000-C000-000000000046}';
  FirstId = $8200;
  LastId = $BFFF;
var
  Unk: IUnknown;
  CM: IContextMenu;
  CM2: ITestCM2;
  Init: IShellExtInitX;
  PIDL: PItemIDList;
  HM, Sub, Sub2: HMENU;
  I, J: Integer;
  S: string;
  Id, Id2: UINT;
  FolderId: Integer;
  R: HResult;
begin
  Log('--- CNewMenu を直接作る : ' + AFolder);
  PIDL := GetPIDL(AFolder);
  if PIDL = nil then begin Check('N PIDL', False); Exit; end;
  try
    R := CoCreateInstance(CLSID_NewMenu, nil, CLSCTX_INPROC_SERVER, IUnknown, Unk);
    Log('  CoCreateInstance = $' + IntToHex(R, 8));
    if Failed(R) then begin Check('N CNewMenu を作れる', False); Exit; end;
    if Failed(Unk.QueryInterface(IContextMenu, CM)) then begin Check('N IContextMenu', False); Exit; end;
    if Succeeded(Unk.QueryInterface(IShellExtInitX, Init)) then
      Log('  Initialize = $' + IntToHex(Init.Initialize(PIDL, nil, 0), 8))
    else
      Log('  IShellExtInit が無い');
    CM.QueryInterface(ITestCM2, CM2);
    HM := CreatePopupMenu;
    try
      Log('  QueryContextMenu = ' + IntToStr(CM.QueryContextMenu(HM, 0, FirstId, LastId, CMF_NORMAL)));
      FolderId := -1;
      for I := 0 to GetMenuItemCount(HM) - 1 do
      begin
        S := MenuText(HM, I, Sub, Id);
        Log('  上の階層 ' + IntToStr(I) + ' id=' + IntToStr(Id) + ' [' + S + '] sub=' + BoolToStr(Sub <> 0, True));
        if Sub <> 0 then
        begin
          if CM2 <> nil then CM2.HandleMenuMsg(WM_INITMENUPOPUP, WPARAM(Sub), LPARAM(I and $FFFF));
          for J := 0 to GetMenuItemCount(Sub) - 1 do
          begin
            S := MenuText(Sub, J, Sub2, Id2);
            Log('    ' + IntToStr(J) + ' id=' + IntToStr(Id2) + ' [' + S + ']');
            if (FolderId < 0) and ((Pos('フォルダ', S) > 0) or (Pos('older', S) > 0)) then FolderId := Integer(Id2);
          end;
        end;
      end;
      if FolderId >= 0 then
      begin
        Log('  「フォルダー」を実行する id=' + IntToStr(FolderId) + ' 相対=' + IntToStr(FolderId - FirstId));
        Log('  ShellInvokeMenuCommand = ' +
          BoolToStr(ShellInvokeMenuCommand(CM, F.Handle, UINT(FolderId - FirstId), AFolder), True));
      end
      else
        Log('  「フォルダー」の項目が見つからない');
    finally
      DestroyMenu(HM);
    end;
  finally
    CoTaskMemFree(PIDL);
  end;
end;

{ ADir の中の、APrefix で始まるフォルダー名をコンマでつなぐ }
function FolderLike(const ADir, APrefix: string): string;
var
  SR: TSearchRec;
begin
  Result := '';
  if SysUtils.FindFirst(ADir + '*', faDirectory, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) <> 0) and
         ((APrefix = '') or (Pos(APrefix, SR.Name) = 1)) then
      begin
        if Result <> '' then Result := Result + ',';
        Result := Result + SR.Name;
      end;
    until SysUtils.FindNext(SR) <> 0;
    SysUtils.FindClose(SR);
  end;
end;

{ ---------- 自動テスト ---------- }

{ 開いているメニュー（#32768）にキーを送って、部品の windows メニューを動かす。メニューは、開いている間
  メッセージを自分で回すので、このタイマーは動き続ける }
procedure TRunner.MTick(Sender: TObject);
var
  W: HWND;

  procedure Key(AVK: Word; const ADesc: string);
  begin
    W := FindWindow('#32768', nil);
    Log('  メニュー操作 ' + IntToStr(MState) + ': ' + ADesc + '  メニューの窓=' + BoolToStr(W <> 0, True));
    if W <> 0 then
    begin
      PostMessage(W, WM_KEYDOWN, AVK, 0);
      PostMessage(W, WM_KEYUP, AVK, LPARAM($C0000001));
    end;
  end;

begin
  Inc(MState);
  case MState of
    1: Key(VK_UP, '↑（最後の項目＝windowsメニューを選ぶ）');
    2: Key(VK_RETURN, 'Enter（windowsメニューを開く）');
    3: Key(VK_UP, '↑（最後の項目＝プロパティ）');
    4: Key(VK_UP, '↑（新規作成。区切り線は飛ばされる）');
    5: Key(VK_RIGHT, '→（サブメニューを開く）');
    6: Key(VK_RETURN, 'Enter（先頭＝フォルダー）');
  else
    MTimer.Enabled := False;
  end;
end;

procedure TRunner.Tick(Sender: TObject);
var
  N: TTreeNode;
  S, NewName, DataBefore: string;
  T1: Integer;
begin
  if Wait > 0 then
  begin
    Dec(Wait);
    Exit;
  end;
  Timer.Enabled := False;
  case Step of
    0:
      begin
        // 並び順：フォルダー → ファイルの順で、それぞれ自然順（dir1, dir2, dir10）
        S := RootChildren;
        Check('1 並び順', S = 'dir1,dir2,dir10,a.txt,b.txt,bin.dat,sample.url,日本語.txt', S);
        Check('2 根は1つだけ（根より上が無い）', Tree.Items.TopLvlCount = 1,
          'TopLvlCount=' + IntToStr(Tree.Items.TopLvlCount));
        Check('3 根の名前', Tree.Items.GetFirstNode.Text = 'data', Tree.Items.GetFirstNode.Text);
        Check('4 隠しファイルは出ない', Pos('hidden.txt', S) = 0);
      end;
    1:
      begin
        Tree.ShowHidden := True;
        S := RootChildren;
        Check('5 ShowHidden=True で hidden.txt が出る', Pos('hidden.txt', S) > 0, S);
        Tree.ShowHidden := False;
        S := RootChildren;
        Check('6 ShowHidden=False で hidden.txt が消える', Pos('hidden.txt', S) = 0, S);
      end;
    2:
      begin
        // 外からの作成：dir1 を開いておき、根と dir1 の中にファイルを作る
        N := FindNode('dir1');
        if N <> nil then N.Expand(False);
        MakeFile(DataDir + 'new1.txt', 'x');
        MakeFile(DataDir + 'dir1\new2.txt', 'y');
        ForceDirectories(DataDir + 'dir1\subA');
        Wait := 0;
      end;
    3:
      begin
        // 通知が届くまでの遅れを測る（最大 8 秒）
        T1 := WaitForNode('new1.txt', 8000);
        Check('7 外から作った根のファイルが出る（CREATE）', T1 >= 0, 'ms=' + IntToStr(T1));
        T1 := WaitForNode('dir1\new2.txt', 8000);
        Check('8 外から作った dir1 の中のファイルが出る（CREATE・1つ下の階層）', T1 >= 0, 'ms=' + IntToStr(T1));
        T1 := WaitForNode('dir1\subA', 8000);
        Check('8c 外から作った dir1 の中のフォルダーが出る（MKDIR・1つ下の階層）', T1 >= 0, 'ms=' + IntToStr(T1));
        if FindNode('dir1\new2.txt') = nil then
        begin
          // 切り分け：通知が届かないのか、読み直しの処理が間違っているのか
          Tree.RefreshTree;
          Pump(300);
          Check('8b RefreshTree（F5）の後なら、dir1 の中のファイルが出る', FindNode('dir1\new2.txt') <> nil);
        end;
        SysUtils.DeleteFile(DataDir + 'new1.txt');
        Wait := 8;
      end;
    4:
      begin
        Check('9 外から消したファイルが消える（DELETE）', Pos('new1.txt', RootChildren) = 0, RootChildren);
        if Pos('new1.txt', RootChildren) > 0 then
        begin
          Tree.RefreshTree;
          Pump(300);
          Check('9b RefreshTree（F5）の後なら、消える', Pos('new1.txt', RootChildren) = 0, RootChildren);
        end;
        RenameFile(DataDir + 'a.txt', DataDir + 'c.txt');
        Wait := 8;
      end;
    5:
      begin
        S := RootChildren;
        Check('10 名前の変更が出て、並びも合う', (Pos('a.txt', S) = 0) and (Pos('b.txt,bin.dat,c.txt', S) > 0), S);
        if Pos('c.txt', S) = 0 then
        begin
          Tree.RefreshTree;
          Pump(300);
          S := RootChildren;
          Check('10b RefreshTree（F5）の後なら、名前の変更が出て並びも合う',
            (Pos('a.txt', S) = 0) and (Pos('b.txt,bin.dat,c.txt', S) > 0), S);
        end;
        N := FindNode('dir1');
        Check('11 更新しても、開いていた dir1 は開いたまま', (N <> nil) and N.Expanded);
      end;
    6:
      begin
        // NewFolder：dir2 を選んで作る → dir2 の中にできる
        N := FindNode('dir2');
        Tree.ClearSelection;
        Tree.Selected := N;
        DataBefore := FolderLike(DataDir, '');
        Tree.NewFolder;
        NewName := CXT(sBmNewFolder);
        S := FolderLike(DataDir + 'dir2\', NewName);
        Check('12 NewFolder は、選んだフォルダー（dir2）の中に作る', S <> '', 'dir2 の中: ' + S);
        Check('13 NewFolder は、親（data）には作らない', FolderLike(DataDir, '') = DataBefore,
          'data の中: ' + FolderLike(DataDir, ''));
        Check('14 作ったフォルダーのノードが出る', FindNode('dir2\' + NewName) <> nil);
        Pump(500);
        Tree.Selected := Tree.Items.GetFirstNode;   // 名前の編集を終える
      end;
    7:
      begin
        // Windows のメニュー：フォルダーと、ファイル
        ProbeMenu('フォルダー(dir1)', DataDir + 'dir1', DataDir + 'dir1', False);
        ProbeMenu('ファイル(b.txt)', DataDir + 'b.txt', DataDir, False);
        // 項目のメニューに「新規作成」が無かったので、フォルダー自身の背景メニューを調べる
        ProbeMenu('背景メニュー(dir10)', DataDir + 'dir10', DataDir + 'dir10', False, True);
      end;
    8:
      begin
        // 背景メニューの「新規作成」→「フォルダー」を実行する（作業フォルダー＝dir10）
        DataBefore := FolderLike(DataDir, '');
        Log('  実行前  data: ' + DataBefore + '   dir10: [' + FolderLike(DataDir + 'dir10\', '') + ']');
        ProbeMenu('背景メニューの新規作成を実行(dir10)', DataDir + 'dir10', DataDir + 'dir10', True, True);
        T1 := 0;
        while (FolderLike(DataDir + 'dir10\', '') = '') and (T1 < 50) do   // 最大5秒待つ（作るのが遅れることがある）
        begin
          Pump(100);
          Inc(T1);
        end;
        Log('  フォルダーができるまで ' + IntToStr(T1 * 100) + ' ms');
        Log('  実行後  data: ' + FolderLike(DataDir, '') + '   dir10: [' + FolderLike(DataDir + 'dir10\', '') + ']');
        Check('15 背景メニューの「新規作成」のフォルダーは、そのフォルダー（dir10）の中にできる',
          FolderLike(DataDir + 'dir10\', '') <> '', 'dir10 の中: [' + FolderLike(DataDir + 'dir10\', '') + ']');
        Check('16 背景メニューの「新規作成」のフォルダーが、親（data）にできていない',
          FolderLike(DataDir, '') = DataBefore, 'data の中: ' + FolderLike(DataDir, ''));
      end;
    9:
      begin
        // CNewMenu を直接作る方法（項目メニューに「新規作成」を差し込むために使えるか）
        DataBefore := FolderLike(DataDir, '');
        Log('  実行前  data: ' + DataBefore + '   dir2: [' + FolderLike(DataDir + 'dir2\', '') + ']');
        ProbeNewMenu(ExcludeTrailingPathDelimiter(DataDir) + '\dir2');
        T1 := 0;
        while (Pos(',', FolderLike(DataDir + 'dir2\', '')) = 0) and (T1 < 50) do   // dir2 には既に New Folder がある → 2つになるまで
        begin
          Pump(100);
          Inc(T1);
        end;
        Log('  実行後  data: ' + FolderLike(DataDir, '') + '   dir2: [' + FolderLike(DataDir + 'dir2\', '') + ']');
        Check('17 CNewMenu の「フォルダー」は、指定したフォルダー（dir2）の中にできる',
          Pos(',', FolderLike(DataDir + 'dir2\', '')) > 0, 'dir2 の中: [' + FolderLike(DataDir + 'dir2\', '') + ']');
        Check('18 CNewMenu のフォルダーが、親（data）にできていない',
          FolderLike(DataDir, '') = DataBefore, 'data の中: ' + FolderLike(DataDir, ''));
      end;
    10:
      begin
        // 部品の本物の右クリックメニュー → windowsメニュー → 新規作成 → フォルダー を、キー操作で動かす（dir1 を選ぶ）
        N := FindNode('dir1');
        Tree.ClearSelection;
        Tree.Selected := N;
        GDataBefore := FolderLike(DataDir, '');
        GDir1Before := FolderLike(DataDir + 'dir1\', '');
        Log('  実行前  data: ' + GDataBefore + '   dir1: [' + GDir1Before + ']');
        SetForegroundWindow(F.Handle);
        Tree.SetFocus;
        MState := 0;
        MTimer.Enabled := True;
        // キーボードのメニュー（lParam = -1）：選んでいるノードの位置に出る。メニューが閉じるまで戻らないので Post する
        PostMessage(Tree.Handle, WM_CONTEXTMENU, WPARAM(Tree.Handle), LPARAM(-1));
        Wait := 30;   // 約6秒
      end;
    11:
      begin
        Log('  実行後  data: ' + FolderLike(DataDir, '') + '   dir1: [' + FolderLike(DataDir + 'dir1\', '') + ']');
        Check('19 部品の windowsメニューの「新規作成」→「フォルダー」で、選んだフォルダー（dir1）の中にできる',
          (FolderLike(DataDir + 'dir1\', '') <> GDir1Before) and (Pos('新しいフォルダー', FolderLike(DataDir + 'dir1\', '')) > 0),
          'dir1 の中: [' + FolderLike(DataDir + 'dir1\', '') + ']  （前: [' + GDir1Before + ']）');
        Check('20 そのとき、親（data）にはできていない', FolderLike(DataDir, '') = GDataBefore,
          'data の中: ' + FolderLike(DataDir, ''));
      end;
  else
    begin
      Log('終了  FAIL=' + IntToStr(Fails));
      LogLines.SaveToFile(LogFile);
      Halt(Fails);
    end;
  end;
  Inc(Step);
  Timer.Enabled := True;
end;

var
  Ed1, Ed2: TCMonacoEditor;
  Br: TCTabBrowser;

begin
  AutoMode := SameText(ParamStr(1), '/auto');
  ExeDir := ExtractFilePath(ParamStr(0));
  DataDir := ExeDir + 'data\';
  LogFile := ExeDir + 'tcFileTree_auto.log';
  LogLines := TStringList.Create;
  MakeTestData;
  Log('data ok');

  Application.Scaled := True;
  Application.Initialize;

  Application.CreateForm(TForm, F);
  F.Caption := 'tcFileTree';
  F.SetBounds(60, 60, 1200, 800);

  if not AutoMode then
  begin
    LogMemo := TMemo.Create(F);
    LogMemo.Parent := F;
    LogMemo.Align := alBottom;
    LogMemo.Height := 150;
    LogMemo.ScrollBars := ssVertical;
    LogMemo.ReadOnly := True;
  end;

  Tree := TCFileTree.Create(F);
  Tree.Parent := F;
  Tree.Align := alLeft;
  Tree.Width := 360;
  Log('tree created');
  Tree.RootPath := ExcludeTrailingPathDelimiter(DataDir);
  Log('rootpath set');

  if not AutoMode then
  begin
    // 右：エディター 2 つ（上＝TargetEditor、下＝SideEditor）とブラウザー
    Ed1 := TCMonacoEditor.Create(F);
    Ed1.Parent := F;
    Ed1.Align := alTop;
    Ed1.Height := 240;
    Br := TCTabBrowser.Create(F);
    Br.Parent := F;
    Br.Align := alBottom;
    Br.Height := 220;
    Ed2 := TCMonacoEditor.Create(F);
    Ed2.Parent := F;
    Ed2.Align := alClient;
    Tree.TargetEditor := Ed1;
    Tree.SideEditor := Ed2;
    Tree.TargetBrowser := Br;
    Log('準備できました。左のツリーを操作してください（右クリック、ダブルクリック、ドラッグ）。');
  end;

  Log('before show');
  F.Show;
  Log('after show');

  if AutoMode then
  begin
    Runner := TRunner.Create;
    Timer := TTimer.Create(F);
    Timer.Interval := 200;
    Timer.OnTimer := @Runner.Tick;
    Timer.Enabled := True;
    MTimer := TTimer.Create(F);
    MTimer.Interval := 700;
    MTimer.OnTimer := @Runner.MTick;
    MTimer.Enabled := False;
  end;
  Application.Run;
end.
