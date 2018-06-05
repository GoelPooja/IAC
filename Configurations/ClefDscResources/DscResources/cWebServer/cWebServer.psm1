function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,
                
        [String]
        $FeatureName,

        [ValidateSet("Present", "Absent")]
		[System.String]$Ensure,

        [Boolean]
        $IncludeAllSubFeature = $true                      
   )    

    $State = @{
        Name = $Name
        includeAllSubFeature = $true
        Ensure = 'Absent'
        featureName = $null
    }
    
    $feature = Get-WindowsFeature $State.Name   
    $State.featureName = $feature    
    Assert-SingleFeatureExists -Feature $feature -Name $State.Name       
    
    if ($feature.SubFeatures.Count -eq 0)
    {
        $State.includeAllSubFeature = $false
    }
    else
    {
        foreach ($currentSubFeatureName in $feature.SubFeatures)
        {

            $getWindowsFeatureParameters = @{
                Name = $currentSubFeatureName
            }                      
            $subFeature = Get-WindowsFeature @getWindowsFeatureParameters                
            Assert-SingleFeatureExists -Feature $subFeature -Name $currentSubFeatureName    
            if (-not $subFeature.Installed)
            {
                $State.includeAllSubFeature = $false
                break
            }
        }
    }

    if ($feature.Installed)
    {
        $State.Ensure = 'Present'
    }
    else
    {
        $State.Ensure = 'Absent'
    }    
    
    # Add all feature properties to the hash table
    return $State
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
       [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,
                
        [String]
        $FeatureName,

        [ValidateSet("Present", "Absent")]
		[System.String]$Ensure,

        [Boolean]
        $IncludeAllSubFeature = $false       
    )       

    if ($Ensure -eq 'Present')
    {        
        #Install all web features
        $feature = Get-WindowsFeature –Name $Name | Install-WindowsFeature

        #Install chocolatey if absent
        $env:chocolateyVersion = '0.9.10.3'
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

        #Install webdeploy
        choco install webdeploy -Y  
        if ($null -ne $feature -and $feature.Success)
        {            
            # Reboot the VM if required
            if ($feature.RestartNeeded -eq 'Yes')
            {
                Restart-Computer -Force
            }
        }
        else
        {
            New-InvalidOperationException -Message ($script:localizedData.FeatureInstallationFailureError -f $Name)
        }                           
    }
    # Ensure = 'Absent'
    else
    {
        #Uninstall all web features
        $feature = Get-WindowsFeature –Name $Name | Uninstall-WindowsFeature       

        if ($null -ne $feature -and $feature.Success)
        {            
            # Reboot the VM if required
            #if ($feature.RestartNeeded -eq 'Yes')
            #{
                Restart-Computer
            #}
        }
        else
        {
            New-InvalidOperationException -Message ($script:localizedData.FeatureUninstallationFailureError -f $Name)
        }
    }    
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,
                
        [String]
        $FeatureName,

        [ValidateSet("Present", "Absent")]
		[System.String]$Ensure,

        [Boolean]
        $IncludeAllSubFeature = $false
    )

    $testTargetResourceResult = $false

    $currentValues = Get-TargetResource @PSBoundParameters
        
    # Check if the feature is in the requested Ensure state.
    if (($Ensure -eq 'Present' -and $currentValues.FeatureName.Installed -eq $true) -or `
        ($Ensure -eq 'Absent' -and $currentValues.FeatureName.Installed -eq $false))
    {
        $testTargetResourceResult = $true
    
        if ($currentValues.IncludeAllSubFeature)
        {                   
            # Check if each subfeature is in the requested state.
            foreach ($currentSubFeatureName in $currentValues.FeatureName.SubFeatures)
            {                
                 $getWindowsFeatureParameters = @{
                    Name = $currentSubFeatureName
                 }    
                $subFeature = Get-WindowsFeature @getWindowsFeatureParameters                              
                Assert-SingleFeatureExists -Feature $subFeature -Name $currentSubFeatureName
                if (-not $subFeature.Installed -and $Ensure -eq 'Present')
                {
                    $testTargetResourceResult = $false
                    break
                }
    
                if ($subFeature.Installed -and $Ensure -eq 'Absent')
                {
                    $testTargetResourceResult = $false
                    break
                }
            }
        }
    }
    else
    {
        # Ensure is not in the correct state
        $testTargetResourceResult = $false
    }          
    return $testTargetResourceResult
}

function Assert-SingleFeatureExists
{
    [CmdletBinding()]
    param
    (
        [PSObject]
        $Feature,

        [String]
        $Name
    )
    if ($null -eq $Feature)
    {
        Write-Output "Feature not Found"
    }

    if ($Feature.Count -gt 1)
    {
        Write-Output "MultipleFeatureInstancesError"
    }
} 

Export-ModuleMember -Function *-TargetResource