<#
.SYNOPSIS
    Flashes the whole screen after an agent finishes responding.

.DESCRIPTION
    Draws a borderless, always-on-top, click-through window across every
    monitor, holds it at full brightness, then fades it out and exits.

    The window is never activated and is transparent to input, so it cannot
    steal focus or swallow a keystroke or click from whatever you are doing.

.PARAMETER HoldMs
    Milliseconds to stay at full brightness before the fade starts.

.PARAMETER FadeMs
    Milliseconds the fade-out takes. Set to 0 for a hard cut.

.PARAMETER Color
    Flash color, as an HTML color name or hex ("White", "#FF0044").

.PARAMETER MaxOpacity
    Peak opacity, 0.0 - 1.0. Lower this if a full white flash is too much.

.PARAMETER PrimaryScreenOnly
    Flash only the primary monitor instead of all of them.

.EXAMPLE
    .\flashbang.ps1
    A default white flash across all monitors.

.EXAMPLE
    .\flashbang.ps1 -Color '#00E5FF' -MaxOpacity 0.55 -HoldMs 60 -FadeMs 300
    A gentler cyan pulse.
#>
[CmdletBinding()]
param(
    [ValidateRange(0, 5000)]  [int]    $HoldMs     = 250,
    [ValidateRange(0, 5000)]  [int]    $FadeMs     = 250,
                              [string] $Color      = 'White',
    [ValidateRange(0.05, 1)]  [double] $MaxOpacity = 0.35,
                              [switch] $PrimaryScreenOnly
)

$ErrorActionPreference = 'Stop'

try {
# PowerShell 6+ runs on Linux and macOS, where none of this applies.
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) { exit 0 }

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# Compiling this shim costs about a second, which would show up as a full second
# of lag before every flash. Emit it to a DLL once and load that from then on.
$nativeSource = @'
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter,
        int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
'@

if (-not ('Flashbang.Native' -as [type])) {
    # Keyed by host runtime: an assembly emitted by Windows PowerShell (.NET
    # Framework) is not guaranteed to load under pwsh (.NET), and vice versa.
    $cacheDir = Join-Path $env:LOCALAPPDATA 'claude-flashbang'
    $runtimeTag = '{0}{1}' -f $PSVersionTable.PSEdition, $PSVersionTable.PSVersion.Major
    $cacheDll = Join-Path $cacheDir "Flashbang.Native.$runtimeTag.dll"
    $loaded = $false

    if (Test-Path -LiteralPath $cacheDll) {
        try { Add-Type -Path $cacheDll; $loaded = $true } catch { $loaded = $false }
    }

    if (-not $loaded) {
        try {
            if (-not (Test-Path -LiteralPath $cacheDir)) {
                New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
            }
            Add-Type -Namespace 'Flashbang' -Name 'Native' -MemberDefinition $nativeSource `
                     -OutputAssembly $cacheDll
            Add-Type -Path $cacheDll
        } catch {
            # Cache unavailable (locked file, no write access) - compile in-process.
            Add-Type -Namespace 'Flashbang' -Name 'Native' -MemberDefinition $nativeSource
        }
    }
}

$HWND_TOPMOST      = [IntPtr]::new(-1)
$SWP_NOACTIVATE    = 0x0010
$SWP_SHOWWINDOW    = 0x0040
$GWL_EXSTYLE       = -20
$WS_EX_TRANSPARENT = 0x00000020  # clicks fall through to the window underneath
$WS_EX_TOOLWINDOW  = 0x00000080  # keep it out of Alt+Tab
$WS_EX_NOACTIVATE  = 0x08000000  # never take focus

try {
    $background = [System.Drawing.ColorTranslator]::FromHtml($Color)
} catch {
    Write-Warning "Unrecognized color '$Color'; falling back to White."
    $background = [System.Drawing.Color]::White
}

$bounds = if ($PrimaryScreenOnly) {
    [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
} else {
    [System.Windows.Forms.SystemInformation]::VirtualScreen
}

$form = New-Object System.Windows.Forms.Form
try {
    $form.FormBorderStyle   = 'None'
    $form.StartPosition     = 'Manual'
    $form.ShowInTaskbar     = $false
    $form.BackColor         = $background
    # Forces a layered window up front so Opacity animates without a handle rebuild.
    $form.AllowTransparency = $true
    $form.Opacity           = $MaxOpacity
    $form.Bounds            = $bounds

    $handle = $form.Handle   # touching Handle creates the window without showing it

    $exStyle = [Flashbang.Native]::GetWindowLong($handle, $GWL_EXSTYLE)
    [void][Flashbang.Native]::SetWindowLong($handle, $GWL_EXSTYLE,
        ($exStyle -bor $WS_EX_TRANSPARENT -bor $WS_EX_TOOLWINDOW -bor $WS_EX_NOACTIVATE))

    [void][Flashbang.Native]::SetWindowPos($handle, $HWND_TOPMOST,
        $bounds.X, $bounds.Y, $bounds.Width, $bounds.Height,
        ($SWP_NOACTIVATE -bor $SWP_SHOWWINDOW))
    [System.Windows.Forms.Application]::DoEvents()

    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    while ($clock.ElapsedMilliseconds -lt $HoldMs) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 10
    }

    if ($FadeMs -gt 0) {
        $clock.Restart()
        while ($clock.ElapsedMilliseconds -lt $FadeMs) {
            $progress = $clock.ElapsedMilliseconds / $FadeMs
            $form.Opacity = $MaxOpacity * (1 - $progress)
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 8
        }
    }
} finally {
    $form.Dispose()
}
} catch {
    exit 0
}
