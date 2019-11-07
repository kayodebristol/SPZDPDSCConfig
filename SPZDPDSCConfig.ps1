Configuration SPFarmUpdateZDP
{
    $CredsSPFarm = Get-Credential -Message "Farm Account Service Account"
    Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
    Import-DscResource -ModuleName SharePointDSC -ModuleVersion 3.6.0.0
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    #FarmWideConfig
    Node LocalHost
    {
        Script EnableSideBySideFarmWide
        {
            SetScript = 
            {
                Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
                $WebApps = Get-SPWebApplication
                Write-Verbose "Setting SideBySide Property = $true on all SPWebApplications"   
                foreach($webApp in $webapps){
                    $Webapp.WebService.EnableSideBySide = $true
                    $WebApp.Update()
                }
            }
            TestScript = 
            {
                Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
                $WebApps = Get-SPWebApplication
                foreach($webApp in $webapps){
                    if($Webapp.WebService.EnableSideBySide -eq $false){
                        return $false
                    }
                }
                return $true
            }
            GetScript = 
            {
                Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
                $WebApps = Get-SPWebApplication
                foreach($webApp in $webapps){
                    if($Webapp.WebService.EnableSideBySide -eq $false){
                        return $false
                    }
                }
                return @{Result = $true}
            }
        }
        WaitForAll SPConfigWizardServerGroup2
        {
            ResourceName = "[SPConfigWizard]ServerGroup2"
            NodeName = $AllNodes.Where{$_.ServerGroup -eq 2}.NodeName
            RetryIntervalSec = 300
            RetryCount = 720
            DependsOn = "[Script]EnableSideBySideFarmWide"
        }
        Script SetSideBySideTokenFarmWide
        {
            SetScript = 
            {
                Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
                $path = [Microsoft.SharePoint.Utilities.SPUtility]::GetGenericSetupPath("TEMPLATE\Layouts")
                Folders = Get-ChildItem $path -Directory | Where-Object name -match '\d+.\d+.\d+.\d+'
                $latest = ''
                switch($folders.count){
                    0: {break;}
                    1: {$latest = $folders.name}
                    2: {
                        if( ($folders[0].name).replace('.','') -gt ($folders[1].name).replace('.','') ){
                            $latest = $folders[0].name
                        }
                        else{$latest = $folders[1].name}
                    }
                }
                $WebApps = Get-SPWebApplication
                Write-Verbose "Setting SideBySideToken Property to $Latest on all SPWebApplications"            
                foreach($webApp in $webapps){
                    if($WebaApp.WebService.EnableSideBySide -eq $true){
                        $Webapp.WebService.SideBySideToken = $latest
                        $WebApp.Update()
                    }
                }
            }
            TestScript = 
            {
                Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
                $path = [Microsoft.SharePoint.Utilities.SPUtility]::GetGenericSetupPath("TEMPLATE\Layouts")
                Folders = Get-ChildItem $path -Directory | Where-Object name -match '\d+.\d+.\d+.\d+'
                $latest = ''
                switch($folders.count){
                    0: {break;}
                    1: {$latest = $folders.name}
                    2: {
                        if( ($folders[0].name).replace('.','') -gt ($folders[1].name).replace('.','') ){
                            $latest = $folders[0].name
                        }
                        else{$latest = $folders[1].name}
                    }
                }
                $WebApps = Get-SPWebApplication
                foreach($webApp in $webapps){
                    if($Webapp.WebService.SideBySideToken -ne $latest -and $WebApp.WebService.EnableSideBySide){
                        return $false
                    }
                }
                return $true
            }
            GetScript = 
            {
                Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
                $WebApps = Get-SPWebApplication
                return @{Result = $WebApps | ForEach-Object{
                    @{DisplayName = $_.DisplayName; Url = $_.Url; SideBySideToken = $_.WebService.SideBySiteToken}
                    }
                }
            }
            DependsOn = "[WaitForAll]SPConfigWizardServerGroup2"
        }
    }
    #ServerGroup1
    Node $AllNodes.Where{$_.ServerGroup -eq 1}.NodeName
    {
        SPProductUpdate ServerGroup1
        {
            SetupFile = "C:\Patch\CU.exe"
            ShutdownServices = $true
            BinaryInstallDays = @("sat", "sun")
            BinaryInstallTime = "12:00am to 4:00am"
            PsDscRunAsCredential = $CredsSPFarm
        }
        WaitForAll SPProuductUpdateServerGroup2
        {
            ResourceName = "[SPProductUpdate]ServerGroup2"
            NodeName = $AllNodes.Where{$_.ServerGroup -eq 2}.NodeName
            RetryIntervalSec = 300
            RetryCount = 720
            DependsOn = "[SPProductUpdate]ServerGroup1"
        }
        SPConfigWizard ServerGroup1
        {
            Ensure = "Present"
            DatabaseUpgradeDays = @("sat", "sun")
            DatabaseUpgradeTime = "12:00am to 4:00am"
            PsDscRunAsCredential = $CredsSPFarm
            IsSingleInstance = "Yes"
            DependsOn = "[WaitForAll]SPProuductUpdateServerGroup2"
        }
    }
    #ServerGroup 2
    Node $AllNodes.Where{$_.ServerGroup -eq 2}.NodeName
    {
        WaitForAll SPProductUpdateServerGroup1
        {
            ResourceName = "[SPProductUpdate]ServerGroup1"
            NodeName = $AllNodes.Where{$_.ServerGroup -eq 1}.NodeName
            RetryIntervalSec = 300
            RetryCount = 720
        }
        SPProductUpdate ServerGroup2
        {
            SetupFile = "C:\Patch\CU.exe"
            ShutdownServices = $true
            BinaryInstallDays = @("sat", "sun")
            BinaryInstallTime = "12:00am to 4:00am"
            PsDscRunAsCredential = $CredsSPFarm
            DependsOn = "[WaitForAll]SPProductUpdateServerGroup1"
        }
        WaitForAll SPConfigWizardServerGroup1
        {
            ResourceName = "[SPConfigWizard]ServerGroup1"
            NodeName = $AllNodes.Where{$_.ServerGroup -eq 1}.NodeName
            RetryIntervalSec = 300
            RetryCount = 720
            DependsOn = "[SPProductUpdate]ServerGroup2"
        }
        SPConfigWizard ServerGroup2
        {
            Ensure = "Present"
            DatabaseUpgradeDays = @("sat", "sun")
            DatabaseUpgradeTime = "12:00am to 4:00am"
            PsDscRunAsCredential = $CredsSPFarm
            IsSingleInstance = "Yes"
            DependsOn = "[WaitForAll]SPConfigWizardServerGroup1"
        }
    }
}
$ConfigData = @{
    AllNodes = [array] ((Get-SPFarm).Servers | Where-Object Role -ne "Invalid" | ForEach-Object{
        @{
            NodeName = $_.Address;
            ServerGroup = $_.Address -replace '\D', '';
            PSDscAllowPlainTextPassword = $true;
            PSDscAllowDomainUser = $true;
        }
    })
}
SPFarmUpdateZDT -ConfigurationData $ConfigData