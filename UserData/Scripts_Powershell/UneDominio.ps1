
# Script de unión a dominio. 

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force

$DNS_DOMINIO=$args[0];
$NOMBRE_SERVIDOR=$args[1];

# #Eliminamos el registro de la tarea programada
# $exists = Get-ScheduledTask | Where-Object {$_.TaskName -like 'UneDominio'}
# if($exists){
#    Unregister-ScheduledTask -TaskName 'UneDominio' -Confirm:$false
# }

#Eliminamos al usuario usado para la tarea programada 
# Remove-LocalUser -Name "admin_programada"


# Esperamamos a que el servidor esté listo
$ping=$false;
While(!$ping){
    echo "Probando conectividad $NOMBRE_SERVIDOR.$DNS_DOMINIO..."
    $ping=Test-Connection "$NOMBRE_SERVIDOR.$DNS_DOMINIO" -Quiet
    Start-Sleep -Seconds 5
    if($ping){
        echo "Hay conectividad"
    }
}

$username="admin_programada"
$password = ConvertTo-SecureString "Naranco.22" -AsPlainText -Force
$Credenciales = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $password

Add-Computer -DomainName $DNS_DOMINIO -cred $Credenciales -Restart

