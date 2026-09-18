[CmdletBinding()]
param(
    [ValidateSet('Codex', 'Claude')][string]$Client,
    [string]$Key,
    [Parameter(Position = 2)][string]$FilePath,
    [Parameter(Position = 3, ValueFromRemainingArguments = $true)][string[]]$ArgumentList
)

$ErrorActionPreference = 'Stop'

function Assert-CredentialKey {
    param([string]$Value)
    if ($Value -notmatch '^[A-Za-z_][A-Za-z0-9_]{0,127}$') { throw 'Credential key must be an environment-variable-compatible name.' }
}

function Get-CredentialTarget {
    param([string]$Client, [string]$Key)
    Assert-CredentialKey $Key
    return "MyAiConfiguration/$($Client.ToLowerInvariant())/$Key"
}

function Initialize-NativeCredentialApi {
    if ('MyAiConfiguration.NativeCredential' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace MyAiConfiguration {
  public static class NativeCredential {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL {
      public UInt32 Flags;
      public UInt32 Type;
      public IntPtr TargetName;
      public IntPtr Comment;
      public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
      public UInt32 CredentialBlobSize;
      public IntPtr CredentialBlob;
      public UInt32 Persist;
      public UInt32 AttributeCount;
      public IntPtr Attributes;
      public IntPtr TargetAlias;
      public IntPtr UserName;
    }
    [DllImport("Advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CredWrite(ref CREDENTIAL credential, UInt32 flags);
    [DllImport("Advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CredRead(string target, UInt32 type, UInt32 flags, out IntPtr credential);
    [DllImport("Advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CredDelete(string target, UInt32 type, UInt32 flags);
    [DllImport("Advapi32.dll", SetLastError = true)]
    public static extern void CredFree(IntPtr buffer);
  }
}
'@
}

function Set-ManagedCredential {
    param([ValidateSet('Codex', 'Claude')][string]$Client, [string]$Key, [securestring]$Value)
    if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) { throw 'The OS credential store is currently supported on Windows only.' }
    Initialize-NativeCredentialApi
    $plain = [System.Net.NetworkCredential]::new('', $Value).Password
    $bytes = [Text.Encoding]::UTF8.GetBytes($plain)
    if ($bytes.Length -eq 0 -or $bytes.Length -gt 2560) { throw 'Credential value must contain between 1 and 2560 UTF-8 bytes.' }
    $native = New-Object MyAiConfiguration.NativeCredential+CREDENTIAL
    $native.Type = 1
    $native.Persist = 2
    $native.TargetName = [Runtime.InteropServices.Marshal]::StringToCoTaskMemUni((Get-CredentialTarget $Client $Key))
    $native.UserName = [Runtime.InteropServices.Marshal]::StringToCoTaskMemUni($Key)
    $native.CredentialBlobSize = $bytes.Length
    $native.CredentialBlob = [Runtime.InteropServices.Marshal]::AllocCoTaskMem($bytes.Length)
    try {
        [Runtime.InteropServices.Marshal]::Copy($bytes, 0, $native.CredentialBlob, $bytes.Length)
        if (-not [MyAiConfiguration.NativeCredential]::CredWrite([ref]$native, 0)) { throw [ComponentModel.Win32Exception]::new([Runtime.InteropServices.Marshal]::GetLastWin32Error()) }
    } finally {
        [Array]::Clear($bytes, 0, $bytes.Length)
        $plain = $null
        if ($native.TargetName -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::FreeCoTaskMem($native.TargetName) }
        if ($native.UserName -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::FreeCoTaskMem($native.UserName) }
        if ($native.CredentialBlob -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::FreeCoTaskMem($native.CredentialBlob) }
    }
}

function Get-ManagedCredential {
    param([ValidateSet('Codex', 'Claude')][string]$Client, [string]$Key)
    if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) { throw 'The OS credential store is currently supported on Windows only.' }
    Initialize-NativeCredentialApi
    $pointer = [IntPtr]::Zero
    if (-not [MyAiConfiguration.NativeCredential]::CredRead((Get-CredentialTarget $Client $Key), 1, 0, [ref]$pointer)) { throw 'Credential was not found.' }
    try {
        $native = [Runtime.InteropServices.Marshal]::PtrToStructure($pointer, [type]'MyAiConfiguration.NativeCredential+CREDENTIAL')
        $bytes = New-Object byte[] $native.CredentialBlobSize
        [Runtime.InteropServices.Marshal]::Copy($native.CredentialBlob, $bytes, 0, $bytes.Length)
        try { return [Text.Encoding]::UTF8.GetString($bytes) } finally { [Array]::Clear($bytes, 0, $bytes.Length) }
    } finally {
        [MyAiConfiguration.NativeCredential]::CredFree($pointer)
    }
}

function Remove-ManagedCredential {
    param([ValidateSet('Codex', 'Claude')][string]$Client, [string]$Key)
    if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) { throw 'The OS credential store is currently supported on Windows only.' }
    Initialize-NativeCredentialApi
    if (-not [MyAiConfiguration.NativeCredential]::CredDelete((Get-CredentialTarget $Client $Key), 1, 0)) { throw [ComponentModel.Win32Exception]::new([Runtime.InteropServices.Marshal]::GetLastWin32Error()) }
}

function Invoke-WithManagedCredential {
    param([ValidateSet('Codex', 'Claude')][string]$Client, [string]$Key, [string]$FilePath, [string[]]$ArgumentList)
    Assert-CredentialKey $Key
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { throw 'Child command was not found.' }
    $prior = [Environment]::GetEnvironmentVariable($Key, 'Process')
    $value = Get-ManagedCredential $Client $Key
    try {
        [Environment]::SetEnvironmentVariable($Key, $value, 'Process')
        & $FilePath @ArgumentList
        return $LASTEXITCODE
    } finally {
        [Environment]::SetEnvironmentVariable($Key, $prior, 'Process')
        $value = $null
    }
}

if ($FilePath) {
    if (-not $Client -or -not $Key) { throw 'Client and key are required.' }
    exit (Invoke-WithManagedCredential $Client $Key $FilePath $ArgumentList)
}
