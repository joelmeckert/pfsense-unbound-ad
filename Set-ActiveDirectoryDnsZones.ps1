# Creates configuration files from the output of Get-ActiveDirectoryDnsZones

Function Set-UnboundDns {
    Param (
        [Parameter(Mandatory=$false)]
        [switch]$FirstRun
        ,
        [Parameter(Mandatory=$true)]
        $InputObject
        ,
        [Parameter(Mandatory=$true)]
        $Zone
        ,
        [Parameter(Mandatory=$true)]
        $OutputFile
    )
    Function LineOut {
        $Line | Out-File -FilePath $OutputFile -Encoding ascii -NoNewline -Append
    }
    If (($FirstRun.IsPresent) -and ($InputObject.TYPE -ne "SOA")) {
        $Line = 'local-zone: "' + $Zone + "`"" + " " + "typetransparent`n"
        $Line += 'private-domain: "' + $Zone + "`"" + "`n"
    }
    $Line += 'local-data: "' + $InputObject.name + "." + $Zone + "." + " " + ($InputObject.TTL * 60) + " " + $InputObject.Class + " " + $InputObject.TYPE + " "
    # Types A, CNAME, NS, SOA, SRV
    # Order: hostname, TTL, TYPE, 
    If ($InputObject.TYPE -eq "A") {
        # Order: name, TTL, TYPE, DATA
        $Line += $InputObject.DATA + "`"" + "`n"
        LineOut
    }
    ElseIf ($InputObject.TYPE -eq "CNAME") {
        # Order: name, TTL, TYPE, DATA
        $Line += $InputObject.DATA + "`"" + "`n"
        LineOut
    }
    ElseIf ($InputObject.TYPE -eq "NS") {
        $Line += $InputObject.DATA + "`"" + "`n"
        LineOut
    }
    #ElseIf ($InputObject.TYPE -eq "SOA") {
    #    
    #}
    ElseIf ($InputObject.TYPE -eq "SRV") {
        If ($InputObject.PRIORITY -eq 0) {
            $Line += "0" + " " + $InputObject.WEIGHT + " " + $InputObject.PORT + " " + $InputObject.DATA + "`"" + "`n"
        }
        Else {
            $Line += $InputObject.PRIORITY + " " + $InputObject.WEIGHT + " " + $InputObject.PORT + " " + $InputObject.DATA + "`"" + "`n"
        }
        LineOut
    }
}