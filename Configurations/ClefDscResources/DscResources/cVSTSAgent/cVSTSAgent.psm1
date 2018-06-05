function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[System.String]$Name = 'localhost',
		[System.String]$MachineGroup,
		[String[]]$Tags,
		[ValidateSet("Present", "Absent")]
		[System.String]$Ensure,
		[parameter(Mandatory = $true)]
		[System.String]$ProjectName,
		[parameter(Mandatory = $true)]
		[System.String]$VstsUrl,
		[System.String]$InstallFolder = "%PATH%\vsts-agent",
		[System.String]$PoolName = "default",
		[parameter(Mandatory = $true)]
		[System.String]$token,
		[Bool]$Overwrite = $false,
		[String]$AgentPackagePath,
		[System.Object]$Service,
		[String]$workFolder,
		[String]$Username,
		[String]$Password
	)
	
	if ($Name -eq 'localhost')
	{
		$Name = $Env:ComputerName
	}
	
	$State = @{
		Name = $Null
		MachineGroup = $null
		Tags = $Null
		Ensure = 'Absent'
		ProjectName = $Null
		VstsUrl = $Null
		PoolName = $Null
		Service = $null
		WorkFolder = $Null
		InstallFolder = $InstallFolder
	}
	
	Write-Verbose -Message "Check if any service is running"
	$serviceName = "vstsagent." + $VstsUrl.Substring(8, ($VstsUrl.IndexOf('.') - 8)) + "."
	$Service = (Get-WmiObject win32_service | ?{ $_.Name -like $serviceName + '*' })
	if ($Service)
	{
		$State.Ensure = 'Present'
		$index = $service.pathname
		$Folder = ($index.Split("\", 3) | Select -Index 0, 1) -join "\"
		$State.InstallFolder = $Folder
		$State.Service = $Service
	}
	
	if ($(Try { Test-Path $State.InstallFolder }
			Catch { $false }))
	{
		$settingsJsonFile = "$Folder\.agent"
		if (Test-Path $settingsJsonFile)
		{
			$settings = Get-Content -Raw $settingsJsonFile | ConvertFrom-Json
			
			$State.Name = $settings.agentName
			if ($settings.machinegroup) { $State.MachineGroup = $settings.machinegroup }
			if ($settings.machinegrouptags) { $State.Tags = $settings.machinegrouptags }
			if ($settings.projectname) { $State.ProjectName = $settings.projectname }
			$State.VstsUrl = $settings.serverUrl
			$State.PoolName = $settings.poolName
		}
	}
	
	return $State
	
}
function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		
		[System.String]$Name = 'localhost',
		[System.String]$MachineGroup,
		[String[]]$Tags,
		[ValidateSet("Present", "Absent")]
		[System.String]$Ensure,
		[parameter(Mandatory = $true)]
		[System.String]$ProjectName,
		[parameter(Mandatory = $true)]
		[System.String]$VstsUrl,
		[System.String]$InstallFolder = "%PATH%",
		[System.String]$PoolName = "default",
		[parameter(Mandatory = $true)]
		[System.String]$token,
		[Bool]$Overwrite = $false,
		[String]$AgentPackagePath,
		[System.Object]$Service,
		[String]$workFolder,
		[String]$Username,
		[String]$Password
	)
	if (-Not $AgentPackagePath)
	{
		$latestRelease = Invoke-WebRequest https://github.com/Microsoft/vsts-agent/releases/latest -Headers @{ "Accept" = "application/json" } -UseBasicParsing
		$json = $latestRelease.Content | ConvertFrom-Json
		$latestVersion = $json.tag_name
		$latestVersionWOv = $latestVersion.Substring(1)
		Write-Output "Found latest packge on GitHub for VSTS-Agent: $latestVersion"
		$url = "https://github.com/Microsoft/vsts-agent/releases/download/$latestVersion/vsts-agent-win7-x64-$latestVersionWOv.zip"
		$AgentPackagePath = $url
	}
	
	if ($Name -eq 'localhost')
	{
		$Name = $Env:ComputerName
	}
	
	$currentValues = Get-TargetResource @PSBoundParameters
	
	$path = $currentValues.InstallFolder
	
	if ($Ensure -eq "Absent")
	{
		if ($currentValues.Service)
		{
			Stop-Service $currentValues.Name
			Write-Verbose "$path\config.cmd /remove"
			& "$path\config.cmd" remove --auth PAT --token $token --unattended
			# Remove the agent
			Remove-Item "$path" -force -Recurse
		}
	}
	
	# Check if we need to ensure the agent is present or absent
	if ($Ensure -eq "Present")
	{
		if ($currentValues.Service -and (($currentValues.Service.State -ne 'Running') -or $Overwrite))
		{
			& "$path\config.cmd" remove --auth PAT --token $token --unattended
			if (Test-Path $path)
			{
				rm $path -Recurse -Force
			}
		}
		
		$currentValues = Get-TargetResource @PSBoundParameters
		
		if (-Not ($currentValues.Service))
		{
			if (Test-Path $InstallFolder)
			{
				rm $InstallFolder -Recurse -Force
			}
			Write-Verbose "Creating agent folder $InstallFolder"
			md $InstallFolder
			
			# Download the agent from the server
			Write-Verbose "Downloading agent from  to $InstallFolder\agent.zip"
			Invoke-WebRequest "$AgentPackagePath" -OutFile "$InstallFolder\agent.zip" -UseBasicParsing
			
			# Unzip the agent
			Write-Verbose "Unzipping agent into $InstallFolder"
			Add-Type -AssemblyName System.IO.Compression.FileSystem
			[System.IO.Compression.ZipFile]::ExtractToDirectory("$InstallFolder\agent.zip", "$InstallFolder")
			
			# Delete the zip
			Remove-Item "$InstallFolder\agent.zip"
			
			# Run the configuration
			Write-Verbose "$InstallFolder\Agent\vsoAgent.exe $configureParameters"
			cd $InstallFolder
			& ".\config.cmd" --unattended --machinegroup --agent $Name --runasservice --windowslogonaccount $Username --windowslogonpassword $Password --work $workFolder --url $VstsUrl --projectname $ProjectName --machinegroupname $MachineGroup --addmachinegrouptags --machinegrouptags $Tags --auth PAT --pool $PoolName --token $token --replace
		}
	}
	
}
function Test-TargetResource
{
	[CmdletBinding()]
	param
	(
		[System.String]$Name = 'localhost',
		[System.String]$MachineGroup,
		[String[]]$Tags,
		[ValidateSet("Present", "Absent")]
		[System.String]$Ensure,
		[parameter(Mandatory = $true)]
		[System.String]$ProjectName,
		[parameter(Mandatory = $true)]
		[System.String]$VstsUrl,
		[System.String]$InstallFolder = "%PATH%\vsts-agent",
		[System.String]$PoolName = "default",
		[parameter(Mandatory = $true)]
		[System.String]$token,
		[Bool]$Overwrite = $false,
		[String]$AgentPackagePath,
		[System.Object]$Service,
		[String]$workFolder,
		[String]$Username,
		[String]$Password
	)
	$result = $false
	
	$currentValues = Get-TargetResource @PSBoundParameters
	
	if ($Ensure -eq $currentValues.Ensure)
	{
		if ($Ensure -eq 'Absent')
		{
			$result = $true
		}
		else
		{
			Write-Verbose -Message 'Ensure is in the desired state. Verifying values.'
			if (($currentValues.ServiceStateState -eq 'Running'))
			{
				if ($currentValues.InstallFolder -eq $InstallFolder)
				{
					$result = $true
				}
			}
		}
	}
	
	if ($result)
	{
		Write-Verbose -Message 'In the desired state'
	}
	else
	{
		Write-Verbose -Message 'Not in the desired state'
	}
	
	return $result
}

Export-ModuleMember -Function *-TargetResource