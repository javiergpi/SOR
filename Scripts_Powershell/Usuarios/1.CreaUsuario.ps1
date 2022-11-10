

<# VARIABLES: A RELLENAR POR EL ALUMNO #>

 $dominio="dominioN" <# Sin .local #>
 $UOPrincipal="UO_MOCOSOFT" <# Cambiar por tu empresa #>


<# CreaUSuario.ps1
    Uso: CreaUsuario nombre OU turno
         Crea un usuario en el dominio informaticanaranco.local, en la UO especificada y en un grupo con la misma UO
         turno=[m|t|d]
             m --> Mañana
             t --> Tarde
             d --> Día (sin restricciones horarias)
    PRERREQUISITOS
         Debe existir una UO raíz llamada como la UOPrincipal
         Deben existir las plantillas de usuario _mañana y _tarde con las horas de acceso definidas
    Secuencia de acciones:
         1. Crea una UO como el primer argumento que le paso (en mayus).  Si ya existe no se crea
         2. Crea un grupo como el primer argumento que le paso (en minus). Si ya existe no se crea
         3. Crea un usuario con el login del primer argumento que le paso. Si ya existe no lo crea.
             Nombre de usuario = login
             Password = login (debe cambiarse en el primer inicio de sesión)
        4. Añade al usuario al grupo
        5. Establece las restricciones horarias correspondientes a partir de la plantilla (mañana o tarde)
 #>
 


  
 # Muestra un error si no le paso los argumentos login, UO, turno)

 if($args.Length -ne 3){
     "Uso: CreaUsuario login UO turno [m|t|d]"
     Exit
 }

 
 $loginUsuario=$args.getValue(0);
 $OU=$args.getValue(1).toString().toUpper();
 $turno=$args.getValue(2).ToString().ToLower();
 
 $rutaUO="OU=$OU,OU=$UOPrincipal,DC=$dominio,DC=local"

 
 # 1. Comprobar que existe la UO y crearla en caso negativo

 Try{
     $UO=Get-ADOrganizationalUnit -Identity $rutaUO
     "- YA EXISTE la UO $rutaUO [NO SE CREA]"
    } 
  Catch{
     "1. Creando UO $OU..."
     New-ADOrganizationalUnit -Name $OU -Path "OU=$UOPrincipal,DC=$dominio,DC=local"
 }
  
  # 2. Comprobar que existe el grupo y crearlo en caso negativo
  $grupo=$OU.ToString().ToLower();
  Try{
    $group=Get-ADGroup -Identity $grupo
    "- YA EXISTE el grupo $grupo [NO SE CREA]"
  }
  Catch{
    "2. Creando grupo $grupo..."
    New-ADGroup -Name $grupo -SamAccountName $grupo -GroupCategory Security -GroupScope Global -Path $rutaUO

  }

  
  #3. Comprobar que el usuario existe y crearlo si no existe

  $password=$loginUsuario
  $nombre=$loginUsuario
  $UPN=$loginUsuario+"@"+$domino+".local"

  Try{
       $usuario=Get-ADUser $loginUsuario -ErrorAction Stop
       "- YA EXISTE el usuario $loginUsuario [NO SE CREA]"
  }
  Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]{
        "3. Creando usuario $loginUsuario..."
        $usuario=New-ADUSer -Name $nombre -SamAccountName $loginUsuario -UserPrincipalName $UPN -GivenName $loginUsuario -DisplayName $loginUsuario `
                   -AccountPassword (ConvertTo-SecureString "Naranco.22" -AsPlainText -force) `
                   -Enabled $True -ChangePasswordAtLogon $True -Path $rutaUO

  }

 # 4. Se añade el usuario al grupo
 Try{
   $g=Get-ADGroup -Identity $grupo
   Add-ADGroupMember $g $loginUsuario
   "4.Añadiendo usuario $loginUsuario al grupo $grupo" 

 }
 Catch{
    " - ERROR: No se puede añadir $loginUsuario al grupo $grupo"
 }

# 5. En función del turno copiamos las restricciones de horario de la plantilla correspondiente:
#     Si el turno es "d" (día entero) no se hace nada
#     Si el turno es "m" o "t" se copian las restricciones horarias de la plantilla "_mañana" o "_tarde"
   
If($turno -ne "d"){
    If($turno -eq "m"){
      $plantilla="_mañana"
    }
    If($turno -eq "t"){
      $plantilla="_tarde"
    }

 $usuarioPlantilla=Get-ADUser -Identity $plantilla -Properties logonHours
 $logonhours=@{"Logonhours"= [byte[]]$hours=$usuarioPlantilla.logonHours}
 Set-ADUser $loginUsuario -Replace $logonhours
 "5. Establecido el turno a partir de la plantilla $plantilla"
 
}




   