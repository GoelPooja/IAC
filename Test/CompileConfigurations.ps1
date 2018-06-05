Enable-DscDebug -BreakAll

Configuration test
{
	param ([PSCredential]$cred)
	Import-DSCResource -ModuleName ClefDscResources
	Node localhost
	{
		sSqlFailoverCluster cluster
		{
			ClusterName = "clustername"
			ClusterIPAddress = "x.x.x.x"
			DomainAdminCredential = $cred
			QuorumSharePath = "path"
		}
		
		sMDS mds
		{
			DeployServiceAccount = $cred
			SourceMediaPath = "abc"
			SqlMediaPath = "abc"
			SqlUpdatesPath = "abc"
			ProductKey = "abc"
		}

		sXperiDoPreReqs xdnuc
        { 

        }

		sSqlFailoverCluster ssfc
		{
			ClusterName = "abc"
			ClusterIPAddress = "abc"
			QuorumSharePath = "abc"
			DomainAdminCredential = $cred
		}

		sSqlFormatDisk sfd
		{
			DiskNumber = 0
			DriveLetter = 'D'
			Label = "abc"
			FoldersToCreate = @("abc")
			AccessPath = "abc"
		}

		sSqlServer ss
		{
			SqlInstanceName = "abc"
			DeployServiceAccount = $cred
			SqlMediaPath = "abc"
			SqlUpdatesPath = "abc"
			ProductKey = "abc"
			RunServiceAccount = $cred
		}

		sSqlServerAAG ssaag
		{
			AAGName = "abc"
			AAGPort = 1234
			SysAdminAccount = $cred
			RunServiceAccount = $cred
			PrimaryNodeNumber = 1
			SqlInstanceName = "abc"
			ClusterIP = "abc"
			SqlMediaPath = "abc"
			SqlUpdatesPath = "abc"
			ProductKey = "abc"
		}
		
	}
}

$configData = @{
	AllNodes = @(
		@{
			NodeName = 'localhost';
			PSDscAllowPlainTextPassword = $true
		}
	)
}

$cred = New-Object System.Management.Automation.PSCredential("ServiceAccount", (ConvertTo-SecureString -String "Password" -AsPlainText -Force))

test -ConfigurationData $configData -cred $cred