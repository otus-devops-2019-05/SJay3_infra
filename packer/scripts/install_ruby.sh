#!/bin/bash
# Run this script with sudo
echo "Install ruby"
apt update && sudo apt install -y ruby-full ruby-bundler build-essential
echo " "
echo "Check versions of ruby and bundler"
ruby -v
bundler -v
