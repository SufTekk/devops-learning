# Commands Used

## On the EC2 server (Ubuntu 26.04)

### Check the environment

| Command | What it does |
|---|---|
| `whoami` | Shows the logged-in user (`ubuntu`) |
| `cat /etc/os-release` | Shows the Linux distribution and version |
| `clear` | Clears the terminal screen |

### Install and run NGINX

| Command | What it does |
|---|---|
| `sudo apt update` | Refreshes the list of available packages |
| `sudo apt install -y nginx` | Installs NGINX (`-y` auto-confirms) |
| `sudo systemctl enable --now nginx` | Starts NGINX now **and** on every boot |
| `systemctl status nginx` | Shows whether NGINX is loaded, enabled and running (`q` to exit) |

### Test the web server

| Command | What it does |
|---|---|
| `curl -I http://localhost` | Requests only the HTTP headers. `200 OK` means NGINX is serving |
| `sudo ufw status` | Checks whether Ubuntu's firewall is active |

## On my laptop (Windows)

| Command | What it does |
|---|---|
| `nslookup nginx.sufyaanmoalim.co.uk` | Checks which IP the domain resolves to |
| `ipconfig /flushdns` | Clears the local DNS cache if a lookup is stale |

## Example outputs

```text
$ curl -I http://localhost
HTTP/1.1 200 OK
Server: nginx/1.28.3 (Ubuntu)
Content-Type: text/html
Content-Length: 615
```

```text
> nslookup nginx.sufyaanmoalim.co.uk
Non-authoritative answer:
Name:    nginx.sufyaanmoalim.co.uk
Address: 18.132.243.56
```
