Configuration sMDS
{
	param (
		[Parameter(Mandatory = $True)]
		[PSCredential]$DeployServiceAccount,
		[Parameter(Mandatory = $True)]
		[string]$SourceMediaPath,
		[Parameter(Mandatory = $True)]
		[string]$SqlMediaPath,
		[Parameter(Mandatory = $True)]
		[string]$SqlUpdatesPath,
		[Parameter(Mandatory = $True)]
		[string]$ProductKey
	)
	
	Import-DSCResource -ModuleName xSqlServer
	
	WindowsFeature DotNet35
	{
		Name = "NET-Framework-Core"
		Ensure = "Present"
		Source = $SourceMediaPath
	}
	
	xSQLServerSetup Instance
	{
		InstanceName = "MDS"
		Action = "Install"
		SetupCredential = $DeployServiceAccount
		SourcePath = $SqlMediaPath
		UpdateSource = $SqlUpdatesPath
		UpdateEnabled = $True
		Features = "MDS"
		ProductKey = $ProductKey
		DependsOn = '[WindowsFeature]DotNet35'
	}
}