#!/bin/sh
#Calculate project suffix based on context for uniqueness
hash_acc=`gcloud config get-value account | sha256sum`
hash_date=`date | sha256sum`
project_suffix="${hash_acc:0:6}${hash_date:0:6}"

#Define global variables
ROOT_NODE='""'
BILLING_ACCOUNT='""'
PROJECT_KMS_NAME='"kms-project-'${project_suffix}'"'
PROJECT_SERVICE_NAME='"service-project-'${project_suffix}'"'
VAR_FILENAME=testing

#Loop over all possible flags that can be entered (each char corresponds to a global variable in order defined above)
while getopts ':r:b:k:s:f:' flag; do
    case $flag in
    r) ROOT_NODE="\"$OPTARG"\" ;;
    b) BILLING_ACCOUNT="\"$OPTARG"\" ;;
    k) PROJECT_KMS_NAME="\"$OPTARG"\" ;;
    s) PROJECT_SERVICE_NAME="\"$OPTARG"\" ;;
    f) VAR_FILENAME=$OPTARG ;;
    *) echo 'Error: Entered flag is not supported yet' >&2
       exit 1
    esac
done

#If other arguments are entered then take the previous one as final one
shift "$(( OPTIND - 1))"  

#Print variables for debugging
echo "Root Node is ${ROOT_NODE}"
echo "Billing Account is ${BILLING_ACCOUNT}"
echo "KMS Project is ${PROJECT_KMS_NAME}"
echo "Service Project is ${PROJECT_SERVICE_NAME}"

#Append global variables to a new .tfvars file 
cat /dev/null > ${VAR_FILENAME}.tfvars

echo "root_node = ${ROOT_NODE}" >> ${VAR_FILENAME}.tfvars
echo "billing_account = ${BILLING_ACCOUNT}" >> ${VAR_FILENAME}.tfvars
echo "project_kms_name = ${PROJECT_KMS_NAME}" >> ${VAR_FILENAME}.tfvars
echo "project_service_name = ${PROJECT_SERVICE_NAME}" >> ${VAR_FILENAME}.tfvars


terraform init 

terraform apply -var-file=${VAR_FILENAME}.tfvars --auto-approve