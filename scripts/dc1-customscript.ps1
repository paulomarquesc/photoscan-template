param
(
	[Parameter(Mandatory=$true,ParameterSetName="BeeGFS")]
	[string]$BeeGfsSmbServersVip,

	[Parameter(Mandatory=$false,ParameterSetName="BeeGFS")]
	[string]$BeeGfsARecordName="beegfs",

	[Parameter(Mandatory=$true,ParameterSetName="BeeGFS")]
	[string]$BeeGfMasterARecordName,

	[Parameter(Mandatory=$true,ParameterSetName="BeeGFS")]
	[string]$BeeGfMasterIpAddress,

	[Parameter(Mandatory=$true,ParameterSetName="NFS")]
	[string]$NfsDnsEntry, # E.g. vfxp,10.0.0.11,10.0.0.12,10.0.0.13

	[string]$domainName
)

# NfsDnsEntry details
# This string must be in this format:
# <DNS A Record for NFS servers>,<IP1>,<IP2>,<IP3>,<IPx>
# This will be used to create an A record on Windows DNS with one of each listed IP addresses for round robin 

$ErrorActionPreference = "Stop"

Enable-NetFirewallRule -DisplayGroup "Remote Event Log Management"

if ($PSCmdlet.ParameterSetName -eq "BeeGFS")
{
	# BeeGFS SMB Servers DNS Config 
	$result = get-DnsServerResourceRecord -Name $BeeGfsARecordName -ZoneName $domainName -ErrorAction SilentlyContinue
	if ($result -eq $null)
	{
		Add-DnsServerResourceRecordA -Name $BeeGfsARecordName -IPv4Address $BeeGfsSmbServersVip -ZoneName $domainName 
	}

	# BeeGFS Master DNS Config 
	$result = get-DnsServerResourceRecord -Name $BeeGfMasterARecordName -ZoneName $domainName -ErrorAction SilentlyContinue
	if ($result -eq $null)
	{
		Add-DnsServerResourceRecordA -Name $BeeGfMasterARecordName -IPv4Address $BeeGfMasterIpAddress -ZoneName $domainName 
	}
}
else
{
	$NfsArr = $NfsDnsEntry.Split(",")

	$result = get-DnsServerResourceRecord -Name $NfsArr[0] -ZoneName $domainName -ErrorAction SilentlyContinue
	if ($result -eq $null)
	{
		for ($i=1;$i -lt $nfsArr.Length; $i++)
		{
			Add-DnsServerResourceRecordA -Name $NfsArr[0] -IPv4Address $NfsArr[$i] -ZoneName $domainName
		}
		
	}
}