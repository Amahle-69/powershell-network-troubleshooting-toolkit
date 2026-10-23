
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$diagnosticScript = Join-Path $projectRoot 'scripts\Invoke-NetworkDiagnostics.ps1'
$reportPath = Join-Path $projectRoot 'reports\network-diagnostics-report.csv'

$script:passed = 0
$script:failed = 0

function Assert-True {
    param(
        [string]$Name,
        [bool]$Condition
    )

    if ($Condition) {
        Write-Host "[PASS] $Name" -ForegroundColor Green
        $script:passed++
    }
    else {
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        $script:failed++
    }
}

# Confirm the diagnostic script exists.
Assert-True `
    -Name 'Network diagnostic script exists' `
    -Condition (Test-Path -LiteralPath $diagnosticScript -PathType Leaf)

if (-not (Test-Path -LiteralPath $diagnosticScript -PathType Leaf)) {
    throw 'Cannot run the tests because the diagnostic script is missing.'
}

# Run the real diagnostics and produce a fresh report.
& $diagnosticScript | Out-Null

Assert-True `
    -Name 'Network diagnostics report was generated' `
    -Condition (Test-Path -LiteralPath $reportPath -PathType Leaf)

if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw 'Cannot continue because the network diagnostics report was not generated.'
}

$results = @(Import-Csv -LiteralPath $reportPath)

Assert-True `
    -Name 'Report contains seven diagnostic checks' `
    -Condition ($results.Count -eq 7)

# Verify the required report columns.
$requiredColumns = @(
    'AuditTimestamp',
    'CheckName',
    'Status',
    'ObservedValue',
    'Finding',
    'Recommendation'
)

$actualColumns = @($results[0].PSObject.Properties.Name)

$missingColumns = @(
    $requiredColumns |
        Where-Object { $actualColumns -notcontains $_ }
)

Assert-True `
    -Name 'All required report columns are present' `
    -Condition ($missingColumns.Count -eq 0)

# Verify that the expected diagnostic checks are present exactly once.
$expectedChecks = @(
    'Network adapter status',
    'IPv4 configuration',
    'Default gateway configuration',
    'DNS server configuration',
    'Destination reachability',
    'DNS name resolution',
    'TCP service connectivity'
)

foreach ($checkName in $expectedChecks) {
    $matchingRows = @(
        $results | Where-Object { $_.CheckName -eq $checkName }
    )

    Assert-True `
        -Name "Check is recorded exactly once: $checkName" `
        -Condition ($matchingRows.Count -eq 1)
}

# Confirm statuses use the documented labels.
$allowedStatuses = @('Pass', 'Review', 'UnableToAssess')

$invalidStatuses = @(
    $results | Where-Object { $_.Status -notin $allowedStatuses }
)

Assert-True `
    -Name 'All results use documented status labels' `
    -Condition ($invalidStatuses.Count -eq 0)

# Every result must include a finding and recommendation.
$incompleteRows = @(
    $results | Where-Object {
        [string]::IsNullOrWhiteSpace($_.Finding) -or
        [string]::IsNullOrWhiteSpace($_.Recommendation)
    }
)

Assert-True `
    -Name 'Every result includes a finding and recommendation' `
    -Condition ($incompleteRows.Count -eq 0)

# Check that report column names exclude direct machine identifiers.
$disallowedColumns = @(
    'ComputerName',
    'UserName',
    'Username',
    'IPAddress',
    'MacAddress',
    'SerialNumber'
)

$exposedColumns = @(
    $actualColumns | Where-Object { $_ -in $disallowedColumns }
)

Assert-True `
    -Name 'Report columns exclude direct machine identifiers' `
    -Condition ($exposedColumns.Count -eq 0)

# Status totals should account for all report rows.
$passCount = @($results | Where-Object Status -eq 'Pass').Count
$reviewCount = @($results | Where-Object Status -eq 'Review').Count
$unableCount = @($results | Where-Object Status -eq 'UnableToAssess').Count

Assert-True `
    -Name 'Status totals match the report row count' `
    -Condition (($passCount + $reviewCount + $unableCount) -eq $results.Count)

Write-Host "`nNetwork diagnostics test summary" -ForegroundColor Cyan
Write-Host "Passed: $script:passed"
Write-Host "Failed: $script:failed"

if ($script:failed -gt 0) {
    throw 'One or more network diagnostics tests failed.'
}

Write-Host "`nAll network diagnostics report tests passed." -ForegroundColor Green
