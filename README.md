# CKB Node — Orange Pi 3B Build Guide

A complete guide to building a Nervos CKB full node on an Orange Pi 3B, including 3D-printed enclosure files and update tooling.

📁 **Pre-built image (Ubuntu 22.04 XFCE, DSI display configured):**
https://drive.google.com/drive/folders/1HcHqw6diSt8tZUwNw4w6q0revqnInk0n?usp=sharing

---

## Notes on the pre-built image

1. **DSI display:** The image is pre-configured to output to the DSI port via device tree overlay. This disables HDMI output. To switch back to HDMI, open a terminal and run `sudo orangepi-config`, then disable the DSI overlay under the hardware/display section.

2. **NVMe upgrade:** The board is PCIe x2 so ultra-fast drives are overkill. Note the awkward placement of the NVMe slot — use a 2230-size drive that is flat on the bottom for clearance above the SD card slot. To clone the OS to NVMe: power off, fit the drive, power on, then run `sudo orangepi-config` → Storage → Install, and follow the prompts. Takes a few minutes.

---

## Parts list

| Part | Link |
|------|------|
| Orange Pi 3B 8GB + 256G eMMC + 5V3A USB-C PSU | https://a.aliexpress.com/_mtsnkO4 |
| 5" DSI Capacitive Touch LCD 800×480 | https://a.aliexpress.com/_mttBpfS |
| Passive copper heatsink set | https://a.aliexpress.com/_m0l0tb2 |
| 30×30×10mm 5V fan (2-pin hydraulic bearing) | https://a.aliexpress.com/_mLKDkuY |
| JST PH **1.25mm** 2-pin connectors (male + female) | https://a.aliexpress.com/_mKi6gp2 |

A wireless USB keyboard/mouse is also recommended for initial setup.

---

## 3D printed enclosure

STL files are in the [`stl files/`](stl%20files/) folder. Designed for a **Bambu Lab X1C** with AMS for multi-colour printing.

- Colour is assigned per-layer height (not per-STL) to minimise filament changes
- Tolerance gaps are 0.05–0.1mm — test with the main body first before committing to panels
- If your printer needs looser tolerances, modify the files accordingly
- The base holds the screen snugly; if your tolerances are wider, a small amount of superglue works fine
- Printed in PLA+ but any material works

---

## Updating CKB

### Quick method (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/toastmanAu/CKB-Node/main/update_ckb.sh | sudo bash
```

The script will auto-detect the latest release and prompt for confirmation.

### Manual method

```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/toastmanAu/CKB-Node/main/update_ckb.sh -o update_ckb.sh
chmod +x update_ckb.sh

# Run it (optionally pass a specific version)
sudo ./update_ckb.sh             # auto-detects latest
sudo ./update_ckb.sh 0.204.0     # specific version
```

### What the script does

- Detects your architecture (aarch64/x86_64) automatically
- Fetches the latest release version from GitHub if none specified
- Stops the CKB systemd service gracefully before updating
- Backs up the current binary as `ckb.vX.Y.Z.bak` before overwriting
- Preserves `data/`, `ckb.toml`, `ckb-miner.toml`, and any local scripts
- Verifies the installed version after update
- Restarts the service if it was running before

> **Tip:** If the node is running in a terminal rather than as a systemd service, stop it first with `Ctrl+C` and wait for a graceful shutdown before running the script.

---

## Setting up as a systemd service

If you want the node to start automatically on boot:

```bash
sudo tee /etc/systemd/system/ckb.service > /dev/null <<EOF
[Unit]
Description=Nervos CKB Node
After=network.target

[Service]
Type=simple
User=orangepi
WorkingDirectory=/home/orangepi/ckb
ExecStart=/home/orangepi/ckb/ckb run
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ckb
sudo systemctl start ckb
```

Check status: `sudo systemctl status ckb`
View logs: `journalctl -u ckb -f`
