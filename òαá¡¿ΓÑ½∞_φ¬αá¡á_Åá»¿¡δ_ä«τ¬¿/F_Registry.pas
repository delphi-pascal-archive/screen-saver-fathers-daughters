unit F_Registry;

interface

uses
  Windows;

procedure RegWriteInteger(RegPath, Name: AnsiString; Value: DWORD);
function RegReadInteger(RegPath, Name: AnsiString): DWORD;

implementation

procedure RegWriteInteger(RegPath, Name: AnsiString; Value: DWORD);
var
  hReg: HKEY;
  hNew: HKEY;
begin
  if RegOpenKeyEx(HKEY_CURRENT_USER, 'Software', 0, KEY_WRITE, hReg) = ERROR_SUCCESS then
    begin
      try
        if RegCreateKeyEx(hReg, @RegPath[1], 0, nil, 0, KEY_WRITE, nil, hNew, nil) = ERROR_SUCCESS then
          RegSetValueEx(hNew, @Name[1], 0, REG_DWORD, @Value, sizeof(DWORD));
      finally
        RegCloseKey(hReg);
      end;
    end;
end;

function RegReadInteger(RegPath, Name: AnsiString): DWORD;
var
  hReg  : HKEY;
  Value : Integer;
  cbData: Integer;
  lpType: DWORD;
begin
  lpType := REG_DWORD;
  Value := 0;
  cbData := SizeOf(DWORD);
  if RegOpenKeyEx(HKEY_CURRENT_USER, @('Software\' + RegPath)[1], 0, KEY_READ, hReg) = ERROR_SUCCESS then
    begin
      try
        RegQueryValueEx(hReg, @Name[1], nil, @lpType, @Value, @cbData);
      finally
        RegCloseKey(hReg);
      end;
    end;
  Result := Value;
end;

end.