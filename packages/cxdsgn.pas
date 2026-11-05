{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit cxdsgn;

{$warn 5023 off : no warning about unused units}
interface

uses
  uCXReg, uCSideBarReg, uCExpandPanelReg, uCPageControl_reg, uCbookmark_reg, uCFileTreeReg, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('uCXReg', @uCXReg.Register);
  RegisterUnit('uCSideBarReg', @uCSideBarReg.Register);
  RegisterUnit('uCExpandPanelReg', @uCExpandPanelReg.Register);
  RegisterUnit('uCPageControl_reg', @uCPageControl_reg.Register);
  RegisterUnit('uCbookmark_reg', @uCbookmark_reg.Register);
  RegisterUnit('uCFileTreeReg', @uCFileTreeReg.Register);
end;

initialization
  RegisterPackage('cxdsgn', @Register);
end.
