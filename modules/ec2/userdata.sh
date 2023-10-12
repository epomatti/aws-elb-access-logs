#!/usr/bin/env bash

relasever="2023.0.20230210"

dnf check-update --releasever=$relasever
dnf update --releasever=$relasever

# nginx
dnf install -y nginx

systemctl start nginx.service
systemctl status nginx.service
systemctl enable nginx.service
