#!/usr/bin/env bash
su ec2-user
sudo yum update
sudo yum upgrade -y

# nginx
sudo amazon-linux-extras install nginx1
sudo systemctl start nginx
