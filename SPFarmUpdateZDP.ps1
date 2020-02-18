Configuration SPFarmUpdateZDP
{
    $CredsSPFarm = Get-Credential -Message "Farm Account Service Account"
    Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
    Import-DscResource -ModuleName SharePointDSC 
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    #FarmWideConfig
    Node $AllNodes.Where{$_.CentralAdminServer -eq $true}.NodeName
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
            PsDscRunAsCredential = $CredsSPFarm

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
            PsDscRunAsCredential = $CredsSPFarm
            DependsOn = "[WaitForAll]SPConfigWizardServerGroup2"
        }
    }
    #ServerGroup1
    Node $AllNodes.Where{$_.ServerGroup -eq 1}.NodeName
    {
        SPProductUpdate ServerGroup1
        {
            SetupFile = "c:\sts2019-kb4484224-fullfile-x64-glb.exe"
            ShutdownServices = $true
            BinaryInstallDays = @("wed")
            BinaryInstallTime = "12:00am to 11:00pm"
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
            DatabaseUpgradeDays = @("wed")
            DatabaseUpgradeTime = "12:00am to 11:00pm"
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
            SetupFile = "c:\sts2019-kb4484224-fullfile-x64-glb.exe"
            ShutdownServices = $true
            BinaryInstallDays = @("wed")
            BinaryInstallTime = "12:00am to 11:00pm"
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
            DatabaseUpgradeDays = @("wed")
            DatabaseUpgradeTime = "12:00am to 11:00pm"
            PsDscRunAsCredential = $CredsSPFarm
            IsSingleInstance = "Yes"
            DependsOn = "[WaitForAll]SPConfigWizardServerGroup1"
        }
    }
}
Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
$CentralAdminServer = "SP"
$ConfigData = @{
    
    AllNodes = [array] ((Get-SPFarm).Servers | Where-Object Role -ne "Invalid" | ForEach-Object{
        @{
            NodeName = $_.Address;
            ServerGroup = Get-Random -Minimum 1 -Maximum 3;
            PSDscAllowPlainTextPassword = $true;
            PSDscAllowDomainUser = $true;
            CentralAdminServer = ($_.Address -eq $CentralAdminServer);
        }
    })
    
}
SPFarmUpdateZDP -ConfigurationData $ConfigData