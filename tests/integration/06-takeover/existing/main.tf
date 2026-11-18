# Stage 06, first half: objects created as by hand, with the plain provider resources and the
# defaults of the CLI: a router attached by subnet (Neutron creates the port), a security group
# with Neutron's default egress rules, an instance on a port created beforehand,
# a floating IP. takeover.sh then removes them from this state, so that the module takes them
# over with import blocks (stage 06 itself).

resource "openstack_networking_network_v2" "net" {
  name = "it06-net"
}

resource "openstack_networking_subnet_v2" "main" {
  name            = "it06-net-main"
  network_id      = openstack_networking_network_v2.net.id
  cidr            = "192.168.156.0/24"
  dns_nameservers = var.dns_nameservers
}

data "openstack_networking_network_v2" "ext" {
  name = var.external_network
}

resource "openstack_networking_router_v2" "out" {
  name                = "it06-net-out"
  external_network_id = data.openstack_networking_network_v2.ext.id
}

# As `openstack router add subnet`: the interface takes the subnet's gateway address.
resource "openstack_networking_router_interface_v2" "out" {
  router_id = openstack_networking_router_v2.out.id
  subnet_id = openstack_networking_subnet_v2.main.id
}

resource "openstack_networking_secgroup_v2" "ssh" {
  name        = "it06-ssh"
  description = ""
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  security_group_id = openstack_networking_secgroup_v2.ssh.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
}

# A group with several rules, taken over from a list generated from the API (takeover.sh).
resource "openstack_networking_secgroup_v2" "web" {
  name        = "it06-web"
  description = ""
}

resource "openstack_networking_secgroup_rule_v2" "web" {
  for_each          = toset(["80", "443", "8443"])
  security_group_id = openstack_networking_secgroup_v2.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = tonumber(each.key)
  port_range_max    = tonumber(each.key)
  remote_ip_prefix  = "0.0.0.0/0"
}

# As `openstack port create` then `openstack server create --port`. An instance attached by
# network (Nova creates the port) cannot be taken over without being replaced: the provider does
# not record the port of an imported instance (docs/takeover.md).
resource "openstack_networking_port_v2" "vm" {
  name               = "it06-vm-port"
  network_id         = openstack_networking_network_v2.net.id
  security_group_ids = [openstack_networking_secgroup_v2.ssh.id]

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.main.id
    ip_address = "192.168.156.20"
  }
}

resource "openstack_compute_instance_v2" "vm" {
  name              = "it06-vm"
  availability_zone = var.az
  flavor_name       = var.flavor
  image_name        = var.image

  network {
    port = openstack_networking_port_v2.vm.id
  }

  depends_on = [openstack_networking_router_interface_v2.out]
}

resource "openstack_networking_floatingip_v2" "vm" {
  pool = var.external_network
}

resource "openstack_networking_floatingip_associate_v2" "vm" {
  floating_ip = openstack_networking_floatingip_v2.vm.address
  port_id     = openstack_networking_port_v2.vm.id

  depends_on = [openstack_networking_router_interface_v2.out]
}

# The IDs stage 06 imports, read by takeover.sh.
output "ids" {
  value = {
    network          = openstack_networking_network_v2.net.id
    subnet           = openstack_networking_subnet_v2.main.id
    router           = openstack_networking_router_v2.out.id
    router_port      = openstack_networking_router_interface_v2.out.port_id
    security_group   = openstack_networking_secgroup_v2.ssh.id
    ssh_rule         = openstack_networking_secgroup_rule_v2.ssh.id
    web_group        = openstack_networking_secgroup_v2.web.id
    instance         = openstack_compute_instance_v2.vm.id
    instance_port    = openstack_networking_port_v2.vm.id
    floating_ip      = openstack_networking_floatingip_v2.vm.id
    floating_address = openstack_networking_floatingip_v2.vm.address
  }
}
