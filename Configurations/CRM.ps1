Configuration CRM
{
	[string]$EnvironmentName = Get-AutomationVariable -Name 'EnvironmentName'
	[string]$MediaShare = Get-AutomationVariable -Name 'MediaShare'
	[PSCredential]$UserCrmApp = Get-AutomationPSCredential -Name 'crmapp'
	[PSCredential]$UserCrmAps = Get-AutomationPSCredential -Name 'crmaps'
	[PSCredential]$UserCrmSps = Get-AutomationPSCredential -Name 'crmsps'
	[PSCredential]$UserCrmDws = Get-AutomationPSCredential -Name 'crmdws'
	[PSCredential]$UserCrmMon = Get-AutomationPSCredential -Name 'crmmon'
	[PSCredential]$UserCrmVss = Get-AutomationPSCredential -Name 'crmvss'
	[PSCredential]$DomainAdminAccount = Get-AutomationPSCredential -Name 'DomainAdmin'
	[string]$CrmLicenseKey = Get-AutomationVariable -Name 'CrmLicenseKey'
	[string]$Domain = Get-AutomationVariable -Name 'Domain'
	#[string]$CrmPrimarySqlServer = Get-AutomationVariable -Name 'CrmPrimarySqlServer'
	#[string]$CrmPrimarySqlInstance = Get-AutomationVariable -Name 'CrmPrimarySqlInstance'

	[string[]]$CrmServiceAccounts = @($UserCrmApp.UserName, $UserCrmAps.UserName, $UserCrmSps.UserName, $UserCrmDws.UserName, $UserCrmMon.UserName, $UserCrmVss.UserName)
	[string[]]$IISGroupMembers = @($UserCrmApp.UserName, $UserCrmAps.UserName,$UserCrmDws.UserName)
	[string[]]$LocalAdminGroupMembers = @($UserCrmDws.UserName)
	[string[]]$PerfLogUsrsGroupMembers = @($UserCrmApp.UserName,$UserCrmAps.UserName)

	[string]$CrmAppUser = $UserCrmApp.GetNetworkCredential().UserName
	[string]$CrmApsUser = $UserCrmAps.GetNetworkCredential().UserName
	[string]$CrmDwsUser = $UserCrmDws.GetNetworkCredential().UserName
	[string]$CrmSpsUser = $UserCrmSps.GetNetworkCredential().UserName
	[string]$CrmMonUser = $UserCrmMon.GetNetworkCredential().UserName
	[string]$CrmVssUser = $UserCrmVss.GetNetworkCredential().UserName

	[string]$CrmAppUserPwd = $UserCrmApp.GetNetworkCredential().Password
	[string]$CrmApsUserPwd = $UserCrmAps.GetNetworkCredential().Password
	[string]$CrmSpsUserPwd = $UserCrmSps.GetNetworkCredential().Password
	[string]$CrmDwsUserPwd = $UserCrmDws.GetNetworkCredential().Password
	[string]$CrmMonUserPwd = $UserCrmMon.GetNetworkCredential().Password
	[string]$CrmVssUserPwd = $UserCrmVss.GetNetworkCredential().Password

	Import-DscResource -ModuleName ClefDscResources

	Node $AllNodes.Where{$_.NodeName.StartsWith("CRMWEB01", "CurrentCultureIgnoreCase")}.NodeName
	{
		cInitialSetup CrmCIS
		{
			DomainName = $Domain
			DomainCreds = $DomainAdminAccount
			OU = "OU=CLEF, OU=Servers, DC=trn, DC=apra, DC=com, DC=au"
			Disks = @{ }
		}

		sCRMBase CrmBaseInstallOnWeb01
		{
			DependsOn = '[cInitialSetup]CrmCIS'
			EnvironmentName = $EnvironmentName
			CrmServiceAccounts = $CrmServiceAccounts
			DomainAdminAccount = $DomainAdminAccount
			IISGroupMembers = $IISGroupMembers
			LocalAdminGroupMembers = $LocalAdminGroupMembers
			PerfLogUsrsGroupMembers = $PerfLogUsrsGroupMembers
			CrmDwsUser = $CrmDwsUser
			CrmAppUser = $CrmAppUser
			CrmApsUser = $CrmApsUser
			CrmSpsUser = $CrmSpsUser
			CrmMonUser = $CrmMonUser
			CrmVssUser = $CrmVssUser
			CrmAppUserPwd = $CrmAppUserPwd
			CrmApsUserPwd = $CrmApsUserPwd
			CrmSpsUserPwd = $CrmSpsUserPwd
			CrmDwsUserPwd = $CrmDwsUserPwd
			CrmMonUserPwd = $CrmMonUserPwd
			CrmVssUserPwd = $CrmVssUserPwd
			CrmLicenseKey = $CrmLicenseKey
			Domain = $Domain
			CrmPrimarySqlServer = "SYD" + $EnvironmentName + "DYNDB02"
			CrmPrimarySqlInstance = $EnvironmentName + "_CRM01"
			MediaShare = $MediaShare
			DatabaseFlag = "True"
			CRMFeatures = @("WebApplicationServer", "OrganizationWebService", "DiscoveryWebService", "HelpServer")
		}
	}

	Node $AllNodes.Where{$_.NodeName.StartsWith("CRMWEB02", "CurrentCultureIgnoreCase")}.NodeName
	{
		WaitForAll CrmWeb01Installation
		{
			PsDscRunAsCredential = $DomainAdminAccount
			ResourceName = '[sCRMBase]CrmBaseInstallOnWeb01'
			NodeName = "SYD" + $EnvironmentName + "CRMWEB01." + $Domain
			RetryIntervalSec = 30
			RetryCount = 120
		}

		cInitialSetup CrmCIS
		{
			DomainName = $Domain
			DomainCreds = $DomainAdminAccount
			OU = "OU=CLEF, OU=Servers, DC=trn, DC=apra, DC=com, DC=au"
			Disks = @{ }
		}

		sCRMBase CrmBaseInstallOnWeb02
		{
			DependsOn = '[cInitialSetup]CrmCIS', '[WaitForAll]CrmWeb01Installation'
			EnvironmentName = $EnvironmentName
			CrmServiceAccounts = $CrmServiceAccounts
			DomainAdminAccount = $DomainAdminAccount
			IISGroupMembers = $IISGroupMembers
			LocalAdminGroupMembers = $LocalAdminGroupMembers
			PerfLogUsrsGroupMembers = $PerfLogUsrsGroupMembers
			CrmDwsUser = $CrmDwsUser
			CrmAppUser = $CrmAppUser
			CrmApsUser = $CrmApsUser
			CrmSpsUser = $CrmSpsUser
			CrmMonUser = $CrmMonUser
			CrmVssUser = $CrmVssUser
			CrmAppUserPwd = $CrmAppUserPwd
			CrmApsUserPwd = $CrmApsUserPwd
			CrmSpsUserPwd = $CrmSpsUserPwd
			CrmDwsUserPwd = $CrmDwsUserPwd
			CrmMonUserPwd = $CrmMonUserPwd
			CrmVssUserPwd = $CrmVssUserPwd
			CrmLicenseKey = $CrmLicenseKey
			Domain = $Domain
			CrmPrimarySqlServer = "SYD" + $EnvironmentName + "DYNDB02"
			CrmPrimarySqlInstance = $EnvironmentName + "_CRM01"
			MediaShare = $MediaShare
			DatabaseFlag = "False"
			CRMFeatures = @("WebApplicationServer", "OrganizationWebService", "DiscoveryWebService", "HelpServer")
		}
	}

	Node $AllNodes.Where{$_.NodeName.StartsWith("CRMAPP", "CurrentCultureIgnoreCase")}.NodeName
	{
		WaitForAll CrmWeb01Installation
		{
			PsDscRunAsCredential = $DomainAdminAccount
			ResourceName = '[sCRMBase]CrmBaseInstallOnWeb01'
			NodeName = "SYD" + $EnvironmentName + "CRMWEB01." + $Domain
			RetryIntervalSec = 30
			RetryCount = 120
		}

		cInitialSetup CrmCIS
		{
			DomainName = $Domain
			DomainCreds = $DomainAdminAccount
			OU = "OU=CLEF, OU=Servers, DC=trn, DC=apra, DC=com, DC=au"
			Disks = @{ }
		}

		sCRMBase CrmBaseInstallOnApp
		{
			DependsOn = '[cInitialSetup]CrmCIS', '[WaitForAll]CrmWeb01Installation'
			EnvironmentName = $EnvironmentName
			CrmServiceAccounts = $CrmServiceAccounts
			DomainAdminAccount = $DomainAdminAccount
			IISGroupMembers = $IISGroupMembers
			LocalAdminGroupMembers = $LocalAdminGroupMembers
			PerfLogUsrsGroupMembers = $PerfLogUsrsGroupMembers
			CrmDwsUser = $CrmDwsUser
			CrmAppUser = $CrmAppUser
			CrmApsUser = $CrmApsUser
			CrmSpsUser = $CrmSpsUser
			CrmMonUser = $CrmMonUser
			CrmVssUser = $CrmVssUser
			CrmAppUserPwd = $CrmAppUserPwd
			CrmApsUserPwd = $CrmApsUserPwd
			CrmSpsUserPwd = $CrmSpsUserPwd
			CrmDwsUserPwd = $CrmDwsUserPwd
			CrmMonUserPwd = $CrmMonUserPwd
			CrmVssUserPwd = $CrmVssUserPwd
			CrmLicenseKey = $CrmLicenseKey
			Domain = $Domain
			CrmPrimarySqlServer = "SYD" + $EnvironmentName + "DYNDB02"
			CrmPrimarySqlInstance = $EnvironmentName + "_CRM01"
			MediaShare = $MediaShare
			DatabaseFlag = "False"
			CRMFeatures = @("DeploymentTools", "DeploymentWebService", "VSSWriter")
		}
	}

	Node $AllNodes.Where{$_.NodeName.StartsWith("CRMSBX", "CurrentCultureIgnoreCase")}.NodeName
	{
		WaitForAll CrmWeb01Installation
		{
			PsDscRunAsCredential = $DomainAdminAccount
			ResourceName = '[sCRMBase]CrmBaseInstallOnWeb01'
			NodeName = "SYD" + $EnvironmentName + "CRMWEB01." + $Domain
			RetryIntervalSec = 30
			RetryCount = 120
		}

		cInitialSetup CrmCIS
		{
			DomainName = $Domain
			DomainCreds = $DomainAdminAccount
			OU = "OU=CLEF, OU=Servers, DC=trn, DC=apra, DC=com, DC=au"
			Disks = @{ }
		}

		sCRMBase CrmBaseInstallOnSbx
		{
			DependsOn = '[cInitialSetup]CrmCIS', '[WaitForAll]CrmWeb01Installation'
			EnvironmentName = $EnvironmentName
			CrmServiceAccounts = $CrmServiceAccounts
			DomainAdminAccount = $DomainAdminAccount
			IISGroupMembers = $IISGroupMembers
			LocalAdminGroupMembers = $LocalAdminGroupMembers
			PerfLogUsrsGroupMembers = $PerfLogUsrsGroupMembers
			CrmDwsUser = $CrmDwsUser
			CrmAppUser = $CrmAppUser
			CrmApsUser = $CrmApsUser
			CrmSpsUser = $CrmSpsUser
			CrmMonUser = $CrmMonUser
			CrmVssUser = $CrmVssUser
			CrmAppUserPwd = $CrmAppUserPwd
			CrmApsUserPwd = $CrmApsUserPwd
			CrmSpsUserPwd = $CrmSpsUserPwd
			CrmDwsUserPwd = $CrmDwsUserPwd
			CrmMonUserPwd = $CrmMonUserPwd
			CrmVssUserPwd = $CrmVssUserPwd
			CrmLicenseKey = $CrmLicenseKey
			Domain = $Domain
			CrmPrimarySqlServer = "SYD" + $EnvironmentName + "DYNDB02"
			CrmPrimarySqlInstance = $EnvironmentName + "_CRM01"
			MediaShare = $MediaShare
			DatabaseFlag = "False"
			CRMFeatures = @("EmailConnector", "AsynchronousProcessingService", "SandboxProcessingService")
		}
	}
}

    <#Node $AllNodes.Where{$_.NodeName.StartsWith("CRM", "CurrentCultureIgnoreCase")}.NodeName
	{
		$DatabaseFlag = "False"
		$CrmFeatures = ""
		If ($Node.NodeName.StartsWith("CRMWEB"))
		{
			If ($Node.Instance -eq "01" ) { $DatabaseFlag = "True" }
			$CrmFeatures = @("WebApplicationServer", "OrganizationWebService", "DiscoveryWebService", "HelpServer")
		}
		If ( $Node.NodeName.StartsWith("CRMSBX") )
		{
			$CrmFeatures = @("EmailConnector", "AsynchronousProcessingService", "SandboxProcessingService")
		}
		If ( $Node.NodeName.StartsWith("CRMAPP") )
		{
			$CrmFeatures = @("DeploymentTools", "DeploymentWebService", "VSSWriter")
		}
	
		cInitialSetup CrmCIS
		{
			DomainName = $Domain
			DomainCreds = $DomainAdminAccount
			OU = "OU=CLEF, OU=Servers, DC=trn, DC=apra, DC=com, DC=au"
			Disks = @{ }
		}

		sCRMBase CrmBaseInstallation
		{
			DependsOn = '[cInitialSetup]CrmCIS'
			EnvironmentName = $EnvironmentName
			CrmServiceAccounts = $CrmServiceAccounts
			DomainAdminAccount = $DomainAdminAccount
			IISGroupMembers = $IISGroupMembers
			LocalAdminGroupMembers = $LocalAdminGroupMembers
			PerfLogUsrsGroupMembers = $PerfLogUsrsGroupMembers
			CrmDwsUser = $CrmDwsUser
			CrmAppUser = $CrmAppUser
			CrmApsUser = $CrmApsUser
			CrmSpsUser = $CrmSpsUser
			CrmMonUser = $CrmMonUser
			CrmVssUser = $CrmVssUser
			CrmAppUserPwd = $CrmAppUserPwd
			CrmApsUserPwd = $CrmApsUserPwd
			CrmSpsUserPwd = $CrmSpsUserPwd
			CrmDwsUserPwd = $CrmDwsUserPwd
			CrmMonUserPwd = $CrmMonUserPwd
			CrmVssUserPwd = $CrmVssUserPwd
			CrmLicenseKey = $CrmLicenseKey
			Domain = $Domain
			CrmPrimarySqlServer = "SYD" + $EnvironmentName + "DYNDB02"
			CrmPrimarySqlInstance = $EnvironmentName + "_CRM01"
			MediaShare = $MediaShare
			DatabaseFlag = $DatabaseFlag
			CRMFeatures = $CrmFeatures
		}
    }

} #>
    
<#    Node Web
    {
        # sCrmWeb
    }
    
    Node App
    {
        # sCrmApp : WaitForOne (Crm.Web)
    }
    
    Node Sandbox
    {
        # sCrmSbx : WaitForOne (Crm.Web)
	}
	
	# sCrmBase
	# Base CRM Common Activity
	# - install .net 3.5 on all nodes
	# - install webserver IIS & Web-Mgmt-Tools
	# - install .net 4.6.2
	# # setup all service accounts (logon as service)
	# - populate configuration file & run installation
	
	
	# sCrmWeb
	# Install the CRM Web Role
	# - configure service account
	# - Base CRM
	# Set Web App Host config
	
	# sCrmApp
	# Install the CRM App Role
	# # create the CRM OU
	# - configure service account
	# - disable loopback check
	# - enable database permissions
	# - enable crmou access to service account
	# - Base CRM
	# - Database Reporting Server Extensions
	# - Create new organisation
	# - set SPNs for App Service Account
	# - Repoint to AAG endpoint
	
	# sCrmSbx
	# Install the CRM Sandbox Role
	# - configure service account
	# - Base CRM
	#>
