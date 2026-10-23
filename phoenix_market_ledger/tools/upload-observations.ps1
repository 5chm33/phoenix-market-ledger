[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Endpoint = "https://horgearhunte-p5jnpha3.manus.space/api/phoenix/market-ledger/submit",
    [Parameter(Mandatory = $false)]
    [string]$ObservationFile = (Join-Path $PSScriptRoot "..\data\observations.tsv"),
    [Parameter(Mandatory = $false)]
    [SecureString]$CollectorToken,
    [Parameter(Mandatory = $false)]
    [switch]$Watch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$BatchSize = 100
$SweepSeconds = 30

function Write-QueueFile {
    param([object[]]$Rows)
    $directory = Split-Path -LiteralPath $ObservationFile -Parent
    $temporary = Join-Path $directory ("observations-{0}.tmp" -f [guid]::NewGuid().ToString("N"))
    $header = "eventId`tschemaVersion`treleaseVersion`tobservedAt`titemId`tquantity`tpriceGil`tevidence"
    if ($Rows.Count -gt 0) {
        $Rows | Select-Object eventId, schemaVersion, releaseVersion, observedAt, itemId, quantity, priceGil, evidence |
            ConvertTo-Csv -Delimiter "`t" -NoTypeInformation |
            Set-Content -LiteralPath $temporary -Encoding utf8
    }
    else {
        Set-Content -LiteralPath $temporary -Value $header -Encoding utf8
    }
    Move-Item -LiteralPath $temporary -Destination $ObservationFile -Force
}

function Append-SentAudit {
    param([object[]]$Rows)
    if ($Rows.Count -eq 0) { return }
    $auditFile = Join-Path (Split-Path -LiteralPath $ObservationFile -Parent) "sent-observations.tsv"
    $needsHeader = -not (Test-Path -LiteralPath $auditFile -PathType Leaf)
    if ($needsHeader) {
        "eventId`tschemaVersion`treleaseVersion`tobservedAt`titemId`tquantity`tpriceGil`tevidence" | Set-Content -LiteralPath $auditFile -Encoding utf8
    }
    $Rows | Select-Object eventId, schemaVersion, releaseVersion, observedAt, itemId, quantity, priceGil, evidence |
        ConvertTo-Csv -Delimiter "`t" -NoTypeInformation |
        Select-Object -Skip 1 |
        Add-Content -LiteralPath $auditFile -Encoding utf8
}

function Get-QueuedObservations {
    if (-not (Test-Path -LiteralPath $ObservationFile -PathType Leaf)) {
        throw "Observation file was not found: $ObservationFile"
    }
    return @(
        Import-Csv -LiteralPath $ObservationFile -Delimiter "`t" |
        Where-Object {
            $_.eventId -and $_.schemaVersion -and $_.releaseVersion -and $_.observedAt -and $_.itemId -and $_.quantity -and $_.priceGil -and $_.evidence
        } |
        ForEach-Object {
            [PSCustomObject]@{
                eventId        = [string]$_.eventId
                schemaVersion  = [string]$_.schemaVersion
                releaseVersion = [string]$_.releaseVersion
                observedAt     = [string]$_.observedAt
                itemId         = [int]$_.itemId
                quantity       = [int]$_.quantity
                priceGil       = [int]$_.priceGil
                evidence       = [string]$_.evidence
            }
        }
    )
}

function Invoke-UploadQueue {
    param([string]$Token)
    $queued = @(Get-QueuedObservations)
    if ($queued.Count -eq 0) {
        return 0
    }
    $uploaded = @()
    $remaining = @($queued)
    for ($offset = 0; $offset -lt $queued.Count; $offset += $BatchSize) {
        $count = [Math]::Min($BatchSize, $queued.Count - $offset)
        $batch = @($queued[$offset..($offset + $count - 1)])
        $payload = @{ observations = $batch } | ConvertTo-Json -Depth 5 -Compress
        try {
            $response = Invoke-RestMethod -Method Post -Uri $Endpoint -ContentType "application/json" -Headers @{ Authorization = "Bearer $Token" } -Body $payload -TimeoutSec 20
            if (-not $response.ok) { throw "The market ledger rejected the upload." }
            $uploaded += $batch
            $remaining = @($queued | Select-Object -Skip ($offset + $count))
        }
        catch {
            # Preserve every unacknowledged event locally. Event IDs make a retry
            # harmless if an acknowledgement was lost after the server accepted it.
            $remaining = @($queued | Select-Object -Skip $offset)
            Write-Warning "Upload paused: $($_.Exception.Message)"
            break
        }
    }
    if ($uploaded.Count -gt 0) {
        Append-SentAudit -Rows $uploaded
        Write-QueueFile -Rows $remaining
        Write-Host "Server accepted $($uploaded.Count) completed-sale observation(s). $($remaining.Count) remain in the local outbox."
    }
    return $uploaded.Count
}

if ($null -eq $CollectorToken) {
    $CollectorToken = Read-Host -AsSecureString "Enter your revocable Phoenix Market Ledger upload key"
}

$tokenBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($CollectorToken)
try {
    $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($tokenBstr)
    if ([string]::IsNullOrWhiteSpace($token) -or -not $token.StartsWith("pml_")) {
        throw "The upload key must start with pml_."
    }

    if (-not $Watch) {
        [void](Invoke-UploadQueue -Token $token)
        exit 0
    }

    # This is an external Windows process. It observes local file changes and does
    # a bounded periodic sweep to recover missed watcher events; it never runs in,
    # or communicates back to, the game process.
    $directory = Split-Path -LiteralPath $ObservationFile -Parent
    $filename = Split-Path -LiteralPath $ObservationFile -Leaf
    $watcher = [System.IO.FileSystemWatcher]::new($directory, $filename)
    $watcher.EnableRaisingEvents = $true
    $changed = $true
    $handler = { $script:changed = $true }
    $subscriptions = @(
        Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $handler,
        Register-ObjectEvent -InputObject $watcher -EventName Created -Action $handler,
        Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $handler
    )
    Write-Host "Phoenix Market Ledger uploader is watching the local outbox. Press Ctrl+C to stop; no game process network activity occurs."
    try {
        while ($true) {
            if ($changed) {
                $changed = $false
                Start-Sleep -Milliseconds 400
                [void](Invoke-UploadQueue -Token $token)
            }
            Start-Sleep -Seconds $SweepSeconds
            [void](Invoke-UploadQueue -Token $token)
        }
    }
    finally {
        $subscriptions | ForEach-Object { Unregister-Event -SubscriptionId $_.Id -ErrorAction SilentlyContinue }
        $watcher.Dispose()
    }
}
finally {
    if ($tokenBstr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($tokenBstr)
    }
}
