
# Script de promoción a PDC. 
# Debería incluir las variables:
#   - DNS_DOMINIO
#   - NETBIOS_DOMINIO

Import-Module ADDSDeployment
Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "C:\Windows\NTDS" `
-DomainMode "WinThreshold" `
-DomainName $DNS_DOMINIO `
-DomainNetbiosName $NETBIOS_DOMINIO `
-SafeModeAdministratorPassword (ConvertTo-SecureString -AsPlainText "Naranco.22" -Force) `
-ForestMode "WinThreshold" `
-InstallDns:$true `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\Windows\SYSVOL" `
-Force:$true