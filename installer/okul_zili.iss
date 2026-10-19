; Okul Zili - Windows kurulum betiği (Inno Setup 6)
;
; Kullanıcı başına kurulur (yönetici izni gerekmez); böylece "açılışta başlat"
; kaydı, uygulamayı kullanacak Windows kullanıcısına yazılır.
; GitHub Actions'ta derlenir: .github/workflows/windows.yml

#ifndef MyAppVersion
  #define MyAppVersion "0.7.0"
#endif
#define MyAppName "Okul Zili"
#define MyAppDeveloper "İrfan Yücel ÜZÜM"
#define MyAppURL "https://github.com/irfanyuceluzum/okul-zili"
#define MyAppExe "okul_zili.exe"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{6E0F3B52-7A41-4C7B-9C55-0B6E2D3F1A10}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppDeveloper}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}/releases
AppCopyright=Copyright (C) 2026 {#MyAppDeveloper}. GPL-3.0
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\build\installer
OutputBaseFilename=OkulZili-Kurulum-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExe}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Tasks]
Name: "autostart"; Description: "Bilgisayar açılınca Okul Zili'ni otomatik başlat (önerilir)"; GroupDescription: "Başlatma:"
Name: "desktopicon"; Description: "Masaüstüne kısayol oluştur"; GroupDescription: "Kısayollar:"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"
Name: "{group}\{#MyAppName} kaldır"; Filename: "{uninstallexe}"
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; Tasks: desktopicon

[Registry]
; Uygulamanın Ayarlar sayfasındaki anahtarla aynı kayıt.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "OkulZili"; ValueData: """{app}\{#MyAppExe}"" --autostart"; Tasks: autostart; Check: KeepAutostartChoice; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#MyAppExe}"; Description: "Okul Zili'ni şimdi başlat"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
const
  RunKey = 'Software\Microsoft\Windows\CurrentVersion\Run';
  UninstallKey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{6E0F3B52-7A41-4C7B-9C55-0B6E2D3F1A10}_is1';

// Önceden kurulmuş mu (güncelleme mi)?
function IsUpgrade(): Boolean;
begin
  Result := RegKeyExists(HKCU, UninstallKey);
end;

function AutostartEnabledNow(): Boolean;
begin
  Result := RegValueExists(HKCU, RunKey, 'OkulZili');
end;

// Güncellemede, uygulamanın Ayarlar sayfasında kapatılmış otomatik
// başlatmayı yeniden açma: seçenek mevcut duruma göre işaretlenir.
procedure CurPageChanged(CurPageID: Integer);
begin
  if (CurPageID = wpSelectTasks) and IsUpgrade() and not AutostartEnabledNow() then
    WizardSelectTasks('!autostart');
end;

// Sessiz kurulumda görev sayfası görünmez; o durumda da mevcut ayar korunur.
function KeepAutostartChoice(): Boolean;
begin
  if WizardSilent() and IsUpgrade() then
    Result := AutostartEnabledNow()
  else
    Result := True;
end;

// Uygulama pencere kapatılınca kapanmayıp sistem tepsisinde kaldığı için
// güncelleme ve kaldırma öncesinde süreç sonlandırılır.
procedure StopRunningApp();
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM {#MyAppExe}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  StopRunningApp();
  Result := '';
end;

function InitializeUninstall(): Boolean;
begin
  StopRunningApp();
  Result := True;
end;
