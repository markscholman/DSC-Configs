param (
$BaseVhdPath = 'V:\Hyper-V\_MASTER\WS2012R2DCu3_gpt.vhdx',
$VMName = "VM1",
$UnattendFile = "$ConfigDataLocation\VM_Unattend.xml"
)

$ConfigDataLocation = Split-Path $MyInvocation.MyCommand.Definition
$ConfigDataLocation = Split-Path $ConfigurationData
$ConfigData = @{

    Allnodes = @(
        @{
            NodeName = 'localhost';
            Role = 'Hyper-V Server';
            VMName = "$VMName";
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

        File DirectoryVM
        {
            Ensure = 'Present'
            Type = 'Directory'
            DestinationPath = "V:\Hyper-V\$($Node.VMName)"
        }

        xVMSwitch Internal
        {
            Ensure = 'Present'
            Name = 'Internal'
            Type = 'Internal'
        }

        xVHD NewVHD
        {
            Ensure = 'Present'
            Name = $Node.VMName
            Path = "V:\Hyper-V\$($Node.VMName)"
            Generation = "vhdx"
            ParentPath = $Node.baseVhdPath
        }

        xVhdFile CopyUnattendxml
        {
            VhdPath = "V:\Hyper-V\$($Node.VMName)\$($Node.VMName).vhdx"
            FileDirectory = $Node.FilesToCopy | % {
                MSFT_xFileDirectory
                {
                    SourcePath = $_.Source
                    DestinationPath = $_.Destination

                }
            }
            DependsOn = "[xVHD]NewVHD"
        }

        xVMHyperV VM
        {
            Name = "$($Node.VMName)"
            Path = "V:\Hyper-V\"
            SwitchName = "Internal"
            VhdPath = "V:\Hyper-V\$($Node.VMName)\$($Node.VMName).vhdx"
            MaximumMemory = 4GB
            MinimumMemory = 2GB
            RestartIfNeeded = $true
            State = 'Running'
            Generation = 'vhdx'
            DependsOn = "[xVhdFile]CopyUnattendxml"
        }
    }

}

HyperV -ConfigurationData $ConfigData
Start-DscConfiguration .\HyperV -Wait -Verbose -Force