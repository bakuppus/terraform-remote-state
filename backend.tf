##################################################################################
## Sample Backend Config
##################################################################################

#terraform {
#  backend "s3" {
#    bucket = "360alumni-global-tfbackend-24025"
#    key    = "development/container/ecr-remote-state/terraform.tfstate"
#    region = "us-east-1"
#    dynamodb_table = "360alumni-global-tfstatelock-24025"
#    encrypt = true
#    profile = "infrasharedservices-aws-account"
#  }
#}
