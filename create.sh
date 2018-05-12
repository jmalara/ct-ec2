#!/bin/bash

# Cheap random number for stack name
RANDO=$(awk -v min=1000 -v max=9999 'BEGIN{srand(); print int(min+rand()*(max-min+1))}')

# Checking for AWS CLI
command -v aws >/dev/null 2>&1 || { echo >&2 "ERROR: AWS CLI was not found. Please install or ensure that it's in your PATH."; exit 1; }

# Check for access
aws iam get-user | grep 'error' &> /dev/null
if [ $? == 0 ]; then
   echo "ERROR: Your default AWS profile doesn't have the correct permissions. Make sure you have an account with the Administrator role and you've run aws configure."
   exit 1
fi

echo "Building cloudformation stack..."
# Deploy stack
aws cloudformation create-stack --region us-west-2 --stack-name ct-stack-$RANDO --template-body file://cf/consumertrak.template &> /dev/null
sleep 5s
# This is a hack but it works for this manual scenario
# This stack takes about 200 seconds to build so lets wait for that then keep trying to get the lb DNS
echo "Waiting for stack to complete..."
x=8
while [ $x -gt 0 ]
do
    sleep 30s
    echo "Waiting for stack to complete..."
    x=$(( $x - 1 ))
done

# OK Stack should be ready now, lets try and get that lb DNS
x=20
while [ $x -gt 0 ]
do
    aws cloudformation --region us-west-2 describe-stacks --stack-name ct-stack-$RANDO  | grep 'CREATE_COMPLETE' &> /dev/null
    if [ $? == 0 ]; then
        # OK Stack is finally complete
        URL=$(aws cloudformation --region us-west-2 describe-stacks --stack-name ct-stack-$RANDO | grep 'OutputValue' |  sed "s/\"//g" | sed "s/,//g" |  awk '{print "http://"$2}')
        printf "\\nYou can access the website at the URL below\\n"
        echo "$URL"
        exit 0
    fi
    sleep 5s
    x=$(( $x - 1 ))
done

echo "There was an error creating the stack, oops"
exit 1
