#!/usr/bin/env bash
su ec2-user
sudo yum apt update
sudo yum upgrade -y

# nginx
sudo yum install nginx -y
sudo systemctl start nginx
