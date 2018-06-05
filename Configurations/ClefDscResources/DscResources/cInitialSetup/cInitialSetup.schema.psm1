Configuration cInitialSetup
{
	param
	(
		[Parameter(Mandatory)]
		[String]$DomainName,
		[Parameter(Mandatory)]
		[System.Management.Automation.PSCredential]$DomainCreds,
		[Parameter(Mandatory)]
		[String]$OU,
		[Hashtable]$Disks = $null
	)
	
	Import-DSCResource -ModuleName xComputerManagement, xStorage, xActiveDirectory
    <#
    Disks Hashtable format @{"Diskletter"=DiskNumber}
    Diskletter is of type [string] and DiskNumber is of type [int]
    Disknumber '1' and Diskletter 'C' are always allotted to OS Disk therefore start disk number from 2 
    and assign Diskletter other than 'C'    
    #>
	
	xWaitForADDomain WaitForDomainDiscovery
	{
		DomainName = $DomainName
		DomainUserCredential = $DomainCreds
		RetryCount = $RetryCount
		RetryIntervalSec = $RetryIntervalSec
	}
	
	xComputer DomainJoin
	{
		Name = "localhost"
		DomainName = $DomainName
		Credential = $DomainCreds
		JoinOU = $OU
		DependsOn = "[xWaitForADDomain]WaitForDomainDiscovery"
	}
	if ($Disks)
	{
		foreach ($disk in $Disks.GetEnumerator())
		{
			xWaitforDisk "WaitForDisk$($disk.Key)"
			{
				DiskNumber =[Convert]::ToUInt32($disk.Value)
				RetryIntervalSec = 2
				RetryCount = 100
			}
			
			xDisk "DataDisk$($disk.Key)"
			{
				DiskNumber = [Convert]::ToUInt32($disk.Value)
				DriveLetter = $disk.Key
				DependsOn = "[xWaitforDisk]$($disk.Key)"
			}
		}
	}
}
