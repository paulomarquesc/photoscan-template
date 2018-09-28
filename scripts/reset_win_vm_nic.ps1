# Restarting Network Adapter to update DNS
Get-NetAdapter | Restart-NetAdapter
Shutdown -r -t 0