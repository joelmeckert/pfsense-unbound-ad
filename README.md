# WinDnsToUnbound
Windodws Server DNS, export to unbound, for use on a firewall / pfSense



Many organizations rely on Microsoft DNS Server for internal DNS, which leads to using Microsoft DHCP. If the DNS or DHCP servers are down, the network is regarded as down, and the complexity and frequent updates of Windows adds to the issues.

This script exports the DNS entries from Active Directory and creates a configuration file that may be used by the Unbound DNS resolver, if you are using pfSense, this would be /var/unbound. In the DNS resolver for pfSense, add this custom option after uploading the file: server:include: /var/unbound/activedirectory.conf

Optionally, a Scheduled Task could be configured on the Windows server that runs the script, generates the configuration file, calls WinSCP or similar, and uploads the file upon changes. Event Log monitoring on the Windows side is as follows: Application and Service Logs => Microsoft => Windows => DNS Server => Audit Source: DNS-Server Event ID: 515 (creation of new DNS entries)
