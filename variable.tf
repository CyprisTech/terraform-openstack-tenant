variable "auth_url" {
  description = "Authentication URL for OpenStack"
  type        = string
}

variable "user_name" {
  description = "OpenStack admin user"
  type        = string
}

variable "password" {
  description = "OpenStack admin password"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "OpenStack region"
  type        = string
}

variable "ssh_user" {
  description = "Tenant admin user for VM instances"
  type        = string
  default     = ""
}

variable "projects" {
  description = "List of OpenStack projects"
  type = list(object({
    name        = string
    description = string
    enabled     = bool
  }))
  default = []
}

variable "compute_aggregates" {
  description = "List of compute aggregates to create"
  type = list(object({
    name  = string
    zone  = string
    hosts = list(string)
  }))
  default = []
}

variable "quotas" {
  description = "Network, Compute and Storage quotas"
  type = list(object({
    project_name = string
    compute = optional(object({
      ram       = optional(number)
      cores     = optional(number)
      instances = optional(number)
    }))
    network = optional(object({
      floatingip          = optional(number)
      network             = optional(number)
      subnet              = optional(number)
      port                = optional(number)
      router              = optional(number)
      security_group      = optional(number)
      security_group_rule = optional(number)
      rbac_policy         = optional(number)
    }))
    volume = optional(object({
      volumes              = optional(number)
      snapshots            = optional(number)
      per_volume_gigabytes = optional(number)
      gigabytes            = optional(number)
      backups              = optional(number)
      backup_gigabytes     = optional(number)
    }))
  }))
  default = []
}

variable "users" {
  description = "List of users to create"
  type = list(object({
    name     = string
    password = string
    email    = string
    enabled  = string
  }))
  default = []
}

variable "user_project_roles" {
  description = "Mapping of users to projects and roles"
  type = list(object({
    user    = string
    project = string
    role    = string
  }))
  default = []
}


variable "project_zones" {
  description = "Zone to create into the project"
  type = list(object({
    name        = string
    email       = string
    description = string
    ttl         = number
  }))
  default = []
}


variable "images" {
  description = "Images to import into Glance"
  type = list(object({
    name             = string
    image_source_url = string
    container_format = string
    disk_format      = string
  }))
  default = []
}

variable "flavors" {
  description = "List of flavors to create"
  type = list(object({
    name  = string
    ram   = number
    vcpus = number
    disk  = number
  }))
  default = []
}

variable "security_groups" {
  description = "List of security groups to create"
  type = list(object({
    name        = string
    description = string
    rules = list(object({
      protocol         = optional(string)
      direction        = string
      ethertype        = string
      port_min         = optional(number)
      port_max         = optional(number)
      remote_ip_prefix = string
    }))
  }))
  default = []
}

variable "networks" {
  description = "List of networks, subnets, and routers"
  type = list(object({
    admin_state_up = bool
    name           = string
    mtu            = number
    physnet        = optional(string)
    type           = optional(string)
    az_hints       = list(string)
    external       = bool
    subnets = list(object({
      name        = string
      ip_version  = number
      cidr        = string
      nameservers = optional(list(string))
      gateway_ip  = optional(string)
      extra_routes = optional(list(object({
        to  = string
        via = string
      })))
      allocation_pools = optional(list(object({
        start = string
        end   = string
      })))
      routers = optional(list(object({
        name                    = string
        admin_state_up          = bool
        external_network_name   = string
        subnet_name             = string
        availability_zone_hints = list(string)
        ip_address              = string
        subnet_cidr_override    = optional(string)
        subnet_extra_route_to   = optional(string)
      })))
    }))
  }))
  default = [{
    name           = "private"
    mtu            = 1362
    az_hints       = ["site-a-az", "site-b-az"]
    external       = false
    admin_state_up = true
    subnets = [{
      name        = "private"
      ip_version  = 4
      cidr        = "10.20.5.0/24"
      nameservers = ["1.1.1.1"]
      gateway_ip  = "10.20.5.1"
      routers = [
        {
          name                    = "router-site_a_provider"
          admin_state_up          = true
          external_network_name   = "site_a_provider"
          subnet_name             = "site_a_provider"
          availability_zone_hints = ["site-a-az"]
          ip_address              = "10.20.5.10"
        },
        {
          name                    = "router-intranet_site_a"
          admin_state_up          = true
          external_network_name   = "intranet"
          subnet_name             = "intranet_site_a"
          subnet_extra_route_to   = "10.10.0.0/22"
          availability_zone_hints = ["site-a-az"]
          ip_address              = "10.20.5.11"
        },
        {
          name                    = "router-svc_public_site_a"
          admin_state_up          = true
          external_network_name   = "svc_public"
          subnet_name             = "svc_public_site_a"
          subnet_extra_route_to   = "10.10.4.0/22"
          availability_zone_hints = ["site-a-az"]
          ip_address              = "10.20.5.12"
        },
        {
          name                    = "router-site_b_provider"
          admin_state_up          = true
          external_network_name   = "site_b_provider"
          subnet_name             = "site_b_provider"
          availability_zone_hints = ["site-b-az"]
          ip_address              = "10.20.5.128"
        },
        {
          name                    = "router-intranet_site_b"
          admin_state_up          = true
          external_network_name   = "intranet"
          subnet_name             = "intranet_site_b"
          subnet_extra_route_to   = "10.10.0.0/22"
          availability_zone_hints = ["site-b-az"]
          ip_address              = "10.20.5.129"
        },
        {
          name                    = "router-svc_public_site_b"
          admin_state_up          = true
          external_network_name   = "svc_public"
          subnet_name             = "svc_public_site_b"
          subnet_extra_route_to   = "10.10.4.0/22"
          availability_zone_hints = ["site-b-az"]
          ip_address              = "10.20.5.130"
        }
      ]
    }]
  }]
}

variable "data" {
  description = "Data structure containing networks"
  type = object({
    networks = list(object({
      name    = string
      subnets = list(string)
    }))
    projects        = list(string)
    project_zones   = list(string)
    flavors         = list(string)
    security_groups = list(string)
  })
  default = {
    projects = []
    networks = [
      { name = "monitoring", subnets = ["monitoring"] },
      { name = "provisioning", subnets = ["provisioning"] },
      { name = "intranet", subnets = ["intranet_site_a"] },
      { name = "site_a_provider", subnets = ["site_a_provider"] },
      { name = "svc_public", subnets = ["svc_public_site_a"] }
    ],
    flavors = ["vcpu1_ram1G_nodisk",
      "vcpu2_ram2G_nodisk",
      "vcpu2_ram4G_nodisk",
      "vcpu4_ram4G_nodisk",
      "vcpu4_ram8G_nodisk"
    ],
    security_groups = ["intranet-https-ingress",
      "intranet-ssh-ingress",
      "intranet-smtps-ingress",
      "intranet-smtp-starttls-ingress",
      "intranet-imaps-ingress",
      "public-http-ingress",
      "public-https-ingress",
      "public-smtp-ingress",
      "admin-ssh-ingress",
      "allow-all-traffic"
    ]
    project_zones = []
  }
}

variable "dns_records" {
  description = "List of DNS records"
  type        = list(any)
  default     = []
}

variable "instances" {
  description = "List of instances configuration"
  type = list(object({
    name              = string
    az                = string
    flavor            = string
    enable_admin_port = bool
    ports = list(object({
      name                 = string
      network_name         = string
      subnet_name          = string
      security_group_names = list(string)
      fip_pool_name        = optional(string)
      fip_subnet_name      = optional(string)
      fip_dns_records = optional(list(object({
        name = string
        zone = string
      })))
    }))
    root_volume = object({
      name   = string
      size   = number
      az     = string
      image  = string
      create = bool
    })
    data_volumes = list(object({
      name       = string
      size       = number
      az         = string
      mountpoint = optional(string)
      username   = optional(string)
      uid        = optional(string)
      gid        = optional(string)
      create     = bool
    }))
    instance_labels = list(string)
    bind_mounts = optional(list(object({
      username           = string
      uid                = string
      gid                = string
      path               = string
      conf_src_file      = optional(string)
      conf_template_file = optional(string)
      template_vars      = optional(map(any))
    })))
    cloud_init = optional(object({
      runcmd   = optional(list(any))
      users    = optional(list(any))
      packages = optional(list(any))
    }))
  }))
  default = []
}

variable "haproxy" {
  description = "HAProxy configuration"
  type = list(object({
    name            = string
    az              = string
    vip_net_name    = string
    vip_subnet_name = string
    fip_pool_name   = string
    fip_subnet_name = string
    listeners = list(object({
      name             = string
      protocol         = string
      port             = number
      dns_record_names = optional(list(string))
      pool = object({
        protocol  = string
        lb_method = string
        monitor = object({
          type        = string
          delay       = number
          timeout     = number
          max_retries = number
        })
        instance_names = list(string)
      })
    }))
  }))
  default = []
}

variable "cloud_init_common" {
  description = "Common cloud init user data for tenant instances"
  type = object({
    runcmd   = optional(list(any))
    users    = optional(list(any))
    packages = optional(list(any))
  })

  default = {}
}

