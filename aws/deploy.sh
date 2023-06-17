#!/bin/bash

set -eo pipefail
if [ -f ".env" ]; then
  source .env
fi

profile=farm
aws_region=us-east-2
templates_bucket=${aws_region}-farm-cloudformation-templates
config_bucket=${aws_region}-farm-config-scripts

networking_stack_file=FarmNetworking.yml
networking_stack_name=FarmNetworking
networking_role=arn:aws:iam::189863663806:role/farm-networking-cf-role

rds_stack_file=FarmDataStore.yml
rds_stack_name=FarmRDS
rds_role=arn:aws:iam::189863663806:role/farming-cf-role

servers_stack_file=FarmServers.yml
servers_stack_name=FarmServers
servers_role=arn:aws:iam::189863663806:role/farming-cf-role

echo "Setting AWS profile to: $profile"
export AWS_PROFILE=$profile

if [ $# -lt 1 ]; then

  echo "Usage $0 stackName"

  exit 1
fi

stack_name=$1

case $stack_name in
"networking")
  aws --region $aws_region cloudformation deploy \
    --stack-name $networking_stack_name \
    --template-file "$networking_stack_file" \
    --s3-bucket "$templates_bucket" \
    --s3-prefix "$networking_stack_name" \
    --role-arn "$networking_role" \
    --capabilities CAPABILITY_IAM \
    --profile $profile \
    --force-upload
  ;;
"datastore")
  aws --region $aws_region cloudformation deploy \
    --stack-name $rds_stack_name \
    --template-file "$rds_stack_file" \
    --s3-bucket "$templates_bucket" \
    --s3-prefix "$rds_stack_name" \
    --role-arn "$rds_role" \
    --parameter-override NetworkingStack=$networking_stack_name \
    --profile $profile \
    --force-upload
  ;;
"servers")
  # Deploy config
  config_bucket_exists=$(aws s3 ls "s3://$config_bucket" || echo 'error' 2>&1)
  if echo "${config_bucket_exists}" | grep -q 'error'
  then
    echo "Creating config S3 bucket"
    aws s3api create-bucket --region $aws_region --bucket $config_bucket --acl private --profile $profile --create-bucket-configuration LocationConstraint=$aws_region --object-ownership BucketOwnerEnforced
  fi
  aws s3 cp  --recursive ./files/ "s3://$config_bucket/" 
  # Deploy the stack
  aws --region $aws_region cloudformation deploy \
    --stack-name $servers_stack_name \
    --template-file "$servers_stack_file" \
    --s3-bucket "$templates_bucket" \
    --s3-prefix "$servers_stack_name" \
    --role-arn "$servers_role" \
    --parameter-override NetworkingStack=$networking_stack_name \
    PublicServerUD="$(base64 -b 0 -i ./public-server-init.yml)" \
    InternalServerUD="$(base64 -b 0 -i ./private-server-init.yml)" \
    ConfigBucket=$config_bucket \
    RDSStack=$rds_stack_name \
    K3sServerUD="$(base64 -b 0 -i ./k3s-master-init.yml)" \
    K3sWorkerUD="$(base64 -b 0 -i ./k3s-worker-init.yml)" \
    --capabilities CAPABILITY_IAM \
    --profile $profile \
    --force-upload
  ;;
*)
  echo "Unknown stack $stack_name"
  exit 1
  ;;
esac
