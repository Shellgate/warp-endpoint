#!/bin/bash

# Cloudflare WARP Endpoint Finder (Full /24 Scan, All 256 IPs per Range)
# Silent + Progress Bar, Top 4 by lowest ping

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

max_ping=20        # ms threshold
max_jobs=64        # Parallel jobs (adjust if needed)
tmpfile=$(mktemp)
total_ips=$((${#ranges[@]} * 256))
tested=0

# Progress bar function
progress_bar() {
  percent=$(( 100 * $1 / $2 ))
  bar_size=40
  filled=$(( bar_size * $1 / $2 ))
  empty=$(( bar_size - filled ))
  bar=$(printf "%0.s#" $(seq 1 $filled))
  spaces=$(printf "%0.s-" $(seq 1 $empty))
  printf "\rProgress: [%s%s] %d%% (%d/%d)" "$bar" "$spaces" "$percent" "$1" "$2"
}

# Ping function (silent)
ping_ip() {
  ip="$1"
  ping_time=$(ping -c 1 -W 1 "$ip" 2>/dev/null | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
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

# Main execution
for range in "${ranges[@]}"; do
  for i in $(seq 0 255); do
    ip="$range.$i"
    ping_ip "$ip" &
    ((tested++))
    # Progress bar every 25 IPs
    if (( tested % 25 == 0 || tested == total_ips )); then
      progress_bar "$tested" "$total_ips"
    fi
    # Limit parallel jobs
    while (( $(jobs -r | wc -l) >= max_jobs )); do
      sleep 0.02
    done
  done
done

wait
progress_bar "$total_ips" "$total_ips"
echo

echo -e "\nTop 4 Best WARP Endpoints (ping ≤ ${max_ping}ms):"
if [[ -s "$tmpfile" ]]; then
  sort -k2 -n "$tmpfile" | head -n4 | awk '{printf "%-15s %sms\n", $1, $2}'
else
  echo "No endpoint was reachable under ${max_ping}ms."
fi

rm -f "$tmpfile"
