
sudo_sponge() {
    local out=${1:-/dev/stdout}
    _sudo awk -v o="${out}" '
        {
            b = (NR > 1 ? b""ORS""$0 : $0);
        }
        END{
            print b > o;
        }'
}

if [ $(id -u) -eq 0 ]; then
    _sudo() {
        "$@"
    }
else
    if ! which sudo > /dev/null 2>&1; then
        print_critical "In user mode, sudo with suitable system rights is required"
    fi
    _sudo() {
        sudo "$@"
    }
fi

write_daemon_json() {
    bashopts_process_option -n CITBX_DOCKER_DNS_LIST -r

    # Setup docker0 bridge with:
    # - NET: 192.168.255.0/24 (by default)
    # - DNS: Use system dns instead of Google one
    _sudo mkdir -p /etc/docker
    if ! jq '' /etc/docker/daemon.json > /dev/null 2>&1; then
        if [ -f /etc/docker/daemon.json ]; then
            _sudo mv /etc/docker/daemon.json{,.bak}
            print_warning "Invalid file /etc/docker/daemon.json, moving it to /etc/docker/daemon.json.bak"
        fi
        _sudo bash -c 'echo {} > /etc/docker/daemon.json'
    fi
    for dns in $CITBX_DOCKER_DNS_LIST; do
        if [ -n "$dnslist" ]; then
            dnslist="$dnslist, \"$dns\""
        else
            dnslist="\"$dns\""
        fi
    done

    _sudo cat /etc/docker/daemon.json |
    jq '. + {
        "bip": "'"$CITBX_DOCKER_BIP"'",
        "fixed-cidr": "'"$CITBX_DOCKER_FIXED_CIDR"'",
        "dns": '"$(bashopts_dump_array "string" "${CITBX_DOCKER_DNS_LIST[@]}")"',
        "storage-driver": "'"$CITBX_DOCKER_STORAGE_DRIVER"'"
    }' | sudo_sponge /etc/docker/daemon.json
}

install_ci_toolbox() {
    curl -ksL https://gitlab.com/ercom/citbx4gitlab/raw/master/tools/gitlab-ci/citbx4gitlab/bashcomp \
        | sed 's/\bcitbx4gitlab\b/'"$CITBX_TOOLBOX_NAME"'/' \
        | sudo_sponge /etc/bash_completion.d/$CITBX_TOOLBOX_NAME
    _sudo curl -ksLo /usr/local/bin/$CITBX_TOOLBOX_NAME https://gitlab.com/ercom/citbx4gitlab/raw/master/tools/gitlab-ci/citbx4gitlab/citbx4gitlab
    _sudo chmod +x /usr/local/bin/$CITBX_TOOLBOX_NAME
}
