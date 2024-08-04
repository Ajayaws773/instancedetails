#!/bin/bash
set -e

Environment=$Environment
LocalWorkspace=${WORKSPACE}
CurrentDateTime="$(date +"%d-%m-%Y-%H-%M-%S")"

#### VARIABLES - DECLARATION SECTION ######
echo "########## The server details are ........################"
echo "The Environment to Deploy is: $Environment"

########## Declaring the server names by the environment ##########
Devserver=("i-0d6040c16f1f5643d" "i-011b26fedbeffbf1f")
UATserver=("i-047ed6ecbed5e4add" "i-02695a0eca8be2b56")

# Function to describe instances
describe_instances() {
  local servers=("$@")
  INSTANCE_IDS=$(echo "${servers[@]}" | tr '\\t' ' ')
  IFS=' ' read -r -a INSTANCE_ID_ARRAY <<< "$INSTANCE_IDS"
  INSTANCE_DETAILS=()
  for INSTANCE_ID in "${INSTANCE_ID_ARRAY[@]}"
  do
    echo "Describing instance: $INSTANCE_ID"
    INSTANCE_DETAIL=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[*].Instances[*].{InstanceId:InstanceId,InstanceName:Tags[?Key==`Name`].Value | [0],State:State.Name,PublicIpAddress:PublicIpAddress,PrivateIpAddress:PrivateIpAddress,LaunchTime:LaunchTime}' --output json)
    INSTANCE_DETAILS+=("$INSTANCE_DETAIL")
  done
  INSTANCE_DETAILS_JSON=$(jq -s 'map(.[][])' <<< "${INSTANCE_DETAILS[@]}")
  echo "$INSTANCE_DETAILS_JSON" | jq -r '.[] | [.InstanceId, .InstanceName, .State, .PublicIpAddress, .PrivateIpAddress, .LaunchTime] | @tsv' | column -t
}

# Function to describe instances in an ASG
describe_asg_instances() {
  local asg="$1"
  INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name "$asg" --query 'AutoScalingGroups[*].Instances[*].InstanceId' --output text)
  echo "Raw instance IDs: $INSTANCE_IDS"
  INSTANCE_IDS=$(echo $INSTANCE_IDS | tr '\t' ' ')
  echo "Processed instance IDs: $INSTANCE_IDS"
  IFS=' ' read -r -a INSTANCE_ID_ARRAY <<< "$INSTANCE_IDS"
  echo "Array items: ${INSTANCE_ID_ARRAY[@]}"
  INSTANCE_DETAILS=()
  for INSTANCE_ID in "${INSTANCE_ID_ARRAY[@]}"
  do
    echo "Describing instance: $INSTANCE_ID"
    INSTANCE_DETAIL=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[*].Instances[*].{InstanceId:InstanceId,InstanceName:Tags[?Key==`Name`].Value | [0],State:State.Name,PublicIpAddress:PublicIpAddress,PrivateIpAddress:PrivateIpAddress,LaunchTime:LaunchTime}' --output json)
    INSTANCE_DETAILS+=("$INSTANCE_DETAIL")
  done
  INSTANCE_DETAILS_JSON=$(jq -s 'map(.[][])' <<< "${INSTANCE_DETAILS[@]}")
  echo "$INSTANCE_DETAILS_JSON" | jq -r '.[] | [.InstanceId, .InstanceName, .State, .PublicIpAddress, .PrivateIpAddress, .LaunchTime] | @tsv' | column -t
}

if [[ "$Environment" == "Dev" || "$Environment" == "UAT" ]]; then
  case $Environment in
    "Dev")
      echo "The Target environment is: Dev"
      describe_instances "${Devserver[@]}"
      ;;
    "UAT")
      echo "The Target environment is: UAT"
      describe_instances "${UATserver[@]}"
      ;;
    *)
      echo "Invalid environment specified for Dev/UAT."
      exit 1
      ;;
  esac
elif [[ "$Environment" == "ASG" ]]; then
  asg="asg"  # Replace with the actual Auto Scaling Group name
  describe_asg_instances "$asg"
elif [[ "$Environment" == "ASG2" ]]; then
  asg="asg2"  # Replace with the actual Auto Scaling Group name
  describe_asg_instances "$asg"
else
  echo "Invalid environment specified."
  exit 1
fi
