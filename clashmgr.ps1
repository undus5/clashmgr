# powershell

$program_name = Split-Path $MyInvocation.MyCommand.Path -LeafBase

$baseurl = "https://github.com"
# $baseurl = "https://ghproxy.com/https://github.com"
$api_baseurl = "https://api.github.com/repos"

$script_dir = $MyInvocation.MyCommand.Path | Split-Path -Parent
$update_dir = "${runtime_dir}\updates"

$runtime_old_dir = "${script_dir}\runtime_old"

$runtime_dir = "${script_dir}\runtime"
if ( !(Test-Path $runtime_dir) ) {
    New-Item -Path $runtime_dir -ItemType Directory | Out-Null
}

$process_name = "clash-windows-amd64-v3"

$clash_path = "${runtime_dir}\${process_name}.exe"
$clash_update_path = "${update_dir}\${process_name}.exe"

$clash_repo = "Dreamacro/clash"
# $clash_release_url = "${api_baseurl}/${clash_repo}/releases/tags/premium"
$clash_release_url = "${api_baseurl}/${clash_repo}/releases/latest"

$dashboard_name = "clash-dashboard"
$dashboard_owner = "Dreamacro"
# $dashboard_name = "yacd"
# $dashboard_owner = "haishanh"

$dashboard_repo = "${dashboard_owner}/${dashboard_name}"
$dashboard_repo_branch = "gh-pages"
$dashboard_path = "${runtime_dir}\${dashboard_name}"
$dashboard_update_path = "${update_dir}\${dashboard_name}"

$geoip_name = "Country.mmdb"
$geoip_path = "${runtime_dir}\${geoip_name}"
$geoip_update_path = "${update_dir}\${geoip_name}"

$geoip_repo = "Dreamacro/maxmind-geoip"
$geoip_release_url = "${api_baseurl}/${geoip_repo}/releases/latest"
$geoip_download_url = "${baseurl}/${geoip_repo}/releases/latest/download/${geoip_name}"
# $geoip_repo = "Hackl0us/GeoIP2-CN"
# $geoip_release_url = "${api_baseurl}/${geoip_repo}/branches/release"
# $geoip_download_url = "${baseurl}/${geoip_repo}/raw/release/${geoip_name}"

if (Test-Path $update_dir) {
    Remove-Item -Recurse $update_dir
}
New-Item -Path $update_dir -ItemType Directory | Out-Null

$config_path = "${runtime_dir}\config.yaml"
if ( !(Test-Path $config_path) ) {
    "mixed-port: 7890" >> $config_path
    "external-controller: 127.0.0.1:9090" >> $config_path
    "external-ui: ${dashboard_name}" >> $config_path
}

function Get-Help {
    "Clash command-line management tool`n"
    "Usage: ${process_name} <start|stop|status|update|set|get>"
    "Options:"
    $format = "{0, 3} {1, -20} {2}"
    $format -f "", "start", "start clash service"
    $format -f "", "stop", "stop clash service"
    $format -f "", "status", "check clash service status"
    $format -f "", "update", "update clash, dashboard, geoip database"
    $format -f "", "set <example.yaml>", "apply config file to clash service"
    $format -f "", "get <example.txt>", "update config subscription"
    $format -f "", "", "the content of example.txt is your subscription url"
}

function Start-Clash {
    Get-Process -Name $process_name > $null 2>&1
    if ($?) {
        Write-Host "already running"
        Break
    }
    & $clash_path -d $runtime_dir
    $CLASH_CONF = Get-Item Env:CLASH_CONF -ErrorAction SilentlyContinue
    if ($CLASH_CONF) {
        Start-Sleep -Seconds 1
        Set-Config $CLASH_CONF
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
    $external_controller_raw = $(Get-Content "${runtime_dir}\config.yaml" | Select-String $pattern) -replace $pattern, ""
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
        Write-Host "no 'external-controller' attribute in ${runtime_dir}\config.yaml"
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
        Write-Host "no 'external-controller' attribute in ${runtime_dir}\config.yaml"
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
    $url = $clash_release_url
    $release_name = $(curl -sSL $url | ConvertFrom-Json).name

    if (!$release_name.StartsWith("v")) {
        $latest_version = $(-split $release_name)[1]
    } else {
        $latest_version = $release_name
    }
    if ( !(Test-Path $clash_path) ) {
        Return $latest_version
    }

    $current_version = $(-split $(& $clash_path -v))[1]
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

    if (!$latest_version.StartsWith("v")) {
        $tag = "premium"
    } else {
        $tag = $latest_version
    }

    $url = "${baseurl}/${clash_repo}/releases/download/${tag}/${archive_name}"
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
    if (Test-Path $clash_update_path) {
        Write-Host "updating clash ... " -NoNewline
        Move-Item $clash_update_path $runtime_dir -Force
        if ($?) {
            Write-Host "success"
        }
    }
}

function Test-Dashboard-Update {
    if ( !(Test-Path $dashboard_path) ) {
        Return $true
    }
    $current_version_datetime = Get-ItemPropertyValue -Name LastWriteTime ${runtime_dir}\${dashboard_name}
    $url = "${api_baseurl}/${dashboard_repo}/branches/${dashboard_repo_branch}"
    $latest_version_datetime = $(curl -sSL $url | ConvertFrom-Json).commit.commit.committer.date
    $lt = $($current_version_datetime -lt $latest_version_datetime)
    return $lt
}

function Get-Dashboard {
    Write-Host "downloading dashboard ... "
    $dashboard_repo_branch = "gh-pages"
    $url = "${baseurl}/${dashboard_repo}/archive/refs/heads/${dashboard_repo_branch}.zip"
    $archive_path = "${dashboard_update_path}-${dashboard_repo_branch}.zip"
    curl -#SL $url -o $archive_path
    if ($?) {
        Write-Host "unpacking dashboard ... " -NoNewline
        Expand-Archive -Path $archive_path -DestinationPath $update_dir
        if ($?) {
            Move-Item "${dashboard_update_path}-${dashboard_repo_branch}" $dashboard_update_path
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
        Move-Item $dashboard_update_path $runtime_dir -Force
        if ($?) {
            Write-Host "success"
        }
    }
}

function Test-Geoip-Update {
    if ( !(Test-Path $geoip_path) ) {
        Return $true
    }
    $current_version_datetime = Get-ItemPropertyValue -Name LastWriteTime ${runtime_dir}\${geoip_name}
    $url = $geoip_release_url
    $release_info = $(curl -sSL $url | ConvertFrom-Json)
    if ($url.Contains("branches")) {
        $latest_version_datetime = $release_info.commit.commit.committer.date
    } else {
        $latest_version_datetime = $release_info.published_at
    }
    $lt = $($current_version_datetime -lt $latest_version_datetime)
    return $lt
}

function Get-Geoip {
    Write-Host "downloading geoip ... "
    $url = $geoip_download_url
    curl -#SL $url -o $geoip_update_path
}

function Update-Geoip {
    if (Test-Path $geoip_update_path) {
        Write-Host "updating geoip ... " -NoNewline
        Move-Item $geoip_update_path $runtime_dir -Force
        if ($?) {
            Write-Host "success"
        }
    }
}

function Test-Downloaded-Update {
    Return ( (Test-Path $clash_update_path) -or (Test-Path $dashboard_update_path) -or (Test-Path $geoip_update_path) )
}

function Make-Backup {
    Copy-Item -Path $runtime_dir -Destination $runtime_old_dir -Recurse
}

function Update {
    if ( Test-Path $runtime_old_dir ) {
        Write-Host "'runtime_old' exists, remove first."
        Return $false
    }

    Write-Host "checking clash update ... " -NoNewline
    $latest_version = Test-Clash-Update
    if ($latest_version) {
        Write-Host "success"
        Get-Clash $latest_version
    } else {
        Write-Host "is up to date"
    }

    Write-Host "checking dashboard update ... " -NoNewline
    if (Test-Dashboard-Update) {
        Get-Dashboard
    } else {
        Write-Host "is up to date"
    }

    Write-Host "checking geoip update ... " -NoNewline
    if (Test-Geoip-Update) {
        Get-Geoip
    } else {
        Write-Host "is up to date"
    }

    if (Test-Downloaded-Update) {
        Stop-Clash
        Make-Backup
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
            Write-Host "saved as ${target_path}"
        }
    } else {
        Write-Host "invalid url"
    }
}

switch ($args[0]) {
    "start" {
        if ( !(Test-Path $clash_path) ) {
            Update
        }
        Start-Clash
    }
    "stop" {
        Stop-Clash
    }
    { "restart", "reload" -contains $_ } {
        Stop-Clash
        Start-Clash
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
