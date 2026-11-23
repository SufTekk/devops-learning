#!/bin/bash
# User data for web-server-a (eu-west-2a).
# Runs once on first boot: installs Apache, starts it on every boot,
# and writes a page that identifies this server.
yum install -y httpd
systemctl enable --now httpd
echo "<h1>Hello from SERVER A</h1><p>Availability Zone: eu-west-2a</p><p>Host: $(hostname -f)</p>" > /var/www/html/index.html
