#!/bin/bash

# Update the package list
sudo apt-get update

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

# Install eksctl
echo "Installing eksctl..."
curl -s "https://api.github.com/repos/weaveworks/eksctl/releases/latest" | \
grep "browser_download_url.*linux_amd64.tar.gz" | \
cut -d : -f 2,3 | \
tr -d \" | \
wget -qi -
tar -xzf eksctl_*.tar.gz -C /tmp && rm eksctl_*.tar.gz
sudo mv /tmp/eksctl /usr/local/bin
eksctl version

# Install AWS CLI v2
echo "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

# Clean up
rm kubectl awscliv2.zip
rm -rf aws

echo "All tools have been installed successfully."

# Optional: Configure AWS CLI
echo "To configure AWS CLI, run: aws configure"
