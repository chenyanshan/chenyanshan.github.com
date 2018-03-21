---
layout: page
title: MySQL 备份还原系列之 mysqldump
date:   2018-3-14 18:05:07
categories: Database
tags: Database
---

mysqldump 是现在在小型企业使用最为广泛的 MySQL 备份工具，因为很多初级运维工程师基本上只能接触到它，所以我们就先来讲一下它。mysqldump 的原理很简单，就是 SELECT 把数据提取出来，但是结合不同存储引擎的其他特性，mysqldump 既可以实现温备，又可以实现热备。

- MySQL 版本: `5.5.56-MariaDB MariaDB Server (yum 安装)`
- Linux 版本: `CentOS 7.4 x86_64`
- SELinux 状态: `Permissive`
- Firewalld 状态: `Stop`

配置文件为默认配置文件，就添加了 binlog 的两条设置

	[root@chenyanshan ~]# cat /etc/my.cnf | grep -v "^#"
	[mysqld]
	datadir=/var/lib/mysql
	socket=/var/lib/mysql/mysql.sock
	symbolic-links=0
	log-bin=/opt/binlog/binlog       # 设置 binlog 文件位置
	binlog-format=mixed          # 设置 binlog 格式
	
	[mysqld_safe]
	log-error=/var/log/mariadb/mariadb.log
	pid-file=/var/run/mariadb/mariadb.pid
	
	!includedir /etc/my.cnf.d
	
	[root@chenyanshan ~]# mkdir /opt/binlog/
	[root@chenyanshan ~]# chown mysql:mysql /opt/binlog/

随便找了些数据创建了一张表。

	MariaDB [test_db]> DESC test;
	+--------+-----------------------+------+-----+---------+-------+
	| Field  | Type                  | Null | Key | Default | Extra |
	+--------+-----------------------+------+-----+---------+-------+
	| group  | mediumint(8) unsigned | NO   | PRI | 0       |       |
	| module | char(30)              | NO   | PRI |         |       |
	| method | char(30)              | NO   | PRI |         |       |
	+--------+-----------------------+------+-----+---------+-------+
	3 rows in set (0.00 sec)
	
	MariaDB [test_db]> SELECT count(`group`) FROM test;
	+----------------+
	| count(`group`) |
	+----------------+
	|           2027 |
	+----------------+
	1 row in set (0.00 sec)

对新创建的表进行备份。

	# mysqldump --databases test_db --lock-all-tables --master-data=2 > ~/test_backup.sql

在这里，我们详细的说一下上面那条命令所使用的参数:

- `--databases db1 db2 …` : 指定需要备份的库，如有多个请用空格隔开
- `--lock-all-tables`: 所有需要进行备份的库都施加读锁，这样可以防止在一张表做备份的时候另一张表正在被修改。导致数据不一致，这个锁全表的操作，是可以算作为备份的开销的。
- `--master-data={ 0 | 1 | 2 }`:  记录当前二进制日志文件名和在里面的位置，0为不记录，1为记录为非注释信息，2为记录为注释信息，一般用2

这个时候我们再对表进行一些操作。

	MariaDB [test_db]> DELETE FROM test WHERE group = 5;
	Query OK, 219 rows affected (0.00 sec)
	
	MariaDB [test_db]> SELECT count(`group`) FROM test;
	+----------------+
	| count(`group`) |
	+----------------+
	|           1808 |
	+----------------+
	1 row in set (0.00 sec)
	
	MariaDB [test_db]> DELETE FROM test WHERE module = "bug";
	Query OK, 167 rows affected (0.00 sec)

我们假设 “WHERE group = 5” 为正常操作，“WHERE `module` = "bug"” 为误操作，这个时候我们就需要回到 “WHERE group = 5” 操作后面，但是备份并没有备份到这里，所以还需要结合二进制日志进行即时点还原。

# 还原操作
## 1. 离线数据库

如果出现误操作需要还原数据库，请千万要先将数据库离线。

	#socket=/var/lib/mysql/mysql.sock
	socket=/var/lib/mysql/mysql_temp.sock
	port=3307

即注释掉正常的 socket 文件位置（如果 APP 程序并不是和 MySQL 在同一服务器就不需要更改 socket 文件位置），并设置 MySQL 端口为非正常使用端口。当然在这样设定之后就需要手动指定 socket 位置或者 port。

## 2. 查看备份位置：

之前备份的时候使用了 --master-data=2 参数，现在可以看下这个参数的效果了。

	[root@chenyanshan ~]# head -n200 ~/test_backup.sql | grep MASTER_LOG_FILE
	-- CHANGE MASTER TO MASTER_LOG_FILE='binlog.000001', MASTER_LOG_POS=733;

这里就可以看出来 binlog 文件为 binlog.000001，log pos 为 733。

## 3. 查看错误位置：

	# mysqlbinlog --start-position=733 /opt/binlog/binlog.000001
	·····
	·····
	·····
	# at 804
	#180314 10:33:29 server id 1  end_log_pos 904 	Query	thread_id=2	exec_time=0	error_code=0
	use `test_db`/*!*/;
	SET TIMESTAMP=1521038009/*!*/;
	DELETE FROM test WHERE `group` = 5
	/*!*/;
	# at 904
	#180314 10:33:29 server id 1  end_log_pos 976 	Query	thread_id=2	exec_time=0	error_code=0
	SET TIMESTAMP=1521038009/*!*/;
	COMMIT
	/*!*/;
	# at 976
	#180314 10:33:31 server id 1  end_log_pos 1047 	Query	thread_id=2	exec_time=0	error_code=0
	SET TIMESTAMP=1521038011/*!*/;
	BEGIN
	/*!*/;
	# at 1047
	#180314 10:33:31 server id 1  end_log_pos 1152 	Query	thread_id=2	exec_time=0	error_code=0
	SET TIMESTAMP=1521038011/*!*/;
	DELETE FROM test WHERE `module` = "bug"
	/*!*/;

这里可以发现，错误操作为 1047，而它的上一个为 976，所以我们需要回滚到 976 就行了。

## 4. 将 binlog 文件中正确内容导出来。

	# mysqlbinlog --start-position=733 --stop-position=976 /opt/binlog/binlog.000001 > ~/binlog_backup.sql

这样我们就有了完全备份文件，和后面变更过，但是是误操作之前的文件。

## 5. 恢复

	[root@chenyanshan ~]# mysql --socket /var/lib/mysql/mysql_temp.sock
	Welcome to the MariaDB monitor.  Commands end with ; or \g.
	Your MariaDB connection id is 2
	Server version: 5.5.56-MariaDB MariaDB Server
	
	Copyright (c) 2000, 2017, Oracle, MariaDB Corporation Ab and others.
	
	Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
	
	MariaDB [(none)]> DROP DATABASE test_db;        # 删除错误的数据
	Query OK, 1 row affected (0.00 sec)
	
	MariaDB [(none)]> CREATE DATABASE test_db;
	Query OK, 1 row affected (0.00 sec)
	
	MariaDB [(none)]> USE test_db;
	Database changed
	MariaDB [test_db]> SET SESSION SQL_LOG_BIN=0;   # 防止无用的二次二进制日志空间占用
	Query OK, 0 rows affected (0.00 sec)
	
	MariaDB [test_db]> source ~/test_backup.sql    # 先进行完全备份的恢复
	
	MariaDB [test_db]> source ~/binlog_backup.sql     # 再进行更改部分的恢复 
	
	MariaDB [test_db]> SELECT count(`group`) FROM test;
	+----------------+
	| count(`group`) |
	+----------------+
	|           1808 |
	+----------------+
	1 row in set (0.00 sec)

恢复完成之后，修改配置文件，让服务器重新上线。

至此，一次完整的备份外加即时点恢复就完成了。基本上 mysqldump 就这么些内容。这里再将一些 mysqldump 常用的参数列一下

- `--flush-logs`: 滚动二进制日志，一般来说用不上，具体看情况。
- `--events`： 备份事件调度器代码
- `--routines`： 备份存储过程和存储函数
- `--triggers`： 备份触发器

# 热备

上面全部内容都只是温备。并没有涉及到热备。热备只需要一个参数就能进行，但是它需要存储引擎和事务隔离级别支持。具体来说，就是要存储引擎支持MVCC（多版本并发控制），并且事务隔离级别需要为读提交（ READ COMMITTED）和可重读（REPEATABLE READ），当满足这两个需求的时候， 每个事务启动时，存储引擎会为每个启动的事务创建一个当下时刻的快照。并且让这个快照中读到的数据的版本加一的。以后只要是这个事务读的数据，一定会去找比这个版本更老的数据。这样就能读到以前的数据。这样就能实现在施加了锁之后还不影响其他用户的读写操作。MySQL 默认存储引擎 InnoDB 就支持 MVCC，Percona Server 的 XtraDB 存储引擎也支持。

- `--single-transaction`: 它在存储引擎支持 MVCC 和事务隔离级别也符合要求的情况下，会创建一个单一事务来保证备份的过程中数据的一致性。需要注意的是，是指定的库里面所有的表的存储引擎都支持 MACC 的时候（存储引擎是表级别的），才会热备。它和参数`--lock-all-tables`冲突，建议不要一起使用。

上面提及到了MVCC和事务隔离级别，以及存储引擎等概念。相信这也是很多运维同学不是太能理解 MySQL 备份还原的原因，因为里面涉及到的不只是简简单单的操作，还有 MySQL 一些略深层次的概念。

# 其他

mysqldump 自身并不支持增量备份和差异备份，但是可以通过 binlog 来实现增量和差异备份。虽然做法有点low，但是是可行的。方法也比较简单。增量就是备份的时候只备份 binlog 导出来的 SQL 文件，并且开始的 POS 是全备的记录的那个。实现差异备份的方式也差不多。

当然很少有人去这么做，因为需要增量备份或者差异备份的话，Xtrabackup会更好。
