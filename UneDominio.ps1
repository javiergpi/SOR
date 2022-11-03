
# Script de unión a dominio. 
# Debería incluir las variables:
#   - DNS_DOMINIO

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force

$Credenciales = $Host.UI.PromptForCredential("Credenciales", "Escribe credenciales para unirte al dominio", "", $DNS_DOMINIO)
Add-Computer -DomainName $DNS_DOMINIO -cred $Credenciales
Restart-Computer 