# Assignment 1: VPC & Networking, working notes

Notes taken while building the assignment on 22 November 2026, in the London region (eu-west-2). These feed into the README.

---

## What I built

| Resource | Name | Details |
|---|---|---|
| VPC | `sufyaan-vpc` | `10.0.0.0/16` |
| Public subnet | `public-subnet-a` | `10.0.1.0/24`, eu-west-2a, auto-assign public IPv4 **on** |
| Private subnet | `private-subnet-a` | `10.0.2.0/24`, eu-west-2a, auto-assign public IPv4 **off** |
| Internet Gateway | `sufyaan-igw` | Attached to `sufyaan-vpc` |
| Elastic IP | `sufyaan-nat-eip` | `3.11.89.237`, used by the NAT Gateway |
| NAT Gateway | `sufyaan-nat` | In `public-subnet-a`, public connectivity |
| Public route table | `public-rt` | `0.0.0.0/0 → sufyaan-igw`, associated with `public-subnet-a` |
| Private route table | `private-rt` | `0.0.0.0/0 → sufyaan-nat`, associated with `private-subnet-a` |
| Public EC2 SG | `public-ec2-sg` | SSH + HTTP from my IP only |
| Private EC2 SG | `private-ec2-sg` | SSH only from `public-ec2-sg` (security group reference) |
| Public EC2 | `public-ec2` | `10.0.1.135`, public IP, Apache via user data |
| Private EC2 | `private-ec2` | `10.0.2.141`, no public IP |

Both route tables also have the automatic `10.0.0.0/16 → local` route, which lets everything inside the VPC talk to each other.

---

## Order I built it in

1. Secured the account: MFA on root, MFA on my IAM admin user, and day-to-day work as the IAM user instead of root
2. Created the VPC with **"VPC only"** (not "VPC and more"), so I built each piece myself
3. Created the public and private subnets, and enabled auto-assign public IP on the public one only
4. Created and attached the Internet Gateway
5. Allocated an Elastic IP and created the NAT Gateway **in the public subnet**
6. Created the public and private route tables, added the default routes and associated the subnets
7. Created the security groups before launching any instances
8. Launched the public EC2 (with Apache user data) and the private EC2 (no public IP)
9. Tested everything (see below)
10. Cleaned up the paid resources

---

## Testing

| Test | Command / action | Result |
|---|---|---|
| Public EC2 serves a web page | `http://18.133.226.95` in a browser | ✅ Page loaded (after fixing the security group, see Issue 1) |
| SSH to the public EC2 | `ssh -A ec2-user@18.133.226.95` from my laptop | ✅ Prompt `ec2-user@ip-10-0-1-135` |
| SSH from public to private EC2 | `ssh ec2-user@10.0.2.141` from the public EC2 | ✅ Prompt `ec2-user@ip-10-0-2-141` |
| Private EC2 can reach the internet | `curl -s https://checkip.amazonaws.com` on the private EC2 | ✅ Returned `3.11.89.237`, the NAT Gateway's Elastic IP |

The last test proves the NAT is working: the private server went out to the internet using the NAT's address, while its own private IP stayed hidden.

I used **SSH agent forwarding** (`ssh-agent`, `ssh-add`, `ssh -A`) to jump from the public EC2 to the private one, so the private key never had to be copied onto a server.

---

## Issues and how I solved them

### Issue 1: The public EC2 timed out in the browser

**Symptom:** `http://<public IP>` gave "took too long to respond".

**Investigation (layer by layer):**

| Check | Result |
|---|---|
| Instance in the right VPC? | ✅ `sufyaan-vpc` (at first I checked my old NGINX instance by mistake, which is in the default VPC) |
| Public route table has `0.0.0.0/0 → IGW`? | ✅ Yes, Active |
| `public-subnet-a` associated with `public-rt`? | ✅ Yes |
| Instance's security group? | ❌ **The VPC's `default` SG** (`sg-0405...`), not `public-ec2-sg` |

**Root cause:** the instance launched with the VPC's default security group. A default SG only allows inbound traffic from other members of the same group, so my browser was silently dropped, which caused the timeout.

**Fix:** EC2 → Actions → Security → Change security groups. I removed `default` and added `public-ec2-sg`. The page loaded straight away, with no relaunch needed.

**Lesson:** on the launch page, choose "Select existing security group" and check the Summary panel before launching. A timeout means traffic is being dropped, so check the routing and security groups first.

### Issue 2: Couldn't find the instance by name

The new instance had no Name tag, so it didn't show up when I searched for "public-ec2". I identified it by its AZ (eu-west-2a) and by the missing public DNS name (custom VPCs have DNS hostnames turned off by default), then added the Name tag.

### Issue 3: Running laptop commands on the server

After SSHing into the public EC2, I ran commands meant for my laptop (`cd ~/Downloads`, `ssh-add`). They failed because the key file isn't on the server. I also typed the `10.0.2.x` placeholder instead of the real IP.

**Lesson:** always check the prompt before typing:

| Prompt | Machine |
|---|---|
| `moali@DESKTOP... MINGW64` | My laptop |
| `ec2-user@ip-10-0-1-...` | Public EC2 |
| `ec2-user@ip-10-0-2-...` | Private EC2 |

### Issue 4: The Elastic IP wouldn't release during clean-up

**Error:** "Cannot be released with association IDs".

**Cause:** the Elastic IP was still attached to the NAT Gateway's network interface. Even after the NAT showed "Deleted", AWS took a few more minutes to clean up the interface.

**Fix:** waited a few minutes, refreshed, and released it.

**Lesson:** delete in the right order: the NAT Gateway first, then wait until it's fully gone, then release the Elastic IP.

---

## Key concepts I now understand

- **What makes a subnet public:** a route table with `0.0.0.0/0` pointing to an **Internet Gateway**. Auto-assigning public IPs alone isn't enough.
- **NAT Gateway:** lets private instances reach out (e.g. for updates) while blocking inbound connections. It must sit in a **public** subnet.
- **Security group references:** `private-ec2-sg` allows SSH from `public-ec2-sg`, not from an IP, so it keeps working if IPs change, and nothing else can get in.
- **Default security group:** only allows traffic from itself, so it isn't suitable for anything that needs to be reached from outside.
- **A `/24` subnet:** 256 addresses, with 5 reserved by AWS, so 251 usable.
- **Cost:** NAT Gateways and Elastic IPs are billed by the hour, so I deleted them as soon as testing was done.

---

## Clean-up

- ✅ NAT Gateway deleted
- ✅ Elastic IP released
- ✅ `public-ec2` and `private-ec2` terminated
- Kept (free): VPC, subnets, IGW, route tables and security groups, which I'm reusing for Assignment 2. The private route table's NAT route now shows as "Blackhole", which is expected.

---

## Screenshots

| File | Shows |
|---|---|
| `00-root-mfa-enabled.png` | Root MFA enabled (IAM dashboard) |
| `00-iam-admin-user.png` | IAM admin user with MFA |
| `a1-01-vpc-created.png` | VPC `10.0.0.0/16` |
| `a1-02-subnets.png` | Both subnets, CIDRs and AZs |
| `a1-03-igw-attached.png` | Internet Gateway attached |
| `a1-04-nat-gateway.png` | NAT Gateway available in the public subnet |
| `a1-05-public-route-table.png` | `0.0.0.0/0 → igw` |
| `a1-05b-public-rt-association.png` | `public-subnet-a` associated |
| `a1-06-private-route-table.png` | `0.0.0.0/0 → nat` |
| `a1-07-public-ec2-sg.png` | Public SG rules |
| `a1-08-private-ec2-sg.png` | Private SG, SSH from the public SG |
| `a1-09-public-ec2-security.png` | Instance using `public-ec2-sg` after the fix |
| `a1-10-public-ec2-browser.png` | Web page from the public EC2 |
| `a1-11-private-ec2-networking.png` | Private EC2: private IP only |
| `a1-12-ssh-public-ec2.png` | SSH into the public EC2 |
| `a1-13-ssh-private-ec2.png` | Jump to the private EC2 |
| `a1-14-private-ec2-via-nat.png` | `curl` shows the NAT's IP |
| `a1-15-nat-elastic-ip.png` | The Elastic IP matching the curl output |

Before pushing: blur my home IP and the AWS account ID, and never commit the `.pem` key.
