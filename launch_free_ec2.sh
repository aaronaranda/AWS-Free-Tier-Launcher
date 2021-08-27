#!/bin/bash

# Dependencies
which jq &> /dev/null
if [ $? -eq 1 ]; then
  sudo brew install jq
fi

# Variables
MY_KEY_PAIR=""
# security group
MY_SG=""
MY_SG_DESC=""
SG_ID=""
# vpc
VPC_ID=""
SUB_ID=""
# ec2
TYPE="t2.micro"
COUNT=1
AMI="ami-0ab4d1e9cf9a1215a"
CIDR=""

get_sg() {
  echo "Choose a security group from the list OR specify a name for a new security group: "
  echo "Use 'Name' value to choose from list."
  aws ec2 describe-security-groups | jq ".SecurityGroups | .[] | { Name: .GroupName, ID: .GroupId }"
  read -p "Name: " MY_SG  
  aws ec2 describe-security-groups --group-name "$MY_SG" &> /dev/null  
  if [ $? -ne 0 ]; then
    read -p "Add a description for new SG (or leave blank):" descr
    aws ec2 create-security-group --group-name "$MY_SG" --description "$descr" --vpc-id "$VPC_ID"
  fi
  SG_ID=$(aws ec2 describe-security-groups --group-name "$MY_SG" | jq ".SecurityGroups | .[] | .GroupId" | awk '{print substr($1,2,length($1)-2)}')
}

get_vpc_id() {
  echo "Select a VPC (1 or 2 or...):"
  aws ec2 describe-vpcs | jq ".Vpcs | .[] | .VpcId" | nl
  read -p 'VPC: ' vpc_choice
  VPC_ID=$(aws ec2 describe-vpcs | jq ".Vpcs | .[] | .VpcId" | nl | grep "$vpc_choice\t" | awk '{print substr($2,2,length($2)-2)}')
}

get_subnet_id() {
  echo "Select a Subnet (1 or 2 or ...):"
  aws ec2 describe-subnets | jq ".Subnets | .[] | .SubnetId" | nl 
  read -p 'Subnet: ' subnet_choice
  SUB_ID=$(aws ec2 describe-subnets | jq ".Subnets | .[] | .SubnetId" | nl | grep "$subnet_choice\t" | awk '{print substr($2,2,length($2)-2)}')
}

get_key_pair() {
  if [ "$MY_KEY_PAIR" == "" ]; then
    read -p "Enter a key pair name that you would like to use: " MY_KEY_PAIR
    aws ec2 describe-key-pairs --key-name "$MY_KEY_PAIR" &> /dev/null
    if [ $? -ne 0 ]; then
      aws ec2 create-key-pair --key-name "$MY_KEY_PAIR" --query 'KeyMaterial' --output text > "$MY_KEY_PAIR.pem"
    fi
  fi
  chmod 400 "$MY_KEY_PAIR.pem"
}



while test $# -gt 0; do
  case "$1" in
    -h|--help)
      printf "Used to Launch a Free Tier AWS Instance\n"
      printf "Amazon Linux 2 AMI (HVM), SSD Volume Type (64-bit x86)\n"
      printf "t2.micro\n"
      printf "\tOptions and arguments:\n"
      printf -- "-h, --help\tshow this message\n\n"
      printf -- "-k, --key-pair=\tspecify the name of .pem file\n"
      printf -- "\t\twill locate keypair if it already exists\n\n"
      printf -- "-sg, --security-group\tname of security group\n"
      printf "\t\twill create new security group if it does not already exist\n"
      printf "\t\tif security group does not already exist, add description:\n"
      printf -- '\t\tExample: -sg my-group "my new sg"\n\n'
      printf -- "--desc\tadd a description to security group\n"
      printf "\tonly works if security group does not already exist\n\n"
      printf -- "--vpc-id\tID of VPC to associate security group with\n"
      printf "\t\tonly works if security group does not already exist\n\n"
      printf -- "--subnet-id\tID of subnet to associate security group with\n\n"
      printf -- "-i, --ingress\tadd ingress rule\n"
      printf -- "-e, --egress\tadd egress rule\n"
      printf "\toptions: ssh (tcp port 22, default public IP)\n\n"
      printf -- "-c, --count\tnumber of instances, default is 1\n\n"
      printf -- "Note: instance type can be overidden (-t)"
      exit 0
      ;;
    -k|--key-pair)
      shift
      if test $# -gt 0; then
        MY_KEY_PAIR=$1
      else
        echo "No keypair name specified" >&2
        get_key_pair
      fi
      aws ec2 describe-key-pairs --key-name "$MY_KEY_PAIR" &> /dev/null
      if [ $? -ne 0 ]; then
        aws ec2 create-key-pair --key-name "$MY_KEY_PAIR" --query 'KeyMaterial' --output text > "$MY_KEY_PAIR.pem"
      fi
      chmod 400 "$MY_KEY_PAIR.pem"
      shift
      ;;
    -sg|--security-group)
      shift
      if test $# -eq 1; then
        MY_SG=$1
      elif test $# -eq 2; then
        MY_SG=$1
        MY_SG_DESC=$2
      else
        echo "No Security Group specified" >&2
        exit 1
      fi
      if [ "$VPC_ID" == "" ]; then
        get_vpc_id
      fi
      aws ec2 describe-security-groups --group-name "$MY_SG" &> /dev/null
      if [ $? -ne 0 ]; then
        aws ec2 create-security-group --group-name "$MY_SG" --description "$MY_SG_DESC" --vpc-id "$VPC_ID"
      fi
      shift
      ;;
    --subnet-id)
      shift
      if test $# -gt 1; then
        SUB_ID=$1
      else
        echo "No Subnet ID specified"
        get_subnet_id
      fi
      shift
      ;;
    -c|--count)
      shift
      if test $# -gt 0; then
        COUNT=$1
      else
        echo "No instance count specified" >&2
      fi
      shift
      ;;
    --vpc-id)
      shift
      if tes $# -gt 0; then
        VPC_ID=$1
      else 
        printf "No VPC ID was specified\n"
        get_vpc_id
      fi
      shift
      ;;
    -i|--ingress)
      shift
      if test $# -gt 0; then
        if [ $1 == "ssh" ]; then
          read -p "CIDR: " cidr
          aws ec2 authorize-security-group --group-id "$SG_ID" --protocol tcp --port 22 --cidr $cidr
        fi
      fi
      shift
      ;;
    -t)
      shift
      if test $# -gt 0; then
        TYPE=$1
      fi
      shift
      ;;
    *)
      break
      ;;
  esac
done

if [ "$MY_KEY_PAIR" == "" ]; then
  get_key_pair
fi

if [ "$VPC_ID" == "" ]; then
  get_vpc_id
fi

if [ "$MY_SG" == "" ]; then
  get_sg
fi

if [ "$SUB_ID" == "" ]; then
  get_subnet_id
fi




echo "Launch instance with these characteristics?"
printf "AMI\t\t: $AMI\n"
printf "Type\t\t: $TYPE\n"
printf "Key-Pair\t: $MY_KEY_PAIR\n"
printf "VPC ID\t\t: $VPC_ID\n"
printf "Security Group\t: $MY_SG\t ID: $SG_ID\n"
printf "Subnet\t\t: $SUB_ID\n\n"

read -p "Launch? (y/n): " confirm
if [ "$confirm" == "y" ]; then
  aws ec2 run-instances \
    --image-id "$AMI" \
    --count "$COUNT" \
    --instance-type "$TYPE" \
    --key-name "$MY_KEY_PAIR" \
    --security-group-ids "$SG_ID" \
    --subnet-id "$SUB_ID" 
  if [ $? -eq 0 ]; then
    echo "Success"
    exit 0
  fi
elif [ "$confirm" == "n" ]; then
  echo "Launch cancelled"
  exit 0
fi




  
