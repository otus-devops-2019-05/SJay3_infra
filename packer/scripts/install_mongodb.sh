#!/bin/bash
# Run this script with sudo
echo "Install MongoDB"
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
bash -c 'echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.2.list'
apt update && sudo apt install -y mongodb-org

echo " "
echo "Start and enable MongoDB"
systemctl start mongod
systemctl enable mongod
echo "check mongoDB"
systemctl status mongod
