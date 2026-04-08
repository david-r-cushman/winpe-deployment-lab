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
        flushed into the configured Workspace.log file, and all subsequent messages are
        appended directly to the log file.

    * Initialize-WorkspaceLogging
        Creates the Logs folder under the workspace root (if not present),
        sets the log file path, and flushes any buffered messages into
        Workspace.log.

    This hybrid approach ensures immediate console feedback while also
    maintaining lifecycle-safe, recruiter-friendly log files inside the
    configured runtime log directory. Early initialization events are never lost, and every step
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
if (-not (Get-Variable -Scope Global -Name WorkspaceLogPath -ErrorAction SilentlyContinue)) {
    $Global:WorkspaceLogPath = $null
}

function Write-FileUtf8NoBom {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string[]]$Lines,

        [Parameter()]
        [switch]$Append
    )

    $encoding = [System.Text.UTF8Encoding]::new($false)
    $mode = if ($Append) { [System.IO.FileMode]::Append } else { [System.IO.FileMode]::Create }
    $stream = [System.IO.FileStream]::new($Path, $mode, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
    try {
        $writer = [System.IO.StreamWriter]::new($stream, $encoding)
        try {
            foreach ($line in $Lines) {
                $writer.WriteLine($line)
            }
        }
        finally {
            $writer.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Write-WorkspaceLog {
<#
.SYNOPSIS
    Logs messages to both console and workspace log file.

.DESCRIPTION
    Displays a timestamped message on the console and also writes it to
    Workspace.log once logging has been initialized. Before initialization,
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
    Write-WorkspaceLog "Created runtime folder: E:\Git\winpe-deployment-lab\Build\ISO" -Level SUCCESS

    Logs a success message to the console and appends it to Workspace.log.
#>

    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $logEntry  = "[$timestamp] [$Level] $Message"

    # Always write to console
    switch ($Level) {
        'SUCCESS' { Write-Host $logEntry -ForegroundColor Green }
        'INFO'    { Write-Host $logEntry -ForegroundColor Cyan }
        'WARNING' { Write-Warning $logEntry }
        'ERROR'   { Write-Error -Message $logEntry -ErrorAction Continue }
    }

    # If workspace log path is not yet set, buffer the message
    if (-not $Global:WorkspaceLogPath) {
        $Global:WorkspaceLogBuffer += $logEntry
    }
    else {
        # Flush buffer if needed
        if ($Global:WorkspaceLogBuffer.Count -gt 0) {
            Write-FileUtf8NoBom -Path $Global:WorkspaceLogPath -Lines $Global:WorkspaceLogBuffer -Append
            $Global:WorkspaceLogBuffer = @()
        }

        # Append new entry
        Write-FileUtf8NoBom -Path $Global:WorkspaceLogPath -Lines @($logEntry) -Append
    }
}

function Initialize-WorkspaceLogging {
<#
.SYNOPSIS
    Initializes workspace logging and flushes buffered messages.

.DESCRIPTION
    Creates a Logs folder under the workspace root (if not present),
    sets the log file path, and flushes any buffered messages into
    Workspace.log. After initialization, all new log entries are
    appended directly to the log file. This hybrid approach ensures
    recruiter-friendly visibility of all events and lifecycle safety
    by preserving early initialization messages.

.PARAMETER WorkspaceRoot
    The root path used when no explicit log directory is supplied.

.PARAMETER LogRoot
    Optional explicit log directory. When provided, Workspace.log is created
    there instead of under WorkspaceRoot\Logs.

.EXAMPLE
    Initialize-WorkspaceLogging -WorkspaceRoot "E:\Git\winpe-deployment-lab" -LogRoot "E:\Git\winpe-deployment-lab\Build\Logs"

    Creates Workspace.log in the configured runtime log folder and flushes
    any buffered messages into the log file.
#>

    param(
        [string]$WorkspaceRoot,
        [string]$LogRoot
    )

    if ([string]::IsNullOrWhiteSpace($WorkspaceRoot) -and [string]::IsNullOrWhiteSpace($LogRoot)) {
        throw 'Initialize-WorkspaceLogging requires either WorkspaceRoot or LogRoot.'
    }

    try {
        $logsFolder = if (-not [string]::IsNullOrWhiteSpace($LogRoot)) {
            $LogRoot
        }
        else {
            Join-Path -Path $WorkspaceRoot -ChildPath 'Logs'
        }

        if (-not (Test-Path -LiteralPath $logsFolder)) {
            New-Item -Path $logsFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        $Global:WorkspaceLogPath = Join-Path -Path $logsFolder -ChildPath 'Workspace.log'

        # Flush any buffered messages
        if ($Global:WorkspaceLogBuffer.Count -gt 0) {
            Write-FileUtf8NoBom -Path $Global:WorkspaceLogPath -Lines $Global:WorkspaceLogBuffer -Append
            $Global:WorkspaceLogBuffer = @()
        }
    }
    catch {
        throw "Failed to initialize workspace logging. WorkspaceRoot='$WorkspaceRoot'; LogRoot='$LogRoot'. $($_.Exception.Message)"
    }
}
