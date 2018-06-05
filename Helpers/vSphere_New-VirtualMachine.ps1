Function New-VirtualMachine
{
	[cmdletbinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string]$Name,
		[string]$AdminPassword,
		[string]$EnvironmentName,
		[string]$vCenterUsername,
		[string]$vCenterPassword,
		[string]$vCenterServer = "sydprodvc01.apra.com.au",
		[string]$TemplateName = "APRA_Win2012_PRES",
		[string]$DataCenter = "Ultimo",
		[string]$ClusterName = "CLEF_TEST_CLUSTER",
		[string]$NumCpu = 1,
		[string]$MemoryGB = 4,
		[string]$NetworkName = "Presentation",
		[string]$IPAddress,
		[string]$SubnetMask,
		[string]$DefaultGateway,
		[string[]]$DNSServers,
		[int[]]$AdditionalDisks,
		[bool]$PowerOnVM = $True,
		[string]$RegUrl,
		[string]$RegKey,
		[string]$NodeName,
		[string[]]$RunOnceCommand,
		[bool]$IsSQL = $False
	)
	
	if ($RunOnceCommand -eq $null)
	{
		$RunOnceCommand =
		@(
			"powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command `"Configure-LCM -RegistrationUri '$RegUrl'`"",
			"powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command `"Configure-LCM -RegistrationKey '$RegKey'`"",
			"powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command `"Configure-LCM -ConfigurationName '$NodeName'`"",
			"powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command `"Configure-LCM`""
		)
		
	}
	
	Import-Module -Name VMware.VimAutomation.Core -ErrorAction Stop
	
	Connect-VIServer -Server $vCenterServer `
					 -User $vCenterUsername `
					 -Password $vCenterPassword `
					 -Verbose
	
	#Get all hosts in the cluster and select the one with most available memory left
	$Cluster = Get-Cluster -Name $ClusterName
	$vmHosts = Get-VMHost -Location $Cluster -State Connected
	$vmHost = $vmHosts | Sort-Object MemoryUsageGB | Select-Object -First 1
	
	$SystemDataStore = Get-Datastore -Name "3PAR_CLEF_ESX_SSD_LUN01"
	$SqlLogsDataStore = Get-Datastore -Name "3PAR_CLEF_ESX_SSD_LUN02"
	$SqlDataDataStore = Get-Datastore -Name "3PAR_CLEF_ESX_SSD_LUN03"
	
	$osSpec = New-OSCustomizationSpec -Name $Name `
									  -OrgName "APRA AMCOS" `
									  -Workgroup WORKGROUP `
									  -GuiRunOnce $RunOnceCommand `
									  -FullName "Administrator" `
									  -AdminPassword $AdminPassword `
									  -TimeZone "255" `
									  -NamingScheme Fixed `
									  -NamingPrefix $Name `
									  -ChangeSid:$true `
									  -AutoLogonCount 1 `
									  -Type NonPersistent
	
	$osSpec = Get-OSCustomizationSpec -Name $Name
	Get-OSCustomizationNicMapping -OSCustomizationSpec $osSpec |
	Set-OSCustomizationNicMapping -IpMode UseStaticIP `
								  -IpAddress $IPAddress `
								  -SubnetMask $SubnetMask `
								  -DefaultGateway $DefaultGateway `
								  -Dns $DNSServers
	
	#Get/Create environment folder if doesnt exist
	$Folder = Get-Folder -Name $EnvironmentName
	if ($Folder -eq $null) { $Folder = New-Folder -Name $EnvironmentName }
	
	#Get Template to use based on Name
	$template = Get-Template -Name $TemplateName
	
	#Create the VM
	$newVMTask = New-VM -Name $Name `
						-Template $template `
						-OSCustomizationSpec $osSpec `
						-VMHost $vmHost `
						-Datastore $SystemDataStore `
						-Location $Folder `
						-RunAsync:$true `
						-DiskStorageFormat "Thin"
	
	# Wait for task to complete
	while ($newVMTask.State.ToString().ToLower() -eq 'running')
	{
		Start-Sleep -Seconds 5
		$newVMTask = Get-Task -Id $newVMTask.Id -Verbose:$false -Debug:$false
	}
	$newVMTask = Get-Task -Id $newVMTask.Id -Verbose:$false -Debug:$false
	
	if ($newVMTask.State.ToString().ToLower() -eq 'success')
	{
		#$vm = Get-VM -Id $t.Result.Vm -Verbose:$false -Debug:$false
		$vm = Get-VM -Name $Name -Verbose:$false -Debug:$false
	}
	
	if ($null -eq $vm)
	{
		throw 'VM failed to create'
	}
	
	
	#Update the VM Ram and CPU cores
	$setVMTask = Set-VM -VM $vm `
						-MemoryGB $MemoryGB `
						-NumCpu $NumCpu `
						-Confirm:$false -RunAsync:$true
	
	while ($setVMTask.State.ToString().ToLower() -eq 'running')
	{
		Start-Sleep -Seconds 1
	}
	if ($setVMTask.State.ToString().ToLower() -eq 'success')
	{
		$vm = Get-VM -Name $Name -Verbose:$false -Debug:$false
	}
	
	if ($PowerOnVM)
	{
		$startVMTask = $vm | Start-VM -RunAsync:$true -Confirm:$false
		while ($startVMTask.State.ToString().ToLower() -eq 'running')
		{
			Start-Sleep -Seconds 1
		}
		if ($startVMTask.State.ToString().ToLower() -eq 'success')
		{
			
			
			$vm = Get-VM -Name $Name -Verbose:$false -Debug:$false
		}
	}
	
	#Add additional disks
	if ($name.ToUpper().Contains("DB"))
	{
		$IsSQL = $true
	}
	$SQLLogDiskSet = $False
	foreach ($disk in $AdditionalDisks)
	{
		if ($disk -eq 0)
		{
			continue;
		}
		
		$hdd = $vm | New-HardDisk -CapacityGB $disk `
								  -DiskType Flat `
								  -Persistence Persistent `
								  -StorageFormat Thin `
								  -Datastore $SystemDataStore `
								  -Confirm:$false
		
		if ($IsSQL)
		{
			if (!$SQLLogDiskSet)
			{
				$hddtask = $hdd | Set-HardDisk -Datastore $SqlLogsDataStore -Confirm:$false -ToolsWaitSecs 1
				$SQLLogDiskSet = $true
			}
			else
			{
				$hddtask = $hdd | Set-HardDisk -Datastore $SqlDataDataStore -Confirm:$false -ToolsWaitSecs 1
			}
		}
	}
	
	#Get and update the VM Network Adaptor settings
	$networkadaptor = Get-NetworkAdapter -VM $vm
	$setNetworkAdaptorTask = Set-NetworkAdapter -NetworkAdapter $networkadaptor -NetworkName $NetworkName -Type Vmxnet3 -StartConnected $true -Connected $true -Confirm:$false -RunAsync:$true
	
	Remove-OSCustomizationSpec -OSCustomizationSpec $osSpec -Confirm:$false
	
	Disconnect-VIServer -Server $vCenterServer -Confirm:$false -Force:$true
	
}