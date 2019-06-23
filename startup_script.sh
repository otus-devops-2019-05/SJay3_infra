#!/bin/bash
# Startup script
echo "Install ruby"
apt update && apt install -y ruby-full ruby-bundler build-essential
echo " "
echo "Check versions of ruby and bundler"
ruby -v
bundler -v

echo " "
echo "Install MongoDB"
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
bash -c 'echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.2.list'
apt update && apt install -y mongodb-org

echo " "
echo "Start and enable MongoDB"
systemctl start mongod
systemctl enable mongod
echo "check mongoDB"
systemctl status mongod

echo " "
appdir="reddit"
echo "This script run as user $USER"
cd ~
echo "Check repo for reddit-app"
if [ -d $appdir ]
then
  echo "Directory $appdir exist! Check repo"
  cd $appdir
  git status
  git branch
else
  echo "Clonning git repo"
  git clone -b monolith https://github.com/express42/reddit.git
  echo "Install application"
  cd $appdir && bundle install
fi
echo "Check app running"
pumapid=$(ps aux | grep puma | grep -v grep | awk '{print $2}')
if [ -z $pumapid ]
then
  echo "Start service"
  puma -d
  ps aux | grep puma | grep -v grep | awk '{print "Service runnig with PID:",$2}'
else
  echo "Service already running with PID: $pumapid"
fi
