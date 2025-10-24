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
├── tools/
│   ├── analyze_security.py
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
├── terraform-monitoring/
│   ├── backend.tf
│   ├── monitoring.tf
│   ├── provider.tf
│   ├── variables.tf
└── .github/
    └── workflows/
        └── ci-cd.yml
        └── bootstrap-tfstate.yml
        └── deploy-terraform.yml
        └── destroy-terraform.yml
        └── security.yml
└── .gitignore
└── .trivyignore
└── checkov.yml
└── trivy.yaml

