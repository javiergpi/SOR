$ping=$false;
While(!$ping){
    echo "Probando conectividad..."
    $ping=Test-Connection SERVIDOR-66.dominio66.local -Quiet
    Start-Sleep -Seconds 5
    if($ping){
        echo "Hay conectividad"
    }
}

echo "Espero 5 mas"
Start-Sleep -Seconds 5
echo "Fin"