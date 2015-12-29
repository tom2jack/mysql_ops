#!/bin/zsh

#此脚本需要su到root下安装
#此脚本的文件属性为770

#判断脚本执行时所带的参数

#安装依赖软件包
apt-get -y install libaio1

mysql_install_dir=/usr/local

#创建用户组和用户
echo "\nmysql group and user check\n"

grpchk=$(cat /etc/group | grep mysql)

#[]中必须有空格，否则报错
if [ $? -eq 0 ]
then
    echo "group mysql exists!\n"
else
    echo "add group mysql!\n"
    groupadd mysql
fi

userchk=$(cat /etc/passwd | grep mysql)

if [ $? -eq 0 ]
then
    echo "user mysql exists!\n"
else
    echo "add user mysql!\n"
    useradd -r -g mysql mysql
fi

#复制配置文件
echo "copy config file!\n"
cd `dirname $0`
cp $(pwd)/my.cnf /etc/my.cnf

mysql_dir=$(echo $1 | sed "s/.tar.gz//g")
#得到MySQL版本
version=$(echo $mysql_dir | cut -d '-' -f 2 | cut -d '.' -f 1,2)

mysql_link=mysql_5_6
if [ $version = "5.7" ]
then
    mysql_link=mysql_5_7
fi

bin_dir=$mysql_install_dir/$mysql_link/bin

#/usr/local/mysql-5.x.x-linux-glibc2.5-x86_64目录存在则不解压
if test -d $mysql_install_dir/$mysql_dir
then
    echo "dir exists!\n"
else
    #解压二进制压缩包
    echo "decompress binary package...\n"
    tar zxf $1 -C$mysql_install_dir

    #切换到/usr/local
    if [ $(pwd) != $mysql_install_dir ]
    then
        cd $mysql_install_dir
    fi

    #创建mysql软链接
    echo "create link...\n"
    ln -s $mysql_dir $mysql_link
    
    #/etc/profile中包含了对bash的操作(不需要)
    rm /etc/profile
    echo "PATH=$bin_dir:$PATH" >>/etc/profile
    echo "export PATH" >>/etc/profile
    #这是在子shell中执行，需要在父shell中再执行一次
    . /etc/profile
fi

#创建datadir
echo "create data dir!\n"
if test -d /data/mysql
then
    rm -rf /data
fi

mkdir -p /data/mysql
cd /data/mysql

if [ $2 = "multi" ]
then
    mkdir data{1..4}
fi

#datadir的用户权限为mysql:mysql
chown -R mysql:mysql /data/mysql

#对每个实例进行初始化
cd $mysql_install_dir/$mysql_link
chown -R mysql:mysql .

function create_mysql_files_dir {
    if [ $version = "5.7" ]
    then
        mkdir mysql-files
        chmod 770 mysql-files
        chown -R mysql:mysql mysql-files
    fi
}

create_mysql_files_dir

function multi_init_mysql_5_7 {
    echo "multi init 5.7...\n"

    for dir_name in data{1..4}
    do
        datadir=/data/mysql/$dir_name
        $bin_dir/mysqld --initialize --user=mysql --datadir=$datadir
        sleep 2 
        $bin_dir/mysql_ssl_rsa_setup --datadir=$datadir
        sleep 2
    done
}

function single_init_mysql_5_7 {
    echo "single init 5.7...\n"

    #使用>init_mysql.log 2>&1可以重定向输出
    $bin_dir/mysqld --initialize --datadir=/data/mysql --user=mysql
    sleep 2
    $bin_dir/mysql_ssl_rsa_setup
}

function multi_init_mysql_5_6 {
    echo "multi init 5.6...\n"

    for dir_name in data{1..4}
    do
        datadir=/data/mysql/$dir_name
        $bin_dir/../scripts/mysql_install_db --user=mysql --datadir=$datadir
        sleep 2
    done
}

function single_init_mysql_5_6 {
    echo "single init 5.6...\n"

    $bin_dir/../scripts/mysql_install_db --user=mysql --datadir=/data/mysql
}

#初始化
if [ $version = "5.7" ]
then
    if [ $2 = "multi" ]
    then
        multi_init_mysql_5_7
    else
        single_init_mysql_5_7
    fi
else
    if [ $2 = "multi" ]
    then
        multi_init_mysql_5_6
    else
        single_init_mysql_5_6
    fi
fi

chown -R root .
if [ $version = "5.7" ]
then
    chown -R mysql:mysql mysql-files
fi

if [ $version = "5.7" ] && [ $2 = "multi" ]
then
    #在初始化后创建mysql-files，否则会报错，datadir下存在文件，初始化失败
    cd /data/mysql
    for dir_name in data{1..4}
    do
        cd $dir_name
        create_mysql_files_dir
        cd ..
    done
fi

ctrl_script=mysql.server
if [ $2 = "multi" ]
then
    ctrl_script=mysqld_multi.server
fi

#5.6中需要将basedir添加到my.cnf，否则会报错找不到my_print_defaults
cp $mysql_install_dir/$mysql_link/support-files/$ctrl_script /etc/init.d/$ctrl_script

#启动实例
if [ $2 = "multi" ]
then
    $bin_dir/mysqld_multi start
else
    #见mysqld_safe --help
    $bin_dir/mysqld_safe --user=mysql --ledir=$mysql_install_dir/$mysql_link/bin & 
fi

#睡眠2s，等待mysqld启动完毕，否则会报告mysql无法通过/tmp/mysql.sock连接到mysqld
sleep 2

#5.7使用临时密码登录，重新设置密码
if [ $version = "5.7" ]
then
    echo -n "enter your new password: "
    read password

    if [ $2 = "multi" ]
    then
        for num in {1..4}
        do
            tmp_password=$(cat /data/mysql/data$num/error.log | grep "A temporary password is generated for" | awk -F' ' '{print $NF}')
            echo $tmp_password

            $bin_dir/mysql --connect-expired-password -uroot -p$tmp_password -S /tmp/mysql.sock$num -e"set password='$password';create user 'multi_admin'@'localhost' identified by 'Syl19880121';grant shutdown on *.* to 'multi_admin'@'localhost';"
        done
    else
        tmp_password=$(cat /data/mysql/error.log | grep "A temporary password is generated for" | awk -F' ' '{print $NF}')
        echo $tmp_password

        #注意-e中要使用单引号
        $bin_dir/mysql --connect-expired-password -uroot -p$tmp_password -e"set password='$password';"
    fi
else
    if [ $2 = "multi" ]
    then
        for num in {1..4}
        do
            $bin_dir/mysql -uroot -S /tmp/mysql.sock$num -e"create user 'multi_admin'@'localhost' identified by 'Syl19880121';grant shutdown on *.* to 'multi_admin'@'localhost'";
        done
    fi
fi

exit
