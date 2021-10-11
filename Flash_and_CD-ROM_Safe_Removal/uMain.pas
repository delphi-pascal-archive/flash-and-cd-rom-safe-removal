////////////////////////////////////////////////////////////////////////////////
//
//  ****************************************************************************
//  * Project   : Safe Removal Demo
//  * Unit Name : uMain.pas
//  * Purpose   : Демо безопасного извлечения CD-ROM и флэш накопителей
//  * Author    : Александр (Rouse_) Багель
//  * Copyright : © Fangorn Wizards Lab 1998 - 2009.
//  * Version   : 1.00
//  * Home Page : http://rouse.drkb.ru
//  ****************************************************************************
//

unit uMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ActnList;

type
  TdlgSafeRemoval = class(TForm)
    gbVolumes: TGroupBox;
    lbVolumes: TListBox;
    gbLog: TGroupBox;
    memLog: TMemo;
    btnRemove: TButton;
    ActionList1: TActionList;
    acRemoval: TAction;
    procedure FormCreate(Sender: TObject);
    procedure acRemovalUpdate(Sender: TObject);
    procedure acRemovalExecute(Sender: TObject);
  private
    procedure Log(const Value: string);
    function IsCDOpen(const Value: string): Boolean;
    procedure FillDrives;
    function RemoveCDRom(const Value: string): Boolean;
    function RemoveFlash(const Value: string): Boolean;
  end;

var
  dlgSafeRemoval: TdlgSafeRemoval;

implementation

{$R *.dfm}

// Выравнивание должно равняться восьми,
// иначе может поплыть размер непакованных структур
{$ALIGN 8}

const
  DeviceMask = '%s:';
  VolumeMask = '\\.\' + DeviceMask;

  setupapi = 'SetupApi.dll';
  cfgmgr = 'cfgmgr32.dll';  

  // Константы и типы из winioctl.h

const
  FILE_DEVICE_CONTROLLER = $00000004;
  FILE_DEVICE_FILE_SYSTEM = $00000009;
  FILE_DEVICE_MASS_STORAGE = $0000002D;

  METHOD_BUFFERED = $00000000;
  FILE_ANY_ACCESS = $00000000;
  FILE_READ_ACCESS = $00000001;
  FILE_WRITE_ACCESS = $00000002;

  IOCTL_STORAGE_BASE = FILE_DEVICE_MASS_STORAGE;
  IOCTL_SCSI_BASE = FILE_DEVICE_CONTROLLER;

  FSCTL_LOCK_VOLUME = (FILE_DEVICE_FILE_SYSTEM shl 16) or
    (FILE_ANY_ACCESS shl 14) or ($6 shl 2) or METHOD_BUFFERED;

  FSCTL_DISMOUNT_VOLUME = (FILE_DEVICE_FILE_SYSTEM shl 16) or
    (FILE_ANY_ACCESS shl 14) or ($8 shl 2) or METHOD_BUFFERED;

  IOCTL_STORAGE_MEDIA_REMOVAL = (IOCTL_STORAGE_BASE shl 16) or
    (FILE_READ_ACCESS shl 14) or ($0201 shl 2) or METHOD_BUFFERED;

  IOCTL_STORAGE_EJECT_MEDIA = (IOCTL_STORAGE_BASE shl 16) or
    (FILE_READ_ACCESS shl 14) or ($0202 shl 2) or METHOD_BUFFERED; 

  IOCTL_STORAGE_GET_DEVICE_NUMBER = (IOCTL_STORAGE_BASE shl 16) or
    (FILE_ANY_ACCESS shl 14) or ($0420 shl 2) or METHOD_BUFFERED;

  IOCTL_SCSI_PASS_THROUGH = (IOCTL_SCSI_BASE shl 16) or
    ((FILE_WRITE_ACCESS or FILE_READ_ACCESS) shl 14) or
    ($0401 shl 2) or METHOD_BUFFERED;

  GUID_DEVINTERFACE_DISK: TGUID = (
    D1:$53f56307; D2:$b6bf; D3:$11d0; D4:($94, $f2, $00, $a0, $c9, $1e, $fb, $8b));

type
  DEVICE_TYPE = DWORD;

  PStorageDeviceNumber = ^TStorageDeviceNumber;
  TStorageDeviceNumber = packed record
    DeviceType: DEVICE_TYPE;
    DeviceNumber: DWORD;
    PartitionNumber: DWORD;
  end;

  // Константы и типы из setupapi.h

const
  ANYSIZE_ARRAY = 1024;

  DIGCF_PRESENT         = $00000002;
  DIGCF_DEVICEINTERFACE = $00000010;

type
  HDEVINFO = THandle;

  PSPDevInfoData = ^TSPDevInfoData;
  SP_DEVINFO_DATA = packed record
    cbSize: DWORD;
    ClassGuid: TGUID;
    DevInst: DWORD; // DEVINST handle
    Reserved: ULONG; // ULONG_PTR;
  end;
  TSPDevInfoData = SP_DEVINFO_DATA;

  PSPDeviceInterfaceData = ^TSPDeviceInterfaceData;
  SP_DEVICE_INTERFACE_DATA = packed record
    cbSize: DWORD;
    InterfaceClassGuid: TGUID;
    Flags: DWORD;
    Reserved: ULONG; // ULONG_PTR;
  end;
  TSPDeviceInterfaceData = SP_DEVICE_INTERFACE_DATA;

  PSPDeviceInterfaceDetailDataA = ^TSPDeviceInterfaceDetailDataA;
  PSPDeviceInterfaceDetailData = PSPDeviceInterfaceDetailDataA;
  SP_DEVICE_INTERFACE_DETAIL_DATA_A = packed record
    cbSize: DWORD;
    DevicePath: array [0..ANYSIZE_ARRAY - 1] of AnsiChar;
  end;
  TSPDeviceInterfaceDetailDataA = SP_DEVICE_INTERFACE_DETAIL_DATA_A;
  TSPDeviceInterfaceDetailData = TSPDeviceInterfaceDetailDataA;

  function SetupDiGetClassDevsA(ClassGuid: PGUID; const Enumerator: PAnsiChar;
    hwndParent: HWND; Flags: DWORD): HDEVINFO; stdcall; external setupapi;

  function SetupDiDestroyDeviceInfoList(
    DeviceInfoSet: HDEVINFO): LongBool; stdcall; external setupapi;

  function SetupDiEnumDeviceInterfaces(DeviceInfoSet: HDEVINFO;
    DeviceInfoData: PSPDevInfoData; const InterfaceClassGuid: TGUID;
    MemberIndex: DWORD; var DeviceInterfaceData: TSPDeviceInterfaceData):
    LongBool; stdcall; external setupapi;

  function SetupDiGetDeviceInterfaceDetailA(DeviceInfoSet: HDEVINFO;
    DeviceInterfaceData: PSPDeviceInterfaceData;
    DeviceInterfaceDetailData: PSPDeviceInterfaceDetailDataA;
    DeviceInterfaceDetailDataSize: DWORD; var RequiredSize: DWORD;
    Device: PSPDevInfoData): LongBool; stdcall; external setupapi;

  // Константы и типы из cfgmgr32.h

const
  CR_SUCCESS = 0;

  PNP_VetoTypeUnknown          = 0;
  PNP_VetoLegacyDevice         = 1;
  PNP_VetoPendingClose         = 2;
  PNP_VetoWindowsApp           = 3;
  PNP_VetoWindowsService       = 4;
  PNP_VetoOutstandingOpen      = 5;
  PNP_VetoDevice               = 6;
  PNP_VetoDriver               = 7;
  PNP_VetoIllegalDeviceRequest = 8;
  PNP_VetoInsufficientPower    = 9;
  PNP_VetoNonDisableable       = 10;
  PNP_VetoLegacyDriver         = 11;  
  PNP_VetoInsufficientRights   = 12;

type
  DEVINST = DWORD;
  CONFIGRET = DWORD;

  PPNP_VETO_TYPE = ^PNP_VETO_TYPE;
  PNP_VETO_TYPE = DWORD;

  function CM_Get_Parent(var dnDevInstParent: DEVINST;
    dnDevInst: DEVINST; ulFlags: ULONG): CONFIGRET; stdcall;
    external cfgmgr;

  function CM_Request_Device_EjectA(dnDevInst: DEVINST;
    pVetoType: PPNP_VETO_TYPE; pszVetoName: PWideChar;
    ulNameLength: ULONG; ulFlags: ULONG): CONFIGRET; stdcall;
    external setupapi;

  // Константы и типы из ntddscsi.h

const
  SCSI_IOCTL_DATA_IN = 1;
  SCSIOP_MECHANISM_STATUS = $BD;

type
  USHORT = Word;

  PSCSI_PASS_THROUGH_DIRECT = ^SCSI_PASS_THROUGH_DIRECT;
  _SCSI_PASS_THROUGH_DIRECT = {packed} record
    Length: USHORT;
    ScsiStatus: UCHAR;
    PathId: UCHAR;
    TargetId: UCHAR;
    Lun: UCHAR;
    CdbLength: UCHAR;
    SenseInfoLength: UCHAR;
    DataIn: UCHAR;
    DataTransferLength: ULONG;
    TimeOutValue: ULONG;
    DataBuffer: ULONG;
    SenseInfoOffset: ULONG;
    Cdb: array [0..15] of UCHAR;
  end;
  SCSI_PASS_THROUGH_DIRECT = _SCSI_PASS_THROUGH_DIRECT;

  TSCSIPassThroughDirectBuffer = record
    Header: SCSI_PASS_THROUGH_DIRECT;
    SenseBuffer: array [0..31] of UCHAR;
    DataBuffer: array [0..191] of UCHAR;
  end;         

//  Обработчик извлечения диска
// =============================================================================
procedure TdlgSafeRemoval.acRemovalExecute(Sender: TObject);
var
  Volume: string;
  Done: Boolean;
begin
  Volume := Format(DeviceMask, [lbVolumes.Items[acRemoval.Tag][1]]);
  // Определяем тип накопителя
  case GetDriveType(PChar(Volume)) of
    DRIVE_CDROM: // Диск является CDROM-ом
      Done := RemoveCDRom(lbVolumes.Items[acRemoval.Tag][1]);
    DRIVE_REMOVABLE: // Диск является флэшкой
      Done := RemoveFlash(lbVolumes.Items[acRemoval.Tag][1]);
  else
    Done := False;
  end;
  // Если извлечение успешно - перечитываем список дисков
  if Done then  
    FillDrives;
end;

//  Обработчик обновления состояния кнопки
//  кнопка активна, если выбран какой-либо диск
// =============================================================================
procedure TdlgSafeRemoval.acRemovalUpdate(Sender: TObject);
var
  ACount, I: Integer;
begin
  ACount := lbVolumes.Items.Count;
  for I := 0 to ACount - 1 do
    if lbVolumes.Selected[I] then
    begin
      acRemoval.Tag := I;
      acRemoval.Enabled := True;
      Exit;
    end;
  acRemoval.Enabled := False;
end;

//  Процедура производит поиск подходящих устройств
// =============================================================================
procedure TdlgSafeRemoval.FillDrives;
const
  NameSize = 4;
  VolumeCount = 26;
  TotalSize = NameSize * VolumeCount;
  Report = 'Найден диск: %s %s';
var
  Buff, Volume: string;
  lpQuery: array [0..MAXCHAR - 1] of Char;
  I, Count: Integer;
begin
  lbVolumes.Clear;
  SetLength(Buff, TotalSize);
  // Получаем список всех дисков в сстеме
  Count := GetLogicalDriveStrings(TotalSize, @Buff[1]) div NameSize;
  if Count = 0 then
    Log('Диски не определены')
  else
    for I := 0 to Count - 1 do
    begin
      Volume := PChar(@Buff[(I * NameSize) + 1]);
      // Смотрим тип каждого диска
      case GetDriveType(PChar(Volume)) of
        DRIVE_REMOVABLE: // флэш или флопи
        begin
          Volume[3] := #0;
          QueryDosDevice(PChar(Volume), @lpQuery[0], MAXCHAR);
          Volume[3] := '\';
          if Copy(String(lpQuery), 1, 14) <> '\Device\Floppy' then
          begin
            // Если диск не флопи - добавляем в список
            Log(Format(Report,
              [Volume, 'Флэш накопитель']));
            lbVolumes.Items.Add(Volume[1] + ' - Флэш накопитель');
          end;
        end;
        DRIVE_CDROM: // сидиром
        begin
          // Если лоток привода компакт дисков закрыт - добавляем в список
          if not IsCDOpen(Volume[1]) then
          begin
            Log(Format(Report, [Volume,'CD-ROM']));
            lbVolumes.Items.Add(Volume[1] + ' - CD-ROM');
          end;
        end;
      end;
    end;
end;

// =============================================================================
procedure TdlgSafeRemoval.FormCreate(Sender: TObject);
begin
  FillDrives;
end;

//  Функция определяет состояние лотка привода компакт дисков
// =============================================================================
function TdlgSafeRemoval.IsCDOpen(const Value: string): Boolean;
var
  PassTrought: TSCSIPassThroughDirectBuffer;
  dwQueryLen, dwBytesReturned: DWORD;
  hCDHandle: THandle;
begin
  Result := False;

  // Принцип получения состояния лотка основан на отправке команды
  // SCSIOP_MECHANISM_STATUS посредством IOCTL запроса IOCTL_SCSI_PASS_THROUGH

  // Подготавливаем буффер запроса
  ZeroMemory(@PassTrought, SizeOf(TSCSIPassThroughDirectBuffer));
  PassTrought.Header.Length := SizeOf(SCSI_PASS_THROUGH_DIRECT);
  // Размер команды в байтах
  PassTrought.Header.CdbLength := 12;
  // Тип обмена данных
  PassTrought.Header.DataIn := SCSI_IOCTL_DATA_IN;
  // Размер буффера данных
  PassTrought.Header.DataTransferLength := SizeOf(PassTrought.DataBuffer);
  // Время ожидания ответа
  PassTrought.Header.TimeOutValue := 10;
  // Оффсет на начало буффера данных
  PassTrought.Header.DataBuffer :=
    DWORD(@PassTrought.DataBuffer) - DWORD(@PassTrought);
  // Заполняем Command Descriptor Block
  // Код команды
  PassTrought.Header.Cdb[0] := SCSIOP_MECHANISM_STATUS;
  // Размер ожидаемого ответа
  PassTrought.Header.Cdb[8] := 8;
  // общий размер запроса
  dwQueryLen := PassTrought.Header.DataBuffer +
    PassTrought.Header.DataTransferLength;
  // Открываем устройство
  hCDHandle := CreateFile(PChar(Format(VolumeMask, [Value])),
    GENERIC_WRITE or GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE,
    nil, OPEN_EXISTING, 0, 0);
  if hCDHandle <> INVALID_HANDLE_VALUE then
  try
    // Отправка запроса
    if DeviceIoControl(hCDHandle, IOCTL_SCSI_PASS_THROUGH, @PassTrought,
      dwQueryLen, @PassTrought, dwQueryLen, dwBytesReturned, nil) then
      // при успешном ответе 12-ый бит буффера будет содержать состояние лотка
      // 1 - открыт, 0 - закрыт
      Result := PassTrought.DataBuffer[1] and $10 = $10;
  finally
    CloseHandle(hCDHandle);
  end;
end;

// =============================================================================
procedure TdlgSafeRemoval.Log(const Value: string);
begin
  memLog.Lines.Add(Value);
end;

//  Открытие лотка привода компакт дисков
// =============================================================================
function TdlgSafeRemoval.RemoveCDRom(const Value: string): Boolean;
var
  hFile: THandle;
  dwBytesReturned: DWORD;
  nTryLockCount: Integer;
  PMRBuffer: Boolean;
begin
  Result := False;

  // Открываем том
  hFile := CreateFile(PChar(Format(VolumeMask, [Value])), GENERIC_READ,
    FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
  if hFile = INVALID_HANDLE_VALUE then
  begin
    Log('CreateFile Error: ' + SysErrorMessage(GetLastError));
    Exit;
  end;
  try

    // Пробуем заблокировать доступ к устройству
    // из других приложений (20 попыток максимум)
    nTryLockCount := 0;
    while nTryLockCount < 20 do
    begin
      if DeviceIoControl(hFile,
        FSCTL_LOCK_VOLUME, nil, 0, nil, 0, dwBytesReturned, nil) then
        Break;
      Inc(nTryLockCount);
      Sleep(500);
    end;
    if nTryLockCount = 20 then
    begin
      Log('DeviceIoControl (FSCTL_LOCK_VOLUME) Error: ' +
        SysErrorMessage(GetLastError));
      Exit;
    end;

    // Размонтируем устройство
    if not DeviceIoControl(hFile,
      FSCTL_DISMOUNT_VOLUME, nil, 0, nil, 0, dwBytesReturned, nil) then
    begin
      Log('DeviceIoControl (FSCTL_DISMOUNT_VOLUME) Error: ' +
        SysErrorMessage(GetLastError));
      Exit;
    end;

    // Подготавливаем лоток к открытию
    PMRBuffer := False;
    if not DeviceIoControl(hFile,
      IOCTL_STORAGE_MEDIA_REMOVAL, @PMRBuffer, SizeOf(Boolean),
        nil, 0, dwBytesReturned, nil) then
    begin
      Log('DeviceIoControl (IOCTL_STORAGE_MEDIA_REMOVAL) Error: ' +
        SysErrorMessage(GetLastError));
      Exit;
    end;

    // Открываем лоток
    if not DeviceIoControl(hFile,
      IOCTL_STORAGE_EJECT_MEDIA, nil, 0, nil, 0, dwBytesReturned, nil) then
    begin
      Log('DeviceIoControl (IOCTL_STORAGE_EJECT_MEDIA) Error: ' +
        SysErrorMessage(GetLastError));
      Exit;
    end;

    Result := True;

  finally
    CloseHandle(hFile);
  end;
end;

//  Функция производит безопасное отключение флэш накопителя
// =============================================================================
function TdlgSafeRemoval.RemoveFlash(const Value: string): Boolean;
var
  hFile, hDevInfo, hDrive, hDevInstance, hDevInstanceParent: THandle;
  sdn: TStorageDeviceNumber;
  dwDeviceNumber, dwBytesReturned, dwSize: DWORD;
  FlashGuid: TGUID;
  I: Integer;
  DeviceInfoData: TSPDevInfoData;
  DeviceInterfaceData: TSPDeviceInterfaceData;
  DeviceInterfaceDetailData: TSPDeviceInterfaceDetailData;
  nTryLockCount: Integer;
begin
  Result := False;

  hDevInstance := INVALID_HANDLE_VALUE;

  // Открываем том
  hFile := CreateFile(PChar(Format(VolumeMask, [Value])), 0,
    FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
  if hFile = INVALID_HANDLE_VALUE then
  begin
    Log('CreateFile Error: ' + SysErrorMessage(GetLastError));
    Exit;
  end;
  try

    // Получаем номер устройства в системе
    if not DeviceIoControl(hFile,
      IOCTL_STORAGE_GET_DEVICE_NUMBER, nil, 0, @sdn,
        SizeOf(TStorageDeviceNumber), dwBytesReturned, nil) then
    begin
      Log('DeviceIoControl (IOCTL_STORAGE_GET_DEVICE_NUMBER) Error: ' +
        SysErrorMessage(GetLastError));
      Exit;
    end;

    dwDeviceNumber := sdn.DeviceNumber;    
    FlashGuid := GUID_DEVINTERFACE_DISK;

    // Подготавливаем список устройств в системе, для поиска хэндла устройства
    hDevInfo := SetupDiGetClassDevsA(@FlashGuid, nil, 0,
      DIGCF_PRESENT or DIGCF_DEVICEINTERFACE);
    if hDevInfo = INVALID_HANDLE_VALUE then
    begin
      Log('SetupDiGetClassDevsA Error: ' + SysErrorMessage(GetLastError));
      Exit;
    end;
    try

      I := 0;
      // Крутим цикл по всем устройствам
      DeviceInterfaceData.cbSize := SizeOf(TSPDeviceInterfaceData);
      while SetupDiEnumDeviceInterfaces(
        hDevInfo, nil, FlashGuid, I, DeviceInterfaceData) do
      begin

        Inc(I);

        // Узнаем необходимый размер буффера для получения пути к устройству
        SetupDiGetDeviceInterfaceDetailA(hDevInfo, @DeviceInterfaceData,
          nil, 0, dwSize, nil);
        if dwSize = 0 then        
        begin
          Log('SetupDiGetDeviceInterfaceDetailA Error: ' +
            SysErrorMessage(GetLastError));
          Exit;
        end;

        DeviceInfoData.cbSize :=  SizeOf(TSPDevInfoData);

        // Узкий момент, размер структуры должен быть обьявлен как пятерка.
        // Почему? Это не ко мне, а к тем кто это придумал -
        // в противном случае вызов SetupDiGetDeviceInterfaceDetailA
        // будет не успешен
        DeviceInterfaceDetailData.cbSize := 5;

        // Получаем путь к устройству
        if not SetupDiGetDeviceInterfaceDetailA(hDevInfo, @DeviceInterfaceData,
          @DeviceInterfaceDetailData, dwSize, dwSize, @DeviceInfoData) then
        begin
          Log('SetupDiGetDeviceInterfaceDetailA Error: ' +
            SysErrorMessage(GetLastError));
          Exit;
        end;

        // Открываем устройство
        hDrive := CreateFile(PChar(@DeviceInterfaceDetailData.DevicePath[0]),
          0, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
        if hFile = INVALID_HANDLE_VALUE then
        begin
          Log('CreateFile Error: ' + SysErrorMessage(GetLastError));
          Exit;
        end;
        try

          // Получаем номер устройства в системе
          if not DeviceIoControl(hDrive,
            IOCTL_STORAGE_GET_DEVICE_NUMBER, nil, 0, @sdn,
              SizeOf(TStorageDeviceNumber), dwBytesReturned, nil) then
          begin
            Log('DeviceIoControl (IOCTL_STORAGE_GET_DEVICE_NUMBER) Error: ' +
              SysErrorMessage(GetLastError));
            Exit;
          end;

          // Если данное устройство - наше, запоминаем хэндл
          if sdn.DeviceNumber = dwDeviceNumber then
          begin
            hDevInstance := DeviceInfoData.DevInst;
            Break;
          end;

        finally
          CloseHandle(hDrive);
        end;
      end;
    finally
      SetupDiDestroyDeviceInfoList(hDevInfo);
    end;
  finally
    CloseHandle(hFile);
  end;

  // Смотрим - нашелся ли хэндл устройства
  if hDevInstance <> INVALID_HANDLE_VALUE then
  begin

    // Получаем хэндл родителя
    if CM_Get_Parent(hDevInstanceParent, hDevInstance, 0) <> CR_SUCCESS then
    begin
      Log('CM_Get_Parent Error: ' +
        SysErrorMessage(GetLastError));
      Exit;
    end;

    nTryLockCount := 0;
    // Говорим родителю - извлечь подключенное устройство
    // (20 попыток максимум)
    while nTryLockCount < 20 do
    begin
      if CM_Request_Device_EjectA(
        hDevInstanceParent, nil, nil, 0, 0) = CR_SUCCESS then
        Break;
      Inc(nTryLockCount);
      Sleep(500);
    end;
    if nTryLockCount = 20 then
    begin
      Log('CM_Request_Device_EjectW Error: ' +
        SysErrorMessage(GetLastError));
      Exit;
    end
    else
      Result := True;
  end;
end;

end.
