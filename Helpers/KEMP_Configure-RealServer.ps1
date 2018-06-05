function Configure-RealServer {
[CmdletBinding()]
	param (	     
        [Parameter(Mandatory)]
		[string]$ServerIP,
        [Parameter(Mandatory)]
        [string]$KempIPAddress,
        [Parameter(Mandatory)]
        [PSCredential]$KempCred,
        [Parameter(Mandatory)]
        [string]$VirtualService,
        [int]$ServerPort,
        [int]$VSPort,
        [switch]$Disabled,
        [string]$Weight,
        [switch]$IsCritical,     
        [switch]$RemoveServer,
        [string]$CertLocation,
        [string]$CertName,
        [string]$Limit
        )

Initialize-Lm -Address $KempIPAddress -LBPort 443 -Credential $KempCred -Verbose -ErrorAction Stop
$vs=Get-VirtualService -VirtualService $VirtualService
if([string]::IsNullOrWhiteSpace($ServerPort))
{
$ServerPort=$vs.VSPort
}
if($RemoveServer)
{
Remove-RealServer -RealServer $ServerIP `                 
                  -RealServerPort $ServerPort `
                  -VirtualService $VirtualService `
                  -Port $vs.VSPort `
                  -Protocol $vs.Protocol `
                  -Force
}
else
{
New-RealServer -RealServer $ServerIP `
               -RealServerPort $ServerPort `
               -VirtualService $VirtualService `
               -Port $vs.VSPort `
               -Protocol $vs.Protocol
if($Disabled)
{
Set-RealServer -RealServer $ServerIP `
               -RealServerPort $ServerPort `
               -VirtualService $VirtualService `
               -Port $vs.VSPort `
               -Protocol $vs.Protocol `
               -Enable $false
}
if($IsCritical)
{
Set-RealServer -RealServer $ServerIP `
               -RealServerPort $ServerPort `
               -VirtualService $VirtualService `
               -Port $vs.VSPort `
               -Protocol $vs.Protocol `
               -Critical $true
}
if(-not [string]::IsNullOrWhiteSpace($Weight))
{
Set-RealServer -RealServer $ServerIP `
               -RealServerPort $ServerPort `
               -VirtualService $VirtualService `
               -Port $vs.VSPort `
               -Protocol $vs.Protocol `
               -Weight ([convert]::ToInt32($Weight))
}
if(-Not [string]::IsNullOrWhiteSpace($CertName))
{
if([string]::IsNullOrWhiteSpace($CertLocation))
{
Set-RealServer -RealServer $ServerIP `
               -RealServerPort $ServerPort `
               -VirtualService $VirtualService `
               -Port $vs.VSPort `
               -Protocol $vs.Protocol `
               -SubjectCN $CertName
}
else
{
Set-RealServer -RealServer $ServerIP `
               -RealServerPort $ServerPort `
               -VirtualService $VirtualService `
               -Port $vs.VSPort `
               -Protocol $vs.Protocol `
               -SubjectCN $CertName `
               -CertificateStoreLocation $CertLocation
}
}
if(-not [string]::IsNullOrWhiteSpace($Limit))
{
if($vs.ForceL7 -eq "Y")
{
Set-RealServer -RealServer $ServerIP `
               -RealServerPort $ServerPort `
               -VirtualService $VirtualService `
               -Port $vs.VSPort `
               -Protocol $vs.Protocol `
               -Limit ([convert]::ToInt64($Limit))
}
else
{
Write-Error "Limit parameter is only valid when virtual service is operating on Layer 7"
}
}
}
}









