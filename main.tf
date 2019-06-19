variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}

variable "web_rg" {}
variable "resource_prefix" {}
variable "web_server_name" {}
variable "app_server_name" {}
variable "environment" {}
variable "web_server_count" {}
variable "terraform_script_version" {}
variable "domain_name_label" {}
variable "domain_name_app_label" {}
variable "db_name" {}
variable "sql_admin_username" {}
variable "sql_password" {}
variable "db_location" {}
variable "jump_server_location" {}
variable "jump_server_prefix" {}
variable "jump_server_name" {}


provider "azurerm" {
  version         = "1.16"
  tenant_id       = "${var.tenant_id}"
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
}


module "resource_lam" {
  source = "./main"
  web_server_location = "westus"
  web_rg = "${var.web_rg}-usw"
  resource_prefix = "${var.resource_prefix}-usw"
  web_server_address_space = "10.55.0.0/22"
  web_server_name = "${var.web_server_name}"
  app_server_name = "${var.app_server_name}"
  environment = "${var.environment}"
  web_server_count = "${var.web_server_count}"
  web_server_subnets = ["10.55.1.0/24","10.55.2.0/24"]
  domain_name_label = "${var.domain_name_label}"
  domain_name_app_label = "${var.domain_name_app_label}"
  terraform_script_version = "${var.terraform_script_version}"
  db_location            = "${var.db_location}"
  db_name             = "${var.db_name}-usw"
  sql_admin_username  = "${var.sql_admin_username}"
  sql_password        = "${var.sql_password}"

  tags = {
    environment = "dev"
    costcenter  = "it"
    }  
}

module "resource_lamus2" {
  source = "./main"
  web_server_location = "westus2"
  web_rg = "${var.web_rg}-usw2"
  resource_prefix = "${var.resource_prefix}-usw2"
  web_server_address_space = "10.56.0.0/22"
  web_server_name = "${var.web_server_name}"
  app_server_name = "${var.app_server_name}"
  environment = "${var.environment}"
  web_server_count = "${var.web_server_count}"
  web_server_subnets = ["10.56.1.0/24","10.56.2.0/24"]
  domain_name_label = "${var.domain_name_label}"
  domain_name_app_label = "${var.domain_name_app_label}"
  terraform_script_version = "${var.terraform_script_version}"
  db_location         = "${var.db_location}2"
  db_name             = "${var.db_name}2"
  sql_admin_username  = "${var.sql_admin_username}"
  sql_password        = "${var.sql_password}"

  tags = {
  environment = "dev"
   costcenter  = "it"
   }
}


resource "azurerm_traffic_manager_profile" "traffic_manager" {
  name = "${var.resource_prefix}-traffic-manager"
  resource_group_name = "${module.resource_lam.web_rg_name}"
  traffic_routing_method = "Weighted"
  dns_config {
    relative_name = "${var.domain_name_label}"
    ttl = "100"
    
  }
  monitor_config {
    protocol = "http"
    port = "80"
    path = "/"
  }
}
resource "azurerm_traffic_manager_endpoint" "traffic_manager_usw" {
  name = "${var.resource_prefix}-usw-endpoint"
  resource_group_name = "${module.resource_lam.web_rg_name}"
  profile_name        = "${azurerm_traffic_manager_profile.traffic_manager.name}"
  target_resource_id  = "${module.resource_lam.web_server_lb_public_ip_id}"
  type                = "azureEndpoints"
  weight              = 100  
}


resource "azurerm_traffic_manager_endpoint" "traffic_manager_usw2" {
  name = "${var.resource_prefix}-usw2-endpoint"
  resource_group_name = "${module.resource_lam.web_rg_name}"
  profile_name        = "${azurerm_traffic_manager_profile.traffic_manager.name}"
  target_resource_id  = "${module.resource_lamus2.web_server_lb_public_ip_id}"
  type                = "azureEndpoints"
  weight              = 100
}

resource "azurerm_resource_group" "jump_server_rg" {
  name = "${var.jump_server_prefix}-rg"
  location = "${var.jump_server_location}"
}

resource "azurerm_virtual_network" "jump_server_vnet" {
  name = "${var.jump_server_prefix}-vnet"
  location = "${var.jump_server_location}"
  resource_group_name = "${azurerm_resource_group.jump_server_rg.name}"
  address_space  = ["10.33.0.0/24"]
}

resource "azurerm_subnet" "jump_server_subnet" {
  name = "${var.jump_server_prefix}-10.33.0.0-subnet"
  resource_group_name = "${azurerm_resource_group.jump_server_rg.name}"
  virtual_network_name = "${azurerm_virtual_network.jump_server_vnet.name}"
  address_prefix       = "10.33.0.0/24"  
}

resource "azurerm_virtual_network_peering" "jump_server_peer_web_usw" {
  name = "jump-euw-peer-web-usw"
  resource_group_name = "${azurerm_resource_group.jump_server_rg.name}"
  virtual_network_name = "${azurerm_virtual_network.jump_server_vnet.name}"
  remote_virtual_network_id = "${module.resource_lam.web_server_vnet_id}"
  allow_virtual_network_access = true
  depends_on             = ["azurerm_subnet.jump_server_subnet"]  
}


resource "azurerm_virtual_network_peering" "web_usw_peer_jump_server" {
  name = "web_usw_peer_jump_euw"
  resource_group_name = "${module.resource_lam.web_rg_name}"
  virtual_network_name = "${module.resource_lam.web_server_vnet_name}"
  remote_virtual_network_id = "${azurerm_virtual_network.jump_server_vnet.id}"
  allow_virtual_network_access = true
  depends_on             = ["azurerm_subnet.jump_server_subnet"]  
}


resource "azurerm_virtual_network_peering" "jump_server_peer_web_usw2" {
  name = "jump-euw-peer-web-usw2"
  resource_group_name = "${azurerm_resource_group.jump_server_rg.name}"
  virtual_network_name = "${azurerm_virtual_network.jump_server_vnet.name}"
  remote_virtual_network_id = "${module.resource_lamus2.web_server_vnet_id}"
  allow_virtual_network_access = true
  depends_on             = ["azurerm_subnet.jump_server_subnet"]  
}


resource "azurerm_virtual_network_peering" "web_usw2_peer_jump_server" {
  name = "web_usw2_peer_jump_euw"
  resource_group_name = "${module.resource_lamus2.web_rg_name}"
  virtual_network_name = "${module.resource_lamus2.web_server_vnet_name}"
  remote_virtual_network_id = "${azurerm_virtual_network.jump_server_vnet.id}"
  allow_virtual_network_access = true
  depends_on             = ["azurerm_subnet.jump_server_subnet"]  
}
resource "azurerm_network_interface" "jump_server_nic" {
  name                      = "${var.jump_server_name}-nic"
  location                  = "${var.jump_server_location}"
  resource_group_name       = "${azurerm_resource_group.jump_server_rg.name}"
  network_security_group_id = "${azurerm_network_security_group.jump_server_nsg.id}"

  ip_configuration {
    name                          = "${var.jump_server_name}-ip"
    subnet_id                     = "${azurerm_subnet.jump_server_subnet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.jump_server_public_ip.id}"
  }
}

resource "azurerm_public_ip" "jump_server_public_ip" {
  name                         = "${var.jump_server_name}-public-ip"
  location                     = "${var.jump_server_location}"
  resource_group_name          = "${azurerm_resource_group.jump_server_rg.name}"
  public_ip_address_allocation = "${var.environment == "production" ? "static" : "dynamic"}"
}

resource "azurerm_network_security_group" "jump_server_nsg" {
  name                = "${var.jump_server_name}-nsg"
  location            = "${var.jump_server_location}"
  resource_group_name = "${azurerm_resource_group.jump_server_rg.name}" 
}

resource "azurerm_network_security_rule" "jump_server_nsg_rule_ssh" {
        name                       = "SSH Inbound"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
		resource_group_name         = "${azurerm_resource_group.jump_server_rg.name}" 
		network_security_group_name = "${azurerm_network_security_group.jump_server_nsg.name}" 
}

resource "azurerm_virtual_machine" "jump_server" {
  name                         = "${var.jump_server_name}"
  location                     = "${var.jump_server_location}"
  resource_group_name          = "${azurerm_resource_group.jump_server_rg.name}"  
  network_interface_ids        = ["${azurerm_network_interface.jump_server_nic.id}"]
  vm_size                      = "Standard_DS1_v2"

  storage_image_reference {
	   publisher = "Canonical"
	   offer     = "UbuntuServer"
	   sku       = "16.04-LTS"
	   version   = "latest"
  }

  storage_os_disk {
	   name              = "jumpbox-osdisk"
	   caching           = "ReadWrite"
	   create_option     = "FromImage"
	   managed_disk_type = "Standard_LRS"
  }
  
  os_profile {
    computer_name      = "${var.jump_server_name}" 
    admin_username     = "jumpserver"
    admin_password     = "Passw0rd1234"
  }

 os_profile_linux_config {
   disable_password_authentication = false
 }
}