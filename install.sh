#!/bin/zsh

if [ $1 = "5.6" ]
then
    ./mysql_install.sh mysql-5.6.27-linux-glibc2.5-x86_64.tar.gz $2
else
    ./mysql_install.sh mysql-5.7.9-linux-glibc2.5-x86_64.tar.gz $2
fi
