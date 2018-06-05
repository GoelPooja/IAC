Configuration sCrmAagCfgOnSqlPrimary
{
    param (
        [Parameter(Mandatory = $True)]
        [string]$DomainAdminAccount,
        [Parameter(Mandatory = $True)]
        [string]$CrmAagName,
        [Parameter(Mandatory = $True)]
        [String]$CrmPrimarySqlServer,
        [Parameter(Mandatory = $True)]
        [string]$CrmPrimarySqlInstance,
        [Parameter(Mandatory = $True)]
        [string]$CrmSecondarySqlServer,
        [Parameter(Mandatory = $True)]
        [string]$CRMSecondarySqlInstance,


        [Parameter(Mandatory = $True)]
        [string]$EnvName,
        [Parameter(Mandatory = $True)]
        [string]$CrmPrivRepGrp,
        [Parameter(Mandatory = $True)]
        [string]$CrmRepGrp,
        [Parameter(Mandatory = $True)]
        [string]$CrmSqlAccessGrp,
        [Parameter(Mandatory = $True)]
        [string]$MediaShare,
        [Parameter(Mandatory = $True)]
        [string]$Domain
    )

    Import-DscResource -ModuleName xSqlServer
    Import-DscResource -ModuleName ClefDscResources
    Import-DscResource -ModuleName xRobocopy

    xSQLServerDatabaseRecoveryModel ChangeCrmOrgDbRecModel
    {
        PsDscRunAsCredential = $DomainAdminAccount
        Name = "ApraAmcos_MSCRM"
        SQLServer = $CrmPrimarySqlServer
        SQLInstanceName = $CrmPrimarySqlInstance
        RecoveryModel = 'Full'
    }

    cAddDbToAag AddCrmDbToAag
    {
        DependsOn = '[xSQLServerDatabaseRecoveryModel]ChangeCrmOrgDbRecModel'
        PsDscRunAsCredential = $DomainAdminAccount
        DatabaseNames = @("ApraAmcos_MSCRM", "MSCRM_Config")
        SqlAlwaysOnAvailabilityGroupName = $CrmAagName
        PrimaryReplica = $CrmPrimarySqlServer + "\" + $CrmPrimarySqlInstance
        SecondaryReplica = $CrmSecondarySqlServer + "\" + $CRMSecondarySqlInstance
        SqlAdministratorCredential = $DomainAdminAccount
    }

    xSQLServerLogin AddCrmPrivRepGrpToSecondary
    {
        PsDscRunAsCredential = $DomainAdminAccount
        Ensure = 'Present'
        Name = $EnvName + "\" + $CrmPrivRepGrp
        LoginType = 'WindowsGroup'
        SQLServer = $CrmSecondarySqlServer
        SQLInstanceName = $CRMSecondarySqlInstance
    }

    xSQLServerLogin AddCrmRepGrpToSecondary
    {
        PsDscRunAsCredential = $DomainAdminAccount
        Ensure = 'Present'
        Name = $EnvName + "\" + $CrmRepGrp
        LoginType = 'WindowsGroup'
        SQLServer = $CrmSecondarySqlServer
        SQLInstanceName = $CRMSecondarySqlInstance
    }

    xSQLServerLogin AddSqlAccessGrpToSecondary
    {
        PsDscRunAsCredential = $DomainAdminAccount
        Ensure = 'Present'
        Name = $EnvName + "\" + $CrmSqlAccessGrp
        LoginType = 'WindowsGroup'
        SQLServer = $CrmSecondarySqlServer
        SQLInstanceName = $CRMSecondarySqlInstance
    }

    xRobocopy CopyCrmSqlClrHelper
    {
        PsDscRunAsCredential = $DomainAdminAccount
        Source = $MediaShare + "\CrmTools"
        Destination = "\\" + $CrmSecondarySqlServer + "." + $Domain + "\C$\Media"
    }

    xSQLServerScript CreateAsymKey
    {
        DependsOn = '[xRobocopy]CopyCrmSqlClrHelper'
        PsDscRunAsCredential = $DomainAdminAccount
        ServerInstance = $CrmSecondarySqlServer + "\" + $CRMSecondarySqlInstance
        TestFilePath = 'C:\Media\CrmTools\CreateAsymKeyScripts\Test-RunSQLScript.sql'
        SetFilePath = 'C:\Media\CrmTools\CreateAsymKeyScripts\Set-RunSQLScript.sql'
        GetFilePath = 'C:\Media\CrmTools\CreateAsymKeyScripts\Get-RunSQLScript.sql'
    }

    xSQLServerScript CreateCRMSqlClrLogin
    {
        DependsOn = '[xSQLServerScript]CreateAsymKey'
        PsDscRunAsCredential = $DomainAdminAccount
        ServerInstance = $CrmSecondarySqlServer + "\" + $CRMSecondarySqlInstance
        TestFilePath = 'C:\Media\CrmTools\CreateCRMSqlClrLoginScripts\Test-RunSQLScript.sql'
        SetFilePath = 'C:\Media\CrmTools\CreateCRMSqlClrLoginScripts\Set-RunSQLScript.sql'
        GetFilePath = 'C:\Media\CrmTools\CreateCRMSqlClrLoginScripts\Get-RunSQLScript.sql'
    }

}