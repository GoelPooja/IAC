function Create-ServiceAccount
{
	
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True)]
		[string]$domain,
		[Parameter(Mandatory = $True)]
		[string]$domainControllerFQDN,
		[Parameter(Mandatory = $True)]
		[string]$saUsername,
		[pscredential]$domainAdminPSCredential
		
	)
	
	Add-Type -AssemblyName System.Web
	$unsecuredPwd = [System.Web.Security.Membership]::GeneratePassword(10, 3)
	$securePWD = ConvertTo-SecureString -AsPlainText $unsecuredPwd -Force
	$UPN = $saUsername + "@" + $domain
	$distinguishedName = (Get-ADDomain -Server $domainControllerFQDN).DistinguishedName
	$OU = "OU=CLEF,OU=Services," + $distinguishedName
	
	Invoke-Command -ComputerName $domainControllerFQDN `
				   -Credential $domainAdminPSCredential `
				   -Script 	{
		New-ADUser –GivenName $using:saUsername `
				   –SamAccountName $using:saUsername `
				   -Name $using:saUsername `
				   -AccountPassword $using:securePWD `
				   -DisplayName $using:saUserName `
				   –UserPrincipalName $using:UPN `
				   -Enabled $true `
				   -PasswordNeverExpires $True `
				   -path $using:OU
	}
	
	return $unsecuredPwd
	
}
