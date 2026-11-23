#!/bin/bash
# User data for web-server-b (eu-west-2b).
# Runs once on first boot: installs Apache, starts it on every boot,
# and writes a page that identifies this server.
yum install -y httpd
systemctl enable --now httpd
echo "<h1>Hello from SERVER B</h1><p>Availability Zone: eu-west-2b</p><p>Host: $(hostname -f)</p>" > /var/www/html/index.html
