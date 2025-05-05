////////////////////////////////////////////////////////////////////////////////////////
//                            TERRAFORM PROVIDERS & BACKEND
////////////////////////////////////////////////////////////////////////////////////////
terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 2.38"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

terraform {
  backend "s3" {
    region                      = "main"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_region_validation      = true
    use_path_style              = true
    key                         = "infrastructure/perfnet-1/terraform.tfstate"
  }
}

provider "linode" {
  token = var.linode_api_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

////////////////////////////////////////////////////////////////////////////////////////
//                                        VARIABLES
////////////////////////////////////////////////////////////////////////////////////////
variable "linode_api_token" {
  type        = string
  sensitive   = true
  description = "Linode API Token"
}

variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API Token"
}

variable "ethereum_network" {
  type    = string
  default = "perfnet-1"
}

variable "base_cidr_block" {
  default = "10.76.0.0/16"
}
////////////////////////////////////////////////////////////////////////////////////////
//                                        LOCALS
////////////////////////////////////////////////////////////////////////////////////////
locals {
  vm_groups = [
    var.bootnode,
    var.lighthouse_geth,
    var.lighthouse_nethermind,
    var.lighthouse_erigon,
    var.lighthouse_besu,
    var.lighthouse_ethereumjs,
    var.lighthouse_reth,
    var.lighthouse_nimbusel,
    var.prysm_geth,
    var.prysm_nethermind,
    var.prysm_erigon,
    var.prysm_besu,
    var.prysm_ethereumjs,
    var.prysm_reth,
    var.prysm_nimbusel,
    var.lodestar_geth,
    var.lodestar_nethermind,
    var.lodestar_erigon,
    var.lodestar_besu,
    var.lodestar_ethereumjs,
    var.lodestar_reth,
    var.lodestar_nimbusel,
    var.nimbus_geth,
    var.nimbus_nethermind,
    var.nimbus_erigon,
    var.nimbus_besu,
    var.nimbus_ethereumjs,
    var.nimbus_reth,
    var.nimbus_nimbusel,
    var.teku_geth,
    var.teku_nethermind,
    var.teku_erigon,
    var.teku_besu,
    var.teku_ethereumjs,
    var.teku_reth,
    var.teku_nimbusel,
    var.grandine_geth,
    var.grandine_nethermind,
    var.grandine_erigon,
    var.grandine_besu,
    var.grandine_ethereumjs,
    var.grandine_reth,
    var.grandine_nimbusel,
  ]
}
