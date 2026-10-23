[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Endpoint = "https://horgearhunte-p5jnpha3.manus.space/api/phoenix/market-ledger/submit",
    [Parameter(Mandatory = $false)]
    [string]$ObservationFile = (Join-Path $PSScriptRoot "..\data\observations.tsv"),
    [Parameter(Mandatory = $false)]
    [SecureString]$CollectorToken
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ObservationFile -PathType Leaf)) {
    throw "Observation file was not found: $ObservationFile"
}

if ($null -eq $CollectorToken) {
    $CollectorToken = Read-Host -AsSecureString "Enter your revocable Phoenix Market Ledger collector key"
}

$tokenBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($CollectorToken)
try {
    $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($tokenBstr)
    if ([string]::IsNullOrWhiteSpace($token) -or -not $token.StartsWith("pml_")) {
        throw "The collector key must start with pml_."
    }

    $observations = @(
        Import-Csv -LiteralPath $ObservationFile -Delimiter "`t" |
        Where-Object { $_.observedAt -and $_.itemId -and $_.side -and $_.priceGil -and $_.evidence } |
        ForEach-Object {
            [PSCustomObject]@{
                itemId     = [int]$_.itemId
                side       = [string]$_.side
                priceGil   = [int]$_.priceGil
                observedAt = [string]$_.observedAt
                evidence   = [string]$_.evidence
            }
        }
    )

    if ($observations.Count -eq 0) {
        Write-Host "No local observations are ready to submit."
        exit 0
    }
    if ($observations.Count -gt 250) {
        throw "The local file contains $($observations.Count) rows. Upload at most 250 at a time."
    }

    $payload = @{ observations = $observations } | ConvertTo-Json -Depth 4 -Compress
    $response = Invoke-RestMethod -Method Post -Uri $Endpoint -ContentType "application/json" -Headers @{ Authorization = "Bearer $token" } -Body $payload
    if (-not $response.ok) {
        throw "The market ledger rejected the upload."
    }

    # The server has fingerprint deduplication. Clear only after its accepted response.
    Set-Content -LiteralPath $ObservationFile -Value "observedAt`titemId`tside`tpriceGil`tevidence" -Encoding utf8
    Write-Host "Accepted $($response.accepted) observation(s). The local queue is now clear."
}
finally {
    if ($tokenBstr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($tokenBstr)
    }
}
