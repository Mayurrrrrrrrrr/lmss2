# Server Specification Summary (ffops2)

## System Overview
- **Hostname**: ffops2
- **Operating System**: Ubuntu 24.04.4 LTS (64-bit)
- **Kernel**: Linux 6.17.0-1011-oracle
- **Environment**: Virtual Machine (KVM/QEMU) on Oracle Cloud

## Hardware Specifications
- **CPU**: 2 vCPUs (AMD EPYC 7551 32-Core Processor architecture)
- **Memory (RAM)**: 1 GB (954 MiB usable)
- **Swap Space**: 2.0 GB
- **Disk Storage (Root /)**: 45 GB total capacity (4.8 GB used, 40 GB available)

## Network Configuration
- **Public IP Address**: `129.159.231.29`
- **Private / Local IP**: `10.0.0.183` (Interface: `ens3`)
- **SSH Key**: Found in workspace directory: [ssh-key-2026-07-17.key](file:///c:/Users/mayur/.gemini/antigravity/scratch/lms-new/ssh-key-2026-07-17.key)
- **SSH Command**: `ssh -i .\ssh-key-2026-07-17.key ubuntu@129.159.231.29`

## Active Services & Open Ports
- **Port 22 (TCP)**: SSH (Listening for remote connections on IPv4 and IPv6)
- **Port 80 (TCP)**: HTTP (A web server is currently running and listening for traffic)
- **Port 2019 (TCP)**: Localhost only (Often used by the Caddy web server admin API)
- **Port 53 (TCP/UDP)**: Local DNS resolution (systemd-resolved)

## System Health (as of July 17, 2026)
- **Uptime**: ~6 hours, 44 minutes
- **System Load**: 0.08 (Extremely low/idle)
- **Disk Usage**: 11% consumed, plenty of room to grow.
