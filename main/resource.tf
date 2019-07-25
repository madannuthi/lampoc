variable "web_server_location" {}

variable "web_rg" {}
variable "resource_prefix" {}
variable "web_server_address_space" {}
variable "web_server_name" {}
variable "app_server_name" {}
variable "environment" {}
variable "web_server_count" {}
variable "web_server_subnets" {
  type = "list"
}
variable "terraform_script_version" {}
variable "domain_name_label" {}
variable "domain_name_app_label" {}

variable "db_location" {}



variable "server_version" {
  default     = "12.0"
}
variable "db_name" {
  description = "The name of the database to be created."
}
variable "db_edition" {
  default     = "Basic"
}
variable "service_objective_name" {
  description = "The performance level for the database. For the list of acceptable values, see https://docs.microsoft.com/en-gb/azure/sql-database/sql-database-service-tiers. Default is Basic."
  default     = "Basic"
}
variable "collation" {
  description = "The collation for the database. Default is SQL_Latin1_General_CP1_CI_AS"
  default     = "SQL_Latin1_General_CP1_CI_AS"
}
variable "sql_admin_username" {
  description = "The administrator username of the SQL Server."
}
variable "sql_password" {
  description = "The administrator password of the SQL Server."
}
variable "start_ip_address" {
  description = "Defines the start IP address used in your database firewall rule."
  default     = "0.0.0.0"
}
variable "end_ip_address" {
  description = "Defines the end IP address used in your database firewall rule."
  default     = "0.0.0.0"
}
variable "tags" {
  description = "The tags to associate with your network and subnets."
  type        = "map"

  default = {
    tag1 = ""
    tag2 = ""
  }
}
variable "application_port" {
   description = "The port that you want to expose to the external load balancer"
   default     = 80
}


locals {
  web_server_name   = "${var.environment == "production" ? "${var.web_server_name}-prd" : "${var.web_server_name}"}"
  app_server_name   = "${var.environment == "production" ? "${var.app_server_name}-prd" : "${var.app_server_name}"}"
  build_environment = "${var.environment == "production" ? "production" : "development"}"
}

resource "azurerm_resource_group" "web_rg" {
  name     = "${var.web_rg}"
  location = "${var.web_server_location}"

tags {
  environment   = "${local.build_environment}"
  build-version = "${var.terraform_script_version}"
  }
}

resource "azurerm_virtual_network" "web_server_vnet" {
  name                = "${var.resource_prefix}-vnet"
  location            = "${var.web_server_location}"
  resource_group_name = "${azurerm_resource_group.web_rg.name}"
  address_space       = ["${var.web_server_address_space}"]
}

resource "azurerm_subnet" "web_server_subnet" {
  name                      = "${var.resource_prefix}-${substr(var.web_server_subnets[count.index], 0, length(var.web_server_subnets[count.index]) - 3)}-subnet"
  resource_group_name       = "${azurerm_resource_group.web_rg.name}"
  virtual_network_name      = "${azurerm_virtual_network.web_server_vnet.name}"
  address_prefix            = "${var.web_server_subnets[count.index]}"
  network_security_group_id = "${count.index == 0 ? "${azurerm_network_security_group.web_server_nsg.id}" : ""}"
  count                     = "${length(var.web_server_subnets)}"
}

resource "azurerm_public_ip" "web_server_lb_public_ip" {
  name                         = "${var.resource_prefix}-public-ip"
  location                     = "${var.web_server_location}"
  resource_group_name          = "${azurerm_resource_group.web_rg.name}"
  public_ip_address_allocation = "${var.environment == "production" ? "static" : "dynamic"}"
  domain_name_label            = "${var.domain_name_label}"
}

resource "azurerm_public_ip" "app_server_lb_public_ip" {
  name                         = "${var.resource_prefix}-app-public-ip"
  location                     = "${var.web_server_location}"
  resource_group_name          = "${azurerm_resource_group.web_rg.name}"
  public_ip_address_allocation = "${var.environment == "production" ? "static" : "dynamic"}"
  domain_name_label            = "${var.domain_name_app_label}"
}

resource "azurerm_network_security_group" "web_server_nsg" {
  name                = "${var.resource_prefix}-nsg"
  location            = "${var.web_server_location}"
  resource_group_name = "${azurerm_resource_group.web_rg.name}" 
}

resource "azurerm_network_security_rule" "web_server_nsg_rule_http" {
  name                        = "HTTP Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.web_rg.name}" 
  network_security_group_name = "${azurerm_network_security_group.web_server_nsg.name}" 
}

resource "azurerm_virtual_machine_scale_set" "web_server" {
  name                         = "${var.resource_prefix}"
  location                     = "${var.web_server_location}"
  resource_group_name          = "${azurerm_resource_group.web_rg.name}"  
  upgrade_policy_mode          = "Manual"

  sku {
    name     = "Standard_B1s"
    tier     = "Standard"
    capacity = "${var.web_server_count}"
  }

  storage_profile_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter-Server-Core-smalldisk"
    version   = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  
  os_profile {
    computer_name_prefix = "${local.web_server_name}" 
    admin_username       = "webserver"
    admin_password       = "Passw0rd1234"
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }

  network_profile {
    name    = "web_server_network_profile"
    primary = true

    ip_configuration {
      name                                   = "${local.web_server_name}" 
      primary                                = true
      subnet_id                              = "${azurerm_subnet.web_server_subnet.*.id[0]}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.web_server_lb_backend_pool.id}"]
    }
  }

  extension {
    name                 = "${local.web_server_name}-extension" 
    publisher            = "Microsoft.Compute"
    type                 = "CustomScriptExtension"
    type_handler_version = "1.9"

    settings = <<SETTINGS
    {
      "fileUris": ["https://raw.githubusercontent.com/eltimmo/learning/master/azureInstallWebServer.ps1"],
      "commandToExecute": "start powershell -ExecutionPolicy Unrestricted -File azureInstallWebServer.ps1"
    }
    SETTINGS

  }

}

resource "azurerm_virtual_machine_scale_set" "app_server" {
 name                         = "${var.resource_prefix}-app"
 location                     = "${var.web_server_location}"
 resource_group_name          = "${azurerm_resource_group.web_rg.name}"  
 upgrade_policy_mode          = "Manual"

 sku {
   name     = "Standard_DS1_v2"
   tier     = "Standard"
   capacity = 2
 }

 storage_profile_image_reference {
   publisher = "Canonical"
   offer     = "UbuntuServer"
   sku       = "16.04-LTS"
   version   = "latest"
 }

 storage_profile_os_disk {
   name              = ""
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 storage_profile_data_disk {
   lun          = 0
   caching        = "ReadWrite"
   create_option  = "Empty"
   disk_size_gb   = 10
 }

 os_profile {
   computer_name_prefix = "${local.app_server_name}"
   admin_username       = "appserver"
   admin_password       = "Passw0rd1234"
   custom_data          = "${file("web.conf")}"
 }

 os_profile_linux_config {
   disable_password_authentication = false
 }

 network_profile {
   name    = "terraformnetworkprofile"
   primary = true

   ip_configuration {
     name                                   = "IPConfiguration"
     subnet_id                              = "${azurerm_subnet.web_server_subnet.*.id[0]}"
     load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.app_server_lb_backend_pool.id}"]
     primary = true
   }
 }
 extension {
    name                 = "${local.app_server_name}-extension"
    publisher            = "Microsoft.OSTCExtensions"
    type                 = "CustomScript"
    type_handler_version = "2.0"
     
    "protectedSettings": {
       "commandToExecute": "bash install.sh",
       "script": "install.sh",
       "storageAccountName": "madannuthi",
       "storageAccountKey": "rajisai9",
       "fileUris": ["https://github.com/madannuthi/lampoc/blob/master/install.sh"]  
    }
  }
}

resource "azurerm_lb" "web_server_lb" {
  name                = "${var.resource_prefix}-lb"
  location            = "${var.web_server_location}"
  resource_group_name = "${azurerm_resource_group.web_rg.name}" 

  frontend_ip_configuration {
     name                 = "${var.resource_prefix}-lb-frontend-ip"
     public_ip_address_id = "${azurerm_public_ip.web_server_lb_public_ip.id}"
  }  
}

resource "azurerm_lb_backend_address_pool" "web_server_lb_backend_pool" {
  name                = "${var.resource_prefix}-lb-backend-pool"
  resource_group_name = "${azurerm_resource_group.web_rg.name}" 
  loadbalancer_id     = "${azurerm_lb.web_server_lb.id}"
}

resource "azurerm_lb_probe" "web_server_lb_http_probe" {
  name                = "${var.resource_prefix}-lb-http-probe"
  resource_group_name = "${azurerm_resource_group.web_rg.name}" 
  loadbalancer_id     = "${azurerm_lb.web_server_lb.id}" 
  protocol            = "tcp" 
  port                = "${var.application_port}"
}

resource "azurerm_lb_rule" "web_server_lb_http_rule" {
  name                           = "${var.resource_prefix}-lb-http-rule"
  resource_group_name            = "${azurerm_resource_group.web_rg.name}" 
  loadbalancer_id                = "${azurerm_lb.web_server_lb.id}" 
  protocol                       = "tcp"  
  frontend_port                  = "80" 
  backend_port                   = "80"
  frontend_ip_configuration_name = "${var.resource_prefix}-lb-frontend-ip"
  probe_id                       = "${azurerm_lb_probe.web_server_lb_http_probe.id}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.web_server_lb_backend_pool.id}"
}

######## Load Balancer for Linux VMs ################
resource "azurerm_lb" "applcation_lb" {
 name                = "${var.resource_prefix}-app-lb"
 location            = "${var.web_server_location}"
 resource_group_name = "${azurerm_resource_group.web_rg.name}"

 frontend_ip_configuration {
   name                 = "${var.resource_prefix}-app-lb-frontend-ip"
   public_ip_address_id = "${azurerm_public_ip.app_server_lb_public_ip.id}"
 }

}

resource "azurerm_lb_backend_address_pool" "app_server_lb_backend_pool" {
 name                = "${var.resource_prefix}-app-lb-backend-pool"
 resource_group_name = "${azurerm_resource_group.web_rg.name}"
 loadbalancer_id     = "${azurerm_lb.applcation_lb.id}"
}

resource "azurerm_lb_probe" "app_server_lb_backend_probe" {
 name                = "${var.resource_prefix}-lb-app-probe"
 resource_group_name = "${azurerm_resource_group.web_rg.name}"
 loadbalancer_id     = "${azurerm_lb.applcation_lb.id}"
 port                = "${var.application_port}"
 protocol            = "tcp"
}

resource "azurerm_lb_rule" "app_server_lb_http_rule" {
   name                           = "${var.resource_prefix}-app-lb-http-rule"
   resource_group_name = "${azurerm_resource_group.web_rg.name}"
   loadbalancer_id     = "${azurerm_lb.applcation_lb.id}"
   protocol                       = "Tcp"
   frontend_port                  = "${var.application_port}"
   backend_port                   = "${var.application_port}"
   backend_address_pool_id        = "${azurerm_lb_backend_address_pool.app_server_lb_backend_pool.id}"
   frontend_ip_configuration_name = "${var.resource_prefix}-app-lb-frontend-ip"
   probe_id                       = "${azurerm_lb_probe.app_server_lb_backend_probe.id}"
}

resource "azurerm_sql_database" "db" {
  name                             = "${var.resource_prefix}-mysql-db"
  location            			   = "${var.db_location}"
  resource_group_name              = "${azurerm_resource_group.web_rg.name}"
  edition                          = "${var.db_edition}"
  collation                        = "${var.collation}"
  server_name                      = "${azurerm_sql_server.server.name}"
  create_mode                      = "Default"
  requested_service_objective_name = "${var.service_objective_name}"
  tags                             = "${var.tags}"
}

resource "azurerm_sql_server" "server" {
  name                         = "${var.resource_prefix}-mysqlsvr"
  location                     = "${var.db_location}"
  resource_group_name          = "${azurerm_resource_group.web_rg.name}"
  version                      = "${var.server_version}"
  administrator_login          = "${var.sql_admin_username}"
  administrator_login_password = "${var.sql_password}"
  tags                         = "${var.tags}"
}

resource "azurerm_sql_firewall_rule" "fw" {
  name                = "${var.resource_prefix}-mysql-fwrules"
  resource_group_name = "${azurerm_resource_group.web_rg.name}"
  server_name         = "${azurerm_sql_server.server.name}"
  start_ip_address    = "${var.start_ip_address}"
  end_ip_address      = "${var.end_ip_address}"
}
