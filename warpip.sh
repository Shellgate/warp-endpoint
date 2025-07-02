#!/bin/bash

# warpip.sh - Ultimate Cloudflare WARP Endpoint & Open Port Finder
# Author: Shellgate

set -e

### CONFIGURATION ###
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
ip_count=6
max_jobs=64
max_ping=50
port_timeout=0.4

### FUNCTIONS ###
progress_bar() {
  percent=$(( 100 * $1 / $2 ))
  bar_size=40
  filled=$(( bar_size * $1 / $2 ))
  empty=$(( bar_size - filled ))
  bar=$(printf "%0.s#" $(seq 1 $filled))
  spaces=$(printf "%0.s-" $(seq 1 $empty))
  printf "\rProgress: [%s%s] %d%% (%d/%d)" "$bar" "$spaces" "$percent" "$1" "$2"
}

stage1_ping() {
  ip="$1"
  ping_time=$(ping -c 1 -W 1 "$ip" 2>/dev/null | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
  if [[ -n "$ping_time" ]]; then
    ping_int=${ping_time%.*}
    if (( ping_int <= max_ping )); then
      echo "$ip $ping_int"
    fi
  fi
}

stage2_portscan() {
  ip="$1"
  port="$2"
  timeout "$port_timeout" bash -c "echo >/dev/tcp/$ip/$port" 2>/dev/null && echo "$port"
}

### MAIN ###

echo "[warpip] Stage 1: Scanning endpoints for lowest latency..."
tmpfile1=$(mktemp)
total_ips=$((${#ranges[@]} * 256))
tested=0

export -f stage1_ping

for range in "${ranges[@]}"; do
  for i in $(seq 0 255); do
    ip="$range.$i"
    (
      stage1_ping "$ip"
    ) >> "$tmpfile1" &
    ((tested++))
    if (( tested % 50 == 0 || tested == total_ips )); then
      progress_bar "$tested" "$total_ips"
    fi
    while (( $(jobs -r | wc -l) >= max_jobs )); do sleep 0.01; done
  done
done

wait
progress_bar "$total_ips" "$total_ips"
echo

if [[ ! -s "$tmpfile1" ]]; then
  echo "[warpip] No fast endpoint found. Exiting."
  rm -f "$tmpfile1"
  exit 1
fi

mapfile -t best_ips < <(sort -k2 -n "$tmpfile1" | head -n${ip_count} | awk '{print $1}')
echo "[warpip] Top $ip_count endpoints:"
for ip in "${best_ips[@]}"; do echo " - $ip"; done

### Stage 2: Full port scan ###
for ip in "${best_ips[@]}"; do
  echo -e "\n[warpip] Scanning all 65535 TCP ports on $ip (this may take a while)..."
  tmp_port=$(mktemp)
  tested_ports=0

  export -f stage2_portscan
  export ip
  export port_timeout

  for port in $(seq 1 65535); do
    (
      stage2_portscan "$ip" "$port"
    ) >> "$tmp_port" &
    ((tested_ports++))
    if (( tested_ports % 200 == 0 || tested_ports == 65535 )); then
      progress_bar "$tested_ports" 65535
    fi
    while (( $(jobs -r | wc -l) >= max_jobs )); do sleep 0.003; done
  done
  wait
  progress_bar 65535 65535
  echo

  if [[ -s "$tmp_port" ]]; then
    echo "[warpip] $ip - Open TCP ports:"
    cat "$tmp_port" | tr '\n' ' '
    echo
    # Optionally, pick the lowest port (or test wireguard handshake if desired)
    best_port=$(sort -n "$tmp_port" | head -n1)
    echo "[warpip] $ip - Recommended port: $best_port"
  else
    echo "[warpip] $ip - No open ports found."
  fi
  rm -f "$tmp_port"
done

rm -f "$tmpfile1"

echo -e "\n[warpip] DONE! Use the best IP:PORT above for your WARP setup."
