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
		[string]$SourceMediaPath,
		[Parameter(Mandatory = $True)]
		[string]$SqlMediaPath,
		[Parameter(Mandatory = $True)]
		[string]$ProductKey,
		[Parameter(Mandatory = $True)]
		[string]$Domain,
		[Parameter(Mandatory = $True)]
		[PSCredential]$RunServiceAccount
	)
	Import-DSCResource -Name sSqlFormatDisk
	Import-DSCResource -ModuleName xSqlServer
	
	[string]$mountRoot = "C:\Mount"
	[string]$logsDiskLabel = "SQLLogs"
	[string]$logsFolder = "Logs"
	[string]$dataDiskLabel = "SQLData"
	[string]$dataFolder = "Data"
	[string]$dataTempFolder = "TempDB"
	[string]$dataBkupFolder = "Backup"
	
	File LogDiskAccessPath
	{
		Ensure = "Present"
		Type = "Directory"
		DestinationPath = "$mountRoot\$logsDiskLabel"
	}
	
	File DataDiskAccessPath
	{
		Ensure = "Present"
		Type = "Directory"
		DestinationPath = "$mountRoot\$dataDiskLabel"
	}
	
	sSqlFormatDisk LogDisk
	{
		DependsOn = '[File]LogDiskAccessPath'
		DiskNumber = 1
		DriveLetter = 'E'
		Label = $logsDiskLabel
		FoldersToCreate = @($logsFolder)
		AccessPath = "$mountRoot\$logsDiskLabel"
	}
	
	sSqlFormatDisk DataDisk
	{
		DependsOn = '[File]DataDiskAccessPath'
		DiskNumber = 2
		DriveLetter = 'F'
		Label = $dataDiskLabel
		FoldersToCreate = @($dataFolder, $dataTempFolder, $dataBkupFolder)
		AccessPath = "$mountRoot\$dataDiskLabel"
	}
	
	WindowsFeature DotNet35
	{
		Name = "NET-Framework-Core"
		Ensure = "Present"
		Source = "$SourceMediaPath\WinMedia"
	}
	
	File SQLMediaPath
	{
		Ensure = "Present"
		Type = "Directory"
		DestinationPath = "C:\Media"
		SourcePath =  "$SqlMediaPath"
		Recurse = $true
	}
	
	[hashtable]$SqlFeatures = `
	@{
		"SQLENGINE" = "SQL Server Engine";
		"FULLTEXT" = "Full Text Search";
		"DQ" = "Data Quality Services";
		"DQC" = "Data Quality Client";
		"CONN" = "Client Tools Connectivity";
		"BC" = "Client Tools Backward Compatibility";
		"SDK" = "Client Tools SDK";
		"AS" = "Analysis Services";
		"RS" = "Reporting Services – Native";
		"SSMS" = "Management Tools – Basic";
		"ADV_SSMS" = "Management Tools – Complete"
	}
	
	if ($SqlMediaPath.Contains("2016"))
	{
		$SqlFeatures.Remove("SSMS")
		$SqlFeatures.Remove("ADV_SSMS")
	}
	
	foreach($Feature in $AdditionalFeatures)
	{
		$SqlFeatures.Add($Feature, $Feature)
	}
	
	$Features = ""
	
	foreach($Feature in $SqlFeatures.GetEnumerator())
	{
		$Features += $Feature.Key + ","
	}
	
	$Features = $Features.Substring(0, $Features.Length - 1)
	
	xSQLServerSetup Instance
	{
		DependsOn = '[sSqlFormatDisk]LogDisk', '[sSqlFormatDisk]DataDisk', '[WindowsFeature]DotNet35', '[File]SQLMediaPath'
		
		Action = "Install"
		InstanceName = $SqlInstanceName
		SetupCredential = $DeployServiceAccount
		SourcePath = "C:\Media"
		ForceReboot = $True
		Features = $Features
		ProductKey = $ProductKey
		SQMReporting = $False
		ErrorReporting = $False
		
		SQLSvcAccount = $RunServiceAccount
		AgtSvcAccount = $RunServiceAccount
		FTSvcAccount = $RunServiceAccount
		
		SQLCollation = "Latin1_General_CI_AS"
		
		SQLSysAdminAccounts = "$Domain\Domain Admins"
		
		SQLUserDBLogDir = "$mountRoot\$logsDiskLabel\$logsFolder\$SqlInstanceName"
		SQLUserDBDir = "$mountRoot\$dataDiskLabel\$dataFolder\$SqlInstanceName"
		SQLTempDBDir = "$mountRoot\$dataDiskLabel\$dataTempFolder\$SqlInstanceName"
		SQLTempDBLogDir = "$mountRoot\$dataDiskLabel\$dataTempFolder\$SqlInstanceName"
		SQLBackupDir = "$mountRoot\$dataDiskLabel\$dataBkupFolder\$SqlInstanceName"
		
		BrowserSvcStartupType = "Automatic"
	}
	
	xSQLServerNetwork EnableTcp
	{
		DependsOn = '[xSQLServerSetup]Instance'
		InstanceName = $SqlInstanceName
		ProtocolName = "tcp"
		IsEnabled = $true
		RestartService = $true
		PsDscRunAsCredential = $DeployServiceAccount
		TCPDynamicPorts = "0"
	}
}