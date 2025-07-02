#!/bin/bash

# Cloudflare WARP Endpoint & Port Finder (Advanced, 2-Stage, Wide Port Scan, Progress Bar)
# Stage 1: Find the 6 best (lowest latency) endpoints from all major Cloudflare WARP IPv4 ranges.
# Stage 2: For each of the top 6 IPs, scan a wide range of well-known and commonly open ports to find the best open port with the lowest ping.
# Output: The best endpoints and their optimal open ports for WARP usage.

# --------------------------- CONFIGURATION -------------------------------

ranges=(
  "162.159.192"
  "162.159.193"
  "188.114.96"
  "188.114.97"
  "188.114.98"
  "188.114.99"
  "188.114.100"
  "188.114.101"
  "188.114.102"
  "188.114.103"
)

# A wide range of commonly used and relevant ports for Cloudflare, WARP, VPN, and bypassing restrictions
ports=(
  443 2408 53 8080 8443 2053 2096 2083 2087 2052 2082 2086 500 3306 143 993 995 587 2525
  6666 8444 2080 5060 1194 123 8880 8883 8448 5222 5228 3478 1935 10000 65432
)

max_jobs=64         # Maximum parallel jobs (tune for your hardware)
max_ping=50         # Max ping for stage 1 (ms)
ip_count=6          # Number of top IPs to scan ports on

# ------------------------ STAGE 1: IP LATENCY SCAN ----------------------

tmpfile1=$(mktemp)
total_ips=$((${#ranges[@]} * 256))
tested=0

progress_bar() {
  percent=$(( 100 * $1 / $2 ))
  bar_size=40
  filled=$(( bar_size * $1 / $2 ))
  empty=$(( bar_size - filled ))
  bar=$(printf "%0.s#" $(seq 1 $filled))
  spaces=$(printf "%0.s-" $(seq 1 $empty))
  printf "\rProgress: [%s%s] %d%% (%d/%d)" "$bar" "$spaces" "$percent" "$1" "$2"
}

ping_ip() {
  ip="$1"
  ping_time=$(ping -c 1 -W 1 "$ip" 2>/dev/null | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
  if [[ -n "$ping_time" ]]; then
    ping_int=${ping_time%.*}
    if (( ping_int <= max_ping )); then
      echo "$ip $ping_int" >> "$tmpfile1"
    fi
  fi
}

export -f ping_ip
export tmpfile1
export max_ping

for range in "${ranges[@]}"; do
  for i in $(seq 0 255); do
    ip="$range.$i"
    ping_ip "$ip" &
    ((tested++))
    if (( tested % 50 == 0 || tested == total_ips )); then
      progress_bar "$tested" "$total_ips"
    fi
    while (( $(jobs -r | wc -l) >= max_jobs )); do
      sleep 0.01
    done
  done
done

wait
progress_bar "$total_ips" "$total_ips"
echo

# Select the top N fastest IPs
if [[ -s "$tmpfile1" ]]; then
  mapfile -t best_ips < <(sort -k2 -n "$tmpfile1" | head -n${ip_count} | awk '{print $1}')
else
  echo "No fast endpoint found."
  rm -f "$tmpfile1"
  exit 1
fi

# ---------------- STAGE 2: PORT SCAN ON TOP IPs -------------------------

tmpfile2=$(mktemp)
total_tests=$((${#best_ips[@]} * ${#ports[@]}))
tested=0

echo -e "\nScanning a wide range of ports on the top $ip_count endpoints..."

# Check if TCP port is open (fast & silent)
port_open() {
  ip="$1"
  port="$2"
  timeout 0.7 bash -c "</dev/tcp/$ip/$port" 2>/dev/null
}

# If port is open, log it with ping
ping_to_port() {
  ip="$1"
  port="$2"
  if port_open "$ip" "$port" ; then
    ping_time=$(ping -c 1 -W 1 "$ip" 2>/dev/null | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
    if [[ -n "$ping_time" ]]; then
      ping_int=${ping_time%.*}
      echo "$ip $port $ping_int" >> "$tmpfile2"
    fi
  fi
}

export -f port_open
export -f ping_to_port
export tmpfile2

for ip in "${best_ips[@]}"; do
  for port in "${ports[@]}"; do
    ping_to_port "$ip" "$port" &
    ((tested++))
    if (( tested % 10 == 0 || tested == total_tests )); then
      progress_bar "$tested" "$total_tests"
    fi
    while (( $(jobs -r | wc -l) >= max_jobs )); do
      sleep 0.01
    done
  done
done

wait
progress_bar "$total_tests" "$total_tests"
echo

# Show best open port (lowest ping) for each IP
echo -e "\nBest Cloudflare WARP Endpoints and Open Ports (from the fastest $ip_count IPs):"
if [[ -s "$tmpfile2" ]]; then
  awk '{print $1}' "$tmpfile2" | sort -u | while read ip; do
    grep "^$ip " "$tmpfile2" | sort -k3 -n | head -n1
  done | sort -k3 -n | head -n$ip_count | awk '{printf "%-15s %-6s %sms\n", $1, $2, $3}'
else
  echo "No open port found on the top $ip_count endpoints."
fi

rm -f "$tmpfile1" "$tmpfile2"
