program Project;

{$R Project.res}
{$E scr}

uses
  Windows, Messages, CommCtrl, F_GdiPlus, F_IStream, F_SysUtils, F_CommCtrl,
  F_Registry;

const
  WndClassName  = 'Screen Saver Class';
  WndClassApp   = 'Screen Saver';
  RC_DRAW_IMAGE = 101;
  RC_DRAW_DIALG = 101;
  RC_DRAW_ICOND = 101;
  ID_DRAW_TRACK = 101;
  ID_BLEND_EDIT = 102;
  ID_DRAW_TIMER = 100;
  ID_UEDIT_SNOW = 103;
  ID_UPDWN_SNOW = 104;
  ID_UEDIT_WIND = 105;
  ID_UPDWN_WIND = 106;

type
  TscrMode = (scrStart, scrPreview, scrConfig);
  MyTPoint = record
  XcurPoint: Integer;
  YcurPoint: Integer;
  CrazySnow: Integer;
  lastColor: COLORREF;
  SpeedSnow: Byte;
end;

var
  hSaver   : Thandle;
  hParams  : Thandle;
  hDialog  : Thandle;
  hParent  : Thandle;
  WndClass : TWndClass;
  uMsg     : TMsg;
  scrMode  : TscrMode;
  lpRect   : TRect;
  stPoint  : TPoint;
  Counter  : Integer;
  lpPoint  : TPoint;
  PaintStr : PAINTSTRUCT;
  //
  resHandle: Cardinal;
  resSize  : Cardinal;
  hBuffer  : Cardinal;
  presData : Pointer;
  pBuffer  : Pointer;
  rIStream : IStream;
  loadRes  : HGLOBAL;
  //
  Graphics : Cardinal;
  GdiImage : Cardinal;
  iHeight  : UINT;
  iWidth   : UINT;

  hMemHdc  : HDC;
  hBmpNew  : THandle;
  hBmpOld  : THandle;

  _hMemHdc_: HDC;
  _hBmpNew_: THandle;
  _hBmpOld_: THandle;

  DrawThrd : Cardinal;
  DrawThrID: LongWord;

  MyPoints : Array of MyTPoint;
  Snow_Clr : COLORREF;
  IndexSnow: Integer;
//
  BlendVal : Integer;
  FirstRun : Integer;
  SnowVal  : Integer;
  SpeedVal : Integer;

  hAppIcon : hIcon;

function SetgDlgProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  GetValue: Integer;
  SetValue: AnsiString;
begin
  Result := 0;
  case uMsg of
    {}
    WM_INITDIALOG:
      begin
        hParams := hWnd;
        if hAppIcon <> 0 then
          SendMessageW(hParams, WM_SETICON, ICON_SMALL, hAppIcon);
        SendMessage(GetDlgItem(hParams, ID_DRAW_TRACK), TBM_SETRANGE, Integer(TRUE), MAKELONG(0, 100));
        SendMessage(GetDlgItem(hParams, ID_DRAW_TRACK), TBM_SETPAGESIZE, 0, 0);
        SendMessage(GetDlgItem(hParams, ID_DRAW_TRACK), TBM_SETTICFREQ, 5, 0);
        SendMessage(GetDlgItem(hParams, ID_DRAW_TRACK), TBM_SETPOS, Integer(TRUE), BlendVal);
        SetValue := IntToStr(BlendVal);
        SendMessage(GetDlgItem(hParams, ID_BLEND_EDIT), WM_SETTEXT, 0, Integer(PAnsiChar(SetValue)));
        { минимальное и максимальное значения }
        SendMessage(GetDlgItem(hParams, ID_UPDWN_SNOW), UDM_SETRANGE, 0, MAKELONG(2500, 0));
        { начальная позиция шкалы }
        SendMessage(GetDlgItem(hParams, ID_UPDWN_SNOW), UDM_SETPOS, 0, MAKELONG(SnowVal, 0));
        { минимальное и максимальное значения }
        SendMessage(GetDlgItem(hParams, ID_UPDWN_WIND), UDM_SETRANGE, 0, MAKELONG(10, 1));
        { начальная позиция шкалы }
        SendMessage(GetDlgItem(hParams, ID_UPDWN_WIND), UDM_SETPOS, 0, MAKELONG(SpeedVal, 0));
        CenterDialogPos(hParams, hSaver);
      end;
    {}
    WM_COMMAND:
      begin
        case LoWord(wParam) of
          ID_OK:
            begin
              GetValue := SendMessage(GetDlgItem(hParams, ID_DRAW_TRACK), TBM_GETPOS, 0, 0);
              RegWriteInteger(WndClassApp, 'BlendValue', GetValue);
              SnowVal := SendMessage(GetDlgItem(hParams, ID_UPDWN_SNOW), UDM_GETPOS, 0, 0);
              RegWriteInteger(WndClassApp, 'SnowValue', SnowVal);
              SpeedVal := SendMessage(GetDlgItem(hParams, ID_UPDWN_WIND), UDM_GETPOS, 0, 0);
              RegWriteInteger(WndClassApp, 'SpeedValue', SpeedVal);
              PostMessage(hParams, WM_CLOSE, 0, 0);
            end;
          ID_CANCEL:
            PostMessage(hParams, WM_CLOSE, 0, 0);
        end;
      end;
    {}
     WM_HSCROLL:
       begin
         case LoWord(wParam) of
           TB_TOP, TB_BOTTOM, TB_LINEUP, TB_LINEDOWN, TB_PAGEUP, TB_PAGEDOWN, TB_ENDTRACK, TB_THUMBPOSITION, TB_THUMBTRACK :
             begin
               GetValue := SendMessage(GetDlgItem(hParams, ID_DRAW_TRACK), TBM_GETPOS, 0, 0);
               SetValue := IntToStr(GetValue);
               SendMessage(GetDlgItem(hParams, ID_BLEND_EDIT), WM_SETTEXT, 0, Integer(PAnsiChar(SetValue)));
             end;
           end;
       end;
    {}
    WM_ACTIVATE:
      SetWindowPos(hParams, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_SHOWWINDOW);
    {}
    WM_CLOSE, WM_DESTROY:
      EndDialog(hParams, 0);
  end;
end;

function IsContrast(Color1, Color2: COLORREF): Boolean;
var
  r1: Byte;
  g1: Byte;
  b1: Byte;
  r2: Byte;
  g2: Byte;
  b2: Byte;
begin
  Result := FALSE;
  r1 := GetRValue(Color1);
  g1 := GetGValue(Color1);
  b1 := GetBValue(Color1);
  r2 := GetRValue(Color2);
  g2 := GetGValue(Color2);
  b2 := GetBValue(Color2);
  if ((r1 - r2) + (g1 - g2) + (b1 - b2)) > 100 then
    Result := TRUE;
end;

procedure PaintSnow(PaintHDC: HDC);
var
  i        : Integer;
  x        : Integer;
  y        : Integer;
  color_1  : COLORREF;
  color_2  : COLORREF;
  down_snow: Byte;
begin
  case 2 - random(2) of
  1:
    Inc(SpeedVal);
  2:
    Dec(SpeedVal);
  end;
  if SpeedVal > 5 then
    Dec(SpeedVal);
  if SpeedVal <- 5 then
    Inc(SpeedVal);
  for i := 0 to High(MyPoints) do
    begin
      x := MyPoints[i].XcurPoint + MyPoints[i].CrazySnow + SpeedVal;
      y := MyPoints[i].YcurPoint + 1 + MyPoints[i].SpeedSnow;
      if (y > iHeight) then
        y := 1;
      if (x > iWidth) then
        x := 1;
      if (x < 0) then
        x := iWidth;
      color_1 := GetPixel(PaintHDC, x, y);
      color_2 := GetPixel(PaintHDC, x, y + 1);
      if (IsContrast(color_1, color_2)) and (color_1 <> Snow_Clr) then
        begin
          down_snow := Random(1);
          MyPoints[i].YcurPoint := MyPoints[i].YcurPoint + down_snow;
          MyPoints[i].XcurPoint := MyPoints[i].XcurPoint;
          case (Random(2)) of
            1:
              SetPixelV(PaintHDC, MyPoints[i].XcurPoint, MyPoints[i].YcurPoint, Snow_Clr);
            2:
              begin
                SetPixelV(PaintHDC, MyPoints[i].XcurPoint - 1, MyPoints[i].YcurPoint, Snow_Clr);
                SetPixelV(PaintHDC, MyPoints[i].XcurPoint, MyPoints[i].YcurPoint, Snow_Clr);
              end;
            0:
              begin
                MyPoints[i].YcurPoint := MyPoints[i].YcurPoint - Random(3);
                SetPixelV(PaintHDC, MyPoints[i].XcurPoint + 1, MyPoints[i].YcurPoint + 1, Snow_Clr);
                SetPixelV(PaintHDC, MyPoints[i].XcurPoint, MyPoints[i].YcurPoint, Snow_Clr);
                SetPixelV(PaintHDC, MyPoints[i].XcurPoint - 1, MyPoints[i].YcurPoint + 1, Snow_Clr);
              end;
          end;
          y := Random(iHeight div 4);
        end
      else
        begin
          if GetPixel(PaintHDC, MyPoints[i].XcurPoint, MyPoints[i].YcurPoint) = Snow_Clr then
            SetPixelV(PaintHDC, MyPoints[i].XcurPoint, MyPoints[i].YcurPoint, MyPoints[i].lastColor);
          MyPoints[i].lastColor := GetPixel(PaintHDC, x, y);
          SetPixelV(PaintHDC, x, y, Snow_Clr);
        end;
      MyPoints[i].XcurPoint := x;
      MyPoints[i].YcurPoint := y;
      MyPoints[i].CrazySnow := - MyPoints[i].CrazySnow;
    end;
end;

function PaintThreadFunc(Data: Pointer): DWORD; stdcall;
begin
  Result := 0;
  while TRUE do
    begin
      if FALSE then
        Break;
      InvalidateRect(hDialog, nil, FALSE);
      Sleep(75);
      case scrMode of
        scrStart:
          begin
            BitBlt(hMemHdc, 0, 0, iWidth, iHeight, _hMemHdc_, 0, 0, SRCCOPY);
            PaintSnow(hMemHdc);
          end;
        scrPreview:
          BitBlt(hMemHdc, 0, 0, iWidth, iHeight, _hMemHdc_, 0, 0, SRCCOPY);
      end;
      if FALSE then
        Break;
    end;
end;

function MainWndProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
begin
  Result := 0;

  case uMsg of

    {}
    WM_CREATE:
      begin
        hDialog := hWnd;

        { создаем битмап для рисования }
        hMemHdc := CreateCompatibleDC(0);
        hBmpNew := CreateCompatibleBitmap(GetDC(hDialog), iWidth, iHeight);
        hBmpOld := SelectObject(hMemHdc, hBmpNew);

        _hMemHdc_ := CreateCompatibleDC(0);
        _hBmpNew_ := CreateCompatibleBitmap(GetDC(hDialog), iWidth, iHeight);
        _hBmpOld_ := SelectObject(_hMemHdc_, _hBmpNew_);

        { инициализируем библиотеку gdiplus }
        StartUpInfo.GdiPlusVersion := 1;
        GdiplusStartup(GdipToken, StartUpInfo, 0);

        { получаем хэндл указанного ресурса }
        resHandle := FindResource(hInstance, MAKEINTRESOURCE(RC_DRAW_IMAGE), RT_RCDATA);
        if resHandle = 0 then
          begin
            MessageBox(hDialog, nil, nil, MB_ICONSTOP);
            PostMessage(hDialog, WM_CLOSE, 0, 0);
          end;
        { получаем размер ресурса }
        resSize := SizeofResource(hInstance, resHandle);
        if resSize = 0 then
          begin
            MessageBox(hDialog, nil, nil, MB_ICONSTOP);
            PostMessage(hDialog, WM_CLOSE, 0, 0);
          end;
        { получаем указатель на первый байт ресурса }
        loadRes := LoadResource(hInstance, resHandle);
        presData := LockResource(loadRes);
        if presData = nil then
          begin
            MessageBox(hDialog, nil, nil, MB_ICONSTOP);
            PostMessage(hDialog, WM_CLOSE, 0, 0);
          end;
        { выделяем необходимое количество байт в куче и получаем хэндл }
        hBuffer := GlobalAlloc(GMEM_MOVEABLE, resSize);
        if hBuffer <> 0 then
          begin
            { получаем указатель на выделенный блок памяти }
            pBuffer := GlobalLock(hBuffer);
            if pBuffer <> nil then
              begin
                { копируем ресурс в память }
                CopyMemory(pBuffer, presData, resSize);
                { и создаем на его основе поток в памяти }
                if CreateStreamOnHGlobal(hBuffer, FALSE, rIStream) = S_OK then
                  { загружаем png изображение }
                  GdipLoadImageFromStream(rIStream, GdiImage)
                else
                  begin
                    MessageBox(hDialog, nil, nil, MB_ICONSTOP);
                    PostMessage(hDialog, WM_CLOSE, 0, 0);
                  end;
              end;
          end;

        { освобождаем загруженные ресурсы }  
        UnlockResource(loadRes);
        FreeResource(loadRes);

        { проверяем правильность загрузки изображения }
        if GdiImage = 0 then
          begin
            MessageBox(hDialog, nil, nil, MB_ICONSTOP);
            PostMessage(hDialog, WM_CLOSE, 0, 0);
          end;

        { создем объект dgi из hdc }
        GdipCreateFromHDC(_hMemHdc_, Graphics);

        { выполняем отрисовку изображения }
        GdipDrawImageRect(Graphics, GdiImage, 0, 0, iWidth, iHeight);

        { освобождаем память и удаляем gdi изображение }
        GdipDisposeImage(GdiImage);
        GdipDeleteGraphics(Graphics);

        { скрываем курсор при запуске заставки }
        if scrMode = scrStart then
          ShowCursor(FALSE);

        { обнуляем счетчик положения координат курсора }
        Counter := 0;

        { запускаем таймер на проверку курсора в окне }
        SetTimer(hDialog, ID_DRAW_TIMER, 10, nil);
        GetCursorPos(stPoint);

        { устанавливаем прозрачность окна }
        SetWindowLongW(hDialog, GWL_EXSTYLE, GetWindowLong(hDialog, GWL_EXSTYLE) or WS_EX_LAYERED);
        SetLayeredWindowAttributes(hDialog, RGB(255, 0, 255), (255 * BlendVal) div 100, LWA_COLORKEY + LWA_ALPHA);

        { запускаем поток для прорисовки снежинок }
        Snow_Clr := RGB(255, 0, 255);
        Randomize;
        SetLength(MyPoints, SnowVal);
        for IndexSnow := 0 to High(MyPoints) do
        begin
          MyPoints[IndexSnow].XcurPoint := iWidth - Random(iWidth);
          MyPoints[IndexSnow].YcurPoint := iHeight - Random(iHeight);
          MyPoints[IndexSnow].SpeedSnow := 3 - Random(2);
          MyPoints[IndexSnow].CrazySnow := 1 - Random(1);
          MyPoints[IndexSnow].lastColor := GetPixel(hMemHdc, MyPoints[IndexSnow].XcurPoint + 1, MyPoints[IndexSnow].YcurPoint);
        end;
        DrawThrd := CreateThread(nil, 0, @PaintThreadFunc, nil, 0, DrawThrID);
      end;

    {}
    WM_ACTIVATE:
      if LoWord(wParam) = WA_INACTIVE then
        PostMessage(hDialog, WM_CLOSE, 0, 0);
        
    {}
    WM_LBUTTONDOWN, WM_MBUTTONDOWN, WM_RBUTTONDOWN, WM_KEYDOWN:
      if scrMode = scrStart then
        PostMessage(hDialog, WM_CLOSE, 0, 0);

    {}
    WM_MOUSEMOVE:
      begin
        if (scrMode = scrStart) and (Counter >= 10) then
          begin
            GetCursorPos(lpPoint);
            if (lpPoint.X - stPoint.X <- 10) or (lpPoint.X - stPoint.X > 10) or (lpPoint.y - stPoint.Y <- 10) or (lpPoint.y - stPoint.Y > 10) then
              PostMessage(hDialog, WM_CLOSE, 0, 0);
          end;
      end;

    {}
    WM_SYSCOMMAND:
      case wParam of
        SC_MONITORPOWER:;
        SC_SCREENSAVE, SC_CLOSE:
          Result := 0;
      end;

    {}
    WM_TIMER:
      begin
        if Counter < (1000 div ID_DRAW_TIMER) then
          Inc(Counter);
      end;

    {}
    WM_PAINT:
      begin
        BeginPaint(hDialog, PaintStr);
        BitBlt(PaintStr.hdc, 0, 0, iWidth, iHeight, hMemHdc, 0, 0, SRCCOPY);
        EndPaint(hDialog, PaintStr);
      end;

    {}
    WM_CLOSE, WM_DESTROY:
      begin
        if scrMode = scrStart then
          ShowCursor(TRUE);
        KillTimer(hDialog, ID_DRAW_TIMER);
        { удаляем созданные объекты }
        CloseHandle(DrawThrd);
        SelectObject(hMemHdc, hBmpOld);
        DeleteObject(hMemHdc);
        DeleteObject(hBmpNew);
        SelectObject(_hMemHdc_, _hBmpOld_);
        DeleteObject(_hMemHdc_);
        DeleteObject(_hBmpNew_);
        DestroyWindow(hDialog);
        { выгружаем библиотеку gdiplus }
        GdiplusShutdown(GdipToken);
        PostQuitMessage(0);
      end;

  else
    Result := DefWindowProc(hWnd, uMsg, wParam, lParam);
  end;
end;

begin
  {}
  InitCommonControls;
  {}
  BlendVal := RegReadInteger(WndClassApp, 'BlendValue');
  SnowVal := RegReadInteger(WndClassApp, 'SnowValue');
  SpeedVal := RegReadInteger(WndClassApp, 'SpeedValue');
  FirstRun := RegReadInteger(WndClassApp, 'IsFirstRun');
  case Boolean(FirstRun) of
    FALSE:
      begin
        if BlendVal = 0 then
          BlendVal := 100;
        if SnowVal = 0 then
          SnowVal := 500;
        if SpeedVal = 0 then
          SpeedVal := 1;
        RegWriteInteger(WndClassApp, 'BlendValue', BlendVal);
        RegWriteInteger(WndClassApp, 'SnowValue', SnowVal);
        RegWriteInteger(WndClassApp, 'SpeedValue', SpeedVal);
        FirstRun := 1;
        RegWriteInteger(WndClassApp, 'IsFirstRun', FirstRun);
      end;
  end;
  hAppIcon := LoadImage(hInstance, MAKEINTRESOURCE(RC_DRAW_ICOND), IMAGE_ICON, 16, 16, LR_LOADTRANSPARENT or LR_LOADMAP3DCOLORS);
  {}
  if ParamCount = 0 then
    scrMode := scrConfig
  else
    if ParamStr(1)[1] in ['-', '/'] then
      begin
        case ParamStr(1)[2] of
          'S', 's':
            scrMode := scrStart;
          'P', 'p':
            scrMode := scrPreview;
          'C', 'c':
            scrMode := scrConfig;
        end;
      end;
  {}
  if System.HPrevInst = 0 then
  begin
    ZeroMemory(@WndClass, Sizeof(TWndClass));
    with WndClass do
    begin
      Style         := CS_VREDRAW or CS_HREDRAW or CS_SAVEBITS or CS_DBLCLKS;
      lpfnWndProc   := @MainWndProc;
      cbClsExtra    := 0;
      cbWndExtra    := 0;
      hbrBackground := GetStockObject(BLACK_BRUSH);
      lpszMenuName  := nil;
      lpszClassName := WndClassName;
      hInstance     := hInstance;
      hIcon         := hAppIcon;
      hCursor       := LoadImage(0, PAnsiChar(IDC_ARROW), IMAGE_CURSOR, 16, 16, LR_LOADTRANSPARENT or LR_LOADMAP3DCOLORS or LR_SHARED);
    end;
    RegisterClass(WndClass);
  end;
  {}
  if scrMode = scrStart then
    begin
      GetClientRect(GetDesktopWindow, lpRect);
      iWidth := lpRect.Right - lpRect.Left;
      iHeight := lpRect.Bottom - lpRect.Top;
      hSaver := CreateWindowEx(WS_EX_TOPMOST, WndClassName, WndClassApp, WS_VISIBLE or WS_POPUP {or WS_SYSMENU}, lpRect.Left, lpRect.Top, lpRect.Right, lpRect.Bottom, 0, 0, hInstance, nil);
    end
  else
    if scrMode = scrPreview then
      begin
        hParent := StrToInt(ParamStr(2));
        GetClientRect(hParent, lpRect);
        iWidth := lpRect.Right - lpRect.Left;
        iHeight := lpRect.Bottom - lpRect.Top;
        hSaver := CreateWindow(WndClassName, WndClassApp, WS_CHILD or WS_VISIBLE, lpRect.Left, lpRect.Top, lpRect.Right, lpRect.Bottom, hParent, 0, hInstance, nil);
      end
  else
    begin
      hSaver := GetForegroundWindow;
      DialogBox(hInstance, MAKEINTRESOURCE(RC_DRAW_DIALG), hSaver, @SetgDlgProc);
      PostQuitMessage(0);
    end;
  {}
  UpdateWindow(hSaver);
  {}
  while (GetMessage(uMsg, 0, 0, 0)) do
    begin
      TranslateMessage(uMsg);
      DispatchMessage(uMsg);
    end;
  {}
  DeleteObject(hAppIcon);
  ExitCode := uMsg.wParam;
end.