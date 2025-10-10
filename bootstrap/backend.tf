terraform {
  backend "oci" {
    bucket         = "tfstate-bucket"
    namespace      = "frxdvqsyd4jy"
    region         = "eu-frankfurt-1"
  }
}