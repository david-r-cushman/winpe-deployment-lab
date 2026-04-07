<#
.SYNOPSIS
    Provides hybrid logging for workspace automation scripts.

.DESCRIPTION
    This script defines two functions — Write-WorkspaceLog and Initialize-WorkspaceLogging —
    that together implement lifecycle-safe, recruiter-friendly logging.

    * Write-WorkspaceLog
        Logs messages to both the console and a workspace log file.
        Before the workspace root exists, messages are buffered in memory
        and displayed on the console. Once the workspace root is created
        and Initialize-WorkspaceLogging is called, buffered messages are
        flushed into Logs\Workspace.log, and all subsequent messages are
        appended directly to the log file.

    * Initialize-WorkspaceLogging
        Creates the Logs folder under the workspace root (if not present),
        sets the log file path, and flushes any buffered messages into
        Logs\Workspace.log.

    This hybrid approach ensures immediate console feedback while also
    maintaining lifecycle-safe, recruiter-friendly log files inside the
    workspace. Early initialization events are never lost, and every step
    is documented in both console and permanent log output.

.NOTES
    Author: David R. Cushman
    Script: Write-WorkspaceLog.ps1
    Design rationale:
      * Hybrid logging guarantees recruiter-friendly visibility of all events.
      * Buffered messages prevent loss of early initialization steps.
      * Log file is written in UTF-8 without BOM for cross-platform safety.
      * Functions are designed for reuse across all workspace automation scripts.
#>

# Global buffer for log messages
if (-not $Global:WorkspaceLogBuffer) { $Global:WorkspaceLogBuffer = @() }
$Global:WorkspaceLogPath = $null

function Write-WorkspaceLog {
<#
.SYNOPSIS
    Logs messages to both console and workspace log file.

.DESCRIPTION
    Displays a timestamped message on the console and also writes it to
    Logs\Workspace.log once logging has been initialized. Before initialization,
    messages are buffered in memory and flushed later. This ensures lifecycle
    safety by preventing loss of early events and recruiter-friendly clarity
    by documenting every step.

.PARAMETER Message
    The text message to log.

.PARAMETER Level
    The severity level of the log entry.
    Valid values: INFO, SUCCESS, WARNING, ERROR.
    Default: INFO.

.EXAMPLE
    Write-WorkspaceLog "Created folder: E:\Temp\Test1\Scripts" -Level SUCCESS

    Logs a success message to the console and appends it to Logs\Workspace.log.
#>

    param(
        [string]$Message,
        [ValidateSet("INFO","SUCCESS","WARNING","ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry  = "[$timestamp] [$Level] $Message"

    # Always write to console
    switch ($Level) {
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        "INFO"    { Write-Host $logEntry -ForegroundColor Cyan }
        "WARNING" { Write-Warning $logEntry }
        "ERROR"   { Write-Error $logEntry }
    }

    # If workspace log path is not yet set, buffer the message
    if (-not $Global:WorkspaceLogPath) {
        $Global:WorkspaceLogBuffer += $logEntry
    }
    else {
        # Flush buffer if needed
        if ($Global:WorkspaceLogBuffer.Count -gt 0) {
            $Global:WorkspaceLogBuffer | Out-File -FilePath $Global:WorkspaceLogPath -Append -Encoding UTF8NoBOM
            $Global:WorkspaceLogBuffer = @()
        }
        # Append new entry
        Add-Content -Path $Global:WorkspaceLogPath -Value $logEntry
    }
}

function Initialize-WorkspaceLogging {
<#
.SYNOPSIS
    Initializes workspace logging and flushes buffered messages.

.DESCRIPTION
    Creates a Logs folder under the workspace root (if not present),
    sets the log file path, and flushes any buffered messages into
    Logs\Workspace.log. After initialization, all new log entries are
    appended directly to the log file. This hybrid approach ensures
    recruiter-friendly visibility of all events and lifecycle safety
    by preserving early initialization messages.

.PARAMETER WorkspaceRoot
    The root path of the workspace where the Logs folder and log file
    will be created.

.EXAMPLE
    Initialize-WorkspaceLogging -WorkspaceRoot "E:\Temp\Test1"

    Creates Logs\Workspace.log under the workspace root and flushes
    any buffered messages into the log file.
#>

    param(
        [string]$WorkspaceRoot,
        [string]$LogRoot
    )

    $logsFolder = if ($LogRoot) {
        $LogRoot
    }
    else {
        Join-Path $WorkspaceRoot "Logs"
    }
    if (-not (Test-Path $logsFolder)) {
        New-Item -Path $logsFolder -ItemType Directory | Out-Null
    }

    $Global:WorkspaceLogPath = Join-Path $logsFolder "Workspace.log"

    # Flush any buffered messages
    if ($Global:WorkspaceLogBuffer.Count -gt 0) {
        $Global:WorkspaceLogBuffer | Out-File -FilePath $Global:WorkspaceLogPath -Encoding UTF8NoBOM
        $Global:WorkspaceLogBuffer = @()
    }
}
