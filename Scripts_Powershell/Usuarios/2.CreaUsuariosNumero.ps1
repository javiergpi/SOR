
<# CreaUsuariosNumero.ps1
    Uso: CreaUsuariosNumero fichero.csv
            Crea una serie de usuarios a partir de la información que contiene el fichero
            Utiliza el script ./1.CreaUsuario (ver documentación)
            El fichero tiene el siguiente formato:
            Grupo;NumeroUsuarios;Turno
            CONTABILIDAD;5;m
            DISEÑO;5;t
    Funcionamiento:
      El script crea tantos usuarios como el número que he puesto llamados como el grupo (en minúsculas) y sucesivos números.
        Ejemplo:contabilidad01, contabilidad02, ... contabilidad30 --> Para estos usuarios se copian las horas de acceso de la plantilla _mañana. Todos dentro de la UO CONTABILIDAD y el grupo contabilidad
                 diseño01, diseño02, ... diseño05 --> Para estos usuarios se copian las horas de acceso de la plantilla _tarde.   Todos dentro de la UO DISEÑO y el grupo diseño

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





