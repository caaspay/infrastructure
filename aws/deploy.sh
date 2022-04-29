#!/bin/bash

set -eo pipefail
if [ -f ".env" ]; then
  source .env
fi

profile=farm
aws_region=ap-southeast-1
templates_bucket=farm-cloudformation-templates

networking_stack_file=FarmNetworking.yml
networking_stack_name=FarmNetworking
networking_role=arn:aws:iam::189863663806:role/farm-networking-cf-role


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
*)
  echo "Unknown stack $stack_name"
  exit 1
  ;;
esac
