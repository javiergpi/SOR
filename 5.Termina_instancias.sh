###########################################################
#    Termina todas las instancias 
#  Autor: Javier González Pisano 
#  Fecha: 06/10/2022
###########################################################


# Borra todas las instancias
echo ".....1.Borrando instancias..."
aws ec2 terminate-instances 
        --instance-ids 
         $(
          aws ec2 describe-instances 
            | grep InstanceId 
            | awk {'print $2'} 
            | sed 's/[",]//g'
          )
sleep 2
echo ".....1. Borradas instancias..."

# Liberamos IPs elásticas no usadas
echo ".....2.Liberando IPs elásticas..."
aws ec2 describe-addresses --query 'Addresses[].[AllocationId,AssociationId]' --output text | \
awk '$2 == "None" { print $1 }' | \
xargs -I {} aws ec2 release-address --allocation-id {} 
echo ".....2.Liberadas IPs elásticas..."

# Eliminamos todas las VPC menos la VPC por defecto
echo ".....3.Eliminando VPCs..."


#  # get default vpc
#   vpc=$( aws ec2  describe-vpcs  --output text --query 'Vpcs[0].VpcId' )
#   if [ "${vpc}" = "None" ]; then
#     echo "${INDENT}No default vpc found"
#     continue
#   fi
#   echo "${INDENT}Found default vpc ${vpc}"

#   # get internet gateway
#   igw=$(aws ec2 describe-internet-gateways --filter Name=attachment.vpc-id,Values=${vpc}  --output text --query 'InternetGateways[0].InternetGatewayId' )
#   if [ "${igw}" != "None" ]; then
#     echo "${INDENT}Detaching and deleting internet gateway ${igw}"
#     aws ec2 detach-internet-gateway --internet-gateway-id ${igw} --vpc-id ${vpc}
#     aws ec2 delete-internet-gateway --internet-gateway-id ${igw}
#   fi

#   # get subnets
#   subnets=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=${vpc} --output text --query 'Subnets[].SubnetId' )
#   if [ "${subnets}" != "None" ]; then
#     for subnet in ${subnets}; do
#       echo "${INDENT}Deleting subnet ${subnet}"
#       aws ec2 delete-subnet --subnet-id ${subnet}
#     done
#   fi

#   # https://docs.aws.amazon.com/cli/latest/reference/ec2/delete-vpc.html
#   # - You can't delete the main route table
#   # - You can't delete the default network acl
#   # - You can't delete the default security group

#   # delete default vpc
#   echo "${INDENT}Deleting vpc ${vpc}"
#   aws ec2 delete-vpc --vpc-id ${vpc}
