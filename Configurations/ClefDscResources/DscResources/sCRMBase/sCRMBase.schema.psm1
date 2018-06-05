Configuration sCRMBase
{
    param (
        [Parameter(Mandatory = $True)]
		[string]$EnvironmentName,
        [Parameter(Mandatory = $True)]
		[string]$MediaShare,
		[Parameter(Mandatory = $True)]
		[string[]]$CrmServiceAccounts,
		[Parameter(Mandatory = $True)]
		[PSCredential]$DomainAdminAccount,
        [Parameter(Mandatory = $True)]
		[string[]]$IISGroupMembers,
        [Parameter(Mandatory = $True)]
		[string[]]$LocalAdminGroupMembers,
        [Parameter(Mandatory = $True)]
		[string[]]$PerfLogUsrsGroupMembers,
        [Parameter(Mandatory = $True)]
		[string]$CrmDwsUser,
        [Parameter(Mandatory = $True)]
		[string]$CrmAppUser,
        [Parameter(Mandatory = $True)]
		[string]$CrmApsUser,
        [Parameter(Mandatory = $True)]
		[string]$CrmSpsUser,
        [Parameter(Mandatory = $True)]
		[string]$CrmMonUser,
        [Parameter(Mandatory = $True)]
		[string]$CrmVssUser,
        [Parameter(Mandatory = $True)]
		[string]$CrmLicenseKey,
        [Parameter(Mandatory = $True)]
		[string]$Domain,
        [Parameter(Mandatory = $True)]
		[string]$CrmPrimarySqlServer,
        [Parameter(Mandatory = $True)]
		[string]$CrmPrimarySqlInstance,
        [Parameter(Mandatory = $True)]
		[string]$DatabaseFlag,
        [Parameter(Mandatory = $True)]
		[string[]]$CRMFeatures,
        [Parameter(Mandatory = $True)]
		[string]$CrmAppUserPwd,
        [Parameter(Mandatory = $True)]
		[string]$CrmApsUserPwd,
        [Parameter(Mandatory = $True)]
		[string]$CrmSpsUserPwd,
        [Parameter(Mandatory = $True)]
		[string]$CrmDwsUserPwd,
        [Parameter(Mandatory = $True)]
		[string]$CrmMonUserPwd,
        [Parameter(Mandatory = $True)]
		[string]$CrmVssUserPwd
	)

    Import-DscResource -ModuleName cUserRightsAssignment, xSqlServer, xActiveDirectory, PSDesiredStateConfiguration

    xADOrganizationalUnit CreateCrmOU
    {
        Name = "CRM"
        Ensure = "Present"
        Description = "OU for CRM"
        Path = "OU=CLEF,OU=Services,DC=$(($domain).Split(".")[0]),DC=apra,DC=com,DC=au"
        ProtectedFromAccidentalDeletion = $False
        PsDscRunAsCredential = $DomainAdminAccount
    }

    WindowsFeature DotNet35
    {
        Name = "Net-Framework-Core"
        Ensure = "Present"
        Source = $MediaShare + "\WinMedia"
    }
    
    WindowsFeature IIS
    {
        Name = "Web-Server"
        Ensure = "Present"
        IncludeAllSubFeature = $true
        Source = $MediaShare + "\WinMedia"
    }
    
    WindowsFeature IISMgmtTools
    {
        Name = "Web-Mgmt-Tools"
        Ensure = "Present"
        IncludeAllSubFeature = $true
        Source = $MediaShare + "\WinMedia"
    }

    WindowsFeature RsatADPS
    {
        Name = "RSAT-AD-PowerShell"
        Ensure = "Present"
        Source = $MediaShare + "\WinMedia"
    }

    File MediaFolder
    {
        Type = 'Directory'
        DestinationPath = 'C:\Media'
        Ensure = 'Present'
    }
    
    File CopyDotNet462Media
    {
        DependsOn = '[File]MediaFolder'
        DestinationPath = 'C:\Media\DotNet462'
        Credential = $DomainAdminAccount
        Ensure = 'Present'
        Force = $True
        Recurse = $True
        SourcePath = "$MediaShare\DotNet462"
        Type = 'Directory'
        MatchSource = $True
    }
        
    Script InstallDotNet462
    {
        DependsOn = '[File]CopyDotNet462Media'
        TestScript = {
            $dotNetFull = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse |
            Get-ItemProperty -name Version,Release -EA 0 |
            Where-Object { $_.Version -match '4.6.01590' -and $_.PSChildName -eq 'Full' }
            If ($dotNetFull -eq $null) { $false } Else { $true } }
        SetScript = {
            $proc = Start-Process -FilePath "C:\Media\DotNet462\NDP462-KB3151800-x86-x64-AllOS-ENU.exe" -ArgumentList "/quiet /norestart /log C:\Media\DotNet462\NDP462-KB3151800-x86-x64-AllOS-ENU_install.log" -PassThru -Wait
            Switch($proc.ExitCode)
            {
                0 { <# Success #> }
                1603 { Throw "Failed installation" }
                1641 { <# Restart required #> $global:DSCMachineStatus = 1 }
                3010 { <# Restart required #> $global:DSCMachineStatus = 1 }
                5100 { Throw "Computer does not meet system requirements." }
                default { Throw "Unknown exit code $($proc.ExitCode)" }
            } }
        GetScript = { @{Result = "InstallDotNet462"} }
    }
    
	cUserRight LogOnAsServiceForCrmApp
    {
		Ensure = 'Present'
		Constant = 'SeServiceLogonRight'
		Principal = ($Domain.Split(".")[0]) + "\" + $CrmAppUser
	}

    cUserRight LogOnAsServiceForCrmAps
    {
		Ensure = 'Present'
		Constant = 'SeServiceLogonRight'
		Principal = ($Domain.Split(".")[0]) + "\" + $CrmApsUser
	}

    cUserRight LogOnAsServiceForCrmSps
    {
		Ensure = 'Present'
		Constant = 'SeServiceLogonRight'
		Principal = ($Domain.Split(".")[0]) + "\" + $CrmSpsUser
	}

    cUserRight LogOnAsServiceForCrmDws
    {
		Ensure = 'Present'
		Constant = 'SeServiceLogonRight'
		Principal = ($Domain.Split(".")[0]) + "\" + $CrmDwsUser
	}

    cUserRight LogOnAsServiceForCrmMon
    {
		Ensure = 'Present'
		Constant = 'SeServiceLogonRight'
		Principal = ($Domain.Split(".")[0]) + "\" + $CrmMonUser
	}

    cUserRight LogOnAsServiceForCrmVss
    {
		Ensure = 'Present'
		Constant = 'SeServiceLogonRight'
		Principal = ($Domain.Split(".")[0]) + "\" + $CrmVssUser
	}

    Group IISGrpMembership
    {
        GroupName = 'IIS_IUSRS'
        Ensure = 'Present'
        MembersToInclude =  $IISGroupMembers
        Credential = $DomainAdminAccount
    }

    Group LocalAdminsGrpMembership
    {
        GroupName = 'Administrators'
        Ensure = 'Present'
        MembersToInclude =  $LocalAdminGroupMembers
        Credential = $DomainAdminAccount
    }

    Group PerfLogUsrGrpMembership
    {
        GroupName = 'Performance Log Users'
        Ensure = 'Present'
        MembersToInclude =  $PerfLogUsrsGroupMembers
        Credential = $DomainAdminAccount
    }

    File CopySqlSmoMedia
    {
        DependsOn = '[File]MediaFolder'
        DestinationPath = 'C:\Media\PSModules'
        Credential = $DomainAdminAccount
        Ensure = 'Present'
        Force = $True
        Recurse = $True
        SourcePath = "$MediaShare\PSModules"
        Type = 'Directory'
        MatchSource = $True
    }

    Package InstallSQLSysClrTypes
    {
        DependsOn = '[File]CopySqlSmoMedia'
        Ensure = 'Present'
        Name = 'Microsoft System CLR Types for SQL Server 2014 (x64)'
        Path = 'C:\Media\PSModules\SQLSMO\SQLSysClrTypes.msi'
        ProductId = '65BC038D-2086-4C3B-90C5-A6798F044BD5'
    }

    Package InstallSmo
    {
        DependsOn = '[Package]InstallSQLSysClrTypes'
        Ensure = 'Present'
        Name = 'Microsoft SQL Server 2014 Management Objects  (x64)'
        Path = 'C:\Media\PSModules\SQLSMO\SharedManagementObjects.msi'
        ProductId = '1F9EB3B6-AED7-4AA7-B8F1-8E314B74B2A5'
    }

    Package InstallPowerShellTools
    {
        DependsOn = '[Package]InstallSmo'
        Ensure = 'Present'
        Name = 'Windows PowerShell Extensions for SQL Server 2014 '
        Path = 'C:\Media\PSModules\SQLSMO\PowerShellTools.msi'
        ProductId = '6A7D0067-CF88-453E-9EA5-A2008EC7CB19'
    }

    xSQLServerLogin AddCrmDwsAccountToSQL
    {
        DependsOn = '[Package]InstallPowerShellTools'
        Ensure = 'Present'
        Name = ($Domain.Split(".")[0]) + "\" + $CrmDwsUser
        LoginType = 'WindowsUser'
        SQLServer = $CrmPrimarySqlServer + "." + $Domain
        SQLInstanceName = $CrmPrimarySqlInstance
        PsDscRunAsCredential = $DomainAdminAccount
    }

    xSQLServerRole AddCrmDwsAccountToSysAdmin
    {
        DependsOn = '[xSQLServerLogin]AddCrmDwsAccountToSQL'
        Ensure = 'Present'
        MembersToInclude  = ($Domain.Split(".")[0]) + "\" + $CrmDwsUser
        ServerRoleName = "sysadmin"
        SQLServer = $CrmPrimarySqlServer + "." + $Domain
        SQLInstanceName = $CrmPrimarySqlInstance
        PsDscRunAsCredential = $DomainAdminAccount
        }

    File CopyCrmMedia
    {
        DependsOn = '[File]MediaFolder'
        DestinationPath = 'C:\Media\DynCRM2016SP1'
        Credential = $DomainAdminAccount
        Ensure = 'Present'
        Force = $True
        Recurse = $True
        SourcePath = "$MediaShare\DynCRM2016SP1"
        Type = 'Directory'
        MatchSource = $True
    }

    ## Delegate DWS user to have full permissions on the CRM OU. Need custom DSC Resource for this.
    Script CrmOUPermissions
    {
        DependsOn = '[xADOrganizationalUnit]CreateCrmOU', '[WindowsFeature]RsatADPS'
        PsDscRunAsCredential = $DomainAdminAccount
        TestScript = {
            $ThisDomain = $Using:Domain
            Import-Module -Name ActiveDirectory
            $AccessList = get-acl "ad:OU=CRM,OU=CLEF,OU=Services,DC=$($ThisDomain.Split(".")[0]),DC=apra,DC=com,DC=au"
            $CheckDwsUserAccess = $AccessList.Access | Where-Object {$_.IdentityReference -like "*dws*"}
            If($CheckDwsUserAccess){
                If(($CheckDwsUserAccess.ActiveDirectoryRights -eq "GenericAll") -and ($CheckDwsUserAccess.AccessControlType -eq "Allow") ) { $True }
            }
            Else { $False }
        }
        SetScript = {
            $ThisDomain = $Using:Domain
            Import-Module -Name ActiveDirectory
            $AccessList = get-acl "ad:OU=CRM,OU=CLEF,OU=Services,DC=$($ThisDomain.Split(".")[0]),DC=apra,DC=com,DC=au"
            $AccessObject = New-Object System.DirectoryServices.ActiveDirectoryAccessRule ([System.Security.Principal.IdentityReference] (Get-ADUser -Filter 'Name -like "*dws*"').SID),([System.DirectoryServices.ActiveDirectoryRights] "GenericAll"),([System.Security.AccessControl.AccessControlType] "Allow"),([System.DirectoryServices.ActiveDirectorySecurityInheritance] "All")
            $AccessList.AddAccessRule($AccessObject)
            Set-Acl -aclobject $AccessList "ad:OU=CRM,OU=CLEF,OU=Services,DC=$(($Using:domain).Split(".")[0]),DC=apra,DC=com,DC=au"
        }
        GetScript = { @{Result = "CrmOUPermissions"} }
    }

    Package CrmPreReqNativeClient
    {
        Ensure = 'Present'
        Name = 'Microsoft SQL Server 2008 Native Client'
        Path = 'C:\Media\DynCRM2016SP1\PreReqs\sqlncli.msi'
        ProductId = 'BBDE8A3D-64A2-43A6-95F3-C27B87DF7AC1'
    }

    Package CrmPreReqClrTypes
    {
        DependsOn = '[Package]CrmPreReqNativeClient'
        Ensure = 'Present'
        Name = 'Microsoft System CLR Types for SQL Server 2012 (x64)'
        Path = 'C:\Media\DynCRM2016SP1\PreReqs\SQLSysClrTypes.msi'
        ProductId = 'F1949145-EB64-4DE7-9D81-E6D27937146C'
    }

    Package CrmPreReqSmo
    {
        DependsOn = '[Package]CrmPreReqClrTypes'
        Ensure = 'Present'
        Name = 'Microsoft SQL Server 2012 Management Objects  (x64)'
        Path = 'C:\Media\DynCRM2016SP1\PreReqs\SharedManagementObjects.msi'
        ProductId = 'FA0A244E-F3C2-4589-B42A-3D522DE79A42'
    }

    Script SetSPNForCrmLB
    {
        DependsOn = '[Script]CrmOUPermissions'
        PsDscRunAsCredential = $DomainAdminAccount
        TestScript = {
            $ThisDomain = $Using:Domain
            [string[]]$Result = Get-ADUser -Filter 'Name -like "*crmapp*"' -Properties name, serviceprincipalname -ErrorAction Stop | Select-Object -ExpandProperty serviceprincipalname
            if(($Result -match ("http/crm." + $ThisDomain)) -and ($Result -match 'http/crm') ) { $True }
            Else { $False }
        }
        SetScript = {
            Import-Module -Name ActiveDirectory
            Set-ADObject -Identity ((Get-ADUser -Filter 'Name -like "*crmapp*"' -ErrorAction Stop).DistinguishedName) -add @{serviceprincipalname= "http/crm." + $Using:Domain} -ErrorVariable SPNerror -ErrorAction SilentlyContinue
            Set-ADObject -Identity ((Get-ADUser -Filter 'Name -like "*crmapp*"' -ErrorAction Stop).DistinguishedName) -add @{serviceprincipalname= "http/crm"} -ErrorVariable SPNerror -ErrorAction SilentlyContinue
        }
        GetScript = { @{Result = "SetSPNForCrmLB"} }
    }

	# - populate configuration file & run installation 
    Script UpdateCrmXmlBase
    {
        DependsOn = '[Script]InstallDotNet462', '[File]CopyCrmMedia', '[Script]SetSPNForCrmLB', '[xSQLServerRole]AddCrmDwsAccountToSysAdmin'
        TestScript = {
                [XML]$CrmXml = Get-Content -LiteralPath "C:\Media\DynCRM2016SP1\CRM2016Input.xml"
                if (($Using:CrmPrimarySqlServer + "\" + $Using:CrmPrimarySqlInstance) -eq ($CrmXml.CRMSetup.Server.SqlServer)) {
                    if (("http://" + $Using:CrmPrimarySqlServer + "." + $Using:domain + "/ReportServer_" + $Using:CrmPrimarySqlInstance) -eq ($CrmXml.CRMSetup.Server.Reporting.URL)) { 
                            $true 
                        }
                    }
                    Else { 
                            $false 
                        }
                    }
        
        SetScript = {
            [XML]$CrmXml = Get-Content -LiteralPath "C:\Media\DynCRM2016SP1\CRM2016Input.xml"
            $CrmXml.CRMSetup.Server.Patch.update = "false"
            $CrmXml.CRMSetup.Server.LicenseKey = $Using:CrmLicenseKey
            $CrmXml.CRMSetup.Server.SqlServer = $Using:CrmPrimarySqlServer + "\" + $Using:CrmPrimarySqlInstance
            $CrmXml.CRMSetup.Server.Database.create = $Using:DatabaseFlag
            $CrmXml.CRMSetup.Server.Organization = "Apra Amcos"
            $CrmXml.CRMSetup.Server.OrganizationUniqueName = "ApraAmcos"
            $CrmXml.CRMSetup.Server.basecurrency.currencyprecision = "2"
            $CrmXml.CRMSetup.Server.basecurrency.currencysymbol = "$"
            $CrmXml.CRMSetup.Server.basecurrency.currencyname = "Australian Dollar"
            $CrmXml.CRMSetup.Server.basecurrency.isocurrencycode = "AUD"
            $CrmXml.CRMSetup.Server.OrganizationCollation = "Latin1_General_CI_AS"
            $CrmXml.CRMSetup.Server.Reporting.URL = "http://" + $Using:CrmPrimarySqlServer + "." + $Using:domain + "/" + "ReportServer_" + $Using:CrmPrimarySqlInstance
            $CrmXml.CRMSetup.Server.OU = "OU=CRM,OU=CLEF,OU=Services,DC=$(($Using:domain).Split(".")[0]),DC=$(($Using:domain).Split(".")[1]),DC=$(($Using:domain).Split(".")[2]),DC=$(($Using:domain).Split(".")[3])"
            $CrmXml.CRMSetup.Server.InstallDir= "C:\Program Files\Microsoft Dynamics CRM"
            ForEach ($CrmRole in $Using:CRMFeatures)
            {
                $CrmXml.CRMSetup.Server.SelectNodes("Roles").AppendChild($CrmXml.CreateElement("Role")).SetAttribute("name", "$CrmRole")
            }
            #$CrmXml.CRMSetup.Server.SelectNodes("Roles").AppendChild($CrmXml.CreateElement("Role")).SetAttribute("name", "WebApplicationServer")
            #$CrmXml.CRMSetup.Server.SelectNodes("Roles").AppendChild($CrmXml.CreateElement("Role")).SetAttribute("name", "OrganizationWebService")
            #$CrmXml.CRMSetup.Server.SelectNodes("Roles").AppendChild($CrmXml.CreateElement("Role")).SetAttribute("name", "DiscoveryWebService")
            #$CrmXml.CRMSetup.Server.SelectNodes("Roles").AppendChild($CrmXml.CreateElement("Role")).SetAttribute("name", "HelpServer")
            $CrmXml.CRMSetup.Server.SQM.optin = "false"
            $CrmXml.CRMSetup.Server.SandboxServiceAccount.type = "DomainUser"
            $CrmXml.CRMSetup.Server.SandboxServiceAccount.ServiceAccountLogin = ($Domain.Split(".")[0]) + "\" + $Using:CrmSpsUser
            $CrmXml.CRMSetup.Server.SandboxServiceAccount.ServiceAccountPassword = $Using:CrmSpsUserPwd
            $CrmXml.CRMSetup.Server.AsyncServiceAccount.type = "DomainUser"
            $CrmXml.CRMSetup.Server.AsyncServiceAccount.ServiceAccountLogin = ($Domain.Split(".")[0]) + "\" + $Using:CrmApsUser
            $CrmXml.CRMSetup.Server.AsyncServiceAccount.ServiceAccountPassword = $Using:CrmApsUserPwd
            $CrmXml.CRMSetup.Server.VSSWriterServiceAccount.type = "DomainUser"
            $CrmXml.CRMSetup.Server.VSSWriterServiceAccount.ServiceAccountLogin = ($Domain.Split(".")[0]) + "\" + $Using:CrmVssUser
            $CrmXml.CRMSetup.Server.VSSWriterServiceAccount.ServiceAccountPassword = $Using:CrmVssUserPwd
            $CrmXml.CRMSetup.Server.DeploymentServiceAccount.type = "DomainUser"
            $CrmXml.CRMSetup.Server.DeploymentServiceAccount.ServiceAccountLogin = ($Domain.Split(".")[0]) + "\" + $Using:CrmDwsUser
            $CrmXml.CRMSetup.Server.DeploymentServiceAccount.ServiceAccountPassword = $Using:CrmDwsUserPwd
            $CrmXml.CRMSetup.Server.MonitoringServiceAccount.type = "DomainUser"
            $CrmXml.CRMSetup.Server.MonitoringServiceAccount.ServiceAccountLogin = ($Domain.Split(".")[0]) + "\" + $Using:CrmMonUser
            $CrmXml.CRMSetup.Server.MonitoringServiceAccount.ServiceAccountPassword = $Using:CrmMonUserPwd
            $CrmXml.CRMSetup.Server.CrmServiceAccount.type = "DomainUser"
            $CrmXml.CRMSetup.Server.CrmServiceAccount.ServiceAccountLogin = ($Domain.Split(".")[0]) + "\" + $Using:CrmAppUser
            $CrmXml.CRMSetup.Server.CrmServiceAccount.ServiceAccountPassword = $Using:CrmAppUserPwd
            $CrmXml.Save("C:\Media\DynCRM2016SP1\CRM2016Input.xml")
        }
        GetScript = { @{Result = "UpdateCrmXmlBase"} }
    }

    Package InstallCrmBase
    {
        DependsOn = '[Script]UpdateCrmXmlBase', '[Package]CrmPreReqSmo'
        Ensure = 'Present'
        Name = 'Microsoft Dynamics CRM Server 2016'
        Path = 'C:\Media\DynCRM2016SP1\Server\amd64\SetupServer.exe'
        ProductId = '0C524D55-1409-0080-BD7E-530E52560E52'
        Arguments = "/q /l C:\Media\DynCRM2016SP1\InstallLogs\ServerInstallLog.log /config C:\Media\DynCRM2016SP1\CRM2016Input.xml"
        PsDscRunAsCredential = $DomainAdminAccount
    }

    <#Script InstallCrmBase
    {
        PsDscRunAsCredential = $DomainAdminAccount
        DependsOn = '[Script]UpdateCrmXmlBase'
        TestScript = {
            $CrmVersion = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\MSCRM' -ea 0
            If ($CrmVersion -eq $null){ $False }
            Elseif ($CrmVersion.CRM_Server_Version -ne "8.0.0000.0000") { $False }
            Else { $True }
        }
        SetScript = {
            $CrmInstallerFile = "C:\Media\DynCRM2016SP1\Server\amd64\SetupServer.exe"
            $CrmInputFile = "C:\Media\DynCRM2016SP1\CRM2016Input.xml"
            $Arguments = "/Q /config $CrmInputFile"
            $process = Start-Process -FilePath $CrmInstallerFile -ArgumentList $Arguments -PassThru -Wait
            if($process.ExitCode -ne 0){
                Throw "Installation of CRM failed $($process.ExitCode)"
            }
        }
        GetScript = { @{Result = "InstallCrmBase"} }
    }#>

    
}