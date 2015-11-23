#!/bin/zsh

#此脚本需要su到root下安装
#安装依赖软件包
apt-get -y install libaio1

mysql_install_dir=/usr/local

#创建用户组和用户
echo "mysql group and user check"

grpchk=$(cat /etc/group | grep mysql)

#[]中必须有空格，否则报错
if [ $? -eq 0 ]
then
    echo "group mysql exists!"
else
    echo "add group mysql!"
    groupadd mysql
fi

userchk=$(cat /etc/passwd | grep mysql)

if [ $? -eq 0 ]
then
    echo "user mysql exists!"
else
    echo "add user mysql!"
    useradd -r -g mysql mysql
fi

#解压二进制压缩包
echo "decompress binary package..."
tar zxf $1 -C$mysql_install_dir

#切换到安装目录
if [ $(pwd) != $mysql_install_dir ]
then
    cd $mysql_install_dir
fi

#创建软链接
echo "create link..."
mysql_dir=$(echo $1 | sed "s/.tar.gz//g")
ln -s $mysql_dir mysql

#安装MySQL 5.7
function install_mysql_5_7 {
    echo "install MySQL 5.7..."

    cd mysql
    mkdir data mysql-files
    chmod 770 mysql-files
    chown -R mysql .
    chgrp -R mysql .

    echo "initializing..."
    #注意--datadir和init_mysql.log的位置和权限，此时的错误日志路径为/usr/local/mysql/data/主机名.err
    bin/mysqld --initialize --datadir=/usr/local/mysql/data --user=mysql>init_mysql.log 2>&1
    bin/mysql_ssl_rsa_setup
    chown -R root .
    #注意这2个文件夹的权限
    chown -R mysql data mysql-files
    
    #修改自动生成的root密码
    tmp_password=$(cat init_mysql.log | grep "A temporary password is generated for" | awk -F' ' '{print $NF}')
    echo $tmp_password
    echo -n "enter your new password: "
    read password

    bin/mysqld_safe --user=mysql & 
    #睡眠3s，等待mysqld启动完毕，否则会报告mysql无法通过/tmp/mysql.sock连接到mysqld
    sleep 3
    #注意-e中要使用单引号
    bin/mysql --connect-expired-password -uroot -p$tmp_password -e"set password='$password';"
}

function install_mysql_5_6 {
    echo "install MySQL 5.6..."
}

#判断MySQL版本
version=$(echo $mysql_dir | cut -d '-' -f 2 | cut -d '.' -f 1,2)
if [ $version = "5.7" ]
then
    install_mysql_5_7
else
    install_mysql_5_6
fi

cp support-files/mysql.server /etc/init.d/mysql.server

echo "PATH=$mysql_install_dir/mysql/bin/:$PATH" >>/etc/profile
echo "export PATH" >>/etc/profile
. /etc/profile

exit
