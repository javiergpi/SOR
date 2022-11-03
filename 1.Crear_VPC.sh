###########################################################
#       Creación de una VPC en AWS con AWS CLI
#  Autor: Javier González Pisano (basado en Javier Terán González)
#  Fecha: 23/10/2022
###########################################################

## Definición de variables
AWS_VPC_CIDR_BLOCK=192.168.4.0/24



## Crear una VPC (Virtual Private Cloud) con su etiqueta
## La VPC tendrá un bloque IPv4 proporcionado por el usuario y uno IPv6 de AWS

echo "Creando VPC..."

AWS_ID_VPC=$(aws ec2 create-vpc \
  --cidr-block $AWS_VPC_CIDR_BLOCK \
  --amazon-provided-ipv6-cidr-block \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=SOR-vpc}]' \
  --query 'Vpc.{VpcId:VpcId}' \
  --output text)