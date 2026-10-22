# Lab: a complete tenant in one stack

Creates its own project with quotas (`project.create = true`, **admin credentials required**), a network and router, two security groups, and two instances with a data volume and a floating IP each. Instances are bootstrapped with `modules/cloudinit`.

Variables: `ssh_public_key`, `admin_cidr`.
