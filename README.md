# Cloudflare WARP Endpoint Finder (`warpip.sh`)

A blazing fast, parallel Bash script to find the **4 best (lowest ping) Cloudflare WARP endpoints** across all major global IPv4 ranges.  
Perfect for users in Iran and worldwide, covering all official Cloudflare WARP IPv4 blocks.

---

## 🚀 Quick Usage (No Download or Git Clone Needed)

Just run this command in your terminal – no need to download anything or clone the repo!

```bash
bash <(curl -s https://raw.githubusercontent.com/Shellgate/warp-endpoint/main/warpip.sh)
```

Or using `wget`:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/Shellgate/warp-endpoint/main/warpip.sh)
```

---

## Features

- **Scans all major Cloudflare WARP IPv4 ranges** (.0 to .20 of each /24)
- **Super fast parallel ping testing**
- **Filters endpoints with ping ≤ 20ms**
- **Shows the top 4 best endpoints** with their ping
- **Easily customizable**

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

- **IP Ranges:**  
  Edit the `ranges` array inside the script to scan more or fewer IP blocks.
- **Ping Threshold:**  
  Change the `max_ping` value in the script to set your own quality limit.
- **Parallel Jobs:**  
  Adjust `max_jobs` to control the number of concurrent pings for your system/network.

---

## Requirements

- A Unix-like OS (Linux, macOS, WSL)
- `bash`, `ping`, `awk`, and basic GNU utils

---

## License

MIT

---

**Made with ❤️ for the open internet.**

[View source code on GitHub](https://github.com/Shellgate/warp-endpoint)
