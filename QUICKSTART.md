# Quick Start Guide - Cloudflare Proxy Management

Get started in 5 minutes! 🚀

## ⚠️ Legal Notice

**This script is for testing purposes only. Cloudflare, Inc. cannot be held liable for any issues arising from its use. See [README.md](README.md) for full legal disclaimer.**

---

## Step 1: Get Your Cloudflare API Token

1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Click **Create Token**
3. Use **Edit zone DNS** template
4. Or create custom token with:
   - Permission: **Zone** → **DNS** → **Edit**
   - Permission: **Zone** → **Zone** → **Read**
   - Zone Resources: **All zones**
5. Click **Continue to summary** → **Create Token**
6. **Copy the token** (you won't see it again!)

---

## Step 2: Set Environment Variable

### Windows (PowerShell)

```powershell
# Temporary (current session only)
$env:CLOUDFLARE_API_TOKEN = "your_token_here"

# Permanent (all future sessions)
[System.Environment]::SetEnvironmentVariable('CLOUDFLARE_API_TOKEN', 'your_token_here', 'User')
```

### Linux/macOS (PowerShell Core)

```bash
# Temporary
export CLOUDFLARE_API_TOKEN="your_token_here"

# Permanent - Add to ~/.bashrc or ~/.zshrc
echo 'export CLOUDFLARE_API_TOKEN="your_token_here"' >> ~/.bashrc
source ~/.bashrc
```

---

## Step 3: Test the Script (DRY RUN)

**ALWAYS test with dry run first!**

```powershell
# Preview what would happen (doesn't make actual changes)
.\Manage-CloudflareProxies.ps1 -Disable -DryRun -Verbose
```

Review the output carefully. It will show:
- ✅ All zones found
- ✅ All records that would be modified
- ✅ No actual changes made

---

## Step 4: Disable Proxies

When ready to actually disable:

```powershell
.\Manage-CloudflareProxies.ps1 -Disable
```

This will:
- Turn OFF proxy (orange cloud) for all A, AAAA, and CNAME records
- Add comment: "Disabled Proxy on YYYY-MM-DD"
- Create a log file in `.\Logs\`

---

## Step 5: Enable Proxies (When Ready)

To restore proxy settings:

```powershell
# Preview first
.\Manage-CloudflareProxies.ps1 -Enable -DryRun

# Then enable
.\Manage-CloudflareProxies.ps1 -Enable
```

This will:
- Turn ON proxy for records previously disabled by this script
- Update comment: "Enabled Proxy on YYYY-MM-DD"
- Log all operations

---

## 🎯 Common Commands

```powershell
# Preview disable operation
.\Manage-CloudflareProxies.ps1 -Disable -DryRun

# Disable all proxies
.\Manage-CloudflareProxies.ps1 -Disable

# Preview enable operation
.\Manage-CloudflareProxies.ps1 -Enable -DryRun

# Enable previously disabled proxies
.\Manage-CloudflareProxies.ps1 -Enable

# Run with detailed output
.\Manage-CloudflareProxies.ps1 -Disable -Verbose

# Custom log location
.\Manage-CloudflareProxies.ps1 -Disable -LogPath "C:\Logs\my-proxy.log"
```

---

## 📊 Understanding Output

### Success Output
```
[INFO] Processing zone: example.com
  Found 5 proxied record(s)
  [SUCCESS] Disabled proxy: www.example.com (A)
  [SUCCESS] Disabled proxy: api.example.com (A)

================================================================================
SUMMARY REPORT
================================================================================
Zones Processed:    3
Records Modified:   15
Records Skipped:    0
Errors:             0
================================================================================
```

### What Each Means
- **Zones Processed**: Number of zones checked in your account
- **Records Modified**: DNS records actually changed
- **Records Skipped**: Zones/records that didn't need changes
- **Errors**: Failed operations (0 is good!)

---

## 🔍 Checking Logs

Logs are automatically created in `.\Logs\` directory:

```powershell
# View the most recent log
Get-ChildItem .\Logs\CloudflareProxy_*.log | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1 | 
    Get-Content

# View last 20 lines of most recent log
Get-ChildItem .\Logs\CloudflareProxy_*.log | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1 | 
    Get-Content -Tail 20
```

---

## ❌ Troubleshooting

### "CLOUDFLARE_API_TOKEN environment variable is not set"

**Fix:**
```powershell
$env:CLOUDFLARE_API_TOKEN = "your_token_here"
```

### "Failed to connect to Cloudflare API"

**Possible causes:**
- Invalid token
- Token lacks permissions
- Network issues

**Fix:**
1. Verify token in Cloudflare dashboard
2. Ensure token has Zone:Read and DNS:Edit permissions
3. Test connectivity: `Test-NetConnection api.cloudflare.com -Port 443`

### "No zones found in account"

**Fix:**
- Verify your Cloudflare account has zones
- Check token has access to your zones
- Try creating a new token with "All zones" access

---

## ✅ Safety Checklist

Before using in production:

- [ ] Set `CLOUDFLARE_API_TOKEN` environment variable
- [ ] Run with `-DryRun` flag first
- [ ] Review the output carefully
- [ ] Test on ONE zone first (use zone-specific token)
- [ ] Verify changes in Cloudflare dashboard
- [ ] Test the enable operation
- [ ] Backup DNS records (optional but recommended)
- [ ] Read the full [README.md](README.md)

---

## 🆘 Need More Help?

- **Full Documentation**: See [README.md](README.md)
- **Usage Examples**: See [EXAMPLES.md](EXAMPLES.md)
- **Troubleshooting**: Check README.md → Troubleshooting section
- **Check Logs**: Look in `.\Logs\` directory
- **Verbose Mode**: Add `-Verbose` to any command for details

---

## 🎓 Learn By Doing

### Complete Example Workflow

```powershell
# 1. Set API token
$env:CLOUDFLARE_API_TOKEN = "your_cloudflare_token_here"

# 2. Test with dry run
.\Manage-CloudflareProxies.ps1 -Disable -DryRun -Verbose

# 3. Review output - does it look correct?
# If yes, continue. If no, check your token/permissions.

# 4. Actually disable proxies
.\Manage-CloudflareProxies.ps1 -Disable

# 5. Check the summary report
# Should show zones processed and records modified

# 6. Verify in Cloudflare dashboard
# Go to DNS settings, check that orange clouds are off

# 7. When ready to restore, test first
.\Manage-CloudflareProxies.ps1 -Enable -DryRun

# 8. Enable proxies
.\Manage-CloudflareProxies.ps1 -Enable

# 9. Verify everything is back to normal
# Check Cloudflare dashboard - orange clouds should be back
```

---

## 💡 Pro Tips

1. **Always use `-DryRun` first** ← Most important!
2. **Start small** - Test with a non-critical zone
3. **Use `-Verbose`** - See exactly what's happening
4. **Check logs** - They contain detailed information
5. **Backup DNS** - Export records before bulk changes
6. **Document** - Note when and why you ran the script
7. **Plan ahead** - Set reminders to re-enable proxies
8. **Monitor** - Watch the first execution carefully

---

## 📝 What's Next?

Now that you've run the script successfully:

1. **Read the full [README.md](README.md)** for comprehensive documentation
2. **Check [EXAMPLES.md](EXAMPLES.md)** for advanced usage scenarios
3. **Review logs** to understand what was changed
4. **Set up scheduled tasks** if you need automation
5. **Create backups** of DNS records before major changes

---

## ⚡ TL;DR - Absolute Minimum

```powershell
# Set token
$env:CLOUDFLARE_API_TOKEN = "your_token"

# Test first (REQUIRED!)
.\Manage-CloudflareProxies.ps1 -Disable -DryRun

# Then run for real
.\Manage-CloudflareProxies.ps1 -Disable

# Later, re-enable
.\Manage-CloudflareProxies.ps1 -Enable
```

**That's it!** You're ready to manage Cloudflare proxies.

---

**Version:** 1.0.0  
**Last Updated:** January 2026

**Remember**: Always test with `-DryRun` first! 🛡️
