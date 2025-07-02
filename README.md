# Cloudflare WARP Endpoint Finder

A fast, parallel Bash script to find the 4 best (lowest ping) Cloudflare WARP endpoints across all major global IPv4 ranges.  
This tool is particularly useful for users in Iran, but covers all official Cloudflare WARP IPv4 ranges.

---

## Features

- **Scans all major Cloudflare WARP IPv4 ranges** (.0 to .20 of each /24)
- **Parallel ping testing** for high speed
- **Filters endpoints with ping ≤ 20ms**
- **Displays the top 4 best endpoints** with their ping
- **Easy to customize**

---

## Usage

1. **Download the script:**

   [Direct Link to Script on GitHub](https://github.com/Shellgate/warp-endpoint/blob/main/best_warp_endpoints.sh)

   Or clone the repository:
   ```bash
   git clone https://github.com/Shellgate/warp-endpoint.git
   cd warp-endpoint
   ```

2. **Make the script executable:**
   ```bash
   chmod +x best_warp_endpoints.sh
   ```

3. **Run the script:**
   ```bash
   ./best_warp_endpoints.sh
   ```

---

## Example Output

```
Parallel scanning of Cloudflare WARP IPs (.0 to .20, ping ≤ 20ms)...
162.159.192.2 : 13.1 ms (OK)
188.114.97.3 : 15.0 ms (OK)
...
------------------------------
Top 4 Best WARP Endpoints (ping ≤ 20ms):
162.159.192.2    13ms
188.114.97.3     15ms
162.159.193.4    16ms
188.114.98.1     18ms
```

---

## Customization

- **Ranges:**  
  To scan more IPs or different ranges, edit the `ranges` array in the script.
- **Ping Threshold:**  
  To change the maximum accepted ping, set the `max_ping` variable.
- **Parallelism:**  
  To speed up or slow down the scan (depending on your hardware/network), change the `max_jobs` variable.

---

## Requirements

- A Unix-like OS (Linux, macOS, WSL)
- `bash`, `ping`, `awk`, and basic GNU utils

---

## License

MIT

---

**Made with ❤️ for the open internet.**
