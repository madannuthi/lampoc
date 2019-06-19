output "jumpbox_public_ip" {
   value = "${azurerm_public_ip.jump_server_public_ip.id}"
}