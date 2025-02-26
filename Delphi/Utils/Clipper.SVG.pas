 unit Clipper.SVG;

(*******************************************************************************
* Author    :  Angus Johnson                                                   *
* Version   :  Clipper2 - ver.1.0.4                                            *
* Date      :  6 September 2022                                                *
* Website   :  http://www.angusj.com                                           *
* Copyright :  Angus Johnson 2010-2022                                         *
* Purpose   :  This module provides a very simple SVG Writer for Clipper2      *
* License   :  http://www.boost.org/LICENSE_1_0.txt                            *
*******************************************************************************)

interface

{$I ..\Clipper2Lib\Clipper.inc}

uses
  Classes, SysUtils, Math, Clipper.Core, Clipper;

const
  black   = $FF000000;
  white   = $FFFFFFFF;
  maroon  = $FF800000;
  navy    = $FF000080;
  blue    = $FF0000FF;
  red     = $FFFF0000;
  green   = $FF008000;
  yellow  = $FFFFFF00;
  lime    = $FF00FF00;
  fuscia  = $FFFF00FF;
  aqua    = $FF00FFFF;

type

{$IFDEF RECORD_METHODS}
  TCoordStyle = record
{$ELSE}
  TCoordStyle = object
{$ENDIF}
    FontName: string;
    FontSize: integer;
    FontColor: cardinal;
    constructor Create(const afontname: string;
      afontsize: integer; afontcolor: Cardinal);
  end;

  TArrayOfString = array of string;

  PChartAxis = ^TChartAxis;
  TChartAxis = record
    caption: string;
    fontSize: integer;
    spaceNeeded: integer;
    horizontal: Boolean;
    ranges: TArrayOfInteger;
  end;

  PChartSeries = ^TChartSeries;
  TChartSeries = record
    caption: string;
    values: TPathD;
    color: Cardinal;
  end;

  PTextInfo = ^TTextInfo;
{$IFDEF RECORD_METHODS}
  TTextInfo = record
{$ELSE}
  TTextInfo = object
{$ENDIF}
    x,y : integer;
    text: string;
    fontSize: integer;
    fontColor: Cardinal;
    Bold: Boolean;
    constructor Create(atext: string; _x, _y: integer;
      afontsize: integer = 12;
      afontcolor: Cardinal = black;
      aBold: Boolean = false);
  end;

  PPolyInfo = ^TPolyInfo;
  TPolyInfo = record
    paths     : TPathsD;
    BrushClr  : Cardinal;
    PenClr    : Cardinal;
    PenWidth  : double;
    ShowCoords: Boolean;
    IsOpen    : Boolean;
    dashes    : TArrayOfInteger;
  end;

  PCircleInfo = ^TCircleInfo;
  TCircleInfo = record
    center    : TPointD;
    radius    : double;
    BrushClr  : Cardinal;
    PenClr    : Cardinal;
    PenWidth  : double;
  end;

  TSvgWriter = class
  private
    fFillRule   : TFillRule;
    fCoordStyle : TCoordStyle;
    fPolyInfos  : TList;
    fCircleInfos: TList;
    fTextInfos  : TList;
    fHorzAxis   : TChartAxis;
    fVertAxis   : TChartAxis;
    fChartSeries: TList;
    function GetBounds: TRectD;
  public
    constructor Create(fillRule: TFillRule;
      const coordFontName: string = 'Verdana';
      coordFontSize: integer = 9;
      coordFontColor: Cardinal = black);
    destructor Destroy; override;

    procedure AddPath(const path: TPath64; isOpen: Boolean;
      brushColor, penColor: Cardinal;
      penWidth: double; showCoords: Boolean = false);

    procedure AddPaths(const paths: TPaths64; isOpen: Boolean;
      brushColor, penColor: Cardinal;
      penWidth: double; showCoords: Boolean = false); overload;

    procedure AddPaths(const paths: TPathsD; isOpen: Boolean;
      brushColor, penColor: Cardinal;
      penWidth: double; showCoords: Boolean = false); overload;
    procedure AddDashedPath(const paths: TPathsD; penColor: Cardinal;
      penWidth: double; const dashes: TArrayOfInteger);

    procedure AddArrow(const center: TPointD;
      radius: double; angleRad: double;
      brushColor, penColor: Cardinal;
      penWidth: double); overload;

    procedure AddCircle(const center: TPoint64; radius: double;
      brushColor, penColor: Cardinal; penWidth: double); overload;
    procedure AddCircle(const center: TPointD; radius: double;
      brushColor, penColor: Cardinal; penWidth: double); overload;
    procedure AddText(text: string; x,y: integer;
      fontSize: integer = 14; fontClr:
      Cardinal = black; bold: Boolean = false);

    procedure AddChartAxis(const caption: string;
      fontSize: integer; isHorizontal: Boolean;
      spaceNeeded: integer; const ranges: TArrayOfInteger);
    procedure AddChartSeries(const caption: string; color: Cardinal;
      const values: TPathD);

    function SaveToFile(const filename: string;
      maxWidth: integer = 0; maxHeight: integer = 0;
      margin: integer = 20): Boolean;
    procedure ClearPaths;
    procedure ClearText;
    procedure ClearChart;
    procedure ClearAll;
  end;

  procedure AddSubject(svg: TSvgWriter; const paths: TPaths64); overload;
  procedure AddOpenSubject(svg: TSvgWriter; const paths: TPaths64); overload;
  procedure AddClip(svg: TSvgWriter; const paths: TPaths64); overload;
  procedure AddSolution(svg: TSvgWriter; const paths: TPaths64; showCoords: Boolean = false); overload;
  procedure AddOpenSolution(svg: TSvgWriter; const paths: TPaths64); overload;
  procedure SaveSvg(svg: TSvgWriter; const filename: string;
    width: integer = 0; height: integer = 0; margin: integer = 0); overload;

  procedure AddSubject(svg: TSvgWriter; const paths: TPathsD); overload;
  procedure AddOpenSubject(svg: TSvgWriter; const paths: TPathsD); overload;
  procedure AddClip(svg: TSvgWriter; const paths: TPathsD); overload;
  procedure AddSolution(svg: TSvgWriter; const paths: TPathsD; showCoords: Boolean= false); overload;
  procedure AddOpenSolution(svg: TSvgWriter; const paths: TPathsD); overload;

implementation

const
  MaxRect: TRectD  = (left: MaxDouble;
    Top: MaxDouble; Right: -MaxDouble; Bottom: -MaxDouble);

  svg_header: string =
      '<svg width="%dpx" height="%dpx" viewBox="0 0 %0:d %1:d" ' +
      'version="1.1" xmlns="http://www.w3.org/2000/svg">';
  svg_path_format: string = '"'+#10+'    style="fill:%s;' +
        ' fill-opacity:%1.2f; fill-rule:%s; stroke:%s;' +
        ' stroke-opacity:%1.2f; stroke-width:%1.2f;"/>'#10;
  svg_path_format2: string = '"'+#10+
        '   style="fill:none; stroke:%s; ' +
        'stroke-opacity:%1.2f; stroke-width:%1.2f; %s"/>'#10;

function ColorToHtml(color: Cardinal): string;
begin
  Result := Format('#%6.6x', [color and $FFFFFF]);;
end;

function GetAlpha(clr: Cardinal): double;
begin
  Result := (clr shr 24) / 255;
end;

constructor TCoordStyle.Create(const afontname: string;
  afontsize: integer; afontcolor: Cardinal);
begin
  Self.FontName   := afontname;
  Self.FontSize   := afontsize;
  Self.FontColor  := afontcolor;
end;

constructor TTextInfo.Create(atext: string; _x, _y: integer;
  afontsize: integer = 12; afontcolor: Cardinal = black;
  aBold: Boolean = false);
begin
  self.x := _x;
  self.y := _y;
  self.text := text;
  self.fontSize := afontsize;
  self.fontColor := afontcolor;
  Self.Bold       := aBold;
end;

constructor TSvgWriter.Create(fillRule: TFillRule;
  const coordFontName: string = 'Verdana';
  coordFontSize: integer = 9;
  coordFontColor: Cardinal = black);
begin
  fFillRule := fillRule;
  fCoordStyle.FontName := coordFontName;
  fCoordStyle.FontSize := coordFontSize;
  fCoordStyle.FontColor := coordFontColor;
  fPolyInfos := TList.Create;
  fCircleInfos := TList.Create;
  fTextInfos := TList.Create;
  fChartSeries := TList.Create;
end;

destructor TSvgWriter.Destroy;
begin
  ClearAll;
  fPolyInfos.Free;
  fCircleInfos.Free;
  fTextInfos.Free;
  fChartSeries.Free;
  inherited;
end;

procedure TSvgWriter.AddPath(const path: TPath64; isOpen: Boolean;
  brushColor, penColor: Cardinal;
  penWidth: double; showCoords: Boolean);
begin
  AddPaths(Paths64(path), isOpen, brushColor, penColor, penWidth, showCoords);
end;

procedure TSvgWriter.AddPaths(const paths: TPaths64;
  isOpen: Boolean; brushColor, penColor: Cardinal;
  penWidth: double; showCoords: Boolean = false);
var
  pi: PPolyInfo;
begin
  if Length(paths) = 0 then Exit;
  new(pi);
  pi.paths := PathsD(paths);
  pi.BrushClr := brushColor;
  pi.PenClr   := penColor;
  pi.PenWidth := penWidth;
  pi.ShowCoords := showCoords;
  pi.IsOpen := isOpen;
  fPolyInfos.Add(pi);
end;

procedure TSvgWriter.AddPaths(const paths: TPathsD; isOpen: Boolean;
  brushColor, penColor: Cardinal;
  penWidth: double; showCoords: Boolean = false);
var
  pi: PPolyInfo;
begin
  new(pi);
  pi.paths := Copy(paths, 0, Length(paths));
  pi.BrushClr := brushColor;
  pi.PenClr   := penColor;
  pi.PenWidth := penWidth;
  pi.ShowCoords := showCoords;
  pi.IsOpen := isOpen;
  fPolyInfos.Add(pi);
end;

procedure TSvgWriter.AddDashedPath(const paths: TPathsD;
  penColor: Cardinal; penWidth: double; const dashes: TArrayOfInteger);
var
  pi: PPolyInfo;
begin
  new(pi);
  pi.paths := Copy(paths, 0, Length(paths));
  pi.BrushClr := 0;
  pi.PenClr   := penColor;
  pi.PenWidth := penWidth;
  pi.ShowCoords := false;
  pi.IsOpen := true;
  pi.dashes := Copy(dashes, 0, Length(dashes));
  fPolyInfos.Add(pi);
end;

procedure TSvgWriter.AddArrow(const center: TPointD;
  radius: double; angleRad: double; brushColor, penColor: Cardinal;
  penWidth: double);
var
  pp: TPathsD;
  s,c: double;
begin
  SetLength(pp, 1);
  with center do
    pp[0] := Ellipse(RectD(X - radius * 1.2, Y - radius * 0.9,
      X + radius * 1.2, Y + radius * 0.9), 3);
  if angleRad <> 0 then
  begin
    GetSinCos(angleRad, s,c);
    RotatePath(pp[0], center, s, c);
  end;
  AddPaths(pp, false, brushColor, penColor, penWidth);
end;

procedure TSvgWriter.AddCircle(const center: TPoint64;
  radius: double; brushColor, penColor: Cardinal; penWidth: double);
var
  ci: PCircleInfo;
begin
  new(ci);
  ci.center := PointD(center);
  ci.radius := radius;
  ci.BrushClr := brushColor;
  ci.PenClr   := penColor;
  ci.PenWidth := penWidth;
  fCircleInfos.Add(ci);
end;

procedure TSvgWriter.AddCircle(const center: TPointD;
  radius: double; brushColor, penColor: Cardinal; penWidth: double);
var
  ci: PCircleInfo;
begin
  new(ci);
  ci.center := center;
  ci.radius := radius;
  ci.BrushClr := brushColor;
  ci.PenClr   := penColor;
  ci.PenWidth := penWidth;
  fCircleInfos.Add(ci);
end;

procedure TSvgWriter.AddText(text: string; x,y: integer;
  fontSize: integer; fontClr: Cardinal; bold: Boolean);
var
  ti: PTextInfo;
begin
  new(ti);
  ti.x := x;
  ti.y := y;
  ti.text := text;
  ti.fontSize := fontSize;
  ti.fontColor := fontClr;
  ti.Bold := bold;
  fTextInfos.Add(ti);
end;

procedure TSvgWriter.AddChartAxis(const caption: string;
  fontSize: integer; isHorizontal: Boolean;
  spaceNeeded: integer; const ranges: TArrayOfInteger);
var
  axis: PChartAxis;
begin
  if spaceNeeded <= 0 then Exit;
  if isHorizontal then
    axis := @fHorzAxis else
    axis := @fVertAxis;
  axis.caption := caption;
  axis.fontSize := fontSize;
  axis.spaceNeeded := spaceNeeded;
  axis.ranges := ranges;
end;

procedure TSvgWriter.AddChartSeries(const caption: string; color: Cardinal;
  const values: TPathD);
var
  series: PChartSeries;
begin
  new(series);
  fChartSeries.Add(series);
  series.caption := caption;
  series.color := color;
  series.values := values;
end;

function TSvgWriter.GetBounds: TRectD;
var
  i: integer;
  bounds: TRectD;
begin
  Result := MaxRect;
  for i := 0 to fPolyInfos.Count -1 do
    with PPolyInfo(fPolyInfos[i])^ do
    begin
      bounds := Clipper.Core.GetBounds(paths);
      if (bounds.left < Result.Left) then Result.Left := bounds.Left;
      if (bounds.right> Result.Right) then Result.Right := bounds.Right;
      if (bounds.top < Result.Top) then Result.Top := bounds.Top;
      if (bounds.bottom > Result.Bottom) then Result.Bottom := bounds.Bottom;
    end;
  for i := 0 to fChartSeries.Count -1 do
    with PChartSeries(fChartSeries[i])^ do
    begin
      bounds := Clipper.Core.GetBounds(values);
      if (bounds.left < Result.Left) then Result.Left := bounds.Left;
      if (bounds.right> Result.Right) then Result.Right := bounds.Right;
      if (bounds.top < Result.Top) then Result.Top := bounds.Top;
      if (bounds.bottom > Result.Bottom) then Result.Bottom := bounds.Bottom;
    end;
end;

procedure TSvgWriter.ClearPaths;
var
  i: integer;
begin
  for i := 0 to fPolyInfos.Count -1 do
    Dispose(PPolyInfo(fPolyInfos[i]));
  fPolyInfos.Clear;

  for i := 0 to fCircleInfos.Count -1 do
    Dispose(PCircleInfo(fCircleInfos[i]));
  fCircleInfos.Clear;
end;

procedure TSvgWriter.ClearText;
var
  i: integer;
begin
  for i := 0 to fTextInfos.Count -1 do
    Dispose(PTextInfo(fTextInfos[i]));
  fTextInfos.Clear;
end;

procedure TSvgWriter.ClearChart;
var
  i: integer;
begin
  fHorzAxis.spaceNeeded := 0;
  fVertAxis.spaceNeeded := 0;
  for i := 0 to fChartSeries.Count -1 do
    Dispose(PChartSeries(fChartSeries[i]));
  fChartSeries.Clear;
end;

procedure TSvgWriter.ClearAll;
begin
  ClearText;
  ClearChart;
  ClearPaths;
end;

function TSvgWriter.SaveToFile(const filename: string;
  maxWidth: integer = 0; maxHeight: integer = 0; margin: integer = 20): Boolean;
var
  i,j,k, len1, len2: integer;
  x,y,x2,y2,delta: double;
  bounds: TRectD;
  scale, scaleX, scaleY: double;
  offsetX, offsetY: integer;
  s, sInline, dashStr: string;
  sl: TStringList;
  formatSettings: TFormatSettings;
const
  fillRuleStr: array[boolean] of string = ('evenodd', 'nonzero');
  boldFont: array[boolean] of string = ('normal', '700');
  gap: integer = 5;

  procedure Add(const s: string);
  begin
    sl.Add( sInline + s);
    sInline := '';
  end;

  procedure AddInline(const s: string);
  begin
    sInline := sInline + s;
  end;

begin
  formatSettings := TFormatSettings.Create;
  formatSettings.DecimalSeparator := '.';

  Result := false;
  if (margin < 20) then margin := 20;
  bounds := GetBounds;
  if bounds.IsEmpty then Exit;

  scale := 1.0;
  if (maxWidth > 0) and (maxHeight > 0) then
    scale := 1.0 / Max((bounds.right - bounds.left) /
      (maxWidth - margin * 2), (bounds.bottom - bounds.top) /
      (maxHeight - margin * 2));

  offsetX := margin - Round(bounds.left * scale);
  offsetY := margin - Round(bounds.top * scale);

  sl := TStringList.Create;
  try
    if (maxWidth <= 0) or (maxHeight <= 0) then
       Add(Format(svg_header,
       [Round(bounds.right - bounds.left) + margin * 2,
        Round(bounds.bottom - bounds.top) + margin * 2], formatSettings))
    else
      Add(Format(svg_header, [maxWidth, maxHeight], formatSettings));

    for i := 0 to fPolyInfos.Count -1 do
      with PPolyInfo(fPolyInfos[i])^ do
      begin
        AddInline('  <path d="');
        for j := 0 to High(paths) do
        begin
          if Length(paths[j]) < 2 then Continue;
          if not IsOpen and (Length(paths[j]) < 3) then Continue;
          AddInline(Format('M %1.2f %1.2f L ',
            [paths[j][0].x * scale + offsetX,
            paths[j][0].y * scale + offsetY], formatSettings));
          for k := 1 to High(paths[j]) do
            AddInline(Format('%1.2f %1.2f ',
              [paths[j][k].x * scale + offsetX,
              paths[j][k].y * scale + offsetY], formatSettings));
          if not IsOpen then AddInline('Z');
        end;

        if not IsOpen then
          Add(Format(svg_path_format,
            [ColorToHtml(BrushClr), GetAlpha(BrushClr),
            fillRuleStr[fFillRule = frNonZero],
            ColorToHtml(PenClr), GetAlpha(PenClr), PenWidth], formatSettings))
        else
        begin
          dashStr := '';;
          if Length(dashes) > 0 then
          begin
            s := '';
            for k := 0 to High(dashes) do
              s := s + IntToStr(dashes[k]) + ' ';
            dashStr := 'stroke-dasharray: ' + s + ';';
          end;
          Add(Format(svg_path_format2,
              [ColorToHtml(PenClr), GetAlpha(PenClr),
              PenWidth, dashStr], formatSettings));
        end;

        if (ShowCoords) then
        begin
          with fCoordStyle do
            Add(Format('<g font-family="%s" font-size="%d" fill="%s">',
              [FontName, FontSize, ColorToHtml(FontColor)], formatSettings));
          for j := 0 to High(paths) do
            for k := 0 to High(paths[j]) do
              with paths[j][k] do
                Add(Format('  <text x="%1.2f" y="%1.2f">%1.0f,%1.0f</text>',
                  [x * scale + offsetX, y * scale + offsetY, x, y],
                  formatSettings));
          Add('</g>'#10);
        end;
      end;

      for i := 0 to fCircleInfos.Count -1 do
        with PCircleInfo(fCircleInfos[i])^ do
        begin
          if GetAlpha(BrushClr) > 0.1 then
            Add(Format('  <circle cx="%1.2f" cy="%1.2f" r="%1.2f" '+
              'stroke="%s" stroke-width="%1.2f" '+
              'fill="%s" opacity="%1.2f" />',
              [center.X * scale + offsetX, center.Y * scale + offsetY,
              radius, ColorToHtml(PenClr), PenWidth,
              ColorToHtml(BrushClr), GetAlpha(BrushClr)], formatSettings))
          else
            Add(Format('  <circle cx="%1.2f" cy="%1.2f" r="%1.2f" '+
              'stroke="%s" stroke-width="%1.2f" '+
              'fill="none" opacity="%1.2f" />',
              [center.X * scale + offsetX, center.Y * scale + offsetY,
              radius, ColorToHtml(PenClr), PenWidth,
              GetAlpha(PenClr)], formatSettings));
        end;

    for i := 0 to fTextInfos.Count -1 do
      with PTextInfo(fTextInfos[i])^ do
      begin
            Add(Format(
            '  <g font-family="Verdana" font-style="normal" ' +
            'font-weight="%s" font-size="%d" fill="%s">' +
            '<text x="%1.2f" y="%1.2f">%s</text></g>',
            [boldFont[Bold], Round(fontSize * scale),
            ColorToHtml(fontColor),
            (x) * scale + offsetX,
            (y) * scale + offsetY, text], formatSettings));
      end;


    len1 := Length(fHorzAxis.ranges);
    len2 := Length(fVertAxis.ranges);
    if (len1 > 0) and (len2 > 0) then
    begin
      x2 := fHorzAxis.ranges[0];
      y2 := fVertAxis.ranges[0];
      scaleX := (maxWidth - fVertAxis.spaceNeeded) * ((len1-1)/(len1)) /
        (fHorzAxis.ranges[len1-1]-fHorzAxis.ranges[0]);
      scaleY := (maxHeight - fHorzAxis.spaceNeeded) * ((len2-1)/len2) /
        (fVertAxis.ranges[len2-1]-fVertAxis.ranges[0]);
      offsetX := fVertAxis.spaceNeeded;
      offsetY := (maxHeight - fHorzAxis.spaceNeeded);

      AddInline('  <path d="');
      AddInline(Format('M %d %d L ',
        [fVertAxis.spaceNeeded, 10], formatSettings));
      AddInline(Format('%d %d ',
        [fVertAxis.spaceNeeded, maxHeight - fHorzAxis.spaceNeeded], formatSettings));
      AddInline(Format('%d %d ',
        [maxWidth -10, maxHeight - fHorzAxis.spaceNeeded], formatSettings));
      Add('"' +#10+ '   style="fill:none; stroke:black; ' +
        'stroke-width:1.2;"/>'+#10);

      x := fVertAxis.spaceNeeded;
      y := maxHeight - fHorzAxis.spaceNeeded + fHorzAxis.fontSize + gap;
      delta := (maxWidth -fVertAxis.spaceNeeded) / len1;
      for i := 0 to len1 -1 do
        begin
          Add(Format(
          '  <g font-family="Verdana" font-style="normal" ' +
          'font-size="%d" fill="black">' +
          '<text text-anchor="middle" x="%1.2f" y="%1.2f">%d</text></g>',
          [fHorzAxis.fontSize, x, y,
            fHorzAxis.ranges[i] ], formatSettings));
          Add(Format('  <circle cx="%1.2f" cy="%1.2f" r="2.0" '+
            'stroke="none" fill="black" />',
            [ x, 1.0 * maxHeight - fHorzAxis.spaceNeeded], formatSettings));
          x := x + delta;
        end;

      x := fVertAxis.spaceNeeded - gap;
      delta := (maxHeight -fHorzAxis.spaceNeeded) / len2;

      y := maxHeight - fHorzAxis.spaceNeeded;
      for i := 0 to len1 -1 do
        begin
          Add(Format(
          '  <g font-family="Verdana" font-style="normal" ' +
          'font-size="%d" fill="black">' +
          '<text text-anchor="end" x="%1.2f" y="%1.2f">%d</text></g>',
          [fVertAxis.fontSize, x, y,
            fVertAxis.ranges[i] ], formatSettings));
          Add(Format('  <circle cx="%d" cy="%1.0f" r="2.0" '+
            'stroke="none" fill="black" />',
            [ fVertAxis.spaceNeeded, y], formatSettings));
          y := y - delta;
        end;


      for i := 0 to fChartSeries.Count -1 do
        with PChartSeries(fChartSeries[i])^ do
        begin
          AddInline('  <path d="');
          AddInline(Format('M %1.2f %1.2f L ',
            [(values[0].X -x2) * scaleX + offsetX,
            (y2 - values[0].Y) * scaleY + offsetY], formatSettings));
          for j := 1 to High(values) do
            AddInline(Format('%1.2f %1.2f ',
              [(values[j].X -x2) * scaleX + offsetX,
              (y2 - values[j].Y) * scaleY + offsetY], formatSettings));
            Add(Format(svg_path_format2,
                [ColorToHtml(color), GetAlpha(color),
                2.2, ''], formatSettings));

          for j := 0 to High(values) do
            Add(Format('  <circle cx="%1.2f" cy="%1.2f" r="%1.2f" '+
              'stroke="none" fill="%s" opacity="%1.2f" />',
              [ values[j].X * scaleX + offsetX,
                y2 - values[j].Y * scaleY + offsetY,
                5.0, ColorToHtml(color), GetAlpha(color) ], formatSettings));
        end;
    end;

    Add('</svg>'#10);
    sl.SaveToFile(filename);
    Result := true;
  finally
    sl.free;
  end;
end;


procedure AddSubject(svg: TSvgWriter; const paths: TPaths64);
begin
  svg.AddPaths(paths, false, $200099FF, $800066FF, 1.0);
end;

procedure AddOpenSubject(svg: TSvgWriter; const paths: TPaths64);
begin
  svg.AddPaths(paths, true, $0, $800066FF, 2.2);
end;

procedure AddClip(svg: TSvgWriter; const paths: TPaths64);
begin
  svg.AddPaths(paths, false, $10FF9900, $80FF6600, 1.0);
end;

procedure AddSolution(svg: TSvgWriter; const paths: TPaths64; showCoords: Boolean);
begin
  svg.AddPaths(paths, false, $8066FF66, $FF006600, 1.5, showCoords);
  //svg.AddPaths(paths, false, $8066FF66, $FF006600, 1.5, showCoords);
end;

procedure AddOpenSolution(svg: TSvgWriter; const paths: TPaths64);
begin
  svg.AddPaths(paths, true, $0, $FF006600, 1.5);
end;

procedure SaveSvg(svg: TSvgWriter; const filename: string;
  width: integer = 0; height: integer = 0; margin: integer = 0);
begin
  svg.SaveToFile(filename, width, height, margin);
end;

procedure AddSubject(svg: TSvgWriter; const paths: TPathsD);
begin
  svg.AddPaths(paths, false, $200099FF, $800066FF, 1.0);
end;

procedure AddOpenSubject(svg: TSvgWriter; const paths: TPathsD);
begin
  svg.AddPaths(paths, true, $0, $400066FF, 2.2);
end;

procedure AddClip(svg: TSvgWriter; const paths: TPathsD);
begin
  svg.AddPaths(paths, false, $10FF9900, $80FF6600, 1.0);
end;

procedure AddSolution(svg: TSvgWriter; const paths: TPathsD; showCoords: Boolean);
begin
  svg.AddPaths(paths, false, $8066FF66, $FF006600, 1.5, showCoords);
end;

procedure AddOpenSolution(svg: TSvgWriter; const paths: TPathsD);
begin
  svg.AddPaths(paths, true, $0, $FF006600, 1.5);
end;

end.

