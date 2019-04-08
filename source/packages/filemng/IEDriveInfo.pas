unit IEDriveInfo;

{==================================================================

 Component TDriveInfo  /  Version 2.6  / January 2000
 ====================================================


    Description:
    ============
    Central drive management class. Provides information about all
    installed drives, for example wether drive is valid, disk is inserted
    displayname or volume size.

    Author:
    =======
    (c) Ingo Eckel 1999
    Sodener Weg 38
    65812 Bad Soden
    Germany

    For detailed documentation and history see the documentation in TDriveInfo.htm.

{==================================================================}

{Required compiler options:}
{$A+,B-,X+,H+,P+}
{$WARN SYMBOL_PLATFORM OFF}

interface

uses
  Windows, Registry, SysUtils, Classes, ComCtrls, ShellApi, ShlObj, CommCtrl, Forms,
  BaseUtils, System.Generics.Collections;

const
  {Flags used by TDriveInfo.ReadDriveStatus and TDriveView.RefreshRootNodes:}
  dsValid = 0;        {checks only whether drive is still valid}
  dsImageIndex = 1;   {Fetch imageindex, if not allready fetched}
  dsSize = 2;         {Fetch disk size and serialnumber}
  dsDisplayName = 4;  {Fetch drives displayname}
  dsAll = dsImageIndex or dsSize or dsDisplayName;
  FirstDrive          = 'A';
  FirstFixedDrive     = 'C';
  LastDrive           = 'Z';
  FirstSpecialFolder  = CSIDL_DESKTOP;
  LastSpecialFolder   = CSIDL_PRINTHOOD;

type
  TDriveInfoRec = class
    PIDL        : PItemIDList; {Fully qualyfied PIDL}
    Init        : Boolean;     {Drivestatus was updated once}
    Valid       : Boolean;     {Drivestatus is valid}
    DriveReady  : Boolean;     {Drive is ready}
    DriveType   : Integer;     {DRIVE_REMOVABLE, DRIVE_FIXED, DRIVE_CDROM, DRIVE_RAMDISK, DRIVE_REMOTE}
    DisplayName : string;      {Windows displayname}
    PrettyName  : string;      {Prettyfied displayname}
    DriveSerial : DWORD;       {Serial number of the drive}
    Size        : Int64;       {Drivesize}
    ImageIndex  : Integer;     {Drive imageIndex}
  end;

  TRealDrive = char;
  TSpecialFolder = FirstSpecialFolder..LastSpecialFolder;
  PSpecialFolderRec = ^TSpecialFolderRec;
  TSpecialFolderRec = record
    Valid: Boolean;
    Location: string;
    DisplayName: string;
    ImageIndex: Integer;
    PIDL: PItemIDList;
  end;

  TDriveInfo = class(TObject)
  private
    FData: TObjectDictionary<string, TDriveInfoRec>;
    FNoDrives: DWORD;
    FDesktop: IShellFolder;
    FFolders: array[TSpecialFolder] of TSpecialFolderRec;
    FHonorDrivePolicy: Boolean;
    FLoaded: Boolean;
    function GetFolder(Folder: TSpecialFolder): PSpecialFolderRec;
    procedure ReadDriveBasicStatus(Drive: string);
    procedure ResetDrive(Drive: string);
    procedure SetHonorDrivePolicy(Value: Boolean);
    procedure NeedData;
    procedure Load;
    function AddDrive(Drive: string): TDriveInfoRec;

  public
    function Get(Drive: string): TDriveInfoRec;
    property SpecialFolder[Folder: TSpecialFolder]: PSpecialFolderRec read GetFolder;

    function AnyValidPath: string;
    function GetDriveKey(Path: string): string;
    function GetDriveRoot(Drive: string): string;
    function IsRealDrive(Drive: string): Boolean;
    function IsFixedDrive(Drive: string): Boolean;
    function GetImageIndex(Drive: string): Integer;
    function GetSimpleName(Drive: string): string;
    function GetDisplayName(Drive: string): string;
    function GetPrettyName(Drive: string): string;
    function ReadDriveStatus(Drive: string; Flags: Integer): Boolean;
    property HonorDrivePolicy: Boolean read FHonorDrivePolicy write SetHonorDrivePolicy;
    constructor Create;
    destructor Destroy; override;
  end;

function GetShellFileName(const Name: string): string; overload;
function GetShellFileName(PIDL: PItemIDList): string; overload;
function GetNetWorkName(Drive: string): string;
function GetNetWorkConnected(Drive: string): Boolean;
function IsRootPath(Path: string): Boolean;

{Central drive information object instance of TDriveInfo}
var
  DriveInfo : TDriveInfo;

resourceString
  ErrorInvalidDrive = '%s is a invalid drive letter.';

implementation

uses
  Math, PIDL, OperationWithTimeout, PasTools;

constructor TDriveInfo.Create;
begin
  inherited;

  FHonorDrivePolicy := True;
  FLoaded := False;
  FData := TObjectDictionary<string, TDriveInfoRec>.Create([doOwnsValues]);
end; {TDriveInfo.Create}

destructor TDriveInfo.Destroy;
begin
  FData.Free;
  inherited;
end; {TDriveInfo.Destroy}

procedure TDriveInfo.NeedData;
begin
  if not FLoaded then
  begin
    Load;
    FLoaded := True;
  end;
end;

function TDriveInfo.AnyValidPath: string;
var
  Drive: TRealDrive;
begin
  for Drive := FirstFixedDrive to LastDrive do
    if Get(Drive).Valid and
       (Get(Drive).DriveType = DRIVE_FIXED) and
       DirectoryExists(ApiPath(DriveInfo.GetDriveRoot(Drive))) then
    begin
      Result := DriveInfo.GetDriveRoot(Drive);
      Exit;
    end;
  for Drive := FirstFixedDrive to LastDrive do
    if Get(Drive).Valid and
       (Get(Drive).DriveType = DRIVE_REMOTE) and
       DirectoryExists(ApiPath(DriveInfo.GetDriveRoot(Drive))) then
    begin
      Result := DriveInfo.GetDriveRoot(Drive);
      Exit;
    end;
  raise Exception.Create(SNoValidPath);
end;

function TDriveInfo.IsRealDrive(Drive: string): Boolean;
begin
  Result := (Length(Drive) = 1);
  Assert((not Result) or ((Drive[1] >= FirstDrive) and (Drive[1] <= LastDrive)));
end;

function TDriveInfo.IsFixedDrive(Drive: string): Boolean;
begin
  Result := True;
  if IsRealDrive(Drive) and (Drive[1] < FirstFixedDrive) then Result := False;
end;

function TDriveInfo.GetDriveKey(Path: string): string;
begin
  Result := ExtractFileDrive(Path);
  if (Length(Result) = 2) and (Result[2] = DriveDelim) then
  begin
    Result := Upcase(Result[1]);
  end
    else
  if IsUncPath(Path) then
  begin
    Result := LowerCase(Result);
  end
    else
  begin
    raise EConvertError.Create(Format(ErrorInvalidDrive, [Path]))
  end;
end;

function TDriveInfo.GetDriveRoot(Drive: string): string;
begin
  if IsRealDrive(Drive) then
  begin
    Result := Drive + ':\'
  end
    else
  begin
    Assert(IsUncPath(Drive));
    Result := IncludeTrailingBackslash(Drive);
  end;
end;

function TDriveInfo.GetFolder(Folder: TSpecialFolder): PSpecialFolderRec;
var
  FileInfo: TShFileInfo;
  Path: PChar;
  Flags: Word;
begin
  NeedData;
  Assert((Folder >= Low(FFolders)) and (Folder <= High(FFolders)));

  with FFolders[Folder] do
  begin
    if not Valid then
    begin
      SpecialFolderLocation(Folder, Location, PIDL);
      if Assigned(PIDL) then
      begin
        Path := PChar(PIDL);
        Flags := SHGFI_PIDL;
      end
        else
      begin
        Path := PChar(Location);
        Flags := 0;
      end;

      SHGetFileInfo(Path, 0, FileInfo, SizeOf(FileInfo),
        SHGFI_DISPLAYNAME or SHGFI_SYSICONINDEX or SHGFI_SMALLICON or Flags);
      ImageIndex := FileInfo.iIcon;
      DisplayName := FileInfo.szDisplayName;
      Valid := True;
    end;
  end;

  Result := @FFolders[Folder];
end;

procedure TDriveInfo.SetHonorDrivePolicy(Value: Boolean);
var
  Drive: TRealDrive;
begin
  if HonorDrivePolicy <> Value then
  begin
    FHonorDrivePolicy := Value;
    if FLoaded then
    begin
      for Drive := FirstDrive to LastDrive do
      begin
        ReadDriveBasicStatus(Drive);
      end;
    end;
  end;
end;

procedure TDriveInfo.ReadDriveBasicStatus(Drive: string);
begin
  Assert(FData.ContainsKey(Drive));
  with FData[Drive] do
  begin
    DriveType := Windows.GetDriveType(PChar(DriveInfo.GetDriveRoot(Drive)));
    Valid :=
      ((not IsRealDrive(Drive)) or (not FHonorDrivePolicy) or (not Bool((1 shl (Ord(Drive[1]) - 65)) and FNoDrives))) and
      (DriveType in [DRIVE_REMOVABLE, DRIVE_FIXED, DRIVE_CDROM, DRIVE_RAMDISK, DRIVE_REMOTE]);
  end;
end;

procedure TDriveInfo.ResetDrive(Drive: string);
begin
  with FData[Drive] do
  begin
    DriveReady := False;
    DisplayName := '';
    PrettyName := '';
    DriveSerial := 0;
    Size := -1;
    ImageIndex := 0;
  end;
end;

procedure TDriveInfo.Load;
var
  Drive: TRealDrive;
  Reg: TRegistry;
  Folder: TSpecialFolder;
begin
  FNoDrives := 0;
  Reg := TRegistry.Create;
  try
    if Reg.OpenKeyReadOnly('Software\Microsoft\Windows\CurrentVersion\Policies\Explorer') Then
       Reg.ReadBinaryData('NoDrives', FNoDrives, SizeOf(FNoDrives));
  except
    try
      FNoDrives := Reg.ReadInteger('NoDrives');
    except
    end;
  end;
  Reg.Free;

  FDesktop := nil;

  for Drive := FirstDrive to LastDrive do
  begin
    AddDrive(Drive);
  end;

  for Folder := Low(FFolders) to High(FFolders) do
    FFolders[Folder].Valid := False;
end;

function TDriveInfo.AddDrive(Drive: string): TDriveInfoRec;
begin
  Result := TDriveInfoRec.Create;
  FData.Add(Drive, Result);
  ResetDrive(Drive);
  ReadDriveBasicStatus(Drive);
end;

function TDriveInfo.GetImageIndex(Drive: string): Integer;
begin
  NeedData;

  Result := 0;

  if Get(Drive).Valid then
  begin
    if Get(Drive).ImageIndex = 0 then
      ReadDriveStatus(Drive, dsImageIndex);
    Result := Get(Drive).ImageIndex;
  end;
end; {TDriveInfo.GetImageIndex}

function TDriveInfo.GetDisplayName(Drive: string): string;
begin
  if Get(Drive).Valid then
  begin
    if Length(Get(Drive).DisplayName) = 0 then
      ReadDriveStatus(Drive, dsDisplayName);
    Result := Get(Drive).DisplayName;
  end
    else
  begin
    Result := GetSimpleName(Drive);
  end;
end; {TDriveInfo.GetDisplayname}

function TDriveInfo.GetPrettyName(Drive: string): string;
begin
  if Get(Drive).Valid then
  begin
    if Length(Get(Drive).PrettyName) = 0 then
      ReadDriveStatus(Drive, dsDisplayName);
    Result := Get(Drive).PrettyName;
  end
    else
  begin
    Result := GetSimpleName(Drive);
  end;
end; {TDriveInfo.GetPrettyName}

function TDriveInfo.GetSimpleName(Drive: string): string;
begin
  Result := Drive;
  if IsRealDrive(Result) then Result := Result + ':';
end;

function TDriveInfo.Get(Drive: string): TDriveInfoRec;
begin
  NeedData;
  if not FData.TryGetValue(Drive, Result) then
  begin
    Assert(IsUncPath(Drive));
    Result := AddDrive(Drive);
  end;
end; {TDriveInfo.GetData}

function TDriveInfo.ReadDriveStatus(Drive: string; Flags: Integer): Boolean;
var
  ErrorMode: Word;
  FileInfo: TShFileInfo;
  DriveRoot: string;
  DriveID: string;
  CPos: Integer;
  Eaten: ULONG;
  ShAttr: ULONG;
  MaxFileNameLength: DWORD;
  FileSystemFlags: DWORD;
  FreeSpace: Int64;
  SimpleName: string;
  DriveInfoRec: TDriveInfoRec;
  S: string;
begin
  if not Assigned(FDesktop) then
    SHGetDesktopFolder(FDesktop);

  DriveRoot := DriveInfo.GetDriveRoot(Drive);

  // When this method is called, the entry always exists already
  Assert(FData.ContainsKey(Drive));
  DriveInfoRec := FData[Drive];
  with DriveInfoRec do
  begin
    Init := True;
    ReadDriveBasicStatus(Drive);

    if Valid then
    begin
      if (not Assigned(PIDL)) and IsFixedDrive(Drive) then
      begin
        ShAttr := 0;
        if DriveType = DRIVE_REMOTE then
        begin
          ShellFolderParseDisplayNameWithTimeout(
            FDesktop, Application.Handle, nil, PChar(DriveRoot), Eaten, PIDL, ShAttr, 2 * MSecsPerSec);
        end
          else
        begin
          FDesktop.ParseDisplayName(Application.Handle, nil, PChar(DriveRoot), Eaten, PIDL, ShAttr);
        end;
      end;

      {Read driveStatus:}
      if (Flags and dsSize) <> 0 then
      begin
        { turn off critical errors }
        ErrorMode := SetErrorMode(SEM_FailCriticalErrors or SEM_NOOPENFILEERRORBOX);
        try
          DriveReady := GetDiskFreeSpaceEx(PChar(DriveRoot), FreeSpace, Size, nil);
          if DriveReady then
          begin
            {Access the physical drive:}
            if GetVolumeInformation(PChar(DriveRoot), nil, 0,
                 @DriveSerial, MaxFileNameLength, FileSystemFlags,
                 nil, 0) then
            begin
            end
              else
            begin
              DriveSerial := 0;
            end;
          end
            else
          begin
            DriveSerial := 0;
          end;
        finally
          { restore old error mode }
          SetErrorMode(ErrorMode);
        end;
      end;

      {DisplayName:}
      if (Flags and dsDisplayName <> 0) then
      begin
        {Fetch drives displayname:}
        SimpleName := GetSimpleName(Drive);
        if Assigned(PIDL) then DisplayName := GetShellFileName(PIDL)
          else
        begin
          // typical reason we do not have PIDL is that it took too long to
          // call ParseDisplayName, in what case calling SHGetFileInfo with
          // path (instead of PIDL) will take long too, avoiding that and using
          // fallback
          DisplayName := '(' + SimpleName + ')';
        end;

        if DriveType <> DRIVE_REMOTE then
        begin
          PrettyName := SimpleName + ' ' + DisplayName;

          S := ' (' + SimpleName + ')';
          CPos := Pos(S, PrettyName);
          if CPos > 0 then
            Delete(PrettyName, CPos, Length(S));
        end
          else
        if IsRealDrive(Drive) then
        begin
          DriveID := GetNetWorkName(Drive);
          PrettyName := Format('%s %s (%s)', [SimpleName, ExtractFileName(DriveID), ExtractFileDir(DriveID)]);
        end
          else
        begin
          Assert(IsUncPath(DriveRoot));
          PrettyName := SimpleName;
        end;
      end;

      {ImageIndex:}
      if ((Flags and dsImageIndex) <> 0) and (ImageIndex < 5) then
      begin
        if Assigned(PIDL) then
        begin
          SHGetFileInfo(PChar(PIDL), 0, FileInfo, SizeOf(FileInfo), SHGFI_SYSICONINDEX or SHGFI_SMALLICON or SHGFI_PIDL)
        end
          else
        begin
          SHGetFileInfo(PChar(DriveRoot), 0, FileInfo, SizeOf(FileInfo), SHGFI_SYSICONINDEX or SHGFI_SMALLICON);
        end;
        ImageIndex := FileInfo.iIcon;
      end;
    end
      else
    begin
      if Assigned(PIDL) then
        FreePIDL(PIDL);
      ResetDrive(Drive);
    end;
    Result := Valid and DriveReady;
  end;
end; {TDriveInfo.ReadDriveStatus}

function GetShellFileName(const Name: string): string;
var
  SFI: TSHFileInfo;
  E: Integer;
begin
  E := SetErrorMode(SEM_FAILCRITICALERRORS);
  try
    if SHGetFileInfo(PChar(Name), 0, SFI, SizeOf(TSHFileInfo), SHGFI_DISPLAYNAME) <> 0 then
      Result := SFI.szDisplayName;
  finally
    SetErrorMode(E);
  end;
end; {GetShellFileName}

function GetShellFileName(PIDL: PItemIDList): string;
var
  SFI: TSHFileInfo;
  E: Integer;
begin
  E := SetErrorMode(SEM_FAILCRITICALERRORS);
  try
    if SHGetFileInfo(PChar(PIDL), 0, SFI, SizeOf(TSHFileInfo), SHGFI_PIDL or SHGFI_DISPLAYNAME) <> 0 then
      Result := SFI.szDisplayName;
  finally
    SetErrorMode(E);
  end;
end; {GetShellFileName}

function GetNetWorkName(Drive: string): string;
var
  Path: string;
  P: array[0..MAX_PATH] of Char;
  MaxLen : DWORD;
begin
  Path := ExcludeTrailingBackslash(DriveInfo.GetDriveRoot(Drive));
  MaxLen := MAX_PATH;
  if WNetGetConnection(PChar(Path), P, MaxLen) = NO_ERROR then
    Result := P
  else
    Result := '';
end; {GetNetWorkName}

type
  LPBYTE = ^BYTE;
  LMSTR = LPWSTR;
  NET_API_STATUS = DWORD;
  _USE_INFO_1 = record
    ui1_local: LMSTR;
    ui1_remote: LMSTR;
    ui1_password: LMSTR;
    ui1_status: DWORD;
    ui1_asg_type: DWORD;
    ui1_refcount: DWORD;
    ui1_usecount: DWORD;
  end;
  USE_INFO_1 = _USE_INFO_1;
  PUSE_INFO_1 = ^USE_INFO_1;
  LPVOID = Pointer;

const
  USE_OK       = 0;
  USE_PAUSED   = 1;
  USE_SESSLOST = 2;
  USE_DISCONN  = 2;
  USE_NETERR   = 3;
  USE_CONN     = 4;
  USE_RECONN   = 5;

function NetUseGetInfo(UncServerName: LMSTR; UseName: LMSTR; Level: DWORD; var BufPtr: LPBYTE): NET_API_STATUS; stdcall; external 'netapi32.dll';
function NetApiBufferFree(Buffer: Pointer): DWORD; stdcall; external 'netapi32.dll';

function GetNetWorkConnected(Drive: string): Boolean;
var
  BufPtr: LPBYTE;
  NetResult: Integer;
  ServerName: string;
  PServerName: PChar;
  Name: string;
  P: Integer;
begin
  Name := '';
  PServerName := nil;
  if DriveInfo.IsRealDrive(Drive) then
  begin
    Name := Drive + ':';
  end
    else
  if IsUncPath(Drive) then
  begin
    Name := Copy(Drive, 3, Length(Drive) - 2);
    P := Pos('\', Name);
    if P > 0 then
    begin
      ServerName := Copy(Name, P + 1, Length(Name) - P);
      PServerName := PChar(ServerName);
      SetLength(Name, P - 1);
    end
      else
    begin
      Assert(False);
    end;
  end
    else
  begin
    Assert(False);
  end;

  if Name = '' then
  begin
    Result := False;
  end
    else
  begin
    NetResult := NetUseGetInfo(PServerName, PChar(Name), 1, BufPtr);
    if NetResult = 0 then
    begin
      Result := (PUSE_INFO_1(BufPtr)^.ui1_status = USE_OK);
      NetApiBufferFree(LPVOID(BufPtr));
    end
      else
    begin
      // NetUseGetInfo works for DFS shares only, hence when it fails
      // we suppose different share type and fallback to "connected"
      Result := True;
    end;
  end;
end;

function IsRootPath(Path: string): Boolean;
begin
  Result := SameText(ExcludeTrailingBackslash(ExtractFileDrive(Path)), ExcludeTrailingBackslash(Path));
end;

initialization
  if not Assigned(DriveInfo) then
    DriveInfo := TDriveInfo.Create;

finalization
  if Assigned(DriveInfo) then
  begin
    DriveInfo.Free;
    DriveInfo := nil;
  end;
end.
