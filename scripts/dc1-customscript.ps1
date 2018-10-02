param
(
    [string]$BeeGfsSmbServersVip,
	[string]$BeeGfsARecordName="beegfs",
	[string]$BeeGfMasterARecordName,
	[string]$BeeGfMasterIpAddress,
	[string]$domainName
)

$ErrorActionPreference = "Stop"

Enable-NetFirewallRule -DisplayGroup "Remote Event Log Management"

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
