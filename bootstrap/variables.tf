variable "region" {}
variable "tenancy_ocid" {}
variable "compartment_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}


#move terraform .tfstate to OCI
# export AWS_ACCESS_KEY_ID="<tenancy_namespace>/<username>"   # np. myns/jan.kowalski@firma.pl
# export AWS_SECRET_ACCESS_KEY="<OCI Auth Token>"              # wygenerowany token
# export AWS_DEFAULT_REGION="eu-frankfurt-1"

#change backend and migrate state
# terraform init -migrate-state
# terraform state list  
# terraform plan           
