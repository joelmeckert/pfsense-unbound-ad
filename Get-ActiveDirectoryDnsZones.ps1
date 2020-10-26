# Gets the DNS zone information for Active Directory, exports it to a CSV file

$Server = ($env:LOGONSERVER -replace "\\","")

. (Join-Path $PSScriptRoot "Set-ActiveDirectoryDnsZones.ps1")
$UnboundOut = Join-Path $PSScriptRoot "activedirectory.conf"

# $RootZoneExportFile = Join-Path $PSScriptRoot "zone-"
# $TemplateZoneFile = Join-Path $PSScriptRoot "zone-template.csv"
[regex]$SkipPTR = '(0\.in-addr\.arpa)|(127\.in-addr\.arpa)|(255\.in-addr\.arpa)'
$Zones = Get-DnsServerZone -ComputerName $Server | Where-Object -Property ZoneName -NotMatch $SkipPTR | Select-Object -ExpandProperty ZoneName

ForEach ($Zone in $Zones) {
    $ZoneData = @()
    Write-Host $Zone -ForegroundColor "Green"
    $ResourceRecords = Get-DnsServerResourceRecord -ZoneName $Zone
    $FirstRun = $true
    ForEach ($ResourceRecord in $ResourceRecords) {
        # name, ttl, class, type, data
        # Type-specific record entries
        If ($ResourceRecord.RecordType -eq "A") {
            $RecordEntry = [PSCustomObject][Ordered] @{
                "name"              = $ResourceRecord.Hostname
                "TTL"               = $ResourceRecord.TimeToLive.TotalMinutes
                "CLASS"             = $ResourceRecord.RecordClass
                "TYPE"              = $ResourceRecord.RecordType                        
                "DATA"              = $ResourceRecord.RecordData.IPv4Address.IPAddressToString
            }
        }
        ElseIf ($ResourceRecord.RecordType -eq "CNAME") {
            $RecordEntry = [PSCustomObject][Ordered] @{    
                "name"              = $ResourceRecord.Hostname
                "TTL"               = $ResourceRecord.TimeToLive.TotalMinutes
                "CLASS"             = $ResourceRecord.RecordClass
                "TYPE"              = $ResourceRecord.RecordType
                "DATA"              = $ResourceRecord.RecordData.HostNameAlias
            }
        }
        ElseIf ($ResourceRecord.RecordType -eq "NS") {
            $RecordEntry = [PSCustomObject][Ordered] @{
                "name"              = $ResourceRecord.Hostname
                "TTL"               = $ResourceRecord.TimeToLive.TotalMinutes
                "CLASS"             = $ResourceRecord.RecordClass
                "TYPE"              = $ResourceRecord.RecordType                        
                "DATA"              = $ResourceRecord.RecordData.NameServer
            }
        }
        ElseIf ($ResourceRecord.RecordType -eq "SOA") {
            $RecordEntry = [PSCustomObject][Ordered] @{
                "name"              = $ResourceRecord.Hostname
                "TTL"               = $ResourceRecord.TimeToLive.TotalMinutes
                "CLASS"             = $ResourceRecord.RecordClass
                "TYPE"              = $ResourceRecord.RecordType
                "MNAME"             = $ResourceRecord.RecordData.PrimaryServer
                "RNAME"             = $ResourceRecord.RecordData.ResponsiblePerson
                "REFRESH"           = $ResourceRecord.RecordData.RefreshInterval.TotalMinutes
                "RETRY"             = $ResourceRecord.RecordData.RetryDelay.TotalMinutes
                "EXPIRE"            = $ResourceRecord.RecordData.ExpireLimit.TotalMinutes
            }
        }
        ElseIf ($ResourceRecord.RecordType -eq "SRV") {
            $RecordEntry = [PSCustomObject][Ordered] @{
                "name"              = $ResourceRecord.Hostname
                "TTL"               = $ResourceRecord.TimeToLive.TotalMinutes
                "CLASS"             = $ResourceRecord.RecordClass
                "TYPE"              = $ResourceRecord.RecordType
                "DATA"              = $ResourceRecord.RecordData.DomainName
                "PORT"              = $ResourceRecord.RecordData.Port
                "PRIORITY"          = $ResourceRecord.RecordData.Priority
                "WEIGHT"            = $ResourceRecord.RecordData.Weight
            }
        }
        If ($FirstRun) {
            Set-UnboundDns -InputObject $RecordEntry -Zone $Zone -OutputFile $UnboundOut -FirstRun
        }
        Else {
            Set-UnboundDns -InputObject $RecordEntry -Zone $Zone -OutputFile $UnboundOut
        }
        $FirstRun = $false
        $RecordEntry
        $ZoneData += $RecordEntry
    }
    # $CurrentZoneFile = $RootZoneExportFile + $Zone + ".csv"
    # Copy-Item $TemplateZoneFile $CurrentZoneFile
    # $ZoneData | Export-Csv -Path $CurrentZoneFile -NoTypeInformation
}