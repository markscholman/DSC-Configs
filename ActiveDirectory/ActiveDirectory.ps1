param(
$cred = (Get-Credential)
)

$ConfigData = @{
	AllNodes = @(
	    @{
		    NodeName = "localhost"
		    Name = "TESTDC01"
            PSDscAllowPlainTextPassword = $true
		    DomainName = "Azure.Lab"
            Credential = $cred
	    }
	)
}
configuration ActiveDirectory {
	Import-DscResource -Module xComputerManagement,xActiveDirectory
	node $AllNodes.NodeName {
		LocalConfigurationManager
		{
            CertificateID = $AllNodes.Thumbprint
			ConfigurationMode = 'ApplyAndAutoCorrect'
			RefreshFrequencyMins = 30
			RebootNodeIfNeeded = $true
		}
		
		WindowsFeature AD {
			Ensure = 'Present'
			Name   = 'AD-Domain-Services'
		}
			
		WindowsFeature ADTools {
			Ensure = 'Present'
			Name   = 'RSAT-AD-Tools'
			IncludeAllSubFeature = $true
		}
			
		xComputer RenamePC {
			Name = $AllNodes.Name
			DependsOn = '[WindowsFeature]ADTools'
		}
			
		xADDomain Domain {
			DomainAdministratorCredential = $AllNodes.Credential
			DomainName = $AllNodes.DomainName
			SafeModeAdministratorPassword = $AllNodes.Credential
			DependsOn = '[WindowsFeature]AD', '[xComputer]RenamePC'
		}
	}
}
	
ActiveDirectory -ConfigurationData $ConfigData
Set-DscLocalConfigurationManager -Path .\ActiveDirectory -Verbose
Start-DscConfiguration .\ActiveDirectory -Wait -Verbose
