# Think-Inside-the-Box
# Vulnix VM - Penetration Testing & Hardening

## Overview

This repository contains a complete penetration testing and hardening exercise on the **Vulnix VM** from VulnHub. The project demonstrates a full attack chain from initial reconnaissance to root privilege escalation, followed by a comprehensive hardening process that blocks all identified attack vectors.

## Repository Structure

```
.
├── README.md                 # This file
├── LICENSE                   # MIT License
├── fix_vulnix.sh             # Hardening script
├── Part-A-Attack-Writeup.pdf  # Full attack documentation
├── Part-B-Hardening-Writeup.pdf # Full hardening documentation
└── media/                    # Screenshots
```

## Part A: Attack

### Attack Chain Summary

| Step | Action | Tool/Method |
|------|--------|-------------|
| 1 | Host discovery | `arp-scan` |
| 2 | Port scanning | `nmap` |
| 3 | NFS share discovery | `showmount` |
| 4 | SMTP user enumeration | Metasploit `smtp_enum` |
| 5 | User information gathering | `finger` |
| 6 | SSH brute-force | `hydra` |
| 7 | Initial SSH access | `ssh` |
| 8 | Internal reconnaissance | `groups`, `find`, `id` |
| 9 | NFS share mounting | `mount` |
| 10 | Local user creation | `useradd` |
| 11 | SSH key generation | `ssh-keygen` |
| 12 | SSH key injection | `cp`, `chmod` |
| 13 | SSH as `vulnix` | `ssh -i` |
| 14 | Sudo privilege check | `sudo -l` |
| 15 | `/etc/exports` modification | `sudoedit` |
| 16 | VM reboot | VMware |
| 17 | NFS remount | `mount` |
| 18 | SUID shell creation | `cp`, `chmod` |
| 19 | Root shell execution | `bash_suid -p` |
| 20 | Flag capture | `cat /root/thropy.txt` |

### Key Vulnerabilities Exploited

1. **Weak SSH password** (`user:letmein`)
2. **World-readable NFS share** (`/home/vulnix` exported to `*`)
3. **`sudoedit` privilege** on `/etc/exports` for `vulnix`
4. **`no_root_squash`** NFS option enabled

## Part B: Hardening

### Hardening Script

The `fix_vulnix.sh` script implements 12 security measures:

| # | Measure | Purpose |
|---|---------|---------|
| 1 | Strong password policy | Prevents weak passwords |
| 2 | Force password change | Removes weak passwords |
| 3 | Disable Finger service | Prevents user enumeration |
| 4 | Disable SMTP VRFY/EXPN | Prevents user enumeration |
| 5 | Restrict NFS exports | Prevents world access |
| 6 | Enable `root_squash` | Prevents `no_root_squash` escalation |
| 7 | Remove `sudoedit` | Prevents `/etc/exports` modification |
| 8 | SSH hardening | Prevents brute-force attacks |
| 9 | Remove SUID from unnecessary binaries | Reduces attack surface |
| 10 | Secure `/tmp` and `/var/tmp` | Prevents SUID execution |
| 11 | Enable auditing | Provides visibility |
| 12 | Remove attack artifacts | Cleans up backdoors |

### Verification Results

All eight attack vectors were successfully blocked:

| Attack Vector | Status |
|---------------|--------|
| SMTP user enumeration | Blocked |
| Finger user enumeration | Blocked |
| SSH brute-force | Blocked |
| NFS share mounting | Blocked |
| NFS write as root | Blocked |
| SSH key injection | Blocked |
| `sudoedit` on `/etc/exports` | Blocked |
| SUID shell execution | Blocked |

## Usage

### Running the Hardening Script

```bash
# Make the script executable
chmod +x fix_vulnix.sh

# Run as root on the Vulnix VM
./fix_vulnix.sh
```

### Verification Commands

```bash
# 1. Verify SMTP user enumeration is blocked
smtp-user-enum -M VRFY -u root -t 192.168.0.29

# 2. Verify Finger service is disabled
finger user@192.168.0.29

# 3. Verify SSH brute-force is blocked
hydra -l user -P /usr/share/wordlists/fasttrack.txt ssh://192.168.0.29

# 4. Verify NFS exports are restricted
showmount -e 192.168.0.29
```

## Issues Encountered During Hardening

| # | Issue | Solution |
|---|-------|----------|
| 1 | Script execution failed (Permission denied) | Spawned proper root shell with `python -c 'import os; os.setuid(0); os.system("/bin/bash")'` |
| 2 | `apt-get` failed (404 Not Found) | Updated repository sources to `old-releases.ubuntu.com` |
| 3 | `gb.old-releases.ubuntu.com` failed to resolve | Removed country code from repository URLs |
| 4 | `libpam-pwquality` not found | Changed to `libpam-cracklib` (correct package for Ubuntu 12.04) |
| 5 | `systemctl: command not found` | Changed to `service ssh restart` (correct command for Ubuntu 12.04) |

## Lessons Learned

- **Security is a chain**: Multiple low-severity issues can be combined to achieve full system compromise.
- **Principle of Least Privilege**: Users should have only the permissions they absolutely need.
- **Defense in Depth**: Multiple layers of security prevent a single failure from compromising the entire system.
- **Minimize Attack Surface**: Disable unnecessary services and restrict access.
- **Legacy systems are vulnerable**: Ubuntu 12.04 repositories are archived, and package names differ from modern versions.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [VulnHub](https://www.vulnhub.com/) for the Vulnix VM
- [HackTricks](https://book.hacktricks.wiki/) for privilege escalation techniques
- [GTFOBins](https://gtfobins.github.io/) for SUID exploitation
