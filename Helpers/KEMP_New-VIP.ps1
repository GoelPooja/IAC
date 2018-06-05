function NewVip
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True)]
		[string]$ipAddress,
		[Parameter(Mandatory = $True)]
		[string]$envName,
		[Parameter(Mandatory = $True)]
		[string]$nodeName,
		[Parameter(Mandatory = $True)]
		[string]$template,
		[Parameter(Mandatory = $True)]
		[string]$mainPort,
		[Parameter(Mandatory = $False)]
		[string]$extraPorts,
		[Parameter(Mandatory = $True)]
		[string]$kempUser,
		[Parameter(Mandatory = $True)]
		[string]$kempPwd,
		[Parameter(Mandatory = $True)]
		[string]$kempIPAddress
	)
	
	$kempPwdSecure = $kempPwd | ConvertTo-SecureString -AsPlainText -Force
	$kempCreds = New-Object System.Management.Automation.PSCredential ($kempUser, $kempPwdSecure)
	$VIPNickName = $envName + "_" + $nodeName + "_" + $template.TrimStart("CLEF_")
	Invoke-Command -Computer localhost -Script {
		Import-Module KEMP.LoadBalancer.Powershell
		Initialize-Lm -Address $using:kempIPAddress -LBPort 443 -Credential $using:kempCreds -Verbose
		$protocol = "tcp"
		$result = New-VirtualService -VirtualService $using:ipAddress -Port $using:mainPort -Protocol $protocol -Nickname $using:VIPNickName -Template $using:template
		
		if ($result -eq "ok")
		{
			if ($using:extraPorts)
			{ Set-VirtualService -VirtualService $using:ipAddress -Port $using:mainPort -Protocol $protocol -Enable $true -ExtraPorts $using:extraPorts }
			else
			{ Set-VirtualService -VirtualService $using:ipAddress -Port $using:mainPort -Protocol $protocol -Enable $true }
		}
		else
		{
			Write-Output "Virtual Service for $using:VIPNickName is not created "
			Write-Output $result
		}
	}
}