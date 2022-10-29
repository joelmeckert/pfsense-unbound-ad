# pfsense-unbound-ad
Export Active Directory DNS to unbound include file, SRV records, to use unbound / pfSense as the DNS resolver, rather than Windows AD DNS.


## Usage
- Run the PowerShell script as admin on a domain controller
```
.\Get-DomainInfo.ps1
```
- Configuration file is automatically generated, unbound.adinclude.conf
- Verify configuration file
  - Open with a text editor (e.g. notepad++ or something that supports UNIX format)
  - Remove bogus entries, such as for network adapters with multiple IP addresses that are not accessible, hopefully rectified in this release
- Upload configuration file, copy/paste into nano (pkg install nano), or WinSCP
  - Upload to /var/unbound/unbound.adinclude.conf
```
chmod 644 /var/unbound/unbound.adinclude.conf
chown root:unbound /var/unbound/unbound.adinclude.conf
```
- Unbound, Services => DNS Resolver => Custom options
```
server:include: /var/unbound/unbound.adinclude.conf
```
- Point the clients and Active Directory servers to use the firewall as DNS

## Limitations
- If the firewall is reinstalled and configuration restored, the file must be manually uploaded again
- Active Directory uses secure dynamic DNS updates, this does not, it's likely a fit for smaller environments, but not larger environments

## Rationale
- DNS and DHCP need appliance-level availability
- There is a lot of fearmongering in this space, I was with a public university for 11 years who used alternative DNS with 50k+ users, so it is possible
- Forcing Windows DNS with Active Directory impacts uptime and perception, server down == network down
- Using unbound with TYPETRANSPARENT, it is possible to use a UPN that reflects the public internet UPN, without split DNS
  - TYPETRANSPARENT will attempt to resolve the DNS record locally first, and when this fails, it will revert to the firewall's system-configured DNS
  - Tested with Azure AD Connect domains and standard Active Directory
  - Conceptually, unbound should support deferring DNS resolution to an alternate DNS server as specified in the configuration file, where the firewall does not have the local records, it is on my agenda to test
- pfSense's DHCP implementation will automatically link local DHCP/DNS registrations and PTR by default
