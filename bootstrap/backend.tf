terraform {
  backend "oci" {
    bucket         = "tfstate-bucket"
    namespace      = "frxdvqsyd4jy"
    compartment_id = "ocid1.compartment.oc1..aaaaaaaahjpyn7ffagxkqpybbrckq7ysmyir65mmybxk7zkpkb6cevjuwm4q"
    region         = "eu-frankfurt-1"
  }
}