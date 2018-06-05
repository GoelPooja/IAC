Configuration SQL 
{	

    Import-DSCResource -ModuleName ClefDSCResources
	Import-DSCResource -ModuleName xSqlServer
	
	[string]$mountRoot = "C:\Mount"
	[string]$logsDiskLabel = "SQLLogs"
	[string]$logsFolder = "Logs"
	[string]$dataDiskLabel = "SQLData"
	[string]$dataFolder = "Data"
	[string]$dataTempFolder = "TempDB"
	[string]$dataBkupFolder = "Backup"
    $SourceMediaPath = "\\sydprodipam01.apra.com.au\CLEF_IaC"

     
    $RunServiceAccount = Get-Credential "trn\svc_env_crmapp"
    $DeployServiceAccount =  Get-Credential "trn\svcclefsetup"
    $SqlInstanceName = "TestInstance01"

	
    Node localhost
    {
	    File LogDiskAccessPath
        {
            Ensure          = "Present"
            Type            = "Directory"
            DestinationPath = "$mountRoot\$logsDiskLabel"
        }
         File DataDiskAccessPath
        {
            Ensure          = "Present"
            Type            = "Directory"
            DestinationPath = "$mountRoot\$dataDiskLabel"
        }
	    sSqlFormatDisk LogDisk
	    {
		    DiskNumber = 1
		    DriveLetter = 'E'
		    Label = $logsDiskLabel
		    FoldersToCreate = @($logsFolder)
		    AccessPath = "$mountRoot\$logsDiskLabel"
	    }

        sSqlFormatDisk DataDisk
	    {
		    DiskNumber = 2
		    DriveLetter = 'F'
		    Label = $dataDiskLabel
		    FoldersToCreate = @( $dataFolder, $dataTempFolder, $dataBkupFolder )
		    AccessPath = "$mountRoot\$dataDiskLabel"
	    }
        
        WindowsFeature DotNet35
	    {
		    Name = "NET-Framework-Core"
		    Ensure = "Present"
		    Source = "$SourceMediaPath\WinMedia"
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
	
	foreach($Feature in $AdditionalFeatures)
	{
		$SqlFeatures.Add($Feature, $Feature)
	}
	
	$Features = ""
	
	foreach($Feature in $SqlFeatures.Values)
	{
		$Features += $Feature + ","
	}
	
	$Features = $Features.Substring(0, $Features.Length - 1)

       File SQLMediaPath
        {
            Ensure          = "Present"
            Type            = "Directory"
            DestinationPath = "C:\Media"
            SourcePath =  "$SourceMediaPath\SQL2016"	
        }
	
	xSQLServerSetup Instance
	{
		DependsOn = '[sSqlFormatDisk]LogDisk', '[sSqlFormatDisk]DataDisk', '[WindowsFeature]DotNet35' , '[File]SQLMediaPath'
		
		Action = "Install"
		InstanceName = $SqlInstanceName
		SetupCredential = $DeployServiceAccount
		SourcePath = "C:\Media"		
		ForceReboot = $True
		Features = "SQLENGINE,FULLTEXT,RS,AS,IS"
		ProductKey = "22222-00000-00000-00000-00000"
		SQMReporting = $False
		ErrorReporting = $False
		
		SQLSvcAccount = $RunServiceAccount
		AgtSvcAccount = $RunServiceAccount
		FTSvcAccount = $RunServiceAccount
		
		SQLCollation = "Latin1_General_CI_AS"
		
		SQLSysAdminAccounts = "Administrators"
		
		SQLUserDBLogDir = "$mountRoot\$logsDiskLabel\$logsFolder\$SqlInstanceName"
		SQLUserDBDir = "$mountRoot\$dataDiskLabel\$dataFolder\$SqlInstanceName"
		SQLTempDBDir = "$mountRoot\$dataDiskLabel\$dataTempFolder\$SqlInstanceName"
		SQLTempDBLogDir = "$mountRoot\$dataDiskLabel\$dataTempFolder\$SqlInstanceName"
		SQLBackupDir = "$mountRoot\$dataDiskLabel\$dataBkupFolder\$SqlInstanceName"
		
		BrowserSvcStartupType = "Automatic"
	}      
}
}
$configData = @{
	AllNodes = @(
		@{
			NodeName = "localhost"			
			PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainuser = $true			
		}		
	)
}
SQL -ConfigurationData $configData