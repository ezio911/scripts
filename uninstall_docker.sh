#!/bin/bash

set -e

echo "Stopping Docker service..."
sudo systemctl stop docker || true
sudo systemctl disable docker || true

echo "Removing Docker packages..."
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true

echo "Cleaning up unused dependencies..."
sudo apt-get autoremove -y --purge || true

echo "Removing Docker directories..."
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm -rf /etc/docker
sudo rm -rf /run/docker
sudo rm -rf /var/run/docker.sock

echo "Cleaning Docker-related files..."
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/keyrings/docker.asc
sudo rm -f /usr/bin/docker
sudo rm -f /usr/local/bin/docker

echo "Updating package lists..."
sudo apt-get update

echo "Docker has been completely removed from the system."
