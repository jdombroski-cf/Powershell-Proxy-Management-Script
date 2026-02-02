<#
.SYNOPSIS
    Manages Cloudflare DNS record proxy settings across all zones in an account.

.DESCRIPTION
    Automates enabling or disabling Cloudflare proxy (orange cloud) for DNS records
    across all zones in your Cloudflare account. Tracks changes via record comments 
    for intelligent state management.
    
    LEGAL DISCLAIMER: This script is provided for testing and educational purposes only.
    Cloudflare, Inc. cannot be held liable for any issues arising from the use of this script.
    Use at your own risk. See README.md for full legal disclaimer.

.PARAMETER Enable
    Enables proxy for all records that were previously disabled by this script.
    Only affects records with comment "Disabled Proxy on *".

.PARAMETER Disable
    Disables proxy for all currently proxied A, AAAA, and CNAME records.
    Adds comment "Disabled Proxy on YYYY-MM-DD" to each record.

.PARAMETER DryRun
    Preview what changes would be made without actually making them.
    Useful for testing and validation before executing.

.PARAMETER LogPath
    Path where the log file will be created. Directory will be created if it doesn't exist.
    Default: .\Logs\CloudflareProxy_YYYYMMDD_HHMMSS.log

.PARAMETER KeepLogsForDays
    Number of days to keep old log files. Older logs will be automatically deleted.
    Default: 30 days. Set to 0 to disable automatic cleanup.

.EXAMPLE
    .\Manage-CloudflareProxies.ps1 -Disable
    Disables proxy for all A, AAAA, and CNAME records across all zones.

.EXAMPLE
    .\Manage-CloudflareProxies.ps1 -Enable -Verbose
    Enables proxy for previously disabled records with detailed verbose output.

.EXAMPLE
    .\Manage-CloudflareProxies.ps1 -Disable -DryRun
    Preview which records would be affected without making changes.

.EXAMPLE
    .\Manage-CloudflareProxies.ps1 -Enable -LogPath "C:\Logs\cf-proxy.log"
    Enable proxies with custom log file location.

.NOTES
    Version: 1.0.0
    Author: Cloudflare Community
    Requires: PowerShell 5.1+ or PowerShell Core 7+
    
    Prerequisites:
    - Environment Variable: CLOUDFLARE_API_TOKEN must be set
    - Required API Permissions: Zone:Read, DNS:Edit
    - Internet connectivity to api.cloudflare.com
    
    Supported Record Types: A, AAAA, CNAME (only types that support Cloudflare proxy)
#>

[CmdletBinding(DefaultParameterSetName='None')]
param(
    [Parameter(ParameterSetName='Enable', Mandatory=$true)]
    [switch]$Enable,
    
    [Parameter(ParameterSetName='Disable', Mandatory=$true)]
    [switch]$Disable,
    
    [Parameter()]
    [switch]$DryRun,
    
    [Parameter()]
    [string]$LogPath = ".\Logs\CloudflareProxy_$(Get-Date -Format 'yyyyMMdd_HHmmss').log",
    
    [Parameter()]
    [int]$KeepLogsForDays = 30
)

#Requires -Version 5.1

# Script-level variables
$script:ApiBase = "https://api.cloudflare.com/client/v4"
$script:ApiToken = $null
$script:LogFile = $null
$script:Statistics = @{
    ZonesProcessed = 0
    RecordsModified = 0
    RecordsSkipped = 0
    Errors = 0
    StartTime = Get-Date
}

#region Logging Functions

<#
.SYNOPSIS
    Initializes the logging system and creates log directory if needed.
#>
function Initialize-Logging {
    param([string]$Path)
    
    try {
        # Get absolute path
        $script:LogFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        
        # Create directory if it doesn't exist
        $logDir = Split-Path -Path $script:LogFile -Parent
        if (-not (Test-Path -Path $logDir)) {
            Write-Verbose "Creating log directory: $logDir"
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        
        # Initialize log file
        $header = @"
================================================================================
Cloudflare Proxy Management Script
Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Mode: $(if ($Enable) { 'ENABLE' } else { 'DISABLE' })
Dry Run: $(if ($DryRun) { 'YES' } else { 'NO' })
================================================================================

"@
        $header | Out-File -FilePath $script:LogFile -Encoding UTF8
        
        Write-Verbose "Log file initialized: $script:LogFile"
        
        # Clean up old logs if configured
        if ($KeepLogsForDays -gt 0) {
            Clear-OldLogs -LogDirectory $logDir -DaysToKeep $KeepLogsForDays
        }
        
        return $true
    }
    catch {
        Write-Error "Failed to initialize logging: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Writes a message to both console and log file.
#>
function Write-ProxyLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    if ($script:LogFile) {
        $logMessage | Out-File -FilePath $script:LogFile -Append -Encoding UTF8
    }
    
    # Write to console with color
    switch ($Level) {
        'INFO'    { Write-Host $Message -ForegroundColor Cyan }
        'SUCCESS' { Write-Host $Message -ForegroundColor Green }
        'WARNING' { Write-Warning $Message }
        'ERROR'   { Write-Host $Message -ForegroundColor Red }
    }
}

<#
.SYNOPSIS
    Cleans up log files older than specified days.
#>
function Clear-OldLogs {
    param(
        [string]$LogDirectory,
        [int]$DaysToKeep
    )
    
    try {
        $cutoffDate = (Get-Date).AddDays(-$DaysToKeep)
        $pattern = "CloudflareProxy_*.log"
        
        $oldLogs = Get-ChildItem -Path $LogDirectory -Filter $pattern -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoffDate }
        
        if ($oldLogs) {
            Write-Verbose "Cleaning up $($oldLogs.Count) old log file(s)"
            foreach ($log in $oldLogs) {
                Write-Verbose "Deleting old log: $($log.Name)"
                Remove-Item -Path $log.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        Write-Verbose "Warning: Failed to clean up old logs: $_"
        # Don't fail the script if log cleanup fails
    }
}

#endregion

#region API Functions

<#
.SYNOPSIS
    Invokes Cloudflare API with retry logic and exponential backoff.
#>
function Invoke-CloudflareApiWithRetry {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,
        
        [Parameter()]
        [string]$Method = 'GET',
        
        [Parameter()]
        [object]$Body = $null,
        
        [Parameter()]
        [int]$MaxRetries = 3,
        
        [Parameter()]
        [int]$InitialDelaySeconds = 1
    )
    
    $headers = @{
        'Authorization' = "Bearer $script:ApiToken"
        'Content-Type' = 'application/json'
    }
    
    $attempt = 0
    $delay = $InitialDelaySeconds
    
    while ($attempt -lt $MaxRetries) {
        try {
            $attempt++
            Write-Verbose "$Method $Uri (Attempt $attempt/$MaxRetries)"
            
            $params = @{
                Uri = $Uri
                Method = $Method
                Headers = $headers
                ErrorAction = 'Stop'
            }
            
            if ($Body -and $Method -ne 'GET') {
                $jsonBody = $Body | ConvertTo-Json -Depth 10 -Compress
                Write-Verbose "Request body: $jsonBody"
                $params['Body'] = $jsonBody
            }
            
            $response = Invoke-RestMethod @params
            
            Write-Verbose "API call successful"
            return $response
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            
            Write-Verbose "API call failed: $($_.Exception.Message) (Status: $statusCode)"
            
            # Handle rate limiting specially
            if ($statusCode -eq 429) {
                Write-ProxyLog "Rate limited by Cloudflare API. Waiting before retry..." -Level WARNING
                Start-Sleep -Seconds ($delay * 2)
            }
            
            # If this was our last attempt, throw the error
            if ($attempt -ge $MaxRetries) {
                throw "API call failed after $MaxRetries attempts: $($_.Exception.Message)"
            }
            
            # Wait before retrying with exponential backoff
            Write-Verbose "Waiting $delay seconds before retry..."
            Start-Sleep -Seconds $delay
            $delay = $delay * 2
        }
    }
}

<#
.SYNOPSIS
    Retrieves all zones in the Cloudflare account with pagination support.
#>
function Get-CloudflareZones {
    Write-Verbose "Fetching all zones from Cloudflare account"
    
    $allZones = @()
    $page = 1
    $perPage = 100
    
    do {
        $uri = "$script:ApiBase/zones?page=$page&per_page=$perPage"
        
        try {
            $response = Invoke-CloudflareApiWithRetry -Uri $uri -Method GET
            
            if ($response.result) {
                $allZones += $response.result
                Write-Verbose "Retrieved $($response.result.Count) zones from page $page"
            }
            
            # Check if there are more pages
            $hasMorePages = ($response.result_info.page * $response.result_info.per_page) -lt $response.result_info.total_count
            $page++
        }
        catch {
            Write-ProxyLog "Failed to fetch zones: $_" -Level ERROR
            throw
        }
    } while ($hasMorePages)
    
    Write-Verbose "Total zones retrieved: $($allZones.Count)"
    return $allZones
}

<#
.SYNOPSIS
    Retrieves DNS records for a zone with optional filtering.
#>
function Get-CloudflareDnsRecords {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ZoneId,
        
        [Parameter()]
        [ValidateSet('A', 'AAAA', 'CNAME')]
        [string[]]$RecordTypes = @('A', 'AAAA', 'CNAME'),
        
        [Parameter()]
        [bool]$ProxiedOnly = $false,
        
        [Parameter()]
        [string]$CommentStartsWith = $null
    )
    
    Write-Verbose "Fetching DNS records for zone: $ZoneId"
    
    $allRecords = @()
    $page = 1
    $perPage = 100
    
    do {
        # Build query string
        $queryParams = @(
            "page=$page"
            "per_page=$perPage"
        )
        
        # Add proxy filter
        if ($ProxiedOnly) {
            $queryParams += "proxied=true"
        }
        
        $uri = "$script:ApiBase/zones/$ZoneId/dns_records?" + ($queryParams -join '&')
        
        try {
            $response = Invoke-CloudflareApiWithRetry -Uri $uri -Method GET
            
            if ($response.result) {
                $allRecords += $response.result
                Write-Verbose "Retrieved $($response.result.Count) records from page $page"
            }
            
            # Check if there are more pages
            $hasMorePages = $response.result_info -and 
                           ($response.result_info.page * $response.result_info.per_page) -lt $response.result_info.total_count
            $page++
        }
        catch {
            Write-ProxyLog "Failed to fetch DNS records for zone $ZoneId : $_" -Level ERROR
            throw
        }
    } while ($hasMorePages)
    
    # Filter by record type client-side (API doesn't support multiple types in one query)
    if ($RecordTypes) {
        $allRecords = $allRecords | Where-Object { $_.type -in $RecordTypes }
    }
    
    # Filter by comment prefix client-side (API filter syntax not reliable)
    if ($CommentStartsWith) {
        $allRecords = $allRecords | Where-Object { $_.comment -like "$CommentStartsWith*" }
    }
    
    Write-Verbose "Total records retrieved: $($allRecords.Count)"
    return $allRecords
}

<#
.SYNOPSIS
    Updates a DNS record's proxy status and comment.
#>
function Update-CloudflareDnsRecord {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ZoneId,
        
        [Parameter(Mandatory=$true)]
        [string]$RecordId,
        
        [Parameter(Mandatory=$true)]
        [bool]$Proxied,
        
        [Parameter(Mandatory=$true)]
        [string]$Comment
    )
    
    $uri = "$script:ApiBase/zones/$ZoneId/dns_records/$RecordId"
    
    $body = @{
        proxied = $Proxied
        comment = $Comment
    }
    
    try {
        Write-Verbose "Updating record $RecordId : proxied=$Proxied, comment='$Comment'"
        $response = Invoke-CloudflareApiWithRetry -Uri $uri -Method PATCH -Body $body
        return $response.result
    }
    catch {
        throw "Failed to update DNS record: $_"
    }
}

<#
.SYNOPSIS
    Tests Cloudflare API connectivity and token validity.
#>
function Test-CloudflareApiToken {
    Write-Verbose "Testing Cloudflare API connectivity"
    
    try {
        $uri = "$script:ApiBase/zones?page=1&per_page=1"
        $response = Invoke-CloudflareApiWithRetry -Uri $uri -Method GET
        
        if ($response.success) {
            Write-Verbose "API connectivity test successful"
            return $true
        }
        else {
            Write-ProxyLog "API test failed: $($response.errors)" -Level ERROR
            return $false
        }
    }
    catch {
        Write-ProxyLog "API connectivity test failed: $_" -Level ERROR
        return $false
    }
}

#endregion

#region Main Logic

<#
.SYNOPSIS
    Disables proxy for all proxied DNS records in all zones.
#>
function Disable-CloudflareProxies {
    Write-ProxyLog "Starting proxy DISABLE operation" -Level INFO
    
    if ($DryRun) {
        Write-ProxyLog "DRY RUN MODE - No changes will be made" -Level WARNING
    }
    
    try {
        # Get all zones
        $zones = Get-CloudflareZones
        
        if (-not $zones -or $zones.Count -eq 0) {
            Write-ProxyLog "No zones found in account" -Level WARNING
            return
        }
        
        Write-ProxyLog "Found $($zones.Count) zone(s) to process" -Level INFO
        
        foreach ($zone in $zones) {
            $script:Statistics.ZonesProcessed++
            
            Write-ProxyLog "`nProcessing zone: $($zone.name)" -Level INFO
            Write-Verbose "Zone ID: $($zone.id)"
            
            # Get all proxied A, AAAA, and CNAME records
            try {
                $records = Get-CloudflareDnsRecords -ZoneId $zone.id -ProxiedOnly $true
                
                if (-not $records -or $records.Count -eq 0) {
                    Write-ProxyLog "  No proxied records found in zone $($zone.name)" -Level INFO
                    continue
                }
                
                Write-ProxyLog "  Found $($records.Count) proxied record(s)" -Level INFO
                
                foreach ($record in $records) {
                    $recordInfo = "$($record.name) ($($record.type))"
                    
                    Write-Verbose "Evaluating record: $recordInfo"
                    Write-Verbose "  Current proxied status: $($record.proxied)"
                    Write-Verbose "  Current content: $($record.content)"
                    
                    if ($DryRun) {
                        Write-ProxyLog "  [DRY RUN] Would disable proxy: $recordInfo" -Level INFO
                        $script:Statistics.RecordsModified++
                    }
                    else {
                        try {
                            $comment = "Disabled Proxy on $(Get-Date -Format 'yyyy-MM-dd')"
                            
                            Update-CloudflareDnsRecord `
                                -ZoneId $zone.id `
                                -RecordId $record.id `
                                -Proxied $false `
                                -Comment $comment
                            
                            Write-ProxyLog "  [SUCCESS] Disabled proxy: $recordInfo" -Level SUCCESS
                            $script:Statistics.RecordsModified++
                        }
                        catch {
                            Write-ProxyLog "  [ERROR] Failed to update $recordInfo : $_" -Level ERROR
                            $script:Statistics.Errors++
                        }
                    }
                }
            }
            catch {
                Write-ProxyLog "  [ERROR] Failed to process zone $($zone.name): $_" -Level ERROR
                $script:Statistics.Errors++
                continue
            }
        }
    }
    catch {
        Write-ProxyLog "Critical error during disable operation: $_" -Level ERROR
        throw
    }
}

<#
.SYNOPSIS
    Enables proxy for all records previously disabled by this script.
#>
function Enable-CloudflareProxies {
    Write-ProxyLog "Starting proxy ENABLE operation" -Level INFO
    
    if ($DryRun) {
        Write-ProxyLog "DRY RUN MODE - No changes will be made" -Level WARNING
    }
    
    try {
        # Get all zones
        $zones = Get-CloudflareZones
        
        if (-not $zones -or $zones.Count -eq 0) {
            Write-ProxyLog "No zones found in account" -Level WARNING
            return
        }
        
        Write-ProxyLog "Found $($zones.Count) zone(s) to process" -Level INFO
        
        foreach ($zone in $zones) {
            $script:Statistics.ZonesProcessed++
            
            Write-ProxyLog "`nProcessing zone: $($zone.name)" -Level INFO
            Write-Verbose "Zone ID: $($zone.id)"
            
            # Get all records with "Disabled Proxy on" comment
            try {
                # First get all A, AAAA, CNAME records
                $allRecords = Get-CloudflareDnsRecords -ZoneId $zone.id
                
                # Filter for unproxied records with the disable comment
                $records = $allRecords | Where-Object {
                    $_.proxied -eq $false -and 
                    $_.comment -match '^Disabled Proxy on \d{4}-\d{2}-\d{2}'
                }
                
                if (-not $records -or $records.Count -eq 0) {
                    Write-ProxyLog "  No records to enable in zone $($zone.name)" -Level INFO
                    continue
                }
                
                Write-ProxyLog "  Found $($records.Count) record(s) to enable" -Level INFO
                
                foreach ($record in $records) {
                    $recordInfo = "$($record.name) ($($record.type))"
                    
                    Write-Verbose "Evaluating record: $recordInfo"
                    Write-Verbose "  Current proxied status: $($record.proxied)"
                    Write-Verbose "  Current comment: $($record.comment)"
                    Write-Verbose "  Current content: $($record.content)"
                    
                    if ($DryRun) {
                        Write-ProxyLog "  [DRY RUN] Would enable proxy: $recordInfo" -Level INFO
                        $script:Statistics.RecordsModified++
                    }
                    else {
                        try {
                            $comment = "Enabled Proxy on $(Get-Date -Format 'yyyy-MM-dd')"
                            
                            Update-CloudflareDnsRecord `
                                -ZoneId $zone.id `
                                -RecordId $record.id `
                                -Proxied $true `
                                -Comment $comment
                            
                            Write-ProxyLog "  [SUCCESS] Enabled proxy: $recordInfo" -Level SUCCESS
                            $script:Statistics.RecordsModified++
                        }
                        catch {
                            Write-ProxyLog "  [ERROR] Failed to update $recordInfo : $_" -Level ERROR
                            $script:Statistics.Errors++
                        }
                    }
                }
            }
            catch {
                Write-ProxyLog "  [ERROR] Failed to process zone $($zone.name): $_" -Level ERROR
                $script:Statistics.Errors++
                continue
            }
        }
    }
    catch {
        Write-ProxyLog "Critical error during enable operation: $_" -Level ERROR
        throw
    }
}

<#
.SYNOPSIS
    Displays summary statistics at the end of execution.
#>
function Show-SummaryReport {
    $endTime = Get-Date
    $elapsed = $endTime - $script:Statistics.StartTime
    
    $summary = @"

================================================================================
SUMMARY REPORT
================================================================================
Operation:          $(if ($Enable) { 'ENABLE PROXIES' } else { 'DISABLE PROXIES' })
Dry Run:            $(if ($DryRun) { 'YES' } else { 'NO' })
Started:            $($script:Statistics.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))
Completed:          $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))
Time Elapsed:       $($elapsed.ToString('hh\:mm\:ss'))

Zones Processed:    $($script:Statistics.ZonesProcessed)
Records Modified:   $($script:Statistics.RecordsModified)
Records Skipped:    $($script:Statistics.RecordsSkipped)
Errors:             $($script:Statistics.Errors)

$(if ($DryRun) { 'NOTE: No actual changes were made (Dry Run mode)' })
Log File:           $script:LogFile
================================================================================

"@

    Write-Host $summary -ForegroundColor Cyan
    
    # Also write to log
    $summary | Out-File -FilePath $script:LogFile -Append -Encoding UTF8
    
    # Return exit code based on errors
    if ($script:Statistics.Errors -gt 0) {
        Write-ProxyLog "Script completed with errors" -Level WARNING
        return 1
    }
    else {
        Write-ProxyLog "Script completed successfully" -Level SUCCESS
        return 0
    }
}

#endregion

#region Main Execution

# Validate parameters
if (-not $Enable -and -not $Disable) {
    Write-Error "You must specify either -Enable or -Disable parameter"
    exit 1
}

# Initialize logging
if (-not (Initialize-Logging -Path $LogPath)) {
    Write-Error "Failed to initialize logging. Exiting."
    exit 1
}

Write-ProxyLog "Cloudflare Proxy Management Script v1.0.0" -Level INFO
Write-ProxyLog "PowerShell Version: $($PSVersionTable.PSVersion)" -Level INFO

# Validate API token
Write-Verbose "Checking for CLOUDFLARE_API_TOKEN environment variable"
$script:ApiToken = $env:CLOUDFLARE_API_TOKEN

if ([string]::IsNullOrWhiteSpace($script:ApiToken)) {
    Write-ProxyLog "CLOUDFLARE_API_TOKEN environment variable is not set" -Level ERROR
    Write-ProxyLog "Please set the environment variable with your Cloudflare API token" -Level ERROR
    Write-ProxyLog "Example (PowerShell): `$env:CLOUDFLARE_API_TOKEN = 'your_token_here'" -Level ERROR
    exit 1
}

Write-Verbose "API token found (length: $($script:ApiToken.Length) characters)"

# Test API connectivity
Write-ProxyLog "Testing Cloudflare API connectivity..." -Level INFO
if (-not (Test-CloudflareApiToken)) {
    Write-ProxyLog "Failed to connect to Cloudflare API. Please check your API token." -Level ERROR
    exit 1
}
Write-ProxyLog "API connectivity test successful" -Level SUCCESS

# Execute main operation
try {
    if ($Disable) {
        Disable-CloudflareProxies
    }
    elseif ($Enable) {
        Enable-CloudflareProxies
    }
    
    # Show summary and exit with appropriate code
    $exitCode = Show-SummaryReport
    exit $exitCode
}
catch {
    Write-ProxyLog "Fatal error: $_" -Level ERROR
    Write-ProxyLog "Stack Trace: $($_.ScriptStackTrace)" -Level ERROR
    exit 1
}

#endregion
