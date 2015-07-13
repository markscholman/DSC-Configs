param(
$cred = (Get-Credential)
)
# Create working directory
if (-not $(Test-Path c:\DSC)) {mkdir c:\DSC}

# Check if valid certificate is already present    
$Certificate = Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Subject -eq "CN=Self Signed Cert" -AND $_.PrivateKey.KeyExchangeAlgorithm} | Select-Object -first 1

# If no certificate is available, create one
if (-not $Certificate) {
@'
[NewRequest]
Subject = "CN=Self Signed Cert"
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
RequestType = Cert
'@ | out-file 'c:\DSC\cert.inf'

certreq.exe -new -machine 'c:\DSC\cert.inf' 'c:\DSC\cert.cer'
}

# Export certificate file
if (-not $(test-path 'c:\DSC\cert.cer')) {
    $CertificateFile = Export-Certificate -Type CERT -FilePath 'c:\DSC\cert.cer' -Cert $Certificate
    }
else {$CertificateFile = 'c:\DSC\cert.cer'}

# Import certificate file to trusted root authorities so it is trusted on the local machine
if (-not $(Get-ChildItem 'Cert:\LocalMachine\Root' | Where-Object {$_.Thumbprint -eq $Certificate.Thumbprint})) {
    $Import = Import-Certificate -FilePath $CertificateFile -CertStoreLocation 'Cert:\LocalMachine\Root'
    }

$ConfigData = @{
	AllNodes = @(
	    @{
		    NodeName = "localhost"
		    Name = "TESTAPP01"
            Thumbprint = $Certificate.Thumbprint
            CertificateFile = "C:\DSC\cert.cer"
		    DomainName = "Azure.Lab"
            Credential = $cred
	    }
	)
}
configuration MemberServer {
	Import-DscResource -Module xComputerManagement
	node $AllNodes.NodeName {
		LocalConfigurationManager
		{
            CertificateID = $AllNodes.Thumbprint
			ConfigurationMode = 'ApplyAndAutoCorrect'
			RefreshFrequencyMins = 30
			RebootNodeIfNeeded = $true
		}
			
		xComputer RenamePC {
			Name = $AllNodes.Name
            DomainName = $AllNodes.DomainName
            Credential = $AllNodes.Credential
		}
	}
}
	
MemberServer -ConfigurationData $ConfigData
Set-DscLocalConfigurationManager -Path .\MemberServer -Verbose
Start-DscConfiguration .\MemberServer -Wait -Verbose
