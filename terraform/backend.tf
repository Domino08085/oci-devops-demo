terraform {
  backend "s3" {
    bucket                      = "tfstate-bucket"
    key                         = "envs/dev/terraform.tfstate"
    region                      = "eu-frankfurt-1"
    endpoint                    = "https://objectstorage.eu-frankfurt-1.oraclecloud.com"
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    force_path_style            = true
  }
}
