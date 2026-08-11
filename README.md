# openSUSE Post-Setup Scripts

An orchestrator to optimize **openSUSE**.

## ⚡ Fast Bootstrap (No Git)

If `zypper` is slow, run this to optimize throughput and install Git:

```bash
echo -e "[main]\ndownload.max_concurrent_connections = 10\ndeltarpm = false" | sudo tee /etc/zypp/zypp.conf
sudo env ZYPP_CURL2=1 zypper ref
sudo zypper in -y git-core
```

> [!TIP]
> **Reboot** after execution to apply the new multimedia libraries and zRAM configuration.

---
