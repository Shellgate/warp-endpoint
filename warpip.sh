#!/bin/bash

# Cloudflare WARP Endpoint Finder (Full Range, Silent, Progress Bar)
# Finds the 4 best (lowest ping) IPs from all known Cloudflare WARP /24 ranges

# All known Cloudflare WARP IPv4 /24 ranges (add/update as needed)
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

max_ping=20      # ms, only keep IPs with ping <= this value
max_jobs=64      # Parallel jobs
tmpfile=$(mktemp)
total_ips=0
ips=()

# Prepare full list of IPs to test (all 256 IPs per range)
for range in "${ranges[@]}"; do
  for last_octet in $(seq 0 255); do
    ips+=("$range.$last_octet")
    ((total_ips++))
  done
done

# Progress bar function
print_progress() {
  percent=$(awk "BEGIN {printf \"%.1f\", ($1/$2)*100}")
  bar_size=40
  filled=$(awk "BEGIN {printf \"%d\", ($1/$2)*$bar_size}")
  bar=$(printf "%0.s#" $(seq 1 $filled))
  empty=$(printf "%0.s-" $(seq 1 $((bar_size-filled))))
  printf "\rProgress: [%s%s] %s%% (%d/%d)" "$bar" "$empty" "$percent" "$1" "$2"
}

# Silent ping function: $1=IP
ping_ip() {
  ip="$1"
  ping_time=$(ping -c 1 -W 1 "$ip" 2>&1 | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
  if [[ -n "$ping_time" ]]; then
    ping_int=${ping_time%.*}
    if (( ping_int <= max_ping )); then
      echo "$ip $ping_int" >> "$tmpfile"
    fi
  fi
}

export -f ping_ip
export tmpfile
export max_ping

# Main loop: silent, with progress bar
current=0
for ip in "${ips[@]}"; do
  ((current++))
  # Launch ping in background
  ping_ip "$ip" &
  # Progress bar (every 50 IPs)
  if (( current % 50 == 0 || current == total_ips )); then
    print_progress "$current" "$total_ips"
  fi
  # Limit parallel jobs
  while (( $(jobs -r | wc -l) >= max_jobs )); do
    sleep 0.05
  done
done

# Final progress update and wait for all jobs
wait
print_progress "$total_ips" "$total_ips"
echo

echo -e "\nTop 4 Best WARP Endpoints (ping ≤ ${max_ping}ms):"
if [[ -s "$tmpfile" ]]; then
  sort -k2 -n "$tmpfile" | head -n4 | awk '{printf "%-15s %sms\n", $1, $2}'
else
  echo "No endpoint was reachable under ${max_ping}ms."
fi

rm -f "$tmpfile"
