#!/usr/bin/env bash

dirname() {
    # Usage: dirname "path"
    local tmp=${1:-.}

    [[ $tmp != *[!/]* ]] && {
        printf '/\n'
        return
    }

    tmp=${tmp%%"${tmp##*[!/]}"}

    [[ $tmp != */* ]] && {
        printf '.\n'
        return
    }

    tmp=${tmp%/*}
    tmp=${tmp%%"${tmp##*[!/]}"}

    printf '%s\n' "${tmp:-/}"
}

bkr() {
    (nohup "$@" &>/dev/null &)
}

strip_all() {
    # Usage: strip_all "string" "pattern"
    printf '%s\n' "${1//$2}"
}

lstrip() {
    # Usage: lstrip "string" "pattern"
    printf '%s\n' "${1##$2}"
}

test_command() {
    if [[ ! $(command -v $1) ]]; then
        echo "error: $1 command not found"
        exit 1
    fi
}

trim_quotes() {
    # Usage: trim_quotes "string"
    : "${1//\'}"
    printf '%s\n' "${_//\"}"
}

basename() {
    # Usage: basename "path" ["suffix"]
    local tmp

    tmp=${1%"${1##*[!/]}"}
    tmp=${tmp##*/}
    tmp=${tmp%"${2/"$tmp"}"}

    printf '%s\n' "${tmp:-/}"
}

head() {
    # Usage: head "n" "file"
    mapfile -tn "$1" line < "$2"
    printf '%s\n' "${line[@]}"
}

# baseurl="https://github.com"
baseurl="https://download.fastgit.org"

# script_dir=$(dirname $(realpath $0))
config_dir=~/.config/clashc
update_dir=${config_dir}/update

process_name="clash-linux-amd64"

program_path=${config_dir}/${process_name}
program_update_path=${update_dir}/${process_name}

# dashboard_name="clash-dashboard"
# dashboard_repo="Dreamacro/clash-dashboard"
dashboard_name="yacd"
dashboard_repo="haishanh/yacd"
dashboard_path=${config_dir}/${dashboard_name}
dashboard_update_path=${update_dir}/${dashboard_name}

geoip_name="Country.mmdb"
geoip_path=${config_dir}/${geoip_name}
geoip_update_path_path=${update_dir}/${geoip_name}

if [[ -d $update_dir ]]; then
    rm -rf $update_dir
fi
mkdir -p $update_dir

config_path=${config_dir}/config.yaml

if [[ ! -f $config_path ]]; then
    echo "mixed-port: 7890" >> $config_path
    echo "external-controller: 127.0.0.1:9090" >> $config_path
    echo "external-ui: ${dashboard_name}" >> $config_path
fi

start_clash() {
    pid=$(pidof $process_name)
    if [ -z $pid ]; then
        bkr $program_path -d $config_dir
    else
        echo "already running"
    fi
}

stop_clash() {
    pid=$(pidof $process_name)
    if [[ -n $pid ]]; then
        kill -9 $pid
    fi
}

get_external_controller() {
    pattern="external-controller:"
    while IFS= read line || [ -n "$line" ]; do
        line=$(strip_all "$line" "[[:space:]]")
        if [[ $line == ${pattern}* ]]; then
            external_controller=$(lstrip "$line" "$pattern")
        fi
    done < ${config_dir}/config.yaml

    if [[ -n $external_controller ]]; then
        echo $external_controller
        return 0
    else
        return 1
    fi
}

get_status() {
    pid=$(pidof $process_name)
    if [ -z $pid ]; then
        echo "clash not running"
        return 1
    fi

    external_controller=$(get_external_controller)

    if [[ -z $external_controller ]]; then
        echo "no 'external-controller' attribute in ${config_dir}/config.yaml"
        return 1
    fi

    url="${external_controller}/configs"
    curl -sSL $url | jq
}

set_config() {
    pid=$(pidof $process_name)
    if [ -z $pid ]; then
        echo "clash not running"
        return 1
    fi

    external_controller=$(get_external_controller)

    if [[ -z $external_controller ]]; then
        echo "no 'external-controller' attribute in ${config_dir}/config.yaml"
        return 1
    fi

    if [[ -z $1 ]]; then
        echo "usage: clashc set file.yaml"
        return 1
    fi
    if [[ ! -f $1 ]]; then
        echo "$1 not exists"
        return 1
    fi

    config_path=$(realpath $1)
    printf "setting ${config_path} ... "
    data="{\"path\":\"${config_path}\"}"
    header="Content-Type:application/json"
    url="${external_controller}/configs"
    status=$(curl -sSL -X PUT $url -H $header --data-raw $data -w "%{http_code}")

    if [[ $? && $status == "204" ]]; then
        printf "success\n"
    else
        printf "error: $status\n"
    fi
}

test_clash_update() {
    url="https://api.github.com/repos/Dreamacro/clash/releases/tags/premium"
    latest_version=$(lstrip "$(trim_quotes "$(curl -sSL $url | jq '.name')")" "Premium ")
    if [[ ! -f $program_path ]]; then
        echo $latest_version
        return 0
    fi
    current_version=$(lstrip "$($program_path -v)" "Clash ")
    if [[ $current_version == $latest_version ]]; then
        return 1
    else
        echo $latest_version
    fi
}

get_clash() {
    printf "downloading clash ... \n"
    archive_name="${process_name}-${latest_version}.gz"
    archive_path=${update_dir}/${archive_name}
    url="${baseurl}/Dreamacro/clash/releases/download/premium/${archive_name}"
    curl -#SL $url -o $archive_path
    if [[ $? ]]; then
        printf "unpacking clash ... "
        gzip -dc $archive_path > $program_update_path
        if [[ $? ]]; then
            rm $archive_path
            printf "success\n"
        else
            printf "error\n"
        fi
    else
        printf "error\n"
    fi
}

update_clash() {
    if [[ -f $program_update_path ]]; then
        printf "updating clash ... "
        mv -f $program_update_path $config_dir
        chmod u+x $program_path
        if [[ $? ]]; then
            printf "success\n"
        fi
    fi
}

test_dashboard_update() {
    if [[ ! -d $dashboard_path ]]; then
        return 0
    fi
    current_version_datetime=$(date -r $dashboard_path)
    url="https://api.github.com/repos/Dreamacro/clash/commits"
    latest_version_datetime=$(trim_quotes "$(curl -sSL $url | jq '.[0].commit.author.date')")
    if [[ $current_version_datetime < $latest_version_datetime ]]; then
        return 0
    else
        return 1
    fi
}

get_dashboard() {
    printf "downloading dashboard ... \n"
    suffix="gh-pages"
    url="${baseurl}/${dashboard_repo}/archive/refs/heads/${suffix}.zip"
    archive_path="${dashboard_update_path}-${suffix}.zip"
    curl -#SL $url -o $archive_path
    if [[ $? ]]; then
        printf "unpacking dashboard ... "
        unzip -qq $archive_path -d $update_dir
        if [[ $? ]]; then
            mv -f ${dashboard_update_path}-${suffix} $dashboard_update_path
            rm $archive_path
            printf "success\n"
        else
            printf "error\n"
        fi
    else
        printf "error\n"
    fi
}

update_dashboard() {
    if [[ -d $dashboard_update_path ]]; then
        printf "updating dashboard ... "
        mv -f $dashboard_update_path $config_dir
        if [[ $? ]]; then
            printf "success\n"
        fi
    fi
}

test_geoip_update_path() {
    if [[ ! -f $geoip_path ]]; then
        return 0
    fi
    current_version_datetime=$(date -r $geoip_path)
    url="https://api.github.com/repos/Dreamacro/maxmind-geoip/releases/latest"
    latest_version_datetime=$(trim_quotes "$(curl -sSL $url | jq '.published_at')")
    if [[ $current_version_datetime < $latest_version_datetime ]]; then
        return 0
    else
        return 1
    fi
}

get_geoip() {
    printf "downloading geoip ... \n"
    url="${baseurl}/Dreamacro/maxmind-geoip/releases/latest/download/${geoip_name}"
    curl -#SL $url -o $geoip_update_path_path
}

update_geoip() {
    if [[ -f $geoip_update_path_path ]]; then
        printf "updating geoip ... "
        mv -f $geoip_update_path_path $config_dir
        if [[ $? ]]; then
            printf "success\n"
        fi
    fi
}

test_downloaded_update() {
    if [[ -f $program_update_path ]] || [[ -d $dashboard_update_path ]] || [[ -f $geoip_update_path_path ]]; then
        return 0
    else
        return 1
    fi
}

update() {
    test_command jq
    test_command gzip
    test_command unzip

    printf "checking clash update ... "
    latest_version=$(test_clash_update)
    if [[ -n $latest_version ]]; then
        printf "success\n"
        get_clash
    else
        printf "alreay up to date\n"
    fi

    printf "checking dashboard update ... "
    if [[ test_dashboard_update ]]; then
        printf "success\n"
        get_dashboard
    else
        printf "alreay up to date\n"
    fi

    printf "checking geoip update ... "
    if [[ test_geoip_update_path ]]; then
        printf "success\n"
        get_geoip
    else
        printf "alreay up to date\n"
    fi

    if [[ test_downloaded_update ]]; then
        stop_clash
        update_clash
        update_dashboard
        update_geoip
    fi
}

get_config() {
    if [[ -z $1 ]]; then
        echo "usage: clashc get file.txt"
        return 1
    fi
    if [[ ! -f $1 ]]; then
        echo "$1 not exists"
        return 1
    fi

    abs_path=$(realpath $1)
    basename=$(basename $abs_path .txt)
    target_dir=$(dirname $abs_path)
    target_path=${target_dir}/${basename}.yaml
    url=$(head 1 $abs_path)
    url=$(strip_all "$url" "[[:space:]]")

    if [[ $url == http* ]]; then
        printf "downloading config ... "
        curl -sSL $url -o $target_path
        if [[ $? ]]; then
            printf "success\n"
            printf "save as ${target_path}\n"
        fi
    else
        printf "invalid url\n"
    fi
}

case $1 in
    "start")
        if [[ ! -f $program_path ]]; then
            update
        fi
        start_clash
    ;;
    "stop")
        stop_clash
    ;;
    "status")
        get_status
    ;;
    "set")
        set_config $2
    ;;
    "update")
        update
    ;;
    "get")
        get_config $2
    ;;
    *)
        echo "usage: clashc start|stop|update|set|get"
    ;;
esac
