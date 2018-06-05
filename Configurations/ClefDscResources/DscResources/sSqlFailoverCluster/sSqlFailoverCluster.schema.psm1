Configuration sSqlFailoverCluster
{
    param(
        [Parameter(Mandatory=$True)]
        [string]$ClusterName,
        
        [Parameter(Mandatory=$True)]
        [string]$ClusterIPAddress,
        
        [Parameter(Mandatory=$True)]
        [string]$QuorumSharePath,
        
        [Parameter(Mandatory=$True)]
		[PSCredential]$DomainAdminCredential,
		
		[Parameter(Mandatory = $True)]
		[bool]$PrimaryNode,
		
		[Parameter(Mandatory = $true)]
		[string]$Domain
    )
	
	Import-DSCResource -ModuleName xFailOverCluster
	Import-DSCResource -ModuleName xSmbShare
    
    WindowsFeature FailoverFeature
    {
        Ensure = "Present"
        Name   = "Failover-clustering"
    }

    WindowsFeature RSATClusteringPowerShell
    {
        Ensure = "Present"
        Name   = "RSAT-Clustering-PowerShell"   

        DependsOn = "[WindowsFeature]FailoverFeature"
	}
	
	WindowsFeature RSATClusteringMgmt
	{
		Ensure = "Present"
		Name = "RSAT-Clustering-Mgmt"
		
		DependsOn = "[WindowsFeature]FailoverFeature"
	}
	
	WindowsFeature RSATClusteringCmdInterface
	{
		Ensure = "Present"
		Name = "RSAT-Clustering-CmdInterface"
		
		DependsOn = "[WindowsFeature]RSATClusteringPowerShell"
	}
	
	# Only do these next ones if we are on the primary node
    if($PrimaryNode)
	{
		xCluster SetupCluster
        {
            Name = $ClusterName
            StaticIPAddress = $ClusterIPAddress
            DomainAdministratorCredential = $DomainAdminCredential
			PsDscRunAsCredential = $DomainAdminCredential
            DependsOn = "[WindowsFeature]RSATClusteringCmdInterface"
		}
		
		xWaitForCluster WaitForCluster
		{
			Name = $ClusterName
			RetryIntervalSec = 5
			RetryCount = 60
			PsDscRunAsCredential = $DomainAdminCredential			
			DependsOn = "[xCluster]SetupCluster"
		}
		
		cAccessControl ClusterOUPermissions
		{
			Name = $ClusterName
			Type = "Computer"
			PsDscRunAsCredential = $DomainAdminCredential
			DependsOn = "[xWaitForCluster]WaitForCluster"
		}		
		
		xClusterQuorum SetupQuorum
        {
            IsSingleInstance = "Yes"
            Type = "NodeAndFileShareMajority"
            Resource = $QuorumSharePath
			PsDscRunAsCredential = $DomainAdminCredential
            DependsOn = "[xCluster]SetupCluster"
        }
    }
    else
    {
        xWaitForCluster WaitForCluster
        {
            Name = $ClusterName
            RetryIntervalSec = 5
            RetryCount = 60
            PsDscRunAsCredential = $DomainAdminCredential

            DependsOn = "[WindowsFeature]RSATClusteringCmdInterface"
        }

        xCluster JoinCluster
        {
            Name = $ClusterName
            StaticIPAddress = $ClusterIPAddress
            DomainAdministratorCredential = $DomainAdminCredential
			PsDscRunAsCredential = $DomainAdminCredential
            DependsOn = "[xWaitForCluster]WaitForCluster"
        }  
    }
}