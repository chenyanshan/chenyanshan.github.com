---
layout: page
title:  自动化运维之 Ansible 管理多套环境
date:   2017-10-04 23:45:01
categories: Automation
tags: Automation
---

前面一篇中已经有说明了。我现在公司需要管理的环境有三套，分别为生产环境、测试环境和审核环境。所有需要更新到生产环境的代码都必须先经由测试环境测试，测试通过了，再才能更新到生产环境。测试环境并没有外部人员进行连接，审核环境是用于 App Store 审核使用，这里就不多说了。

![](/images/Automation-2/DraggedImage.png)

上图中展示的架构，其中 Erlang Servers 和 Java Servers 每台服务器所使用的端口都不同。而在不同的环境，其所连接的数据库和 Redis 以及一些其他的配置都不同。所以需要分环境，环境下需要分组，并且各个主机都需要自己的配置。当时考虑了 Puppet 和 Ansible，但是考虑到 Puppet 太重量级，每台服务器上面都需要安装 Agentd。相比来说，Ansible 就简单多了。Ansible 理念也和当前应用场景相似，Puppet 却是类似保证最终一致性的那种。而且如果考虑到我一但离职，Ansible 交给后面的人维护也轻松些。

这里就不讲 Ansible 的前置了，主要讲这个架构中 Ansible 实现的方式和一般的实现不同的地方。

## 变量分组

	/etc/ansible/environments
	.
	|-- 000_cross_env_vars  # 全局变量，各个环境都会使用到的变量
	|-- exa
	|   |-- group_vars   # 组变量文件夹，里面除了 all 直接会被调用，其他需要指定才会被调用
	|   |   |-- all
	|   |   |   |-- 000_cross_env_vars -> ../../../000_cross_env_vars
	|   |   |   `-- env_specific  # 组通用变量
	|   |   `-- gamedb            # 独立变量，如需使用，需要调用 
	|   |-- hosts                 # hosts 文件，和 /etc/ansibles/hosts 结构一样
	|   `-- host_vars             # host独立变量文件夹
	|       `-- java01.exa.chenyanshan.github.io
	|-- prd
	|   |-- group_vars
	|   |   |-- all
	|   |   |   |-- 000_cross_env_vars -> ../../../000_cross_env_vars
	|   |   |   `-- env_specific
	|   |   |-- backstage
	|   |   `-- gamedb
	|   |-- hosts
	|   `-- host_vars
	|       |-- erl01.prd.chenyanshan.github.io
	|       |-- erl02.prd.chenyanshan.github.io
	|       |-- java01.prd.chenyanshan.github.io
	|       `-- java02.prd.chenyanshan.github.io
	`-- tst
	    |-- group_vars
	    |   |-- all
	    |   |   |-- 000_cross_env_vars -> ../../../000_cross_env_vars
	    |   |   `-- env_specific
	    |   |-- backstage
	    |   `-- gamedb
	    |-- hosts
	    `-- host_vars
	        |-- erl01.tst.chenyanshan.github.io
	        `-- java01.tst.chenyanshan.github.io

和其他实现使用同一个 `group_vars` 文件夹下面不同的文件不同，这里直接直接将环境划分成不同的能独立给 Ansible 使用的文件夹，并且用 `-i` 选项区分:

	 -i INVENTORY, --inventory-file=INVENTORY
	                        specify inventory host path
	                        (default=/etc/ansible/environments/tst) or comma
	                        separated host list.

当然在配置文件中也可以指定：

	$ vim /etc/ansible/ansible.cfg
	[defaults]
	inventory      = /etc/ansible/environments/tst

这个是变量配置文件中的具体内容(我已将敏感内容去掉):

	$ cat environments/prd/group_vars/{all/env_specific,gamedb}
	---
	env: prd
	env_path: /etc/ansible/environments/prd
	connect_address:  
	redis_address: redis.rds.aliyuncs.com 
	redis_password: password
	redis_port: 6379
	mysql_address: mysql.rds.aliyuncs.com
	mysql_port: 3306
	---
	# game db database name
	game_db_name: db_name
	# game db username
	game_db_user: username
	# game db password
	game_db_password: password
	
	$ cat environments/prd/host_vars/erl01.prd.chenyanshan.github.io
	---
	work_port: 8881
	ipv4_address: 192.168.1.174

## roles配置

Role 是 Ansible 里面一个非常重要的内容，它于 ansible 1.2 被引入，用于层次性，结构性的组织 playbook 。如果想使用 Ansible，Role 是必须要会的。这里就不讲 Role 是如何应用的了。

	/apps/playbooks/roles/tomcat
	.
	|-- files     # tasks 中的任务使用 file or copy 调用文件的文件位置
	|   |-- configure
	|   |   |-- catalina.sh
	|   |   |-- server.xml
	|   |   |-- tomcat_exa
	|   |   |-- tomcat_prd
	|   |   `-- tomcat_tst
	|   |-- install
	|   |   |-- apache-tomcat-7.0.75.tar.gz
	|   |   `-- tomcat
	|   |-- update_back
	|   |   |-- backstage.war
	|   `-- update_manager
	|       |-- check_version.sh
	|       `-- web_login.war
	|-- tasks   # tasks 
	|   |-- configure.yml
	|   |-- install.yml
	|   |-- main.yml
	|   |-- update_back.yml
	|   `-- update_login.yml
	`-- templates   # task 中的任务使用 template 模块调用文件的文件位置。
	    |-- update_back
	    |   |-- jdbc.properties.j2
	    |   `-- JedisPoolConfig.properties.j2
	    `-- update_manager
	        `-- mpnet-tools.xml.j2

这里 tasks 分了多个任务文件，是因为很多时候都不需要用到 install 和 configure 功能，而且 update 也有两种(因为都是运行 tomcat 上面，所以放在一起)，这里讲下控制方法。

	$ cat tasks/main.yml 
	- name: Include install.yml 
	  include: install.yml 
	  when: install
	
	- name: Include configure.yml 
	  include: configure.yml 
	  when: configure
	
	- name: Include update_back.yml 
	  include: update_back.yml 
	  when: update_back
	
	- name: Include update_login.yml 
	  include: update_login.yml 
	  when: update_login
	
	- name: Restart tomcat service
	  command: service tomcat restart
	  when: configure or update_back or update_login

上面是 main 文件的结构，里面都是调用其他任务文件执行，但是它加了个判断，只有某个参数为真的时候才执行。

	$ pwd; cat update_backstage.yml 
	/apps/playbooks
	- hosts: backs 
	  vars_files:
	    - "{{ env_path }}/group_vars/gamedb"    # 调用变量文件
	    - "{{ env_path }}/group_vars/backstage"  # evn_path 变量是在 all 变量定义的，所以无需调用
	  tasks:
	  - include_role:
	      name: tomcat 
	    vars:
	        install: false
	        configure: false
	        update_back: true
	        update_login: false 

这样，就能完美实现想使用哪个功能，就使用哪个功能，想使用哪个功能，就将其改成 true 就行。

## 结合 SVN

到这个地方，基本上 Ansible 所实现的地方基本上就已经实现了。但是其实到这个程度，做更新还是很繁琐，因为需要更新，就需要上传必要的代码文件到服务器。生产环境更新还不频繁，但是测试环境更新实在频繁，每次更新，都由开发将文件传过来，然后再传到服务器，再更新。实在太麻烦。所以在这里就使用 SVN 的钩子脚本，让某个目录一旦更新就自动同步到服务器，而且执行更新到测试环境的操作。当然，你也可以只同步文件，不自动更新。使用 SVN 还不止便捷一个好处，在出现故障需要执行版本回退的时候，SVN 上面回退一个版本直接更新，更方便。

	#!/bin/bash
	# auther: yanshanchen@hotmail.com    website: http://chenyanshan.github.io
	# create time: 2017.09.15 
	# version: 2 
	
	REPOS="$1"
	REV="$2"
	
	export LANG=en_US.UTF-8
	
	SVN_BIN=/usr/bin/svn
	
	# backstage update
	backstage_state=`${SVN_BIN} update /apps/tempdata/update/backstage --username=username --password=password | wc -l`
	if [ ${backstage_state} -gt 2 ]
	then
	        /usr/bin/scp  /apps/tempdata/update/backstage/backstage.war chenys@remote_host:/apps/playbooks/roles/tomcat/files/update_back
	        /usr/bin/ssh chenys@remote_host "/usr/bin/ansible-playbook -i /etc/ansible/environments/tst/ /apps/playbooks/update_backstage.yml"
	fi
	

这里我已经将钩子脚本删减到一个内容，其实就是在钩子脚本触发的时候，检测指定的目录有无更新，如果有，就执行同步文件并更新到测试环境的操作。其中的` -i /etc/ansible/environments/tst/ ` 就是指定测试环境。这样的命令太长，太繁琐，可以使用别名。或者自己写个脚本。接受几个参数的方式执行。

然后美滋滋之路开始了，软件的安装方便快捷，测试环境的更新无需关心，正式环境的更新频率不会太高。基本上更新这块没有太多事情了。but，如果服务器出现故障怎么办？这个问题也很麻烦，大晚上如果服务器出现故障需要去解决怎么想也是不爽。那到底应该怎么办呢？欲知后事如何，请听下回分解。
