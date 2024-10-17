#!/bin/bash

# 检测并开启swap
if ! swapon --show | grep -q "swap"; then
    swapsize=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') * 2 * 1024 ))
    fallocate -l ${swapsize} /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# 更新软件包并安装必需的软件
dnf update -y
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin bind-utils tuned zram-generator

# 启用并立即启动 Docker 和 Tuned 服务
systemctl enable --now docker
systemctl enable --now tuned

# 修改时区为上海
timedatectl set-timezone Asia/Shanghai

# 修改SSH端口
sed -i 's/#Port 22/Port 9399/' /etc/ssh/sshd_config
systemctl restart sshd

# 运行NextTrace安装脚本
bash -c "$(curl -Ls https://github.com/sjlleo/nexttrace/raw/main/nt_install.sh)"

# 安装Python
curl https://mise.run | sh
mise use -g python@3.10

# 启用zram
echo -e "[zram0]\nzram-size = ram / 2\ncompression-algorithm = zstd" | tee /etc/systemd/zram-generator.conf

# 启动dnsproxy并替换系统dns
cd /root/dnsproxy
docker compose pull
docker compose up -d
bash <(curl -L -s https://raw.githubusercontent.com/1-stream/1stream-public-utils/main/dns-change.sh) 127.0.0.1

# 启动proxy
cd /root/proxy
docker compose pull
docker compose up -d

echo "所有任务完成！"
