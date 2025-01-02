#!/bin/bash

# 检查是否以 root 用户运行
if [[ `id -u` != 0 ]]; then
    echo "请使用 root 用户执行此脚本"
    exit 1
fi

# 获取操作系统类型
OS=$(grep -Eo '(CentOS|Ubuntu|Debian|RedHat)' /etc/*release | head -n 1)

# 安装依赖
if [[ $OS == "CentOS" || $OS == "RedHat" ]]; then
    yum -y install gcc pcre-devel openssl-devel zlib-devel wget
    if [[ $? != 0 ]]; then
        echo "YUM 安装依赖失败，请检查网络或系统配置"
        exit 1
    fi
    echo "使用 YUM 安装依赖包"
elif [[ $OS == "Ubuntu" || $OS == "Debian" ]]; then
    apt update && apt -y install gcc make libpcre3 libpcre3-dev zlib1g-dev libssl-dev wget
    if [[ $? != 0 ]]; then
        echo "APT 安装依赖失败，请检查网络或系统配置"
        exit 1
    fi
    echo "使用 APT 安装依赖包"
else
    echo "不支持的操作系统类型"
    exit 1
fi

# 创建 nginx 用户
id nginx &>/dev/null
if [[ $? != 0 ]]; then
    useradd -r -s /sbin/nologin nginx
    if [[ $? != 0 ]]; then
        echo "创建 nginx 用户失败"
        exit 1
    fi
    echo "nginx 用户已创建"
fi

# 下载并编译 Nginx
cd /usr/local/src
wget https://nginx.org/download/nginx-1.23.0.tar.gz
if [[ $? != 0 ]]; then
    echo "下载 Nginx 源码失败，请检查网络"
    exit 1
fi
tar zxvf nginx-1.23.0.tar.gz
cd nginx-1.23.0

./configure --prefix=/apps/nginx \
--user=nginx \
--group=nginx \
--with-http_ssl_module \
--with-http_v2_module \
--with-http_realip_module \
--with-http_stub_status_module \
--with-http_gzip_static_module \
--with-pcre \
--with-stream \
--with-stream_ssl_module \
--with-stream_realip_module
if [[ $? != 0 ]]; then
    echo "Nginx 配置失败，请检查环境"
    cd ..
    rm -rf nginx-1.23.0*
    exit 1
fi

make -j2 && make install
if [[ $? != 0 ]]; then
    echo "Nginx 编译失败"
    exit 1
fi

# 设置文件权限
chown -R nginx:nginx /apps/nginx

# 创建运行目录
mkdir -p /apps/nginx/run
sed -i '/pid/s/.*/pid \/apps\/nginx\/run\/nginx.pid;/' /apps/nginx/conf/nginx.conf

# 创建 systemd 服务文件
cat > /usr/lib/systemd/system/nginx.service << "EOF"
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/apps/nginx/run/nginx.pid
ExecStart=/apps/nginx/sbin/nginx -c /apps/nginx/conf/nginx.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s TERM $MAINPID

[Install]
WantedBy=multi-user.target
EOF

# 创建符号链接
ln -sv /apps/nginx/sbin/nginx /usr/sbin/

# 启动 nginx
systemctl start nginx
systemctl enable nginx

# 配置文件：创建 down.conf
mkdir -p /apps/nginx/conf/conf.d

cat > /apps/nginx/conf/conf.d/down.conf << "EOF"
server {
    listen 80;

    location /down {
        alias /data/;
        autoindex on;
        autoindex_exact_size on;
        autoindex_localtime on;

        add_header Cache-Control "public, max-age=3600";
        expires 1h;

        auth_basic "FBI WARNING!";
        auth_basic_user_file /apps/nginx/conf/conf.d/.htpasswd;
    }
}
EOF

# 确保将 include 配置添加到 http 块内
sed -i '/http {/a \ \ \ \ include /apps/nginx/conf/conf.d/*.conf;' /apps/nginx/conf/nginx.conf

# 生成 .htpasswd 文件（如果传入了用户名和密码）
if [[ ! -z "$1" && ! -z "$2" ]]; then
    echo "生成 .htpasswd 文件"
    if ! command -v htpasswd &>/dev/null; then
        if [[ $OS == "CentOS" || $OS == "RedHat" ]]; then
            yum install -y httpd-tools
        elif [[ $OS == "Ubuntu" || $OS == "Debian" ]]; then
            apt install -y apache2-utils
        fi
    fi
    htpasswd -bc /apps/nginx/conf/conf.d/.htpasswd "$1" "$2"
    echo ".htpasswd 文件已生成"
else
    sed -i '/auth_basic/s/^/  # /' /apps/nginx/conf/conf.d/down.conf
    sed -i '/auth_basic_user_file/s/^/  # /' /apps/nginx/conf/conf.d/down.conf
    echo "未传入用户名或密码，不生成 .htpasswd 文件"
fi

# 重新加载 nginx 配置
systemctl reload nginx

echo "Nginx 安装和配置完成"
