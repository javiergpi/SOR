###########################################################
#  Autor: Javier González Pisano (basado en Javier Terán González)
#  Fecha: 02/11/2022
      #  Creación de varios elementos en AWS Cli:
      #    - Elementos de red: 
      #         Una VPC
      #         Subred pública
      #         Internet gateway
      #         Tabla de rutas
      #         Conjunto de opciones DHCP
      #    - Elementos de computación: 
      #         Grupo de seguridad compartido para ambas instancias, con tráfico entre la subred permitido
      #         Instancia EC2 Windows 2022 SERVIDOR con IP elástica
      #            - Realizamos las siguientes acciones a partir de los datos de UserDataPDC.txt:
      #                - Abrir reglas de cortafuegos para permitir ping.
      #                - Instalar rol de Active Directory 
      #                - Instalar choco (gestor de paquetes)
      #                - Instalar git
      #                - Renombrar el equipo
      #                - Descargar al escritorio de Administrador el script PromocionaPDC.ps1.
      #                   Dicho script debe ejecutarse manualmente para promocionar a controlador de dominio.
      #         Instancia EC2 Windows 2022 CLIENTE con IP elástica
      #             - Realizamos las siguientes acciones a partir de los datos de UserDataCliente.txt:
      #                - Abrir reglas de cortafuegos para permitir ping.
      #                - Instalar choco (gestor de paquetes)
      #                - Instalar git
      #                - Renombrar el equipo.
      #                - Descargar al escritorio de Administrador el script uneDominio.ps1.
      #                   Dicho script debe ejecutarse para unir el cliente al dominio.
                    
###########################################################

#SECCION DE VARIABLES: A CUSTOMIZAR POR EL ALUMNO

# VARIABLES AWS

#CIDR de la VPC
AWS_VPC_CIDR_BLOCK=192.168.66.0/24

#CIDR de la subred pública (deber ser subconjunto de la anterior)
AWS_Subred_CIDR_BLOCK=192.168.66.0/24

#Dirección privada del PDC en la subred pública
AWS_IP_Servidor=192.168.66.100

#Dirección privada del cliente en la subred pública
AWS_IP_Cliente=192.168.66.200

# Nombre de la clave usada para generar contraseñas
AWS_Nombre_Clave="javier" 

# VARIABLES PDC (NECESARIAS PARA CONFIGURACION PDC)

#Nombre del PDC (Cambia por tu número, ejemplo SERVIDOR-00)
Nombre_Servidor="SERVIDOR-PROFE"

#Nombre del CLIENTE (Cambia por tu número, ejemplo CLIENTE00-01)
Nombre_Cliente="CLIENTEPROFE-01"

#Nombre DNS del dominio (cambia por tu número, ejemplo dominio00.local)
DNS_Dominio="dominioprofe.local"

#Nombre NETBIOS del dominio. Pondremos el DNS sin el sufijo y en mayúsculas, por convención.
# Ejemplo DOMINIO00
NETBIOS_Dominio="DOMINIOPROFE"

#URL Repositorio (no tocar)
URL_Repositorio="https://github.com/javiergpi/SOR-Pruebas.git"

#Script para promocion PDC (no tocar)
Script_PDC="PromocionaPDC.ps1"

#Script para unir cliente a dominio (no tocar)
Script_Cliente="UneDominio.ps1"


## Crear una VPC (Virtual Private Cloud) con su etiqueta
## La VPC tendrá un bloque IPv4 proporcionado por el usuario y uno IPv6 de AWS

echo "1. Creando VPC..."

AWS_ID_VPC=$(aws ec2 create-vpc \
  --cidr-block $AWS_VPC_CIDR_BLOCK \
  --amazon-provided-ipv6-cidr-block \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=SOR-vpc}]' \
  --query 'Vpc.{VpcId:VpcId}' \
  --output text)

## Habilitar los nombres DNS para la VPC
aws ec2 modify-vpc-attribute \
  --vpc-id $AWS_ID_VPC \
  --enable-dns-hostnames "{\"Value\":true}"


echo "2. Creando subred pública..."
## Crear una subred publica con su etiqueta
AWS_ID_SubredPublica=$(aws ec2 create-subnet \
  --vpc-id $AWS_ID_VPC --cidr-block $AWS_Subred_CIDR_BLOCK \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=SOR-subred-publica}]' \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)

## Habilitar la asignación automática de IPs públicas en la subred pública
aws ec2 modify-subnet-attribute \
  --subnet-id $AWS_ID_SubredPublica \
  --map-public-ip-on-launch

echo "3. Creando y asignando Internet Gateway..."
## Crear un Internet Gateway (Puerta de enlace) con su etiqueta
AWS_ID_InternetGateway=$(aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=SOR-igw}]' \
  --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' \
  --output text)

## Asignar el Internet gateway a la VPC
aws ec2 attach-internet-gateway \
--vpc-id $AWS_ID_VPC \
--internet-gateway-id $AWS_ID_InternetGateway


echo "4. Creando y asignando tabla de rutas..."
## Crear una tabla de rutas
AWS_ID_TablaRutas=$(aws ec2 create-route-table \
--vpc-id $AWS_ID_VPC \
--query 'RouteTable.{RouteTableId:RouteTableId}' \
--output text )

## Crear la ruta por defecto a la puerta de enlace (Internet Gateway)
aws ec2 create-route \
  --route-table-id $AWS_ID_TablaRutas \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $AWS_ID_InternetGateway

## Asociar la subred pública con la tabla de rutas
AWS_ROUTE_TABLE_ASSOID=$(aws ec2 associate-route-table  \
  --subnet-id $AWS_ID_SubredPublica \
  --route-table-id $AWS_ID_TablaRutas \
  --output text)

## Añadir etiqueta a la ruta por defecto
AWS_DEFAULT_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$AWS_ID_VPC" \
  --query 'RouteTables[?Associations[0].Main != `flase`].RouteTableId' \
  --output text) &&
aws ec2 create-tags \
--resources $AWS_DEFAULT_ROUTE_TABLE_ID \
--tags "Key=Name,Value=SOR ruta por defecto"

## Añadir etiquetas a la tabla de rutas
aws ec2 create-tags \
--resources $AWS_ID_TablaRutas \
--tags "Key=Name,Value=SOR-rtb-public"

echo "5. Creando un conjunto de opciones DHCP..."
## Crear un conjunto de opciones DHCP
AWS_DHCP_OPTIONS_ID=$(aws ec2 create-dhcp-options \
    --dhcp-configuration \
        "Key=domain-name-servers,Values=$AWS_IP_Servidor,8.8.8.8" \
        "Key=domain-name,Values=$DNS_Dominio" \
        "Key=netbios-node-type,Values=2" \
    --tag-specifications 'ResourceType=dhcp-options,Tags=[{Key=Name,Value=SOR-DHCP-opciones}]' \
    --query 'DhcpOptions.{DhcpOptionsId:DhcpOptionsId}' \
  --output text)

## Asgignar el conjunto de opciones DHCP al VPC
aws ec2 associate-dhcp-options --dhcp-options-id $AWS_DHCP_OPTIONS_ID --vpc-id $AWS_ID_VPC


###################################

echo "6. Creando grupo de seguridad para las instancias..."
## Crear un grupo de seguridad
aws ec2 create-security-group \
  --vpc-id $AWS_ID_VPC \
  --group-name SOR-Windows-SG \
  --description 'SOR-Windows-SG'


AWS_CUSTOM_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$AWS_ID_VPC" \
  --query 'SecurityGroups[?GroupName == `SOR-Windows-SG`].GroupId' \
  --output text)

## Abrir los puertos de acceso a la instancia
aws ec2 authorize-security-group-ingress \
  --group-id $AWS_CUSTOM_SECURITY_GROUP_ID \
  --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 3389, "ToPort": 3389, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow RDP"}]}]'


## Abrir los puertos de acceso a la instancia
                  
BLOQUE=$(dirname $AWS_Subred_CIDR_BLOCK)
aws ec2 authorize-security-group-ingress \
  --group-id $AWS_CUSTOM_SECURITY_GROUP_ID \
  --ip-permissions '[{"IpProtocol": "-1", "IpRanges": [{"CidrIp":"'"$AWS_Subred_CIDR_BLOCK"'", "Description": "Trafico interno"}]}]'



## Añadirle etiqueta al grupo de seguridad
aws ec2 create-tags \
--resources $AWS_CUSTOM_SECURITY_GROUP_ID \
--tags "Key=Name,Value=SOR-Windows-SG" 


##### PERSONALIZACIÓN DE OPCIONES. AÑADIMOS CONTENIDO A LOS UserData. #############


# Modificamos el archivo UserDataPDC.txt para añadir datos de personalización.
# Añadimos contenido al principio (tag de entrada y variables) y al final

BASEDIR=$(cd $(dirname $0) && pwd)

sed -i "1 i\$SCRIPT_PDC=\"${Script_PDC}\" \n" "${BASEDIR}/UserDataPDC.txt"
# Extraemos el nombre del respositorio de la URL
  basename=$(basename $URL_Repositorio)
  Nombre_Repositorio=${basename%.*}
sed -i "1 i\$NOMBRE_REPOSITORIO=\"${Nombre_Repositorio}\" \n" "${BASEDIR}/UserDataPDC.txt"
sed -i "1 i\$URL_REPOSITORIO=\"${URL_Repositorio}\" \n" "${BASEDIR}/UserDataPDC.txt"
sed -i "1 i\$NETBIOS_DOMINIO=\"${NETBIOS_Dominio}\" \n" "${BASEDIR}/UserDataPDC.txt"
sed -i "1 i\$DNS_DOMINIO=\"${DNS_Dominio}\" \n" "${BASEDIR}/UserDataPDC.txt"
sed -i "1 i\$NOMBRE_SERVIDOR=\"${Nombre_Servidor}\" \n" "${BASEDIR}/UserDataPDC.txt"
sed -i '1s/^/<powershell> \n /' "${BASEDIR}/UserDataPDC.txt"
sed -i "$ a </powershell> \n"  "${BASEDIR}/UserDataPDC.txt"

# Modificamos el archivo UserDataCliente.txt para añadir datos de personalización.

sed -i "1 i\$SCRIPT_CLIENTE=\"${Script_Cliente}\" \n" "${BASEDIR}/UserDataCliente.txt"
sed -i "1 i\$NOMBRE_REPOSITORIO=\"${Nombre_Repositorio}\" \n" "${BASEDIR}/UserDataCliente.txt"
sed -i "1 i\$URL_REPOSITORIO=\"${URL_Repositorio}\" \n" "${BASEDIR}/UserDataCliente.txt"
sed -i "1 i\$DNS_DOMINIO=\"${DNS_Dominio}\" \n" "${BASEDIR}/UserDataCliente.txt"
sed -i "1 i\$NOMBRE_CLIENTE=\"${Nombre_Cliente}\" \n" "${BASEDIR}/UserDataCliente.txt"
sed -i '1s/^/<powershell> \n /' "${BASEDIR}/UserDataCliente.txt"
sed -i "$ a </powershell> \n"  "${BASEDIR}/UserDataCliente.txt"



## Crear una instancia EC2  (con una imagen Windows Server 2022 Base )
echo "7. Creando instancia SERVIDOR..."
AWS_AMI_ID=ami-07a53499a088e4a8c 
AWS_EC2_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AWS_AMI_ID \
  --instance-type t2.medium \
  --key-name "$AWS_Nombre_Clave" \
  --user-data file://${BASEDIR}/UserDataPDC.txt \
  --monitoring "Enabled=false" \
  --security-group-ids $AWS_CUSTOM_SECURITY_GROUP_ID \
  --subnet-id $AWS_ID_SubredPublica \
  --private-ip-address $AWS_IP_Servidor \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value='$Nombre_Servidor'}]' \
  --query 'Instances[0].InstanceId' \
  --output text)


##########################################################
## Crear IP Estatica para la instancia SERVIDOR. (IP elastica)
AWS_IP_Fija_Servidor=$(aws ec2 allocate-address --output text)
 
## Recuperar AllocationId de la IP elastica
AWS_IP_Fija_Servidor_AllocationId=$(echo $AWS_IP_Fija_Servidor | awk '{print $1}')

## Añadirle etiqueta a la ip elástica de SERVIDOR
aws ec2 create-tags \
--resources $AWS_IP_Fija_Servidor_AllocationId \
--tags "Key=Name,Value=SOR-SERVIDOR-ip" 


echo "8. Creando instancia CLIENTE..."
AWS_AMI_ID=ami-07a53499a088e4a8c
AWS_EC2_INSTANCE_ID2=$(aws ec2 run-instances \
  --image-id $AWS_AMI_ID \
  --instance-type t2.small \
  --key-name "$AWS_Nombre_Clave" \
  --user-data file://${BASEDIR}/UserDataCliente.txt \
  --monitoring "Enabled=false" \
  --security-group-ids $AWS_CUSTOM_SECURITY_GROUP_ID \
  --subnet-id $AWS_ID_SubredPublica \
  --private-ip-address $AWS_IP_Cliente \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value='$Nombre_Cliente'}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

##########################################################
## Crear IP Estatica para la instancia CLIENTE. (IP elastica)
AWS_IP_Fija_Cliente=$(aws ec2 allocate-address --output text)
 
## Recuperar AllocationId de la IP elastica
AWS_IP_Fija_Cliente_AllocationId=$(echo $AWS_IP_Fija_Cliente | awk '{print $1}')

## Añadirle etiqueta a la ip elástica de CLIENTE
aws ec2 create-tags \
--resources $AWS_IP_Fija_Cliente_AllocationId \
--tags "Key=Name,Value=SOR-CLIENTE-ip" 


echo "9. Esperando a que las instancias estén disponibles para asociar IPs elásticas (80 segundos)"
sleep 80

## Asociar la ip elastica a la instancia SERVIDOR
aws ec2 associate-address --instance-id $AWS_EC2_INSTANCE_ID --allocation-id $AWS_IP_Fija_Servidor_AllocationId 


## Asociar la ip elastica a la instancia CLIENTE
aws ec2 associate-address --instance-id $AWS_EC2_INSTANCE_ID2 --allocation-id $AWS_IP_Fija_Cliente_AllocationId 


## Mostrar la ip publica de la instancia SERVIDOR
 AWS_EC2_INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances \
 --filters "Name=instance-id,Values="$AWS_EC2_INSTANCE_ID \
 --query "Reservations[*].Instances[*].PublicIpAddress" \
 --output=text) &&
 echo "10. Creada instancia servidor con IP " $AWS_EC2_INSTANCE_PUBLIC_IP

## Mostrar la ip publica de la instancia Cliente
 AWS_EC2_INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances \
 --filters "Name=instance-id,Values="$AWS_EC2_INSTANCE_ID2 \
 --query "Reservations[*].Instances[*].PublicIpAddress" \
 --output=text) &&
 echo "11. Creada instancia cliente con IP " $AWS_EC2_INSTANCE_PUBLIC_IP


