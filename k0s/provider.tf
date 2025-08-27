terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc03"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_user             = var.proxmox_username
  pm_api_token_id     = var.proxmox_token_id
  pm_api_token_secret = var.proxmox_token
  pm_tls_insecure     = true
}