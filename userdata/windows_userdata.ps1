<powershell>
#ps1_sysnative

$StartupScriptArchive = "kasm-windows-startup.zip"
$StartupScriptUrl = "https://kasmweb-build-artifacts.s3.amazonaws.com/kasm-autoscale-scripts/1.18.1/$StartupScriptArchive"
$WorkingDirectory = "$($Env:Temp)"
$InitScript = "$WorkingDirectory\Init-VM-Task.ps1"
$ProgressPreference = "SilentlyContinue" # improve Invoke-Webrequest performance

Write-Output "`nInitiating Kasm Startup Script"

try {{
    Write-Output "`nDownloading $StartupScriptUrl"
    Invoke-Webrequest -URI $StartupScriptUrl -OutFile "$WorkingDirectory\$StartupScriptArchive"
}} catch {{
    Write-Output "Request failed: $($_.Exception.Message)"
}}

Write-Output "Extracting archive $WorkingDirectory\$StartupScriptArchive"
Expand-Archive -Path "$WorkingDirectory\$StartupScriptArchive" -DestinationPath $WorkingDirectory

& $InitScript `
  -KasmHostname "{upstream_auth_address}" `
  -RegistrationToken "{checkin_jwt}" `
  -ServerId "{server_id}"

</powershell>