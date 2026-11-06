program tcFileTree;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset

  SysUtils,
  Forms,

  LCLType,
  Graphics,
  uDarkStyleParams,
  uMetaDarkStyle,
  uDarkStyleSchemes,

  Unit1
  { you can add units after this };

{$R *.res}

begin

  // エクスプローラー寄せ（既定は 53,53,53 などの明るめグレー）
  DefaultDark.SysColor[COLOR_FORM]      := RGBToColor(32, 32, 32);  // フォーム背景
  DefaultDark.SysColor[COLOR_BTNFACE]   := RGBToColor(32, 32, 32);  // パネル等
  DefaultDark.SysColor[COLOR_WINDOW]    := RGBToColor(30, 30, 30);  // リスト・入力欄（エディタ #1E1E1E と同じ）
  DefaultDark.SysColor[COLOR_HIGHLIGHT] := RGBToColor(58, 58, 58);  // 選択（既定は青）

  DefaultDark.SysColor[ COLOR_SCROLLBAR ]       := RGBToColor(32, 32, 32);  // フォーム背景
  DefaultDark.SysColor[ COLOR_BACKGROUND ]      := RGBToColor(32, 32, 32);  // フォーム背景
  DefaultDark.SysColor[ COLOR_ACTIVEBORDER ]    := RGBToColor(32, 32, 32);  // フォーム背景
  DefaultDark.SysColor[ COLOR_INACTIVEBORDER ]  := RGBToColor(32, 32, 32);  // フォーム背景
  DefaultDark.SysColor[ COLOR_APPWORKSPACE ]    := RGBToColor(32, 32, 32);  // フォーム背景
  DefaultDark.SysColor[ COLOR_INACTIVECAPTION ] := RGBToColor(32, 32, 32);  // フォーム背景
  DefaultDark.SysColor[ COLOR_BTNHIGHLIGHT ]    := RGBToColor(20, 20, 20);   //RGBToColor(43, 43, 43);
  DefaultDark.SysColor[ COLOR_MENUHILIGHT ]     := RGBToColor(58, 58, 58);  // メニュー上の選択（メニューより明るく）
  DefaultDark.SysColor[ COLOR_MENU ]            := RGBToColor(32, 32, 32);  // メニュー（タイトルバー・フォームと同じ）
  DefaultDark.SysColor[ COLOR_MENUBAR ]         := RGBToColor(32, 32, 32);
  DefaultDark.SysColor[ COLOR_3DLIGHT ]         := RGBToColor(40, 40, 40);  // タブの枠線（32で消える）
  DefaultDark.SysColor[ COLOR_HIGHLIGHT ]       := RGBToColor(58, 58, 58);

  DefaultDark.DrawControl.CustomDrawPushButtons := True;  // ボタンをライブラリで描く
  DefaultDark.DrawControl.CustomDrawComboBoxs   := True;  // コンボをライブラリで描く

  PreferredAppMode := pamAllowDark;
  uMetaDarkStyle.ApplyMetaDarkStyle(DefaultDark);

  RequireDerivedFormResource := True;
  Application.Scaled := True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar := True;
  {$POP}
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

