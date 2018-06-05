Configuration WebServer
{
    Import-DSCResource -ModuleName ClefDscResources
   
    Node localhost
    {
        cWebServer WebServer
        {	        
            Name = "Web-*" 
            FeatureName = "" 
            Ensure = "Present"
            IncludeAllSubFeature = $true	                            
        }
    }
}

WebServer