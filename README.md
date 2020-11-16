# WinDnsToUnbound
Windodws Server DNS, export to unbound, for use on a firewall / pfSense

<#
.SYNOPSIS
  Gets the DNS zone information and records from Active Directory, exports it to an include file for the Unbound DNS resolver.
.DESCRIPTION
  Rationale:
  * DNS needs appliance-level availability, and forcing Windows DNS with Active Directory impacts uptime and perception, server down == network down
  * This provides for the potential of local host resolution using the Active Directory / Azure AD domain, and retaining UPNs that match the Azure AD, e.g. email@contoso.com
  * The Unbound option of TypeTransparent will attempt to resolve the DNS query, and if there is no entry, it will pass it on to the host / firewall's DNS servers
  * pfSense's DHCP implementation will automatically register DNS and PTR
  pfSense configuration, as custom options:
  * Copy the contents of the newly created file
  * Open the pfSense web interface, browse to Services, DNS Resolver, Custom Options, and paste the entries
  * Backed up with the pfSense configuration file
  pfSense, as an include file:
  * Upload the file to /var/unbound/unbound.adinclude.conf ...
  * Open the pfSense web interface, browse to Services, DNS Resolver, Custom Options
  * Add the line 'server:include: /var/unbound/unbound.adinclude.conf'
  * Must be manually restored as part of the firewall build process
  Once the changes are in place, Active Directory domain controllers can point to the Unbound instance of DNS for seamless operations, re-run the script at a later date, DNS changes for AD SRV and CNAME records don't occur without a major reconfiguration.
  Optionally, disable dynamic DNS on the domain controllers, if they are pointing to Unbound:
  # Windows Registry Editor Version 5.00
  # [HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters]
  # "UseDynamicDns"=dword:00000000
.PARAMETER OutputFile
  Output filename, default is ".\unbound.adinclude.conf", removes any file that exists
.INPUTS
  None
.OUTPUTS
  Configuration file, as per above
.NOTES
  Version:        0.0.2
  Author:         Joel Eckert
  Creation Date:  November 15, 2020
  Purpose/Change: Initial script development
.EXAMPLE
  Note: Run as a domain admin on a domain controller
  WinDnsToUnbound                                       # Creates "unbound.adinclude.conf" in the current directory
  WinDnsToUnbound -OutputFile ".\configuration.conf"    # Creates file as specified
#>
