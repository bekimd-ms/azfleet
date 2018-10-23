$Root = "C:\"
$Workspace = $Root + "IOStormplus\"

#Download and unzip controller package

$PackageName = "RemoteConsole.ps1"
$PackageUrl = "https://raw.githubusercontent.com/bekimd-ms/AzureStack/master/RemoteConsole.ps1"
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

Invoke-WebRequest -Uri $PackageUrl -OutFile ($Workspace + $PackageName)

# Install AzureRM 
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
Install-Module -Name AzureRm.BootStrapper -Force  
Use-AzureRmProfile -Profile 2018-03-01-hybrid -Force

#Install SSH client
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

#Enable PSRemoting
$DNSName = $env:COMPUTERNAME 
Enable-PSRemoting -Force   

New-NetFirewallRule -Name "WinRM HTTPS" -DisplayName "WinRM HTTPS" -Enabled True -Profile "Any" -Action "Allow" -Direction "Inbound" -LocalPort 5986 -Protocol "TCP"    

$thumbprint = (New-SelfSignedCertificate -DnsName $DNSName -CertStoreLocation Cert:\LocalMachine\My).Thumbprint   
$cmd = "winrm create winrm/config/Listener?Address=*+Transport=HTTPS @{Hostname=""$DNSName""; CertificateThumbprint=""$thumbprint""}" 

cmd.exe /C $cmd  

