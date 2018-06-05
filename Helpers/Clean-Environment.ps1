. $PSScriptRoot\Azure_Configure-AzureAutomationAccount.ps1
function Remove-AllADobjects
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$ADbjects,
		[Parameter(Mandatory)]
		$Environment,
		[Parameter(Mandatory)]
		[PSCredential]$DomainAdminCred
	)
	foreach ($object in $ADobjects)
	{
		try
		{
			Remove-ADObject -Identity $object -Recursive -Server "$Environment.apra.com.au" -ErrorAction SilentlyContinue -Credential $DomainAdminCred -Confirm:$false
		}
		catch
		{
			#Empty catch block to avoid error when cmdlet tries to delete object already deleted due to parent object deletion
		}
	}
}
function Clean-Environment
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$Environment,
		[switch]$DeleteAutomationAccount,
		[string]$AutomationAccountName,
		[switch]$CleanupAD,
		[PSCredential]$DomainAdminCred,
		[switch]$DeleteVMs,
		[array]$DC_ComputerName = @(),
		[string]$Cluster = "CLEF_TEST_CLUSTER",
		[string]$Datacenter = "Ultimo",
		[string]$vSphereServer = "sydprodvc01.apra.com.au",
		[PSCredential]$vSphereAdminCreds,
		[switch]$IPAMIPsDeallocate,
		[string]$IPAMServerName,
		[PSCredential]$IPAMServerCreds,
		[switch]$DeleteKempVIPs,
		[string]$KempIPAddress,
		[PSCredential]$KempCred,
		[switch]$DeleteKempTemplates,
		[switch]$DeleteDNSentries,
		[string]$DnsServerfqdn
	)
	
	#Delete Automation Account
	if ($DeleteAutomationAccount)
	{
		if ([string]::IsNullOrWhiteSpace($AutomationAccountName))
		{
			Write-Error "Automation account name is a manadatory parameter when DeleteAutomationAccount switch is used"
			return
		}
		Configure-AzureAutomationAccount -AutomationAccountName $AutomationAccountName -DeleteAutomationAccount
	}
	
	#Cleanup AD
	if ($CleanupAD)
	{
		if ($DomainAdminCred -eq $null)
		{
			Write-Error "Domain admin credential is a mandatory parameter when CleanupAd switch is used"
			return
		}
		#Active Directory Module for Windows Powershell should be Installed
		
		#Removing all objects from Server OU
		
		$ADobjects = (Get-ADObject -Filter * -Server "$Environment.apra.com.au" | Where-Object `
			{ $_.DistinguishedName -like "*,OU=Servers,DC=$Environment,DC=apra,DC=com,DC=au" }).DistinguishedName
		if ($ADobjects -ne $null)
		{
			Remove-AllADobjects -ADbjects $ADobjects -Environment $Environment -DomainAdminCred $DomainAdminCred
		}
		
		#Removing all objects from Services OU
		
		$ADobjects = (Get-ADObject -Filter * -Server "$Environment.apra.com.au" | Where-Object `
			{ $_.DistinguishedName -like "*,OU=Services,DC=$Environment,DC=apra,DC=com,DC=au" }).DistinguishedName
		
		if ($ADobjects -ne $null)
		{
			Remove-AllADobjects -ADbjects $ADobjects -Environment $Environment -DomainAdminCred $DomainAdminCred
		}
		
		#Removing all users except built in users
		
		$ADobjects = (Get-ADObject -Filter * -Server "$Environment.apra.com.au" -Credential $DomainAdminCred | Where-Object `
			{ $_.DistinguishedName -like "*,CN=Users,DC=$Environment,DC=apra,DC=com,DC=au" }).DistinguishedName
		if ($ADobjects -ne $null)
		{
			Remove-AllADobjects -ADbjects $ADobjects -Environment $Environment -DomainAdminCred $DomainAdminCred
		}
	}
	
	#Delete VM's
	if ($DeleteVMs)
	{
		if ($vSphereAdminCreds -eq $null)
		{
			Write-Error "vSphereAdmin credential is a mandatory parameter when DeleteVMs switch is used"
			return
		}
		if ($DC_ComputerName.Length -eq 0)
		{
			Write-Error "Provide an array with values of DC computer names in DC_ComputerName parameter to exclude DC from deletion"
			return
		}
		# Requires PowerCLI add-on and vpn connection to vSphere
		
		Import-Module -Name VMware.VimAutomation.Core -ErrorAction Stop
		
		Connect-VIServer -Server $vSphereServer -Credential $vSphereAdminCreds -Force
		$cltr = Get-Cluster -Name $Cluster -Location $Datacenter
		$VMList = Get-VM -Server $vSphereServer `
						 -Location $cltr `
		| ?{ $_.Name -like "SYD$Environment*" -and $DC_ComputerName -notcontains $_.Name }
		
		
		foreach ($VM in $VMList)
		{
			if ($VM.PowerState -ne "PoweredOff")
			{
				$VM | Stop-VM -Server $vSphereServer -Kill -Confirm:$false
			}
			$VM | Remove-VM -Server $vSphereServer -DeletePermanently -RunAsync -Confirm:$false
		}
		
	}
	
	#CLear IPAM Allocations
	if ($IPAMIPsDeallocate)
	{
		if ([string]::IsNullOrWhiteSpace($IPAMServerName))
		{
			Write-Error "IPAMServerName is a mandatory parameter when IPAMIPDeallocate switch is used"
			return
		}
		if ($IPAMServerCreds -eq $null)
		{
			Invoke-Command -ComputerName $IPAMServerName -Script {
				Get-IpamAddress -AddressFamily IPv4 `
				| where { $_.AssetTag -like "*$using:Environment`*" } `
				| select IPAddress, AssetTag `
				| Remove-IpamAddress -Force
			}
		}
		else
		{
			Invoke-Command -ComputerName $IPAMServerName -Credential $IPAMServerCreds -Script {
				Get-IpamAddress -AddressFamily IPv4 `
				| where { $_.AssetTag -like "*$using:Environment`*" } `
				| select IPAddress, AssetTag `
				| Remove-IpamAddress -Force
			}
		}
	}
	#Delete KEMP VIPs
	# Requires Kemp powershell module
	if ($DeleteKempVIPs)
	{
		if ([string]::IsNullOrWhiteSpace($KempIPAddress))
		{
			Write-Error "KempIPAddress is a mandatory parameter when DeleteKempVIPs switch is used"
			return
		}
		if ($KempCred -eq $null)
		{
			Write-Error "KempCred is a mandatory parameter when DeleteKempVIPs switch is used"
			return
		}
		Invoke-Command -Computer localhost -Script {
			Import-Module KEMP.LoadBalancer.Powershell
			Initialize-Lm -Address $using:KempIPAddress -LBPort 443 -Credential $using:KempCred -ErrorAction Stop
			Get-VirtualService | ?{ $_.NickName -like "*$using:Environment*" }`
			| select Protocol, @{ name = "Port"; expression = { $_.VSPort } }, @{ name = "VirtualService"; expression = { $_.VSAddress } }`
			| Remove-VirtualService -Force
		}
	}
	
	#Delete KEMP Templates
	# Requires Kemp powershell module
	if ($DeleteKempTemplates)
	{
		if ([string]::IsNullOrWhiteSpace($KempIPAddress))
		{
			Write-Error "KempIPAddress is a mandatory parameter when DeleteKempTemplates switch is used"
			return
		}
		if ($KempCred -eq $null)
		{
			Write-Error "KempCred is a mandatory parameter when DeleteKempTemplates switch is used"
			return
		}
        Invoke-Command -Computer localhost -Script {
        Import-Module KEMP.LoadBalancer.Powershell
		Initialize-Lm -Address $using:KempIPAddress -LBPort 443 -Credential $using:KempCred -ErrorAction Stop -Confirm:$false
		
		$templates = (Get-Template | ?{ $_.name -like "$using:Environment`_*" }).name
		foreach ($template in $templates)
		{
			Remove-Template -Name $template
		}
    }
		
	}
	
	#Delete DNS Entries
	if ($DeleteDNSentries)
	{
		if ([string]::IsNullOrWhiteSpace($DnsServerfqdn))
		{
			Write-Error "DnsServerfqdn is a mandatory parameter when DeleteDNSentries switch is used"
			return
		}
		if ($DomainAdminCred -eq $null)
		{
			Write-Error "Domain admin credential is a mandatory parameter when DeleteDNSentries switch is used"
			return
		}
		Invoke-Command -ComputerName $DnsServerfqdn `
					   -Credential $DomainAdminCred `
					   -ScriptBlock {
			Get-DnsServerResourceRecord -ZoneName "$using:Environment`.apra.com.au" `
			| ?{ $_.RecordType -eq "A" -or $_.RecordType -eq "AAAA" } `
			| ?{$_.HostName -notin $DC_ComputerName} `
			| Remove-DnsServerResourceRecord -Force -ZoneName "$using:Environment`.apra.com.au"
		}
	}
	
}