. $CITBX_ABS_DIR/env-setup/common.sh

ubuntu_is_installed() {
    if [ "$(dpkg -s "$1" 2>/dev/null | grep -o 'installed' | head -n 1)" == "installed" ]; then
        return 0
    fi
    return 1
}

INSTALL_PKGS=()

if setup_component_enabled base-pkgs; then
    INSTALL_PKGS+=(docker-ce gawk python-yaml jq)

    # remove old versions...
    if ubuntu_is_installed docker.io; then
        print_note "Removing old docker.io package..."
        _sudo /etc/init.d/docker stop
        _sudo apt-get remove -y --allow-change-held-packages docker.io
    fi
    if ubuntu_is_installed docker-engine; then
        print_note "Removing old docker-engine package..."
        _sudo /etc/init.d/docker stop
        _sudo apt-get remove -y --allow-change-held-packages docker-engine
    fi
    _sudo apt-get update
    _sudo apt-get install -y aufs-tools \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common
    if grep -qr 'download.docker.com' /etc/apt/; then
        print_note "Docker apt repository is already present."
    else
        print_note "Adding docker apt repository..."
        # setup - pre install
        # add docker repo
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | _sudo apt-key add -
        _sudo add-apt-repository \
            "deb [arch=amd64] http://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) \
            stable"
        _sudo apt-get update
    fi
fi

if setup_component_enabled git-lfs \
    && [ "$CITBX_GIT_LFS_SUPPORT_ENABLED" == "true" ]; then
    if grep -qr 'git-lfs' /etc/apt/; then
        print_note "GIT LFS apt repository is already present."
    else
        print_note "Adding GIT LFS apt repository..."
        curl -fsSL https://packagecloud.io/github/git-lfs/gpgkey | _sudo apt-key add -
        _sudo add-apt-repository \
            "deb [arch=amd64] http://packagecloud.io/github/git-lfs/ubuntu \
            $(lsb_release -cs) \
            main"
        _sudo apt-get update
    fi
    INSTALL_PKGS+=(git-lfs)
fi

if [ "${#INSTALL_PKGS[@]}" -gt 0 ]; then
    print_info "Installing packages..."
    _sudo apt-get -y install "${INSTALL_PKGS[@]}"
fi

if setup_component_enabled base-pkgs; then
    if [ "${USER}" != "root" ]; then
        _sudo gpasswd -a ${USER} docker
    fi
fi

if setup_component_enabled ca-certs; then
    print_info "Installing CA certificates..."
    # Add user SSL ROOT CA
    if [ -d $CITBX_ABS_DIR/ca-certificates ]; then
        _sudo cp $CITBX_ABS_DIR/ca-certificates/*.crt /usr/local/share/ca-certificates/
        _sudo update-ca-certificates
        _sudo mkdir -p /etc/docker/certs.d
        _sudo cp $CITBX_ABS_DIR/ca-certificates/*.crt /etc/docker/certs.d/
    fi
fi

if setup_component_enabled docker-cfg; then
    print_info "Configuring docker..."

    write_daemon_json

    # Put in comment the docker default options
    if grep -q '^ *\<DOCKER_OPTS\>' /etc/default/docker; then
        _sudo sed '/^ *\<DOCKER_OPTS\>/s/^/#/' -i /etc/default/docker
    fi
    _sudo ip link del docker0 2>/dev/null || true
    _sudo service docker restart
fi

if setup_component_enabled ci-toolbox; then
    print_info "Installing the CI toolbox $CITBX_TOOLBOX_NAME..."
    install_ci_toolbox
fi
