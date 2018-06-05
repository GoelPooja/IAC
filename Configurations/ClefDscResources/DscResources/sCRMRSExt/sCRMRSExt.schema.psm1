Configuration sCRMRSExt
{
    param(
        [Parameter(Mandatory = $True)]
        [string]$MediaShare,
        [Parameter(Mandatory = $True)]
        [string]$CrmPrimarySqlServer,
        [Parameter(Mandatory = $True)]
        [string]$CRMPrimarySqlInstance,
        [Parameter(Mandatory = $True)]
        [string]$Domain,
        [Parameter(Mandatory = $True)]
		[PSCredential]$CrmMonUser,
        [Parameter(Mandatory = $True)]
		[PSCredential]$DomainAdminAccount
    )

    File CopyCrmMedia
    {
        DestinationPath = "C:\Media"
        Credential = $DomainAdminAccount
        Ensure = 'Present'
        Force = $True
        Recurse = $True
        SourcePath = "$MediaShare\DynCRM2016SP1"
        Type = 'Directory'
        MatchSource = $False
    }

    Script UpdateCrmRSExtXml
    {
        DependsOn = "[File]CopyCrmMedia"
        TestScript = {
                [XML]$CrmXml = Get-Content -LiteralPath "C:\Media\DynCRM2016SP1\CRM2016RSExtInput.xml"
                if (($Using:CrmPrimarySqlServer + "\" + $Using:CRMPrimarySqlInstance) -eq ($CrmXml.CRMSetup.Server.SqlServer)) {
                    if (("http://" + $Using:CrmPrimarySqlServer + "." + $Using:Domain + "/ReportServer_" + $Using:CRMPrimarySqlInstance) -eq ($CrmXml.CRMSetup.Server.Reporting.URL)) { 
                            $return = $true 
                    }
                        else { 
                            $return = $false 
                        }
                }
        }
        
        SetScript = {
            [XML]$CrmXml = Get-Content -LiteralPath "C:\Media\DynCRM2016SP1\CRM2016RSExtInput.xml"
            $CrmXml.CRMSetup.Server.SqlServer = $Using:CrmPrimarySqlServer + "\" + $Using:CRMPrimarySqlInstance
            $CrmXml.CRMSetup.srsdataconnector.autogroupmanagementoff = "0"
            $CrmXml.CRMSetup.srsdataconnector.instancename = $Using:CRMPrimarySqlInstance
            $CrmXml.CRMSetup.srsdataconnector.patch.update = "false"
            $CrmXml.CRMSetup.srsdataconnector.muoptin.optin = "false"
            $CrmXml.CRMSetup.srsdataconnector.MonitoringServiceAccount.type = "DomainUser"
            $CrmXml.CRMSetup.srsdataconnector.MonitoringServiceAccount.ServiceAccountLogin = $(($Using:Domain).Split(".")[0]) + "\" + $Using:CrmMonUser.UserName
            $CrmXml.CRMSetup.srsdataconnector.MonitoringServiceAccount.ServiceAccountPassword = ($Using:CrmMonUser).GetNetworkCredential().password
            $CrmXml.Save("C:\Media\DynCRM2016SP1\CRM2016RSExtInput.xml")
        }
        GetScript = { @{Result = "UpdateCrmRSExtXml"} }
    }

    Script InstallCrmRSExt
    {
        PsDscRunAsCredential = $DomainAdminAccount
        DependsOn = "[Script]UpdateCrmRSExtXml"
        TestScript = {
            $CrmVersion = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\MSCRM' -ea 0
            If ($CrmVersion -eq $null){ $False }
            Elseif ($CrmVersion.CRM_SrsDataConnector_Version -ne "8.0.0000.0000") { $False }
            Else { $True }
        }
        SetScript = {
            $proc = Start-Process -FilePath "C:\Store\DynCRM2016SP1\Server\amd64\SrsDataConnector\SetupSrsDataConnector.exe" -ArgumentList "/Q /L C:\Store\CRMInstallLogs\SRSInstall_logs.log /config C:\Store\DynCRM2016SP1\CRM2016RSExtInput.xml" -PassThru -Wait
            if($proc.ExitCode -ne 0){
                Throw "Installation of CRM failed $($proc.ExitCode)"
            }
        }
        GetScript = { @{Result = "InstallCrmRSExt"} }
    }
}

