Configuration AdditionalDcConfig
{
	Param
	(
		[string]$dnsDomainName,
		[string]$adDomainNetBIOSName,
		[int]$dataDiskNumber=2,
		[string]$dataDiskDriveLetter="F",
		[System.Management.Automation.PSCredential]$DomainAdminCredentials,
		[int]$RetryIntervalSec=30,
		[int]$RetryCount=20
	)

	Import-DscResource -ModuleName PSDesiredStateConfiguration, xActiveDirectory, StorageDsc 

	[System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("$adDomainNetBIOSName\$($DomainAdminCredentials.UserName)", $DomainAdminCredentials.Password)
	
	Node localhost
	{     
	      
  		LocalConfigurationManager
		{
			ConfigurationMode = 'ApplyAndAutoCorrect'
			RebootNodeIfNeeded = $true
			ActionAfterReboot = 'ContinueConfiguration'
			AllowModuleOverwrite = $true
		}

		WindowsFeature ADDS_Install 
		{ 
			Ensure = 'Present' 
			Name = 'AD-Domain-Services' 
		} 

		WindowsFeature RSAT_ADDS 
		{
			Ensure = 'Present'
			Name   = 'RSAT-ADDS'
		}

		WindowsFeature RSAT_AD_PowerShell 
		{
			Ensure = 'Present'
			Name   = 'RSAT-AD-PowerShell'
		}

		WindowsFeature RSAT_AD_Tools 
		{
			Ensure = 'Present'
			Name   = 'RSAT-AD-Tools'
		}

		WindowsFeature RSAT_Role_Tools 
		{
			Ensure = 'Present'
			Name   = 'RSAT-Role-Tools'
        }   
           
        WaitforDisk Disk2
        {
             DiskId = 2
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }
        
        Disk ADDataDisk
        {
            DiskId = 2
            DriveLetter = "F"
	        DependsOn="[WaitForDisk]Disk2"
        }

		xWaitForADDomain DscForestWait
        {
            DomainName = $dnsDomainName
            DomainUserCredential = $DomainCreds
            RetryCount = $RetryCount
            RetryIntervalSec = $Node.RetryIntervalSec
            DependsOn = "[Disk]ADDataDisk"
        }
        xADDomainController SecondDC
        {
            DomainName = $dnsDomainName
            DomainAdministratorCredential = [System.Management.Automation.PSCredential]$DomainCreds
			SafemodeAdministratorPassword = [System.Management.Automation.PSCredential]$DomainCreds
			DatabasePath = $dataDiskDriveLetter + ":\NTDS"
			LogPath = $dataDiskDriveLetter + ":\NTDS"
            SysvolPath = $dataDiskDriveLetter + ":\SYSVOL"
			DependsOn = "[xWaitForADDomain]DscForestWait"
        }
	}
}