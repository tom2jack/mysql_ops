#!/bin/zsh

mysql_install_dir=/usr/local/mysql
mysql_data_dir=/data/mysql_data
dbrootpwd=root

#获得内存和虚拟内存大小
mem=`free -m | awk '/Mem:/{print $2}'`
swap=`free -m | awk '/Swap:/{print $2}'`

#安装依赖包并下载源码包

#生成Makefile
cmake . -DCMAKE_INSTALL_PREFIX=$mysql_install_dir \
-DMYSQL_DATADIR=$mysql_data_dir \
-DSYSCONFDIR=/etc \
-DWITH_INNOBASE_STORAGE_ENGINE=1 \
-DWITH_FEDERATED_STORAGE_ENGINE=1 \
-DWITH_MYISAM_STORAGE_ENGINE=1 \
-DENABLED_LOCAL_INFILE=1 \
-DENABLE_DTRACE=0 \
-DEXTRA_CHARSETS=all \
-DDEFAULT_CHARSET=utf8mb4 \
-DDEFAULT_COLLATION=utf8mb4_general_ci \
-DWITH_EMBEDDED_SERVER=1 \

#获取CPU个数进行多线程编译
make -j `grep processor /proc/cpuinfo | wc -l`
make install

#根据机器内存大小配置参数 
if [ $mem -gt 1500 -a $mem -le 2500 ];then
    sed -i 's@^thread_cache_size.*@thread_cache_size = 16@' /etc/my.cnf
    sed -i 's@^query_cache_size.*@query_cache_size = 16M@' /etc/my.cnf
    sed -i 's@^myisam_sort_buffer_size.*@myisam_sort_buffer_size = 16M@' /etc/my.cnf
    sed -i 's@^key_buffer_size.*@key_buffer_size = 16M@' /etc/my.cnf
    sed -i 's@^innodb_buffer_pool_size.*@innodb_buffer_pool_size = 128M@' /etc/my.cnf
    sed -i 's@^tmp_table_size.*@tmp_table_size = 32M@' /etc/my.cnf
    sed -i 's@^table_open_cache.*@table_open_cache = 256@' /etc/my.cnf
elif [ $mem -gt 2500 -a $mem -le 3500 ];then
    sed -i 's@^thread_cache_size.*@thread_cache_size = 32@' /etc/my.cnf
    sed -i 's@^query_cache_size.*@query_cache_size = 32M@' /etc/my.cnf
    sed -i 's@^myisam_sort_buffer_size.*@myisam_sort_buffer_size = 32M@' /etc/my.cnf
    sed -i 's@^key_buffer_size.*@key_buffer_size = 64M@' /etc/my.cnf
    sed -i 's@^innodb_buffer_pool_size.*@innodb_buffer_pool_size = 512M@' /etc/my.cnf
    sed -i 's@^tmp_table_size.*@tmp_table_size = 64M@' /etc/my.cnf
    sed -i 's@^table_open_cache.*@table_open_cache = 512@' /etc/my.cnf
elif [ $mem -gt 3500 ];then
    sed -i 's@^thread_cache_size.*@thread_cache_size = 64@' /etc/my.cnf
    sed -i 's@^query_cache_size.*@query_cache_size = 64M@' /etc/my.cnf
    sed -i 's@^myisam_sort_buffer_size.*@myisam_sort_buffer_size = 64M@' /etc/my.cnf
    sed -i 's@^key_buffer_size.*@key_buffer_size = 256M@' /etc/my.cnf
    sed -i 's@^innodb_buffer_pool_size.*@innodb_buffer_pool_size = 1024M@' /etc/my.cnf
    sed -i 's@^tmp_table_size.*@tmp_table_size = 128M@' /etc/my.cnf
    sed -i 's@^table_open_cache.*@table_open_cache = 1024@' /etc/my.cnf
fi

#执行SQL语句
$mysql_install_dir/bin/mysql -e "grant all privileges on *.* to root@'127.0.0.1' identified by \"$dbrootpwd\" with grant option;"
$mysql_install_dir/bin/mysql -e "grant all privileges on *.* to root@'localhost' identified by \"$dbrootpwd\" with grant option;"
$mysql_install_dir/bin/mysql -uroot -p$dbrootpwd -e "delete from mysql.user where Password='';"
$mysql_install_dir/bin/mysql -uroot -p$dbrootpwd -e "delete from mysql.db where User='';"
$mysql_install_dir/bin/mysql -uroot -p$dbrootpwd -e "delete from mysql.proxies_priv where Host!='localhost';"
$mysql_install_dir/bin/mysql -uroot -p$dbrootpwd -e "drop database test;"
$mysql_install_dir/bin/mysql -uroot -p$dbrootpwd -e "reset master;"

#配置动态库
rm -rf /etc/ld.so.conf.d/{mysql,mariadb,percona}*.conf
echo "$mysql_install_dir/lib" > mysql.conf
/sbin/ldconfig