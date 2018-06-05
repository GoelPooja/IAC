function CreateHostRecord
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True)]
		[string]$ipAddress,
		[Parameter(Mandatory = $True)]
		[string]$alias,
		[Parameter(Mandatory = $True)]
		[string]$domain,
		[Parameter(Mandatory = $True)]
		[string]$domainControllerFQDN,
		[pscredential]$domainAdminPSCredential
		
	)
	
	Invoke-Command -ComputerName $domainControllerFQDN -Credential $domainAdminPSCredential -Script { Add-DnsServerResourceRecordA -Name $using:alias -ZoneName $using:domain -AllowUpdateAny -IPv4Address $using:ipAddress }
	Write-Host "Host(A) record created for $alias with the IP address $ipAddress on the domain $domain"
}