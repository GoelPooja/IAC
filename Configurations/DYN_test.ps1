Configuration DYN
{
	#Explicit Variables
	[string]$EnvironmentName = 'TRN'
	[PSCredential]$DomainAdmin = New-Object System.Management.Automation.PSCredential ("adam", (ConvertTo-SecureString -String "password" -AsPlainText -Force))
	[string]$MediaShare = 'MediaShare'
	[int]$numberNodes = 2
	[string]$DomainName = "domain"
	
	Import-DSCResource -ModuleName ClefDscResources
	
	
	
	Node $AllNodes.NodeName
	{
		#Explicit Variables
		[string]$SqlKey = 'SqlKey2014'
		
		#Generated Variables (from Excel)
		[PSCredential]$SvcAccountAX = New-Object System.Management.Automation.PSCredential ("adam", (ConvertTo-SecureString -String "password" -AsPlainText -Force))
		[PSCredential]$SvcAccountCRM = New-Object System.Management.Automation.PSCredential ("adam", (ConvertTo-SecureString -String "password" -AsPlainText -Force))
		[string]$DynDBClusterVIP = 'DYN.DB_WSFC'
		[string]$AxAagVIP = 'AX_WSFC_VIP'
		[string]$CrmAagVIP = 'CRM_WSFC_VIP'
		[int]$AxAagPort = 5555
		[int]$CrmAagPort = 6666
		[string]$SubnetMask = 'SubnetMask'
		[string]$ClusterName = $EnvironmentName + "_DYN"
		
		
		
		
		sSqlServerAAG AX
		{
			AAGName = $EnvironmentName + "-AX-AAG"
			AAGPort = $AxAagPort
			SysAdminAccount = $DomainAdmin
			RunServiceAccount = $SvcAccountAX
			PrimaryInstanceNumber = 1
			SqlInstanceBaseName = $EnvironmentName + "_AX"
			ClusterIP = $DynDBClusterVIP
			AagIP = $AxAagVIP
			SourceMediaPath = "$MediaShare"
			SqlUpdatesPath = "$Env:SystemDrive\Media\SQL2016\Updates"
			ProductKey = $SqlKey
			SubnetMask = $SubnetMask
			InstanceNumber = $Node.Instance
			ClusterName = $ClusterName
			Domain = $DomainName
			QuorumSharePath = "\\" + $Node.VmName + "\ClusterQuorum"
		}
		
		sSqlServerAAG CRM
		{
			AAGName = $EnvironmentName + "-CRM-AAG"
			AAGPort = $CrmAagPort
			SysAdminAccount = $DomainAdmin
			RunServiceAccount = $SvcAccountCRM
			PrimaryInstanceNumber = 2
			SqlInstanceBaseName = $EnvironmentName + "_CRM"
			ClusterIP = $DynDBClusterVIP
			AagIP = $CrmAagVIP
			SourceMediaPath = "$MediaShare"
			SqlUpdatesPath = "$Env:SystemDrive\Media\SQL2016\Updates"
			ProductKey = $SqlKey
			SubnetMask = $SubnetMask
			InstanceNumber = $Node.Instance
			ClusterName = $ClusterName
			Domain = $DomainName
			QuorumSharePath = "\\" + $Node.VmName + "\ClusterQuorum"
		}
	}
	# Setup KingswaySoft on CRM Primary
	
}

$configData = @{
	AllNodes = @(
		@{
			NodeName = "DYNDB01"
			InstanceNumber = 1
			PSDscAllowPlainTextPassword = $true
		}
		@{
			NodeName = "DYNDB02"
			InstanceNumber = 2
			PSDscAllowPlainTextPassword = $true
		}
	)
}

DYN -ConfigurationData $configData