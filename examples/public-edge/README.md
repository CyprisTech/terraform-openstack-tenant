# Public edge

Two reverse proxies behind an Octavia load balancer in active/standby topology:

- port 443 in TCP passthrough with the **PROXY protocol**, so that backends see client addresses and terminate TLS themselves;
- port 80 in HTTP with an HTTP health check;
- a floating IP with DNS records at the zone apex and `www`.

Requires Octavia and Designate.
