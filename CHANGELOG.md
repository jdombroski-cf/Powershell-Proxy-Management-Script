# Changelog

All notable changes to the Cloudflare Proxy Management Script will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-30

### Added - Initial Release

#### Core Features
- **Bulk proxy management** across all zones in Cloudflare account
- **Enable/Disable modes** with mutually exclusive `-Enable` and `-Disable` parameters
- **Smart tracking** using DNS record comments to track modified records
- **Dry run mode** with `-DryRun` parameter for safe preview of changes
- **Verbose mode** with `-Verbose` for detailed debugging output

#### API Integration
- Full Cloudflare API v4 integration
- Automatic pagination handling for zones and DNS records
- **Retry logic** with exponential backoff (3 retries: 1s, 2s, 4s delays)
- **Rate limit handling** for HTTP 429 responses
- Support for A, AAAA, and CNAME record types (all proxiable types)

#### Logging & Monitoring
- **Comprehensive logging** system with automatic directory creation
- **Log rotation** with configurable retention (default: 30 days)
- Color-coded console output (Cyan, Green, Yellow, Red)
- **Detailed summary reports** showing:
  - Zones processed
  - Records modified
  - Records skipped
  - Errors encountered
  - Time elapsed

#### Safety Features
- Environment variable authentication (`CLOUDFLARE_API_TOKEN`)
- API connectivity validation before operations
- Per-record error handling (continues on failure)
- Comment-based change tracking prevents unintended modifications
- Complete audit trail in log files

#### Documentation
- **README.md** with comprehensive documentation and legal disclaimer
- **QUICKSTART.md** for 5-minute setup guide
- **EXAMPLES.md** with real-world usage scenarios
- **CHANGELOG.md** for version tracking
- Inline code documentation with comment-based help
- Full parameter documentation for `Get-Help` support

#### Compatibility
- PowerShell 5.1+ (Windows PowerShell)
- PowerShell Core 7+ (Cross-platform)
- Windows, Linux, and macOS support

### Technical Details

#### Functions Implemented
1. `Initialize-Logging` - Log system initialization
2. `Write-ProxyLog` - Unified logging to file and console
3. `Clear-OldLogs` - Automatic log cleanup
4. `Invoke-CloudflareApiWithRetry` - API wrapper with retry logic
5. `Get-CloudflareZones` - Fetch all zones with pagination
6. `Get-CloudflareDnsRecords` - Fetch DNS records with filtering
7. `Update-CloudflareDnsRecord` - Update proxy status and comments
8. `Test-CloudflareApiToken` - Validate API connectivity
9. `Disable-CloudflareProxies` - Main disable operation
10. `Enable-CloudflareProxies` - Main enable operation
11. `Show-SummaryReport` - Generate and display statistics

#### API Endpoints Used
- `GET /zones` - List zones with pagination
- `GET /zones/{zone_id}/dns_records` - List DNS records with filtering
- `PATCH /zones/{zone_id}/dns_records/{record_id}` - Update records

#### Comment Format
- Disable: `"Disabled Proxy on YYYY-MM-DD"`
- Enable: `"Enabled Proxy on YYYY-MM-DD"`
- Uses ISO 8601 date format (YYYY-MM-DD)

### Security
- No hardcoded credentials
- Environment variable-based authentication
- API token validation before operations
- Minimal required permissions (Zone:Read, DNS:Edit)

### Known Limitations
- Processes all zones in account (no zone filtering)
- Sequential processing (no parallel execution in PS 5.1)
- Cloudflare API rate limits apply
- DNS propagation delays may occur

### Legal
- Comprehensive legal disclaimer for testing purposes only
- Clear statement that Cloudflare, Inc. is not liable
- User assumes all responsibility for script usage
- Recommended testing procedures documented

---

## [Future Enhancements] - Planned

### Under Consideration
- Zone filtering by name or ID
- Parallel zone processing for PowerShell 7+
- CSV export of changes
- Backup/restore functionality
- Email notifications
- Webhook support
- Record type filtering options
- Custom comment prefix/format
- Integration with monitoring tools
- Interactive mode with confirmations
- Rollback to previous state
- Scheduled task helper scripts

---

## Version History

- **1.0.0** (2026-01-30) - Initial release

---

## How to Report Issues

If you encounter issues:

1. Review the [README.md](README.md) troubleshooting section
2. Run with `-Verbose` to capture detailed information
3. Check log files in `.\Logs\` directory
4. Verify API token permissions
5. Test with `-DryRun` to isolate issues
6. Document exact error messages and steps to reproduce

---

## How to Suggest Enhancements

To suggest new features:

1. Ensure feature doesn't already exist (check documentation)
2. Consider if it aligns with script's purpose
3. Document the use case clearly
4. Consider security implications
5. Provide example of desired behavior

---

**Maintained by**: Cloudflare Community  
**License**: Provided as-is for testing purposes only  
**Requires**: PowerShell 5.1+, Cloudflare API Token

