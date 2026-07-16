variable "metallb_version" {
  description = "Version du chart Helm MetalLB"
  type        = string
  default     = "0.14.9"
}

variable "vlan_subinterfaces" {
  description = "Subinterfaces VLAN — génère un IPAddressPool + L2Advertisement par entrée"
  type = list(object({
    name    = string
    vlan_id = number
    ip      = string  # CIDR ex: "10.0.1.200/24"
  }))
}
