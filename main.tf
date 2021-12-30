# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}
provider "azurerm" {
  features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "testtaskgroup" {
    name     = "myResourceGroup"
    location = "westeurope"

    tags = {
        environment = "Test Task"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "trtesttasknetwork" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "westeurope"
    resource_group_name = azurerm_resource_group.testtaskgroup.name

    tags = {
        environment = "Test Task"
    }
}

# Create subnet
resource "azurerm_subnet" "trtesttasksubnet" {
    name                 = "testTaskSubnet"
    resource_group_name  = azurerm_resource_group.testtaskgroup.name
    virtual_network_name = azurerm_virtual_network.trtesttasknetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "trtesttaskpublicip" {
    name                         = "testTaskPublicIP"
    location                     = "westeurope"
    resource_group_name          = azurerm_resource_group.testtaskgroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Test Task"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "trtesttasknsg" {
    name                = "testTaskNetworkSecurityGroup"
    location            = "westeurope"
    resource_group_name = azurerm_resource_group.testtaskgroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Test Task"
    }
}

# Create network interface
resource "azurerm_network_interface" "trtesttasknic" {
    name                      = "myNIC"
    location                  = "westeurope"
    resource_group_name       = azurerm_resource_group.testtaskgroup.name

    ip_configuration {
        name                          = "testTaskNicConfiguraion"
        subnet_id                     = azurerm_subnet.trtesttasksubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.trtesttaskpublicip.id
    }

    tags = {
        environment = "Test Task"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.trtesttasknic.id
    network_security_group_id = azurerm_network_security_group.trtesttasknsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.testtaskgroup.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "testtaskstorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.testtaskgroup.name
    location                    = "westeurope"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Test Task"
    }
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { 
    value = tls_private_key.example_ssh.private_key_pem 
    sensitive = true
}
variable "instance_count" {
  default = "2"
}
# Create virtual machine
resource "azurerm_linux_virtual_machine" "trtesttaskvm" {
    name                  = "server-${count.index}"
    location              = "westeurope"
    resource_group_name   = azurerm_resource_group.testtaskgroup.name
    network_interface_ids = [azurerm_network_interface.trtesttasknic.id]
    size                  = "Standard_DS1_v2"
    count                 = "${var.instance_count}"

    os_disk {
        name              = "testTaskDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "testTaskVM"
    admin_username = "bohdanb"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "bohdanb"
        public_key     = tls_private_key.example_ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.testtaskstorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "Test Task"
    }
}