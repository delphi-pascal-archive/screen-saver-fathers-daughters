unit F_SysUtils;

interface

uses
  Windows, Messages;

function StrToInt(S: AnsiString): Integer;
function IntToStr(I: Integer): AnsiString;
function Format(szString: AnsiString; Params: Array of const): AnsiString;
procedure CenterDialogPos(hDialog, hParent: Thandle);

implementation

{}
function StrToInt(S: AnsiString): Integer;
var
  I : Integer;
begin
  Val(S, Result, I);
end;

{}
function IntToStr(I: Integer): AnsiString;
begin
  Str(I, Result);
end;

{}
function Format(szString: AnsiString; Params: Array of const): AnsiString;
var
  PDW1 : PDWORD;
  PDW2 : PDWORD;
  I    : Integer;
  PC   : PAnsiChar;
begin
  PDW1 := nil;
  if Length(Params) > 0 then
    GetMem(PDW1, Length(Params) * SizeOf(Pointer));
  PDW2 := PDW1;
  for I := 0 to High(Params) do
    begin
      PDW2^ := DWORD(PDWORD(@Params[I])^);
      Inc(PDW2);
    end;
  GetMem(PC, 1024 - 1);
  try
    SetString(Result, PC, wvsprintf(PC, PAnsiChar(szString), PAnsiChar(PDW1)));
  except
    Result := '';
  end;
  if (PDW1 <> nil) then
    FreeMem(PDW1);
  if (PC <> nil) then
    FreeMem(PC);
end;

procedure CenterDialogPos(hDialog, hParent: Thandle);
var
  DlgRC  : TRect;
  WndRC  : TRect;
  DesRC  : TRect;
  xLeft  : Integer;
  yTop   : Integer;
  wWidth : Integer;
  wHeight: Integer;
begin
  if (hDialog <> 0) then
    begin
      GetWindowRect(hDialog, DlgRC);
      GetWindowRect(hParent, WndRC);
      wWidth := DlgRC.Right - DlgRC.Left;
      wHeight := DlgRC.Bottom - DlgRC.Top;
      SystemParametersInfoW(SPI_GETWORKAREA, 0, @DesRC, 0);
      xLeft := WndRC.Left + ((WndRC.Right - WndRC.Left - wWidth) div 2);
      if xLeft < 0 then
        xLeft := 0
      else
        if xLeft + wWidth > (DesRC.Right - DesRC.Left) then
          xLeft := DesRC.Right - DesRC.Left - wWidth;
      yTop := WndRC.Top + ((WndRC.Bottom - WndRC.Top - wHeight) div 2);
      if yTop < 0 then
        yTop := 0
      else
        if yTop + wHeight > (DesRC.Bottom - DesRC.Top) then
          yTop := DesRC.Bottom - DesRC.Top - wHeight;
      SetWindowPos(hDialog, 0, xLeft, yTop, 0, 0, SWP_NOACTIVATE or SWP_NOSIZE or SWP_NOZORDER);
    end;
end;

end.