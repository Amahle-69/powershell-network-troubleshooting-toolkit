
[CmdletBinding()]
param(
    [string]$ConnectivityTarget = '1.1.1.1',
    [string]$DnsName = 'example.com',
    [string]$TcpHost = 'example.com',

    [ValidateRange(1, 65535)]
    [int]$TcpPort = 443
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$reportDirectory = Join-Path $projectRoot 'reports'
$reportPath = Join-Path $reportDirectory 'network-diagnostics-report.csv'
$auditTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

$results = [System.Collections.Generic.List[object]]::new()

function Add-NetworkResult {
    param(
        [string]$CheckName,
        [string]$Status,
        [string]$ObservedValue,
        [string]$Finding,
        [string]$Recommendation
    )

    $results.Add([pscustomobject]@{
        AuditTimestamp = $auditTimestamp
        CheckName      = $CheckName
        Status         = $Status
        ObservedValue  = $ObservedValue
        Finding        = $Finding
        Recommendation = $Recommendation
    })
}

# 1. Check whether any network adapters report an Up state.
$activeAdapters = @()

try {
    $adapters = @(Get-NetAdapter -ErrorAction Stop)
    $activeAdapters = @(
        $adapters | Where-Object { $_.Status -eq 'Up' }
    )

    if ($activeAdapters.Count -gt 0) {
        Add-NetworkResult `
            -CheckName 'Network adapter status' `
            -Status 'Pass' `
            -ObservedValue "$($activeAdapters.Count) adapter(s) report Up; adapter details omitted." `
            -Finding 'At least one network adapter reports an Up state.' `
            -Recommendation 'Continue checking IP configuration and connectivity.'
    }
    else {
        Add-NetworkResult `
            -CheckName 'Network adapter status' `
            -Status 'Review' `
            -ObservedValue 'No adapters report Up.' `
            -Finding 'No network adapters reported an Up state.' `
            -Recommendation 'Check the network connection and adapter status in Windows.'
    }
}
catch {
    Add-NetworkResult `
        -CheckName 'Network adapter status' `
        -Status 'UnableToAssess' `
        -ObservedValue 'Adapter query failed; error details omitted.' `
        -Finding 'Network adapter status could not be assessed.' `
        -Recommendation 'Check command availability and permissions.'
}

# 2. Inspect IP configuration without recording actual IP addresses.
try {
    $configurations = @(Get-NetIPConfiguration -ErrorAction Stop)

    $activeConfigurations = @(
        $configurations | Where-Object {
            $null -ne $_.NetAdapter -and
            $_.NetAdapter.Status -eq 'Up'
        }
    )

    $ipv4AddressCount = 0
    $gatewayCount = 0
    $dnsServerCount = 0

    foreach ($configuration in $activeConfigurations) {
        $addresses = @(
            $configuration.IPv4Address | Where-Object {
                $null -ne $_ -and
                -not [string]::IsNullOrWhiteSpace([string]$_.IPAddress)
            }
        )

        $gateways = @(
            $configuration.IPv4DefaultGateway | Where-Object {
                $null -ne $_ -and
                -not [string]::IsNullOrWhiteSpace([string]$_.NextHop)
            }
        )

        $dnsServers = @(
            $configuration.DNSServer.ServerAddresses | Where-Object {
                -not [string]::IsNullOrWhiteSpace([string]$_)
            }
        )

        $ipv4AddressCount += $addresses.Count
        $gatewayCount += $gateways.Count
        $dnsServerCount += $dnsServers.Count
    }

    if ($activeConfigurations.Count -eq 0) {
        Add-NetworkResult `
            -CheckName 'IPv4 configuration' `
            -Status 'UnableToAssess' `
            -ObservedValue 'No active adapter configurations were returned.' `
            -Finding 'IPv4 configuration could not be assessed for active adapters.' `
            -Recommendation 'Review adapter state and available IP configuration.'
    }
    else {
        if ($ipv4AddressCount -gt 0) {
            $ipv4Status = 'Pass'
            $ipv4Finding = 'An IPv4 address is present on an active adapter.'
            $ipv4Recommendation = 'Continue with gateway, DNS, and connectivity checks.'
        }
        else {
            $ipv4Status = 'Review'
            $ipv4Finding = 'No IPv4 address was detected on active adapter configurations.'
            $ipv4Recommendation = 'Review DHCP settings and the adapter IPv4 configuration.'
        }

        Add-NetworkResult `
            -CheckName 'IPv4 configuration' `
            -Status $ipv4Status `
            -ObservedValue "$ipv4AddressCount IPv4 address record(s) detected; addresses omitted." `
            -Finding $ipv4Finding `
            -Recommendation $ipv4Recommendation

        if ($gatewayCount -gt 0) {
            $gatewayStatus = 'Pass'
            $gatewayFinding = 'A default gateway is configured on an active adapter.'
            $gatewayRecommendation = 'Continue with the selected connectivity test.'
        }
        else {
            $gatewayStatus = 'Review'
            $gatewayFinding = 'No default gateway was detected on active adapter configurations.'
            $gatewayRecommendation = 'Check routing requirements for the current network.'
        }

        Add-NetworkResult `
            -CheckName 'Default gateway configuration' `
            -Status $gatewayStatus `
            -ObservedValue "$gatewayCount default gateway record(s) detected; addresses omitted." `
            -Finding $gatewayFinding `
            -Recommendation $gatewayRecommendation

        if ($dnsServerCount -gt 0) {
            $dnsStatus = 'Pass'
            $dnsFinding = 'DNS server configuration is present on active adapters.'
            $dnsRecommendation = 'Continue with the DNS name-resolution check.'
        }
        else {
            $dnsStatus = 'Review'
            $dnsFinding = 'No DNS server addresses were detected on active adapter configurations.'
            $dnsRecommendation = 'Check the configured DNS servers and DHCP settings.'
        }

        Add-NetworkResult `
            -CheckName 'DNS server configuration' `
            -Status $dnsStatus `
            -ObservedValue "$dnsServerCount DNS server record(s) detected; addresses omitted." `
            -Finding $dnsFinding `
            -Recommendation $dnsRecommendation
    }
}
catch {
    Add-NetworkResult `
        -CheckName 'IP configuration inspection' `
        -Status 'UnableToAssess' `
        -ObservedValue 'IP configuration query failed; details omitted.' `
        -Finding 'IP configuration could not be fully inspected.' `
        -Recommendation 'Check the networking cmdlets and permissions.'
}

# 3. Test reachability of the selected target.
try {
    $pingCommand = Get-Command Test-Connection -ErrorAction Stop

    $pingSucceeded = Test-Connection `
        -ComputerName $ConnectivityTarget `
        -Count 2 `
        -Quiet `
        -ErrorAction Stop

    if ($pingSucceeded) {
        Add-NetworkResult `
            -CheckName 'Destination reachability' `
            -Status 'Pass' `
            -ObservedValue "Target $ConnectivityTarget responded to the connectivity test." `
            -Finding 'The selected destination responded to the test.' `
            -Recommendation 'Continue with DNS and TCP checks.'
    }
    else {
        Add-NetworkResult `
            -CheckName 'Destination reachability' `
            -Status 'Review' `
            -ObservedValue "Target $ConnectivityTarget did not respond to the connectivity test." `
            -Finding 'No response was received from the selected destination.' `
            -Recommendation 'Check the target and route. ICMP traffic may be blocked, so this alone does not prove the network is unavailable.'
    }
}
catch {
    Add-NetworkResult `
        -CheckName 'Destination reachability' `
        -Status 'UnableToAssess' `
        -ObservedValue 'Connectivity test could not be completed; details omitted.' `
        -Finding 'The selected destination could not be assessed using this test.' `
        -Recommendation 'Check the target value, command availability, and local connectivity.'
}

# 4. Resolve the selected DNS name without storing returned IP addresses.
try {
    $dnsCommand = Get-Command Resolve-DnsName -ErrorAction Stop

    $dnsAnswers = @(
        Resolve-DnsName -Name $DnsName -ErrorAction Stop |
            Where-Object { $_.Type -in @('A', 'AAAA', 'CNAME') }
    )

    if ($dnsAnswers.Count -gt 0) {
        Add-NetworkResult `
            -CheckName 'DNS name resolution' `
            -Status 'Pass' `
            -ObservedValue "Name $DnsName resolved; $($dnsAnswers.Count) answer record(s); IP addresses omitted." `
            -Finding 'The selected DNS name returned an answer.' `
            -Recommendation 'Continue with the TCP service connectivity check.'
    }
    else {
        Add-NetworkResult `
            -CheckName 'DNS name resolution' `
            -Status 'Review' `
            -ObservedValue "No A, AAAA, or CNAME answers were returned for $DnsName." `
            -Finding 'The query did not return the expected address or alias records.' `
            -Recommendation 'Verify the hostname and the DNS records expected for it.'
    }
}
catch {
    Add-NetworkResult `
        -CheckName 'DNS name resolution' `
        -Status 'Review' `
        -ObservedValue "DNS query for $DnsName failed; technical details omitted." `
        -Finding 'The selected DNS name could not be resolved by this query.' `
        -Recommendation 'Check the hostname, DNS server configuration, and network connectivity.'
}

# 5. Test TCP connectivity to the selected host and port.
try {
    $tcpCommand = Get-Command Test-NetConnection -ErrorAction Stop

    $tcpSucceeded = Test-NetConnection `
        -ComputerName $TcpHost `
        -Port $TcpPort `
        -InformationLevel Quiet `
        -WarningAction SilentlyContinue `
        -ErrorAction Stop

    if ($tcpSucceeded) {
        Add-NetworkResult `
            -CheckName 'TCP service connectivity' `
            -Status 'Pass' `
            -ObservedValue "TCP connection to $TcpHost on port $TcpPort succeeded." `
            -Finding 'A TCP connection to the selected host and port succeeded.' `
            -Recommendation 'If the reported application problem persists, investigate the application and its configuration.'
    }
    else {
        Add-NetworkResult `
            -CheckName 'TCP service connectivity' `
            -Status 'Review' `
            -ObservedValue "TCP connection to $TcpHost on port $TcpPort did not succeed." `
            -Finding 'A TCP connection to the selected host and port was not established.' `
            -Recommendation 'Check DNS, routing, service availability, firewall policy, and whether the destination should accept connections on this port.'
    }
}
catch {
    Add-NetworkResult `
        -CheckName 'TCP service connectivity' `
        -Status 'UnableToAssess' `
        -ObservedValue 'TCP connectivity test failed to run; details omitted.' `
        -Finding 'TCP connectivity could not be assessed.' `
        -Recommendation 'Check command availability, target values, and permissions.'
}

# 6. Export the report.
if (-not (Test-Path -LiteralPath $reportDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $reportDirectory -Force |
        Out-Null
}

$results |
    Export-Csv -LiteralPath $reportPath -NoTypeInformation -Encoding UTF8

$passCount = @($results | Where-Object Status -eq 'Pass').Count
$reviewCount = @($results | Where-Object Status -eq 'Review').Count
$unableCount = @($results | Where-Object Status -eq 'UnableToAssess').Count

Write-Host "`nNetwork diagnostics completed." -ForegroundColor Green
Write-Host "Checks reporting Pass: $passCount"
Write-Host "Checks needing review: $reviewCount"
Write-Host "Checks unable to assess: $unableCount"
Write-Host "Report saved to: $reportPath"
Write-Host 'No network settings were changed.'

$results |
    Format-Table CheckName, Status, ObservedValue -Wrap -AutoSize
