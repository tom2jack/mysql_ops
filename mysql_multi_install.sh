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
#目录存在则不解压
if test -d /usr/local/$mysql_dir
then
    echo "dir exists!"
else
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
    ln -s $mysql_dir mysql
fi

#创建数据目录
if test -d /data/mysql
then
    rm -rf /data
fi

cd /
mkdir -p data/mysql
cd data/mysql
mkdir data{1..4}

#初始化
cd /usr/local/mysql

chown -R mysql:mysql .

for dir_name in data{1..4}
do
    datadir=/data/mysql/$dir_name
    bin/mysqld --initialize --user=mysql --datadir=$datadir
    sleep 3
    bin/mysql_ssl_rsa_setup --datadir=$datadir
    sleep 3
done

chown -R root:root .

#在初始化后创建mysql-files，否则会报错，数据目录下存在文件，初始化失败
cd /data/mysql
for dir_name in data{1..4}
do
    cd $dir_name
    mkdir -p mysql-files
    chmod 770 mysql-files
    cd ..
done

chown -R mysql:mysql /data/mysql

cp $mysql_install_dir/mysql/support-files/mysqld_multi.server /etc/init.d/mysqld_multi.server

echo "PATH=$mysql_install_dir/mysql/bin/:$PATH" >>/etc/profile
echo "export PATH" >>/etc/profile
. /etc/profile

exit
