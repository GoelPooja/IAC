Configuration ConfigureFileShare
{
param(
[Parameter(Mandatory)]
[string]$NodeName,
[Parameter(Mandatory)]
[string]$ShareName,
[ValidateSet("Present","Absent")]
[string]$Ensure = 'Present',
[Parameter(Mandatory)]
[string]$Path,
[UInt32]$ConcurrentUserLimit=0,
[Parameter(Mandatory)]
[string]$FullAccess,
[string]$ReadAccess

)
<#
 As azure automation dsc does not support array input, pass comma seperated string in $FullAccess and $ReadAccess to add multiple users
#>
    Import-DscResource -Name MSFT_xSmbShare   
    Node $NodeName
    {
 
  if([string]::IsNullOrWhiteSpace($ReadAccess))
  {
        xSmbShare SMBShare
        {
          Ensure = $Ensure 
          Name   = $ShareName
          Path = $Path 
          ConcurrentUserLimit =$ConcurrentUserLimit  
          FullAccess = $FullAccess.Split(',')           
        }
   }
   else
   {
    xSmbShare SMBShare
        {
          Ensure = $Ensure 
          Name   = $ShareName
          Path = $Path 
          ConcurrentUserLimit =$ConcurrentUserLimit  
          FullAccess = $FullAccess.Split(',')  
          ReadAccess = $ReadAccess.Split(',')          
        }
   }
        
    }
} 

