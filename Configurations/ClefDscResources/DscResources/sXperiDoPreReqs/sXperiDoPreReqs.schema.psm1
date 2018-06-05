Configuration sXperiDoPreReqs
{
	
	Import-DSCResource -ModuleName xSQLServer

  <#  File JavaMsi
    {
        # download the MSI package and unpack the exe and extract the two java MSIs

        #\\SYDPRODIPAM01\CLEF_IaC\Software
    }#>

    Package JDK
    {
        Ensure = "Present"
        Name = "Java 8 Update 121 (64-bit)"
        Path = "$Env:SystemDrive\Program Files\Java\jdk1.8.0_121"
        ProductId = "64A3A4F4-B792-11D6-A78A-00B0D0180121"
        DependsOn = @("[File]JavaMsi")
        Arguments = "/s STATIC=1 WEB_JAVA=0"
    }

    WindowsFeature IIS
    {
        Ensure = "Present"
        Name = {"Web-Server", "Web-Net-Ext45", "Web-AppInit", "Web-ASP", "Web-Asp-Net45", "Web-ISAPI-Ext", "Web-ISAPI-Filter", "Web-Scripting-Tools"}
    }

 <#   File URLRewrite
    {
        # download the MSI package and unpack the exe and extract the two java MSIs

        #\\SYDPRODIPAM01\CLEF_IaC\Software
    }#>

 <#  File WebFarmFramework
    {
        # download the MSI package and unpack the exe and extract the two java MSIs

        #\\SYDPRODIPAM01\CLEF_IaC\Software
    }

    File ApplicationRequestRouting
    {
        # download the MSI package and unpack the exe and extract the two java MSIs

        #\\SYDPRODIPAM01\CLEF_IaC\Software

        #1 - Enable Proxy
        #2 - Disable IIS Static Content Compression
    }

    Package Net462
    {
        #install .NET 4.6.2
    }

    Package PostgreSQL
    {
        #install postgre
    }#>
}
