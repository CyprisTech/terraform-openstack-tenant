# Taking over existing objects

Two ways to work with objects that exist before the module:

| | Adoption | Takeover |
|---|---|---|
| What | The module references an object it does not manage | The module manages an object created by hand or by another tool |
| How | `existing` in the model, by ID or name ([tenant model](tenant-model.md#existing)) | `import` blocks, then the object is described in the model like any other |
| Objects | networks and subnets, security groups, DNS zones, volumes | networks, subnets, routers and their interfaces, ports, security groups and rules, floating IPs, DNS records; instances with a replacement (below) |
| On `destroy` | the object stays | the object is deleted |

Adopt what belongs to someone else (the cloud operator, another stack); take over what this stack should own from now on.

## Procedure

1. **Describe the objects in the model** as they are: same names, same address ranges, same rules. The module names objects after their keys (`<network>`, `<network>-<subnet>`, `<network>-<router>`, `<instance>-<port>`): a different current name is renamed in place.
2. **Add one `import` block per object**, in the root configuration that calls the module. The address is the module's resource for the key you chose:

| Object | Address (module called `tenant`) | Import ID |
|---|---|---|
| network | `module.tenant.module.network["<net>"].openstack_networking_network_v2.this` | network ID |
| subnet | `module.tenant.module.network["<net>"].openstack_networking_subnet_v2.this["<subnet>"]` | subnet ID |
| router | `module.tenant.module.network["<net>"].openstack_networking_router_v2.this["<router>"]` | router ID |
| router port | `module.tenant.module.network["<net>"].openstack_networking_port_v2.router["<router>"]` | ID of the router's port on the subnet |
| router interface | `module.tenant.module.network["<net>"].openstack_networking_router_interface_v2.this["<router>"]` | the same port ID |
| security group | `module.tenant.module.security_group["<group>"].openstack_networking_secgroup_v2.this` | group ID |
| security group rule | `module.tenant.module.security_group["<group>"].openstack_networking_secgroup_rule_v2.this["<rule>"]` | rule ID |
| instance port | `module.tenant.module.instance["<vm>"].openstack_networking_port_v2.this["<port>"]` | port ID |
| instance | `module.tenant.module.instance["<vm>"].openstack_compute_instance_v2.this` | instance ID |
| floating IP | `module.tenant.module.instance["<vm>"].openstack_networking_floatingip_v2.this["<port>"]` | floating IP ID |
| floating IP association | `module.tenant.module.instance["<vm>"].openstack_networking_floatingip_associate_v2.this["<port>"]` | floating IP ID |

   ```hcl
   import {
     to = module.tenant.module.network["app"].openstack_networking_network_v2.this
     id = "6b1f..."
   }
   ```
3. **Read the plan before applying.** It must import every object and create or destroy nothing, except where this guide says so. An update in place (a name, a description) is expected; a replacement means the model does not match the object: correct the model, not the object.
4. **Apply, then plan again**: the plan must be empty. Remove the `import` blocks afterwards, or keep them: they do nothing once the objects are in the state.

## What to watch

| Object | What happens | What to do |
|---|---|---|
| Router attached by subnet (`openstack router add subnet`) | Neutron created a port holding the subnet's gateway address; the module attaches routers through a port | Import that port and the interface with the port's ID; the port is renamed in place |
| Port with an address | Without `fixed_ip` in the model, the port would get a new address | Set `fixed_ip` to the current address |
| Security group | Neutron's default egress rules are not in the model | They stay, unmanaged; declare them in the model to manage them |
| Instance | **Replaced.** The provider does not record the port of an imported instance, and a change of port replaces an instance, even when the instance was created on that port | Keep the data on volumes (`boot.source = "existing"`, `volumes.*.existing`), or leave the instance out of the module |
| Instance attached by network (`openstack server create --network`) | Nova created the port; it can be imported like any port | Import it as the instance port, with its current `fixed_ip` |
| Floating IP | Its description becomes `<instance>-<port>` | Expected, in place |

## Tested

Stage [`06-takeover`](../tests/integration/README.md) creates these objects as the CLI would (a router attached by subnet, a port, an instance on it, a floating IP), forgets them, takes them over with the module, checks that the plan after apply is empty, then destroys everything.
