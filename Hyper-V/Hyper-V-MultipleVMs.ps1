param (
$BaseVhdPath = "C:\Hyper-V\WS2012R2DCu1507_gpt.vhdx",
$VMName = ("VM1","VM2"),
$UnattendFile = "$ConfigDataLocation\$VMName" + "_Unattend.xml"
)

$ConfigDataLocation = Split-Path $MyInvocation.MyCommand.Definition
$ConfigDataLocation = Split-Path $ConfigurationData
$ConfigData = @{

    Allnodes = @(
        @{
            NodeName = 'localhost';
            Role = 'Hyper-V Server';
            VMName = $VMName;
            BaseVhdPath = "$BaseVhdPath";
            FilesToCopy = @(
                @{ Source = "$UnattendFile"; Destination = 'unattend.xml'}
            )
        }
    )
}

configuration HyperV {
    Import-DscResource -Module xHyper-V
    node $AllNodes.where{$_.Role -eq "Hyper-V Server"}.NodeName 
    {
        WindowsFeature HyperV
        {
            Ensure = 'Present'
            Name = 'Hyper-V'
        }

        WindowsFeature RSATHyperV
        {
            Ensure = 'Present'
            Name = 'RSAT-Hyper-V-Tools'
            IncludeAllSubFeature = $true
        }

        xVMSwitch Internal
        {
            Ensure = 'Present'
            Name = 'Private'
            Type = 'Private'
        }

        foreach ($VM in $Node.VMname) {
            File "DirectoryVM_$VM"
            {
                Ensure = 'Present'
                Type = 'Directory'
                DestinationPath = "V:\Hyper-V\$VM"
            }

            xVHD "NewVHD_$VM"
            {
                Ensure = 'Present'
                Name = $VM
                Path = "V:\Hyper-V\$VM"
                Generation = "vhdx"
                ParentPath = $Node.baseVhdPath
            }

            xVhdFile "CopyUnattendxml_$VM"
            {
                VhdPath = "V:\Hyper-V\$VM\$VM.vhdx"
                FileDirectory = $Node.FilesToCopy | % {
                    MSFT_xFileDirectory
                    {
                        SourcePath = $_.Source
                        DestinationPath = $_.Destination

                    }
                }
                DependsOn = "[xVHD]NewVHD_$VM"
            }

            xVMHyperV "VM_$VM"
            {
                Name = "$VM"
                Path = "V:\Hyper-V\"
                SwitchName = "Private"
                VhdPath = "V:\Hyper-V\$VM\$VM.vhdx"
                MaximumMemory = 4GB
                MinimumMemory = 2GB
                RestartIfNeeded = $true
                State = 'Running'
                Generation = 'vhdx'
                DependsOn = "[xVhdFile]CopyUnattendxml_$VM"
            }
        }
    }

}

HyperV -ConfigurationData $ConfigData
Start-DscConfiguration .\HyperV -Wait -Verbose -Force