Configuration CLEF
{
	Import-DSCResource -Module ClefDscResources
	[string]$EnvironmentName = Get-AutomationVariable -Name 'EnvironmentName'
	[PSCredential]$DomainAdmin = Get-AutomationPSCredential -Name 'DomainAdmin'
	$DomainUser = $DomainAdmin.UserName
	$DomainPassword = $DomainAdmin.GetNetworkCredential().Password
	[string]$numberNodes = Get-AutomationVariable -Name 'DYN.DB_Nodes'
	$DomainName = Get-AutomationVariable -Name 'Domain'
	$ProjectName = Get-AutomationVariable -Name 'TeamProject'
	$VstsUrl = Get-AutomationVariable -Name 'VstsUrl'
	$token = Get-AutomationVariable -Name 'AgentToken'
	
	[string]$MediaShare = Get-AutomationVariable -Name 'MediaShare'
	[string]$SqlKey = Get-AutomationVariable -Name 'SqlKey2016'
	
	#Generated Variables (from Excel)
	[PSCredential]$SvcAccountCLEFDB = Get-AutomationPSCredential -Name 'clefdb' 
	[string]$CLEFDBClusterVIP = Get-AutomationVariable -Name 'trn_CLEF.DB_WSFC_SQL_VIP'
	[string]$ClefdbAagVIP = Get-AutomationVariable -Name 'trn_CLEF.DB_AAG_CLEFDB_VIP'
	[string]$ClefdbAagPort = (Get-AutomationVariable -Name 'trn_CLEF.DB_AAG_CLEFDB_Ports').Split(",")[0]
	[string]$SubnetMask = Get-AutomationVariable -Name 'SubnetMask'
	[string]$ClusterName = $EnvironmentName + "_CLEFDB"
    
<#    Node DBX
	{
		[string] $SqlProductKey = Get-AutomationVariable -Name 'SqlProductKey2016'
		[string] $EnvironmentName = Get-AutomationVariable -Name 'EnvironmentName'
		[PSCredential]$DomainAdmin = Get-AutomationVariable -Name 'DomainAdmin'
		[string]$MediaShare = Get-AutomationVariable -Name 'MediaShare'
		[string]$SqlKey = Get-AutomationVariable -Name 'SqlKey2016'
		[string]$SvcAccount = Get-AutomationVariable -Name 'SqlKey2016'
		
		[string]$nodeName = $Env:ComputerName
		[string]$baseName = $nodeName.SubString(0, $nodeName.Length - 2)
		[int]$nodeNumber = 0
		[bool]$isNumber = [int]::TryParse($nodeName.SubString($nodeName.Length - 2), [ref]$nodeNumber)
		
		sSqlServer SingleInstance
		{
			SqlInstanceName = "$EnvironmentName" + "CLEFDBX" + $nodeNumber.ToString("00")
			DeployServiceAccount = $DomainAdmin
			SourceMediaPath = "$MediaShare"
			SqlUpdatesPath = "$Env:SystemDrive\Media\SQL2016\Updates"
			ProductKey = $SqlKey
			RunServiceAccount = $SvcAccount
		}
		sMDS StaticDataManagement
		{
			DeployServiceAccount = $DomainAdmin
			SourceMediaPath = "$MediaShare\WinMedia"
			SqlMediaPath = "$Env:SystemDrive\Media\SQL2016"
			SqlUpdatesPath = "$Env:SystemDrive\Media\SQL2016\Updates"
			ProductKey = $SqlKey
		}
        sSqlDatabase ClefDB {  }
        sSqlDatabase ServiceBusDB {  }
        sSqlDatabase ClefReportingDB {  }
        
        SSRS ClefReportingService {  }
        SSAS ClefAnalysisService {  }
        SSIS ClefIntegrationService {  }
        
        xSMBShare ClefSharedFolder { 
			Ensure = "Present" 
            Name   = "SMBShare1"
            Path = "C:\Users\Duser1\Desktop"  
            ReadAccess = "User1"
            NoAccess = @("User3", "User4")
            Description = "This is an updated description for this share"
		}
    }
    
    Node CLEF_DB
    {
        sSqlAAG ClefAAGCluster { } 
        sMDS StaticDataManagement { }
        sSqlDB ClefDB {  }
    }
    
    Node SSRS
    {
        sSSRS ClefReportingService {  }
    }
    
    Node SSAS
    {
        sSSAS ClefAnalysisService {  }
    }
    
    Node SSIS
    {
        sSSIS ClefIntegrationService { }
    }
    
    Node FileStore
    {
         xSMB ClefSharedFolder {  }
	}#>
	
	Node $AllNodes.Where{ $_.NodeName.StartsWith("CLEFAPI", "CurrentCultureIgnoreCase") }.NodeName
	{
		
		[string[]]$tags = Get-AutomationVariable -Name 'CLEFAPI_Tags'
		
		cInitialSetup CIS
		{
			DomainName = $DomainName
			DomainCreds = $DomainAdmin
			OU = "OU=CLEF, OU=Servers, DC=trn, DC=apra, DC=com, DC=au"
			Disks = @{ }
		}
		
		cWebServer ApiServer
		{
			Name = "Web-*"
			FeatureName = ""
			Ensure = "Present"
			IncludeAllSubFeature = $true
		}
	
		cVSTSAgent Agent
		{
			MachineGroup = "Training"
			Tags = $tags
			Ensure = "Present"
			ProjectName = $ProjectName
			VstsUrl = $VstsUrl
			token = $token
			Username = $DomainUser
			Password = $DomainPassword
			InstallFolder = "C:\agent"
			workFolder = "C:\agent\_work"
		}
	}
	
	Node $AllNodes.Where{ $_.NodeName.StartsWith("CLEFDB", "CurrentCultureIgnoreCase") }.NodeName
	{
		
		cInitialSetup CIS
		{
			DomainName = $DomainName
			DomainCreds = $DomainAdmin
			OU = "OU=CLEF, OU=Servers, DC=trn, DC=apra, DC=com, DC=au"
			Disks = @{ }
		}
		
		sSqlServerAAG CLEFDB
		{
			DependsOn = '[cInitialSetup]CIS'
			AAGName = $EnvironmentName + "-CLEFDB-AAG"
			AAGPort = $ClefdbAagPort
			SysAdminAccount = $DomainAdmin
			RunServiceAccount = $SvcAccountCLEFDB
			PrimaryInstanceNumber = 1
			SqlInstanceBaseName = $EnvironmentName + "_CLEFDB"
			ClusterIP = $CLEFDBClusterVIP
			AagIP = $ClefdbAagVIP
			SourceMediaPath = "$MediaShare"
			SqlMediaPath = "$MediaShare\SQL2016"
			SqlUpdatesPath = "$Env:SystemDrive\Media\SQL2016\Updates"
			ProductKey = $SqlKey
			SubnetMask = $SubnetMask
			InstanceNumber = $Node.Instance
			ClusterName = $ClusterName
			Domain = $DomainName
			QuorumSharePath = "\\sydtrndc01\ClusterQuorum"
			SQLServer = $Node.VmName
		}
	}
}