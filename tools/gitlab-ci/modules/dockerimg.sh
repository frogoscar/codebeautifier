
citbx_module_dockerimg_define() {
    local prj_name=$(git remote -v \
        | gawk '
            match($0, /^origin\s.*:[\/]*(.*)\.git\s.*$/, ret) {
                print ret[1];
                exit;
            }
            match($0, /^origin\s.*:[\/]*(.*)\s.*$/, ret) {
                print ret[1];
                exit;
            }')
    local declare_opts=()
    if [ -n "$prj_name" ]; then
        declare_opts+=(-x "\"\$CI_REGISTRY/$prj_name\"")
    fi
    bashopts_declare -n CI_REGISTRY_IMAGE -l image-name -d "Registry image name" -t string "${declare_opts[@]}"
    bashopts_declare -n CI_COMMIT_TAG -l image-tag -d "Image tag" -t string -v "test"
    bashopts_declare -n USE_LOCAL_DOCKER -l use-local-docker -d "Use the local docker instance instead of the dind service" -t boolean
    CITBX_UID=0
    CITBX_JOB_SHELL=${CITBX_JOB_SHELL:-/bin/sh}
    citbx_export CI_REGISTRY_IMAGE CI_COMMIT_TAG
}

citbx_module_dockerimg_setup() {
    bashopts_process_option -n CI_REGISTRY_IMAGE -r
    if [ "$USE_LOCAL_DOCKER" == "true" ]; then
        CITBX_DISABLED_SERVICES+=(docker)
    fi
    pattern='\bdocker\b'
    if [[ "${CITBX_DISABLED_SERVICES[*]}" =~ $pattern ]]; then
        DOCKER_HOST="unix:///var/run/docker.sock"
        citbx_export DOCKER_HOST
    fi
}
