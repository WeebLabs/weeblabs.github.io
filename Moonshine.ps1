param([switch]$Elevated)

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false)  {
    if ($elevated) {
        # Tried to elevate, did not work, aborting
        exit
    } else {
        $scriptPath = $myinvocation.MyCommand.Path
        Start-Process powershell.exe -Verb RunAs -ArgumentList ("-noprofile -noexit -file `"$scriptPath`" -elevated")
        exit
    }
}

'Welcome to the Moonshine virtual monitor setup script.'
'Verifying that Sunshine is installed before proceeding.'

# Define the path to the configuration file
$configFilePath = "C:\Program Files\Sunshine\config\sunshine.conf"

# Check if the configuration file exists
if (-not (Test-Path $configFilePath -PathType Leaf)) {
    Write-Host "Sunshine is not installed!  Please install Sunshine before executing."
    exit
}

'Sunshine installation found.  Verifying configuration.'

# Check if config is ready
if (-not (Get-Content -Path $configFilePath | Select-String -Pattern "^$lineToAdd")) {
    # Add the line to the end of the file
    Add-Content -Path $configFilePath -Value "$lineToAdd`n"
    'Added required parameters to Sunshine configuration file.'
}
else {
    Write-Host "Configuration is valid."
}

irm get.scoop.sh -outfile 'install.ps1'
.\install.ps1 -RunAsAdmin


scoop install git
scoop bucket add extras
scoop bucket add nonportable
scoop install iddsampledriver-ge9-np -g

'Adding support for common iPad resolutions'

$filePath = 'C:\IddSampleDriver\option.txt'
$resolutions = @(
    '2732, 2048, 120',
    '1366, 1024, 120',
    '2732, 2048, 60',
    '1366, 1024, 60'
)

# Ensure there is a blank line at the end of the file
Add-Content -Path $filePath -Value "`n"

# Check if each resolution is already in the file before adding
foreach ($resolution in $resolutions) {
    $content = Get-Content -Path $filePath
    if ($content -contains $resolution) {
        Write-Host "Resolution already present. Skipping."
    } else {
        Add-Content -Path $filePath -Value $resolution
    }
}


'Restarting virtual display driver to apply new resolutions'

Get-PnpDevice -FriendlyName "*IddSampleDriver Device*" | Disable-PnpDevice -Confirm:$false
Get-PnpDevice -FriendlyName "*IddSampleDriver Device*" | Enable-PnpDevice -Confirm:$false

'Setting up Virtual Display Helper'

# Define the GitHub repository and release URL
$repoUrl = "https://api.github.com/repos/WeebLabs/Virtual-Monitor-Helper/releases/latest"
$releaseInfo = Invoke-RestMethod -Uri $repoUrl
$latestReleaseTag = $releaseInfo.tag_name

# Construct the URL for the latest release binary
$url = "https://github.com/WeebLabs/Virtual-Monitor-Helper/releases/download/$latestReleaseTag/VirtualMonitorHelper.exe"

# Define the destination folder
$destinationFolder = "C:\IddSampleDriver"

'Fetching latest release.'

# Download the file
Invoke-WebRequest -Uri $url -OutFile "$destinationFolder\VirtualMonitorHelper.exe"

'Adding helper to startup via Task Scheduler'

$action = New-ScheduledTaskAction -Execute 'C:\IddSampleDriver\VirtualMonitorHelper.exe'
$trigger = New-ScheduledTaskTrigger -AtLogOn
$trigger.Delay = 'PT1M'
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "Virtual Monitor Helper" -RunLevel Highest

'Starting Virtual Display Helper'

# Launch the application with admin privileges without prompting the user
Start-Process -FilePath "$destinationFolder\VirtualMonitorHelper.exe" -Verb RunAs


'All done! Helper will start 60 seconds after login to ensure necessary conditions met.'
