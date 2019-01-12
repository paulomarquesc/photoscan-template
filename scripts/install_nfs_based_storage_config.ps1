param
(
    [Parameter(Mandatory=$true)]
    [string]$nfsMapDriveLetter, # E.g. z:

    [Parameter(Mandatory=$true)]
    [string]$NfsExportPathUNC,

    [Parameter(Mandatory=$true)]
    [int]$HpcUserID,

    [Parameter(Mandatory=$true)]
    [int]$HpcGroupID,

    [Parameter(Mandatory=$false)]
    [string]$MountType="hard", # Valid values are "hard" and "soft"

    [Parameter(Mandatory=$false)]
    [string]$CaseSensitiveLookup="false",

    [Parameter(Mandatory=$false)]
    [int]$Timeout=60,

    [Parameter(Mandatory=$false)]
    [int]$MountRetry=3,

    [Parameter(Mandatory=$false)]
    [int]$DefaultAccessMode=777,

    [Parameter(Mandatory=$false)]
    [int]$RSizeKB=512, # Windows max out at 1024KB - with Avere vFXT it max out at 512

    [Parameter(Mandatory=$false)]
    [int]$WSizeKB=512 # Windows max out at 1024KB - with Avere vFXT it max out at 512
)

$ErrorActionPreference="Stop"

$LocalMountScriptFolder = "C:\MountScript"
$MountScriptName = "mountnfs.bat"
$MountScriptNameFullName = [system.io.path]::Combine($LocalMountScriptFolder, $MountScriptName)
$BlnCaseSensitiveLookup = [System.Convert]::ToBoolean($CaseSensitiveLookup)
$Drive = [system.io.path]::GetPathRoot($nfsMapDriveLetter).Replace("/",$null).Replace("\",$null)
$Root = "$drive/"

function ConfigureMountScriptRun
{
    # All new users
    Invoke-Expression "reg load hklm\defaultuser C:\USERS\DEFAULT\NTUSER.DAT"
    Invoke-Expression "reg add ""hklm\defaultuser\Software\Microsoft\Windows\CurrentVersion\Run"" /v MountNfs /d $MountScriptNameFullName /t REG_SZ /f"
    Invoke-Expression "reg unload hklm\defaultuser"

    # Current user
    Invoke-Expression "reg add ""hkcu\Software\Microsoft\Windows\CurrentVersion\Run"" /v MountNfs /d $MountScriptNameFullName /t REG_SZ /f"

    # Schedule task to execute mount as system as well if this is a node

    $PhotoscanProcessName = "photoscan.exe"
    $PhotoscanProcess = Get-WmiObject Win32_Process -Filter "name = '$PhotoscanProcessName'" | Select-Object CommandLine

    if ($PhotoscanProcess -ne $null -and $PhotoscanProcess.CommandLine.contains("--node"))
    {
        schtasks /create /tn "mount_nfs" /tr "C:\MountScript\mountnfs.bat" /sc onstart /RU SYSTEM /RL HIGHEST
        schtasks /run /tn "mount_nfs"
    }
}

function InstallNfsClient
{
    Add-WindowsFeature -Name NFS-Client
}

function ConfigureNfsClient
{
    Set-NfsClientConfiguration -MountType $MountType -CaseSensitiveLookup:$BlnCaseSensitiveLookup -MountRetryAttempts $MountRetry -RpcTimeoutSec $Timeout -ReadBufferSize $RSizeKB -WriteBufferSize $WSizeKB -DefaultAccessMode $DefaultAccessMode

    nfsadmin client config casesensitive=yes
    
    Invoke-Expression "reg add ""hklm\SOFTWARE\Microsoft\ClientForNFS\CurrentVersion\Default"" /v AnonymousGid /d $HpcUserID /t REG_DWORD /f"
    Invoke-Expression "reg add ""hklm\SOFTWARE\Microsoft\ClientForNFS\CurrentVersion\Default"" /v AnonymousUid /d $HpcGroupID /t REG_DWORD /f"
    
    nfsadmin client stop
    nfsadmin client start

    if (! (Test-Path $LocalMountScriptFolder))
    {
        mkdir $LocalMountScriptFolder
    }

    "mount -o anon nolock casesensitive=$(@{$true = "yes"; $false = "no"}[$BlnCaseSensitiveLookup -eq $true]) timeout=$timeout mtype=$MountType rsize=$RSizeKB wsize=$WSizeKB $drive $NfsExportPathUNC" | out-file $MountScriptNameFullName -Encoding ascii
    "mount > c:\mountscript\%username%-mount.txt" | out-file $MountScriptNameFullName -Encoding ascii -Append
    "reg query `"hkcu\SOFTWARE\Agisoft\PhotoScan Pro\main\network`" > c:\mountscript\%username%-hkcu.txt" | out-file $MountScriptNameFullName -Encoding ascii -Append
}

function ModifyDefaultPhotoscanRegKey
{

    # All new users
    Invoke-Expression "reg load hklm\defaultuser C:\USERS\DEFAULT\NTUSER.DAT"
   
    Invoke-Expression "reg add ""hklm\defaultuser\Software\Agisoft\PhotoScan Pro\main\network"" /v root_path /d $Root /f"

    Invoke-Expression "reg unload hklm\defaultuser"

    # Current user
    Invoke-Expression "reg add ""hkcu\Software\Agisoft\PhotoScan Pro\main\network"" /v root_path /d $Root /f"
}

$SetupMarker=[system.io.path]::Combine($env:TEMP,"install_nfs_based_storage_config.marker")
if (Test-Path $SetupMarker)
{
    Write-Verbose "We're already configured, exiting..." -Verbose
    Exit 0
}

InstallNfsClient
ConfigureNfsClient
ConfigureMountScriptRun
ModifyDefaultPhotoscanRegKey

"Done" | Out-File $SetupMarker