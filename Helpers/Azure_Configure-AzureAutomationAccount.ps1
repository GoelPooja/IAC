function Get-PSGalleryModuleUri
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$ModuleName,
		$Version = $null
	)
	
	
	if ($Version -eq $null)
	{
		$module = Find-Module -Name $ModuleName
	}
	else
	{
		$module = Find-Module -Name $ModuleName -RequiredVersion $Version
	}
	return "$($module.RepositorySourceLocation)package/$($module.Name)/$($module.Version)"
}
function Get-ModuleUri
{
	param (
		[Parameter(Mandatory)]
		[string]$ModulePath
	)
	
	$ResourceGroupName = "Environment_Automation"
	$storageacc = "dscmodules"
	$container = "modules"
	$filename = Split-Path $ModulePath -leaf
	
	#Login using service principal
	$ApplicationId = "fa355a8e-0b22-414d-a2b4-8aa1cfdd8c07"
	$TenantId = "40904d6e-3558-48d5-8ff7-9365ed2dd3e7"
	$password = 'M%UTC"F&Ag5JEkS9QfL!Z5P#ZkQfMg#&GY3w'
	$passwordSecure = ConvertTo-SecureString -String $password -AsPlainText -Force
	$AzureLoginCreds = New-Object System.Management.Automation.PSCredential ($ApplicationId, $passwordSecure)
	Add-AzureRmAccount -Credential $AzureLoginCreds `
						 -ServicePrincipal `
						 -TenantId $TenantId | Out-Null
	
	$key = Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $storageacc
	
	$context = New-AzureStorageContext -StorageAccountName $storageacc -StorageAccountKey $key[0].Value
	
	Set-AzureStorageBlobContent -Container $container -Context $context -File $ModulePath -Force | Out-Null
	
	$uri = New-AzureStorageBlobSASToken -Context $context -Container $container -Blob $filename `
										-StartTime (Get-Date) -ExpiryTime (Get-Date).AddHours(2) `
										-Permission r -FullUri
	return $uri
	
}
function Configure-AzureAutomationAccount
{
<# 
 .Synopsis
 Configures Azure Automation Account

 .Description
 Used to create and edit an Azure Automation Account

 .Parameter AutomationAccountName
  Name of the Automatin Account

 .Parameter Location
  Location of Automation Account.

 .Parameter plan
  Plan for the Azure automation account. Possible values 'Basic', 'Free'

 .Parameter DeleteAutomationAccount
 Switch parammeter used to detele an automation account

 .Parameter EditAutomationAccount
  Switch parameter used to edit an existing automation account

  .Parameter OverwriteCredentials
  Switch parameter used to overwrite existing credentials with same name

   .Parameter OverwriteVariables
  Switch parameter used to overwrite existing variables with same name

   .Parameter OverwriteModules
  Switch parameter used to edit existing modules with same name

   .Parameter OverwriteDscConfiguration
  Switch parameter used to edit existing DSC configuration with same name

   .Parameter Variables
 Hashtable of variables to add in Automation Account. Format @{"VariableName1" = "VariableValue1"; "VariableName2" = "VariableValue2"}

   .Parameter Credentials
  Hashtable of credentials to add in Automation Account. Format @{"CredentialName"=[PSCredential]}

   .Parameter Modules
  Hashtale of Modules. Format @{"ModuleName="ModueleZipPath"} For zip structure kindly refer:https://docs.microsoft.com/en-us/azure/automation/automation-troubleshooting-automation-errors#common-errors-when-importing-modules

   .Parameter DscConfiguration
  Array of DSC Configuration script paths. Note that the name of the Script file should match with the configuration name in DSC script

   .Parameter CredentialDescription
  Hashtable of Description for credentials. Format @{"CredentialName"="Description"}

   .Parameter VariableDescription
  Hashtable of Description for variables. Format @{"VariableName"="Description"}

   .Parameter VariableEncrypted
  Hashtable of Encryption status of Variables. Format @{"VariableName"=[Boolean]}

   .Parameter PSGalleryModules
   Array of Powershell Gallery module names to add in Automation account

    .Parameter PSGalleryModuleVersion
   Hashtable of Powershell Gallery module versions. Format @{"ModuleName"="Version"}

 .Example
   # Create an Automation account
   Configure-AzureAutomationAccount -AutomationAccountName "<Automation Account Name>"

 .Example
   # Create an Automation account with variables, credentials, modules and DSC configuration
    $admincreds=New-Object System.Management.Automation.PSCredential ("Domain\Username", (ConvertTo-SecureString -String "Password" -AsPlainText -Force))
    $Credentials=@{"Admin"=$admincreds} 
    $Variables=@{"Env"="Test"} 
    $ModulePath=@{"<ModuleName>"='<Path to ModuleName.zip>'} 
    $PS_GalleryModules=@("<ModuleName>") 
    $Config=@("<Path to .ps1 DSC script>") 
   Configure-AzureAutomationAccount -AutomationAccountName "<Automation Account Name>" -Credentials $Credentials -Variables $Variables -Modules $ModulePath -PSGalleryModules $PS_GalleryModules -DscConfiguration $Config

 .Example
   # Add Modules to existing Automation account
  Configure-AzureAutomationAccount -AutomationAccountName "<Automation Account Name>" -EditAutomationAccount -Modules $ModulePath

   .Example
   # Overwrite an existing module in Automation account
  Configure-AzureAutomationAccount -AutomationAccountName "<Automation Account Name>" -EditAutomationAccount -Modules $ModulePath -OverwriteModules

  .Example
   # Delete existing Automation Account
  Configure-AzureAutomationAccount -AutomationAccountName "<Automation Account Name>" -DeleteAutomationAccount
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$AutomationAccountName,
		[string]$Location = "Australia Southeast",
		[string]$plan = "Basic",
		[switch]$DeleteAutomationAccount,
		[switch]$EditAutomationAccount,
		[switch]$OverwriteCredentials,
		[switch]$OverwriteVariables,
		[switch]$OverwriteModules,
		[switch]$OverwriteDscConfiguration,
		[hashtable]$Variables = $null,
		[hashtable]$Credentials = $null,
		[hashtable]$Modules = $null,
		[array]$PSGalleryModules,
		[hashtable]$PSGalleryModuleVersion = @{ },
		[array]$DscConfiguration = $null,
		[hashtable]$CredentialDescription = @{ },
		[hashtable]$VariableDescription = @{ },
		[hashtable]$VariableEncrypted = @{ }
	)
	
	#Hardcoding resource group as service principal has access only to this resource group
	$ResourceGroupName = "Environment_Automation"
	
	#Login using service principal
	$ApplicationId = "fa355a8e-0b22-414d-a2b4-8aa1cfdd8c07"
	$TenantId = "40904d6e-3558-48d5-8ff7-9365ed2dd3e7"
	$password = 'M%UTC"F&Ag5JEkS9QfL!Z5P#ZkQfMg#&GY3w'
	$passwordSecure = ConvertTo-SecureString -String $password -AsPlainText -Force
	$AzureLoginCreds = New-Object System.Management.Automation.PSCredential ($ApplicationId, $passwordSecure)
	Add-AzureRmAccount -Credential $AzureLoginCreds `
						 -ServicePrincipal `
						 -TenantId $TenantId
	
	#Deleting Account
	if ($DeleteAutomationAccount)
	{
		$existingAccount = Get-AzureRmAutomationAccount -ResourceGroupName $ResourceGroupName `
														-Name $AutomationAccountName `
														-ErrorAction SilentlyContinue
		if ($existingAccount -ne $null)
		{
			Write-Output "Deleting Automation account.."
			Remove-AzureRmAutomationAccount `
											-Name $AutomationAccountName `
											-ResourceGroupName $ResourceGroupName -Force
            While((Get-AzureRmAutomationAccount -ResourceGroupName $ResourceGroupName `
														-Name $AutomationAccountName `
														-ErrorAction SilentlyContinue) -ne $null)
            {
            Start-Sleep -Seconds 5
            }
			Write-Output "Automation Account deleted successfully."
			return
		}
		else
		{
			Write-Information "Unable to delete automation account: Account with name $AutomationAccountName does not exist"
			return
		}
	}
	
	#Creating Automation Account
	if (-Not $EditAutomationAccount)
	{
		$existingAccount = Get-AzureRmAutomationAccount -ResourceGroupName $ResourceGroupName `
														-Name $AutomationAccountName `
														-ErrorAction SilentlyContinue
		if ($existingAccount -eq $null)
		{
			Write-Output "Creating Automation account.."
			New-AzureRmAutomationAccount -ResourceGroupName $ResourceGroupName `
										 -Name $AutomationAccountName `
										 -Location $Location `
										 -Plan $plan
            While((Get-AzureRmAutomationAccount -ResourceGroupName $ResourceGroupName `
														-Name $AutomationAccountName `
														-ErrorAction SilentlyContinue) -eq $null)
            {
            Start-Sleep -Seconds 5
            }
			Write-Output "Automation acount created successfully."
		}
		else
		{
			Write-Error "Account already exists. Kindly use the 'EditAutomationAccount' switch if you want edit existing account."
			return
		}
	}
	
	#Adding Credentials
	if ($Credentials -ne $null)
	{
		foreach ($creds in $Credentials.GetEnumerator())
		{
			if ($CredentialDescription[$creds.Name] -eq $null) { $CredentialDescription[$creds.Name] = " " }
			$existingCredentials = Get-AzureRmAutomationCredential -ResourceGroupName $ResourceGroupName `
																   -AutomationAccountName $AutomationAccountName `
																   -Name $creds.Name `
																   -ErrorAction SilentlyContinue
			if ($existingCredentials -eq $null)
			{
				New-AzureRmAutomationCredential -AutomationAccountName $AutomationAccountName `
												-Name $creds.Name `
												-Value $creds.Value `
												-ResourceGroupName $ResourceGroupName `
												-Description $CredentialDescription[$creds.Name]
				Write-Output "Credentials $($creds.Name) added successfully."
			}
			elseif ($OverwriteCredentials)
			{
				Set-AzureRmAutomationCredential -AutomationAccountName $AutomationAccountName `
												-Name $creds.Name `
												-Value $creds.Value `
												-ResourceGroupName $ResourceGroupName `
												-Description $CredentialDescription[$creds.Name]
				Write-Output "Credential $($creds.Name) edited successfully."
			}
			else
			{
				Write-Error "Credential $($creds.Name) already exists. To edit it kindly use the 'OverwriteCredentials' switch."
				return
			}
		}
	}
	
	#Adding Variables
	if ($Variables -ne $null)
	{
		foreach ($var in $Variables.GetEnumerator())
		{
			if ($VariableDescription[$var.Name] -eq $null) { $VariableDescription[$var.Name] = " " }
			if ($VariableEncrypted[$var.Name] -eq $null) { $VariableEncrypted[$var.Name] = $false }
			$existingVar = Get-AzureRmAutomationVariable -AutomationAccountName $AutomationAccountName `
														 -Name $Var.Name `
														 -ResourceGroupName $ResourceGroupName `
														 -ErrorAction SilentlyContinue
			if ($existingVar -eq $null)
			{
				New-AzureRmAutomationVariable -AutomationAccountName $AutomationAccountName `
											  -Name $var.Name `
											  -Encrypted $VariableEncrypted[$var.Name] `
											  -Value $var.value `
											  -ResourceGroupName $ResourceGroupName `
											  -Description $VariableDescription[$var.Name]
				Write-Output "Variable $($var.Name) added successfully."
			}
			elseif ($OverwriteVariables)
			{
				if ($existingVar.Encrypted -ne $VariableEncrypted[$var.Name])
				{ Write-Error "Error while editing variable $($var.Name). Encrytion status of variables cannot be modified post creation."; return }
				Set-AzureRmAutomationVariable -AutomationAccountName $AutomationAccountName `
											  -Name $var.Name `
											  -Encrypted $VariableEncrypted[$var.Name] `
											  -Value $var.value `
											  -ResourceGroupName $ResourceGroupName `
											  -Description $VariableDescription[$var.Name]
				Write-Output "Variable $($var.Name) edited successfully."
			}
			else
			{
				Write-Error "Variable $($var.Name) already exists. To edit it kindly use the 'OverwriteVariables' switch."
				return
			}
		}
	}
	
	#Adding Modules
	if ($Modules -ne $null)
	{
		foreach ($module in $Modules.GetEnumerator())
		{
			$existingAutomationModule = Get-AzureRmAutomationModule -AutomationAccountName $AutomationAccountName `
																	-Name $module.Name `
																	-ResourceGroupName $ResourceGroupName `
																	-ErrorAction SilentlyContinue
			if ($existingAutomationModule -eq $null)
			{
				$moduleuri = Get-ModuleUri -ModulePath $module.value
				New-AzureRmAutomationModule -ResourceGroupName $ResourceGroupName `
											-AutomationAccountName $AutomationAccountName `
											-Name $module.Name `
											-ContentLink $moduleuri
				Write-Output "Module $($module.Name) added successfully."
			}
			elseif ($OverwriteModules)
			{
				$moduleuri = Get-ModuleUri -ModulePath $module.value
				Set-AzureRmAutomationModule -ResourceGroupName $ResourceGroupName `
											-AutomationAccountName $AutomationAccountName `
											-Name $module.Name `
											-ContentLinkUri $moduleuri
				Write-Output "Module $($module.Name) updated successfully."
			}
			else
			{
				Write-Error "Module $($module.Name) already exists. To edit it kindly use the 'OverwriteModules' switch."
				return
			}
		}
	}
	
	#Adding PSGallery Modules
	if ($PSGalleryModules -ne $null)
	{
		foreach ($module in $PSGalleryModules)
		{
			$existingAutomationModule = Get-AzureRmAutomationModule -AutomationAccountName $AutomationAccountName `
																	-Name $module `
																	-ResourceGroupName $ResourceGroupName `
																	-ErrorAction SilentlyContinue
			if ($existingAutomationModule -eq $null)
			{
				if ($PSGalleryModuleVersion[$module] -eq $null)
				{
					$moduleuri = Get-PSGalleryModuleUri -ModuleName $module
				}
				else
				{
					$moduleuri = Get-PSGalleryModuleUri -ModuleName $module -Version $PSGalleryModuleVersion[$module]
				}
				New-AzureRmAutomationModule -ResourceGroupName $ResourceGroupName `
											-AutomationAccountName $AutomationAccountName `
											-Name $module `
											-ContentLink $moduleuri
				Write-Output "Module $module added successfully."
			}
			elseif ($OverwriteModules)
			{
				if ($PSGalleryModuleVersion[$module] -eq $null)
				{
					$moduleuri = Get-PSGalleryModuleUri -ModuleName $module
					
				}
				else
				{
					
					$moduleuri = Get-PSGalleryModuleUri -ModuleName $module -Version $PSGalleryModuleVersion[$module]
					
				}
				Set-AzureRmAutomationModule -ResourceGroupName $ResourceGroupName `
											-AutomationAccountName $AutomationAccountName `
											-Name $module `
											-ContentLinkUri $moduleuri
				Write-Output "Module $module updated successfully."
			}
			else
			{
				Write-Error "Module $module already exists. To edit it kindly use the 'OverwriteModules' switch."
				return
			}
		}
	}
	#Adding DSC Configuration
	if ($DscConfiguration -ne $null)
	{
		foreach ($config in $DscConfiguration)
		{
			$ConfigName = (Split-Path $config -leaf).Replace(".ps1", "")
			$existingConfiguration = Get-AzureRmAutomationDscConfiguration -AutomationAccountName $AutomationAccountName `
																		   -ResourceGroupName $ResourceGroupName `
																		   -Name $ConfigName  `
																		   -ErrorAction SilentlyContinue
			if ($existingConfiguration -eq $null)
			{
				Import-AzureRmAutomationDscConfiguration -AutomationAccountName $AutomationAccountName `
														 -ResourceGroupName $ResourceGroupName `
														 -SourcePath $config `
														 -LogVerbose $true `
														 -Published `
														 -Force
				Write-Output "$ConfigName added successfully."
			}
			elseif ($OverwriteDscConfiguration)
			{
				Import-AzureRmAutomationDscConfiguration -AutomationAccountName $AutomationAccountName `
														 -ResourceGroupName $ResourceGroupName `
														 -SourcePath $config `
														 -LogVerbose $true `
														 -Published `
														 -Force
				Write-Output "$ConfigName updated successfully."
			}
			else
			{
				Write-Error "Configuration $ConfigName already exists. To edit it kindly use the 'OverwriteDscConfiguration' switch."
				return
			}
		}
	}
}