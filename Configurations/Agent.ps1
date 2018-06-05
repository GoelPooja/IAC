Configuration Agent
{
    Import-DSCResource -ModuleName ClefDscResources
   
    Node localhost
    {
        cVSTSAgent VstsAgent
        {
	        Name = "TrainingAgent"
	        MachineGroup = "ConversionTest"
	        Tags = "tag10"
	        Ensure = "Present"
            ProjectName = "Clef"
            VstsUrl = "https://apra-amcos.visualstudio.com"
	        InstallFolder = "C:\agent"
	        PoolName = "AX"
            token = "yjsyrr32lg5b6fwnloks6awwnquoqha7is75yjes47ceevd2x7yq"
	        Overwrite = $False
            workFolder = "C:\_work"
            Username = "apra\svcvstsagent01"
            Password = "SITP@ssw0rd"                    
        }
    }
}

Agent

