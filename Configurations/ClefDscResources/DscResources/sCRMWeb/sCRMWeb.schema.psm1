Configuration sCRMWeb
{
    param (
        [Parameter(Mandatory = $True)]
		[string]$MediaShare,
        [Parameter(Mandatory = $True)]
		[PSCredential]$DomainAdminAccount,
        [Parameter(Mandatory = $True)]
		[String]$CrmWebNodeName,
        [Parameter(Mandatory = $True)]
		[String]$Domain
    )

    WindowsFeature RsatADPS
    {
        Name = "RSAT-AD-PowerShell"
        Ensure = "Present"
        DependsOn = ""
        Source = $MediaShare + "\WinMedia"
    }
    
    Script SetSPNForCrmWeb
    {
        PsDscRunAsCredential = $DomainAdminAccount
        TestScript = {
            $CrmWebSvr = $Using:CrmWebNodeName
            $ThisDomain = $Using:Domain
            [string[]]$Result = Get-ADUser -Filter 'Name -like "*crmapp*"' -Properties name, serviceprincipalname -ErrorAction Stop | Select-Object -ExpandProperty serviceprincipalname
            if ( ($Result -match ($CrmWebSvr + "." + $ThisDomain)) -and ($Result -match $CrmWebSvr) ) { $True }
            Else { $False }
        }
        SetScript = {
            Import-Module -Name ActiveDirectory
            $CrmWebSvr = $Using:CrmNodeName
            $ThisDomain = $Using:Domain
            Set-ADObject -Identity ((Get-ADUser -Filter 'Name -like "*crmapp*"' -ErrorAction Stop).DistinguishedName) -add @{serviceprincipalname= "http/" + $CrmWebSvr + "." + $ThisDomain} -ErrorVariable SPNerror -ErrorAction SilentlyContinue
            Set-ADObject -Identity ((Get-ADUser -Filter 'Name -like "*crmapp*"' -ErrorAction Stop).DistinguishedName) -add @{serviceprincipalname= "http/" + $CrmWebSvr} -ErrorVariable SPNerror -ErrorAction SilentlyContinue
        }
        GetScript = { 
            @{Result = "SetSPNForCrmWeb"} 
        }
    }

    Script CRMWebConfiguration
    {
        TestScript = {
            $IsUsingAppPoolCreds = Get-WebConfigurationProperty -Location 'Microsoft Dynamics CRM' -Filter "system.webServer/security/authentication/windowsAuthentication" -Name "useAppPoolCredentials"
            If ( $IsUsingAppPoolCreds.value -eq "false" ) { $False }
            Else { $True }
        }
        SetScript = {
            Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -location 'Microsoft Dynamics CRM' -filter "system.webServer/security/authentication/windowsAuthentication" -name "useAppPoolCredentials" -value "True" -ErrorAction SilentlyContinue
        }
        GetScript = { 
            @{Result = "CRMWebConfiguration"} 
        }
    }

    Script CRMWebBindings
    {
        DependsOn = "[Script]CRMWebConfiguration"
        TestScript = {
            if ( (Get-WebBinding -Name "Microsoft Dynamics CRM").bindingInformation -like "*:80:*" ) { $true }
            Else { $false }
        }

        SetScript = {
            Set-WebBinding -Name 'Microsoft Dynamics CRM' -BindingInformation ":5555:" -PropertyName Port -Value 80
            Set-WebBinding -Name 'Microsoft Dynamics CRM' -BindingInformation "*:5555:" -PropertyName Port -Value 80
            Restart-Service "w3svc" -Force
        }

        GetScript = {
            @{Result = "CRMWebBindings"}
        }
    }

}