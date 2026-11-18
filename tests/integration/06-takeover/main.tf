# Stage 06 — taking over objects created by hand (see docs/takeover.md).
# takeover.sh first creates them with existing/ (the plain provider resources, as the CLI
# would), forgets them there, and writes their IDs to ids.auto.tfvars.json. This stage
# describes the same objects with the composite and imports them.
# Checks: the plan imports every object and creates or destroys nothing; the plan after apply
# is empty; destroy removes everything.

variable "web_rules" {
  description = "Rules of the group it06-web, generated from the API by takeover.sh: key => ID and attributes."
  type = map(object({
    id               = string
    protocol         = string
    port             = number
    remote_ip_prefix = string
  }))
}

variable "ids" {
  description = "IDs of the objects to take over, written by takeover.sh."
  type        = map(string)
}

module "tenant" {
  source = "../../.."

  tenant = {
    existing = {
      networks = { ext = { name = var.external_network } }
    }

    networks = {
      it06-net = {
        subnets = { main = { cidr = "192.168.156.0/24", dns_nameservers = var.dns_nameservers } }
        routers = { out = { external_network = "ext", internal_subnet = "main" } }
      }
    }

    security_groups = {
      # Described from the generated list: one rule per entry, keyed like the import below.
      it06-web = {
        rules = { for k, r in var.web_rules : k => {
          direction = "ingress", protocol = r.protocol, port_min = r.port, port_max = r.port, remote_ip_prefix = r.remote_ip_prefix
        } }
      }
      it06-ssh = {
        rules = { ssh = { direction = "ingress", protocol = "tcp", port_min = 22, port_max = 22, remote_ip_prefix = "0.0.0.0/0" } }
      }
    }

    instances = {
      it06-vm = {
        az     = var.az
        flavor = var.flavor
        image  = var.image
        ports = {
          main = {
            network         = "it06-net"
            subnet          = "main"
            fixed_ip        = "192.168.156.20" # the current address: without it, the port would get a new one
            security_groups = ["it06-ssh"]
            floating_ip     = { pool = "ext" }
          }
        }
      }
    }
  }
}

import {
  to = module.tenant.module.network["it06-net"].openstack_networking_network_v2.this
  id = var.ids.network
}

import {
  to = module.tenant.module.network["it06-net"].openstack_networking_subnet_v2.this["main"]
  id = var.ids.subnet
}

import {
  to = module.tenant.module.network["it06-net"].openstack_networking_router_v2.this["out"]
  id = var.ids.router
}

# The port Neutron created when the router was attached by subnet.
import {
  to = module.tenant.module.network["it06-net"].openstack_networking_port_v2.router["out"]
  id = var.ids.router_port
}

import {
  to = module.tenant.module.network["it06-net"].openstack_networking_router_interface_v2.this["out"]
  id = var.ids.router_port
}

import {
  to = module.tenant.module.security_group["it06-ssh"].openstack_networking_secgroup_v2.this
  id = var.ids.security_group
}

import {
  to = module.tenant.module.security_group["it06-ssh"].openstack_networking_secgroup_rule_v2.this["ssh"]
  id = var.ids.ssh_rule
}

# The port created before the instance.
import {
  to = module.tenant.module.instance["it06-vm"].openstack_networking_port_v2.this["main"]
  id = var.ids.instance_port
}

import {
  to = module.tenant.module.instance["it06-vm"].openstack_compute_instance_v2.this
  id = var.ids.instance
}

import {
  to = module.tenant.module.instance["it06-vm"].openstack_networking_floatingip_v2.this["main"]
  id = var.ids.floating_ip
}

import {
  to = module.tenant.module.instance["it06-vm"].openstack_networking_floatingip_associate_v2.this["main"]
  id = var.ids.floating_ip
}

# At scale: one import block for every rule of the generated list.
import {
  to = module.tenant.module.security_group["it06-web"].openstack_networking_secgroup_v2.this
  id = var.ids.web_group
}

import {
  for_each = var.web_rules
  to       = module.tenant.module.security_group["it06-web"].openstack_networking_secgroup_rule_v2.this[each.key]
  id       = each.value.id
}
