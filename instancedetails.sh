#!/bin/bash
set -e

Environment=$Environment
LocalWorkspace=${WORKSPACE}
CurrentDateTime="$(date +"%d-%m-%Y-%H-%M-%S")"

#### VARIABLES - DECLARATION SECTION ######
echo "########## The server details are ........################ "
echo "The Environment to Deploy is : $Environment"

########## Declaring the server names by the environment ##########
Devserver=("i-0d6040c16f1f5643d" "i-0d6040c16f1f5643d")
UATserver=("i-0d6040c16f1f5643d")
ASGserver=("i-0d6040c16f1f5643d")
Prodserver=("i-0d6040c16f1f5643d")

# Function to describe instances
describe_instances() {
  local servers=("$@")
  INSTANCE_IDS=$(echo "${servers[@]}" | tr '\\t' ' ')
  IFS=' ' read -r -a INSTANCE_ID_ARRAY <<< "$INSTANCE_IDS"
  INSTANCE_DETAILS=()
  for INSTANCE_ID in "${INSTANCE_ID_ARRAY[@]}"
  do
    echo "Describing instance: $INSTANCE_ID"
    INSTANCE_DETAIL=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[*].Instances[*].{InstanceId:InstanceId,InstanceName:Tags[?Key==`Name`].Value | [0],State:State.Name,PublicIpAddress:PublicIpAddress,PrivateIpAddress:PrivateIpAddress}' --output json)
    INSTANCE_DETAILS+=("$INSTANCE_DETAIL")
  done
  INSTANCE_DETAILS_JSON=$(jq -s 'map(.[][])' <<< "${INSTANCE_DETAILS[@]}")
  echo "$INSTANCE_DETAILS_JSON" | jq -r '.[] | [.InstanceId, .InstanceName, .State, .PublicIpAddress, .PrivateIpAddress] | @tsv' | column -t
}

case $Environment in
  "Dev")
    echo "The Target environment is : Dev"
    describe_instances "${Devserver[@]}"
    ;;
  "UAT")
    echo "The Target environment is : UAT"
    describe_instances "${UATserver[@]}"
    ;;
  "ASG")
    echo "The Target environment is : ASG"
    describe_instances "${ASGserver[@]}"
    ;;
  "Production")
    echo "The Target environment is : Production"
    describe_instances "${Prodserver[@]}"
    ;;
  *)
    echo "Invalid environment specified."
    exit 1
    ;;
esac
