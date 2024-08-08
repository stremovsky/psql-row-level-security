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

echo "Wait for insance to becove available"
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

echo "Start port forwarding to access remote RDS database"
aws ssm start-session --target $INSTANCE_ID \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters host="$RDS",portNumber="5432",localPortNumber="5432" &
sleep 10

echo "Creating database"
psql 'postgresql://dbadmin:adminpassword@localhost:5432/tenantdb' -f setup-db.sql

# aws_cognito_user_pool.user_pool.arn

echo "Terminate temp EC2 instance"
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

