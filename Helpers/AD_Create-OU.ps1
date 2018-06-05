function Create-OU
{
	
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True)]
		[string]$domain,
		[Parameter(Mandatory = $True)]
		[string]$domainControllerFQDN,
		[Parameter(Mandatory = $True)]
		[string]$OUName,
		[pscredential]$domainAdminPSCredential
		
	)
	
	$distinguishedName = (Get-ADDomain -Server $domainControllerFQDN).DistinguishedName
	$OUPath = "OU=Services," + $distinguishedName
	
	Invoke-Command -ComputerName $domainControllerFQDN -Credential $domainAdminPSCredential -Script { New-ADOrganizationalUnit -Name $Using:OUName -Path $Using:OUPath -ProtectedFromAccidentalDeletion $false }
	$OUPath = "OU=Servers," + $distinguishedName
	
	Invoke-Command -ComputerName $domainControllerFQDN -Credential $domainAdminPSCredential -Script { New-ADOrganizationalUnit -Name $Using:OUName -Path $Using:OUPath -ProtectedFromAccidentalDeletion $false }
	
}
