; Inno Setup script for Draftdown
; Compile with: iscc windows\installer\draftdown.iss

#ifndef MyAppVersion
  #define MyAppVersion "1.2.0"
#endif

#ifndef MyAppArch
  #define MyAppArch "x64"
#endif

#ifndef MyAppBuildDir
  #define MyAppBuildDir "..\..\build\windows\" + MyAppArch + "\runner\Release"
#endif

#define MyAppName "Draftdown"
#define MyAppPublisher "Draftdown"
#define MyAppExeName "draftdown.exe"

[Setup]
AppId={{8B6A1F42-5E3C-4B9A-9D12-4F8E7A2C1B09}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=..\..\LICENSE
OutputDir=..\..\build\installer
OutputBaseFilename=Draftdown-Setup-{#MyAppArch}-{#MyAppVersion}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ChangesAssociations=yes
#if MyAppArch == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "assocmd"; Description: "Associate .md files with {#MyAppName}"; GroupDescription: "File associations:"; Flags: unchecked

[Files]
Source: "{#MyAppBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKA; Subkey: "Software\Classes\.md\OpenWithProgids"; ValueType: string; ValueName: "Draftdown.md"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assocmd
Root: HKA; Subkey: "Software\Classes\Draftdown.md"; ValueType: string; ValueName: ""; ValueData: "Markdown Document"; Flags: uninsdeletekey; Tasks: assocmd
Root: HKA; Subkey: "Software\Classes\Draftdown.md\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: assocmd
Root: HKA; Subkey: "Software\Classes\Draftdown.md\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: assocmd

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
