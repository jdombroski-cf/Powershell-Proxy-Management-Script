# Cloudflare Proxy Management Script

A PowerShell automation script for managing Cloudflare DNS record proxy settings (orange cloud) across all zones in your account.

## ⚠️ LEGAL DISCLAIMER - IMPORTANT

**FOR TESTING AND EDUCATIONAL PURPOSES ONLY**

This script is provided as-is for testing, educational, and evaluation purposes only. By using this script, you acknowledge and agree that:

- **This is an unofficial, community-created tool** and is NOT officially supported or endorsed by Cloudflare, Inc.
- **Cloudflare, Inc. cannot be held liable or accountable** for any issues, damages, service disruptions, outages, data loss, or problems that may arise from the use of this script.
- **You use this script entirely at your own risk** and are solely responsible for any and all consequences resulting from its use.
- **You are responsible for testing** this script in a non-production or staging environment before using it in any production environment.
- **You should have backups and rollback plans** in place before making bulk DNS changes to your infrastructure.
- **No warranty, express or implied, is provided.** This script may contain bugs, errors, or unintended behaviors that could affect your DNS configuration.
- **You are responsible for ensuring** you have proper authorization, permissions, and rights to modify DNS records in your Cloudflare account.
- **DNS changes can have significant impacts** on your website/service availability. Improper use may result in downtime or service disruptions.

**By proceeding to download, install, configure, or execute this script, you accept full responsibility for its use and agree to hold harmless Cloudflare, Inc. and the script author(s) from any and all claims, damages, liabilities, costs, or expenses arising from your use of this script.**

If you do not agree with these terms, **do not use this script.**

---

## 📋 Overview

The **Manage-CloudflareProxies.ps1** script automates the process of enabling and disabling Cloudflare's proxy feature (the "orange cloud") for DNS records across your entire Cloudflare account. It intelligently tracks which records it has modified using DNS record comments, allowing you to easily toggle proxy settings on and off.

### Key Features

- ✅ **Bulk Operations**: Process all zones in your Cloudflare account automatically
- ✅ **Smart Tracking**: Uses DNS record comments to track which records were modified
- ✅ **Dry Run Mode**: Preview changes before making them with `-DryRun`
- ✅ **Comprehensive Logging**: Detailed logs with automatic rotation (30-day retention)
- ✅ **Error Recovery**: Automatic retry with exponential backoff for API failures
- ✅ **Progress Reporting**: Real-time console output and detailed summary statistics
- ✅ **Verbose Mode**: Extensive debugging output with `-Verbose` parameter
- ✅ **Safe by Design**: Only affects A, AAAA, and CNAME records (proxiable types)

### Supported Record Types

Only DNS record types that support Cloudflare's proxy feature:
- **A** records (IPv4 addresses)
- **AAAA** records (IPv6 addresses)
- **CNAME** records (aliases)

---

## 🔧 Prerequisites

### System Requirements
- **PowerShell 5.1** or higher (Windows PowerShell)
- **PowerShell Core 7+** (Cross-platform)
- Internet connectivity to `api.cloudflare.com`

### Cloudflare Requirements
- A Cloudflare account with zones/domains
- A Cloudflare API Token with the following permissions:
  - **Zone:Read** - To list zones in your account
  - **DNS:Edit** - To modify DNS record proxy settings

---

## 🚀 Getting Started

### Step 1: Create a Cloudflare API Token

1. Log in to the [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Go to **My Profile** → **API Tokens**
3. Click **Create Token**
4. Use the **Edit zone DNS** template or create a custom token with:
   - **Permissions**:
     - Zone → DNS → Edit
     - Zone → Zone → Read
   - **Zone Resources**:
     - Include → All zones (or specific zones if preferred)
5. Click **Continue to summary** → **Create Token**
6. **Copy and save the token** (you won't be able to see it again)

### Step 2: Set Environment Variable

Set the `CLOUDFLARE_API_TOKEN` environment variable with your token:

**Windows PowerShell:**
```powershell
$env:CLOUDFLARE_API_TOKEN = "your_api_token_here"
```

**To make it permanent (Windows):**
```powershell
[System.Environment]::SetEnvironmentVariable('CLOUDFLARE_API_TOKEN', 'your_api_token_here', 'User')
```

**Linux/macOS (PowerShell Core):**
```bash
export CLOUDFLARE_API_TOKEN="your_api_token_here"
```

**To make it permanent (Linux/macOS), add to `~/.bashrc` or `~/.zshrc`:**
```bash
export CLOUDFLARE_API_TOKEN="your_api_token_here"
```

### Step 3: Download the Script

Download `Manage-CloudflareProxies.ps1` to your desired location.

### Step 4: Run the Script

**Test with Dry Run first (RECOMMENDED):**
```powershell
.\Manage-CloudflareProxies.ps1 -Disable -DryRun
```

**Disable all proxies:**
```powershell
.\Manage-CloudflareProxies.ps1 -Disable
```

**Enable previously disabled proxies:**
```powershell
.\Manage-CloudflareProxies.ps1 -Enable
```

---

## 📖 Usage

### Basic Commands

#### Disable Proxies (Turn Off Orange Cloud)
```powershell
.\Manage-CloudflareProxies.ps1 -Disable
```
This will:
- Find all proxied A, AAAA, and CNAME records across all zones
- Disable the proxy (turn off orange cloud)
- Add comment: `"Disabled Proxy on YYYY-MM-DD"`

#### Enable Proxies (Turn On Orange Cloud)
```powershell
.\Manage-CloudflareProxies.ps1 -Enable
```
This will:
- Find all unproxied records with comment matching `"Disabled Proxy on *"`
- Enable the proxy (turn on orange cloud)
- Update comment: `"Enabled Proxy on YYYY-MM-DD"`

### Advanced Usage

#### Dry Run Mode (Preview Changes)
```powershell
.\Manage-CloudflareProxies.ps1 -Disable -DryRun
```
Preview what would be changed without making actual modifications.

#### Verbose Output (Detailed Debugging)
```powershell
.\Manage-CloudflareProxies.ps1 -Enable -Verbose
```
Shows detailed information about API calls, record evaluation, and decisions.

#### Custom Log Location
```powershell
.\Manage-CloudflareProxies.ps1 -Disable -LogPath "C:\Logs\cloudflare\proxy.log"
```
Specify a custom path for the log file.

#### Custom Log Retention
```powershell
.\Manage-CloudflareProxies.ps1 -Enable -KeepLogsForDays 60
```
Keep logs for 60 days instead of default 30 days.

#### Disable Log Cleanup
```powershell
.\Manage-CloudflareProxies.ps1 -Disable -KeepLogsForDays 0
```
Set to 0 to disable automatic log cleanup.

### Combined Examples

**Dry run with verbose output:**
```powershell
.\Manage-CloudflareProxies.ps1 -Disable -DryRun -Verbose
```

**Enable with custom log path:**
```powershell
.\Manage-CloudflareProxies.ps1 -Enable -LogPath "D:\CloudflareLogs\$(Get-Date -Format 'yyyy-MM')\proxy.log"
```

---

## 📊 Understanding the Output

### Console Output

The script provides color-coded console output:
- **Cyan**: Informational messages
- **Green**: Successful operations
- **Yellow**: Warnings and skipped items
- **Red**: Errors

### Summary Report

At the end of execution, you'll see a summary like:

```
================================================================================
SUMMARY REPORT
================================================================================
Operation:          DISABLE PROXIES
Dry Run:            NO
Started:            2026-01-30 14:23:15
Completed:          2026-01-30 14:25:42
Time Elapsed:       00:02:27

Zones Processed:    15
Records Modified:   127
Records Skipped:    3
Errors:             0

Log File:           C:\Scripts\Logs\CloudflareProxy_20260130_142315.log
================================================================================
```

### Log Files

Log files are automatically created in the `.\Logs\` directory (or your custom location) with:
- Timestamp for each operation
- Full details of all API calls
- Record-by-record modification status
- Error messages with stack traces
- Summary statistics

**Log file naming:** `CloudflareProxy_YYYYMMDD_HHMMSS.log`

---

## 🔍 How It Works

### Disable Operation Flow

1. **Authenticate**: Validates your API token with Cloudflare
2. **Fetch Zones**: Retrieves all zones in your account (with pagination)
3. **For Each Zone**:
   - Fetch all A, AAAA, and CNAME records where `proxied = true`
   - For each proxied record:
     - Update record to set `proxied = false`
     - Set comment to `"Disabled Proxy on YYYY-MM-DD"`
     - Log the operation
4. **Report**: Display summary statistics

### Enable Operation Flow

1. **Authenticate**: Validates your API token
2. **Fetch Zones**: Retrieves all zones
3. **For Each Zone**:
   - Fetch all A, AAAA, and CNAME records
   - Filter for records where:
     - `proxied = false` AND
     - Comment matches `"Disabled Proxy on *"` pattern
   - For each matching record:
     - Update record to set `proxied = true`
     - Set comment to `"Enabled Proxy on YYYY-MM-DD"`
     - Log the operation
4. **Report**: Display summary statistics

### Comment Tracking

The script uses DNS record comments to track its operations:

- **Disable**: Adds comment `"Disabled Proxy on 2026-01-30"`
- **Enable**: Changes comment to `"Enabled Proxy on 2026-01-30"`

This allows the script to only affect records it has previously modified, preventing accidental changes to records that were intentionally left unproxied.

---

## 🛡️ Safety Features

### Error Handling
- **Automatic Retry**: Failed API calls are retried up to 3 times with exponential backoff
- **Rate Limiting**: Gracefully handles Cloudflare API rate limits (HTTP 429)
- **Continue on Error**: If one record fails, processing continues with others
- **Detailed Logging**: All errors are logged with full context

### Dry Run Mode
Always test with `-DryRun` first to preview changes:
```powershell
.\Manage-CloudflareProxies.ps1 -Disable -DryRun
```

### Verbose Mode
Use `-Verbose` to see exactly what the script is doing:
```powershell
.\Manage-CloudflareProxies.ps1 -Enable -Verbose
```

### Automatic Log Rotation
- Logs older than 30 days (configurable) are automatically deleted
- Prevents disk space issues from accumulating log files
- Can be disabled by setting `-KeepLogsForDays 0`

---

## 🧪 Testing Checklist

**Before using in production, complete this testing checklist:**

- [ ] Create a test zone with a few DNS records
- [ ] Set `CLOUDFLARE_API_TOKEN` environment variable
- [ ] Run with `-DryRun` to preview changes
- [ ] Review the `-Verbose` output to understand what will happen
- [ ] Verify the script only targets A, AAAA, and CNAME records
- [ ] Test `-Disable` on test zone
- [ ] Verify records are unproxied in Cloudflare dashboard
- [ ] Check that comments were added correctly
- [ ] Test `-Enable` on the same zone
- [ ] Verify records are proxied again
- [ ] Confirm comments were updated
- [ ] Test with zone that has no proxied records
- [ ] Test with zone that has no "Disabled Proxy" comments
- [ ] Review log file for completeness
- [ ] Test error handling with invalid API token
- [ ] Verify log directory is created automatically
- [ ] Test on a small subset of production zones before full deployment

---

## ❓ Troubleshooting

### Error: "CLOUDFLARE_API_TOKEN environment variable is not set"

**Solution**: Set the environment variable as shown in Step 2 of Getting Started.

### Error: "Failed to connect to Cloudflare API"

**Possible causes:**
- Invalid or expired API token
- Insufficient permissions on the token
- Network connectivity issues
- Firewall blocking api.cloudflare.com

**Solution**: 
1. Verify your token in Cloudflare dashboard
2. Ensure token has Zone:Read and DNS:Edit permissions
3. Test connectivity: `Test-NetConnection api.cloudflare.com -Port 443`

### Error: "API call failed after 3 attempts"

**Possible causes:**
- Temporary Cloudflare API issues
- Rate limiting
- Network instability

**Solution**: Wait a few minutes and retry. Check [Cloudflare Status](https://www.cloudflarestatus.com/).

### Warning: "No zones found in account"

**Possible causes:**
- API token doesn't have access to any zones
- Account has no zones

**Solution**: 
1. Verify zones exist in your Cloudflare account
2. Check token permissions include your zones

### No Records Modified

**Possible causes:**
- **Disable mode**: No records are currently proxied
- **Enable mode**: No records have "Disabled Proxy on" comment

**Solution**: This is normal if there are no matching records. Use `-Verbose` to see why records were skipped.

### Permission Denied Errors

**Solution**: Ensure your API token has both **Zone:Read** and **DNS:Edit** permissions for all zones you want to modify.

---

## 📝 FAQ

### Q: Will this affect my MX, TXT, or other record types?
**A:** No. The script only affects A, AAAA, and CNAME records, which are the only types that support Cloudflare's proxy feature.

### Q: What happens if I run -Enable but never ran -Disable?
**A:** Nothing. The script only enables records that have the "Disabled Proxy on" comment, which means they were previously disabled by this script.

### Q: Can I use this on specific zones only?
**A:** Currently, the script processes all zones in your account. You can create a separate API token with access to only specific zones to limit scope.

### Q: Will this disrupt my website during execution?
**A:** There may be brief DNS propagation delays (typically seconds) as records are updated. Use `-DryRun` first and consider running during low-traffic periods.

### Q: How long does it take to process many zones?
**A:** Processing time depends on the number of zones and records. The script uses pagination and processes efficiently. Expect approximately 1-5 seconds per zone.

### Q: Can I run this as a scheduled task?
**A:** Yes! You can use Windows Task Scheduler or cron to automate execution. Ensure the environment variable is set in the scheduled task context.

### Q: What if the script is interrupted mid-execution?
**A:** The script processes records one at a time. If interrupted, already-modified records will have the updated proxy status and comments. Simply re-run the script to continue.

### Q: How do I undo changes made by the script?
**A:** 
- If you ran `-Disable`, run `-Enable` to restore proxy settings
- If you need to manually fix records, use the Cloudflare dashboard or API
- Always test with `-DryRun` first!

---

## 🔐 Security Best Practices

1. **Protect Your API Token**
   - Never commit tokens to version control
   - Use environment variables, not hardcoded values
   - Regularly rotate your API tokens
   - Use minimum required permissions

2. **Test Before Production**
   - Always use `-DryRun` first
   - Test on non-critical zones initially
   - Review logs before enabling in production

3. **Monitor and Audit**
   - Review log files regularly
   - Monitor Cloudflare audit logs
   - Set up alerts for unexpected DNS changes

4. **Backup and Recovery**
   - Export DNS records before bulk changes
   - Document rollback procedures
   - Keep logs for audit trail

---

## 📄 Script Parameters Reference

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-Enable` | Switch | Yes* | - | Enable proxy for previously disabled records |
| `-Disable` | Switch | Yes* | - | Disable proxy for all proxied records |
| `-DryRun` | Switch | No | `$false` | Preview changes without executing |
| `-LogPath` | String | No | `.\Logs\CloudflareProxy_<timestamp>.log` | Path for log file |
| `-KeepLogsForDays` | Integer | No | `30` | Days to keep old logs (0 = no cleanup) |
| `-Verbose` | Switch | No | `$false` | Show detailed debugging output |

\* Either `-Enable` or `-Disable` must be specified (mutually exclusive)

---

## 🐛 Known Limitations

1. **All Zones**: Currently processes all zones in account (no zone filtering)
2. **Sequential Processing**: Zones are processed one at a time (no parallel processing in PS 5.1)
3. **Comment Length**: Cloudflare may have limits on comment field length
4. **Propagation**: DNS changes may take time to propagate globally

---

## 🤝 Contributing

This is a community script. Improvements and contributions are welcome:

1. Test thoroughly before suggesting changes
2. Document any modifications
3. Follow PowerShell best practices
4. Maintain backward compatibility when possible

---

## 📜 License

This script is provided "as-is" without warranty of any kind. See the Legal Disclaimer section above for full terms.

---

## 📞 Support

This is an unofficial, community-created tool. For Cloudflare platform issues, contact [Cloudflare Support](https://support.cloudflare.com/).

For script issues:
1. Review this README thoroughly
2. Check the Troubleshooting section
3. Review log files with `-Verbose` output
4. Test with `-DryRun` to isolate issues

---

## 📚 Additional Resources

- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)
- [Cloudflare DNS Documentation](https://developers.cloudflare.com/dns/)
- [PowerShell Documentation](https://docs.microsoft.com/powershell/)

---

**Version:** 1.0.0  
**Last Updated:** January 2026

**Remember: Always test in a non-production environment first!**
