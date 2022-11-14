
<# CreaUsuariosNumero.ps1
    Uso: CreaUsuariosNumero fichero.csv
            Crea una serie de usuarios a partir de la informaci�n que contiene el fichero
            Utiliza el script ./1.CreaUsuario (ver documentaci�n)
            El fichero tiene el siguiente formato:
            Grupo;NumeroUsuarios;Turno
            CONTABILIDAD;5;m
            DISE�O;5;t
    Funcionamiento:
      El script crea tantos usuarios como el n�mero que he puesto llamados como el grupo (en min�sculas) y sucesivos n�meros.
        Ejemplo:contabilidad01, contabilidad02, ... contabilidad30 --> Para estos usuarios se copian las horas de acceso de la plantilla _ma�ana. Todos dentro de la UO CONTABILIDAD y el grupo contabilidad
                 dise�o01, dise�o02, ... dise�o05 --> Para estos usuarios se copian las horas de acceso de la plantilla _tarde.   Todos dentro de la UO DISE�O y el grupo dise�o

        _____
              
 #>



  
 # Muestra un error si no le paso los argumentos el argumento fichero.csv)

 if($args.Length -ne 1){
  "Uso: CreaUsuariosNumero fichero.csv"
  Exit
}


$nombreFichero=$args.getValue(0);

Import-Csv $nombreFichero -Delimiter ";" | ForEach-Object {
 $grupo = $_.Grupo
 $numeroUsuarios = $_.NumeroUsuarios
 $turno = $_.Turno

 for($i=1;$i -le $numeroUsuarios;$i++){
   if($i -lt 10){
     $numero="0"+$i
   }
   else{
    $numero=$i;
   }

   $usuario=$grupo.toLower()+$numero
   .\1.CreaUsuario.ps1 $usuario $grupo.toUpper() $turno

 }


}





