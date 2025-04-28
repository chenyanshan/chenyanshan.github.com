---
layout: page
title:  自动化运维之 Zabbix 自动发现并监控
date:   2017-10-05 20:52:07
categories: Automation
tags: Automation
---

前面已经介绍了服务的自动安装，自动配置，自动更新等。这里主要是讲 Zabbix 在当前运维架构中的应用。当然，还是和之前一样，并不会讲整个软件怎么用，只介绍在我应用的范围中的比较重要的点。其实之前一直有朋友叫我写 Zabbix 的博文，但是 Zabbix 这个东西主要是图形化的，用博文的方式描述其详细应用实在麻烦，就一直没写。不过如果有童鞋有什么疑问，倒是可以来找我。直接邮箱联系我就行。

zabbix-server 的安装只有单台，直接安装就行，配置上面也没有什么特殊的地方，zabbix-agentd 每台服务器都需要安装，而且配置各有不同，所以 zabbix-agentd 是由 Ansible 进行安装的。

	/apps/playbooks/roles/zabbix_agentd
	.
	|-- files
	|   |-- externalscripts
	|   |   |-- erlang_service_state.sh
	|   |   |-- iops.sh
	|   |   `-- tps.sh
	|   |-- sudoers
	|   |-- zabbix-3.0.8.tar.gz
	|   |-- zabbix_agentd
	|   `-- zabbix_agentd.conf.d
	|       |-- zabbix_agentd.iostat.conf
	|       |-- zabbix_agentd.mysql_status.conf
	|       |-- zabbix_agentd.netstat.conf
	|       `-- zabbix_agentd.service_status.conf
	|-- tasks
	|   `-- main.yml
	`-- templates
	    `-- zabbix_agentd.conf.j2

这里是选择在其他服务器上面测试好必要的配置和脚本，然后直接将配置拷贝过去。我上面所展示的配置文件和脚本文件主要都是给 `UserParameter` 使用，用于自己定义监控项目的。基本没有太多特殊的地方。

## 配置
这里配置主要是讲自动发现，以及自动发现后的操作，当然在这里用自动注册的效果也差不多。

### 1. 配置好模版
![](/images/Automation-3/DraggedImage.png)
你有什么服务，就配置好什么模版。比如 Nginx，你就需要监控 Nginx 的进程，可能还需要监控某个页面的访问情况以保证服务确实可用。
还需要更加情况配置触发器(Triggers)，比如 Nginx 服务已经有几次检测为没有运行了。或者是页面访问出了问题。

### 2. 配置 Actions
![](/images/Automation-3/DraggedImage-1.png)
根据 Triggers 配置 Actions，某个 Triggers 被触发了执行什么操作，我一般是先执行故障恢复(重启服务或者其他操作)，多次执行故障恢复失败之后(一般两次)就会执行告警操作，根据时间和严重级别去通知某些组和某些人。我之前用的是微信通知，后面发现微信有时候我自己都无法及时收到，就改成了短信。

![](/images/Automation-3/DraggedImage-2.png)

这样基本上大部分问题都能自动故障恢复，而不能恢复也能及时通知到位，加上我在应用层面又做了高可用，就算某台服务器出了故障，也不需要立马跑过去修。

### 3. 自动发现
到上面的程度其实已经很轻松了，BUT，每加一台服务器，都需要配置一下，让它链接到特定的模版，特定的组，为其设置主机名，这是任何一名“懒人”都无法忍受的。而且服务器如果非常多的情况下，整理起来也烦。这里需要说明一下，服务器如果特别多的话，建议使用自动注册，不用使用自动发现。自动发现的话，在 agent 到 server 建立关联都是 server 在消耗资源，server 只有一台，如果 agent 特别多的话，对 server 的压力也是很大的，自动注册却是相反，server 消耗不了太多资源。这里就不多bb了，讲自动发现如何实现，并且如何优雅的应用。

先创建自动发现规则：
`Configuration --> Discovery --> Create discovery rule`

![](/images/Automation-3/DraggedImage-3.png)

 主要是 `ip range` 和 `Checks type` ，`ip range` 根据自己的服务器所属的网段填，`Checks type` 选择 `Zabbix agent`，如果想监控路由器或者交换机等设备的话，也可以使用 SNMP 协议相关的项目。

配置 Actions :
`Configuration --> Actions --> Event source ( Discovery ) --> Create action`
这个就是检测到主机之后做什么操作了。

![](/images/Automation-3/DraggedImage-4.png)

Actions 配置中，Action 基本无用，不说它，
Conditions 是条件，如果触发了这个条件，就执行后面的 Operations。
由图所示，规则是 `A and B and C` ，这个规则都可以自己定义，or 和 and 可以根据需求使用。
`Received value like back`: Received value 这个东西的具体含义我找了一圈都没找到，国内文档都是将其用来区分服务器是 Windows 还是 Linux 使用，官方文档也很模糊，最后我测试了一下，里面应该是很多的信息，比如主机名，主机内核版本等，`like back` 的意思很简单，就是 Received value 这个字符串匹配 `back` 这个字符串。如果 Received value 里面有 `back` 的字符串，它就算满足条件。这里是用于匹配主机名使用的，当然你如果填 Linux，那么所有的 Linux 服务器都会满足条件。如果你数据库服务器的主机名是 `db01.prd.chenyanshan.github.io`，你想匹配它，就可以用 `like db` 来匹配。
`Service type = Zabbix agent`：不是很重要，可填可不填，
`Host IP = 192.168.1.1-254`： 就是自动发现规则中的 `ip range`

![](/images/Automation-3/DraggedImage-5.png)

如果上面的 `Conditions` 满足条件，那么这里的 `Operations ` 就会被触发，`Add host` 是必须的，再就是 `Link to templates` (链接模版)，之前创建的 Template 就可以用在这里，比如上图就链接了 `Disk Vda IO stat, Network stat, Template OS Linux` 这些公用模版，还链接了 `Tomcat service state` 这个后台 Tomcat 服务器专用模版，而且触发器、故障恢复机制、告警机制全部都链接到了这个模版上。

## 效果

![](/images/Automation-3/DraggedImage-6.png)

这里都是自动发现的，不同的应用服务器链接不同的模版。实现不同的服务监控。

到这里基本上就实现了美滋滋之路，服务器一上线，一条命令自动安装服务，自动启动服务，然后 Zabbix 自动将其纳入监控范围。还有故障恢复，故障告警。更新频繁的测试环境无需关心，需要运维关注的正式环境的更新更新频率低。而且更新过程也非常简单。这个时候基本上就解放了，可以做自己的事情，比如学学 Python，弄弄 kubernetes，搞搞 MySQL。
对了，这几篇博文都不是按照文档的形式写的，只是简单的介绍了一下思路，如果也想踏上美滋滋之路，但是中间遇到了什么问题，可以通过邮箱联系我。





