#!/bin/bash

# ============================
# Cloudflare WARP IP Finder (Parallel, Top 4, All Global Ranges)
# Fastest and lowest ping endpoints (.0 to .20 of each Cloudflare WARP /24 range)
# Only endpoints with ping ≤ 20ms are considered
# ============================

# All known Cloudflare WARP IPv4 ranges (update as needed)
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

max_ping=20
ips_per_range=21      # Only .0 to .20 in each /24
tmpfile=$(mktemp)
max_jobs=32           # Number of concurrent pings; adjust as needed

ping_ip() {
  ip="$1"
  ping_time=$(ping -c 1 -W 1 "$ip" | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
  if [[ -n "$ping_time" ]]; then
    ping_int=${ping_time%.*}
    if (( ping_int <= max_ping )); then
      echo "$ip $ping_int" >> "$tmpfile"
      echo "$ip : $ping_time ms (OK)"
    else
      echo "$ip : $ping_time ms (too high)"
    fi
  else
    echo "$ip : unreachable"
  fi
}

echo "Parallel scanning of Cloudflare WARP IPs (.0 to .20, ping ≤ ${max_ping}ms)..."
job_count=0
for range in "${ranges[@]}"; do
  for last_octet in $(seq 0 $((ips_per_range-1))); do
    ip="$range.$last_octet"
    ping_ip "$ip" &
    ((job_count++))
    if (( job_count % max_jobs == 0 )); then
      wait
    fi
  done
done
wait

if [[ -s "$tmpfile" ]]; then
  echo "------------------------------"
  echo "Top 4 Best WARP Endpoints (ping ≤ ${max_ping}ms):"
  sort -k2 -n "$tmpfile" | head -n4 | awk '{printf "%-15s %sms\n", $1, $2}'
else
  echo "No endpoint was reachable under ${max_ping}ms."
fi

rm -f "$tmpfile"
