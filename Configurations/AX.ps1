Configuration AX
{
	
	$DomainName = Get-AutomationVariable -Name 'Domain'
	[PSCredential]$DomainAdmin = Get-AutomationPSCredential -Name 'DomainAdmin'
	$DomainUser = $DomainAdmin.UserName
	$DomainPassword = $DomainAdmin.GetNetworkCredential().Password
	$ProjectName = Get-AutomationVariable -Name 'TeamProject'
	$VstsUrl = Get-AutomationVariable -Name 'VstsUrl'
	$token = Get-AutomationVariable -Name 'AgentToken'
	
	
	Import-DSCResource -ModuleName ClefDscResources
	
	
	Node $AllNodes.Where{ $_.NodeName.StartsWith("AXUsr", "CurrentCultureIgnoreCase") }.NodeName
	{
		[string[]]$tags = Get-AutomationVariable -Name 'AXUsr_Tags'
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
	}
	
	Node $AllNodes.Where{ $_.NodeName.StartsWith("AXApp", "CurrentCultureIgnoreCase") }.NodeName
	{
		[string[]]$tags = Get-AutomationVariable -Name 'AXApp_Tags'
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
	}
	
	Node $AllNodes.Where{ $_.NodeName.StartsWith("AXBat", "CurrentCultureIgnoreCase") }.NodeName
	{
		[string[]]$tags = Get-AutomationVariable -Name 'AXBat_Tags'
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
	}
	
	Node $AllNodes.Where{ $_.NodeName.StartsWith("AXUtil", "CurrentCultureIgnoreCase") }.NodeName
	{
		[string[]]$tags = Get-AutomationVariable -Name 'AXUtil_Tags'
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
	}
	
	Node $AllNodes.Where{ $_.NodeName.StartsWith("AXAtls", "CurrentCultureIgnoreCase") }.NodeName
	{
		[string[]]$tags = Get-AutomationVariable -Name 'AXAtls_Tags'
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
	}	
	
}
