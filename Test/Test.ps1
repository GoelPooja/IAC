Configuration sSqlServer
{
	param (
		[Parameter(Mandatory = $True)]
		[string]$SqlInstanceName,
		[Parameter(Mandatory = $True)]
		[PSCredential]$DeployServiceAccount,
		[Parameter(Mandatory = $False)]
		[string[]]$AdditionalFeatures,
		[Parameter(Mandatory = $True)]
		[string]$SqlMediaPath,
		[Parameter(Mandatory = $True)]
		[string]$SqlUpdatesPath,
		[Parameter(Mandatory = $True)]
		[string]$ProductKey,
		#[Parameter(Mandatory = $True)]
		[PSCredential]$RunServiceAccount
	)
	Import-DSCResource –ModuleName PSDesiredStateConfiguration
	Import-DSCResource -Name sSqlFormatDisk
	Import-DSCResource -ModuleName xSqlServer
	
	
	[string]$mountRoot = "C:\Mount"
	[string]$logsDiskLabel = "SQLLogs"
	[string]$logsFolder = "Logs"
	[string]$dataDiskLabel = "SQLData"
	[string]$dataFolder = "Data"
	[string]$dataTempFolder = "TempDB"
	[string]$dataBkupFolder = "Backup"
	
	sSqlFormatDisk LogDisk
	{
		DiskNumber = 2
		DriveLetter = 'E'
		Label = $logsDiskLabel
		FoldersToCreate = { $logsFolder }
		AccessPath = "$mountRoot\$logsDiskLabel"
	}
	
	sSqlFormatDisk DataDisk
	{
		DiskNumber = 3
		DriveLetter = 'F'
		Label = $dataDiskLabel
		FoldersToCreate = { $dataFolder, $dataTempFolder, $dataBkupFolder }
		AccessPath = "$mountRoot\$dataDiskLabel"
	}
	
	WindowsFeature DotNet35
	{
		Name = "NET-Framework-Core"
		Ensure = "Present"
		Source = $SourceMediaPath
	}
	[hashtable]$SqlFeatures = `
	@{
		"SQLENGINE" = "SQL Engine";
		"FULLTEST" = "Full Text";
		"DQ" = "Data Quality";
		"DQC" = "Data Quality Client";
		"CONN" = "Client Tools Connectivity";
		"BC" = "Backward Compatibility";
		"SDK" = "Software Development Toolkit";
		"BOL" = "Books Online";
		"SNAC_SDK" = "SQL Client Connectivity SDK";
		"SSMS" = "SQL Server Management Studio";
		"ADV_SSMS" = "Advanced SSMS"
	}
	
	foreach ($Feature in $AdditionalFeatures)
	{
		$SqlFeatures.Add($Feature, $Feature)
	}
	
	$Features = ""
	foreach ($Feature in $SqlFeatures.Values)
	{
		$Features += $Feature + ","
	}
	$Features = $Features.Substring(0, $Features.Length - 1)
	$machineDomain = (Get-WmiObject Win32_ComputerSystem).Domain
#	xSQLServerSetup Instance
#	{
#		
#		
#		DependsOn = '[sSqlFormatDisk]LogDisk', '[sSqlFormatDisk]DataDisk', '[WindowsFeature]DotNet35'
#		
#		Action = "Install"
#		InstanceName = $SqlInstanceName
#		SetupCredential = $DeployServiceAccount
#		SourcePath = $SqlMediaPath
#		UpdateSource = $SqlUpdatesPath
#		UpdateEnabled = $True
#		ForceReboot = $True
#		Features = $Features
#		ProductKey = $ProductKey
#		SQMReporting = $False
#		ErrorReporting = $False
#		
#		#			SQLSvcAccount = $RunServiceAccount
#		#			AgtSvcAccount = $RunServiceAccount
#		#			FTSvcAccount = $RunServiceAccount
#		
#		SQLCollation = "Latin1_General_CI_AS"
#		
#		SQLSysAdminAccounts = { "$machineDomain\Domain Admins" }
#		
#		SQLUserDBLogDir = "$mountRoot\$logsDiskLabel\$logsFolder\$SqlInstanceName"
#		SQLUserDBDir = "$mountRoot\$dataDiskLabel\$dataFolder\$SqlInstanceName"
#		SQLTempDBDir = "$mountRoot\$dataDiskLabel\$dataTempFolder\$SqlInstanceName"
#		SQLTempDBLogDir = "$mountRoot\$dataDiskLabel\$dataTempFolder\$SqlInstanceName"
#		SQLBackupDir = "$mountRoot\$dataDiskLabel\$dataBkupFolder\$SqlInstanceName"
#		
#		BrowserSvcStartupType = "Automatic"
#	}
#	
	
}

#$cd = @{
#	AllNodes = @(
#		@{
#			NodeName = 'localhost'
#			PSDscAllowPlainTextPassword = $true
#		}
#	)
#}

$cred = New-Object System.Management.Automation.PSCredential("ServiceAccount", (ConvertTo-SecureString -String "Password" -AsPlainText -Force))
sSqlServer -SqlInstanceName "Test" -DeployServiceAccount $cred -SqlMediaPath "TestSqlMediaPath" -SqlUpdatesPath "TestSqlUpdatesPath" -ProductKey "ProductKey" 