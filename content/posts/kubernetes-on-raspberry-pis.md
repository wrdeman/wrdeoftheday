---
title: "Running Kubernetes on Raspberry PIs"
date: 2020-10-13T10:05:42Z
draft: false
---
### Another blog about kubernetes and raspberry pis

Why am I doing this? Why don't you use minikube? It's something to do.

<!--more-->

I have followed this blog post: https://uthark.github.io/post/2020-09-02-installing-kubernetes-raspberrypi/ and where possible convert it into ansible.

The code is at https://github.com/wrdeman/wrde-pi

### Topology

I will have 4 Pis for the kubernetes cluster, a master and three workers, and a Pi acting as a network file system. They Pis are a combination of 4 and 3Bs.

### Requirements
1. ansible
2. ansible.posix 

### Preparing the Pis 

The first thing to do is to install a OS image onto the Pis' SD card. This is a bit boring. I am using an Ubuntu image and have dutifully followed: https://ubuntu.com/download/raspberry-pi


Next is to fix the IP addresses for each Pi. I could have probably done this using ansible but ... I didn't. Ubuntu uses `netplan` for network configuration. 


On each Pi you will need to edit the network configuration file. Ubuntu uses [netplan](https://netplan.io/) and these are found in `/etc/netplan/*.yaml`. 

In our case we edit `/etc/netplan/50-cloud-init.yaml`

```
network:
  version: 2
  ethernets:
     enp3s0:
      dhcp4: no
      addresses:
        - 192.168.121.221/24
      gateway4: 192.168.121.1
      nameservers:
          addresses: [8.8.8.8, 1.1.1.1]
```
The address gateway is the default gatework of your router and the IP in the addresses is the IP of your Pi.

Finally in `/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg` add

```
network: {config: disabled}
```

then apply these changes:

```
sudo netplan apply
```

On your host machine you can give the Pis nice names by editing `/etc/hosts`:

```bash
192.168.0.30 k8-worker3
192.168.0.31 k8-master
192.168.0.39 k8-worker2
192.168.0.40 k8-worker1
192.168.0.29 k8-nfs
```

### Ansible and Pi setup

(Ansible)[https://docs.ansible.com/ansible/latest/index.html] is an automation tool to make configuring and deploying systems easier. Like much current think we are defining the system in code making it repeatable etc.

The aim here is to deploy docker on the k8s. We begin by grouping our Pis into logical units - a master, workers, nfs and define these in the hosts file.


`/etc/hosts`
```
[master]
k8-master ansible_user=ubuntu

[workers]
k8-worker1 ansible_user=ubuntu
k8-worker2 ansible_user=ubuntu
k8-worker3 ansible_user=ubuntu

[nfs]
k8-nfs ansible_user=ubuntu

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

where we need to define our ansible user and python interpreter.

#### docker

We need to enable memory control groups or cgroups for docker to work on the Pis. We need to add the following line to `/boot/firmware/cmdline.txt`

``` 
cgroup_enable=memory swapaccount=1 cgroup_memory=1 cgroup_enable=cpuset
``` 

This is a bit of a fudge but I create a playbook to handle this initial setup which I apply to the master and the workers:

`initial.yml`

```
- hosts: masters,workers
  roles: 
    - initial
```

and an accompanying task which adds the new settings and reboots each pi


`roles/initial/tasks/main.yml`

```
- name: add cgroups
  become: true
  lineinfile:
    dest: /boot/firmware/cmdline.txt
    regexp: '$'
    line: " cgroup_enable=memory swapaccount=1 cgroup_memory=1 cgroup_enable=cpuset"

- name: reboot to apply cgroups
  become: true
  reboot:
```

I then apply this  

```
ansible-playbook -i hosts initial.yml
```

and we are in a position to install docker. It is a straight forward installation on linux: install some dependencies, add a new repository for docker - noting its arm64 architecture, then install docker. Once docker is installed we need to update the daemon configuration to let systemd know to use cgroups. I have include all in the following gists:

{{< gist wrdeman 8b7de7a7b28cf764f59bddd1548188d5 >}}


#### kubernetes

In a similar manner we can install kubernetes.  There is no release candidate for ubuntu 20.04 so I am using that from 18.04. So we mark the kubernetes packages as `hold` so they are not updated or upgraded. Kubernetes needs the iptables to see bridged traffic [see here](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#letting-iptables-see-bridged-traffic) and for this we make use of some specific POSIX functions and this requiring us to install `ansible.posix`:

```
ansible-galaxy collection install ansible.posix
```

{{< gist wrdeman 9bb38318ebaec127a4351a5296d3cbef >}}


### Next steps

1. attached an NFS
2. create test app django/postgresql
