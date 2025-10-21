# oci-devops-demo

Demo of DevOps approach in OCI

# repo-structure

oci-devops-demo/
├── app/
│   ├── main.py
│   ├── requirements.txt
│   └── Dockerfile
├── k8s/
│   ├── manifest.yaml
├── bootstrap/
│   ├── main.tf
│   ├── provider.tf
│   └── variables.tf
├── terraform/
│   ├── oke.tf
│   ├── oke-network.tf
│   ├── oke-policies.tf
│   ├── oke-security-lists.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── provider.tf
│   └── backend.tf
│   ├── data.tf
└── .github/
    └── workflows/
        └── ci-cd.yml
        └── bootstrap-tfstate.yml
        └── deploy-terraform.yml
        └── destroy-terraform.yml

