{ Copyright (c) 2026 aotan083
  SPDX-License-Identifier: MIT
  https://github.com/aotan083/CXComponents }
unit uCImages;

{ TCImage・TCImageList - bmp・jpg(jpeg)・png・svg・tif(tiff)・ico を扱える画像部品と画像リスト。
  設計書：docs\TCImage_Design.md
  ・TCImage    ：TImage の子クラス。読み込み・保存を拡張子の形式で行う（svg は読み込みだけ）
  ・TCImageList：TImageList の子クラス。ファイル・TCImage・フォルダーから画像を足せる
  ・保存は、いったんメモリへ書いてからファイルへ写す（変換に失敗しても、元のファイルを壊さない） }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Math, Graphics, Controls, ExtCtrls, ImgList,
  IntfGraphics, FPImage, FPWriteTiff, GraphType, LCLType, LCLIntf, SVGImg, uCXLang;

type
  { 画像の形式 }
  TCImageFormat = (cifNone, cifBmp, cifJpeg, cifPng, cifTiff, cifIcon, cifSvg);

  { 画像の読み書きのエラー }
  ECImageError = class(Exception);

  { TCImage }
  TCImage = class(TImage)
  private
    FFileName: string;
    function GetImageFormat: TCImageFormat;
  public
    { 拡張子から形式を選んで読む。読めなければ ECImageError（今の絵は元のまま） }
    procedure LoadFromFile(const AFileName: string);
    { 保存先の拡張子の形式で書く。フォルダーが無ければ作る。AJpegQuality は jpg のときだけ使う }
    procedure SaveToFile(const AFileName: string; AJpegQuality: Integer = 90);
    { TBitmap の中身を絵にする（取り込み部品が使う） }
    procedure LoadFromBitmap(ABitmap: TBitmap);
    { 今の絵を 32 ビットの TBitmap にして返す。呼んだ側が Free する }
    function ToBitmap: TBitmap;
    class function IsSupportedFile(const AFileName: string): Boolean;
    class function FormatOfFile(const AFileName: string): TCImageFormat;
    property FileName: string read FFileName;
    property ImageFormat: TCImageFormat read GetImageFormat;
  end;

  { TCImageList }
  TCImageList = class(TImageList)
  public
    { 画像ファイルを 1 枚足す（Width x Height に合わせる）。足した位置を返す }
    function AddFromFile(const AFileName: string): Integer;
    { TCImage の絵を足す。足した位置を返す }
    function AddFromImage(AImage: TCImage): Integer;
    { フォルダーの中の対応形式のファイルを、ファイル名順に足す。足した数を返す }
    function AddFromFolder(const AFolder: string; ARecursive: Boolean = False): Integer;
    { 指定の 1 枚を、TCImage.SaveToFile と同じ規則でファイルに書く }
    procedure SaveItemToFile(AIndex: Integer; const AFileName: string);
  end;

{ TBitmap を、拡張子の形式でファイルに書く（TCImage・TCImageList が使う） }
procedure CXSaveBitmapToFile(ABitmap: TBitmap; const AFileName: string; AJpegQuality: Integer = 90);

implementation

const
  MAX_ICON_SIZE = 256;     { ico に書ける大きさの上限 }
  DEFAULT_SVG_SIZE = 256;  { svg に大きさが無いときの大きさ }

{ ---------------------------------------------------------------------------
  形式の判定
  --------------------------------------------------------------------------- }

function FormatOfExt(const AExt: string): TCImageFormat;
var
  E: string;
begin
  E := LowerCase(AExt);
  if E = '.bmp' then Result := cifBmp
  else if (E = '.jpg') or (E = '.jpeg') then Result := cifJpeg
  else if E = '.png' then Result := cifPng
  else if (E = '.tif') or (E = '.tiff') then Result := cifTiff
  else if E = '.ico' then Result := cifIcon
  else if E = '.svg' then Result := cifSvg
  else Result := cifNone;
end;

{ ---------------------------------------------------------------------------
  画素の操作（TLazIntfImage で、アルファを保ったまま扱う）
  --------------------------------------------------------------------------- }

{ 32 ビット（アルファ付き）の空の画像を作る }
function NewIntf(AWidth, AHeight: Integer): TLazIntfImage;
var
  Desc: TRawImageDescription;
begin
  Result := TLazIntfImage.Create(0, 0);
  Desc.Init_BPP32_B8G8R8A8_BIO_TTB(AWidth, AHeight);
  Result.DataDescription := Desc;
  Result.SetSize(AWidth, AHeight);
end;

{ TBitmap の中身を、アルファ付きの TLazIntfImage にする（呼んだ側が Free） }
function BitmapToIntf(ABitmap: TBitmap): TLazIntfImage;
var
  Src: TLazIntfImage;
  X, Y: Integer;
begin
  Result := NewIntf(ABitmap.Width, ABitmap.Height);
  Src := TLazIntfImage.Create(ABitmap.RawImage, False);
  try
    for Y := 0 to ABitmap.Height - 1 do
      for X := 0 to ABitmap.Width - 1 do
        Result.Colors[X, Y] := Src.Colors[X, Y];
  finally
    Src.Free;
  end;
end;

{ TLazIntfImage から 32 ビットの TBitmap を作る（アルファを保つ） }
function IntfToBitmap(AIntf: TLazIntfImage): TBitmap;
begin
  Result := TBitmap.Create;
  Result.PixelFormat := pf32bit;
  Result.LoadFromIntfImage(AIntf);
end;

{ TBitmap を 32 ビットにそろえる。アルファを持たない絵（24 ビットなど）は、不透明にする }
function ToBitmap32(ASrc: TBitmap): TBitmap;
var
  Intf: TLazIntfImage;
  X, Y: Integer;
  C: TFPColor;
begin
  Intf := BitmapToIntf(ASrc);
  try
    if ASrc.RawImage.Description.AlphaPrec = 0 then
      for Y := 0 to Intf.Height - 1 do
        for X := 0 to Intf.Width - 1 do
        begin
          C := Intf.Colors[X, Y];
          C.Alpha := $FFFF;
          Intf.Colors[X, Y] := C;
        end;
    Result := IntfToBitmap(Intf);
  finally
    Intf.Free;
  end;
end;

{ 絵（TGraphic）を AWidth x AHeight に描き、アルファ付きの TBitmap にする。
  svg のように、描く先の canvas にアルファが渡らない絵は、黒地と白地に描いた 2 枚の差からアルファを求める }
function RenderGraphic(AGraphic: TGraphic; AWidth, AHeight: Integer): TBitmap;
var
  BmpK, BmpW: TBitmap;
  IK, IW, IR: TLazIntfImage;
  X, Y: Integer;
  CK, CW, CR: TFPColor;
  A: Integer;

  procedure DrawOn(ABmp: TBitmap; AColor: TColor);
  begin
    ABmp.PixelFormat := pf24bit;
    ABmp.SetSize(AWidth, AHeight);
    ABmp.Canvas.Brush.Color := AColor;
    ABmp.Canvas.FillRect(0, 0, AWidth, AHeight);
    ABmp.Canvas.StretchDraw(Rect(0, 0, AWidth, AHeight), AGraphic);
  end;

begin
  BmpK := TBitmap.Create;
  BmpW := TBitmap.Create;
  IK := nil; IW := nil; IR := nil;
  try
    DrawOn(BmpK, clBlack);
    DrawOn(BmpW, clWhite);
    IK := BitmapToIntf(BmpK);
    IW := BitmapToIntf(BmpW);
    IR := NewIntf(AWidth, AHeight);
    for Y := 0 to AHeight - 1 do
      for X := 0 to AWidth - 1 do
      begin
        CK := IK.Colors[X, Y];
        CW := IW.Colors[X, Y];
        { 白地と黒地の差（緑で見る）が、透けている分 }
        A := $FFFF - (CW.Green - CK.Green);
        if A < 0 then A := 0;
        if A > $FFFF then A := $FFFF;
        CR.Alpha := A;
        if A = 0 then
        begin
          CR.Red := 0; CR.Green := 0; CR.Blue := 0;
        end
        else
        begin
          { 黒地に描いた色 = 色 x アルファ なので、アルファで割って戻す }
          CR.Red := Min($FFFF, (CK.Red * $FFFF) div A);
          CR.Green := Min($FFFF, (CK.Green * $FFFF) div A);
          CR.Blue := Min($FFFF, (CK.Blue * $FFFF) div A);
        end;
        IR.Colors[X, Y] := CR;
      end;
    Result := IntfToBitmap(IR);
  finally
    IK.Free; IW.Free; IR.Free;
    BmpK.Free; BmpW.Free;
  end;
end;

{ 絵を、自分の大きさの TBitmap にする（アルファ付き）。大きさの無い svg は DEFAULT_SVG_SIZE }
function GraphicToBitmap(AGraphic: TGraphic): TBitmap;
var
  W, H: Integer;
  Tmp: TBitmap;
begin
  if (AGraphic is TRasterImage) and not (AGraphic is TIcon) then
  begin
    Tmp := TBitmap.Create;
    try
      Tmp.Assign(AGraphic);
      Result := ToBitmap32(Tmp);
    finally
      Tmp.Free;
    end;
  end
  else
  begin
    W := AGraphic.Width;
    H := AGraphic.Height;
    if (W <= 0) or (H <= 0) then
    begin
      W := DEFAULT_SVG_SIZE;
      H := DEFAULT_SVG_SIZE;
    end;
    { svg・ico は、描いて取る（ico は、TIcon が選んだ絵が描かれる） }
    Result := RenderGraphic(AGraphic, W, H);
  end;
end;

{ ASrc を、縦横比を保って AWidth x AHeight に収め、中央に置いた TBitmap を返す（余白は透明）。
  縮小・拡大は、アルファで重みを付けた双線形補間 }
function FitBitmap(ASrc: TBitmap; AWidth, AHeight: Integer): TBitmap;
var
  Scale: Double;
  NW, NH, OX, OY, X, Y, X0, Y0, X1, Y1: Integer;
  FX, FY, W00, W10, W01, W11, SA, SR, SG, SB: Double;
  Src, Dst: TLazIntfImage;
  C00, C10, C01, C11, CR: TFPColor;

  procedure Acc(const C: TFPColor; W: Double);
  var
    A: Double;
  begin
    A := (C.Alpha / 65535.0) * W;
    SA := SA + A;
    SR := SR + C.Red * A;
    SG := SG + C.Green * A;
    SB := SB + C.Blue * A;
  end;

begin
  Src := BitmapToIntf(ASrc);
  Dst := NewIntf(AWidth, AHeight);
  try
    if (ASrc.Width <= 0) or (ASrc.Height <= 0) then
    begin
      Result := IntfToBitmap(Dst);
      Exit;
    end;
    Scale := Min(AWidth / ASrc.Width, AHeight / ASrc.Height);
    NW := Max(1, Round(ASrc.Width * Scale));
    NH := Max(1, Round(ASrc.Height * Scale));
    OX := (AWidth - NW) div 2;
    OY := (AHeight - NH) div 2;
    for Y := 0 to NH - 1 do
      for X := 0 to NW - 1 do
      begin
        { 出力の画素の中心に当たる、元の位置 }
        FX := (X + 0.5) * ASrc.Width / NW - 0.5;
        FY := (Y + 0.5) * ASrc.Height / NH - 0.5;
        X0 := Floor(FX); Y0 := Floor(FY);
        FX := FX - X0; FY := FY - Y0;
        X1 := Min(X0 + 1, ASrc.Width - 1);
        Y1 := Min(Y0 + 1, ASrc.Height - 1);
        X0 := Max(X0, 0); Y0 := Max(Y0, 0);
        C00 := Src.Colors[X0, Y0]; C10 := Src.Colors[X1, Y0];
        C01 := Src.Colors[X0, Y1]; C11 := Src.Colors[X1, Y1];
        W00 := (1 - FX) * (1 - FY); W10 := FX * (1 - FY);
        W01 := (1 - FX) * FY; W11 := FX * FY;
        SA := 0; SR := 0; SG := 0; SB := 0;
        Acc(C00, W00); Acc(C10, W10); Acc(C01, W01); Acc(C11, W11);
        if SA <= 0.000001 then
        begin
          CR.Red := 0; CR.Green := 0; CR.Blue := 0; CR.Alpha := 0;
        end
        else
        begin
          CR.Red := Min($FFFF, Round(SR / SA));
          CR.Green := Min($FFFF, Round(SG / SA));
          CR.Blue := Min($FFFF, Round(SB / SA));
          CR.Alpha := Min($FFFF, Round(SA * 65535.0));
        end;
        Dst.Colors[OX + X, OY + Y] := CR;
      end;
    Result := IntfToBitmap(Dst);
  finally
    Src.Free;
    Dst.Free;
  end;
end;

{ 透明の部分を白で塗った、24 ビットの TBitmap（jpg 用）。ASrc は 32 ビット }
function FlattenOnWhite(ASrc: TBitmap): TBitmap;
var
  Src: TLazIntfImage;
  Dst: TLazIntfImage;
  X, Y: Integer;
  C: TFPColor;
  A: Integer;
begin
  Src := BitmapToIntf(ASrc);
  Dst := NewIntf(ASrc.Width, ASrc.Height);
  try
    for Y := 0 to ASrc.Height - 1 do
      for X := 0 to ASrc.Width - 1 do
      begin
        C := Src.Colors[X, Y];
        A := C.Alpha;
        C.Red := (C.Red * A + $FFFF * ($FFFF - A)) div $FFFF;
        C.Green := (C.Green * A + $FFFF * ($FFFF - A)) div $FFFF;
        C.Blue := (C.Blue * A + $FFFF * ($FFFF - A)) div $FFFF;
        C.Alpha := $FFFF;
        Dst.Colors[X, Y] := C;
      end;
    Result := IntfToBitmap(Dst);
  finally
    Src.Free;
    Dst.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  保存
  --------------------------------------------------------------------------- }

procedure CXSaveBitmapToFile(ABitmap: TBitmap; const AFileName: string; AJpegQuality: Integer);
var
  Fmt: TCImageFormat;
  Dir: string;
  Mem: TMemoryStream;
  Bmp32, Work, Flat: TBitmap;
  Jpg: TJPEGImage;
  WriterPng: TLazWriterPNG;
  WriterTif: TFPWriterTiff;
  Intf: TLazIntfImage;
  Ico: TIcon;
  Fs: TFileStream;
  Ok: Boolean;
begin
  Fmt := FormatOfExt(ExtractFileExt(AFileName));
  if Fmt = cifSvg then
    raise ECImageError.Create(CXT(sImgSvgWrite));
  if Fmt = cifNone then
    raise ECImageError.CreateFmt(CXT(sImgUnsupported), [AFileName]);
  if (ABitmap = nil) or ABitmap.Empty or (ABitmap.Width <= 0) or (ABitmap.Height <= 0) then
    raise ECImageError.Create(CXT(sImgEmpty));

  Mem := TMemoryStream.Create;
  Bmp32 := nil; Work := nil; Flat := nil;
  try
    { 1. 変換して、メモリへ書く }
    try
      Bmp32 := ToBitmap32(ABitmap);
      case Fmt of
        cifBmp:
          Bmp32.SaveToStream(Mem);
        cifJpeg:
          begin
            Flat := FlattenOnWhite(Bmp32);
            Jpg := TJPEGImage.Create;
            try
              Jpg.Assign(Flat);
              Jpg.CompressionQuality := EnsureRange(AJpegQuality, 1, 100);
              Jpg.SaveToStream(Mem);
            finally
              Jpg.Free;
            end;
          end;
        cifPng:
          begin
            { TPortableNetworkGraphic.Assign はアルファを落とすので、アルファ付きのまま直接書く }
            WriterPng := TLazWriterPNG.Create;
            Intf := BitmapToIntf(Bmp32);
            try
              WriterPng.UseAlpha := True;
              WriterPng.WordSized := False;
              WriterPng.Indexed := False;
              WriterPng.GrayScale := False;
              WriterPng.ImageWrite(Mem, Intf);
            finally
              Intf.Free;
              WriterPng.Free;
            end;
          end;
        cifTiff:
          begin
            { TTiffImage は、アルファ付きで書くと、タグの順序が崩れる（FPC 3.2.2 の fpwritetiff）ので、直接書く }
            WriterTif := TFPWriterTiff.Create;
            Intf := BitmapToIntf(Bmp32);
            try
              WriterTif.ImageWrite(Mem, Intf);
            finally
              Intf.Free;
              WriterTif.Free;
            end;
          end;
        cifIcon:
          begin
            Work := Bmp32;
            if (Bmp32.Width > MAX_ICON_SIZE) or (Bmp32.Height > MAX_ICON_SIZE) then
            begin
              { 256 を超える絵は、縦横比を保って 256 以内に縮める }
              Work := FitBitmap(Bmp32,
                Min(MAX_ICON_SIZE, Max(1, Round(Bmp32.Width * Min(1.0, MAX_ICON_SIZE / Max(Bmp32.Width, Bmp32.Height))))),
                Min(MAX_ICON_SIZE, Max(1, Round(Bmp32.Height * Min(1.0, MAX_ICON_SIZE / Max(Bmp32.Width, Bmp32.Height))))));
            end;
            Ico := TIcon.Create;
            try
              Ico.Assign(Work);
              Ico.SaveToStream(Mem);
            finally
              Ico.Free;
            end;
          end;
      end;
    except
      on E: ECImageError do raise;
      on E: Exception do
        raise ECImageError.CreateFmt(CXT(sImgSaveFailed), [AFileName + ' (' + E.Message + ')']);
    end;

    { 2. 保存先のフォルダーが無ければ作る }
    Dir := ExtractFilePath(ExpandFileName(AFileName));
    if (Dir <> '') and not DirectoryExists(Dir) then
      if not ForceDirectories(Dir) then
        raise ECImageError.CreateFmt(CXT(sCapNoFolder), [Dir]);

    { 3. ファイルへ写す。失敗したら、書きかけのファイルを消す }
    Ok := False;
    Fs := nil;
    try
      Fs := CXCreateFileShared(AFileName);
      Mem.Position := 0;
      Fs.CopyFrom(Mem, Mem.Size);
      Ok := True;
    except
      on E: Exception do
        raise ECImageError.CreateFmt(CXT(sImgSaveFailed), [AFileName + ' (' + E.Message + ')']);
    end;
    Fs.Free;
    if not Ok then DeleteFile(AFileName);
  finally
    if (Work <> nil) and (Work <> Bmp32) then Work.Free;
    Bmp32.Free;
    Flat.Free;
    Mem.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  TCImage
  --------------------------------------------------------------------------- }

class function TCImage.FormatOfFile(const AFileName: string): TCImageFormat;
begin
  Result := FormatOfExt(ExtractFileExt(AFileName));
end;

class function TCImage.IsSupportedFile(const AFileName: string): Boolean;
begin
  Result := FormatOfFile(AFileName) <> cifNone;
end;

function TCImage.GetImageFormat: TCImageFormat;
var
  G: TGraphic;
begin
  G := Picture.Graphic;
  if (G = nil) or G.Empty then Result := cifNone
  else if G is TSVGGraphic then Result := cifSvg
  else if G is TJPEGImage then Result := cifJpeg
  else if G is TPortableNetworkGraphic then Result := cifPng
  else if G is TTiffImage then Result := cifTiff
  else if G is TIcon then Result := cifIcon
  else if G is TBitmap then Result := cifBmp
  else Result := cifNone;
end;

procedure TCImage.LoadFromFile(const AFileName: string);
var
  Tmp: TPicture;
begin
  if not IsSupportedFile(AFileName) then
    raise ECImageError.CreateFmt(CXT(sImgUnsupported), [AFileName]);
  { いったん別の TPicture に読む（失敗しても、今の絵を壊さない） }
  Tmp := TPicture.Create;
  try
    try
      Tmp.LoadFromFile(AFileName);
    except
      on E: Exception do
        raise ECImageError.CreateFmt(CXT(sImgLoadFailed), [AFileName + ' (' + E.Message + ')']);
    end;
    Picture.Assign(Tmp);
    FFileName := AFileName;
  finally
    Tmp.Free;
  end;
end;

procedure TCImage.SaveToFile(const AFileName: string; AJpegQuality: Integer);
var
  Bmp: TBitmap;
begin
  if FormatOfFile(AFileName) = cifSvg then
    raise ECImageError.Create(CXT(sImgSvgWrite));
  if (Picture.Graphic = nil) or Picture.Graphic.Empty then
    raise ECImageError.Create(CXT(sImgEmpty));
  Bmp := ToBitmap;
  try
    CXSaveBitmapToFile(Bmp, AFileName, AJpegQuality);
  finally
    Bmp.Free;
  end;
  FFileName := AFileName;
end;

procedure TCImage.LoadFromBitmap(ABitmap: TBitmap);
begin
  if ABitmap = nil then
    Picture.Clear
  else
    Picture.Bitmap.Assign(ABitmap);
  FFileName := '';
end;

function TCImage.ToBitmap: TBitmap;
begin
  if (Picture.Graphic = nil) or Picture.Graphic.Empty then
  begin
    Result := TBitmap.Create;
    Result.PixelFormat := pf32bit;
  end
  else
    Result := GraphicToBitmap(Picture.Graphic);
end;

{ ---------------------------------------------------------------------------
  TCImageList
  --------------------------------------------------------------------------- }

{ AGraphic を Width x Height に合わせて足す }
function AddGraphicFitted(AList: TCImageList; AGraphic: TGraphic): Integer;
var
  W, H: Integer;
  Sc: Double;
  Big, Fit: TBitmap;
begin
  Result := -1;
  if (AGraphic = nil) or AGraphic.Empty then
    raise ECImageError.Create(CXT(sImgEmpty));
  if (AGraphic is TRasterImage) and not (AGraphic is TIcon) then
  begin
    Big := GraphicToBitmap(AGraphic);
    try
      Fit := FitBitmap(Big, AList.Width, AList.Height);
    finally
      Big.Free;
    end;
  end
  else
  begin
    { svg・ico は、最初から目標の大きさで描く（縮小で荒れない） }
    W := AGraphic.Width;
    H := AGraphic.Height;
    if (W <= 0) or (H <= 0) then
    begin
      W := DEFAULT_SVG_SIZE;
      H := DEFAULT_SVG_SIZE;
    end;
    Sc := Min(AList.Width / W, AList.Height / H);
    W := Max(1, Round(W * Sc));
    H := Max(1, Round(H * Sc));
    Big := RenderGraphic(AGraphic, W, H);
    try
      Fit := FitBitmap(Big, AList.Width, AList.Height);
    finally
      Big.Free;
    end;
  end;
  try
    Result := AList.Add(Fit, nil);
  finally
    Fit.Free;
  end;
end;

function TCImageList.AddFromFile(const AFileName: string): Integer;
var
  Pic: TPicture;
begin
  if not TCImage.IsSupportedFile(AFileName) then
    raise ECImageError.CreateFmt(CXT(sImgUnsupported), [AFileName]);
  Pic := TPicture.Create;
  try
    try
      Pic.LoadFromFile(AFileName);
    except
      on E: Exception do
        raise ECImageError.CreateFmt(CXT(sImgLoadFailed), [AFileName + ' (' + E.Message + ')']);
    end;
    Result := AddGraphicFitted(Self, Pic.Graphic);
  finally
    Pic.Free;
  end;
end;

function TCImageList.AddFromImage(AImage: TCImage): Integer;
begin
  if (AImage = nil) or (AImage.Picture.Graphic = nil) or AImage.Picture.Graphic.Empty then
    raise ECImageError.Create(CXT(sImgEmpty));
  Result := AddGraphicFitted(Self, AImage.Picture.Graphic);
end;

function TCImageList.AddFromFolder(const AFolder: string; ARecursive: Boolean): Integer;
var
  Files: TStringList;

  procedure Collect(const ADir: string);
  var
    SR: TSearchRec;
    Sub, Here: TStringList;
    I: Integer;
    Base: string;
  begin
    Base := IncludeTrailingPathDelimiter(ADir);
    Sub := TStringList.Create;
    Here := TStringList.Create;
    try
      if FindFirst(Base + '*', faAnyFile, SR) = 0 then
      begin
        try
          repeat
            if (SR.Name = '.') or (SR.Name = '..') then Continue;
            if (SR.Attr and faDirectory) <> 0 then
            begin
              if ARecursive then Sub.Add(Base + SR.Name);
            end
            else if TCImage.IsSupportedFile(SR.Name) then
              Here.Add(Base + SR.Name);
          until FindNext(SR) <> 0;
        finally
          FindClose(SR);
        end;
      end;
      Here.Sort;
      Files.AddStrings(Here);
      Sub.Sort;
      for I := 0 to Sub.Count - 1 do
        Collect(Sub[I]);
    finally
      Here.Free;
      Sub.Free;
    end;
  end;

var
  I: Integer;
begin
  Result := 0;
  Files := TStringList.Create;
  try
    Files.CaseSensitive := False;
    Collect(AFolder);
    { フォルダーごとに、ファイル名順に足す（親のフォルダーのファイルが先） }
    for I := 0 to Files.Count - 1 do
      try
        AddFromFile(Files[I]);
        Inc(Result);
      except
        on E: ECImageError do ;   { 読めないファイルは飛ばす }
      end;
  finally
    Files.Free;
  end;
end;

procedure TCImageList.SaveItemToFile(AIndex: Integer; const AFileName: string);
var
  Bmp: TBitmap;
begin
  if (AIndex < 0) or (AIndex >= Count) then
    raise ECImageError.Create(CXT(sImgEmpty));
  Bmp := TBitmap.Create;
  try
    GetBitmap(AIndex, Bmp);
    CXSaveBitmapToFile(Bmp, AFileName);
  finally
    Bmp.Free;
  end;
end;

end.
