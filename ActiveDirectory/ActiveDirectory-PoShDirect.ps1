$VM = "TESTDC01"
Get-ChildItem "C:\DSC\DscResources\xComputerManagement" -Recurse -File | % { Copy-VMFile -Name $VM -SourcePath $_.FullName -DestinationPath $_.FullName -CreateFullPath -FileSource Host }
Get-ChildItem "C:\DSC\DscResources\xActiveDirectory" -Recurse -File | % { Copy-VMFile -Name $VM -SourcePath $_.FullName -DestinationPath $_.FullName -CreateFullPath -FileSource Host }

$cred = Get-Credential Administrator
Invoke-Command -VMName $VM -ScriptBlock {
Move-Item "C:\DSC\DscResources\xComputerManagement" 'C:\Program Files\WindowsPowerShell\Modules'
Move-Item "C:\DSC\DscResources\xActiveDirectory" 'C:\Program Files\WindowsPowerShell\Modules'
} -Credential $cred

Invoke-Command -VMName $VM -ScriptBlock {
    configuration SetLCM {
        Node localhost {
            LocalConfigurationManager
	        {
	            ConfigurationMode = 'ApplyAndAutoCorrect'
	            RefreshFrequencyMins = 30
                RebootNodeIfNeeded = $true
	        }
        }
    }
    SetLCM -OutputPath C:\DSC
    Set-DscLocalConfigurationManager -Path C:\DSC
} -Credential $cred

Invoke-Command -VMName $VM -ScriptBlock {
    $ConfigData = @{
        AllNodes = @(
                    @{
                        NodeName = "localhost"
                        PSDscAllowPlainTextPassword = $True
                        Name = "TESTDC01"
                        DomainName = "Azure.Lab"
                        }
                    )
    }
    configuration ActiveDirectory {
        Param( 
            [pscredential]$Credential,
            [pscredential]$ADRestore
        )
        Import-DscResource -Module xComputerManagement
        Import-DscResource -Module xActiveDirectory
        node $AllNodes.NodeName {
            LocalConfigurationManager
	        {
	            ConfigurationMode = 'ApplyAndAutoCorrect'
	            RefreshFrequencyMins = 30
                RebootNodeIfNeeded = $true
	        }

            WindowsFeature AntiMalware {
                Ensure = 'Absent'
                Name = "Windows-Server-Antimalware-Features"

            }            
            
            WindowsFeature ServerShell {
                Ensure = 'Present'
                Name = "Server-Gui-Shell"
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
                DomainAdministratorCredential = $Credential
                DomainName = $AllNodes.DomainName
                SafeModeAdministratorPassword = $ADRestore
                DependsOn = '[WindowsFeature]AD', '[xComputer]RenamePC'        
            }
        }
    }

    ActiveDirectory -ConfigurationData $ConfigData -Credential $using:cred  -ADRestore $using:cred 
    Start-DscConfiguration .\ActiveDirectory -Wait -Verbose -Force
} -Credential $cred