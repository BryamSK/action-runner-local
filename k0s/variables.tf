variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type      = string
  sensitive = true
}
variable "proxmox_username" {
  description = "Proxmox API username"  
  type      = string
  sensitive = true
}
variable "proxmox_token_id" {
  description = "Proxmox API token ID"
  type      = string
  sensitive = true
}
variable "proxmox_token" {
  description = "Proxmox API token secret"
  type      = string
  sensitive = true
}
variable "storage_pool" {
  description = "Storage pool for VM disks"
  type        = string
}
variable "vm_user" {
  description = "SSH user for cloned template"
  type        = string
}
variable "vm_private_key_path" {
  description = "Path to private SSH key for provisioning"
  type        = string
}
variable "node" {
  description = "Proxmox node where VMs will be created"
  type        = string
}
variable "nodes" {
  description = "List of VM node names"
  type        = list(string)
}
variable "gw" {
  description = "Gateway IP address"
  type        = string
}
variable "ips_master" {
  description = "List of IP addresses for k0smasters"
  type        = list(string)
}
variable "ips_nodes" {
  description = "List of IP addresses for k0snodos"
  type        = list(string)
}
variable "gitrepo" {
  description = "Git repository for the action runners"
  type        = string
}