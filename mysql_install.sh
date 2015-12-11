#!/bin/zsh

#此脚本需要su到root下安装
#修改此脚本的用户/用户组权限为root:root，文件属性为770
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

#复制配置文件
echo "copy config file!"
cd `dirname $0`
cp $(pwd)/my.cnf /etc/my.cnf

mysql_dir=$(echo $1 | sed "s/.tar.gz//g")
#/usr/local/mysql-5.x.x-linux-glibc2.5-x86_64目录存在则不解压
if test -d /usr/local/$mysql_dir
then
    echo "dir exists!"
else
    #解压二进制压缩包
    echo "decompress binary package..."
    tar zxf $1 -C$mysql_install_dir

    #切换到/usr/local
    if [ $(pwd) != $mysql_install_dir ]
    then
        cd $mysql_install_dir
    fi

    #创建mysql软链接
    echo "create link..."
    ln -s $mysql_dir mysql
fi

#创建datadir
echo "create data dir!"
if test -d /data/mysql
then
    rm -rf /data
fi

cd /
mkdir -p data/mysql
cd data/mysql
mkdir data{1..4}

#对每个实例进行初始化
echo "init..."
cd /usr/local/mysql

chown -R mysql:mysql .

#得到MySQL版本
version=$(echo $mysql_dir | cut -d '-' -f 2 | cut -d '.' -f 1,2)

#初始化
if [ $version = "5.7"]
then
    if [ $2 == "multi" ]
    then
        multi_init_mysql_5_7
    else
        single_init_mysql_5_7
    fi
else
    if [ $2 == "multi" ]
    then
        multi_init_mysql_5_6
    else
        single_init_mysql_5_6
    fi
fi

function multi_init_mysql_5_7 {
    for dir_name in data{1..4}
    do
        datadir=/data/mysql/$dir_name
        bin/mysqld --initialize --user=mysql --datadir=$datadir
        sleep 2 
        bin/mysql_ssl_rsa_setup --datadir=$datadir
        sleep 2
    done
}

function single_init_mysql_5_7 {
    echo "init MySQL 5.7..."

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

function single_init_mysql_5_6 {
    echo "init MySQL 5.6..."
}

chown -R root .

if [ $version = "5.7" ]
then
    #在初始化后创建mysql-files，否则会报错，datadir下存在文件，初始化失败
    cd /data/mysql
    for dir_name in data{1..4}
    do
        cd $dir_name
        mkdir -p mysql-files
        chmod 770 mysql-files
        cd ..
    done
fi

chown -R mysql /data/mysql

ctrl_script=mysql.server
if [ $2 == "multi"  ]
then
    ctrl_script=mysqld_multi.server
fi

cp $mysql_install_dir/mysql/support-files/$ctrl_script /etc/init.d/$ctrl_script

bin_dir=$mysql_install_dir/mysql/bin
echo "PATH=$bin_dir:$PATH" >>/etc/profile
echo "export PATH" >>/etc/profile
. /etc/profile

#启动实例
if [ $2 == "multi" ]
then
    $bin_dir/mysqld_multi start
else
    $bin_dir/mysqld_safe --user=mysql & 
fi

#睡眠2s，等待mysqld启动完毕，否则会报告mysql无法通过/tmp/mysql.sock连接到mysqld
sleep 2

#使用临时密码登录，重新设置密码
if [ $version == "5.7"]
then
    echo -n "enter your new password: "
    read password

    if [ $2 == "multi" ]
    then
        for num in {1..4}
        do
            tmp_password=$(cat /data/mysql/data$num/error.log | grep "A temporary password is generated for" | awk -F' ' '{print $NF}')
            echo $tmp_password
            $bin_dir/mysql --connect-expired-password -uroot -p$tmp_password -S /tmp/mysql.sock$num -e"set password='$password';"
        done
    else
        tmp_password=$(cat /data/mysql/error.log | grep "A temporary password is generated for" | awk -F' ' '{print $NF}')
        echo $tmp_password

        #注意-e中要使用单引号
        $bin_dir/mysql --connect-expired-password -uroot -p$tmp_password -e"set password='$password';"
    fi
fi

exit
