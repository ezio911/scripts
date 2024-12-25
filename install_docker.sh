#!/bin/bash


[[ `id -u` != 0 ]] && echo "请使用root用户执行此脚本" && exit 1

check_commond(){
    if [[ $? != 0 ]];then
        echo "$1 执行失败" && exit 1
    fi
}

install_docker(){

        type docker &>/dev/null
        [[ $? == 0 ]] && read -p "docker已存在,是否需要重装:[y/n]:" flag || flag=y
        [[ $flag != "y" ]] && echo "取消重装docker" && exit 1

        yum remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
        rm -rf /var/lib/docker
        rm -rf /var/lib/containerd

        # If prompted to accept the GPG key : 060A 61C5 1B55 8A7F 742B 77AA C52F EB6B 621E 9F35
        # Install the yum-utils package and set up the repository.
        yum install -y yum-utils
        check_commond "安装yum-utils"
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

        # install docker
        yum -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        check_commond "安装docker"

tee /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
        "https://cf-workers-docker-io-bkt.pages.dev"
        "https://registry.docker-cn.com"
        ],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF
    systemctl daemon-reload
    systemctl restart docker

}

install_docker_compose(){
    curl -SL https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
    check_commond "安装docker-compose失败"
    chmod +x /usr/local/bin/docker-compose

}
install_docker
check_commond "安装docker"
install_docker_compose
check_commond "安装docker-compose"
