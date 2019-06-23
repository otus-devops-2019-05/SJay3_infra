#!/bin/bash
# Run this script with sudo
echo "Install MongoDB"
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
sudo bash -c 'echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.2.list'
sudo apt update && sudo apt install -y mongodb-org

echo " "
echo "Start and enable MongoDB"
sudo systemctl start mongod
sudo systemctl enable mongod
echo "check mongoDB"
sudo systemctl status mongod
