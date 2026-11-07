{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
{ uCXLang - CX の部品が画面に出す文字列を、日本語と English で切り替える（CXLang_Design.md）
  環境: Lazarus 4.8 / FPC 3.2.2 / Windows 11 x64

  言語は cx 全体で 1 つ。最初に文字列が必要になったとき 1 回だけ、次の順で決める。
    ① EXE と同じ場所の WebView2.ini の [CX] セクションの Language（ja または en）
    ② それ以外（ini が無い・Language が無い・空・ja en 以外）は Windows の表示言語
       （日本語なら ja、それ以外は en）

    [CX]
    Language=en

  ・実行中に ini を書き換えても、次の起動まで効かない。
  ・ini を読めなくても例外は出さない（②へ進む）。
  ・WebView2 や LCL の部品は使わない（TCListView などが WebView4Delphi を巻き込まないため）。
  ・initialization・finalization は持たない（uses に入れただけで何も動かさない）。

  文字列は TCXStr を添字にした表 CXTable に持つ。並びは TCXStr と同じ（設計書 5 章の No の順）。
  日本語は今のソースの文字列そのまま。Format に渡す文字列は、日本語と English で % の並びを同じにしてある。 }
unit uCXLang;

{$mode objfpc}{$H+}

interface

uses
  Classes;

type
  { 言語。cx 全体で 1 つ }
  TCXLanguage = (cxlJa, cxlEn);

  { 文字列の ID（設計書 5 章の No の順） }
  TCXStr = (
    sUntitled, sUntitledTxt, sActNewCap, sActNewHint, sActOpenCap, sActOpenHint,
    sActSaveCap, sActSaveHint, sActSaveAsCap, sActSaveAsHint, sActCloseCap, sActCloseHint,
    sActPrintCap, sActPrintHint, sActSaveAllCap, sActSaveAllHint, sActCloseAllCap, sActCloseAllHint,
    sActUndoCap, sActUndoHint, sActRedoCap, sActRedoHint, sActCutCap, sActCutHint,
    sActCopyCap, sActCopyHint, sActPasteCap, sActPasteHint, sActSelectAllCap, sActSelectAllHint,
    sActDupLineCap, sActDupLineHint, sActDelToEndCap, sActDelToEndHint, sActDelToStartCap, sActDelToStartHint,
    sActFindCap, sActFindHint, sActFindNextCap, sActFindNextHint, sActFindPrevCap, sActFindPrevHint,
    sActMinimapCap, sActMinimapHint, sActPreviewCap, sActPreviewHint, sActLineNumbersCap, sActLineNumbersHint,
    sActWordWrapCap, sActWordWrapHint, sActRemoteImagesCap, sActRemoteImagesHint, sFilterText, sFindTitle,
    sFindLblFind, sFindLblRepl, sFindChkCase, sFindChkWord, sFindChkLoop, sFindBtnNext,
    sFindBtnPrev, sFindBtnReplace, sFindBtnReplaceAll, sFindBtnClose, sFindNotFound, sFindReplaced,
    sMnCut, sMnCopy, sMnPaste, sMnSelectAll, sMnUndo, sMnRedo,
    sMnQuoteCopy, sMnAppendCut, sMnAppendCopy, sMnDelete, sMnToHalfKana, sMnToHalfKanaSyn,
    sMnToHiragana, sMnToKatakana, sMnTabToSpace, sMnTabToSpaceSyn, sMnSpaceToTab, sMnSpaceToTabSyn,
    sMnIndent, sMnOutdent, sMnMinimap, sMnPreview, sMnPrint, sUnsavedTitle,
    sUnsavedLine1, sUnsavedLine2, sGoToLineTitle, sGoToLinePrompt, sErrCp932, sErrEditorHtml,
    sErrMonacoLoader, sErrPreviewHtml, sErrPrintDialog, sErrPageRange, sErrAlreadyOpen, sErrFileNotFound,
    sErrOpenOtherWindow, sErrMoveOtherWindow, sErrNoPrintPage, sErrPreviewBinder, sErrTabBinder, sErrIniMissing,
    sErrWebView2Start, sTbClose, sTbNew, sTbTabTitle, sPcNew, sPcClose,
    sPcRename, sPcNewPage, sPcErrParent, sSbErrParent, sTitleErrOnlyOne, sEpErrChild, sLvColName,
    sLvColSize, sLvColType, sLvColDate, sLvFolderType, sLvErrOpen, sLvErrBadChars,
    sLvViewLarge, sLvViewSmall, sLvViewList, sLvViewDetail, sLvSortName, sLvSortSize,
    sLvSortType, sLvSortDate, sLvSortAsc, sLvSortDesc, sLvMenuView, sLvMenuSort,
    sLvMenuNewFolder, sLvMenuNewText, sLvMenuPaste, sTvQuickAccess, sTvNetwork, sTvErrBadChars,
    sBmMenuTextOpen, sBmMenuTextOpenNew, sBmMenuBrowserOpen, sBmMenuBrowserOpenNew, sBmMenuEdit, sBmMenuDelete,
    sBmMenuCut, sBmMenuCopy, sBmMenuPaste, sBmMenuAddBookmark, sBmMenuAddFolder, sBmMenuAddSeparator,
    sBmMenuImport, sBmMenuExport, sBmSearchHint, sBmFileMissing, sBmUnsaved, sBmDeleteFolder,
    sBmTooMany, sBmSaveError, sBmLoadError, sBmDlgAdd, sBmDlgEdit, sBmDlgAddFolder,
    sBmDlgEditFolder, sBmDlgName, sBmDlgLocation, sBmNewFolder, sBmOK, sBmCancel,
    sBmImportFolder, sBmImportNone, sBmImportError, sBmExportError, sBmOpenError, sBmHtmlFilter,
    sFtMenuCopy, sFtMenuCut, sFtMenuPaste, sFtMenuRename, sFtMenuDelete, sFtMenuShowInExplorer,
    sFtMenuCopyPath, sFtMenuNewFolder, sFtMenuTextOpen, sFtMenuTextOpenNew, sFtMenuSide, sFtMenuWebOpen,
    sFtMenuWebOpenNew, sFtMenuOpenProgram, sFtMenuShowHidden, sFtMenuWindowsMenu, sFtErrBadChars, sFtErrCreateFolder,
    sErrFileLocked,
    sCcmdMenuCopy, sCcmdMenuPaste, sCcmdMenuSelectAll, sCcmdMenuClear, sCcmdExited, sCcmdErrStart,
    sCcmdErrNoPage, sCcmdErrNoPty
  );

{ 今の言語。最初に呼ばれたとき決め、あとは同じ値を返す }
function CXLanguage: TCXLanguage;

{ 'ja' または 'en'（HTML 側へ渡す値） }
function CXLangCode: string;

{ 今の言語に合う文字列。Format を使う文字列は Format(CXT(ID), [...]) で使う }
function CXT(AId: TCXStr): string;

{ ---- ファイルの保存（TCMonacoEditor・TCsEditor・TCSynEdit で共通） ----
  保存のために、ファイルを作り直して開く（TFileStream.Create(名前, fmCreate) の代わり）。
  fmCreate だけでは共有モードが「誰とも共有しない」になり、ウイルス対策・検索・プレビューなどが、
  書き込みを許す形でそのファイルを開いているだけでも、保存が共有違反（エラー 32）で失敗する。
  ここでは、書き込みを許す相手とは共有して開く。共有違反は 0.1 秒おき 3 回まで再試行し、
  それでも開けなければ、つかんでいるアプリ名を添えた EFCreateError にする（相手が書き込みを許さないとき）。
  使う側は、これまでどおり try ... finally で Free する。 }
function CXCreateFileShared(const AFileName: string): TFileStream;

{ そのファイルを今開いているアプリ名（'a.exe, b.exe'）。Windows の再起動マネージャーで調べる。調べられないときは '' }
function CXFileHolders(const AFileName: string): string;

implementation

uses
  SysUtils, IniFiles;

type
  TCXPair = record
    Ja, En: string;
  end;

const
  { WebView2.ini の場所と、言語を書くセクション・キー }
  INI_NAME = 'WebView2.ini';
  INI_SECTION = 'CX';
  INI_KEY = 'Language';

  CXTable: array[TCXStr] of TCXPair = (
    { A. 無題の名前 }
    (Ja: '無題';
     En: 'Untitled'),
    (Ja: '無題.txt';
     En: 'Untitled.txt'),
    { B. 標準アクション（Caption と Hint） }
    (Ja: '新規(&N)';
     En: '&New'),
    (Ja: '新しい文書';
     En: 'New document'),
    (Ja: '開く(&O)...';
     En: '&Open...'),
    (Ja: 'ファイルを開く';
     En: 'Open a file'),
    (Ja: '上書き保存(&S)';
     En: '&Save'),
    (Ja: '上書き保存';
     En: 'Save'),
    (Ja: '名前を付けて保存(&A)...';
     En: 'Save &As...'),
    (Ja: '名前を付けて保存';
     En: 'Save as'),
    (Ja: '閉じる(&C)';
     En: '&Close'),
    (Ja: '文書を閉じる';
     En: 'Close the document'),
    (Ja: '印刷(&P)...';
     En: '&Print...'),
    (Ja: 'プレビューを印刷（PDF として保存もできる）';
     En: 'Print the preview (can also be saved as PDF)'),
    (Ja: 'すべて保存(&L)';
     En: 'Save A&ll'),
    (Ja: '変更のあるタブをすべて保存';
     En: 'Save all modified tabs'),
    (Ja: 'すべて閉じる(&E)';
     En: 'Clos&e All'),
    (Ja: 'すべての文書を閉じる';
     En: 'Close all documents'),
    (Ja: '元に戻す(&U)';
     En: '&Undo'),
    (Ja: '元に戻す';
     En: 'Undo'),
    (Ja: 'やり直し(&R)';
     En: '&Redo'),
    (Ja: 'やり直し';
     En: 'Redo'),
    (Ja: '切り取り(&T)';
     En: 'Cu&t'),
    (Ja: '切り取り';
     En: 'Cut'),
    (Ja: 'コピー(&C)';
     En: '&Copy'),
    (Ja: 'コピー';
     En: 'Copy'),
    (Ja: '貼り付け(&P)';
     En: '&Paste'),
    (Ja: '貼り付け';
     En: 'Paste'),
    (Ja: 'すべて選択(&A)';
     En: 'Select &All'),
    (Ja: 'すべて選択';
     En: 'Select all'),
    (Ja: '行の複製(&D)';
     En: '&Duplicate Line'),
    (Ja: 'カーソル行を複製して下へ';
     En: 'Duplicate the cursor line below'),
    (Ja: '末尾まで削除';
     En: 'Delete to End'),
    (Ja: 'カーソル位置から文書の末尾まで削除';
     En: 'Delete from the cursor to the end of the document'),
    (Ja: '先頭まで削除';
     En: 'Delete to Start'),
    (Ja: 'カーソル位置から文書の先頭まで削除';
     En: 'Delete from the cursor to the start of the document'),
    (Ja: '検索・置換(&F)...';
     En: '&Find/Replace...'),
    (Ja: '検索・置換ダイアログを開く';
     En: 'Open the find/replace dialog'),
    (Ja: '次を検索(&N)';
     En: 'Find &Next'),
    (Ja: '直前の検索語で次を検索';
     En: 'Find the next match of the last search'),
    (Ja: '前を検索(&V)';
     En: 'Find Pre&vious'),
    (Ja: '直前の検索語で前を検索';
     En: 'Find the previous match of the last search'),
    (Ja: 'ミニマップ(&M)';
     En: '&Minimap'),
    (Ja: 'ミニマップの表示・非表示';
     En: 'Show or hide the minimap'),
    (Ja: 'プレビュー(&V)';
     En: 'Pre&view'),
    (Ja: 'プレビューの表示・非表示';
     En: 'Show or hide the preview'),
    (Ja: '行番号(&L)';
     En: '&Line Numbers'),
    (Ja: '行番号の表示・非表示';
     En: 'Show or hide line numbers'),
    (Ja: '折り返し(&W)';
     En: '&Word Wrap'),
    (Ja: '折り返し表示の切り替え';
     En: 'Toggle word wrap'),
    (Ja: 'ネットの画像を表示(&I)';
     En: 'Show Online &Images'),
    (Ja: 'プレビューで、ネット（http）の画像を表示するか';
     En: 'Show online (http) images in the preview'),
    { C. ファイル選択の絞り込み }
    (Ja: 'テキスト (*.txt)|*.txt|すべてのファイル (*.*)|*.*';
     En: 'Text (*.txt)|*.txt|All files (*.*)|*.*'),
    { D. 検索・置換ダイアログ }
    (Ja: '検索・置換';
     En: 'Find/Replace'),
    (Ja: '検索(&F):';
     En: '&Find:'),
    (Ja: '置換(&R):';
     En: '&Replace:'),
    (Ja: '大文字小文字を区別する(&C)';
     En: 'Match &case'),
    (Ja: '単語単位で検索(&W)';
     En: '&Whole word'),
    (Ja: 'ループ検索(&L)';
     En: '&Loop search'),
    (Ja: '次を検索(&N)';
     En: 'Find &Next'),
    (Ja: '前を検索(&P)';
     En: 'Find &Previous'),
    (Ja: '置換(&E)';
     En: 'R&eplace'),
    (Ja: 'すべて置換(&A)';
     En: 'Replace &All'),
    (Ja: '閉じる';
     En: 'Close'),
    (Ja: '見つかりません';
     En: 'Not found'),
    (Ja: '%d 件置換しました';
     En: '%d replaced'),
    { E. エディタの右クリックメニュー・プレビューの右クリックメニュー }
    (Ja: '切り抜き';
     En: 'Cut'),
    (Ja: 'コピー';
     En: 'Copy'),
    (Ja: '貼り付け';
     En: 'Paste'),
    (Ja: 'すべて選択';
     En: 'Select All'),
    (Ja: '元に戻す';
     En: 'Undo'),
    (Ja: 'やり直し';
     En: 'Redo'),
    (Ja: '引用付きコピー';
     En: 'Copy as Quote'),
    (Ja: '追加切り抜き';
     En: 'Append Cut'),
    (Ja: '追加コピー';
     En: 'Append Copy'),
    (Ja: '削除';
     En: 'Delete'),
    (Ja: 'ﾊﾝｶｸに変換';
     En: 'Convert to Half-width Kana'),
    (Ja: 'ハンカクに変換';
     En: 'Convert to Half-width Kana'),
    (Ja: '全角ひらがなに変換';
     En: 'Convert to Full-width Hiragana'),
    (Ja: '全角カタカナに変換';
     En: 'Convert to Full-width Katakana'),
    (Ja: 'TAB -> 空白';
     En: 'Convert Tabs to Spaces'),
    (Ja: 'TAB -> 空白 変換';
     En: 'Convert Tabs to Spaces'),
    (Ja: '空白 -> TAB';
     En: 'Convert Spaces to Tabs'),
    (Ja: '空白 -> TAB 変換';
     En: 'Convert Spaces to Tabs'),
    (Ja: 'インデント';
     En: 'Indent'),
    (Ja: '逆インデント';
     En: 'Unindent'),
    (Ja: 'ミニマップ';
     En: 'Minimap'),
    (Ja: 'プレビュー';
     En: 'Preview'),
    (Ja: '印刷...';
     En: 'Print...'),
    { F. 確認・入力・エラーのメッセージ }
    (Ja: '未保存の変更';
     En: 'Unsaved changes'),
    (Ja: '%s は変更されています。';
     En: '%s has been modified.'),
    (Ja: '保存しますか？（いいえ = 保存せずに閉じる）';
     En: 'Do you want to save it? (No = close without saving)'),
    (Ja: '行へ移動';
     En: 'Go to Line'),
    (Ja: '行番号（1〜%d）';
     En: 'Line number (1-%d)'),
    (Ja: 'CP932(Shift_JIS)で表現できない文字が含まれています。Encoding を UTF-8 に変更してください。';
     En: 'The text contains characters that cannot be represented in CP932 (Shift_JIS). Change Encoding to UTF-8.'),
    (Ja: 'editor.html が見つかりません: ';
     En: 'editor.html not found: '),
    (Ja: 'Monaco の vs\loader.js が見つかりません: ';
     En: 'Monaco vs\loader.js not found: '),
    (Ja: 'preview.html が見つかりません: ';
     En: 'preview.html not found: '),
    (Ja: '印刷ダイアログを表示できませんでした';
     En: 'Could not show the print dialog'),
    (Ja: 'Pages[%d]: ページの番号が範囲外です（ページの数 %d）';
     En: 'Pages[%d]: page index out of range (page count: %d)'),
    (Ja: 'そのファイルは別のタブで開いています: ';
     En: 'That file is already open in another tab: '),
    (Ja: 'ファイルが見つかりません: ';
     En: 'File not found: '),
    (Ja: '別のウィンドウで開けませんでした: ';
     En: 'Could not open in another window: '),
    (Ja: 'ほかのウィンドウへ移せませんでした';
     En: 'Could not move to the other window'),
    (Ja: '印刷するページがありません';
     En: 'There is no page to print'),
    (Ja: 'TCMPreviewBinder.Attach: エディタまたはプレビューが nil です';
     En: 'TCMPreviewBinder.Attach: the editor or the preview is nil'),
    (Ja: 'TCMTabBinder.Attach: エディタが nil です';
     En: 'TCMTabBinder.Attach: the editor is nil'),
    (Ja: 'WebView2.ini が見つかりません: ';
     En: 'WebView2.ini not found: '),
    (Ja: 'WebView2 を起動できません';
     En: 'Could not start WebView2'),
    { G. TCTabBrowser }
    (Ja: '閉じる';
     En: 'Close'),
    (Ja: '新規作成';
     En: 'New'),
    (Ja: 'タブ %d';
     En: 'Tab %d'),
    { H. TCPageControl・TCSideBar・TCTitleBar }
    (Ja: '新しいタブ';
     En: 'New Tab'),
    (Ja: 'タブを閉じる';
     En: 'Close Tab'),
    (Ja: 'タブ名の変更';
     En: 'Rename Tab'),
    (Ja: '新しいタブ';
     En: 'New Tab'),
    (Ja: '%s の親にできるのは TCPageControl だけです（%s は指定できません）';
     En: 'Only a TCPageControl can be the parent of %s (%s is not allowed)'),
    (Ja: 'TCSideBarPage は TCSideBar の上にだけ置けます';
     En: 'TCSideBarPage can only be placed on a TCSideBar'),
    (Ja: 'TCTitleBar は1つのフォームに1つだけ置けます';
     En: 'Only one TCTitleBar can be placed on a form'),
    { H2. TCExpandPanel }
    (Ja: 'TCExpandPanel には TCRollout だけを入れられます';
     En: 'Only a TCRollout can be placed on a TCExpandPanel'),
    { I. TCListView・TCTreeView }
    (Ja: '名前';
     En: 'Name'),
    (Ja: 'サイズ';
     En: 'Size'),
    (Ja: '種類';
     En: 'Type'),
    (Ja: '更新日時';
     En: 'Date modified'),
    (Ja: 'フォルダ';
     En: 'Folder'),
    (Ja: 'ファイルを開けませんでした。エラーコード: ';
     En: 'Could not open the file. Error code: '),
    (Ja: 'ファイル名に以下の文字は使用できません:';
     En: 'The following characters cannot be used in a file name:'),
    (Ja: '大アイコン(&R)';
     En: 'Lar&ge icons'),
    (Ja: '小アイコン(&N)';
     En: 'S&mall icons'),
    (Ja: '一覧(&L)';
     En: '&List'),
    (Ja: '詳細(&D)';
     En: '&Details'),
    (Ja: '名前(&N)';
     En: '&Name'),
    (Ja: 'サイズ(&S)';
     En: '&Size'),
    (Ja: '種類(&T)';
     En: '&Type'),
    (Ja: '更新日時(&D)';
     En: '&Date modified'),
    (Ja: '昇順(&A)';
     En: '&Ascending'),
    (Ja: '降順(&E)';
     En: 'D&escending'),
    (Ja: '表示(&V)';
     En: '&View'),
    (Ja: '並べ替え(&O)';
     En: 'S&ort by'),
    (Ja: '新規フォルダー(&N)';
     En: 'New &folder'),
    (Ja: '新規テキスト ドキュメント(&T)';
     En: 'New &text document'),
    (Ja: '貼り付け(&P)';
     En: '&Paste'),
    (Ja: 'クイックアクセス';
     En: 'Quick access'),
    (Ja: 'ネットワーク';
     En: 'Network'),
    (Ja: 'フォルダ名に以下の文字は使用できません:';
     En: 'The following characters cannot be used in a folder name:'),
    { J. TCBookmark }
    (Ja: 'Text開く';
     En: 'Open as Text'),
    (Ja: 'Text新しいタブで開く';
     En: 'Open as Text in New Tab'),
    (Ja: 'Browserで開く';
     En: 'Open in Browser'),
    (Ja: 'Browserで新しいタブで開く';
     En: 'Open in Browser in New Tab'),
    (Ja: 'ブックマークを編集';
     En: 'Edit Bookmark'),
    (Ja: 'ブックマークを削除';
     En: 'Delete Bookmark'),
    (Ja: '切取り';
     En: 'Cut'),
    (Ja: 'コピー';
     En: 'Copy'),
    (Ja: '貼り付け';
     En: 'Paste'),
    (Ja: 'ブックマークを追加';
     En: 'Add Bookmark'),
    (Ja: 'フォルダーを追加';
     En: 'Add Folder'),
    (Ja: '区切り線';
     En: 'Add Separator'),
    (Ja: 'インポート...';
     En: 'Import...'),
    (Ja: 'エクスポート...';
     En: 'Export...'),
    (Ja: 'ブックマークを検索';
     En: 'Search bookmarks'),
    (Ja: 'ファイルがありません：%s';
     En: 'File not found: %s'),
    (Ja: '保存されていない変更があります。新しいタブで開きますか？';
     En: 'There are unsaved changes. Open in a new tab?'),
    (Ja: 'フォルダー「%s」と中の %d 件を削除しますか？';
     En: 'Delete the folder "%s" and its %d item(s)?'),
    (Ja: '%d 件を登録しますか？';
     En: 'Add %d item(s)?'),
    (Ja: 'ブックマークを保存できません：%s';
     En: 'Could not save the bookmarks: %s'),
    (Ja: 'ブックマークを読み込めませんでした。元のファイルは %s に残しました。';
     En: 'Could not load the bookmarks. The original file was kept at %s.'),
    (Ja: 'ブックマークを追加';
     En: 'Add Bookmark'),
    (Ja: 'ブックマークを編集';
     En: 'Edit Bookmark'),
    (Ja: 'フォルダーを追加';
     En: 'Add Folder'),
    (Ja: 'フォルダー名を編集';
     En: 'Edit Folder Name'),
    (Ja: '名前';
     En: 'Name'),
    (Ja: 'URL またはファイルパス';
     En: 'URL or file path'),
    (Ja: '新しいフォルダー';
     En: 'New Folder'),
    (Ja: 'OK';
     En: 'OK'),
    (Ja: 'キャンセル';
     En: 'Cancel'),
    (Ja: 'インポート %s';
     En: 'Import %s'),
    (Ja: 'ブックマークが見つかりませんでした。';
     En: 'No bookmarks were found.'),
    (Ja: 'インポートできません：%s';
     En: 'Could not import: %s'),
    (Ja: 'エクスポートできません：%s';
     En: 'Could not export: %s'),
    (Ja: '開けません：%s';
     En: 'Could not open: %s'),
    (Ja: 'ブックマーク HTML (*.html;*.htm)|*.html;*.htm|すべてのファイル (*.*)|*.*';
     En: 'Bookmark HTML (*.html;*.htm)|*.html;*.htm|All files (*.*)|*.*'),
    { K. TCFileTree }
    (Ja: 'コピー';
     En: 'Copy'),
    (Ja: '切取り';
     En: 'Cut'),
    (Ja: '貼付け';
     En: 'Paste'),
    (Ja: '名前の変更';
     En: 'Rename'),
    (Ja: '削除';
     En: 'Delete'),
    (Ja: 'エクスプローラーで表示';
     En: 'Show in Explorer'),
    (Ja: 'パスのコピー';
     En: 'Copy Path'),
    (Ja: 'フォルダ作成';
     En: 'New Folder'),
    (Ja: 'text開く';
     En: 'Open as Text'),
    (Ja: 'text新規タブで開く';
     En: 'Open as Text in New Tab'),
    (Ja: '横に並べて表示';
     En: 'Open Side by Side'),
    (Ja: 'Web開く';
     En: 'Open as Web'),
    (Ja: 'Web新規タブで開く';
     En: 'Open as Web in New Tab'),
    (Ja: 'プログラムで開く';
     En: 'Open with Associated Program'),
    (Ja: '隠しファイルを表示';
     En: 'Show Hidden Files'),
    (Ja: 'windowsメニュー';
     En: 'Windows Menu'),
    (Ja: 'ファイル名・フォルダー名に以下の文字は使用できません:';
     En: 'The following characters cannot be used in a file or folder name:'),
    (Ja: 'フォルダーを作れませんでした：%s';
     En: 'Could not create the folder: %s'),
    { N. ファイルの保存 }
    (Ja: 'ほかのアプリがこのファイルを使用中で、保存できません';
     En: 'The file is in use by another application and cannot be saved'),
    { O. TCcmd（端末） }
    (Ja: 'コピー(&C)';
     En: 'Copy(&C)'),
    (Ja: '貼り付け(&P)';
     En: 'Paste(&P)'),
    (Ja: 'すべて選択(&A)';
     En: 'Select All(&A)'),
    (Ja: '画面を消す(&L)';
     En: 'Clear(&L)'),
    (Ja: '[プロセスが終了しました（コード %d）]';
     En: '[Process exited with code %d]'),
    (Ja: 'シェルを起動できませんでした：%s';
     En: 'Could not start the shell: %s'),
    (Ja: 'terminal.html が見つかりません：%s';
     En: 'terminal.html was not found: %s'),
    (Ja: 'この Windows には、ConPTY（擬似コンソール）がありません';
     En: 'This Windows does not have ConPTY (pseudo console)')
  );

var
  { 言語を決めたか（決めるのは最初の 1 回だけ） }
  GResolved: Boolean = False;
  GLang: TCXLanguage = cxlJa;

{$IFDEF MSWINDOWS}
{ Windows の表示言語（LANGID）。FPC の windows ユニットの宣言に頼らず、自分で宣言する }
function GetUserDefaultUILanguage: Word; stdcall; external 'kernel32' name 'GetUserDefaultUILanguage';
{$ENDIF}

{ Windows の表示言語が日本語なら cxlJa、それ以外は cxlEn }
function OsLanguage: TCXLanguage;
begin
  Result := cxlEn;
  {$IFDEF MSWINDOWS}
  { LANGID の下位 10 ビットが主言語。$11 = LANG_JAPANESE }
  if (GetUserDefaultUILanguage and $3FF) = $11 then Result := cxlJa;
  {$ENDIF}
end;

{ ini の [CX] Language を読む。ja なら 1、en なら 2、それ以外（読めない・無い・空・ほかの値）は 0 }
function IniLanguage: Integer;
var
  FileName, S: string;
  Ini: TIniFile;
begin
  Result := 0;
  try
    FileName := ExtractFilePath(ParamStr(0)) + INI_NAME;
    if not FileExists(FileName) then Exit;
    Ini := TIniFile.Create(FileName);
    try
      S := LowerCase(Trim(Ini.ReadString(INI_SECTION, INI_KEY, '')));
    finally
      Ini.Free;
    end;
    if S = 'ja' then Result := 1
    else if S = 'en' then Result := 2;
  except
    Result := 0;                 { 読めない：例外は出さず、Windows の表示言語に任せる }
  end;
end;

{ 最初に呼ばれたときだけ、ini → Windows の表示言語の順で言語を決める }
procedure ResolveLanguage;
begin
  case IniLanguage of
    1: GLang := cxlJa;
    2: GLang := cxlEn;
  else
    GLang := OsLanguage;
  end;
  GResolved := True;
end;

function CXLanguage: TCXLanguage;
begin
  if not GResolved then ResolveLanguage;
  Result := GLang;
end;

function CXLangCode: string;
begin
  if CXLanguage = cxlJa then Result := 'ja' else Result := 'en';
end;

function CXT(AId: TCXStr): string;
begin
  if CXLanguage = cxlJa then Result := CXTable[AId].Ja else Result := CXTable[AId].En;
end;


{ ---------- ファイルの保存 ---------- }

const
  ERROR_SHARING_VIOLATION = 32;
  ERROR_LOCK_VIOLATION = 33;

type
  { 再起動マネージャー（rstrtmgr.dll）の宣言。FPC の windows ユニットには無いので、自分で宣言する }
  TRmFileTime = record
    dwLowDateTime, dwHighDateTime: LongWord;
  end;
  TRmProcessInfo = record
    dwProcessId: LongWord;
    ProcessStartTime: TRmFileTime;
    strAppName: array[0..255] of WideChar;
    strServiceShortName: array[0..63] of WideChar;
    ApplicationType: LongWord;
    AppStatus: LongWord;
    TSSessionId: LongWord;
    bRestartable: LongBool;
  end;

function RmStartSession(var pSessionHandle: LongWord; dwSessionFlags: LongWord;
  strSessionKey: PWideChar): LongWord; stdcall; external 'rstrtmgr.dll';
function RmRegisterResources(dwSessionHandle: LongWord; nFiles: LongWord; rgsFileNames: PPWideChar;
  nApplications: LongWord; rgApplications: Pointer; nServices: LongWord;
  rgsServiceNames: Pointer): LongWord; stdcall; external 'rstrtmgr.dll';
function RmGetList(dwSessionHandle: LongWord; var pnProcInfoNeeded: LongWord; var pnProcInfo: LongWord;
  rgAffectedApps: Pointer; var lpdwRebootReasons: LongWord): LongWord; stdcall; external 'rstrtmgr.dll';
function RmEndSession(dwSessionHandle: LongWord): LongWord; stdcall; external 'rstrtmgr.dll';

function CXFileHolders(const AFileName: string): string;
var
  Session, Need, Count, Reasons: LongWord;
  Key: array[0..32] of WideChar;
  FileW: UnicodeString;
  PFile: PWideChar;
  Info: array of TRmProcessInfo;
  I: Integer;
  Name: string;
begin
  Result := '';
  try
    FillChar(Key, SizeOf(Key), 0);
    if RmStartSession(Session, 0, @Key[0]) <> 0 then Exit;
    try
      FileW := UTF8Decode(AFileName);
      PFile := PWideChar(FileW);
      if RmRegisterResources(Session, 1, @PFile, 0, nil, 0, nil) <> 0 then Exit;
      Need := 0;
      Count := 0;
      Reasons := 0;
      RmGetList(Session, Need, Count, nil, Reasons);
      if Need = 0 then Exit;
      SetLength(Info, Need);
      Count := Need;
      if RmGetList(Session, Need, Count, @Info[0], Reasons) <> 0 then Exit;
      for I := 0 to Integer(Count) - 1 do
      begin
        Name := UTF8Encode(WideString(PWideChar(@Info[I].strAppName[0])));
        if Name = '' then Continue;
        if Pos(Name, Result) > 0 then Continue;           { 同じ名前は 1 回だけ }
        if Result <> '' then Result := Result + ', ';
        Result := Result + Name;
      end;
    finally
      RmEndSession(Session);
    end;
  except
    Result := '';                    { 調べられなくても、保存の失敗はそのまま伝える }
  end;
end;

function CXCreateFileShared(const AFileName: string): TFileStream;
var
  Attempt, Err: Integer;
  Holders: string;
begin
  Attempt := 0;
  while True do
  begin
    try
      Result := TFileStream.Create(AFileName, fmCreate or fmShareDenyNone);
      Exit;
    except
      on E: EStreamError do
      begin
        Err := GetLastOSError;
        if (Err <> ERROR_SHARING_VIOLATION) and (Err <> ERROR_LOCK_VIOLATION) then raise;
        if Attempt < 3 then
        begin
          Inc(Attempt);
          Sleep(100);                { ウイルス対策などが一瞬つかむことがあるので、少し待つ }
          Continue;
        end;
        Holders := CXFileHolders(AFileName);
        if Holders <> '' then
          raise EFCreateError.Create(CXT(sErrFileLocked) + ' (' + Holders + ')')
        else
          raise EFCreateError.Create(CXT(sErrFileLocked));
      end;
    end;
  end;
end;
end.
