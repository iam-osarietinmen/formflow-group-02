output "vm_public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.main.ip_address
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "network_security_group_name" {
  description = "Name of the Network Security Group"
  value       = azurerm_network_security_group.main.name
}

output "vm_name" {
  description = "Name of the virtual machine"
  value       = azurerm_linux_virtual_machine.main.name
}

output "admin_username" {
  description = "Admin username of the VM"
  value       = var.admin_username
}