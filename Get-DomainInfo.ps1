#Requires -RunAsAdministrator

<#
The MIT License (MIT)

Copyright © 2022 Joel M. Eckert, joel@cyberthion.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

.SYNOPSIS
  Generates an unbound DNS configuration file with all appropriate Active Directory entries.
.DESCRIPTION
  For use when offloading Active Directory DNS to the firewall, frequently used with pfSense, rewrite from previous version which fetched DNS entries from Windows DNS/AD integrated zones.
.INPUTS
  None
.OUTPUTS
  "unbound.adinclude.conf" in current directory
.NOTES
  Version:        0.1
  Author:         Joel Eckert
  Creation Date:  October 15, 2022
  Purpose/Change: Rewrite, gather domain information from cmdlets rather than DNS
  
.EXAMPLE
  ./Get-DomainInfo.ps1
#>

# Output configuration file to be uploaded to the firewall to /var/unbound
$unboundCfgFile = Join-Path $PSScriptRoot "unbound.adinclude.conf"

# Regular expression for private IP addresses
[regex]$rxPrivateIP = '(^127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^172\.1[6-9]{1}[0-9]{0,1}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^172\.2[0-9]{1}[0-9]{0,1}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^172\.3[0-1]{1}[0-9]{0,1}\.[0-9]{1,3}\.[0-9]{1,3}$)|(^192\.168\.[0-9]{1,3}\.[0-9]{1,3}$)'

# Domain DNS name
$domDnsName = Get-ADDomain | Select-Object -ExpandProperty DNSRoot
# Domain GUID
$domGuid = Get-ADDomain | Select-Object -ExpandProperty ObjectGUID | Select-Object -ExpandProperty Guid
# Domain controllers object, can be an array
$dcs = Get-ADDomainController -Filter *
# PDCs, can be an array
#$pdcs = Get-ADDomain | Select-Object -ExpandProperty PDCEmulator
# Get the IP address of the default gateway, to assign this to the router, which will be performing DNS, then assign the hostmame of the firewall
$fwGatewayIp = Get-NetIPConfiguration | Where-Object -Property IPv4DefaultGateway -ne $null | Select-Object -ExpandProperty IPv4DefaultGateway | Select-Object -ExpandProperty NextHop
# Get the IP address of the default gateway, to assign this to the router, which will be performing DNS
$fwHostname = Resolve-DnsName -Type PTR -Name $fwGatewayIp | Select-Object -ExpandProperty NameHost

# Initialize array
$unbound = @()

# Default lines at the start of the configuration file
$unbound += '# Start of Unbound Windows Active Directory DNS include file'
$unbound += '# Upload to firewall, /var/unbound/unbound.adinclude.conf, it does not restore when restoring firewall configuration'
$unbound += '# Manually add static DNS entry for domain controller on firewall, e.g. dc.contoso.com'
$unbound += '# Include configuration file in custom options for the unbound DNS Resolver:'
$unbound += '# server:include: /var/unbound/unbound.adinclude.conf'

# DNS entries for _msdcs.contoso.com
$unbound += 'local-zone: "_msdcs.' + $domDnsName + '" typetransparent'
$unbound += 'private-domain: "_msdcs.' + $domDnsName + '"'
$unbound += 'local-data: "@._msdcs.' + $domDnsName + '. 3600 IN NS ' + $fwHostname + '."'
ForEach ($dc in $dcs) {
    $dcIP = Resolve-DnsName -Name $dc.HostName -Type A | Where-Object -Property IPAddress -match $rxPrivateIP | Select-Object -ExpandProperty IPAddress | Select-Object -First 1
    $unbound += 'local-data: "' + $domGuid + '._msdcs.' + $domDnsName + '. 600 IN CNAME ' + $dc.HostName + '."'
    $unbound += 'local-data: "_kerberos._tcp.' + $dc.Site + '._sites.dc._msdcs.' + $domDnsName + '. 600 IN SRV 0 100 88 ' + $dc.HostName + '."'
    $unbound += 'local-data: "_ldap._tcp.' + $dc.Site + '._sites.dc._msdcs.' + $domDnsName + '. 600 IN SRV 0 100 389 ' + $dc.HostName + '."'
    $unbound += 'local-data: "_kerberos._tcp.dc._msdcs.' + $domDnsName + '. 600 IN SRV 0 100 88 ' + $dc.HostName + '."'
    $unbound += 'local-data: "_ldap._tcp.' + $dc.InvocationId.Guid + '.domains._msdcs.' + $domDnsName + '. 600 IN SRV 0 100 389 ' + $dc.HostName + '."'
    $unbound += 'local-data: "gc._msdcs.' + $domDnsName + '. 600 IN A ' + $dcIP + '"'
    $unbound += 'local-data: "_ldap._tcp.' + $dc.Site + '._sites.gc._msdcs.' + $domDnsName + '. 600 IN SRV 0 100 3268 ' + $dc.HostName + '."'
    $unbound += 'local-data: "_ldap._tcp.gc._msdcs.' + $domDnsName + '. 600 IN SRV 0 100 3268 ' + $dc.HostName + '."'
    $unbound += 'local-data: "_ldap._tcp.dc._msdcs.' + $domDnsName + '. 600 IN SRV 0 100 389 ' + $dc.HostName + '."'
}

# New local zone
$unbound += 'local-zone: "' + $domDnsName + '" typetransparent'

# New private domain
$unbound += 'private-domain: "' + $domDnsName + '"'

# Wildcard domain entries
$unbound += 'local-data: "@.' + $domDnsName + '. 600 IN A ' + $fwGatewayIp + '"'

ForEach ($dc in $dcs) {
    $dcIP = Resolve-DnsName -Name $dc.HostName -Type A | Where-Object -Property IPAddress -match $rxPrivateIP | Select-Object -ExpandProperty IPAddress | Select-Object -First 1
    $unbound += 'local-data: "_gc._tcp.' + $dc.Site + 'e._sites.' + $domDnsName + '. 600 IN SRV 0 100 3268 ' + $dc.HostName + '."'
    $unbound += 'local-data: "_kerberos._tcp.' + $dc.Site + '._sites.' + $domDnsName + '. 600 IN SRV 0 100 88 ' + $dc.HostName + '."'
    $unbound += 'local-data: "_ldap._tcp.' + $dc.Site + '._sites.dc.' + $domDnsName + '. 600 IN SRV 0 100 389 ' + $dc.HostName + '."'
    $unbound += 'local-data: "_ldap._tcp.' + $dc.Site + '._sites.' + $domDnsName + '. 600 IN SRV 0 100 389 ' + $dc.HostName + '."'
    $unbound += 'local-data: "_gc._tcp.' + $domDnsName + '. 600 IN SRV 0 100 3268 ' + $dc.HostName + '."'
    $unbound += 'local-data: "_kerberos._tcp.' + $domDnsName + '. 600 IN SRV 0 100 88 ' + $dc.HostName + '."'
    $unbound += 'local-data: "_kpasswd._tcp.' + $domDnsName + '. 600 IN SRV 0 100 464 ' + $dc.HostName + '."'
    $unbound += 'local-data: "_ldap._tcp.' + $domDnsName + '. 600 IN SRV 0 100 389 ' + $dc.HostName + '."'
    $unbound += 'local-data: "_kerberos._udp.' + $domDnsName + '. 600 IN SRV 0 100 88 ' + $dc.HostName + '."'
    $unbound += 'local-data: "_kpasswd._udp.' + $domDnsName + '. 600 IN SRV 0 100 464 ' + $dc.HostName + '."'
    $unbound += 'local-data: "DomainDnsZones.' + $domDnsName + '. 600 IN A ' + $dcIP + '"'
    $unbound += 'local-data: "_ldap._tcp.' + $dc.Site + '._sites.DomainDnsZones.' + $domDnsName + '. 600 IN SRV 0 100 389 ' + $dc.HostName + '."'
    $unbound += 'local-data: "_ldap._tcp.DomainDnsZones.' + $domDnsName + '. 600 IN SRV 0 100 389 ' + $dc.HostName + '."'
    $unbound += 'local-data: "ForestDnsZones.' + $domDnsName + '. 600 IN A ' + $dcIP + '"'
    $unbound += 'local-data: "_ldap._tcp.' + $dc.Site + '._sites.ForestDnsZones.' + $domDnsName + '. 600 IN SRV 0 100 389 ' + $dc.HostName + '."'
    $unbound += 'local-data: "_ldap._tcp.ForestDnsZones.' + $domDnsName + '. 600 IN SRV 0 100 389 ' + $dc.HostName + '."'
    $unbound += 'local-data: "' + $dc.HostName + '. 3600 IN A ' + $dcIP + '"'
}

$unbound += 'local-data: "' + $fwHostname + '. 3600 IN A ' + $fwGatewayIp + '"'

## TrustAnchors
# Add TrustAnchors zone
$unbound += 'local-zone: "TrustAnchors" typetransparent'

# Add TrustAnchors domain
$unbound += 'private-domain: "TrustAnchors"'

# Add TrustAnchors entry
#ForEach ($dc in $dcs) {
#    $dcHostName = $dc | Select-Object -ExpandProperty HostName
#    $unbound += ('local-data: "@.TrustAnchors. 3600 IN NS dc.contoso.com."').Replace($template.DCHostName,$dcHostName)
#}

$unbound | Set-Content -Path $unboundCfgFile

Write-Host "File has been created, unbound.adinclude.conf"
Write-Host "1. Configure DCs to point to the firewall for DNS"
Write-Host "2. Upload to firewall (WinSCP or copy/paste), /var/unbound/unbound.adinclude.conf, it does not restore when restoring firewall configuration"
Write-Host "3. Log into the web interface on pfSense, browse to Services => DNS Resolver"
Write-Host "4. Click Display Custom Options, and paste the following text in the box:"
Write-Host "server:include: /var/unbound/unbound.adinclude.conf" -ForegroundColor White
Write-Host "5. Click Save, then click Apply to apply the settings"
