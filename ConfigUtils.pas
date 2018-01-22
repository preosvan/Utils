unit ConfigUtils;

interface

uses
  System.IniFiles, System.SysUtils, VCL.Forms, WinApi.Windows;

type
  TJetPathCustom = class
  private const
    //DirName
    FDNJetFile: string = 'JetFile';
    FDNImaging: string = 'Imaging';
    FDNConfig: string = 'Config';
    FDNStamps: string = 'Stamps';
    FDNLogs: string = 'Logs';
    //FileName
    FFNTxtRepoXml: string = 'TxtRepo.xml';
    FFNPrefsDat: string = 'preferences.dat';
    FFNHistDat: string = 'history.dat';
    FFNThumbsDat: string = 'thumbs.dat';
    FFNJfimLog: string = 'jfim.log';
    FFNJetFileLog: string = 'JetFile.log';
    FFNColorThemesXml: string = 'ColorThemes.xml';
  public
    //Dir
    class function GetUserProfilePath: string; virtual; abstract;
    class function GetJetPath: string;
    class function GetJetImagingPath: string;
    class function GetJetConfigPath: string;
    class function GetJetStampsPath: string;
    class function GetJetLogPath: string;
    class function GetJetImagingLogPath: string;
    //Files
    class function GetTxtRepoPathToFile: string;
    class function GetPrefsPathToFile: string;
    class function GetHistPathToFile: string;
    class function GetThumbsPathToFile: string;
    class function GetJfimLogPathToFile: string;
    class function GetJetFileLogPathToFile: string;
    class function GetColorThemesXmlPathToFile: string;
  end;

  TJetPathLocal = class(TJetPathCustom)
  public
    class function GetUserProfilePath: string; override;
  end;

  TJetPathShared = class(TJetPathCustom)
  public
    class function GetUserProfilePath: string; override;
  end;

  TCustomConfig = class
  private
    FIniFile: TIniFile;
  public
    constructor Create(APathToConfig: string);
    destructor Destroy; override;
    procedure Apply; virtual; abstract;
    procedure Load; virtual; abstract;
    property IniFile: TIniFile read FIniFile;
  end;

  TTextRepoConfig = class(TCustomConfig)
  private
    FPathToRepoXmlLocal: string;
    FPathToRepoXmlShared: string;
    const
      //Sections
      FSectionGeneral: string = 'GENERAL';
      //Keys
      FKeyPathToRepoXmlLocal: string = 'PathToRepoXmlLocal';
      FKeyPathToRepoXmlShared: string = 'PathToRepoXmlShared';
    function GetPathToRepoXmlLocal: string;
    function GetPathToRepoXmlShared: string;
  public
    procedure ReplaceSharedPath;
    procedure Apply; override;
    procedure Load; override;
    property PathToRepoXmlLocal: string read GetPathToRepoXmlLocal;
    property PathToRepoXmlShared: string read GetPathToRepoXmlShared write FPathToRepoXmlShared;
  end;

  TJFIMConfig = class(TCustomConfig)
  private
    FPathToStampsShared: string;
    FPathToStampsLocal: string;
    function GetPathToStampsLocal: string;
    function GetPathToStampsShared: string;
    const
      //Sections
      FSectionStamps: string = 'STAMPS';
      //Keys
      FKeyPathToStampsLocal: string = 'PathToStampsLocal';
      FKeyPathToStampsShared: string = 'PathToStampsShared';
  public
    procedure Apply; override;
    procedure Load; override;
    property PathToStampsLocal: string read GetPathToStampsLocal write FPathToStampsLocal;
    property PathToStampsShared: string read GetPathToStampsShared write FPathToStampsShared;
  end;

  procedure SaveFormPosition(AForm: TForm; AIniFile: TIniFile);
  procedure RestoreFormPosition(AForm: TForm; AIniFile: TIniFile);

const
  FN_JFIM_CONFIG_INI = 'JFIM.ini';
  FN_REPO_CONFIG_INI = 'RepoConfig.ini';

  KEY_TOP = 'Top';
  KEY_LEFT = 'Left';
  KEY_HEIGHT = 'Height';
  KEY_WIDTH = 'Width';
  KEY_STATE = 'State';

var
  JFIMConfig: TJFIMConfig;

implementation

uses
  System.IOUtils, Vcl.Dialogs, System.RegularExpressions;

procedure SaveFormPosition(AForm: TForm; AIniFile: TIniFile);
var
  State: Integer;         // state of window
  Pl: TWindowPlacement;   // used for API call
  R: TRect;               // used for window pos
  IniS: string;
begin
  if Assigned(AForm) and Assigned(AIniFile) then
  begin
    IniS := AForm.ClassName;
    if SameText(copy(IniS, 1, 4), 'Tfrm') then
      IniS := Copy(IniS, 5, Length(IniS) - 4);

    Pl.Length := SizeOf(TWindowPlacement);
    GetWindowPlacement(AForm.Handle, @Pl);
    R := Pl.rcNormalPosition;

    AIniFile.WriteInteger(IniS, KEY_WIDTH, R.Right - R.Left);
    AIniFile.WriteInteger(IniS, KEY_HEIGHT, R.Bottom - R.Top);
    AIniFile.WriteInteger(IniS, KEY_LEFT, R.Left);
    AIniFile.WriteInteger(IniS, KEY_TOP, R.Top);

    if IsIconic(Application.Handle) then
      //minimised - write that state
      State := Ord(wsMinimized)
    else
      //not minimised - we can rely on window state of form
      State := Ord(AForm.WindowState);
    AIniFile.WriteInteger(IniS, KEY_STATE, State);
  end;
end;

procedure RestoreFormPosition(AForm: TForm; AIniFile: TIniFile);
var
  State: Integer;   // state of window
  IniS: string;
  t, l, w, h: Word;
  CenterIt: Boolean;
begin
  if Assigned(AForm) and Assigned(AIniFile) then
  begin
    IniS := AForm.ClassName;
    if SameText(copy(IniS, 1, 4),  'Tfrm') then
      IniS := copy(IniS, 5, Length(IniS) - 4);

    w := AIniFile.ReadInteger(IniS, KEY_WIDTH,  AForm.Width);
    h := AIniFile.ReadInteger(IniS, KEY_HEIGHT,  AForm.Height);
    l := AIniFile.ReadInteger(IniS, KEY_LEFT, AForm.Left);
    t := AIniFile.ReadInteger(IniS, KEY_TOP,  AForm.Top);

    CenterIt := (t > Screen.Height) or (l > Screen.Width);  //If outside screen bounds on top-left then center
    if CenterIt then
    begin
      w := AForm.Width;
      h := AForm.Height;
      l := Trunc((Screen.Width  - w) / 2);
      t := Trunc((Screen.Height - h) / 2);
    end;

    AForm.SetBounds(l, t, w, h);

    State := AIniFile.ReadInteger(IniS, KEY_STATE,  Ord(wsNormal));
    if State = Ord(wsMinimized) then
    begin
      AForm.Visible := True;
      Application.Minimize;
    end
    else
      AForm.WindowState := TWindowState(State);
  end;
end;

{ TCustomConfig }

constructor TCustomConfig.Create(APathToConfig: string);
begin
  FIniFile := TIniFile.Create(APathToConfig);
  Load;
end;

destructor TCustomConfig.Destroy;
begin
  Apply;
  FreeAndNil(FIniFile);
  inherited;
end;

{ TTextRepoConfig }

procedure TTextRepoConfig.Apply;
begin
  IniFile.WriteString(FSectionGeneral, FKeyPathToRepoXmlLocal, FPathToRepoXmlLocal);
  IniFile.WriteString(FSectionGeneral, FKeyPathToRepoXmlShared, FPathToRepoXmlShared);
end;

function TTextRepoConfig.GetPathToRepoXmlLocal: string;
begin
  Result := FPathToRepoXmlLocal.Replace('%userprofile%' + PathDelim,
    TJetPathLocal.GetUserProfilePath);
end;

function TTextRepoConfig.GetPathToRepoXmlShared: string;
begin
  Result := FPathToRepoXmlShared.Replace('%userprofile%' + PathDelim,
    TJetPathShared.GetUserProfilePath);
end;

procedure TTextRepoConfig.Load;
begin
  FPathToRepoXmlLocal := IniFile.ReadString(FSectionGeneral,
    FKeyPathToRepoXmlLocal, TJetPathLocal.GetTxtRepoPathToFile);
  FPathToRepoXmlShared := IniFile.ReadString(FSectionGeneral,
    FKeyPathToRepoXmlShared, TJetPathShared.GetTxtRepoPathToFile);
end;

procedure TTextRepoConfig.ReplaceSharedPath;
var
  RepoCfgShared: TTextRepoConfig;
  PathToIni: string;
begin
  PathToIni := TPath.GetDirectoryName(PathToRepoXmlShared) + PathDelim + FN_REPO_CONFIG_INI;
  RepoCfgShared := TTextRepoConfig.Create(PathToIni);
  try
    if FileExists(RepoCfgShared.PathToRepoXmlShared) then
      PathToRepoXmlShared := RepoCfgShared.PathToRepoXmlShared
    else if FileExists(PathToRepoXmlShared) then
      RepoCfgShared.PathToRepoXmlShared := PathToRepoXmlShared;
  finally
    FreeAndNil(RepoCfgShared);
  end;
end;

class function TJetPathCustom.GetColorThemesXmlPathToFile: string;
begin
  Result := GetJetPath + FFNColorThemesXml;
end;

class function TJetPathCustom.GetHistPathToFile: string;
begin
  Result := GetJetConfigPath + FFNHistDat;
end;

class function TJetPathCustom.GetJetConfigPath: string;
begin
  Result := GetJetImagingPath + FDNConfig + PathDelim;
  ForceDirectories(Result);
end;

class function TJetPathCustom.GetJetFileLogPathToFile: string;
begin
  Result := GetJetLogPath + FFNJetFileLog;
end;

class function TJetPathCustom.GetJetStampsPath: string;
begin
  Result := GetJetImagingPath + FDNStamps + PathDelim;
  ForceDirectories(Result);
end;

class function TJetPathCustom.GetJfimLogPathToFile: string;
begin
  Result := GetJetImagingLogPath + FFNJfimLog;
end;

class function TJetPathCustom.GetPrefsPathToFile: string;
begin
  Result := GetJetConfigPath + FFNPrefsDat;
end;

class function TJetPathCustom.GetJetImagingPath: string;
begin
  Result := GetJetPath + FDNImaging + PathDelim;
  ForceDirectories(Result);
end;

class function TJetPathCustom.GetJetLogPath: string;
begin
  Result := GetJetPath + FDNLogs + PathDelim;
  ForceDirectories(Result);
end;

class function TJetPathCustom.GetJetImagingLogPath: string;
begin
  Result := GetJetImagingPath + FDNLogs + PathDelim;
  ForceDirectories(Result);
end;

class function TJetPathCustom.GetJetPath: string;
begin
  Result := GetUserProfilePath + FDNJetFile + PathDelim;
  ForceDirectories(Result);
end;

class function TJetPathCustom.GetThumbsPathToFile: string;
begin
  Result := GetJetConfigPath + FFNThumbsDat;
end;

class function TJetPathCustom.GetTxtRepoPathToFile: string;
begin
  Result := GetJetConfigPath + FFNTxtRepoXml;
end;

{ TJFIMConfig }

procedure TJFIMConfig.Apply;
begin
  IniFile.WriteString(FSectionStamps, FKeyPathToStampsLocal, PathToStampsLocal);
  IniFile.WriteString(FSectionStamps, FKeyPathToStampsShared, PathToStampsShared);
end;

function TJFIMConfig.GetPathToStampsLocal: string;
begin
  Result := FPathToStampsLocal;
  ForceDirectories(Result);
end;

function TJFIMConfig.GetPathToStampsShared: string;
begin
  Result := FPathToStampsShared;
  ForceDirectories(Result);
end;

procedure TJFIMConfig.Load;
begin
  FPathToStampsLocal := IniFile.ReadString(FSectionStamps,
    FKeyPathToStampsLocal, TJetPathLocal.GetJetStampsPath);
  FPathToStampsShared := IniFile.ReadString(FSectionStamps,
    FKeyPathToStampsShared, TJetPathShared.GetJetStampsPath);
end;

class function TJetPathLocal.GetUserProfilePath: string;
begin
  Result := GetEnvironmentVariable('USERPROFILE') + PathDelim;
  // Result := TPath.GetDocumentsPath + PathDelim;
  ForceDirectories(Result);
end;

class function TJetPathShared.GetUserProfilePath: string;
begin
  Result := TPath.GetSharedDocumentsPath + PathDelim;
  ForceDirectories(Result);
end;

initialization
  JFIMConfig := TJFIMConfig.Create(TJetPathLocal.GetJetConfigPath + FN_JFIM_CONFIG_INI);

finalization
  FreeAndNil(JFIMConfig);

end.
