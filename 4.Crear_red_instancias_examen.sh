###########################################################
#       Creación de una infrastructura para el examen
#       Creación de una VPC, subred pública, 
#       internet gateway, tabla de rutas, 
#       grupo de seguridad y dos instancias EC2 Windows 2022 (EXAMEN-SOR-SERVIDOR Y EXAMEN-SOR-CLIENTE)
#      en AWS con AWS CLI
#  Autor: Javier González Pisano (basado en Javier Terán González)
#  Fecha: 23/10/2022
###########################################################

## Definición de variables. CAMBIA EL TERCER DIGITO DE LA SUBRED POR TU NUMERO DE EQUIPO
## (Pregunta a tu profesor si no tienes claro tu número de equipo)
AWS_VPC_CIDR_BLOCK=192.168.199.0/24
AWS_Subred_CIDR_BLOCK=192.168.199.0/24
AWS_IP_Servidor=192.168.199.100
AWS_IP_Cliente=192.168.199.200

AWS_Nombre_Estudiante="javier" #usado para la clave

## Crear una VPC (Virtual Private Cloud) con su etiqueta
## La VPC tendrá un bloque IPv4 proporcionado por el usuario y uno IPv6 de AWS

echo "Creando VPC..."

AWS_ID_VPC=$(aws ec2 create-vpc \
  --cidr-block $AWS_VPC_CIDR_BLOCK \
  --amazon-provided-ipv6-cidr-block \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=EXAMEN-SOR-vpc}]' \
  --query 'Vpc.{VpcId:VpcId}' \
  --output text)

## Habilitar los nombres DNS para la VPC
aws ec2 modify-vpc-attribute \
  --vpc-id $AWS_ID_VPC \
  --enable-dns-hostnames "{\"Value\":true}"


echo "Creando subred pública..."
## Crear una subred publica con su etiqueta
AWS_ID_SubredPublica=$(aws ec2 create-subnet \
  --vpc-id $AWS_ID_VPC --cidr-block $AWS_Subred_CIDR_BLOCK \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=EXAMEN-SOR-subred-publica}]' \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)

## Habilitar la asignación automática de IPs públicas en la subred pública
aws ec2 modify-subnet-attribute \
  --subnet-id $AWS_ID_SubredPublica \
  --map-public-ip-on-launch

echo "Creando y asignando Internet Gateway..."
## Crear un Internet Gateway (Puerta de enlace) con su etiqueta
AWS_ID_InternetGateway=$(aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=EXAMEN-SOR-igw}]' \
  --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' \
  --output text)

## Asignar el Internet gateway a la VPC
aws ec2 attach-internet-gateway \
--vpc-id $AWS_ID_VPC \
--internet-gateway-id $AWS_ID_InternetGateway


echo "Creando y asignando tabla de rutas..."
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
--tags "Key=Name,Value=EXAMEN-SOR ruta por defecto"

## Añadir etiquetas a la tabla de rutas
aws ec2 create-tags \
--resources $AWS_ID_TablaRutas \
--tags "Key=Name,Value=EXAMEN-SOR-rtb-public"





####################################


echo "Creando grupo de seguridad..."
## Crear un grupo de seguridad
aws ec2 create-security-group \
  --vpc-id $AWS_ID_VPC \
  --group-name EXAMEN-SOR-Windows-SG \
  --description 'EXAMEN-SOR-Windows-SG'


AWS_CUSTOM_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$AWS_ID_VPC" \
  --query 'SecurityGroups[?GroupName == `EXAMEN-SOR-Windows-SG`].GroupId' \
  --output text)

## Abrir los puertos de acceso a la instancia
aws ec2 authorize-security-group-ingress \
  --group-id $AWS_CUSTOM_SECURITY_GROUP_ID \
  --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 3389, "ToPort": 3389, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow RDP"}]}]'


## Añadirle etiqueta al grupo de seguridad
aws ec2 create-tags \
--resources $AWS_CUSTOM_SECURITY_GROUP_ID \
--tags "Key=Name,Value=SOR-Windows-SG" 

## aws ec2 create-key-pair --key-name 'clave-SOR'

## Crear una instancia EC2  (con una imagen Windows Server 2022 Base )

echo "Creando instancia EXAMEN-SOR-SERVIDOR..."
AWS_AMI_ID=ami-07a53499a088e4a8c 
AWS_EC2_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AWS_AMI_ID \
  --instance-type t2.medium \
  --key-name "$AWS_Nombre_Estudiante" \
  --monitoring "Enabled=false" \
  --security-group-ids $AWS_CUSTOM_SECURITY_GROUP_ID \
  --subnet-id $AWS_ID_SubredPublica \
  --private-ip-address $AWS_IP_Servidor \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=EXAMEN-SOR-SERVIDOR}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

## Mostrar la ip publica de la instancia
 AWS_EC2_INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances \
 --filters "Name=instance-id,Values="$AWS_EC2_INSTANCE_ID \
 --query "Reservations[*].Instances[*].PublicIpAddress" \
 --output=text) &&
 echo "Creada instancia EXAMEN-SOR con IP " $AWS_EC2_INSTANCE_PUBLIC_IP

echo "Creando instancia EXAMEN-SOR-CLIENTE..."
AWS_AMI_ID=ami-07a53499a088e4a8c
AWS_EC2_INSTANCE_ID2=$(aws ec2 run-instances \
  --image-id $AWS_AMI_ID \
  --instance-type t2.small \
  --key-name "$AWS_Nombre_Estudiante" \
  --monitoring "Enabled=false" \
  --security-group-ids $AWS_CUSTOM_SECURITY_GROUP_ID \
  --subnet-id $AWS_ID_SubredPublica \
  --private-ip-address $AWS_IP_Cliente \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=EXAMEN-SOR-CLIENTE}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

## Mostrar la ip publica de la instancia
 AWS_EC2_INSTANCE_PUBLIC_IP=$(aws ec2 describe-instances \
 --filters "Name=instance-id,Values="$AWS_EC2_INSTANCE_ID2 \
 --query "Reservations[*].Instances[*].PublicIpAddress" \
 --output=text) &&
 echo "Creada instancia EXAMEN-SOR-CLIENTE con IP " $AWS_EC2_INSTANCE_PUBLIC_IP







## aws ec2 describe-addresses