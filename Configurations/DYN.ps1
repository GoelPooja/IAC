Configuration DYN
{
	#Explicit Variables
	[string]$EnvironmentName = Get-AutomationVariable -Name 'EnvironmentName'
	[PSCredential]$DomainAdmin = Get-AutomationPSCredential -Name 'DomainAdmin'
	$DomainUser = $DomainAdmin.UserName
	$DomainPassword = $DomainAdmin.GetNetworkCredential().Password
	[string]$numberNodes = Get-AutomationVariable -Name 'DYN.DB_Nodes'
	$DomainName = Get-AutomationVariable -Name 'Domain'	
	
	[string]$MediaShare = Get-AutomationVariable -Name 'MediaShare'
	[string]$SqlKey = Get-AutomationVariable -Name 'SqlKey2014'
	
	$ProjectName = Get-AutomationVariable -Name 'TeamProject'
	$VstsUrl = Get-AutomationVariable -Name 'VstsUrl'
	$token = Get-AutomationVariable -Name 'AgentToken'
	
	#Generated Variables (from Excel)
	[PSCredential]$SvcAccountAX = Get-AutomationPSCredential -Name 'axdb'
	[PSCredential]$SvcAccountCRM = Get-AutomationPSCredential -Name 'crmdb'
	[string]$DynDBClusterVIP = Get-AutomationVariable -Name 'trn_DYN.DB_WSFC_SQL_VIP'
	[string]$AxAagVIP = Get-AutomationVariable -Name 'trn_DYN.DB_AAG_AX_VIP'
	[string]$CrmAagVIP = Get-AutomationVariable -Name 'trn_DYN.DB_AAG_CRM_VIP'
	[string]$AxAagPort = (Get-AutomationVariable -Name 'trn_DYN.DB_AAG_AX_Ports').Split(",")[0]
	[string]$CrmAagPort = (Get-AutomationVariable -Name 'trn_DYN.DB_AAG_CRM_Ports').Split(",")[0]
	[string]$SubnetMask = Get-AutomationVariable -Name 'SubnetMask'
	[string]$ClusterName = $EnvironmentName + "_DYN"
	
	Import-DSCResource -ModuleName ClefDscResources
	
	
	Node $AllNodes.Where{$_.NodeName.StartsWith("DYNDB", "CurrentCultureIgnoreCase") }.NodeName
	{
		
		[string[]]$tags = Get-AutomationVariable -Name 'DYNDB_Tags'
		cInitialSetup CIS
		{
			DomainName = $DomainName
			DomainCreds = $DomainAdmin
			OU = "OU=CLEF, OU=Servers, DC=trn, DC=apra, DC=com, DC=au"
			Disks = @{ }
		}
		
		cVSTSAgent Agent
		{
			DependsOn = '[cInitialSetup]CIS'
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
		
		sSqlServerAAG AX
		{
			DependsOn = '[cInitialSetup]CIS'
			AAGName = $EnvironmentName + "-AX-AAG"
			AAGPort = $AxAagPort
			SysAdminAccount = $DomainAdmin
			RunServiceAccount = $SvcAccountAX
			PrimaryInstanceNumber = 1
			SqlInstanceBaseName = $EnvironmentName + "_AX"
			ClusterIP = $DynDBClusterVIP
			AagIP = $AxAagVIP
			SourceMediaPath = "$MediaShare"
			SqlMediaPath = "$MediaShare\SQL2014"
			SqlUpdatesPath = "$Env:SystemDrive\Media\SQL2016\Updates"
			ProductKey = $SqlKey
			SubnetMask = $SubnetMask
			InstanceNumber = $Node.Instance
			ClusterName = $ClusterName
			Domain = $DomainName
			QuorumSharePath = "\\sydtrndc01\ClusterQuorum"
			SQLServer = $Node.VmName
		}
		
		sSqlServerAAG CRM
		{
			DependsOn = '[cInitialSetup]CIS'
			AAGName = $EnvironmentName + "-CRM-AAG"
			AAGPort = $CrmAagPort
			SysAdminAccount = $DomainAdmin
			RunServiceAccount = $SvcAccountCRM
			PrimaryInstanceNumber = 2
			SqlInstanceBaseName = $EnvironmentName + "_CRM"
			ClusterIP = $DynDBClusterVIP
			AagIP = $CrmAagVIP
			SourceMediaPath = "$MediaShare"
			SqlMediaPath = "$MediaShare\SQL2014"
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
	# Setup KingswaySoft on CRM Primary
	
}