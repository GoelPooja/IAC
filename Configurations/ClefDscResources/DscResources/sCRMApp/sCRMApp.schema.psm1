Configuration sCRMApp
{
    param (
        [Parameter(Mandatory = $True)]
		[PSCredential]$DomainAdminAccount,
        [Parameter(Mandatory = $True)]
		[string]$Domain,
        [Parameter(Mandatory = $True)]
		[string]$CrmPrimarySqlServer,
        [Parameter(Mandatory = $True)]
		[string]$CRMPrimarySqlInstance
    )

    Script CrmNewOrg
    {
        PsDscRunAsCredential = $DomainAdminAccount
        TestScript = {
            Add-PSSnapin Microsoft.Crm.PowerShell
            If ( (Get-CrmOrganization).FriendlyName -ne $null )
            {
                If ( (Get-CrmOrganization).FriendlyName -eq "Apra Amcos" ) { $true }
                Else { $false }
            }
            Else { $false }
        }

        SetScript = {
            Add-PSSnapin Microsoft.Crm.PowerShell
            [switch]$WaitForJob=$True
            [string]$SrsUrl = "http://" + $Using:CrmPrimarySqlServer + "." + $Using:Domain + "/" + "ReportServer_" + $Using:CRMPrimarySqlInstance
            [string]$SqlServerName = $Using:CrmPrimarySqlServer + "\" + $Using:CRMPrimarySqlInstance
            $newCrmOrg = New-CrmOrganization -DisplayName "Apra Amcos" `
            -SqlServerName $SqlServerName `
            -SrsUrl $SrsUrl `
            -Name "Apra Amcos" `
            -BaseCurrencyCode "AUD" `
            -BaseCurrencyName "Australian Dollar" `
            -BaseCurrencySymbol "$" `
            -BaseCurrencyPrecision "2" `
            -SqlCollation "Latin1_General_CI_AS" `
            -SQMOptIn "False" `
            -SysAdminName $Using:DomainAdminAccount
            
            if($WaitForJob)
            {
                $newCrmOrgStatus = Get-CrmOperationStatus -OperationId $newCrmOrg
                while($newCrmOrgStatus.State -eq "Processing")
                {
                    Write-Host [(Get-Date)] Processing...
                    Start-Sleep -s 30
                    $newCrmOrgStatus = Get-CrmOperationStatus -OperationId $newCrmOrg
                }
            }
            
            if($newCrmOrgStatus.State -eq "Failed")
            {
                Throw ($newCrmOrgStatus.ProcessingError.Message)
            }
            Write-Host [(Get-Date)] Create org completed successfully.
        }

        GetScript = {
            @{Result = "CrmNewOrg"}
        }
    }

    Script UpdateCrmNlbSettings
    {
        DependsOn = '[Script]CrmNewOrg'
        PsDscRunAsCredential = $DomainAdminAccount
        TestScript = {
            $WebSettings = Get-CrmSetting -SettingType WebAddressSettings
            $CrmNlbUrl = "crm." + $Using:Domain + ":80"
            If ($WebSettings.DeploymentSdkRootDomain -eq $CrmNlbUrl -and $WebSettings.DiscoveryRootDomain -eq $CrmNlbUrl -and $WebSettings.SdkRootDomain -eq $CrmNlbUrl -and $WebSettings.WebAppRootDomain -eq $CrmNlbUrl) {
                $True
            }
            Else{
                $False
            }
        }
        SetScript = {
            Add-PSSnapin Microsoft.CRM.PowerShell
            $WebSettings = Get-CrmSetting -SettingType WebAddressSettings
            $WebSettings.NlbEnabled = "true"
            $WebSettings.DeploymentSdkRootDomain = "crm." + $Using:Domain + ":80"
            $WebSettings.DiscoveryRootDomain = "crm." + $Using:Domain + ":80"
            $WebSettings.SdkRootDomain = "crm." + $Using:Domain + ":80"
            $WebSettings.WebAppRootDomain = "crm." + $Using:Domain + ":80"
            Set-CrmSetting -Setting $WebSettings
        }
        GetScript = {
            @{ Result= "UpdateCrmNlbSettings" }
        }
    }

}