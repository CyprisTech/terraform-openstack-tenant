# Adopting existing objects

A tenant that relies on objects owned by others:

- the transit network and a monitoring security group are adopted **by ID** (for example outputs of the cloud baseline);
- the management network and baseline security groups are adopted **by name**;
- a DNS zone owned by the project and a zone **shared** by the administrator;
- an instance that boots from an existing root volume and attaches an existing data volume created and protected outside the module.

Runs with a member role on the project.
