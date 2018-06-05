Configuration sSqlFormatDisk
{
    param(
        [Parameter(Mandatory=$True)]
        [int] $DiskNumber,
        
        [Parameter(Mandatory=$True)]
        [char] $DriveLetter,
        
        [Parameter(Mandatory=$True)]
        [string] $Label,
        
        [Parameter(Mandatory=$True)]
        [string[]] $FoldersToCreate,
        
        [Parameter(Mandatory=$True)]
        [string] $AccessPath
    )
	
	Import-DSCResource -ModuleName xStorage

    xWaitForDisk WaitForDisk
    {
        DiskNumber          = $DiskNumber
        RetryIntervalSec    = 5
        RetryCount          = 60
    }
    
    xDisk VolumeFormat
    {
        DiskNumber          = $DiskNumber
        DriveLetter         = $DriveLetter
        FSLabel             = $Label
        FSFormat            = 'NTFS'
        AllocationUnitSize  = 64KB
        DependsOn           = "[xWaitForDisk]WaitForDisk"
    }
    
    foreach($folderToCreate in $FoldersToCreate)
    {
        File $folderToCreate
        {
            Ensure          = "Present"
            Type            = "Directory"
            DestinationPath = "$DriveLetter`:\$folderToCreate"
            DependsOn       = "[xDisk]VolumeFormat"
        }
    }
    
    xDiskAccessPath AccessPath
    {
        DiskNumber          = $DiskNumber
        AccessPath          = $AccessPath
        DependsOn           = "[xDisk]VolumeFormat"
    }
}