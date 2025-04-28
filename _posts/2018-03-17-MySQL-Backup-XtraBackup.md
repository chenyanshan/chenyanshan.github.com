---
layout: page
title:  MySQL 备份还原系列之 XtraBackup
date:   2018-3-17 8:05:07
categories: Database
tags: Database
---

XtraBackup 是由 Percona 开发的 MySQL 备份软件，官方地址为 [Persona XtraBackup][1]，它支持 MySQL、MariaDB 和 Percona Server for MySQL。也有很多大公司为其做背书，Facebook 早期就是使用它进行增量备份的。根据官方介绍，XtraBackup 是唯一开源的能对使用 InnoDB 和 XtraDB 存储引擎的数据库进行热备的软件。显然，mysqldump 也是开源的。

由于 XtraBackup 是物理备份。所以它的速度很快，XtraBackup 还能自动验证备份是否有效，并且它自带增量备份和差异备份功能，加上其在上面功能实现的同时还是热备，这对很多公司应用场景来说，已经算是强大到无以复加了。有种有了它，数据无忧的感觉。除了上面那些功能外，它还有很快的还原速度，而且它是多张表同时备份（mysqldump 为单线程）。

XtraBackup 为物理备份，再加增量和差异备份的功能，这让它可以胜任中型甚至大型数据规模的数据库的备份。

# 1. 原理

## 1.1 增量备份和物理备份原理

这里讲一下它的实现原理，它是根据 InnoDB (XtraDB) 存储引擎自身底层的数据结构保存机制来进行备份的，在 InooDB (XtraDB) 存储引擎最小磁盘单位“页”里面会存储一个值，`FIL_PAGE_LSN`，它存储在页的`File Header`，该值代表该页最后被修改的日志序列位置 LSN（Log Sequence Number，逻辑单元号）。当页的数据更改了之后，其 LSN 也会改变。通过`SHOW ENGINE InnoDB STATUS\G` 或者 `SHOW InnoDB STATUS\G` 可以查看存储引擎当前 LSN 值。

![][image-1]

如果在全备的时候备份了全部的数据。那么在增量备份的时候，就只需要备份比上次备份的时候最大 LSN 还要大的 LSN 的页。如图所示，全备的时候，会记录最大 LSN 为134，在增量备份的时候，就会直接只备份 LSN 大于 134 的部分。

## 1.2 数据一致性解决方案

LSN解决了增量备份的问题，但是数据备份时候的数据一致性也是需要考虑的问题。毕竟有的数据量大的数据库，一次全量备份几分钟。这个时候数据还在不停的修改中，这个时候如果不考虑数据一致性的问题，就可能导致整个备份不在一个时刻，甚至有的页头尾不一致，数据错误，导致数据不可用。mysqldump 是通过 MVCC 和全局读锁来保证数据一致性的。

XtraBackup并没有在备份的过程中保证数据是一个时刻的，但是它在备份开始之前，先启动了一个 `xtrabackup_log` 进程，这个进程会将备份过程中变动的事务日志也备份过来。并且它不管数据库的变动，会去直接备份磁盘数据。当备份完成之后，XtraBackup会得到两份数据，一份为损坏的数据文件，还有一份是在备份过程中所有的事务日志，这两份数据组合在一起，就好像 MySQL 崩溃之后的数据，完整的事务日志文件和损坏的数据文件。XtraBackup 有专门的操作来处理这些数据。这个过程叫做准备(prepare)，“准备”的主要作用是通过回滚未提交的事务及同步已经提交的事务至数据文件让数据文件处于一致性状态。这样数据的一致性也能有保障了。

可能有的同学会有疑问，虽然有事务日志，但是利用错误的数据进行数据恢复是不会有可能会出问题？

> 这个就涉及事务中的持久性了，在支持事务的存储引擎设计之初，就考虑到了数据库崩溃，服务器崩溃，忽然断电这些情况。并且还能在这些情况保证数据的持久性，在 InnoDB 存储引擎和 XtraBackup 存储引擎中，这个持久性就是依赖事务日志来完成。

# 2. 备份演示

## 2.1 完全备份及恢复

### 2.1.1 安装软件

直接去[Download Percona XtraBackup][2]下载对应系统的安装包就行了，没有需要定制的功能，无需编译安装。

### 2.1.1 创建备份用户

和 mysqldump 不同，使用 XtraBackup 进行备份的数据库一般都有严格的权限设置，所以这里从权限设置开始。这里的设置为备份用户，为能备份所需要最小权限。低于这个权限就会无法备份。

	MariaDB [(none)]> CREATE USER 'xb_user'@'localhost' IDENTIFIED BY 'chenyanshan.github.io';
	MariaDB [(none)]> REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'xb_user'@'localhost';
	MariaDB [(none)]> GRANT PROCESS, RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO "xb_user"@"localhost";
	MariaDB [(none)]> FLUSH PRIVILEGES;

### 2.1.2 制造数据

先建立一张表，存储引擎可以为 InnoDB 或者是 XtraDB

	MariaDB [(xtrabackup)]> CREATE TABLE backup_test (
	    -> id tinyint AUTO_INCREMENT NOT NULL,
	    -> name varchar(25) NOT NULL,
	    -> PRIMARY KEY (`id`)
	    -> ) ENGINE=InnoDB;

写入一些数据

	MariaDB [xtrabackup]> INSERT INTO backup_test (name) VALUES 
	    -> ("chenyanshan"), ("zhanzongxiang"), ("liaozhihua");
	Query OK, 3 rows affected (0.00 sec)
	Records: 3  Duplicates: 0  Warnings: 0

### 2.1.3 执行数据备份

数据备份的命令和 mysqldump 差不多。很简单

	[root@chenyanshan ~]# mkdir /backups
	[root@chenyanshan ~]# innobackupex --user=xb_user --password=chenyanshan.github.io /backups/
	....    
	....    /* 这里省略了一大串日志 */
	....
	180317 02:13:52 Executing UNLOCK TABLES
	180317 02:13:52 All tables unlocked
	180317 02:13:52 Backup created in directory '/backups/2018-03-17_02-13-50/'
	MySQL binlog position: filename 'binlog.000004', position '1471'
	180317 02:13:52 [00] Writing /backups/2018-03-17_02-13-50/backup-my.cnf
	180317 02:13:52 [00]        ...done
	180317 02:13:52 [00] Writing /backups/2018-03-17_02-13-50/xtrabackup_info
	180317 02:13:52 [00]        ...done
	xtrabackup: Transaction log of lsn (1601036) to (1601036) was copied.
	180317 02:13:52 completed OK!                # 确保最后出现了这个

由于 XtraBackup 会自动读取 my.cnf 文件（应该就是根据 MySQL 的配置文件读取顺序读取），所以我们就算是物理备份（逻辑备份会通过套接字或者 Unix Socket 连接SQL接口或者数据库API），也不需要指定 MySQL 的 Datadir。

使用 XtraBackup 进行备份的时候，它会备份所有关于表结构定义的相关文件，以及触发器和配置文件等相关文件。

### 2.1.4 XtraBackup 备份文件结构

XtraBackup 备份的文件除了备份过来的文件之外，还有很多记录重要数据的文件，比如 LSN 的值，binlog 的位置等，

	[root@chenyanshan 2018-03-17_02-13-50]# ll
	total 18472
	-rw-r-----. 1 root root      417 Mar 17 02:13 backup-my.cnf
	-rw-r-----. 1 root root 18874368 Mar 17 02:13 ibdata1
	drwxr-x---. 2 root root     4096 Mar 17 02:13 mysql
	drwxr-x---. 2 root root     8192 Mar 17 02:13 mysql_backup
	drwxr-x---. 2 root root     4096 Mar 17 02:13 performance_schema
	drwxr-x---. 2 root root       20 Mar 17 02:13 test
	drwxr-x---. 2 root root       20 Mar 17 02:13 test_db
	drwxr-x---. 2 root root       43 Mar 17 02:13 xtrabackup
	-rw-r-----. 1 root root       19 Mar 17 02:13 xtrabackup_binlog_info
	-rw-r-----. 1 root root      113 Mar 17 02:13 xtrabackup_checkpoints
	-rw-r-----. 1 root root      470 Mar 17 02:13 xtrabackup_info
	-rw-r-----. 1 root root     2560 Mar 17 02:13 xtrabackup_logfile

- `backup-my.cnf`: 备份命令用到的配置选项信息；
- `ibdata1`: 由于`innodb_file_per_table`参数并未开启，所以这里是 InnoDB 存储引擎的所有表的表空间文件。
- 文件夹: 几个文件都是库文件直接复制过来的
- `xtrabackup_binlog_info`: binglog 信息
- `xtrabackup_checkpoints `: 里面记录了此处备份的备份类型（完全或增长），LSN 范围，以及备份状态（如是否已经为prepared状态）
- `xtrabackup_info `: 里面记录了`xtrabackup_binlog_info `和`xtrabackup_checkpoints `的信息，还记录了备份的数据库的版本，备份命令等内容
- `xtrabackup_logfile `: `xtrabackup_log` 备份的事务日志文件

### 2.1.5 还原前的准备

上面介绍原理的时候已经讲过，备份的数据是有问题的数据加上无问题的事务日志，所以这里在还原之前需要执行准备操作(prepare)。

	[root@chenyanshan ~]# innobackupex --apply /backups/2018-03-17_02-13-50/
	180317 02:53:41 innobackupex: Starting the backup operation
	
	IMPORTANT: Please check that the backup run completes successfully.
	           At the end of a successful backup run innobackupex
	           prints "completed OK!".
	.....
	.....     /*  此处省略十万字  */
	.....
	180317 02:53:43 Executing UNLOCK TABLES
	180317 02:53:43 All tables unlocked
	180317 02:53:43 Backup created in directory '/backups/2018-03-17_02-13-50/2018-03-17_02-53-41/'
	MySQL binlog position: filename 'binlog.000004', position '1471'
	180317 02:53:43 [00] Writing /backups/2018-03-17_02-13-50/2018-03-17_02-53-41/backup-my.cnf
	180317 02:53:43 [00]        ...done
	180317 02:53:43 [00] Writing /backups/2018-03-17_02-13-50/2018-03-17_02-53-41/xtrabackup_info
	180317 02:53:43 [00]        ...done
	xtrabackup: Transaction log of lsn (1601036) to (1601036) was copied.
	180317 02:53:43 completed OK!          # 确保最后出现了这个

### 2.1.6 还原

数据的恢复和逻辑备份的数据恢复不同，XtraBackup 的数据恢复是需要将数据库先停止的，由于数据库并没有错误，所以这里假装数据文件有问题。

	[root@chenyanshan ~]# mv /var/lib/mysql/ /backups/mysql_datadir_file   # 先将数据文件备份
	[root@chenyanshan ~]# innobackupex --copy-back /backups/2018-03-17_02-13-50/
	.....
	.....  
	.....
	180317 03:08:19 completed OK!      # 主要还是看最后提示成功没有
	[root@chenyanshan ~]# chown -R mysql:mysql /var/lib/mysql/    #  文件权限应该会对不上，这里需要修改一下权限
	[root@chenyanshan ~]# systemctl start mariadb
	[root@chenyanshan ~]# mysql
	Welcome to the MariaDB monitor.  Commands end with ; or \g.
	Your MariaDB connection id is 2
	Server version: 5.5.56-MariaDB MariaDB Server
	
	Copyright (c) 2000, 2017, Oracle, MariaDB Corporation Ab and others.
	
	Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
	
	MariaDB [(none)]> SELECT * FROM xtrabackup.backup_test;
	+----+---------------+
	| id | name          |
	+----+---------------+
	|  1 | chenyanshan   |
	|  2 | zhanzongxiang |
	|  3 | liaozhihua    |
	+----+---------------+
	3 rows in set (0.00 sec)

到这里一次完全备份和完全备份的恢复就完成。这里还可以结合 binlog 进行即时点还原，因为上篇已经讲过 binlog 的使用方法了，这里就不再啰嗦了。


## 2.2 增量备份和差异备份及其还原

这里需要说明一下，增量备份和差异备份其实实现差不多，不过一个是在全量备份的基础上进行备份，另一个是在增量备份的基础或者在其他差异备份的基础上再进行备份。其实就可以把增量备份看作为略特殊的差异备份。所以我们这里以差异备份做演示。

### 2.2.1 全量备份

由于上面已经提供了数据，所以在这里就不纠结数据的问题，直接就拿之前的数据用于演示了。

	[root@chenyanshan ~]# rm -rf /backups/*
	[root@chenyanshan ~]# innobackupex --user=xb_user --password=chenyanshan.github.io /backups/
	.....
	180317 03:27:14 completed OK!
 

### 2.2.2 增量和差异备份

第一次进行的，既可以叫增量备份，也可以叫差异备份

	# 修改一下数据，然后再进行备份
	[root@chenyanshan ~]# mysql
	MariaDB [(none)]> INSERT INTO xtrabackup.backup_test (`name`) VALUES
	    -> ("test_1"), ("test_2"), ("test_3");
	Query OK, 3 rows affected (0.01 sec)
	Records: 3  Duplicates: 0  Warnings: 0
	
	# 增量(差异)备份
	[root@chenyanshan ~]# innobackupex --user=xb_user --password=chenyanshan.github.io --incremental /backups/ --incremental-basedir=/backups/2018-03-17_03-27-12/
	.....
	''180317 03:29:53 completed OK!
 

- `—incremental $BACKUP_DIR`: 这个参数的意义是告诉 XtrBackup，此次备份是增量备份，是以`--incremental-basedir `指定的目录为基础。`$BACKUP_DIR`是此次备份的备份目录
- `—incremental-basedir=$BACKUP_DIR`: 这个参数是用于指定增量备份的基础目录。`$BACKUP_DIR`是基础备份目录，此次备份会以里面的 LSN 为基础再进行备份

再进行一次差异备份。

	# 再进行数据修改，再进行备份
	[root@chenyanshan ~]# mysql
	MariaDB [(none)]> DELETE FROM xtrabackup.backup_test WHERE name = "chenyanshan";
	Query OK, 1 row affected (0.00 sec)
	# 差异备份
	[root@chenyanshan ~]# innobackupex --user=xb_user --password=chenyanshan.github.io --incremental /backups/ --incremental-basedir=backups/2018-03-17_03-29-51/
	.....
	180317 03:33:00 completed OK!

和上面不同，上面`--incremental-basedir `指定的目录为`2018-03-17_03-27-12`，为全量备份目录，而这个指定的是`2018-03-17_03-29-51 `，是一个差异备份目录，所以这个备份也是差异备份。

### 2.2.3 差异备份的还原

为完全备份做“准备”，在有增量备份的情况下，需要--redo-only选项来保证未commit的事务也执行

	[root@chenyanshan ~]# innobackupex --apply-log --redo-only /backups/2018-03-17_03-27-12/
	.....
	180317 03:44:41 completed OK!

当全量备份做了操作之后，中间的差异备份，也需要执行和完全备份一样的”准备”

	[root@chenyanshan ~]# innobackupex --apply-log --redo-only /backups/2018-03-17_03-27-12/ --incremental-dir=/backups/2018-03-17_03-29-51/
	.....
	180317 03:44:50 completed OK!

`—incremental-dir=`: 用于指定差异备份目录位置


当前面的差异备份都完成之后，最后一个差异备份需要注意，它不需要再进行 `--redo-only` 操作，同理，如果是增量备份，增量备份也不需要这个操作。

	[root@chenyanshan ~]#innobackupex --apply-log /backups/2018-03-17_03-27-12/ --incremental-dir=/backups/2018-03-17_03-32-58/
	.....
	180317 03:45:00 completed OK!

恢复操作

	[root@chenyanshan ~]# systemctl stop mariadb.service
	[root@chenyanshan ~]# mv /var/lib/mysql/ /backups/mysql_datadir_file
	[root@chenyanshan ~]# innobackupex --copy-back /backups/2018-03-17_03-27-12/
	.....
	180317 03:55:30 completed OK!
	[root@chenyanshan ~]# mysql
	Welcome to the MariaDB monitor.  Commands end with ; or \g.
	Your MariaDB connection id is 2
	Server version: 5.5.56-MariaDB MariaDB Server
	
	Copyright (c) 2000, 2017, Oracle, MariaDB Corporation Ab and others.
	
	Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
	
	MariaDB [(none)]> SELECT * FROM xtrabackup.backup_test;
	+----+---------------+
	| id | name          |
	+----+---------------+
	|  2 | zhanzongxiang |
	|  3 | liaozhihua    |
	|  4 | test_1        |
	|  5 | test_2        |
	|  6 | test_3        |
	+----+---------------+
	5 rows in set (0.00 sec)


## 总结

至此，XtraBackup 相关内容已经基本讲完了，虽然还有一些一些内容，但是基本上也不是特别重要。比如流传输，主从架构中的备份，这些要么可以使用其他方式实现，要么不是特别重要。所以这里就不讲理。基本上中型数据量的数据库可以使用 XtraBackup 来实现备份，还有大型数据量的数据库呢？后面还会介绍一款工具来实现，也是有大公司做背书的工具。


[1]:	https://www.percona.com/software/mysql-database/percona-xtrabackup
[2]:	https://www.percona.com/downloads/XtraBackup/LATEST/

[image-1]:	http://chenyanshan.github.io/images/MySQL-Backup-XtraBackup-image/DraggedImage.png