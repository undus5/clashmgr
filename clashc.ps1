# powershell

$config_dir_raw = "~\.config\clashc"
if ( !(Test-Path $config_dir_raw) ) {
    New-Item -Path $config_dir_raw -ItemType Directory | Out-Null
}

# $baseurl = "https://github.com"
$baseurl = "https://download.fastgit.org"

# $script_dir = $MyInvocation.MyCommand.Path | Split-Path -Parent
$config_dir = Resolve-Path $config_dir_raw
$update_dir = "${config_dir}\update"

$process_name = "clash-windows-amd64"

$program_path = "${config_dir}\${process_name}.exe"
$program_update_path = "${update_dir}\${process_name}.exe"

# $dashboard_name = "clash-dashboard"
# $dashboard_repo = "Dreamacro/clash-dashboard"
$dashboard_name = "yacd"
$dashboard_repo = "haishanh/yacd"
$dashboard_path = "${config_dir}\${dashboard_name}"
$dashboard_update_path = "${update_dir}\${dashboard_name}"

$geoip_name = "Country.mmdb"
$geoip_path = "${config_dir}\${geoip_name}"
$geoip_update_path = "${update_dir}\${geoip_name}"

if (Test-Path $update_dir) {
    Remove-Item -Recurse $update_dir
}
New-Item -Path $update_dir -ItemType Directory | Out-Null

$config_path = "${config_dir}\config.yaml"
if ( !(Test-Path $config_path) ) {
    "mixed-port: 7890" >> $config_path
    "external-controller: 127.0.0.1:9090" >> $config_path
    "external-ui: ${dashboard_name}" >> $config_path
}

function Get-Help {
    "Clash command-line management tool`n"
    "Syntax: clashc [start|stop|status|update|set|get]"
    "Options:"
    "{0, 3} {1, -20} {2}" -f "", "start", "start clash service"
    "{0, 3} {1, -20} {2}" -f "", "stop", "stop clash service"
    "{0, 3} {1, -20} {2}" -f "", "status", "check clash service status"
    "{0, 3} {1, -20} {2}" -f "", "update", "update clash, dashboard, geoip database"
    "{0, 3} {1, -20} {2}" -f "", "set example.yaml", "apply config file to clash service"
    "{0, 3} {1, -20} {2}" -f "", "get example.txt", "update config subscription"
    "{0, 3} {1, -20} {2}" -f "", "", "the content of example.txt is your subscription url"
}

function Start-Clash {
    Get-Process -Name $process_name > $null 2>&1
    if ($?) {
        Write-Host "already running"
    } else {
        & $program_path -d $config_dir
    }
}

function Stop-Clash {
    Get-Process -Name $process_name > $null 2>&1
    if ($?) {
        Stop-Process -Name $process_name
    }
}

function Get-External-Controller {
    $pattern = "external-controller:"
    $external_controller_raw = $(Get-Content "${config_dir}\config.yaml" | Select-String $pattern) -replace $pattern, ""
    if ($external_controller_raw.Length -gt 0) {
        Return $external_controller_raw.Trim()
    } else {
        Return $false
    }
}

function Get-Status {
    Get-Process -Name $process_name > $null 2>&1
    if (!$?) {
        Write-Host "clash not running"
        Break
    }

    $external_controller = Get-External-Controller
    if (!$external_controller) {
        Write-Host "no 'external-controller' attribute in ${config_dir}\config.yaml"
        Break
    }

    $url = "${external_controller}/configs"
    curl -sSL $url | ConvertFrom-Json
}

function Set-Config {
    Param(
        [Parameter(Position=0)] [string] $path
    )

    Get-Process -Name $process_name > $null 2>&1
    if (!$?) {
        Write-Host "clash not running"
        Break
    }

    $external_controller = Get-External-Controller
    if (!$external_controller) {
        Write-Host "no 'external-controller' attribute in ${config_dir}\config.yaml"
        Break
    }

    if ( !($path.Length -gt 0) ) {
        Get-Help
        Break
    }
    if ( !(Test-Path $path) ) {
        Write-Host "${path} not exists"
        Break
    }

    $config_path = $(Resolve-Path $path).Path
    Write-Host "setting ${config_path} ... " -NoNewline

    $data = "{`"`"`"path`"`"`":`"`"$($config_path | ConvertTo-Json)`"`"}"
    $header = "Content-Type: application/json"
    $url = "${external_controller}/configs"
    $status=$(curl -sSL -X PUT $url -H $header --data-raw $data -w "%{http_code}")

    if ( $? -and ($status -eq 204) ) {
        Write-Host "success"
    } else {
        Write-Host "error: $status"
    }
}

function Test-Clash-Update {
    $url = "https://api.github.com/repos/Dreamacro/clash/releases/tags/premium"
    $latest_version = $(-split $(curl -sSL $url | ConvertFrom-Json).name)[1]

    if ( !(Test-Path $program_path) ) {
        Return $latest_version
    }

    $current_version = $(-split $(& $program_path -v))[1]
    $is_latest = $current_version -eq $latest_version

    if ($is_latest) {
        Return $false
    } else {
        Return $latest_version
    }
}

function Get-Clash {
    Param(
        [Parameter(Mandatory,Position=0)] [string] $latest_version
    )

    Write-Host "downloading clash ... "

    $archive_name = "${process_name}-${latest_version}.zip"
    $archive_path = "${update_dir}\${archive_name}"
    $url = "${baseurl}/Dreamacro/clash/releases/download/premium/${archive_name}"
    curl -#SL $url -o $archive_path

    if ($?) {
        Write-Host "unpacking clash ... " -NoNewline
        Expand-Archive -Path $archive_path -DestinationPath $update_dir
        if ($?) {
            Remove-Item $archive_path
            Write-Host "success"
        } else {
            Write-Host "error"
        }
    } else {
        Write-Host "error"
    }
}

function Update-Clash {
    if (Test-Path $program_update_path) {
        Write-Host "updating clash ... " -NoNewline
        Move-Item $program_update_path $config_dir -Force
        if ($?) {
            Write-Host "success"
        }
    }
}

function Test-Dashboard-Update {
    if ( !(Test-Path $dashboard_path) ) {
        Return $true
    }
    $current_version_datetime = Get-ItemPropertyValue -Name LastWriteTime ${config_dir}\${dashboard_name}
    $url = "https://api.github.com/repos/Dreamacro/clash/commits"
    $latest_version_datetime = $(curl -sSL $url | ConvertFrom-Json).commit[0].author.date
    $lt = $($current_version_datetime -lt $latest_version_datetime)
    return $lt
}

function Get-Dashboard {
    Write-Host "downloading dashboard ... "
    $suffix = "gh-pages"
    $url = "${baseurl}/${dashboard_repo}/archive/refs/heads/${suffix}.zip"
    $archive_path = "${dashboard_update_path}-${suffix}.zip"
    curl -#SL $url -o $archive_path
    if ($?) {
        Write-Host "unpacking dashboard ... " -NoNewline
        Expand-Archive -Path $archive_path -DestinationPath $update_dir
        if ($?) {
            Move-Item "${dashboard_update_path}-${suffix}" $dashboard_update_path
            Remove-Item $archive_path
            Write-Host "success"
        } else {
            Write-Host "error"
        }
    }
    else {
        Write-Host " error"
    }
}

function Update-Dashboard {
    if (Test-Path $dashboard_update_path) {
        Write-Host "updating dashboard ... " -NoNewline
        Move-Item $dashboard_update_path $config_dir -Force
        if ($?) {
            Write-Host "success"
        }
    }
}

function Test-Geoip-Update {
    if ( !(Test-Path $geoip_path) ) {
        Return $true
    }
    $current_version_datetime = Get-ItemPropertyValue -Name LastWriteTime ${config_dir}\${geoip_name}
    $url = "https://api.github.com/repos/Dreamacro/maxmind-geoip/releases/latest"
    $latest_version_datetime = $(curl -sSL $url | ConvertFrom-Json).published_at
    $lt = $($current_version_datetime -lt $latest_version_datetime)
    return $lt
}

function Get-Geoip {
    Write-Host "downloading geoip ... "
    $url = "${baseurl}/Dreamacro/maxmind-geoip/releases/latest/download/${geoip_name}"
    curl -#SL $url -o $geoip_update_path
}

function Update-Geoip {
    if (Test-Path $geoip_update_path) {
        Write-Host "updating geoip ... " -NoNewline
        Move-Item $geoip_update_path $config_dir -Force
        if ($?) {
            Write-Host "success"
        }
    }
}

function Test-Downloaded-Update {
    Return ( (Test-Path $program_update_path) -or (Test-Path $dashboard_update_path) -or (Test-Path $geoip_update_path) )
}

function Update {
    Write-Host "checking clash update ... "
    $latest_version = Test-Clash-Update
    if ($latest_version) {
        Write-Host "success"
        Get-Clash $latest_version
    } else {
        Write-Host "already up to date"
    }

    Write-Host "checking dashboard update ... " -NoNewline
    if (Test-Dashboard-Update) {
        Get-Dashboard
    } else {
        Write-Host "already up to date"
    }

    Write-Host "checking geoip update ... " -NoNewline
    if (Test-Geoip-Update) {
        Get-Geoip
    } else {
        Write-Host "already up to date"
    }

    if (Test-Downloaded-Update) {
        Stop-Clash
        Update-Clash
        Update-Dashboard
        Update-Geoip
    }
}

function isURIWeb($address) {
	$uri = $address -as [System.URI]
	$uri.AbsoluteURI -ne $null -and $uri.Scheme -match '[http|https]'
}

function Get-Config {
    Param(
        [Parameter(Position=0)] [string] $path
    )
    if ( !($path.Length -gt 0) ) {
        Get-Help
        Break
    }
    if ( !(Test-Path $path) ) {
        Write-Host "${path} not exists"
        Break
    }
    $abs_path = $(Resolve-Path $path).Path
    $basename = Split-Path $path -LeafBase
    $target_dir = Split-Path -Parent $abs_path
    $target_path = "${target_dir}\${basename}.yaml"
    $url = $(Get-Content $path -First 1).Trim()
    if (isURIWeb $url) {
        Write-Host "downloading config ... " -NoNewline
        curl -sSL $url -o $target_path
        if ($?) {
            Write-Host "success"
            Write-Host "save as ${target_path}"
        }
    } else {
        Write-Host "invalid url"
    }
}

switch ($args[0]) {
    "start" {
        if ( !(Test-Path $program_path) ) {
            Update
        }
        Start-Clash
    }
    "stop" {
        Stop-Clash
    }
    "status" {
        Get-Status
    }
    "set" {
        Set-Config $args[1]
    }
    "update" {
        Update
    }
    "get" {
        Get-Config $args[1]
    }
    default {
        Get-Help
    }
}
