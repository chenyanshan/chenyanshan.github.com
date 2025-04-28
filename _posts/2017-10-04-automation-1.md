---
layout: page
title:  自动化运维之前置条件
date:   2017-10-03 18:52:07
categories: Automation 
tags: Automation
---

   这次的自动化运维博文描述是已经在我现在工作的公司中实际应用的，用于管理多套环境的自动化运维架构，此环境是由我单人搭建和维护（为什么要说是单人呢？我这里需要说明一下，我是我现在所在公司的第一个运维工程师，到现在也一直是唯一一个），从现在的状况看，上百台服务器由单人维护完全不成问题，几百台应该也不成问题，但是因为数量太多，可能会出现其他问题，所以这里不下定论。对于很多公司，其实可以直接将这套运维架构搬过去，直接应用。
  我先说一下，这套运维架构主要应用了 Ansible 和 Zabbix，后面还简单的涉及到了 SVN，所以关于软件的具体使用方法不会去讲，主要会讲这套运维架构中应用到的部分。以及很多需要规避的地方。

## 目录规范
  自动化运维，自动化运维，既然需要自动化，最最需要注意的地方就是目录规范。一般来说大部分公司的服务器目录都有很明确的规范，如果你所在的公司服务器目录没有规范，且架构已经形成，那么想迈入自动化运维的大门，可能需要破而后立。这里我说下我所使用的目录规范：

	/apps/
	├── backups
	│   └── mysql
	├── data
	│   ├── latest -> /apps/data/Version/v17_0407_29
	│   └── Version
	│       ├── v17_0406_25
	│       └── v17_0407_29
	├── dbdata
	│   ├── binlogs
	│   └── data
	├── scripts
	├── srv
	│   ├── erlang
	│   ├── mysql -> /apps/srv/mysql-5.7.16-linux-glibc2.5-x86_64
	│   ├── mysql-5.7.16-linux-glibc2.5-x86_64
	│   ├── source
	│   └── zabbix_agentd
	└── tempdata

这个是我使用的目录规范模版，当然这个只是一个简单的模版，里面的内容倒是经常更换，因为目录结构简单，我就不讲解目录的具体使用途径了。唯一需要注明的地方就是，data 目录下，latest 是工作目录，然后更新都是将 latest 指向到 version 目录下的一个版本目录，这样在出现问题进行回退版本的时候简单便捷。
目录规范是自动化运维的第一步，如果目录没有规范，几十台服务各个目录结构不同。想实现自动化更新，是可以做到，但是很麻烦。如果想要实现自动化运维，那无疑相当于天方夜谈。

## 规范的主机名
  这个不是必须选项，但是这个容易实现，且带来的收益不低，如果你所在的公司没有规范的主机名的话，你也可以做。小公司有小公司的命名规范，大公司应该都有自己的规范，所以我在这里简单介绍一下我现在所使用的命名规范。

	192.168.1.177    cfg-mon-ssh.chenyanshan.github.io cms
	# Production servers
	192.168.1.172    login01.prd.chenyanshan.github.io login01-prd
	192.168.1.173    login02.prd.chenyanshan.github.io login02-prd
	192.168.1.174    erl01.prd.chenyanshan.github.io erl01-prd
	192.168.1.175    erl02.prd.chenyanshan.github.io erl02-prd
	192.168.1.178    java01.prd.chenyanshan.github.io java01-prd
	192.168.1.179    java02.prd.chenyanshan.github.io java02-prd
	192.168.1.182    back01.prd.chenyanshan.github.io back01-prd
	# Testing servers
	192.168.2.134    db01.tst.chenyanshan.github.io db01-tst
	192.168.2.132    erl01.tst.chenyanshan.github.io erl01-tst
	192.168.2.133    redis01.tst.chenyanshan.github.io redis01-tst
	192.168.2.135    login01.tst.chenyanshan.github.io login01-tst
	192.168.2.136    java01.tst.chenyanshan.github.io java01-tst
	192.168.2.137    back01.tst.chenyanshan.github.io back01-tst
	# Apple App Store examine servers
	192.168.3.181    db01.exa.chenyanshan.github.io db01-exa
	192.168.3.182    redis01.exa.chenyanshan.github.io redis01-exa
	192.168.3.183    java01.exa.chenyanshan.github.io java01-exa
	192.168.3.184    login01.exa.chenyanshan.github.io login01-exa

出于某些方面的考虑，我将主机名替换掉了。这个集群有多个环境，在主机名里面的体现就是 `prd`, `tst`, `exa`，分别为正式环境，测试环境，审核环境。本来还应该有开发环境的，但是开发环境在本地。所以开发环境也需要一起维护的童鞋们应该知道怎么办了吧。

## 服务脚本
除了上面介绍的两个，还有一个，就是服务脚本。不管是遵循 `Systemd` 风格还是 `SysV` 风格，都应该书写好服务脚本，这个是经验之谈，也是在我实现的这套系统里面的比较重要的环节。这里给大家看一下 `tomcat` 的服务脚本。

	#!/bin/sh
	# Tomcat init script for Linux.
	#
	# chkconfig: 2345 96 14
	# description: The Apache Tomcat servlet/JSP container.
	JAVA_HOME=/usr
	CATALINA_HOME=/apps/srv/tomcat
	JAVA_OPTS="-Xms6000m -Xmx6000m -XX:NewSize=1024m -XX:MaxNewSize=2048m -XX:PermSize512m -XX:MaxPermSize=1024m"
	export JAVA_HOME CATALINA_HOME JAVA_OPTS
	stop () {
	     /bin/su -c "$CATALINA_HOME/bin/catalina.sh stop" tomcat
	     /usr/bin/pkill java
	}
	
	if [ `whoami` != "root" ]; then
	        echo "Please useage sudo command"
	        exit 1
	fi
	
	case $1 in
	restart)
	    stop
	    sleep 2
	    /bin/su -c "$CATALINA_HOME/bin/catalina.sh start" tomcat
	    ;;
	start)
	    /bin/su -c "$CATALINA_HOME/bin/catalina.sh start" tomcat
	    ;;
	stop)
	    stop
	    ;;
	*)
	    exec "$CATALINA_HOME/bin/catalina.sh $1"
	    ;;
	esac

其实就是很简单的调用 `catalina.sh` 。但是它让 `tomcat` 服务的控制方式从输入路径到 `catalina.sh` 执行，变成了由 `service` 控制，而且还加入了由 `tomcat` 用户启动。而且还可以由 `chkconfig: 2345 96 14` 来控制起开机自启的级别和优先级，可以说是一劳永逸的事情。而且 `tomcat` 还有 `catanina.sh` 控制脚本，很多服务都是固定的启动命令，所以服务脚本是肯定有必要的。

基本上上面三个条件就是自动化运维的前置条件。非常简单，绝大部分公司相信已经实现。对了，这里还需要说明一点，我现在所在的公司的服务器都是在 aliyun 上买的，所以服务器里面的操作系统是直接安装好的，服务器安装这一步我没有去考虑，不过你所在的公司如果是自己维护机房，或者是托管在IDC机房，那么就可以考虑 `PXE` 这种自动安装系统的东西，或者用 `PXE` 外面套了层壳的东西 `Cobber `，`Cobber` 在我之前的博文有介绍，有需要的童鞋可以翻到前面去找下。

