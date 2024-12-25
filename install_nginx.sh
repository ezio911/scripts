#!/bin/bash

[[ `id -u` != 0 ]] && echo "请使用root用户执行此脚本" && exit 1

id nginx &>/dev/null
[[ $? == 0 ]] || useradd -s /sbin/nologin -r nginx

[[ -e /apps/nginx ]] || mkdir -p /apps/nginx

yum -y install gcc pcre-devel openssl-devel zlib-devel &>/dev/null

cd /usr/local/src
wget https://nginx.org/download/nginx-1.18.0.tar.gz
[[ $? == 0 ]] || echo "wget下载nginx源码失败,请检查网络" || exit 1
tar zxvf nginx-1.18.0.tar.gz
cd nginx-1.18.0

./configure --prefix=/apps/nginx \
--user=nginx \
--group=nginx \
--with-http_ssl_module \
--with-http_v2_module \
--with-http_realip_module  \
--with-http_stub_status_module \
--with-http_gzip_static_module \
--with-pcre \
--with-stream \
--with-stream_ssl_module \
--with-stream_realip_module

if [[ $? != 0 ]];then
    echo "源码编译失败,请检查环境,然后重新执行脚本"
    cd ..
    rm -rf nginx-1.18.0*
    exit 1
fi

make -j 2 && make install
chown -R nginx:nginx /apps/nginx

mkdir -p  /apps/nginx/run
sed -i '/pid/s/.*/pid \/apps\/nginx\/run\/nginx.pid; /' /apps/nginx/conf/nginx.conf
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

ln -sv /apps/nginx/sbin/nginx /usr/sbin/ 
systemctl start nginx && systemctl status nginx
