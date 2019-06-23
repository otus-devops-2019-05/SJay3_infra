#!/bin/bash
# this script deploy reddit-app
appdir="reddit"
echo "This script run as user $USER"
cd ~
echo `pwd`
echo "Check repo for reddit-app"
if [ -d $appdir ]
then
  echo "Directory $appdir exist! Check repo"
  cd $appdir
  echo `pwd`
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
