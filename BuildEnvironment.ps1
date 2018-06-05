 #Load Helper functions
Get-ChildItem -Path "$psscriptroot\Helpers\*.ps1" | ForEach-Object {
	Write-Debug -Message "Loading helper function $($_.Name)"
	. $_.FullName
}
# Load Parser
Add-Type -path "$psscriptroot\Helpers\*.dll"


function Get-Environment
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param (
		
	)
	
	$returnValue = @{
		
	}
	
	$returnValue
}

<#
	.SYNOPSIS
		A brief description of the Set-Environment function.
	
	.DESCRIPTION
		A detailed description of the Set-Environment function.
	
	.PARAMETER excelPath
		A description of the excelPath parameter.
	
	.PARAMETER envName
		A description of the envName parameter.
	
	.PARAMETER dcHostname
		A description of the dcHostname parameter.
	
	.PARAMETER rootDomain
		A description of the rootDomain parameter.
	
	.PARAMETER templateName
		A description of the templateName parameter.
	
	.EXAMPLE
		PS C:\> Set-Environment -excelPath 'value1' -envName 'value2' -dcHostname 'value3' -rootDomain 'value4' -templateName 'value5'
	
	.NOTES
		Additional information about the function.
#>
function Set-Environment
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $True)]
		[string]$excelPath,
		[Parameter(Mandatory = $True)]
		[string]$envName,
		[Parameter(Mandatory = $True)]
		[string]$dcHostname,
		[Parameter(Mandatory = $True)]
		[string]$rootDomain,
		[Parameter(Mandatory = $True)]
		[string]$templateName
	)
	
	try
	{
		
		
		$domain = $envName + "." + $rootDomain
		$domainControllerFQDN = $dcHostname + "." + $domain
		$domainAdminUser = "$envName\svcclefsetup"
		$domainAdminPassword = "Apra123`$"
		$domainAdminPSCredential = New-Object System.Management.Automation.PSCredential ($domainAdminUser, (ConvertTo-SecureString -String $domainAdminPassword -AsPlainText -Force))
		$IPAMServerName = "sydprodipam01.apra.com.au"
		$vstsUrl = "https://apra-amcos.visualstudio.com"
		$subnetMask = "255.255.255.0"
		$teamProject = "Clef"
		$agentToken = "ztoumqf7jfcepdehqzmy2fietawgfl46ynxghmuavkhqonoeoprq"
		$pSGalleryModules = @("xFailOverCluster", "xStorage", "xSMBShare", "xComputerManagement", "xActiveDirectory", "cUserRightsAssignment")
		$accountName = $envName + "AutomationAccount"
		$vcentreUserName = "apra\svcclefsetup"
		$vcentrePassword = "JMcwgNwAnrrVr7vfjQkh"
		$vcentrecreds = New-Object System.Management.Automation.PSCredential ($vcentreUserName, (ConvertTo-SecureString -String $vcentrePassword -AsPlainText -Force))
		$kempIPAddress = "10.2.120.4"
		$kempUser = "bal"
		$kempPassword = "L3v1tat3"
		$kempcreds = New-Object System.Management.Automation.PSCredential ($kempUser, (ConvertTo-SecureString -String $kempPassword -AsPlainText -Force))
		
		$automationVariables = @{ }
		$automationPSCredentials = @{ }
		$modules = @{ }
		$nodeDefinitionsPath = "$PSScriptRoot\Configurations\*.ps1"
		$dscNodeConfigurations = @()
		$AllNodes = @(
			@{
				NodeName = "*"
				PSDscAllowPlainTextPassword = $True
			})
		$compilationsJobs = @()
		
		# Create parser instance
		$parser = New-Object -TypeName IaC.ExcelParser.Parser -ArgumentList $excelPath
		
		# Parse Excel file to get templates
		$templates = $parser.ReadExcelFile()
		
		# Select template
		$template = $templates | Where-Object { $_.Name -eq $templateName }
		
		#Add DomainAdmin to automationPSCredentials
		$automationPSCredentials.Add("DomainAdmin", $domainAdminPSCredential)
		
		#region Clean Environment
		Clean-Environment -Environment $envName `
						  -DeleteAutomationAccount:$true `
						  -AutomationAccountName $accountName `
						  -CleanupAD:$true `
						  -DomainAdminCred $domainAdminPSCredential `
						  -DeleteVMs:$true `
						  -DC_ComputerName @("SYDTRNDC01", "SYDTRNDC02")`
						  -vSphereAdminCreds $vcentrecreds `
						  -IPAMIPsDeallocate:$true `
						  -IPAMServerName $IPAMServerName `
						  -DeleteKempVIPs:$true `
						  -KempIPAddress $kempIPAddress `
						  -KempCred $kempcreds `
						  -DeleteDNSentries:$true `
						  -DnsServerfqdn $domainControllerFQDN
		
		#endregion Clean Environment
		
		Create-OU -domain $domain -domainControllerFQDN $domainControllerFQDN -OUName "CLEF" -domainAdminPSCredential $domainAdminPSCredential
		# Create service accounts  and add to automationPSCredentials
		foreach ($acc in $template.ServiceAccounts)
		{
			$saAcc = "svc_" + $envName + "_" + $acc
			$password = Create-ServiceAccount -domain $domain -domainControllerFQDN $domainControllerFQDN -saUsername $saAcc -domainAdminPSCredential $domainAdminPSCredential
			$template.AccountPasswords.Add($saAcc, $password)
			$domainaccName = $envName + "\" + $saAcc
			$cred = New-Object System.Management.Automation.PSCredential ($domainaccName, (ConvertTo-SecureString -String $password -AsPlainText -Force))
			$automationPSCredentials.Add($acc, $cred)
		}
		
		# Add powershell module to DSC pull server shared resource collection
		$moduleName = "ClefDscResources"
		$moduleSource = "$PSScriptRoot\Configurations\$moduleName"
		$moduleDestination = "$moduleSource.zip"
		Compress-Archive -Path $moduleSource -DestinationPath $moduleDestination -Force
		$modules.Add($moduleName, $moduleDestination)
		
		$moduleName = "xSQLServer"
		$moduleSource = "$PSScriptRoot\Configurations\$moduleName"
		$moduleDestination = "$moduleSource.zip"
		Compress-Archive -Path $moduleSource -DestinationPath $moduleDestination -Force
		$modules.Add($moduleName, $moduleDestination)
		
		#Add DSC node configurations
		Get-ChildItem -Path $nodeDefinitionsPath | ForEach-Object {
			$dscNodeConfigurations += $_.FullName
		}
		
		#Add variables to automationVariables
		$automationVariables.Add("Domain", $domain)
		$automationVariables.Add("EnvironmentName", $envName)
		$automationVariables.Add("SubnetMask", $subnetMask)
		$automationVariables.Add("VstsUrl", $vstsUrl)
		$automationVariables.Add("TeamProject", $teamProject)
		$automationVariables.Add("AgentToken", $agentToken)
		$automationVariables.Add("MediaShare", "\\sydprodipam01.apra.com.au\CLEF_IaC")
		$automationVariables.Add("SqlKey2014", "82YJF-9RP6B-YQV9M-VXQFR-YJBGX")
		$automationVariables.Add("SqlKey2016", "22222-00000-00000-00000-00000")
		
		
		foreach ($node in $template.Nodes)
		{
			#Add nodes to node configuration data
			for ($i = 1; $i -le $node.Instances; $i++)
			{
				$instanceNumber = "{0:D2}" -f $i
				$vmName = "SYD" + $envName + $node.Name.replace(".", "") + $instanceNumber
				$AllNodes += @{
					NodeName = $node.Name.replace(".", "") + $instanceNumber
					Instance = $instanceNumber
					VmName = $vmName
				}
			}
			
			#Add VIPs and VIP ports to automationVariables
			$automationVariables.Add($node.Name + "_Nodes", $node.Instances)
			
			foreach ($clusterEndpoint in $node.ClusterEndpoints)
			{
				#Create NewVIP
				$VIPName = $envName + "_" + $node.Name + "_" + $clusterEndpoint.Type + "_" + $clusterEndpoint.Template
				$clusterEndpoint.VIPAddress = GetIPAddress -machineOrNodeName $VIPName `
														   -serviceType $clusterEndpoint.Type `
														   -envName $envName `
														   -networkLayer "PRES" `
														   -IPAMServerName $IPAMServerName
				
				
				#Add VIPs and VIP ports to automationVariables
				$ports = $clusterEndpoint.Ports -join ","
				$automationVariables.Add($VIPName + "_VIP", $clusterEndpoint.VIPAddress)
				$automationVariables.Add($VIPName + "_Ports", $ports)
			}
			
			foreach ($NLBClusterEndpoint in $node.NLBClusterEndpoints)
			{
				
				#Add NLBendpoint to KEMP Load balancer
				$mainport = $NLBClusterEndpoint.Ports | Select-Object -first 1
				$extraports = ($NLBClusterEndpoint.Ports | Select-Object -Skip 1) -join ","
				NewVIP -ipAddress $NLBClusterEndpoint.VIPAddress `
					   -envName $envName `
					   -nodeName $node.Name `
					   -template $NLBClusterEndpoint.Template `
					   -mainPort $mainport `
					   -extraPorts $extraports `
					   -kempUser $kempUser `
					   -kempPwd $kempPassword `
					   -kempIPAddress $kempIPAddress
			}
			
			#Add tags to automationVariables
			$tagsArray = @()
			foreach ($role in $node.Roles)
			{
				$tagsArray += $role.Tag
			}
			[string]$tags = $tagsArray -join ","
			$automationVariables.Add($node.Name.replace(".", "") + "_Tags", $tags)
		}
		
		#Create DNS Host record		
		foreach ($alias in $template.Aliases.GetEnumerator())
		{
			CreateHostRecord -ipAddress $alias.Value.VIPAddress `
							 -alias $alias.Key `
							 -domain $domain `
							 -domainControllerFQDN $domainControllerFQDN `
							 -domainAdminPSCredential $domainAdminPSCredential
		}
		
		
		#Create AzureAutomation Account
		
		Configure-AzureAutomationAccount -AutomationAccountName $accountName `
										 -Credentials $automationPSCredentials `
										 -Modules $modules `
										 -DscConfiguration $dscNodeConfigurations `
										 -Variables $automationVariables `
										 -PSGalleryModules $pSGalleryModules
		
		$registrationInfo = Get-AzureRmAutomationRegistrationInfo -ResourceGroupName "Environment_Automation" -AutomationAccountName $accountName
		$registrationUrl = $registrationInfo.EndPoint
		$registrationKey = $registrationInfo.PrimaryKey
		
		#Wait for modules to provisions		
		while (Get-AzureRmAutomationModule -ResourceGroupName "Environment_Automation" -AutomationAccountName $accountName | where ProvisioningState -eq "Creating")
		{
			Start-Sleep -Seconds 3
		}
		
		Start-Sleep -Seconds 60
		
		#Create DSC Node Configurations data		
		
		$configData = @{
			AllNodes = $AllNodes
		}
		
		
		#Compile DSC Node Configurations
		foreach ($config in $dscNodeConfigurations)
		{
			$configName = (Split-Path $config -leaf).Replace(".ps1", "")
			
			$compilationsJobs += Start-AzureRmAutomationDscCompilationJob -ResourceGroupName "Environment_Automation" -AutomationAccountName $accountName -ConfigurationName $configName -ConfigurationData $configData
			
		}
		
		foreach ($job in $compilationsJobs)
		{
			while ($null –eq $job.EndTime -and $null –eq $job.Exception)
			{
				$job = $job | Get-AzureRmAutomationDscCompilationJob
				Start-Sleep -Seconds 3
			}
			$job | Get-AzureRmAutomationDscCompilationJobOutput –Stream Any
		}
		
		
		#Provision Vms
		foreach ($node in $template.Nodes)
		{
			<#if ($node.Name -ne "CLEF.API")
			{
				if ($node.Name -ne "DYN.DB")
				{
					continue;
				}
			}#>
			for ($i = 1; $i -le $node.Instances; $i++)
			{
				# Create new VM
				$disks = $node.Disks | Select-Object -Skip 1
				$instanceNumber = "{0:D2}" -f $i
				$vmName = "SYD" + $envName + $node.Name.replace(".", "") + $instanceNumber
				$nodeName = $node.Name.split(".")[0] + "." + $node.Name.replace(".", "") + $instanceNumber
				$machineName = $envName + "_" + $nodeName
				# Get IP address for new VM
				$ipAddress = GetIPAddress -machineOrNodeName $machineName `
										  -serviceType "vm" `
										  -envName $envName `
										  -networkLayer "PRES" `
										  -IPAMServerName $IPAMServerName
				
				
				$path = $PSScriptRoot
				$job = Start-Job -ScriptBlock {
					. $using:path\Helpers\vSphere_New-VirtualMachine.ps1
					New-VirtualMachine -Name $using:vmName `
									   -AdminPassword "Password" `
									   -EnvironmentName "vm" `
									   -vCenterUsername $using:vcentreUserName `
									   -vCenterPassword $using:vcentrePassword `
									   -Template "APRA_Win2012_PRES" `
									   -vCenterServer "sydprodvc01.apra.com.au" `
									   -ClusterName "CLEF_TEST_CLUSTER" `
									   -DataCenter "Ultimo" `
									   -NumCpu $using:node.Cores `
									   -MemoryGB $using:node.Memory `
									   -NetworkName "Presentation" `
									   -IPAddress $using:ipAddress `
									   -SubnetMask "255.255.255.0" `
									   -DefaultGateway "10.2.120.1" `
									   -DNSServers @('10.2.0.90', '10.2.0.91') `
									   -AdditionalDisks $using:disks `
									   -RegUrl $using:registrationUrl `
									   -RegKey $using:registrationKey `
									   -NodeName $using:nodeName
					
				}
			}
		}
	}
	catch
	{
		Write-Error 'There was a problem creating the environment'
		Write-Error "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $($_.InvocationInfo.Line)"
		Write-Error $_
	}
	
	# Cleanup connections
	
}

function Test-Environemnt
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param (
	)
	
	$result = $true
	return $true
}

Set-Environment -excelPath "$psscriptroot\Server Role Templates.xlsx" `
				-envName "trn" `
				-dcHostname "sydtrndc01" `
				-rootDomain "apra.com.au" `
				-templateName "CLUSTERED (SIT,TRN,UAT)"

