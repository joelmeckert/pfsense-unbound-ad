#Requires -runasadministrator
#Requires -Version 4
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

Param (
    [Parameter(Mandatory=$false)]
    $OutputFile = (Join-Path $PSScriptRoot "unbound.adinclude.conf")
)

# Initial comment lines in configuration file
'# Start of Unbound Windows DNS include file' | Out-File -FilePath $OutputFile -Encoding ascii
'# Upload to firewall, /var/unbound' | Out-File -FilePath $OutputFile -Encoding ascii -Append
'# Include configuration file in custom options for the DNS Resolver:' | Out-File -FilePath $OutputFile -Encoding ascii -Append
'# server:include: /var/unbound/unbound.adinclude.conf' | Out-File -FilePath $OutputFile -Encoding ascii -Append

# Get the name of one of the domain controllers
$msDnsServer = ($env:LOGONSERVER -replace "\\","")

# Skip export of PTR records and zones
[regex]$regexSkipPtr = '(0\.in-addr\.arpa)|(127\.in-addr\.arpa)|(255\.in-addr\.arpa)'
# Allow Microsoft private domains to have NS records on Unbound
[regex]$regexAllowNS = '^(_msdcs\..+|TrustAnchors)$'

# Get all of the DNS zones hosted on Microsoft DNS Server
Try {
    $zones = Get-DnsServerZone -ComputerName $msDnsServer | Where-Object -Property ZoneName -NotMatch $regexSkipPtr | Select-Object -ExpandProperty ZoneName
}
Catch {
    Write-Error "Unable to obtain Microsoft DNS zones from $msDnsServer"
    Start-Sleep 5
    Exit
}

Write-Host "Processing. . ."
ForEach ($zone in $zones) {
    Try {
        $resourceRecords = Get-DnsServerResourceRecord -ZoneName $zone
    }
    Catch {
        Write-Error "Unable to obtain DNS resource records for $zone"
        Start-Sleep 5
        Continue
    }
    Write-Host "Zone: $zone"
    # Entries for new zones in the Unbound configuration file
    $zoneEntry = 'local-zone: "' + $zone + "`"" + " " + "typetransparent" + "`n"
    $zoneEntry += 'private-domain: "' + $zone + "`"" + "`n"
    $zoneEntry | Out-File -FilePath $OutputFile -Encoding ascii -Append -NoNewline

    ForEach ($resourceRecord in $resourceRecords) {
        $objRecord = $null
        # name, ttl, class, type, data
        # Determines the type of DNS resource record
        If ($resourceRecord.RecordType -eq "A") {
            $objRecord = [PSCustomObject][Ordered] @{
                "name"              = $resourceRecord.Hostname
                "TTL"               = $resourceRecord.TimeToLive.TotalMinutes
                "CLASS"             = $resourceRecord.RecordClass
                "TYPE"              = $resourceRecord.RecordType                        
                "DATA"              = $resourceRecord.RecordData.IPv4Address.IPAddressToString
            }
        }
        ElseIf ($resourceRecord.RecordType -eq "CNAME") {
            $objRecord = [PSCustomObject][Ordered] @{    
                "name"              = $resourceRecord.Hostname
                "TTL"               = $resourceRecord.TimeToLive.TotalMinutes
                "CLASS"             = $resourceRecord.RecordClass
                "TYPE"              = $resourceRecord.RecordType
                "DATA"              = $resourceRecord.RecordData.HostNameAlias
            }
        }
        # If it is an NS record, and the zone matches the regular expression for internal-only Microsoft domains
        ElseIf (($resourceRecord.RecordType -eq "NS") -and ($zone -match $regexAllowNS)) {
            $objRecord = [PSCustomObject][Ordered] @{
                "name"              = $resourceRecord.Hostname
                "TTL"               = $resourceRecord.TimeToLive.TotalMinutes
                "CLASS"             = $resourceRecord.RecordClass
                "TYPE"              = $resourceRecord.RecordType                        
                "DATA"              = $resourceRecord.RecordData.NameServer
            }
        }
        ElseIf ($resourceRecord.RecordType -eq "SOA") {
            # No practical use
            # $objRecord = [PSCustomObject][Ordered] @{
            #    "name"              = $resourceRecord.Hostname
            #    "TTL"               = $resourceRecord.TimeToLive.TotalMinutes
            #    "CLASS"             = $resourceRecord.RecordClass
            #    "TYPE"              = $resourceRecord.RecordType
            #    "MNAME"             = $resourceRecord.RecordData.PrimaryServer
            #    "RNAME"             = $resourceRecord.RecordData.ResponsiblePerson
            #    "REFRESH"           = $resourceRecord.RecordData.RefreshInterval.TotalMinutes
            #    "RETRY"             = $resourceRecord.RecordData.RetryDelay.TotalMinutes
            #    "EXPIRE"            = $resourceRecord.RecordData.ExpireLimit.TotalMinutes
            #}
        }
        ElseIf ($resourceRecord.RecordType -eq "SRV") {
            $objRecord = [PSCustomObject][Ordered] @{
                "name"              = $resourceRecord.Hostname
                "TTL"               = $resourceRecord.TimeToLive.TotalMinutes
                "CLASS"             = $resourceRecord.RecordClass
                "TYPE"              = $resourceRecord.RecordType
                "DATA"              = $resourceRecord.RecordData.DomainName
                "PORT"              = $resourceRecord.RecordData.Port
                "PRIORITY"          = $resourceRecord.RecordData.Priority
                "WEIGHT"            = $resourceRecord.RecordData.Weight
            }
        }
        If ($objRecord) {
            $outputEntry = 'local-data: "' + $objRecord.name + "." + $zone + "." + " " + ($objRecord.TTL * 60) + " " + $objRecord.Class + " " + $objRecord.TYPE + " "
            # Special formatting for SRV records
            If ($objRecord.TYPE -eq "SRV") {
                $outputEntry += $objRecord.PRIORITY.ToString() + " " + $objRecord.WEIGHT.ToString() + " " + $objRecord.PORT.ToString() + " "
            }
            # Shared suffix
            $outputEntry += $objRecord.DATA + "`"" + "`n"
            $outputEntry | Out-File -FilePath $OutputFile -Encoding ascii -Append -NoNewline
        }
    }
}

# Replace the Windows carriage returns
(Get-Content $OutputFile -Raw).Replace("`r`n","`n").Trim() | Set-Content $OutputFile -Force

Write-Host ""
Write-Host "Output conf file w/o CR: $OutputFile"
Start-Sleep 5

# Launch Notepad++ or Notepad, if not installed, with the configuration file
$NotepadPlusPlus = "C:\Program Files\Notepad++\notepad++.exe"
If (Test-Path $NotepadPlusPlus) {
    & $NotepadPlusPlus $OutputFile
}
Else {
    & "notepad.exe" $OutputFile
}
