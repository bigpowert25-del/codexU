[Setup]
AppName=codexU Island
AppVersion=1.0.0
AppPublisher=Sadeesha Sathsara
DefaultDirName={autopf}\codexU Island
DefaultGroupName=codexU Island
UninstallDisplayIcon={app}\CodexUIsland.exe
Compression=lzma2
SolidCompression=yes
OutputDir=.
OutputBaseFilename=DynamicIslandSetup_v1.0.0_arm64
PrivilegesRequired=lowest
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64

[Files]
Source: "publish-arm64\CodexUIsland.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish-arm64\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\codexU Island"; Filename: "{app}\CodexUIsland.exe"
Name: "{autodesktop}\codexU Island"; Filename: "{app}\CodexUIsland.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "CodexUIsland"; ValueData: """{app}\CodexUIsland.exe"""; Flags: uninsdeletevalue

[Run]
Filename: "{app}\CodexUIsland.exe"; Description: "{cm:LaunchProgram,codexU Island}"; Flags: nowait postinstall skipifsilent
