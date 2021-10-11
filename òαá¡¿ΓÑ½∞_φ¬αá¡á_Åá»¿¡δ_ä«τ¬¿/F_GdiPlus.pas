unit F_GdiPlus;

interface

uses
  Windows, F_IStream;

const
  gdiplus = 'gdiplus.dll';

type
  GDIPlusStartupInput = record
    GdiPlusVersion          : Integer;
    DebugEventCallback      : Integer;
    SuppressBackgroundThread: Integer;
    SuppressExternalCodecs  : Integer;
  end;

const
  SFA_DEFAULT                            = $00000000;
  SFA_LeftToRight                        = SFA_DEFAULT;
  SFA_RightToLeft                        = $00000001;
  SFA_DirectionVertical                  = $00000002;
  SFA_NoFitBlackBox                      = $00000004;
  SFA_DisplayFormatControl               = $00000020;
  SFA_FlagsNoFontFallback                = $00000400;
  SFA_MeasureTrailingSpaces              = $00000800;
  SFA_NoWrap                             = $00001000;
  SFA_LineLimit                          = $00002000;
  SFA_NoClip                             = $00004000;

type
  TStringFormatAttributes = SFA_DEFAULT .. SFA_NoClip;
  TGpStringFormat = Pointer;
  TGpFontFamily = Pointer;
  TGpFont     = Pointer;
  TGpFontCollection = Pointer;

const
  FS_Regular    = 0;
  FS_Bold       = 1;
  FS_Italic     = 2;
  FS_BoldItalic = 3;
  FS_Underline  = 4;
  FS_Strikeout  = 8;

type
  TFontStyle = FS_Regular .. FS_Strikeout;

type
  Unit_ = (
    gpUnitWorld,      // 0 -- World coordinate (non-physical unit)
    gpUnitDisplay,    // 1 -- Variable -- for PageTransform only
    gpUnitPixel,      // 2 -- Each unit is one device pixel.
    gpUnitPoint,      // 3 -- Each unit is a printer's point, or 1/72 inch.
    gpUnitInch,       // 4 -- Each unit is 1 inch.
    gpUnitDocument,   // 5 -- Each unit is 1/300 inch.
    gpUnitMillimeter  // 6 -- Each unit is 1 millimeter.
    );
  TUnit = Unit_;
  TGpUnit = TUnit;

const
  SA_Near   = 0;
  SA_Center = 1;
  SA_Far    = 2;

type
  TStringAlignment = SA_Near .. SA_Far;

type
  PGPRectF = ^TGPRectF;
  TGPRectF = packed record
    X     : Single;
    Y     : Single;
    Width : Single;
    Height: Single;
  end;

function GdiplusStartup(var token: Integer; var lpInput: GDIPlusStartupInput; lpOutput: Integer): Integer; stdcall; external gdiplus;
function GdiplusShutdown(var token: Integer): Integer; stdcall; external gdiplus;
function GdipCreateFromHDC(hDC: HDC; var Graphics: Cardinal): Integer; stdcall; external gdiplus;
function GdipLoadImageFromFile(FileName: PWideChar; var Image: Cardinal): Integer; stdcall; external gdiplus;
function GdipLoadImageFromStream(Stream: IStream; var Image: Cardinal): Integer; stdcall; external gdiplus;
function GdipGetImageWidth(Image: Cardinal; var Width: UINT): Integer; stdcall; external gdiplus;
function GdipGetImageHeight(Image: Cardinal; var Height: UINT): Integer; stdcall; external gdiplus;
function GdipDrawImageRect(Graphics: Cardinal; Image: Cardinal; X, Y, Width, Height: Single): Integer; stdcall; external gdiplus;
function GdipDisposeImage(Image: Cardinal): Integer; stdcall; external gdiplus;
function GdipDeleteGraphics(Graphics: Cardinal): Integer; stdcall; external gdiplus;

function GdipCreateStringFormat(StringFormatAttributes: TStringFormatAttributes; Language: LANGID; var StringFormat: TGpStringFormat): Integer; stdcall; external gdiplus;
function GdipCreateFontFamilyFromName(Font: PWideChar; Collection: TGpFontCollection; var FontFamily: TGpFontFamily): Integer; stdcall; external gdiplus;
function GdipCreateFont(FontFamily: TGpFontFamily; emSize: Single; FontStyle: TFontStyle; gpUnit: TGpUnit; var Font: TGpFont): Integer; stdcall; external gdiplus;
function GdipSetStringFormatLineAlign(StringFormat: TGpStringFormat; StringAlignment: TStringAlignment): Integer; stdcall; external gdiplus;

function GdipDeleteFont(Font: TGpFont): Integer; stdcall; external gdiplus;
function GdipDeleteFontFamily(FontFamily: TGpFontFamily): Integer; stdcall; external gdiplus;
function GdipDeleteStringFormat(StringFormat: TGpStringFormat): Integer; stdcall; external gdiplus;


var
  StartUpInfo: GDIPlusStartupInput;
  GdipToken  : Integer;

implementation

end.
