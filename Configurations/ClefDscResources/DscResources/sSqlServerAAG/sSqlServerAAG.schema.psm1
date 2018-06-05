Configuration sSqlServerAAG
{
	param (
		[Parameter(Mandatory = $true)]
		[string]$AAGName,
		[Parameter(Mandatory = $true)]
		[int]$AAGPort,
		[Parameter(Mandatory = $true)]
		[PSCredential]$SysAdminAccount,
		[Parameter(Mandatory = $true)]
		[PSCredential]$RunServiceAccount,
		[Parameter(Mandatory = $true)]
		[int]$PrimaryInstanceNumber,
		[Parameter(Mandatory = $true)]
		[string]$SqlInstanceBaseName,
		[Parameter(Mandatory = $true)]
		[string]$ClusterIP,
		[Parameter(Mandatory = $true)]
		[string]$AagIP,
		[Parameter(Mandatory = $true)]
		[string]$SourceMediaPath,
		[Parameter(Mandatory = $true)]
		[string]$SqlMediaPath,
		[Parameter(Mandatory = $true)]
		[string]$SqlUpdatesPath,
		[Parameter(Mandatory = $true)]
		[string]$ProductKey,
		[Parameter(Mandatory = $true)]
		[string]$SubnetMask,
		[Parameter(Mandatory = $true)]
		[int]$InstanceNumber,
		[Parameter(Mandatory = $true)]
		[string]$ClusterName,
		[Parameter(Mandatory = $true)]
		[string]$Domain,
		[Parameter(Mandatory = $true)]
		[string]$QuorumSharePath,
		[Parameter(Mandatory = $true)]
		[string]$SQLServer
	)
	
	Import-DSCResource -Name sSqlServer
	Import-DSCResource -Name sSqlFailoverCluster
	Import-DSCResource -ModuleName xSqlServer
	
	$SqlInstanceNumber = 1
	$PrimarySqlInstance = $true
	if ($InstanceNumber -ne $PrimaryInstanceNumber)
	{
		$SqlInstanceNumber = 2
		$PrimarySqlInstance = $false
	}
	$SqlInstanceName = $SqlInstanceBaseName + $SqlInstanceNumber.ToString("00")
	$PrimaryClusterNode = $true
	if ($InstanceNumber -ne 1 -and $PrimarySqlInstance)
	{
		$PrimaryClusterNode = $false
	}
	sSqlServer BaseInstance
	{
		SqlInstanceName = $SqlInstanceName
		DeployServiceAccount = $SysAdminAccount
		RunServiceAccount = $RunServiceAccount
		SourceMediaPath = $SourceMediaPath
		SqlMediaPath = $SqlMediaPath
		ProductKey = $ProductKey
		Domain = $Domain
	}
	
	WindowsFeature RsatADPS
	{
		DependsOn ="[sSqlServer]BaseInstance"
		Name = "RSAT-AD-PowerShell"
		Ensure = "Present"
		Source = "$SourceMediaPath\WinMedia"
	}
	
	sSqlFailoverCluster SqlClusterGroup
	{
		ClusterName = $ClusterName
		ClusterIPAddress = $ClusterIP
		QuorumSharePath = $QuorumSharePath
		DomainAdminCredential = $SysAdminAccount
		PrimaryNode = $PrimaryClusterNode
		DependsOn ="[WindowsFeature]RsatADPS"
		Domain = $Domain
	}
	
	xSQLServerAlwaysOnService AlwaysOnService
	{
		Ensure = "Present"
		SQLServer = $SQLServer
		SQLInstanceName = $SqlInstanceName
		DependsOn = "[sSqlFailoverCluster]SqlClusterGroup"
	}
	
	# Adding the required service account to allow the cluster to log into SQL
	xSQLServerLogin AddNTServiceClusSvc
	{
		Ensure = 'Present'
		Name = 'NT AUTHORITY\SYSTEM'
		LoginType = 'WindowsUser'
		SQLServer = $SQLServer
		SQLInstanceName = $SqlInstanceName
		PsDscRunAsCredential = $SysAdminAccount
		DependsOn = "[xSQLServerAlwaysOnService]AlwaysOnService"
	}
	
	# Add the required permissions to the cluster service login
	xSQLServerPermission AddNTServiceClusSvcPermissions
	{
		DependsOn = "[xSQLServerLogin]AddNTServiceClusSvc"
		Ensure = 'Present'
		NodeName = $SQLServer
		InstanceName = $SqlInstanceName
		Principal = 'NT AUTHORITY\SYSTEM'
		Permission = 'AlterAnyAvailabilityGroup', 'ViewServerState'
		PsDscRunAsCredential = $SysAdminAccount
	}
	
	# Create a DatabaseMirroring endpoint
	xSQLServerEndpoint HADREndpoint
	{
		EndPointName = "HADR"
		Ensure = 'Present'
		Port = $AAGPort + 1
		SQLServer = $SQLServer
		SQLInstanceName = $SqlInstanceName
		PsDscRunAsCredential = $SysAdminAccount
		DependsOn = '[xSQLServerPermission]AddNTServiceClusSvcPermissions'
	}
	
	if ($PrimarySqlInstance)
	{
		# Create the availability group on the instance tagged as the primary replica
		xSQLServerAlwaysOnAvailabilityGroup AddAAG
		{
			Ensure = 'Present'
			Name = $AAGName
			SQLInstanceName = $SqlInstanceName
			SQLServer = $SQLServer
			DependsOn = '[xSQLServerEndpoint]HADREndpoint', '[xSQLServerPermission]AddNTServiceClusSvcPermissions'
			PsDscRunAsCredential = $SysAdminAccount
			AutomatedBackupPreference = "Secondary"
			AvailabilityMode = "SynchronousCommit"
			ConnectionModeInPrimaryRole = "AllowAllConnections"
			ConnectionModeInSecondaryRole = "AllowNoConnections"
			FailureConditionLevel = "OnModerateServerErrors"
			FailoverMode = "Automatic"
		}
		
		xSQLServerAvailabilityGroupListener AddAAGListener
		{
			DependsOn = '[xSQLServerAlwaysOnAvailabilityGroup]AddAAG'
			InstanceName = $SqlInstanceName
			AvailabilityGroup = $AAGName
			NodeName = $SQLServer
			Ensure = "Present"
			Name = "$AAGName"
			IpAddress = @("$AagIP/$SubnetMask")
			Port = $AAGPort
			DHCP = $false
		}
	}
	else
	{
		xWaitForAvailabilityGroup waitforAAG
		{
			Name = $AAGName
			RetryIntervalSec = 5
			RetryCount = 60
			DependsOn = "[xSQLServerEndpoint]HADREndpoint"
		}
		
		xSQLServerAlwaysOnAvailabilityGroupReplica AddReplica
		{
			Ensure = 'Present'
			Name = "$SQLServer\$SqlInstanceName"
			AvailabilityGroupName = "$AAGName"
			SQLServer = $SQLServer
			SQLInstanceName = $SqlInstanceName
			PrimaryReplicaSQLServer = $SQLServer.Replace($InstanceNumber, $PrimaryInstanceNumber.ToString("00"))
			PrimaryReplicaSQLInstanceName = $SqlInstanceBaseName + "01"
			PsDscRunAsCredential = $SysAdminAccount
			AvailabilityMode = "SynchronousCommit"
			FailoverMode = "Automatic"
			DependsOn = "[xWaitForAvailabilityGroup]waitforAAG"
		}
	}
}