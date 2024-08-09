#!/bin/bash

INSTANCE_TYPE="t2.micro"
AMI="ami-04a81a99f5ec58529"
REGION="us-east-1"
AWS_ACCOUNT_ID=`aws sts get-caller-identity --query 'Account' --output text`
ROLE_ARN="AmazonSSMRoleForInstancesQuickSetup"
INSTANCE_NAME='setup-db'

RDS=$(terraform output -raw rds| sed 's/:.*//')
echo "RDS: $RDS"

if [[ -z $RDS ]]; then
    echo "Failed to get RDS from terraform output"
    exit
fi

INSTANCE_ID=$(aws ec2 describe-instances \
    --region $REGION \
    --filters "Name=tag:Name,Values=$INSTANCE_NAME" \
    "Name=instance-state-name,Values=pending,running,shutting-down,stopping,stopped" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text)

if [[ -z "$INSTANCE_ID" ]]; then
  echo "Going to create a temp EC2 instance"
  INSTANCE_ID=`aws ec2 run-instances \
    --image-id $AMI \
    --instance-type $INSTANCE_TYPE \
    --iam-instance-profile Name=$ROLE_NAME \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value='$INSTANCE_NAME'}]' \
    --query 'Instances[0].InstanceId' --output text`
else
    echo "Using instance id $INSTANCE_ID to open connection to database"
fi

echo "Wait for instance to become available"
aws ec2 wait instance-running --instance-ids $INSTANCE_ID
sleep 60

echo "Start port forwarding to access remote RDS database"

set -x

aws ssm start-session --target $INSTANCE_ID \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters host="$RDS",portNumber="5432",localPortNumber="5432" &
pid=$!
sleep 6

echo "Creating database"
psql 'postgresql://dbadmin:adminpassword@localhost:5432/tenantdb' -f setup-db.sql
kill $pid

echo "Terminating temp EC2 instance"
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
