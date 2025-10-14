# oci-devops-demo

Demo of DevOps approach in OCI

# repo-structure

oci-devops-demo/
├── app/
│   ├── main.py
│   ├── requirements.txt
│   └── Dockerfile
├── k8s/
│   ├── deployment.yaml
│   └── service.yaml
├── bootstrap/
│   ├── main.tf
│   ├── provider.tf
│   └── variables.tf
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── provider.tf
│   └── backend.tf
└── .github/
    └── workflows/
        └── ci-cd.yml
        └── bootstrap-tfstate.yml
        └── deploy-terraform.yml
        └── destroy-terraform.yml

