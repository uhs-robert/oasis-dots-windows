# Open pwsh in WezTerm with -command typed at the prompt but not run, for tools like xh that are
# useless without arguments. The window title is set to -command so a window rule can float it.
[CmdletBinding(PositionalBinding = $false)]
param([Parameter(Mandatory)][string] $command)

# PSReadLine raises PowerShell.OnIdle while it waits for input, the first moment Insert lands on
# the prompt line. -EncodedCommand spares the script from quoting through Start-Process and WezTerm.
$startup_script = @"
`$Host.UI.RawUI.WindowTitle = '$command'
`$null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action { [Microsoft.PowerShell.PSConsoleReadLine]::Insert('$command ') }
"@
$encoded_script = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($startup_script))
Start-Process wezterm-gui -ArgumentList 'start', '--', 'pwsh', '-NoLogo', '-NoExit', '-EncodedCommand', $encoded_script
