# unbound-pfsense-ad
Export Active Directory DNS information to an unbound include file, SRV records, to use unbound / pfSense as the DNS resolver, rather than Windows AD DNS.

## Future Updates
I'm working on a revision of this that obtains the domain SID, domain controllers, and autopopulates the entries. I need to test with multiple domain controllers. I've seen the export fail when the DNS servers are not responding appropriately with the SRV records, and avoiding this and obtaining a list of DCs to populate the configuration file would be preferable.

## Usage
- Run the PowerShell script as admin on a domain controller
- Configuration file is automatically generated
- Upload the configuration file to the firewall, enter an include statement in unbound to include the file
- Point the clients to use the firewall as DNS

## Limitations
- Active Directory uses secure dynamic DNS updates, this does not, it's likely a fit for smaller environments, but not larger environments

## Rationale
- DNS and DHCP need appliance-level availability
- Forcing Windows DNS with Active Directory impacts uptime and perception, server down == network down
- Using unbound with TYPETRANSPARENT, it is possible to use a UPN that reflects the public internet UPN, without split DNS
  - TYPETRANSPARENT will attempt to resolve the DNS record locally first, and when this fails, it will revert to the firewall's system-configured DNS
  - Tested with Azure AD Connect domains and standard Active Directory
- The Unbound option of TypeTransparent will attempt to resolve the DNS query, and if there is no entry, it will pass it on to the host / firewall's DNS servers
- pfSense's DHCP implementation will automatically link local DHCP/DNS registrations and PTR

More information is available in the PowerShell script comments.
