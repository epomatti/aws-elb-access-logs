#!/usr/bin/env bash

relasever="2023.0.20230210"

dnf check-update --releasever=$relasever
dnf update --releasever=$relasever

# nginx
amazon-linux-extras install nginx1
sudo dnf install -y nginx

sudo systemctl start nginx.service
sudo systemctl status nginx.service
sudo systemctl enable nginx.service
