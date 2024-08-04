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
    INSTANCE_DETAIL=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[*].Instances[*].{InstanceId:InstanceId,InstanceName:Tags[?Key==`Name`].Value | [0],State:State.Name,PublicIpAddress:PublicIpAddress,PrivateIpAddress:PrivateIpAddress,LaunchTime:LaunchTime,PublicDnsName:PublicDnsName}' --output json)
    INSTANCE_DETAILS+=("$INSTANCE_DETAIL")
  done
  INSTANCE_DETAILS_JSON=$(jq -s 'map(.[][])' <<< "${INSTANCE_DETAILS[@]}")

  # Determine column widths
  col1_width=$(echo "$INSTANCE_DETAILS_JSON" | jq -r '.[] | .InstanceId' | awk '{print length($0)}' | sort -n | tail -1)
  col2_width=$(echo "$INSTANCE_DETAILS_JSON" | jq -r '.[] | .InstanceName // ""' | awk '{print length($0)}' | sort -n | tail -1)
  col3_width=$(echo "$INSTANCE_DETAILS_JSON" | jq -r '.[] | .State // ""' | awk '{print length($0)}' | sort -n | tail -1)
  col4_width=$(echo "$INSTANCE_DETAILS_JSON" | jq -r '.[] | .PublicIpAddress // ""' | awk '{print length($0)}' | sort -n | tail -1)
  col5_width=$(echo "$INSTANCE_DETAILS_JSON" | jq -r '.[] | .PrivateIpAddress // ""' | awk '{print length($0)}' | sort -n | tail -1)
  col6_width=$(echo "$INSTANCE_DETAILS_JSON" | jq -r '.[] | .LaunchTime // ""' | awk '{print length($0)}' | sort -n | tail -1)
  col7_width=$(echo "$INSTANCE_DETAILS_JSON" | jq -r '.[] | .PublicDnsName // ""' | awk '{print length($0)}' | sort -n | tail -1)

  # Print the header
  printf "+-%s-+-%s-+-%s-+-%s-+-%s-+-%s-+-%s-+\n" $(printf '%*s' $((col1_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col2_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col3_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col4_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col5_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col6_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col7_width + 2)) '' | tr ' ' '-')
  printf "| %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s |\n" $col1_width "InstanceId" $col2_width "InstanceName" $col3_width "State" $col4_width "PublicIpAddress" $col5_width "PrivateIpAddress" $col6_width "LaunchTime" $col7_width "PublicDnsName"
  printf "+-%s-+-%s-+-%s-+-%s-+-%s-+-%s-+-%s-+\n" $(printf '%*s' $((col1_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col2_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col3_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col4_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col5_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col6_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col7_width + 2)) '' | tr ' ' '-')

  # Print the data rows
  echo "$INSTANCE_DETAILS_JSON" | jq -r ".[] | [.InstanceId, .InstanceName, .State, .PublicIpAddress, .PrivateIpAddress, .LaunchTime, .PublicDnsName] | @tsv" | \
  awk -v col1_width="$col1_width" -v col2_width="$col2_width" -v col3_width="$col3_width" -v col4_width="$col4_width" -v col5_width="$col5_width" -v col6_width="$col6_width" -v col7_width="$col7_width" '
  BEGIN { FS = "\t"; OFS = " | " }
  {
    printf "| %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s |\n", col1_width, $1, col2_width, $2, col3_width, $3, col4_width, $4, col5_width, $5, col6_width, $6, col7_width, $7
  }'
  
  # Print the footer
  printf "+-%s-+-%s-+-%s-+-%s-+-%s-+-%s-+-%s-+\n" $(printf '%*s' $((col1_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col2_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col3_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col4_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col5_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col6_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col7_width + 2)) '' | tr ' ' '-')
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
    INSTANCE_DETAIL=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[*].Instances[*].{InstanceId:InstanceId,InstanceName:Tags[?Key==`Name`].Value | [0],State:State.Name,PublicIpAddress:PublicIpAddress,PrivateIpAddress:PrivateIpAddress,LaunchTime:LaunchTime,PublicDnsName:PublicDnsName}' --output json)
    INSTANCE_DETAILS+=("$INSTANCE_DETAIL")
  done
  INSTANCE_DETAILS_JSON=$(jq -s 'map(.[][])' <<< "${INSTANCE_DETAILS[@]}")

  # Determine column widths
  col1_width=$(echo "$INSTANCE_DETAILS_JSON" | jq -r '.[] | .InstanceId' | awk '{print length($0)}' | sort -n | tail -1)
  col2_width=$(echo "$INSTANCE_DETAILS_JSON" | jq -r '.[] | .InstanceName // ""' | awk '{print length($0)}' | sort -n | tail -1)
  col3_width=$(echo "$INSTANCE_DETAILS_JSON" | jq -r '.[] | .State // ""' | awk '{print length($0)}' | sort -n | tail -1)
  col4_width=$(echo "$INSTANCE_DETAILS_JSON" | jq -r '.[] | .PublicIpAddress // ""' | awk '{print length($0)}' | sort -n | tail -1)
  col5_width=$(echo "$INSTANCE_DETAILS_JSON" | jq -r '.[] | .PrivateIpAddress // ""' | awk '{print length($0)}' | sort -n | tail -1)
  col6_width=$(echo "$INSTANCE_DETAILS_JSON" | jq -r '.[] | .LaunchTime // ""' | awk '{print length($0)}' | sort -n | tail -1)
  col7_width=$(echo "$INSTANCE_DETAILS_JSON" | jq -r '.[] | .PublicDnsName // ""' | awk '{print length($0)}' | sort -n | tail -1)

  # Print the header
  printf "+-%s-+-%s-+-%s-+-%s-+-%s-+-%s-+-%s-+\n" $(printf '%*s' $((col1_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col2_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col3_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col4_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col5_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col6_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col7_width + 2)) '' | tr ' ' '-')
  printf "| %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s |\n" $col1_width "InstanceId" $col2_width "InstanceName" $col3_width "State" $col4_width "PublicIpAddress" $col5_width "PrivateIpAddress" $col6_width "LaunchTime" $col7_width "PublicDnsName"
  printf "+-%s-+-%s-+-%s-+-%s-+-%s-+-%s-+-%s-+\n" $(printf '%*s' $((col1_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col2_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col3_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col4_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col5_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col6_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col7_width + 2)) '' | tr ' ' '-')

  # Print the data rows
  echo "$INSTANCE_DETAILS_JSON" | jq -r ".[] | [.InstanceId, .InstanceName, .State, .PublicIpAddress, .PrivateIpAddress, .LaunchTime, .PublicDnsName] | @tsv" | \
  awk -v col1_width="$col1_width" -v col2_width="$col2_width" -v col3_width="$col3_width" -v col4_width="$col4_width" -v col5_width="$col5_width" -v col6_width="$col6_width" -v col7_width="$col7_width" '
  BEGIN { FS = "\t"; OFS = " | " }
  {
    printf "| %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s |\n", col1_width, $1, col2_width, $2, col3_width, $3, col4_width, $4, col5_width, $5, col6_width, $6, col7_width, $7
  }'
  
  # Print the footer
  printf "+-%s-+-%s-+-%s-+-%s-+-%s-+-%s-+-%s-+\n" $(printf '%*s' $((col1_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col2_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col3_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col4_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col5_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col6_width + 2)) '' | tr ' ' '-') $(printf '%*s' $((col7_width + 2)) '' | tr ' ' '-')
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
elif [[ "$Environment" == "ASG-UAT-B2B" ]]; then
  asg="asg"  # Replace with the actual Auto Scaling Group name
  describe_asg_instances "$asg"
elif [[ "$Environment" == "ASG-UAT-A2A" ]]; then
  asg="asg-test"  # Replace with the actual Auto Scaling Group name
  describe_asg_instances "$asg"
elif [[ "$Environment" == "ASG-UAT-UI" ]]; then
  asg="asg-test"  # Replace with the actual Auto Scaling Group name
  describe_asg_instances "$asg"
else
  echo "Invalid environment specified."
  exit 1
fi
