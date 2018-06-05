Function Configure-LCM
{
	[CmdletBinding()]
	param (
		[string]$RegistrationUri = $null,
		[string]$RegistrationKey = $null,
		[string]$ConfigurationName = $null
	)
	$paramspath = "$env:TEMP\params.csv"
	if ($PSBoundParameters.Keys -ne $null)
	{
		if (-Not (Test-Path $paramspath))
		{
			Add-Content -Value "Key,Value" -Path $paramspath -Force
		}
		switch ($PSBoundParameters.Keys)
		{
			"RegistrationUri" { Add-Content -Value "$($PSBoundParameters.Keys),$($PSBoundParameters.Values)" -Path $paramspath -Force }
			"RegistrationKey" { Add-Content -Value "$($PSBoundParameters.Keys),$($PSBoundParameters.Values)" -Path $paramspath -Force }
			"ConfigurationName" { Add-Content -Value "$($PSBoundParameters.Keys),$($PSBoundParameters.Values)" -Path $paramspath -Force }
		}
	}
	else
	{
		[DscLocalConfigurationManager()]
		Configuration ConfigureLCM
		{
			param
			(
				[Int]$RefreshFrequencyMins = 30,
				[Int]$ConfigurationModeFrequencyMins = 15,
				[String]$ConfigurationMode = "ApplyAndAutoCorrect",
				[Boolean]$RebootNodeIfNeeded = $True,
				[String]$ActionAfterReboot = "ContinueConfiguration",
				[Boolean]$AllowModuleOverwrite = $True
			)
			$values = Import-csv $paramspath
			$hash = @{ }
			foreach($value in $values)
			{
				$hash[$value.Key] = $value.Value
			}
			
			
			Node localhost
			{
				Settings
				{
					RefreshFrequencyMins = $RefreshFrequencyMins
					RefreshMode = 'Pull'
					ConfigurationMode = $ConfigurationMode
					AllowModuleOverwrite = $AllowModuleOverwrite
					RebootNodeIfNeeded = $RebootNodeIfNeeded
					ActionAfterReboot = $ActionAfterReboot
					ConfigurationModeFrequencyMins = $ConfigurationModeFrequencyMins
				}
				
				
				ConfigurationRepositoryWeb AzureAutomationDSC
				{
					ServerUrl = $hash["RegistrationUri"]
					RegistrationKey = $hash["RegistrationKey"]
					ConfigurationNames =@($hash["ConfigurationName"])
					
				}
				
				ResourceRepositoryWeb AzureAutomationDSC
				{
					ServerUrl = $hash["RegistrationUri"]
					RegistrationKey = $hash["RegistrationKey"]
				}
				
				
				ReportServerWeb AzureAutomationDSC
				{
					ServerUrl = $hash["RegistrationUri"]
					RegistrationKey = $hash["RegistrationKey"]
					
				}
			}
		}
		
		Configurelcm -OutputPath $env:TEMP
		Set-DscLocalConfigurationManager -Path $env:TEMP -ComputerName localhost -Force -Verbose
		Update-DscConfiguration
		Remove-Item -Path $paramspath -Force
	}
}

export-modulemember -function Configure-LCM