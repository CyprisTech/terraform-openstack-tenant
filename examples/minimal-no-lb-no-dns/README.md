# Minimal tenant without load balancer or DNS

One network, one router to the external network, one instance with a floating IP. Works on clouds that do not offer Octavia or Designate, with a member role on the project.

Adapt `external`, `m1.small` and `ubuntu-24.04` to the names used by your cloud.
