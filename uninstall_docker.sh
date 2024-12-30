#!/bin/bash

# 停止 Docker 服务
echo "Stopping Docker services..."
sudo systemctl stop docker
sudo systemctl stop docker.socket

# 卸载 Docker 软件包
echo "Uninstalling Docker packages..."
sudo apt-get purge -y docker-engine docker docker.io containerd runc

# 删除 Docker 数据目录
echo "Removing Docker data directories..."
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

# 删除配置文件
echo "Removing Docker configuration files..."
sudo rm -rf /etc/docker
sudo rm -f /etc/default/docker

# 清理 Docker 网络配置
echo "Cleaning up Docker network interfaces..."
sudo ip link delete docker0 2>/dev/null || echo "No docker0 interface found."

# 搜索和删除残留文件
echo "Removing residual Docker files..."
sudo find / -name '*docker*' -exec rm -rf {} + 2>/dev/null

# 清理系统缓存
echo "Cleaning up system packages..."
sudo apt-get autoremove -y
sudo apt-get autoclean

echo "Docker has been completely uninstalled."