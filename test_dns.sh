#!/bin/bash

# 默认域名
domain=${1:-"baidu.com"}

# 定义 DNS 服务器（基于 UDP 的 IP 地址）
dns_servers=(
    "223.5.5.5"
    "223.6.6.6"
    "119.29.29.29"
    "1.12.12.12"
    "180.76.76.76"
    "8.8.8.8"
    "1.1.1.1"
)

# 定义 DNS over HTTPS (DoH) 的 URL
dns_doh=(
    "https://223.5.5.5/dns-query"
    "https://223.6.6.6/dns-query"
    "https://doh.pub/dns-query"
    "https://1.12.12.12/dns-query"
    "https://doh.360.cn"
    "https://dns.google/dns-query"
    "https://1.1.1.1/dns-query"
)

# 创建临时文件存储结果
temp_file=$(mktemp)

# 测试基于 UDP 的 DNS
echo "正在测试dns延迟,请稍等 $domain..."
for ip in "${dns_servers[@]}"; do
    start_time=$(date +%s%N)
    dig_result=$(dig @$ip $domain +time=1 +tries=1 +nocmd +noquestion +noauthority +noadditional +stats 2>/dev/null | grep "Query time" | awk '{print $4}')
    end_time=$(date +%s%N)
    if [[ -n "$dig_result" ]]; then
        latency=$(echo "scale=3; ($end_time - $start_time) / 1000000" | bc) # 保留3位小数
        # 如果延迟小于 1 毫秒，显示为 0.001 毫秒
        if (( $(echo "$latency < 0.001" | bc -l) )); then
            latency="0.001"
        fi
        echo "$ip (UDP): $latency seconds" >> "$temp_file"
    else
        echo "$ip (UDP): Timeout or Failed" >> "$temp_file"
    fi
done

for url in "${dns_doh[@]}"; do
    time_total=$(curl --connect-timeout 1 -m 1 -w "%{time_total}" -o /dev/null -s "$url?name=$domain&type=A")
    if [[ $? -eq 0 ]]; then
        # 保证输出精度，显示为 3 位小数
        if (( $(echo "$time_total < 0.001" | bc -l) )); then
            time_total="0.001"
        fi
        echo "$url (DoH): $(printf "%.3f" $time_total) seconds" >> "$temp_file"
    else
        echo "$url (DoH): Timeout or Failed" >> "$temp_file"
    fi
done

# 输出按延迟排序的结果
echo
cat "$temp_file" | grep -v "Failed" | sort -k3 -n

# 清理临时文件
rm "$temp_file"
