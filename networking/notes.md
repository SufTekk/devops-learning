# Networking Notes

My notes from the CoderCo networking module, written up after applying the concepts in my [EC2 + NGINX + DNS project](README.md). Where possible, I've tied each concept back to something I actually configured or debugged.

---

## 1. IP addressing

An IP address identifies a device on a network so traffic can be delivered to it.

- **IPv4:** 32-bit, written as four octets (`18.132.243.56`). Roughly 4.3 billion addresses, which is why they're scarce and AWS charges for public ones.
- **IPv6:** 128-bit, written in hex (`fe80::4bf:d5ff:feb4:6e64`). Built to solve IPv4 exhaustion.

**Public vs private**

| Type | Reachable from | Example from my project |
|---|---|---|
| Public | The internet | `18.132.243.56`: my EC2 instance's public IPv4 |
| Private | Only inside its own network | `172.31.4.46`: the same instance inside my AWS VPC |

Private ranges (RFC 1918): `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.
My instance has *both*: AWS maps the public IP to the private one at the edge of the VPC.

**CIDR notation**
The number after the `/` says how many bits are fixed for the network part.
- `/32` = exactly one address. My SSH rule `148.252.147.22/32` allowed only my IP.
- `/24` = 256 addresses (e.g. `192.168.1.0/24`).
- `/0` = every address. `0.0.0.0/0` on my HTTP rule means "anyone on the internet".

**Link-local:** `fe80::` addresses only work on the local network segment. My `nslookup` showed my home router's DNS server on a `fe80::` address.

---

## 2. DNS

DNS translates human-readable names into IP addresses. It doesn't carry the web page itself; it just tells the browser *where* to send the request.

**How a lookup works**
1. Browser/OS checks its local cache.
2. If not cached, asks a **recursive resolver** (my router / ISP).
3. Resolver asks a **root server** → gets pointed to the `.uk` **TLD servers**.
4. TLD servers point to the domain's **authoritative nameservers** (Cloudflare, for my domain).
5. Cloudflare returns the record, and the resolver caches it for the TTL.

**Record types**

| Record | Maps | Used in my project? |
|---|---|---|
| A | Name → IPv4 | ✅ `nginx.sufyaanmoalim.co.uk → 18.132.243.56` |
| AAAA | Name → IPv6 | |
| CNAME | Name → another name (alias) | |
| MX | Domain → mail server | |
| TXT | Free text (verification, SPF) | |
| NS | Which nameservers are authoritative | Set by Cloudflare on purchase |

**Authoritative vs non-authoritative:** an authoritative answer comes directly from the domain's own nameserver. A non-authoritative answer comes from a resolver's cache, which is what `nslookup` showed me.

**TTL and propagation:** TTL is how long resolvers cache a record. "Propagation" is really just old cached answers expiring. This matters because if my EC2 IP changes, people may hit the old IP until the TTL runs out.

**Proxied vs DNS only (Cloudflare):** I used *DNS only* so the A record returns my real EC2 IP. *Proxied* would route traffic through Cloudflare first (adding caching, DDoS protection and easier HTTPS) but would hide the origin IP.

---

## 3. Routing

Routing is how packets find their way between networks, hop by hop.

- Every device has a **routing table**: "for this destination range, send traffic to this next hop".
- The **default gateway** (`0.0.0.0/0` route) is where traffic goes when no more specific route matches. At home, that's my router.
- My packets go laptop → home router → ISP → internet backbone → AWS edge → my VPC.

**In AWS**
- A **VPC** is my private network in AWS (`172.31.0.0/16` for the default VPC).
- A **subnet** is a slice of that range in one availability zone.
- The **route table** on a public subnet sends `0.0.0.0/0` to an **Internet Gateway**, which is what makes the instance reachable from the internet.
- Because EC2 Instance Connect worked, I knew routing to my instance was fine, which helped narrow down my port 80 issue.

`traceroute` (Linux) / `tracert` (Windows) shows each hop along the path.

---

## 4. Ports and protocols

An IP gets traffic to the right **machine**; a port gets it to the right **service** on that machine.

| Port | Protocol | Service |
|---|---|---|
| 22 | TCP | SSH: remote admin of my server |
| 53 | UDP/TCP | DNS |
| 80 | TCP | HTTP: what NGINX served |
| 443 | TCP | HTTPS: HTTP over TLS (not set up yet) |

**TCP vs UDP**

| | TCP | UDP |
|---|---|---|
| Connection | Yes, with a 3-way handshake (SYN → SYN-ACK → ACK) | No |
| Delivery | Guaranteed, ordered, retransmits | Best effort |
| Used for | Web, SSH, file transfer | DNS queries, streaming, gaming |

A server **listens** on a port. On Linux, `sudo ss -tlnp` shows which ports are listening and which process owns them (e.g. NGINX on `0.0.0.0:80`).

---

## 5. OSI and TCP/IP models

Models that split networking into layers, so problems can be isolated one layer at a time.

| OSI layer | TCP/IP layer | What happens | Example from my project |
|---|---|---|---|
| 7 Application | Application | The app's protocol | HTTP request to NGINX, DNS query |
| 6 Presentation | Application | Encoding / encryption | TLS (once HTTPS is added) |
| 5 Session | Application | Managing sessions | |
| 4 Transport | Transport | Ports, TCP/UDP | TCP port 80, port 22 |
| 3 Network | Internet | IP addressing, routing | `18.132.243.56`, route tables |
| 2 Data link | Network access | MAC addresses, local frames | Laptop ↔ home router over Wi-Fi |
| 1 Physical | Network access | Signals, cables, radio | Wi-Fi / fibre |

**Why it matters for troubleshooting:** my timeout problem was a **layer 4** issue (wrong port allowed), not a layer 7 issue (NGINX was fine). Knowing the layers stopped me from wasting time reconfiguring NGINX.

---

## 6. Firewalls and AWS security groups

A firewall decides which traffic is allowed in or out, based on rules (protocol, port, source/destination).

**Security groups (AWS)**
- Attached to an instance's network interface.
- **Allow rules only.** Anything not explicitly allowed is denied.
- **Stateful:** if inbound traffic is allowed, the reply is automatically allowed out.
- Sources can be CIDR ranges, other security groups or **AWS-managed prefix lists**. I used `com.amazonaws.eu-west-2.ec2-instance-connect` to allow browser-based SSH without opening port 22 to everyone.

**Network ACLs (NACLs)** sit at the subnet level, are **stateless** and support explicit deny rules.

**Timeout vs connection refused**

| Symptom | Usually means |
|---|---|
| **Timeout** | Packets are being silently dropped, typically by a firewall/security group |
| **Connection refused** | The host was reached, but nothing is listening on that port |

This distinction is what pointed me to the security group when my site timed out.

**Least privilege:** only open what's needed. In my setup, that's HTTP to the world and SSH to known sources only.

---

## 7. Useful troubleshooting commands

| Command | What it tells me |
|---|---|
| `ping <host>` | Is the host reachable? (ICMP. Note that EC2 blocks it unless the security group allows ICMP, so a failed ping doesn't always mean the host is down) |
| `traceroute` / `tracert` | The path and where it stops |
| `nslookup` / `dig <name>` | What a name resolves to |
| `curl -I <url>` | HTTP status and headers |
| `ss -tlnp` | Which ports are listening on the server |
| `systemctl status <service>` | Is the service running and enabled? |
| `ip addr` / `ipconfig` | The machine's own IP addresses |

**My approach, from the project:** troubleshoot **inside out**: service → host → network → DNS. Confirm each layer works before moving to the next.

---

## Still learning

- HTTPS/TLS in practice (certificates, Let's Encrypt)
- Subnetting maths for designing VPCs from scratch
- Load balancers and how they fit in front of multiple instances
- Defining all of this as code with Terraform
