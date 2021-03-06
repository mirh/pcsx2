; PCSX2 Pre-Installer Script
; Copyright (C) 2019 PCSX2 Team

!include "SharedDefs.nsh"

RequestExecutionLevel user

!define OUTFILE_POSTFIX "setup"
OutFile "pcsx2-${APP_VERSION}-${OUTFILE_POSTFIX}.exe"

Var UserPrivileges
Var IsAdmin
Var DirectXSetupError

; Dialogs and Controls
Var hwnd
Var PreInstall_Dialog
Var PreInstall_DlgBack
Var PreInstall_DlgNext

Var InstallMode_Dialog
Var InstallMode_DlgBack
Var InstallMode_DlgNext
Var InstallMode_Label

# Normal installer mode (writes to Program Files)
Var InstallMode_Normal

# Portable installer mode
Var InstallMode_Portable

!include "nsDialogs.nsh"

Page Custom IsUserAdmin
Page Custom PreInstallDialog
Page Custom InstallMode InstallModeLeave

Function IsUserAdmin
!include WinVer.nsh
# No user should ever have to experience this pain ;)
  ${IfNot} ${AtLeastWinVista}
    MessageBox MB_OK "Your operating system is unsupported by PCSX2. Please upgrade your operating system or install PCSX2 1.4.0."
    Quit
  ${EndIf}

ClearErrors
UserInfo::GetName
  Pop $R8

UserInfo::GetOriginalAccountType
Pop $UserPrivileges

  # GetOriginalAccountType will check the tokens of the original user of the
  # current thread/process. If the user tokens were elevated or limited for
  # this process, GetOriginalAccountType will return the non-restricted
  # account type.
  # On Vista with UAC, for example, this is not the same value when running
  # with `RequestExecutionLevel user`. GetOriginalAccountType will return
  # "admin" while GetAccountType will return "user".
  ;UserInfo::GetOriginalAccountType
  ;Pop $R2

${If} $UserPrivileges == "Admin"
    StrCpy $IsAdmin 1
    ${ElseIf} $UserPrivileges == "User"
    StrCpy $IsAdmin 0
${EndIf}
FunctionEnd

Function PreInstallDialog

nsDialogs::Create /NOUNLOAD 1018
Pop $PreInstall_Dialog

    GetDlgItem $PreInstall_DlgBack $HWNDPARENT 3
    EnableWindow $PreInstall_DlgBack ${SW_HIDE}

    GetDlgItem $PreInstall_DlgNext $HWNDPARENT 1
    EnableWindow $PreInstall_DlgNext 0

  ${NSD_CreateTimer} NSD_Timer.Callback 1

nsDialogs::Show
FunctionEnd

Function NSD_Timer.Callback
${NSD_KillTimer} NSD_Timer.Callback
    SendMessage $hwnd ${PBM_SETRANGE32} 0 100

!include WinVer.nsh
!include "X64.nsh" 

# If the user is running at least Windows 8.1
# or has no admin rights, don't waste time trying
# to install the DX and VS runtimes.
# (head straight to the first installer section)
${If} ${AtLeastWin8.1}
${OrIf} $IsAdmin == 0
Call PreInstall_UsrWait
SendMessage $HWNDPARENT ${WM_COMMAND} 1 0
${EndIf}

# Check if the VC runtimes are installed
${If} ${RunningX64}
ReadRegDword $R0 HKLM "SOFTWARE\Wow6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x86" "Installed"
${Else}
   ReadRegDword $R0 HKLM "SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86" "Installed"
${EndIf}
    Pop $R0

# If the runtimes are already here, check for DX.
${If} $R0 == "1"
Goto ExecDxSetup
${EndIf}

# Download and install the VC redistributable from the internet
${NSD_CreateLabel} 0 45 100% 10u "Downloading Visual C++ package"
Pop $hwnd
inetc::get "https://aka.ms/vs/16/release/VC_redist.x86.exe" "$TEMP\vcredist_Update_x86.exe" /SILENT /CONNECTTIMEOUT 30 /RECEIVETIMEOUT 30 /END
    ${NSD_CreateLabel} 0 45 100% 10u "Installing Visual C++ package"
    Pop $hwnd
    ExecWait '"$TEMP\vcredist_Update_x86.exe /S"'
    SendMessage $hwnd ${PBM_SETPOS} 40 0
    Delete "$TEMP\vcredist_Update_x86.exe"


# Download and install DirectX
ExecDxSetup:
${NSD_CreateLabel} 0 45 100% 10u "Installing DXWebSetup package"
Pop $hwnd
SendMessage $hwnd ${PBM_SETPOS} 80 0

SetOutPath "$TEMP"
File "dxwebsetup.exe"
ExecWait '"$TEMP\dxwebsetup.exe" /Q' $DirectXSetupError

SendMessage $hwnd ${PBM_SETPOS} 100 0
Delete "$TEMP\dxwebsetup.exe"
Sleep 20
    Call PreInstall_UsrWait
SendMessage $HWNDPARENT ${WM_COMMAND} 1 0
FunctionEnd

Function PreInstall_UsrWait
GetDlgItem $PreInstall_DlgNext $HWNDPARENT 1
EnableWindow $PreInstall_DlgNext 1
FunctionEnd

# Creates the first dialog "section" to display a choice of installer modes.
Function InstallMode
nsDialogs::Create /NOUNLOAD 1018
Pop $InstallMode_Dialog

GetDlgItem $InstallMode_DlgBack $HWNDPARENT 3
EnableWindow $InstallMode_DlgBack 0

GetDlgItem $InstallMode_DlgNext $HWNDPARENT 1
EnableWindow $InstallMode_DlgNext 0

${NSD_CreateLabel} 0 0 100% 10u "Select an installation mode for PCSX2."
Pop $InstallMode_Label

${NSD_CreateRadioButton} 0 35 100% 10u "Normal Installation"
Pop $InstallMode_Normal

# If the user doesn't have admin rights, disable the button for the normal (non-portable) installer
${If} $IsAdmin == 0
EnableWindow $InstallMode_Normal 0
${EndIf}

# Create labels/buttons for the normal installation
${NSD_OnClick} $InstallMode_Normal InstallMode_UsrWait
${NSD_CreateLabel} 10 55 100% 20u "PCSX2 will be installed in Program Files unless another directory is specified. User files are stored in the Documents/PCSX2 directory."

# Create labels/buttons for the portable installation
${NSD_CreateRadioButton} 0 95 100% 10u "Portable Installation"
Pop $InstallMode_Portable
${NSD_OnClick} $InstallMode_Portable InstallMode_UsrWait
${NSD_CreateLabel} 10 115 100% 20u "Install PCSX2 to any directory you want. Choose this option if you prefer to have all of your files in the same folder or frequently update PCSX2 through Orphis' Buildbot."

nsDialogs::Show

FunctionEnd

# Disables the "next" button until a selection has been made
Function InstallMode_UsrWait
GetDlgItem $InstallMode_DlgNext $HWNDPARENT 1
EnableWindow $InstallMode_DlgNext 1

# Displays a UAC shield on the button
${NSD_GetState} $InstallMode_Normal $0
${NSD_GetState} $InstallMode_Portable $1

${If} ${BST_CHECKED} == $0
SendMessage $InstallMode_DlgNext ${BCM_SETSHIELD} 0 1
${Else}
SendMessage $InstallMode_DlgNext ${BCM_SETSHIELD} 0 0
${EndIf}

FunctionEnd

# Runs the elevated installer and quits the current one
# If they chose portable mode, the current (unelevated installer)
# will still be used.
Function InstallModeLeave
${NSD_GetState} $InstallMode_Normal $0
${NSD_GetState} $InstallMode_Portable $1

${If} ${BST_CHECKED} == $0
SetOutPath "$TEMP"
File "pcsx2-${APP_VERSION}-include_standard.exe"
ExecShell open "$TEMP\pcsx2-${APP_VERSION}-include_standard.exe"
Quit
${EndIf}
FunctionEnd

; ----------------------------------
;     Portable Install Section
; ----------------------------------
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_RUN "$INSTDIR\pcsx2.exe"
!define MUI_PAGE_CUSTOMFUNCTION_SHOW ModifyRunCheckbox
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_LANGUAGE "English"
!include "ApplyExeProps.nsh"

; The default installation directory for the portable binary.
InstallDir "$DOCUMENTS\$R8\PCSX2 ${APP_VERSION}"

; Files to be installed are housed here
!include "SharedCore.nsh"

Section "" INST_PORTABLE
SetOutPath "$INSTDIR"
File portable.ini
SectionEnd

Section "" SID_PCSX2
SectionEnd

# Gives the user a fancy checkbox to run PCSX2 right from the installer!
Function ModifyRunCheckbox
${IfNot} ${SectionIsSelected} ${SID_PCSX2}
    SendMessage $MUI.FINISHPAGE.RUN ${BM_SETCHECK} ${BST_UNCHECKED} 0
    EnableWindow $MUI.FINISHPAGE.RUN 0
${EndIf}
FunctionEnd