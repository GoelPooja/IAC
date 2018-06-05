$dbSqlServer = "axtest01\axdb03"
$mediaPath = "C:\Store\AX_2012Slipstream_CU11"
$aosAccount = "trn\svc_tra_axaos" #<aosAccount service account>
$aosAccountPassword = "Apra123$" #<aosAccount password>

$additionalModelFiles = $mediaPath + "\Models\Labels\FoundationLabels.axmodel"
$clientAosServer = $env:COMPUTERNAME
$aifWebServicesWebSite = "Default Web Site"
$media = $mediaPath + "\setup.exe"
$parameters = @" 
AcceptLicenseTerms=1 HideUI=1 ConfigurePrerequisites=1 OptInCEIP=0 UseMicrosoftUpdate=1 DbSqlServer=$dbSqlServer DbSqlDatabaseName=MicrosoftDynamicsAx InstallAos=1 AosInstanceName=MicrosoftDynamicsAx AosPort=2712 AosWsdlPort=8101 AosNetTcpPort=8201 AosStart=1 AosAccount=$aosAccount AosAccountPassword=$aosAccountPassword InstallClientUI=1 ClientConfig=1 ClientLanguage=en-US ClientAosServer=$clientAosServer ClientInstallType=1 CreateClientDesktopShortcut=1 InstallNetBusinessConnector=1 BusinessConnectorProxyAccount=$aosAccount BusinessConnectorProxyAccountPassword=$aosAccountPassword InstallAifWebServices=1 AifWebServicesWebSite="Default Web Site" AifWebServicesApplicationPool=MicrosoftDynamicsAXAif60 AifWebServicesVirtualDirectory=MicrosoftDynamicsAXAif60 AifWebServicesAosAccounts=$aosAccount InstallDebugger=1 InstallManagementUtilities=1
"@

$axInstProcess = Start-Process -FilePath $media -ArgumentList $parameters -Wait -PassThru
$axInstProcess.ExitCode

#Check if exit code is 0 (success) and stop the AOS service before proceeding to the AX installation on the next node.
If ($axInstProcess.ExitCode -eq 0)
{
	Write-Host "AX installation successful! Stopping AOS service now." -ForegroundColor Green
	if (!(Get-Service -Name "AOS60`$01").Status -eq "Stopped")
	{
		Stop-Service -Name "AOS60`$01"
		Start-Sleep -Seconds 60
		Write-Host "AOS Service is stopped"
	}
}
else
{
	Write-Host "AX Installation has failed." -ForegroundColor Magenta
}