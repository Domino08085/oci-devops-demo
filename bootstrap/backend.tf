terraform {
  backend "s3" {
    bucket                      = "tfstate-bucket"    
    key                         = "bootstrap/terraform.tfstate"
    region                      = "us-east-1"

    endpoints = {
      s3 = "https://objectstorage.eu-frankfurt-1.oraclecloud.com"
    }

    skip_credentials_validation = true
    skip_requesting_account_id  = true
    force_path_style            = true
  }
}
