param
(
    [Parameter(Mandatory=$true)]
    [string]$ActivationCode,

    [Parameter(Mandatory=$false)]
    [string]$DownloadUrl="http://download.agisoft.com/photoscan-pro_1_4_4_x64.msi",
    
    [Parameter(Mandatory=$true)]
    [ValidateSet('Server','Node')]
    [string]$Role,
    
    [Parameter(Mandatory=$true)]
    [string]$Dispatch,
    
    [Parameter(Mandatory=$true,ParameterSetName="Server")]
    [string]$Control,
    
    [Parameter(Mandatory=$true,ParameterSetName="Node")]
    [int]$GpuMask,
    
    [Parameter(Mandatory=$true)]
    [string]$Root,

    [Parameter(Mandatory=$false)]
    [int]$AbsolutePaths=0,

    [Parameter(Mandatory=$false)]
    [int]$ClientCommPort=5841
)

$ErrorActionPreference="Stop"

$scriptPath = ([System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition))
$localInstallPath = Join-Path $scriptPath ([system.io.path]::GetFileName($DownloadUrl))
$InstalledPhotoScanPath="C:\program files\agisoft\photoscan pro"
$PhotoScanExecutable="photoscan.exe"

function DownloadPhotoScan
{
    Write-Verbose "Downloading photoscan from $DownloadUrl..." -Verbose
    $client = new-object System.Net.WebClient 
    $client.DownloadFile($DownloadUrl, $localInstallPath) 
}

function InstallPhotoscan
{
    #Install it via MSI
    Write-Verbose "Installing via MSIEXEC (localInstallPath $localInstallPath)..." -Verbose
    & cmd /c "msiexec.exe /i $localInstallPath" "/qn"
}

function ActivatePhotoscan
{
    # Activate
    Write-Verbose "Activating Photoscan..." -Verbose

    & $(Join-Path $InstalledPhotoScanPath $PhotoScanExecutable) --activate $ActivationCode
}

function ConfigurePhotoscan
{
    # Configuration
    if ($Role -ieq "server")
    {
        Write-Verbose "Creating service with SC CREATE" -Verbose
        & cmd /c "sc" "create" "PhotoScanServer" "binpath=" "C:\Program Files\Agisoft\PhotoScan Pro\photoscan --service run --server --dispatch $Dispatch --control $Control --root $Root --absolute_paths $AbsolutePaths" "start=" "delayed-auto" "DisplayName=" "Agisoft Photoscan Pro Server"

        Write-Verbose "Enabling Firewall Port $ClientCommPort" -Verbose
        New-NetFirewallRule -DisplayName 'PhotoscanServerPort' -Profile @('Domain', 'Private') -Direction Inbound -Action Allow -Protocol TCP -LocalPort @($ClientCommPort)
        Start-Service PhotoScanServer
    }
    else
    {
        & cmd /c "sc" "create" "PhotoScanClient" "binpath=" "C:\Program Files\Agisoft\PhotoScan Pro\photoscan --service run --node --dispatch $Dispatch --root $Root --gpu_mask $GpuMask --absolute_paths $AbsolutePaths" "start=" "delayed-auto" "DisplayName=" "Agisoft Photoscan Pro Node"
        #New-NetFirewallRule -DisplayName 'PhotoscanServerPort' -Profile @('Domain', 'Private') -Direction Inbound -Action Allow -Protocol TCP -LocalPort @($ClientCommPort)
        Start-Service PhotoScanClient
    }
}

function ConfigureDefaultPhotoscanRegKey
{

    # All new users
    Invoke-Expression "reg load hklm\defaultuser C:\USERS\DEFAULT\NTUSER.DAT"
   
    Invoke-Expression "reg add ""hklm\defaultuser\Software\Agisoft\PhotoScan Pro\main\network"" /v root_path /d $Root /f"
    Invoke-Expression "reg add ""hklm\defaultuser\Software\Agisoft\PhotoScan Pro\main\network"" /v host /d $Dispatch /f"
    Invoke-Expression "reg add ""hklm\defaultuser\Software\Agisoft\PhotoScan Pro\main\network"" /v enable /d 1 /t REG_DWORD /f"
    Invoke-Expression "reg add ""hklm\defaultuser\Software\Agisoft\PhotoScan Pro\main\network"" /v parallel_build_dense_cloud /d 1 /t REG_DWORD /f"
    Invoke-Expression "reg add ""hklm\defaultuser\Software\Agisoft\PhotoScan Pro\main\network"" /v parallel_build_tiled_model /d 1 /t REG_DWORD /f"
    Invoke-Expression "reg add ""hklm\defaultuser\Software\Agisoft\PhotoScan Pro\main\network"" /v parallel_build_orthomosaic /d 1 /t REG_DWORD /f"
    Invoke-Expression "reg add ""hklm\defaultuser\Software\Agisoft\PhotoScan Pro\main\network"" /v parallel_build_depth_maps /d 1 /t REG_DWORD /f"
    Invoke-Expression "reg add ""hklm\defaultuser\Software\Agisoft\PhotoScan Pro\main\network"" /v parallel_align_cameras /d 1 /t REG_DWORD /f"
    Invoke-Expression "reg add ""hklm\defaultuser\Software\Agisoft\PhotoScan Pro\main\network"" /v parallel_match_photos /d 1 /t REG_DWORD /f"
    Invoke-Expression "reg add ""hklm\defaultuser\Software\Agisoft\PhotoScan Pro\main\network"" /v parallel_build_dem /d 1 /t REG_DWORD /f"

    Invoke-Expression "reg unload hklm\defaultuser"

    # Current user
    Invoke-Expression "reg add ""hkcu\Software\Agisoft\PhotoScan Pro\main\network"" /v root_path /d $Root /f"
    Invoke-Expression "reg add ""hkcu\Software\Agisoft\PhotoScan Pro\main\network"" /v host /d $Dispatch /f"
    Invoke-Expression "reg add ""hkcu\Software\Agisoft\PhotoScan Pro\main\network"" /v enable /d 1 /t REG_DWORD /f"
    Invoke-Expression "reg add ""hkcu\Software\Agisoft\PhotoScan Pro\main\network"" /v parallel_build_dense_cloud /d 1 /t REG_DWORD /f"
    Invoke-Expression "reg add ""hkcu\Software\Agisoft\PhotoScan Pro\main\network"" /v parallel_build_tiled_model /d 1 /t REG_DWORD /f"
    Invoke-Expression "reg add ""hkcu\Software\Agisoft\PhotoScan Pro\main\network"" /v parallel_build_orthomosaic /d 1 /t REG_DWORD /f"
    Invoke-Expression "reg add ""hkcu\Software\Agisoft\PhotoScan Pro\main\network"" /v parallel_build_depth_maps /d 1 /t REG_DWORD /f"
    Invoke-Expression "reg add ""hkcu\Software\Agisoft\PhotoScan Pro\main\network"" /v parallel_align_cameras /d 1 /t REG_DWORD /f"
    Invoke-Expression "reg add ""hkcu\Software\Agisoft\PhotoScan Pro\main\network"" /v parallel_match_photos /d 1 /t REG_DWORD /f"
    Invoke-Expression "reg add ""hkcu\Software\Agisoft\PhotoScan Pro\main\network"" /v parallel_build_dem /d 1 /t REG_DWORD /f"

}

$SetupMarker=[system.io.path]::Combine($env:TEMP,"install_photoscan_windows.marker")
if (Test-Path $SetupMarker)
{
    Write-Verbose "We're already configured, exiting..." -Verbose
    Exit 0
}

DownloadPhotoScan
InstallPhotoscan
ActivatePhotoscan

if ($Role -ieq "server")
{
    ConfigureDefaultPhotoscanRegKey
}

ConfigurePhotoscan

"Done" | Out-File $SetupMarker