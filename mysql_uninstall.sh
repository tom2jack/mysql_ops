#!/bin/zsh

if [ $1 = "5.7" ]
then
    unlink /usr/local/mysql_5_7
    rm -rf /usr/local/mysql-5.7.9-linux-glibc2.5-x86_64
else
    unlink /usr/local/mysql_5_6
    rm -rf /usr/local/mysql-5.6.27-linux-glibc2.5-x86_64
fi
