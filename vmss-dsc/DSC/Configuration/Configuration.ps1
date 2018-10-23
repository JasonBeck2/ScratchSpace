configuration DomainJoin 
{ 
   param 
    ( 
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String]$domainName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [PSCredential]$adminCreds,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String]$certUrl,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String]$certThumbprint,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [PSCredential]$certCreds
    ) 
    
    Import-DscResource -ModuleName xComputerManagement, CertificateDsc

    $domainCreds = New-Object System.Management.Automation.PSCredential("$domainName\$($adminCreds.UserName)", $adminCreds.Password)

    $certPassword = New-Object System.Management.Automation.PSCredential ("unnused", $certCreds.Password)

    $localCertPath = "C:\temp\cert.pfx"
   
    Node localhost
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }

        WindowsFeature ADPowershell
        {
            Ensure = "Present"
            Name = "RSAT-AD-PowerShell"
        } 

        xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $domainName
            Credential = $domainCreds
            DependsOn = "[WindowsFeature]ADPowershell" 
        }

        WindowsFeature IIS
        {
            Ensure = "Present"
            Name = "Web-Server"
            IncludeAllSubFeature = $true
            DependsOn = "[xComputer]DomainJoin"
        }

        Script DownloadCertificate
        {
            GetScript = { return @{ 'Result' = (dir "C:\") } }
            TestScript = { Test-Path $using:localCertPath }
            SetScript = {
                if(!(Test-Path "C:\temp")){
                    New-Item -ItemType Directory -Force -Path "C:\temp"
                }
                $client = New-Object System.Net.WebClient
                $client.DownloadFile($using:certUrl, $using:localCertPath)
            }
            DependsOn = "[WindowsFeature]IIS"
        }

        PfxImport ImportCertificate
        {
            Thumbprint = $certThumbprint
            Path = $localCertPath
            Location = 'LocalMachine'
            Store = 'My'
            Credential = $certPassword
            DependsOn = "[Script]DownloadCertificate"
        }
   }
}
