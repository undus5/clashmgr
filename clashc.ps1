# powershell

$config_dir_raw = "~\.config\clash"
if ( !(Test-Path $config_dir_raw) ) {
    New-Item -Path $config_dir_raw -ItemType Directory | Out-Null
}
# $script_dir = $MyInvocation.MyCommand.Path | Split-Path -Parent
$config_dir = Resolve-Path $config_dir_raw
$update_dir = "${config_dir}\update"

if (Test-Path $update_dir) {
    Remove-Item -Recurse $update_dir
}
New-Item -Path $update_dir -ItemType Directory | Out-Null

$config_path = "${config_dir}\config.yaml"
if ( !(Test-Path $config_path) ) {
    "mixed-port: 7890" >> $config_path
    "external-controller: 127.0.0.1:9090" >> $config_path
    "external-ui: clash-dashboard" >> $config_path
}

$process_name = "clash-windows-amd64"

$program_path = "${config_dir}\${process_name}.exe"
$program_update_path = "${update_dir}\${process_name}.exe"

$dashboard_name = "clash-dashboard"
$dashboard_path = "${config_dir}\${dashboard_name}"
$dashboard_update_path = "${update_dir}\${dashboard_name}"

$geoip_name = "Country.mmdb"
$geoip_path = "${config_dir}\${geoip_name}"
$geoip_update_path = "${update_dir}\${geoip_name}"

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

function Set-Config {
    Param(
        [Parameter(Position=0)] [string] $path
    )

    Get-Process -Name $process_name > $null 2>&1
    if (!$?) {
        Write-Host "clash not running"
        Break
    }

    $pattern = "external-controller:"
    $external_controller_raw = $(Get-Content "${config_dir}\config.yaml" | Select-String $pattern) -replace $pattern, ""
    if ($external_controller_raw.Length -gt 0) {
        $external_controller = $external_controller_raw.Trim()
    } else {
        Write-Host "no 'external-controller' attribute in ${config_dir}\config.yaml"
        Break
    }

    if ( !($path.Length -gt 0) ) {
        Write-Host "usage: clashc set file.yaml"
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
    $status=$(curl -sSL -X PUT "${external_controller}/configs" -H $header --data-raw $data -w "%{http_code}")

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

    Write-Host "downloading clash ... " -NoNewline

    $archive_name = "${process_name}-${latest_version}.zip"
    $archive_path = "${update_dir}\${archive_name}"
    # $url = "https://github.com/Dreamacro/clash/releases/download/premium/${archive_name}"
    $url = "https://download.fastgit.org/Dreamacro/clash/releases/download/premium/${archive_name}"
    curl -#SL $url -o $archive_path

    if ($?) {
        Write-Host "success"
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

function Test-Clash-Dashboard-Update {
    if ( !(Test-Path $dashboard_path) ) {
        Return $true
    }
    $current_version_datetime = Get-ItemPropertyValue -Name LastWriteTime ${config_dir}\${dashboard_name}
    $url = "https://api.github.com/repos/Dreamacro/clash/commits"
    $latest_version_datetime = $(curl -sSL $url | ConvertFrom-Json).commit[0].author.date
    $lt = $($current_version_datetime -lt $latest_version_datetime)
    return $lt
}

function Get-Clash-Dashboard {
    Write-Host "downloading clash-dashboard ... " -NoNewline
    $suffix = "gh-pages"
    # $url = "https://github.com/Dreamacro/clash-dashboard/archive/refs/heads/${suffix}.zip"
    $url = "https://download.fastgit.org/Dreamacro/clash-dashboard/archive/refs/heads/${suffix}.zip"
    $archive_path = "${dashboard_update_path}-${suffix}.zip"
    curl -#SL $url -o $archive_path
    if ($?) {
        Write-Host "success"
        Write-Host "unpacking clash-dashboard ... " -NoNewline
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

function Update-Clash-Dashboard {
    if (Test-Path $dashboard_update_path) {
        Write-Host "updating clash-dashboard ... " -NoNewline
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
    Write-Host "downloading geoip ... " -NoNewline
    # $url = "https://github.com/Dreamacro/maxmind-geoip/releases/latest/download/${geoip_name}"
    $url = "https://download.fastgit.org/Dreamacro/maxmind-geoip/releases/latest/download/${geoip_name}"
    curl -#SL $url -o $geoip_update_path
    if ($?) {
        Write-Host "success"
    } else {
        Write-Host "error"
    }
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

    Write-Host "checking clash-dashboard update ... " -NoNewline
    if (Test-Clash-Dashboard-Update) {
        Get-Clash-Dashboard
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
        Update-Clash-Dashboard
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
        Write-Host "usage: clashc get file.txt"
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
        Write-Host "usage: clashc start|stop|update|set file.yaml|get file.txt"
    }
}
