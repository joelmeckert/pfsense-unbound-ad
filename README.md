# WinDnsToUnbound
Gets the DNS zone information and records from Active Directory, exports it to an include file for the Unbound DNS resolver, commonly used with pfSense.

## Future Updates
I'm working on a revision of this that obtains the domain / AD SID, and autopopulates the entries. I need to test with multiple domain controllers.

# Rationale
- DNS and DHCP need appliance-level availability, and forcing Windows DNS with Active Directory impacts uptime and perception, server down == network down
- This provides for the potential of local host resolution using the Active Directory / Azure AD domain, and retaining UPNs that match the Azure AD, e.g. email@contoso.com
- The Unbound option of TypeTransparent will attempt to resolve the DNS query, and if there is no entry, it will pass it on to the host / firewall's DNS servers
- pfSense's DHCP implementation will automatically link local DHCP/DNS registrations and PTR

More information is available in the PowerShell script comments.
