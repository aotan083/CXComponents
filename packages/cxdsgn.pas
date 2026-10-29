{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit cxdsgn;

{$warn 5023 off : no warning about unused units}
interface

uses
  uCXReg, uCSideBarReg, uCPageControl_reg, uCbookmark_reg, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('uCXReg', @uCXReg.Register);
  RegisterUnit('uCSideBarReg', @uCSideBarReg.Register);
  RegisterUnit('uCPageControl_reg', @uCPageControl_reg.Register);
  RegisterUnit('uCbookmark_reg', @uCbookmark_reg.Register);
end;

initialization
  RegisterPackage('cxdsgn', @Register);
end.
