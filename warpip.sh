#!/bin/bash

# warpip - Ultimate Cloudflare WARP Endpoint & Port Scanner
# Finds the best Cloudflare WARP endpoints and real usable open ports, fully automatic.
# Author: Shellgate

set -e

# ----------- CONFIGURATION -------------
# Main Cloudflare WARP endpoint IP ranges
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

# How many top endpoints to deeply scan
ip_count=6

# How many parallel jobs (tune for your hardware)
max_jobs=64

# Max ping (ms) to be considered "fast" in stage 1
max_ping=50

# Timeout for port scan in seconds
port_timeout=0.4

# ----------- STAGE 1: FASTEST IP SELECTION -------------
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

echo "[warpip] Stage 1: Scanning all endpoints for fastest ping..."
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

if [[ -s "$tmpfile1" ]]; then
  mapfile -t best_ips < <(sort -k2 -n "$tmpfile1" | head -n${ip_count} | awk '{print $1}')
  echo "[warpip] Top $ip_count fastest endpoints:"
  for ip in "${best_ips[@]}"; do echo " - $ip"; done
else
  echo "[warpip] No fast endpoint found. Exiting."
  rm -f "$tmpfile1"
  exit 1
fi

# ----------- STAGE 2: FULL PORT SCAN ON BEST IPS -------------

echo -e "\n[warpip] Stage 2: Scanning all 65535 TCP ports on top $ip_count endpoints (may take time)..."

for ip in "${best_ips[@]}"; do
  echo -e "\n[warpip] Scanning all ports on $ip ..."
  tmp_port=$(mktemp)
  tested_ports=0

  port_scan() {
    port="$1"
    timeout "$port_timeout" bash -c "</dev/tcp/$ip/$port" 2>/dev/null && echo "$port" >> "$tmp_port"
  }
  export -f port_scan
  export ip
  export tmp_port
  export port_timeout

  for port in $(seq 1 65535); do
    port_scan "$port" &
    ((tested_ports++))
    if (( tested_ports % 200 == 0 || tested_ports == 65535 )); then
      progress_bar "$tested_ports" 65535
    fi
    while (( $(jobs -r | wc -l) >= max_jobs )); do
      sleep 0.003
    done
  done
  wait
  progress_bar 65535 65535
  echo

  if [[ -s "$tmp_port" ]]; then
    # For each open port, do an extra WARP suitability check (optional: basic handshake/response, but here just ping again for speed)
    best_port=""
    best_time=999999
    while read port; do
      # Try ping again to see latency (optional: can be skipped for speed)
      ping_time=$(ping -c 1 -W 1 "$ip" 2>/dev/null | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
      ping_int=${ping_time%.*}
      if [[ -n "$ping_time" && "$ping_int" -lt "$best_time" ]]; then
        best_time="$ping_int"
        best_port="$port"
      fi
    done < "$tmp_port"
    echo "[warpip] $ip - Best open port: $best_port (ping: ${best_time}ms)"
    echo "[warpip] All open ports on $ip: $(tr '\n' ' ' < "$tmp_port")"
  else
    echo "[warpip] $ip - No open ports found."
  fi
  rm -f "$tmp_port"
done

rm -f "$tmpfile1"
echo -e "\n[warpip] Scan complete. Use the best IP:PORT above for your WARP configuration!"
