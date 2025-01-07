# GENERAL
region              = "North Europe"
resource_group_name = "rg-poc-paloalto"
tags = {
  "CreatedBy"   = "Palo Alto Networks"
  "CreatedWith" = "Terraform"
}

# NETWORK

vnets = {
  "hub" = {
    name          = "hub"
    address_space = ["10.100.0.0/25"]
    network_security_groups = {
      "management" = {
        name = "mgmt-nsg"
        rules = {
          mgmt_inbound = {
            name                       = "vmseries-management-allow-inbound"
            priority                   = 100
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_address_prefixes    = ["92.157.208.39/32"] # TODO: Whitelist IP addresses that will be used to manage the appliances
            source_port_range          = "*"
            destination_address_prefix = "*"
            destination_port_ranges    = ["22", "443"]
          }
        }
      }
      "public" = {
        name = "public-nsg"
      }
    }
    route_tables = {
      "management" = {
        name = "mgmt-rt"
        routes = {
          "public_blackhole" = {
            name           = "public-blackhole-udr"
            address_prefix = "10.100.0.80/28"
            next_hop_type  = "None"
          }
          "private_blackhole" = {
            name           = "private-blackhole-udr"
            address_prefix = "10.100.0.96/28"
            next_hop_type  = "None"
          }
        }
      }
      "public" = {
        name = "public-rt"
        routes = {
          "mgmt_blackhole" = {
            name           = "mgmt-blackhole-udr"
            address_prefix = "10.100.0.64/28"
            next_hop_type  = "None"
          }
          "private_blackhole" = {
            name           = "private-blackhole-udr"
            address_prefix = "10.100.0.96/28"
            next_hop_type  = "None"
          }
        }
      }
      "private" = {
        name = "private-rt"
        routes = {
          "default" = {
            name                = "default-udr"
            address_prefix      = "0.0.0.0/0"
            next_hop_type       = "VirtualAppliance"
            next_hop_ip_address = "10.100.0.100"
          }
          "mgmt_blackhole" = {
            name           = "mgmt-blackhole-udr"
            address_prefix = "10.100.0.64/28"
            next_hop_type  = "None"
          }
          "public_blackhole" = {
            name           = "public-blackhole-udr"
            address_prefix = "10.100.0.80/28"
            next_hop_type  = "None"
          }
        }
      }
    }
    subnets = {
      "gateway" = {
        name             = "GatewaySubnet"
        address_prefixes = ["10.100.0.0/26"]
      }
      "management" = {
        name                            = "mgmt-snet"
        address_prefixes                = ["10.100.0.64/28"]
        network_security_group_key      = "management"
        route_table_key                 = "management"
        enable_storage_service_endpoint = true
      }
      "public" = {
        name                       = "public-snet"
        address_prefixes           = ["10.100.0.80/28"]
        network_security_group_key = "public"
        route_table_key            = "public"
      }
      "private" = {
        name             = "private-snet"
        address_prefixes = ["10.100.0.96/28"]
        route_table_key  = "private"
      }
    }
  }
  "spoke1" = {
    name          = "spoke1"
    address_space = ["10.100.10.0/24"]
    subnets = {
      "default" = {
        name             = "default"
        address_prefixes = ["10.100.10.0/25"]
        route_table_key  = "spoke1-rt"
      }
    }
    route_tables = {
      "spoke1-rt" = {
        name = "spoke1-rt"
        routes = {
          "default" = {
            name                = "default-udr"
            address_prefix      = "0.0.0.0/0"
            next_hop_type       = "VirtualAppliance"
            next_hop_ip_address = "10.100.0.100"
          }
        }
      }
    }
  }
  "spoke2" = {
    name          = "spoke2"
    address_space = ["10.100.11.0/24"]
    subnets = {
      "default" = {
        name             = "default"
        address_prefixes = ["10.100.11.0/25"]
        route_table_key  = "spoke2-rt"
      }
    }
    route_tables = {
      "spoke2-rt" = {
        name = "spoke2-rt"
        routes = {
          "default" = {
            name                = "default-udr"
            address_prefix      = "0.0.0.0/0"
            next_hop_type       = "VirtualAppliance"
            next_hop_ip_address = "10.100.0.100"
          }
        }
      }
    }
  }  
}

vnet_peerings = {
  /* Uncomment the section below to peer Transit VNET with Panorama VNET (if you have one)
  "vmseries-to-panorama" = {
    local_vnet_name            = "example-transit"
    remote_vnet_name           = "example-panorama-vnet"
    remote_resource_group_name = "example-panorama"
  }
  */
  hub_to_spoke1 = {
    local_vnet_name  = "hub"
    remote_vnet_name = "spoke1"
  }
  hub_to_spoke2 = {
        local_vnet_name  = "hub"
        remote_vnet_name = "spoke2"
  }
}

# LOAD BALANCING

load_balancers = {
  "public" = {
    name = "public-lb"
    nsg_auto_rules_settings = {
      nsg_vnet_key = "hub"
      nsg_key      = "public"
      source_ips   = ["92.157.208.39/32"] # TODO: Whitelist public IP addresses that will be used to access LB
    }
    frontend_ips = {
      "app1" = {
        name             = "app1"
        public_ip_name   = "public-lb-app1-pip"
        create_public_ip = true
        in_rules = {
          "balanceHttp" = {
            name     = "HTTP"
            protocol = "Tcp"
            port     = 80
          }
        }
      }
    }
  }
  "private" = {
    name     = "private-lb"
    vnet_key = "hub"
    frontend_ips = {
      "ha-ports" = {
        name               = "private-vmseries"
        subnet_key         = "private"
        private_ip_address = "10.100.0.100"
        in_rules = {
          HA_PORTS = {
            name     = "HA-ports"
            port     = 0
            protocol = "All"
          }
        }
      }
    }
  }
}

natgws = {
    "natgw" = {
      name        = "natgw"
      vnet_key    = "hub"
      subnet_keys = ["public"]
      public_ip = {
        create = true
        name   = "natgw-pip"
      }
    }
  }


# VM-SERIES

ngfw_metrics = {
  name = "ngfw-log-analytics-wrksp"
}

/* Uncomment the section below to create a Storage Account for full bootstrap if you intend to use this bootstrap method */
bootstrap_storages = {
  "bootstrap" = {
    name = "fwbtstrppocvmi" # TODO: Change the Storage Account name to be globally unique
    storage_network_security = {
      vnet_key            = "hub"
      allowed_subnet_keys = ["management"]
      allowed_public_ips  = ["92.157.208.0/24"] # TODO: Whitelist public IP addresses that will be used to access storage account
    }
  }
}


scale_sets = {
  common = {
    name     = "common-vmss"
    vnet_key = "hub"
    image = {
      version = "10.2.1009"
    }
    authentication = {
      disable_password_authentication = false
    }
    virtual_machine_scale_set = {
      size  = "Standard_D3_v2"
      zones = ["1", "2", "3"]

      # This example uses basic user-data bootstrap method by default, comment out the map below if you want to use another one
    #   bootstrap_options = {
    #     type = "dhcp-client"
    #   }

      /* Uncomment the section below to use Panorama Software Firewall License (sw_fw_license) plugin bootstrap and fill out missing data
      bootstrap_options = {
        type               = "dhcp-client"
        plugin-op-commands = "panorama-licensing-mode-on"
        panorama-server    = "" # TODO: Insert Panorama IP address from sw_fw_license plugin
        tplname            = "" # TODO: Insert Panorama Template Stack name from sw_fw_license plugin
        dgname             = "" # TODO: Insert Panorama Device Group name from sw_fw_license plugin
        auth-key           = "" # TODO: Insert authentication key from sw_fw_license plugin
      }
      */

      /* Uncomment the section below to use Strata Cloud Manager (SCM) bootstrap and fill out missing data (PAN-OS version 11.0 or higher)
      bootstrap_options = {
        type                                  = "dhcp-client"
        plugin-op-commands                    = "advance-routing:enable"
        panorama-server                       = "cloud"
        tplname                               = "" # TODO: Insert SCM device label name 
        dgname                                = "" # TODO: Insert SCM Folder name
        vm-series-auto-registration-pin-id    = "" # TODO: Insert Device Certificate Registration PIN ID from Support Portal
        vm-series-auto-registration-pin-value = "" # TODO: Insert Device Certificate Registration PIN value from Support Portal
        authcodes                             = "" # TODO: Insert license authorization code from Support Portal
      }
      */

      /* Uncomment the section below to use full bootstrap from Storage Account, make sure to uncomment `bootstrap_storages` section too */
      bootstrap_package = {
        bootstrap_storage_key  = "bootstrap"
        static_files           = { "files/init-cfg.txt" = "config/init-cfg.txt" } # TODO: Modify the map key to reflect a path to init-cfg file
        bootstrap_xml_template = "templates/bootstrap_common.tmpl"                # TODO: Insert a path to bootstrap template file
        private_snet_key       = "private"
        public_snet_key        = "public"
        intranet_cidr          = "10.0.0.0/8"
      }
      

    }
    autoscaling_configuration = {
      default_count = 2
    }
    interfaces = [
      {
        name             = "management"
        subnet_key       = "management"
        create_public_ip = true
      },
      {
        name                    = "public"
        subnet_key              = "public"
        load_balancer_key       = "public"
        application_gateway_key = "public"
        create_public_ip        = true
      },
      {
        name              = "private"
        subnet_key        = "private"
        load_balancer_key = "private"
      }
    ]
    autoscaling_profiles = [
      {
        name          = "default_profile"
        default_count = 2
      },
      {
        name          = "weekday_profile"
        default_count = 2
        minimum_count = 2
        maximum_count = 4
        recurrence = {
          days       = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
          start_time = "07:30"
          end_time   = "17:00"
        }
        scale_rules = [
          {
            name = "DataPlaneCPUUtilizationPct"
            scale_out_config = {
              threshold                  = 70
              grain_window_minutes       = 5
              aggregation_window_minutes = 30
              cooldown_window_minutes    = 60
            }
            scale_in_config = {
              threshold               = 40
              cooldown_window_minutes = 120
            }
          },
        ]
      },
    ]
  }
}

