function GetIPAddress
{
	[CmdletBinding()]
	Param (
		
		[Parameter(Mandatory = $True)]
		[string]$machineOrNodeName,
		[Parameter(Mandatory = $True)]
		[ValidateSet('nlb', 'vm', 'wsfc', 'aag')]
		[string]$serviceType,
		[Parameter(Mandatory = $True)]
		[string]$envName,
		[Parameter(Mandatory = $True)]
		[ValidateSet('PRES', 'APP', 'DATA')]
		[string]$networkLayer,
		[Parameter(Mandatory = $True)]
		[string]$IPAMServerName
	)
	
	if ($networkLayer -eq "PRES")
	{
		$firstIP = "10.2.120.1"
		$lastIP = "10.2.120.254"
	}
	elseif ($networkLayer -eq "APP")
	{
		$firstIP = "10.2.121.1"
		$lastIP = "10.2.121.254"
	}
	elseif ($networkLayer -eq "DATA")
	{
		$firstIP = "10.2.122.1"
		$lastIP = "10.2.122.254"
	}
	
	$ipAddress = Invoke-Command -ComputerName $IPAMServerName -Script { (Get-IpamRange -StartIPAddress $using:firstIP -EndIPAddress $using:lastIP | Find-IpamFreeAddress).IpAddress.IPAddressToString }
	Invoke-Command -ComputerName $IPAMServerName -Script { Add-IpamAddress -IpAddress $using:ipAddress -AssetTag $using:machineOrNodeName }
	Write-Host "The IP addresse assigned to $serviceName is $ipAddress"
	return $ipAddress
}