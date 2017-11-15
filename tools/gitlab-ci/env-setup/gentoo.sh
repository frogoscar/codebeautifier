. $CITBX_ABS_DIR/env-setup/common.sh

INSTALL_PKGS=()

if setup_component_enabled base-pkgs; then
    for pkg in app-emulation/docker sys-apps/gawk dev-python/pyyaml app-misc/jq; do
        if ! equery -q list $pkg > /dev/null; then
            INSTALL_PKGS+=($pkg)
        fi
    done
fi
if setup_component_enabled git-lfs \
    && [ "$CITBX_GIT_LFS_SUPPORT_ENABLED" == "true" ]; then
    if ! equery -q list dev-vcs/git-lfs > /dev/null; then
        INSTALL_PKGS+=(dev-vcs/git-lfs)
    fi
    INSTALL_PKGS+=(git-lfs)
fi
if [ "${#INSTALL_PKGS[@]}" -gt 0 ]; then
    print_info "Installing packages..."
    _sudo emerge -av "${INSTALL_PKGS[@]}"
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
    if grep -q '^DOCKER_OPTS=.*' /etc/conf.d/docker \
        && ! grep -q '^DOCKER_OPTS=""$' /etc/conf.d/docker; then
        _sudo sed -i 's/^DOCKER_OPTS=.*$/DOCKER_OPTS=""/g' /etc/conf.d/docker
    fi
    _sudo ip link del docker0 2>/dev/null || true
    _sudo /etc/init.d/docker restart
fi

if setup_component_enabled ci-toolbox; then
    print_info "Installing the CI toolbox $CITBX_TOOLBOX_NAME..."
    install_ci_toolbox
fi
