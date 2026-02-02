# Cloudflare Proxy Management - Usage Examples

Quick reference guide for common usage scenarios.

## 🚀 Quick Start

### First Time Setup

```powershell
# 1. Set your API token (replace with your actual token)
$env:CLOUDFLARE_API_TOKEN = "your_cloudflare_api_token_here"

# 2. Test with dry run first (ALWAYS DO THIS FIRST!)
.\Manage-CloudflareProxies.ps1 -Disable -DryRun -Verbose

# 3. Review the output, then run for real
.\Manage-CloudflareProxies.ps1 -Disable
```

---

## 📖 Common Scenarios

### Scenario 1: Maintenance Window (Disable Proxy)

**Use Case**: You need to bypass Cloudflare proxy temporarily for maintenance or troubleshooting.

```powershell
# Preview what will be changed
.\Manage-CloudflareProxies.ps1 -Disable -DryRun

# Disable all proxies
.\Manage-CloudflareProxies.ps1 -Disable

# Output shows:
# - Number of zones processed
# - Which records were modified
# - Log file location
```

**Result**: All proxied A, AAAA, and CNAME records across all zones will be unproxied and tagged with "Disabled Proxy on YYYY-MM-DD" comment.

---

### Scenario 2: Restore After Maintenance (Enable Proxy)

**Use Case**: Maintenance is complete, restore proxy settings.

```powershell
# Preview what will be re-enabled
.\Manage-CloudflareProxies.ps1 -Enable -DryRun

# Re-enable proxies that were previously disabled
.\Manage-CloudflareProxies.ps1 -Enable

# Output shows:
# - Only records with "Disabled Proxy on" comment are affected
# - New comment: "Enabled Proxy on YYYY-MM-DD"
```

**Result**: Only records previously disabled by this script are re-proxied.

---

### Scenario 3: Testing/Validation

**Use Case**: Understand what the script will do before executing.

```powershell
# Comprehensive dry run with all details
.\Manage-CloudflareProxies.ps1 -Disable -DryRun -Verbose

# Shows:
# - API connectivity test
# - Every zone being checked
# - Every record evaluated
# - What would be changed (but doesn't change anything)
```

**Result**: Complete preview of operations without making any actual changes.

---

### Scenario 4: Debugging Issues

**Use Case**: Something didn't work as expected, need detailed information.

```powershell
# Run with verbose output for maximum detail
.\Manage-CloudflareProxies.ps1 -Enable -Verbose

# Check the log file
Get-Content .\Logs\CloudflareProxy_*.log -Tail 50

# Or find the most recent log
Get-ChildItem .\Logs\CloudflareProxy_*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content
```

**Result**: Detailed output showing every API call, decision, and error for troubleshooting.

---

### Scenario 5: Custom Log Management

**Use Case**: You want logs in a specific location or retention period.

```powershell
# Custom log location
.\Manage-CloudflareProxies.ps1 -Disable -LogPath "C:\CloudflareLogs\proxy_$(Get-Date -Format 'yyyyMMdd').log"

# Keep logs for 90 days instead of 30
.\Manage-CloudflareProxies.ps1 -Enable -KeepLogsForDays 90

# Disable automatic log cleanup
.\Manage-CloudflareProxies.ps1 -Disable -KeepLogsForDays 0
```

**Result**: Logs stored in your preferred location with custom retention.

---

### Scenario 6: Scheduled Automation

**Use Case**: Run the script automatically on a schedule.

#### Windows Task Scheduler

Create a PowerShell script wrapper (`RunProxyDisable.ps1`):

```powershell
# Set the API token (store securely!)
$env:CLOUDFLARE_API_TOKEN = "your_token_here"

# Run the script
& "C:\Scripts\Manage-CloudflareProxies.ps1" -Disable -LogPath "C:\Logs\Cloudflare\scheduled_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Optionally send notification
if ($LASTEXITCODE -eq 0) {
    Write-Host "Proxy disable completed successfully"
    # Add email notification here if desired
} else {
    Write-Host "Proxy disable failed - check logs"
    # Add alert notification here
}
```

Create scheduled task:
```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Scripts\RunProxyDisable.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 2:00AM
$principal = New-ScheduledTaskPrincipal -UserId "DOMAIN\User" -LogonType Password
Register-ScheduledTask -TaskName "CloudflareProxyDisable" -Action $action -Trigger $trigger -Principal $principal
```

#### Linux/macOS Cron

Add to crontab:
```bash
# Disable proxies every Monday at 2 AM
0 2 * * 1 export CLOUDFLARE_API_TOKEN="your_token" && /usr/local/bin/pwsh /path/to/Manage-CloudflareProxies.ps1 -Disable >> /var/log/cloudflare-proxy.log 2>&1

# Enable proxies every Monday at 6 AM
0 6 * * 1 export CLOUDFLARE_API_TOKEN="your_token" && /usr/local/bin/pwsh /path/to/Manage-CloudflareProxies.ps1 -Enable >> /var/log/cloudflare-proxy.log 2>&1
```

---

### Scenario 7: Emergency Rollback

**Use Case**: Something went wrong, need to quickly revert changes.

```powershell
# If you disabled and need to re-enable immediately
.\Manage-CloudflareProxies.ps1 -Enable -Verbose

# If you enabled and need to disable again
.\Manage-CloudflareProxies.ps1 -Disable -Verbose

# Monitor progress in real-time
Get-Content .\Logs\CloudflareProxy_*.log -Wait
```

**Result**: Quick reversal of proxy changes with full visibility.

---

### Scenario 8: Monitoring and Reporting

**Use Case**: Track what changed and create reports.

```powershell
# Run the operation
.\Manage-CloudflareProxies.ps1 -Disable

# Parse the log file for reporting
$logFile = Get-ChildItem .\Logs\CloudflareProxy_*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$content = Get-Content $logFile.FullName

# Extract statistics
$content | Select-String "Zones Processed|Records Modified|Errors"

# Find all modified records
$content | Select-String "SUCCESS.*Disabled proxy"

# Check for any errors
$content | Select-String "ERROR"

# Create a simple report
@{
    Date = Get-Date
    Operation = "Disable"
    LogFile = $logFile.FullName
    ZonesProcessed = ($content | Select-String "Zones Processed:" | ForEach-Object { $_ -replace '.*:\s+(\d+).*','$1' })
    RecordsModified = ($content | Select-String "Records Modified:" | ForEach-Object { $_ -replace '.*:\s+(\d+).*','$1' })
    Errors = ($content | Select-String "Errors:" | ForEach-Object { $_ -replace '.*:\s+(\d+).*','$1' })
} | ConvertTo-Json
```

---

## 🔧 Advanced Techniques

### Running Against Specific Zones Only

**Approach**: Create a separate API token with access to only specific zones.

1. In Cloudflare Dashboard, create a new API token
2. Under Zone Resources, select "Include → Specific zone" and choose your zones
3. Use this token instead of your main token:

```powershell
$env:CLOUDFLARE_API_TOKEN = "zone_specific_token_here"
.\Manage-CloudflareProxies.ps1 -Disable
```

### Exporting DNS Records Before Changes

**Best Practice**: Always backup DNS records before bulk operations.

```powershell
# Using Cloudflare API to export records
function Export-CloudflareDnsRecords {
    param([string]$ApiToken, [string]$OutputPath = ".\dns_backup_$(Get-Date -Format 'yyyyMMdd').json")
    
    $headers = @{ 'Authorization' = "Bearer $ApiToken" }
    $zones = (Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones" -Headers $headers).result
    
    $backup = @{}
    foreach ($zone in $zones) {
        $records = (Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$($zone.id)/dns_records?per_page=100" -Headers $headers).result
        $backup[$zone.name] = $records
    }
    
    $backup | ConvertTo-Json -Depth 10 | Out-File $OutputPath
    Write-Host "Backup saved to: $OutputPath"
}

# Export before running the script
Export-CloudflareDnsRecords -ApiToken $env:CLOUDFLARE_API_TOKEN

# Now run the proxy script
.\Manage-CloudflareProxies.ps1 -Disable
```

### Creating Alerts for Operations

**Use Case**: Get notified when the script runs or encounters errors.

```powershell
# Wrapper script with email notification (example)
param([switch]$Enable, [switch]$Disable)

# Run the main script and capture output
$result = & .\Manage-CloudflareProxies.ps1 @PSBoundParameters -Verbose 2>&1

# Check exit code
if ($LASTEXITCODE -eq 0) {
    $subject = "Cloudflare Proxy Operation - Success"
    $body = "The proxy operation completed successfully.`n`n$result"
} else {
    $subject = "Cloudflare Proxy Operation - FAILED"
    $body = "The proxy operation failed. Please check logs.`n`n$result"
}

# Send email (configure with your SMTP settings)
# Send-MailMessage -To "admin@example.com" -From "cloudflare@example.com" -Subject $subject -Body $body -SmtpServer "smtp.example.com"

Write-Output $result
exit $LASTEXITCODE
```

---

## 🧪 Testing Workflow

### Recommended Testing Sequence

```powershell
# 1. Verify API token is set
if (-not $env:CLOUDFLARE_API_TOKEN) {
    Write-Error "CLOUDFLARE_API_TOKEN not set!"
    exit 1
}

# 2. Test connectivity with dry run
.\Manage-CloudflareProxies.ps1 -Disable -DryRun -Verbose

# 3. Review output carefully

# 4. Run on a test zone first (use zone-specific token)
# Create a token for ONE test zone only, then:
.\Manage-CloudflareProxies.ps1 -Disable

# 5. Verify in Cloudflare dashboard

# 6. Test the enable operation
.\Manage-CloudflareProxies.ps1 -Enable -DryRun -Verbose

# 7. Actually enable
.\Manage-CloudflareProxies.ps1 -Enable

# 8. Verify everything is back to normal

# 9. Now run on all zones with full token
# (after restoring full-access token)
.\Manage-CloudflareProxies.ps1 -Disable -Verbose
```

---

## 📊 Output Interpretation

### Understanding Console Output

```
[INFO] Processing zone: example.com
  Found 5 proxied record(s)
  [SUCCESS] Disabled proxy: www.example.com (A)
  [SUCCESS] Disabled proxy: api.example.com (A)
  [SUCCESS] Disabled proxy: cdn.example.com (CNAME)
```

- **[INFO]**: General information messages
- **[SUCCESS]**: Record successfully modified
- **[WARNING]**: Skipped items or non-critical issues
- **[ERROR]**: Failed operations (but script continues)

### Reading Summary Reports

```
Zones Processed:    15    ← Total zones in account
Records Modified:   127   ← Records actually changed
Records Skipped:    3     ← Records that didn't match criteria
Errors:             0     ← Failed operations
```

**Zones Processed**: Total number of zones checked  
**Records Modified**: Number of records actually updated  
**Records Skipped**: Zones/records that didn't need changes  
**Errors**: Operations that failed (check logs for details)

---

## 💡 Pro Tips

1. **Always use -DryRun first** - Preview is free, mistakes are not
2. **Keep logs** - They're your audit trail and troubleshooting tool
3. **Test with one zone** - Use zone-specific tokens for testing
4. **Monitor the first run** - Use -Verbose to understand behavior
5. **Document your runs** - Note dates and reasons in your own log
6. **Backup DNS records** - Export before bulk changes
7. **Check Cloudflare status** - Before blaming the script, check [status.cloudflare.com](https://www.cloudflarestatus.com/)
8. **Use meaningful log paths** - Include operation type in filename
9. **Set calendar reminders** - To re-enable proxies after maintenance
10. **Read the README** - Seriously, it has everything

---

## 🎯 Real-World Workflow Example

### Monthly Maintenance Routine

```powershell
# ===== FRIDAY 6 PM - BEFORE MAINTENANCE WINDOW =====

# 1. Export current DNS state for backup
.\Export-DnsBackup.ps1 -OutputPath ".\Backups\dns_backup_$(Get-Date -Format 'yyyyMMdd').json"

# 2. Preview disable operation
.\Manage-CloudflareProxies.ps1 -Disable -DryRun -Verbose | Tee-Object -FilePath ".\preview_disable.txt"

# 3. Review preview file
Get-Content .\preview_disable.txt | Select-String "Would disable"

# 4. If everything looks good, disable proxies
.\Manage-CloudflareProxies.ps1 -Disable -LogPath ".\Logs\maintenance_disable_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# ===== PERFORM YOUR MAINTENANCE WORK =====

# ===== SUNDAY 6 PM - AFTER MAINTENANCE COMPLETE =====

# 5. Preview enable operation
.\Manage-CloudflareProxies.ps1 -Enable -DryRun -Verbose | Tee-Object -FilePath ".\preview_enable.txt"

# 6. Review what will be re-enabled
Get-Content .\preview_enable.txt | Select-String "Would enable"

# 7. Re-enable proxies
.\Manage-CloudflareProxies.ps1 -Enable -LogPath ".\Logs\maintenance_enable_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# 8. Verify everything is back to normal
.\Test-CloudflareHealth.ps1  # Your own health check script

# 9. Archive logs and backup
Move-Item .\Logs\maintenance_*.log -Destination ".\Archive\$(Get-Date -Format 'yyyyMM')\" -Force
```

---

## 📞 Need Help?

1. Check the main [README.md](README.md) for detailed documentation
2. Review the Troubleshooting section
3. Run with `-Verbose` to see detailed information
4. Check log files for specific error messages
5. Verify your API token has correct permissions

---

**Remember**: This script modifies DNS settings for your entire Cloudflare account. Always test with `-DryRun` first!
