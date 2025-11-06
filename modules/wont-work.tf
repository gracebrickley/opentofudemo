terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    kind = {
      source  = "tehcyx/kind"
      version = "0.9.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}

provider "kind" {}

module "kind_cluster" {
  source = "./kind-cluster"
}

#########################
# THIS WON'T WORK
#########################
provider "kubernetes" {
  host                   = module.kind_cluster.cluster_endpoint
  client_certificate     = module.kind_cluster.client_certificate
  client_key             = module.kind_cluster.client_key
  cluster_ca_certificate = module.kind_cluster.cluster_ca_certificate
}

module "team_a" {
  source       = "./team-a"
  environment  = "production"
  project_name = "team-a"
}