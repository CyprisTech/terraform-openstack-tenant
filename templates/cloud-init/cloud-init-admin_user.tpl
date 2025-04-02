#cloud-config

#network:
#  version: 2
#  ethernets:
#    ens3:
#      dhcp4: true
#      dhcp4-overrides:
#        use-routes: false
#    ens4:
#      dhcp4: true
#    ens5:
#      dhcp4: true
#      dhcp4-overrides:
#        use-routes: false
users:
  - name: ${ssh_admin_user}
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEXAMPLEKEYREPLACEDyyyyyyyyyyyyyyyyyyyyyyy ops@example.org
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEXAMPLEKEYREPLACEDxxxxxxxxxxxxxxxxxxxxxxx admin@example.org

