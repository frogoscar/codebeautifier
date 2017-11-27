#!/bin/bash -e
# citbx4gitlab: CI toolbox for Gitlab
# Copyright (C) 2017 ERCOM - Emeric Verschuur <emeric@mbedsys.org>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

CITBX_VERSION=3.2.0

# display a message
print_log() {
    local level=$1;
    shift || print_log C "Usage print_log <level> message"
    case "${level,,}" in
        c|critical)
            >&2 printf "\e[91m[CRIT] %s\e[0m\n" "$@"
            exit 1
            ;;
        e|error)
            >&2 printf "\e[91m[ERRO] %s\e[0m\n" "$@"
            ;;
        w|warning)
            >&2 printf "\e[93m[WARN] %s\e[0m\n" "$@"
            ;;
        n|note)
            printf "[NOTE] %s\n" "$@"
            ;;
        i|info)
            printf "\e[92m[INFO] %s\e[0m\n" "$@"
            ;;
        *)
            print_log C "Invalid log level: $level"
            ;;
    esac
}

# Print an error message and exit with error status 1
print_critical() {
    >&2 printf "\e[91m[CRIT] %s\e[0m\n" "$@"
    exit 1
}

# Print an error message
print_error() {
    >&2 printf "\e[91m[ERRO] %s\e[0m\n" "$@"
}

# Print a warning message
print_warning() {
    >&2 printf "\e[93m[WARN] %s\e[0m\n" "$@"
}

# Print a note message
print_note() {
    printf "[NOTE] %s\n" "$@"
}

# Pring an info message
print_info() {
    printf "\e[92m[INFO] %s\e[0m\n" "$@"
}

# Get the real core number
ncore() {
    lscpu | awk -F ':' '
        /^Core\(s\) per socket/ {
            nc=$2;
        }
        /^Socket\(s\)/ {
            ns=$2;
        }
        END {
            print nc*ns;
        }'
}

# Check bash
if [ ! "${BASH_VERSINFO[0]}" -ge 4 ]; then
    print_critical "This script needs BASH version 4 or greater"
fi

# ci-tools base directory bath
CITBX_ABS_DIR=$(dirname $(readlink -f $0))
# Extract project specific values
if [ -f $CITBX_ABS_DIR/citbx.properties ]; then
    . $CITBX_ABS_DIR/citbx.properties
fi
if [ -z "$CI_PROJECT_DIR" ]; then
    # Find the project directory
    CI_PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -z "$CI_PROJECT_DIR" ]; then
        print_critical "Unable to find the project root directory"
    fi
fi
# Current job script relative directory path
CITBX_DIR=${CITBX_ABS_DIR#${CI_PROJECT_DIR}/}

citbx_register_handler() {
    local list="citbx_job_stage_${2}"
    local func="${1}_${2}"
    if [[ "$(type -t $func)" != "function" ]]; then
        return 0
    fi
    local pattern='\b'"$func"'\b'
    if [[ "${!list}" =~ $pattern ]]; then
        return 0
    fi
    case "$2" in
        define|setup|before|main)
            eval "${list}=\"${!list} $func\""
            ;;
        after)
            eval "${list}=\"$func ${!list}\""
            ;;
        *)
            print_critical "Use: citbx_register_handler <prefix> define|setup|before|main|after"
            ;;
    esac
}

declare -A CITBX_USE_LIST
# Add module in the use list
citbx_use() {
    local module=$1
    if [ -z "$module" ]; then
        print_critical "Usage: citbx_use <module_name>"
    fi
    if [ "${CITBX_USE_LIST[$module]}" == "true" ]; then
        return 0
    fi
    if [ ! -f "$CITBX_ABS_DIR/modules/${module}.sh" ]; then
        print_critical "Module ${module} not found!"
    fi
    . $CITBX_ABS_DIR/modules/${module}.sh
    CITBX_USE_LIST[$module]="true"
    for h in $module_handler_list; do
        citbx_register_handler "citbx_module_${module}" $h
    done
}

citbx_local() {
    if [ -f $CITBX_ABS_DIR/citbx.local ]; then
        . $CITBX_ABS_DIR/citbx.local
    fi
}

# Job end handler
citbx_job_finish() {
    local CITBX_EXIT_CODE=$?
    if [ "$CITBX_JOB_FINISH_CALLED" != "true" ]; then
        CITBX_JOB_FINISH_CALLED="true"
    else
        return 0
    fi
    for hook in $citbx_job_stage_after; do
        $citbx_before_script
        cd $CI_PROJECT_DIR
        $hook $CITBX_EXIT_CODE
        $citbx_after_script
    done
    if [ "$CITBX_EXIT_CODE" == "0" ]; then
        print_info "CI job success!"
    else
        print_error "CI job failure with exit code $CITBX_EXIT_CODE"
    fi
    print_note "Job execution time: $(date +"%H hour(s) %M minute(s) and %S second(s)" -ud @$(($(date +%s) - $CITBX_JOB_START_TIME)))"
}

# If running inside the suitable runner / on gitlab runner
if [ "$GITLAB_CI" == "true" ]; then
    # Load job
    citbx_local
    CITBX_JOB_RUN_FILE_NAME=${CITBX_JOB_RUN_FILE_NAME:-"$CI_JOB_NAME.sh"}
    module_handler_list="before after"
    CITBX_JOB_RUN_FILE_PATH="$CITBX_ABS_DIR/run.d/${CITBX_JOB_RUN_FILE_NAME}"
    if [ ! -f "$CITBX_JOB_RUN_FILE_PATH" ]; then
        print_critical "Job definition file $CITBX_JOB_RUN_FILE_PATH not found"
    fi
    . "$CITBX_JOB_RUN_FILE_PATH"
    citbx_register_handler "job" "main"
    citbx_register_handler "job" "after"
    if [ "$CITBX_DEBUG_SCRIPT_ENABLED" == "true" ]; then
        citbx_before_script="set -x"
        citbx_after_script="set +x"
    else
        citbx_before_script=""
        citbx_after_script=""
    fi
    for hook in $citbx_job_stage_before; do
        $citbx_before_script
        cd $CI_PROJECT_DIR
        $hook
        $citbx_after_script
    done
    CITBX_JOB_START_TIME=$(date +%s)
    trap citbx_job_finish EXIT SIGINT SIGTERM
    print_info "CI job begin"
    if [ -z "$citbx_job_stage_main" ]; then
        print_critical "Funtion job_main not found in the file $CITBX_JOB_RUN_FILE_PATH"
    fi
    for hook in $citbx_job_stage_main; do
        $citbx_before_script
        cd $CI_PROJECT_DIR
        $hook
        $citbx_after_script
    done
    exit 0
fi

# Force use citbx_run_ext_job to run another job
if [ "$CITBX" == "true" ]; then
    print_critical "You cannot call another CI script (i.e. other external job) into a CI script" \
        "Please use citbx_run_ext_job instead"
fi
export CITBX="true"

# YAML to JSON convertion
yaml2json() {
    cat "$@" | python -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout)'
}

# Collect the missing binaries and other dependencies
CITBX_MISSING_PKGS=()
for bin in gawk jq dockerd; do
    if ! which $bin > /dev/null 2>&1; then
        CITBX_MISSING_PKGS+=($bin)
    fi
done
if [ "$(echo "true" | yaml2json 2>/dev/null)" != "true" ]; then
    CITBX_MISSING_PKGS+=("python-yaml")
fi
if [ "$CITBX_GIT_LFS_SUPPORT_ENABLED" == "true" ] && ! git lfs version > /dev/null 2>&1; then
    CITBX_MISSING_PKGS+=("git-lfs")
fi

if [ ! -f $CI_PROJECT_DIR/.gitlab-ci.yml ]; then
    print_critical "$CI_PROJECT_DIR/.gitlab-ci.yml file not found"
fi
if [ ${#CITBX_MISSING_PKGS[@]} -eq 0 ]; then
    GITLAB_CI_JSON=$(yaml2json $CI_PROJECT_DIR/.gitlab-ci.yml)
else
    print_warning "System setup required (command '$CITBX_TOOL_NAME setup')"
fi

gitlab_ci_query() {
    jq "$@" <<< "$GITLAB_CI_JSON"
}

# Check environment and run setup
citbx_check_env() {
    local os_id
    if [ "$1" != "true" ]; then
        if [ ${#CITBX_MISSING_PKGS[@]} -gt 0 ]; then
            print_critical "System setup needed (binary(ies)/component(s) '${CITBX_MISSING_PKGS[*]}' missing): please execute '$CITBX_TOOL_NAME setup' first"
        fi
        return 0
    fi
    if which lsb_release > /dev/null 2>&1; then
        os_id=$(lsb_release --id --short)
    elif [ -f /etc/os-release ]; then
        eval "$(sed 's/^NAME=/os_id=/;tx;d;:x' /etc/os-release)"
    fi
    local setupsh="$CITBX_ABS_DIR/env-setup/${os_id,,}.sh"
    if [ ! -f "$setupsh" ]; then
        print_critical "OS variant '$os_id' not supported (missing $setupsh)"
    fi
    check_dns() {
        case "$1" in
            ::1|127.*)
                print_error "Local $1 DNS server cannot be used with docker containers"
                return 1
                ;;
            *)
                echo "$1"
                ;;
        esac
    }
    setup_component_enabled() {
        local pattern='\b'"$1"'\b'
        if [[ "${CITBX_SETUP_COMPONENT[*]}" =~ $pattern ]]; then
            return 0
        fi
        return 1
    }
    bashopts_process_option -n CITBX_DOCKER_DNS_LIST -r -k check_dns
    . "$setupsh"
    print_info "System setup complete" "On a first install, a system reboot may be necessary"
    exit 0
}

# Get the job list
citbx_job_list() {
    local prefix outcmd arg
    prefix='[^\.]'
    outcmd='print $0'
    if ! arglist=$(getopt -o "f:p:s" -n "citbx_list " -- "$@"); then
        print_critical "Usage citbx_list: [options]" \
            "        -f <val>  Output gawk command (default: 'print $0')" \
            "        -s        Suffix list (same as -f 'printf(\" %s\", f[1]);')" \
            "        -p <val>  Prefix string"
    fi
    eval set -- "$arglist";
    while true; do
        arg=$1
        shift
        case "$arg" in
            -f) outcmd=$1;  shift;;
            -p) prefix=$1;  shift;;
            -s) outcmd='printf(" %s", f[1]);';;
            --) break;;
            *)  print_critical "Fatal error";;
        esac
    done
    gitlab_ci_query -r 'paths | select(.[-1] == "script") | .[0]' \
        | gawk 'match($0, /^'"$prefix"'(.*)$/, f) {'"$outcmd"'}'
}

declare -A CITBX_SHELL_ENV
# fetch YAML variables
gitlab_ci_variables() {
    local node=$1
    local value
    test -n "$node" \
        || print_critical "Usage: gitlab_ci_variables <node path>"
    local node_type="$(gitlab_ci_query -r "$node | type")"
    case "$node_type" in
        null)
            return 1
            ;;
        object)
            for k in $(gitlab_ci_query -r "$node | keys[]"); do
                if ! [[ "$(gitlab_ci_query -r "${node}.$k | type")" =~ ^(string|number)$ ]]; then
                    print_critical "Invalid $node variable (type=$(gitlab_ci_query -r "${node}.$k | type"): $k)"
                fi
                value=$(
                    eval "$k=$(gitlab_ci_query "${node}.$k")"
                    declare | grep "^$k=" | sed -E 's/^[^=]+=//g'
                )
                case "$k" in
                    CITBX_*|GIT_*|CI_*)
                        eval "export $k=$value"
                esac
                CITBX_SHELL_ENV[$k]=$value
                CITBX_DOCKER_RUN_ARGS+=(-e "$k=$(eval echo "$value")")
            done
            ;;
        *)
            print_critical "Invalid $node type"
            ;;
    esac
}

# put YAML (array or string) node script content indo CITBX_YAML_SCRIPT_ELTS
gitlab_ci_script() {
    local node=$1
    local line
    test -n "$node" \
        || print_critical "Usage: gitlab_ci_script <node path>"
    local script_type="$(gitlab_ci_query -r "$node | type")"
    case "$script_type" in
        null)
            return 1
            ;;
        string)
            CITBX_YAML_SCRIPT_ELTS+=(gitlab_ci_query -r "${node}")
            ;;
        array)
            for i in $(seq 0 $(($(gitlab_ci_query "$node | length")-1))); do
                line=$(gitlab_ci_query -r "${node}[$i]")
                if [ "$(gitlab_ci_query -r "${node}[$i] | type")" != "string" ]; then
                    print_critical "Invalid $node line: $line"
                fi
                CITBX_YAML_SCRIPT_ELTS+=("$line")
            done
            ;;
        *)
            print_critical "Invalid $node type"
            ;;
    esac
}

# Run an other job
citbx_run_ext_job() {
    local job_name=$1
    test -n "$job_name" \
        || print_critical "Usage: citbx_run_ext_job <job name>"
    print_note "Starting job $job_name"
    (
        set -e
        unset CITBX
        unset CITBX_COMMAND
        unset CITBX_JOB_RUN_FILE_NAME
        unset CITBX_GIT_CLEAN
        bashopts_export_opts
        export CI_JOB_NAME=$job_name
        exec $0 "$@"
    )
}

# Export an variable to the job environment
citbx_export() {
    CITBX_ENV_EXPORT_LIST+=("$@")
}

# Add docker run arguments
citbx_docker_run_add_args() {
    CITBX_JOB_DOCKER_RUN_ARGS+=("$@")
}

# Load bashopts
BASHOPTS_FILE_PATH=${BASHOPTS_FILE_PATH:-"$CITBX_ABS_DIR/3rdparty/bashopts.sh"}
if [ ! -f "$BASHOPTS_FILE_PATH" ]; then
    print_critical "Missing requered file $BASHOPTS_FILE_PATH [\$BASHOPTS_FILE_PATH]"
fi
bashopts_log_handler="print_log"
. $BASHOPTS_FILE_PATH
# Enable backtrace dusplay on error
trap 'bashopts_exit_handle' ERR

# Set the setting file path
if [ -z "$CITBX_RC_PATH" ]; then
    CITBX_RC_PATH="/dev/null"
fi

if [ ${#CITBX_MISSING_PKGS[@]} -eq 0 ]; then
    eval "$(citbx_job_list -f 'printf("CITBX_JOB_LIST+=(\"%s\");", $0);')"
fi

CITBX_TOOL_NAME=${CITBX_TOOL_NAME:-$0}

bashopts_setup -n "$(basename $CITBX_TOOL_NAME)" \
    -d "Gitlab-CI job runner tool (version $CITBX_VERSION)" \
    -s "$CITBX_RC_PATH"

if [ "$CITBX_BASHCOMP" == "commands" ]; then
    echo -e "\"help\"\n\"setup\"\n\"update\""
    for j in "${CITBX_JOB_LIST[@]}"; do echo "\"$j\""; done | sort -u
    exit 0
fi

command=$1
shift || true
case "$command" in
    ''|h|help|-h|--help)
        bashopts_tool_usage="$CITBX_TOOL_NAME command [command options] [arguments...]
  => type '$CITBX_TOOL_NAME command -h' to display the contextual help

COMMANDS:
    help      : Display this help
    setup     : Setup the environment
    update    : Update this tool (fetch the last version from https://gitlab.com/ercom/citbx4gitlab)
    ... or a job from the job list

JOBS:
$(for j in "${CITBX_JOB_LIST[@]}"; do echo "    $j"; done | sort -u)"
        bashopts_diplay_help_delayed
        ;;
    setup)
        bashopts_tool_usage="$CITBX_TOOL_NAME $command [arguments...]
  => type '$CITBX_TOOL_NAME help' to display the global help"
        bashopts_declare -n CITBX_SETUP_COMPONENT -l component \
            -t enum -m add -d "Setup only specified components" \
            -e base-pkgs -e docker-cfg -e git-lfs -e ca-certs -e ci-toolbox \
            -x '(base-pkgs docker-cfg git-lfs ca-certs ci-toolbox)'
        check_tool_name() {
            if [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                echo $1
                return 0
            fi
            bashopts_log E "'$1' is not a valid tool name"
            return 1
        }
        bashopts_declare -n CITBX_TOOLBOX_NAME -l toolbox-name \
            -t string -d "CI toolbox name" -k check_tool_name -v ci-toolbox
        bashopts_declare -n CITBX_DOCKER_BIP -l docker-bip -v "$(
            val=$(jq -r '.bip' /etc/docker/daemon.json 2> /dev/null || true)
            echo ${val:-"192.168.255.254/24"}
        )" -t string -d "Local docker network IPV4 host adress"
        bashopts_declare -n CITBX_DOCKER_FIXED_CIDR -l docker-cdir -v "$(
            val=$(jq -r '."fixed-cidr"' /etc/docker/daemon.json 2> /dev/null || true)
            echo ${val:-"192.168.255.0/24"}
        )" -t string -d "Local docker network IPV4 prefix"
        bashopts_declare -n CITBX_DOCKER_DNS_LIST -l docker-dns -m add \
            -x "($(
                if [ "0$(jq -e '.dns | length' /etc/docker/daemon.json 2> /dev/null || true)" -gt 0 ]; then
                    jq -r '.dns[]' /etc/docker/daemon.json 2> /dev/null | tr '\n' ' '
                else
                    RESOLV_CONF_DNS="$(cat /etc/resolv.conf | awk '/^nameserver/ {
                        if ($2 !~ /^127\..*/ && $2 != "::1" ) {
                            printf(" %s", $2);
                        }
                    }' 2> /dev/null || true)"
                    echo "${RESOLV_CONF_DNS:-${CITBX_DOCKER_DEFAULT_DNS[*]}}"
                fi
                ) )" \
            -t string -d "Docker DNS"
        bashopts_declare -n CITBX_DOCKER_STORAGE_DRIVER -l docker-storage-driver -v "$(
            val=$(jq -r '."storage-driver"' /etc/docker/daemon.json 2> /dev/null || true)
            echo ${val:-"overlay2"}
        )" -e 'o|overlay2' -e 'overlay' -e 'a|aufs' -e 'd|devicemapper' -e 'b|btrfs' -e 'z|zfs' \
            -t enum -d "Docker storage driver"
        ;;
    update)
        ;;
    *)
        # Properties check
        CITBX_DEFAULT_JOB_SHELL=${CITBX_DEFAULT_JOB_SHELL:-/bin/sh}
        CITBX_DEFAULT_SERVICE_DOCKER_PRIVILEGED=${CITBX_DEFAULT_SERVICE_DOCKER_PRIVILEGED:-false}
        CITBX_DEFAULT_GIT_LFS_ENABLED=${CITBX_DEFAULT_GIT_LFS_ENABLED:-false}
        # Command check
        pattern='\b'"$command"'\b'
        if ! [[ "${CITBX_JOB_LIST[*]}" =~ $pattern ]]; then
            print_critical "Unreconized command; type '$CITBX_TOOL_NAME help' to display the help"
        fi
        CI_JOB_NAME=$command
        citbx_local
        CITBX_JOB_RUN_FILE_NAME=${CITBX_JOB_RUN_FILE_NAME:-"$CI_JOB_NAME.sh"}
        # Read Image property
        for p in '."'"$CI_JOB_NAME"'"' ''; do
            case "$(gitlab_ci_query -r "$p.image | type")" in
                object)
                    if [ "$(gitlab_ci_query -r "$p.image.name | type")" == "string" ]; then
                        CITBX_DEFAULT_DOCKER_IMAGE=$(gitlab_ci_query -r "$p.image.name")
                        if [ "$(gitlab_ci_query -r "$p.image.entrypoint | type")" == "array" ]; then
                            for i in $(seq 0 $(gitlab_ci_query -r "$p.image.entrypoint | length - 1")); do
                                CITBX_DEFAULT_DOCKER_ENTRYPOINT+=("$(gitlab_ci_query -r "$p.image.entrypoint[$i]")")
                            done
                        fi
                        break
                    fi
                    ;;
                string)
                    CITBX_DEFAULT_DOCKER_IMAGE=$(gitlab_ci_query -r "$p.image")
                    break
                    ;;
                *)
                    ;;
            esac
        done
        # Read the gitlab-ci variables
        gitlab_ci_variables ".\"variables\"" || true
        gitlab_ci_variables ".\"$CI_JOB_NAME\".\"variables\"" || true
        # Define job usage
        bashopts_tool_usage="$CITBX_TOOL_NAME $command [arguments...]
  => type '$CITBX_TOOL_NAME help' to display the global help"
        # Define the generic options
        bashopts_declare -n GIT_SUBMODULE_STRATEGY -l submodule-strategy \
            -d "Git submodule strategy (none, normal or recursive)" -t enum -v "${GIT_SUBMODULE_STRATEGY:-none}" \
            -e 'none' -e 'normal' -e 'recursive'
        bashopts_declare -n CITBX_GIT_CLEAN -l git-clean -o c \
            -d "Perfom a git clean -fdx in the main project and submodules" -t boolean
        if [ "$CITBX_GIT_LFS_SUPPORT_ENABLED" == "true" ]; then
            bashopts_declare -n CITBX_GIT_LFS_ENABLED -l git-lfs -v "$CITBX_DEFAULT_GIT_LFS_ENABLED" \
                -d "Enable git LFS support" -t boolean
        fi
        declare_opts=()
        if [ -n "$DEFAULT_CI_REGISTRY" ]; then
            declare_opts+=(-v "$DEFAULT_CI_REGISTRY")
        fi
        bashopts_declare -n CI_REGISTRY -l docker-registry -d "Docker registry" -t string -s "${declare_opts[@]}"
        unset declare_opts
        bashopts_declare -n CITBX_DOCKER_LOGIN -l docker-login -o l -d "Execute docker login" -t boolean
        bashopts_declare -n CITBX_JOB_EXECUTOR -l job-executor -o e \
            -d "Job executor type (only docker or shell is sypported yet)" -t enum \
            -v "$(test -n "$CITBX_DEFAULT_DOCKER_IMAGE" && echo "docker" || echo "shell" )" \
            -e 's|shell' -e 'd|docker'
        bashopts_declare -n CITBX_DOCKER_IMAGE -l docker-image -d "Docker image name" -t string \
            -x "\"$CITBX_DEFAULT_DOCKER_IMAGE\""
        bashopts_declare -n CITBX_DOCKER_ENTRYPOINT -l docker-entrypoint -d "Docker entrypoint" -t string -m add \
            -x "$(bashopts_get_def CITBX_DEFAULT_DOCKER_ENTRYPOINT)"
        bashopts_declare -n CITBX_UID -l uid -t number \
            -d "Start this script as a specific uid (0 for root)" -v "$(id -u)"
        CITBX_USER_GROUPS=(adm plugdev)
        bashopts_declare -n CITBX_USER_GROUPS -l group -t string -m add \
            -d "User group list"
        bashopts_declare -n CITBX_DEBUG_SCRIPT_ENABLED -o x -l debug-script -t boolean \
            -d "Enable SHELL script debug (set -e)"
        citbx_export CITBX_DEBUG_SCRIPT_ENABLED
        bashopts_declare -n CITBX_RUN_SHELL -o s -l run-shell -t boolean \
            -d "Run a shell instead of run the default command (override CITBX_COMMAND option)"
        bashopts_declare -n CITBX_JOB_SHELL -l shell -t string -v "$CITBX_DEFAULT_JOB_SHELL" \
            -d "Use a specific shell to run the job"
        bashopts_declare -n CITBX_WAIT_FOR_SERVICE_START -l wait-srv-started -t number -v 0 \
            -d "Wait for service start (time in seconds)"
        bashopts_declare -n CITBX_DISABLED_SERVICES -l disable-service -t string \
            -d "Disable a service" -m add
        bashopts_declare -n CITBX_SERVICE_DOCKER_PRIVILEGED -l service-privileged -t boolean \
            -d "Start service docker container in privileged mode" -v "$CITBX_DEFAULT_SERVICE_DOCKER_PRIVILEGED"
        CITBX_DOCKER_USER=${CITBX_DOCKER_USER:-root}

        # Load job 
        module_handler_list="define setup"
        if [ -f "$CITBX_ABS_DIR/run.d/$CITBX_JOB_RUN_FILE_NAME" ]; then
            . "$CITBX_ABS_DIR/run.d/$CITBX_JOB_RUN_FILE_NAME"
            citbx_register_handler "job" "define"
            citbx_register_handler "job" "setup"
        fi
        for hook in $citbx_job_stage_define; do
            cd $CI_PROJECT_DIR
            $hook
        done
        ;;
esac

if [ -n "$CITBX_BASHCOMP" ]; then
    case "$CITBX_BASHCOMP" in
        opts)
            for o in "${bashopts_optprop_short_opt[@]}"; do
                echo "\"-$o\""
            done | sort -u
            for o in "${bashopts_optprop_long_opt[@]}"; do
                echo "\"--$o\""
            done | sort -u
            ;;
        longopts)
            for o in "${bashopts_optprop_long_opt[@]}"; do
                echo "\"--$o\""
            done | sort -u
            ;;
        --docker-image)
            while read -r line; do
                echo "\"$line\""
            done <<< "$(docker images | tail -n +2 \
                | awk '($1 != "<none>" && $2 != "<none>") {print $1":"$2}')"
            ;;
        -*)
            bashopts_get_valid_value_list $CITBX_BASHCOMP
            ;;
    esac
    exit 0
fi

# Parse arguments
bashopts_parse_args "$@"

# Process argument
bashopts_process_opts

# check the environment
citbx_check_env $(test "$command" != "setup" || echo "true")

if [ "$command" == "update" ]; then
    tmpdir=$(mktemp -d)
    version=${bashopts_commands[0]:-"master"}
    print_note "Downloading $version archive from gitlab.com..."
    curl -fSsL https://gitlab.com/ercom/citbx4gitlab/repository/$version/archive.tar.bz2 | tar -C $tmpdir -xj
    srcdir="$tmpdir/$(ls -1 $tmpdir)"
    cp -av $srcdir/tools/gitlab-ci/run.sh $CITBX_ABS_DIR/run.sh
    chmod +x $CITBX_ABS_DIR/run.sh
    mkdir -p $CITBX_ABS_DIR/env-setup
    cp -av $srcdir/tools/gitlab-ci/env-setup/* $CITBX_ABS_DIR/env-setup/
    cp -av $srcdir/tools/gitlab-ci/3rdparty/bashopts.sh $BASHOPTS_FILE_PATH
    rm -rf $tmpdir
    print_info "Update done!"
    exit 0
fi

if [ "$(gitlab_ci_query -r '."'"$CI_JOB_NAME"'".script | type')" == "null" ]; then
    print_critical "Unable to find a valid job with tne name \"$CI_JOB_NAME\" in the .gitlab-ci.yml"
fi

# Login to the registry if needed
if [ -n "$CI_REGISTRY" ] \
    && ( [ -z "$(jq -r '."auths"."'$CI_REGISTRY'"."auth"' $HOME/.docker/config.json 2> /dev/null)" ] \
    || [ "$CITBX_DOCKER_LOGIN" == "true" ] ); then
    print_info "You are not authenticated against the gitlab docker registry" \
        "> Please enter your gitlab user id and password:"
    docker login $CI_REGISTRY
fi

# Compute commands from before_script script and after_script
CITBX_JOB_SCRIPT='
if [ -f $HOME/.bashrc ]; then
    . $HOME/.bashrc
fi
print_info() {
    printf "\e[1m\e[92m%s\e[0m\n" "$@"
}
print_error() {
    printf "\e[1m\e[91m%s\e[0m\n" "$@"
}
print_cmd() {
    printf "\e[1m\e[92m$ %s\e[0m\n" "$@"
}
'$(if [ "$CITBX_DEBUG_SCRIPT_ENABLED" == "true" ]; then
    echo "set -x"
fi)'
__job_exit_code__=0
(
'
gitlab_ci_script ".\"$CI_JOB_NAME\".\"before_script\"" \
    || gitlab_ci_script ".\"before_script\"" \
    || true
gitlab_ci_script ".\"$CI_JOB_NAME\".\"script\"" \
    || print_critical "script \"$CI_JOB_NAME\".script node nor found!"
for line in "${CITBX_YAML_SCRIPT_ELTS[@]}"; do
    CITBX_JOB_SCRIPT="$CITBX_JOB_SCRIPT
print_cmd $(bashopts_get_def line)
$line || exit \$?
"
done
CITBX_JOB_SCRIPT="$CITBX_JOB_SCRIPT"'
) || __job_exit_code__=$?
'
unset CITBX_YAML_SCRIPT_ELTS
if gitlab_ci_script ".\"$CI_JOB_NAME\".\"after_script\"" \
    || gitlab_ci_script ".\"after_script\""; then

    CITBX_JOB_SCRIPT="$CITBX_JOB_SCRIPT"'
print_info "Running after script..."
'
    for line in "${CITBX_YAML_SCRIPT_ELTS[@]}"; do
        CITBX_JOB_SCRIPT="$CITBX_JOB_SCRIPT
print_cmd $(bashopts_get_def line)
$line
"
    done
fi
CITBX_JOB_SCRIPT="$CITBX_JOB_SCRIPT"'
if [ $__job_exit_code__ -eq 0 ]; then
    print_info "Job succeeded"
else
    print_error "ERROR: Job failed: exit code $__job_exit_code__"
fi
exit $__job_exit_code__
'
CITBX_JOB_SCRIPT="'"${CITBX_JOB_SCRIPT//\'/\'\\\'\'}"'"

# Fetch git submodules
if [ "$GIT_SUBMODULE_STRATEGY" != "none" ]; then
    GIT_SUBMODULE_ARGS=()
    case "$GIT_SUBMODULE_STRATEGY" in
        normal)
            ;;
        recursive)
            GIT_SUBMODULE_ARGS+=("--recursive")
            ;;
        *)
            print_critical "Invalid value for GIT_SUBMODULE_STRATEGY: $GIT_SUBMODULE_STRATEGY"
            ;;
    esac
    print_info "Fetching git submodules..."
    git submodule --quiet sync "${GIT_SUBMODULE_ARGS[@]}"
    git submodule update --init "${GIT_SUBMODULE_ARGS[@]}"
fi

if [ "$CITBX_GIT_CLEAN" == "true" ]; then
    git clean -fdx
    if [ "$GIT_SUBMODULE_STRATEGY" != "none" ]; then
        git submodule --quiet foreach "${GIT_SUBMODULE_ARGS[@]}" git clean -fdx
    fi
fi

if [ "$CITBX_GIT_LFS_ENABLED" == "true" ]; then
    git lfs pull
    if [ "$GIT_SUBMODULE_STRATEGY" != "none" ]; then
        git submodule --quiet foreach "${GIT_SUBMODULE_ARGS[@]}" git lfs pull
    fi
fi

# Git SHA1
CI_COMMIT_REF_NAME=${CI_COMMIT_REF_NAME:-$(cd $CI_PROJECT_DIR && git rev-parse --abbrev-ref HEAD)}
CITBX_JOB_DOCKER_RUN_ARGS+=(-e CI_COMMIT_REF_NAME="$CI_COMMIT_REF_NAME")

# Add variable to the environment list
CITBX_ENV_EXPORT_LIST+=(CI_JOB_NAME CI_REGISTRY CI_PROJECT_DIR)

if [ "$CITBX_DEBUG_SCRIPT_ENABLED" == "true" ]; then
    citbx_before_script="set -x"
    citbx_after_script="set +x"
else
    citbx_before_script=""
    citbx_after_script=""
fi

# Run the job setup hooks
for hook in $citbx_job_stage_setup; do
    $citbx_before_script
    $hook
    $citbx_after_script
done

case "$CITBX_JOB_EXECUTOR" in
    shell)
        print_info "Running the job \"$CI_JOB_NAME\" into the shell $CITBX_JOB_SHELL..."
        (
            unset CITBX
            export GITLAB_CI=true
            for e in ${CITBX_ENV_EXPORT_LIST[@]}; do
                export $e
            done
            for e in "${!CITBX_SHELL_ENV[@]}"; do
                eval "export $e=${CITBX_SHELL_ENV[$e]}"
            done
            eval "$CITBX_JOB_SHELL -c $CITBX_JOB_SCRIPT"
        )
        ;;
    docker)
        # Setup docker environment
        if [ -z "$CITBX_DOCKER_IMAGE" ] || [ "$CITBX_DOCKER_IMAGE" == "null" ]; then
            print_critical "No image property found in .gitlab-ci.yml for the job \"$CI_JOB_NAME\""
        fi
        CITBX_ID=$(head -c 8 /dev/urandom | od -t x8 -An | grep -oE '\w+')
        CITBX_DOCKER_PREFIX="citbx-$CITBX_ID"
        if [ -f "$HOME/.docker/config.json" ]; then
            CITBX_JOB_DOCKER_RUN_ARGS+=(-v $HOME/.docker/config.json:/root/.docker/config.json:ro)
        fi
        CITBX_JOB_SHELL=${CITBX_JOB_SHELL:-"/bin/sh"}
        if [ "$CITBX_UID" -eq 0 ] || [ "$CITBX_DOCKER_USER" != "root" ]; then
            if [ "$CITBX_RUN_SHELL" == "true" ]; then
                CITBX_COMMANDS=$CITBX_JOB_SHELL
            else
                CITBX_COMMANDS="$CITBX_JOB_SHELL -c $CITBX_JOB_SCRIPT"
            fi
        else
            if [ -f "$HOME/.docker/config.json" ]; then
                CITBX_JOB_DOCKER_RUN_ARGS+=(-v $HOME/.docker/config.json:$HOME/.docker/config.json:ro)
            fi
            CITBX_COMMANDS="
                useradd -o -u $CITBX_UID -s /bin/sh -d $HOME -M ci-user;
                chown $CITBX_UID:$CITBX_UID $HOME
                for g in ${CITBX_USER_GROUPS[*]}; do usermod -a -G \$g ci-user 2> /dev/null || true; done;
                if [ -f /etc/sudoers ]; then
                    sed -i \"/^ci-user /d\" /etc/sudoers;
                    echo \"ci-user ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers;
                fi;
                echo \"export PATH=\\\"\$PATH\\\"\" >> \"$HOME/.bashrc\"
                su ci-user -s $CITBX_JOB_SHELL $( test "$CITBX_RUN_SHELL" == "true" \
                    || echo "-c $CITBX_JOB_SCRIPT" );
            "
        fi

        if [ -n "$CITBX_DOCKER_USER" ]; then
            CITBX_JOB_DOCKER_RUN_ARGS+=(-u "$CITBX_DOCKER_USER")
        fi

        # Compute the environment variables
        for e in ${CITBX_ENV_EXPORT_LIST[@]}; do
            CITBX_DOCKER_RUN_ARGS+=(-e $e="${!e}")
        done

        CITBX_PRE_COMMANDS=()
        # Entrypoint override management
        if [ -n "$CITBX_DOCKER_ENTRYPOINT" ]; then
            CITBX_JOB_DOCKER_RUN_ARGS+=(--entrypoint "$CITBX_DOCKER_ENTRYPOINT")
            for e in "${CITBX_DOCKER_ENTRYPOINT[@]:1}"; do
                CITBX_PRE_COMMANDS+=("$e")
            done
        fi

        # hook executed on exit
        executor_docker_exit_hook() {
            test -n "$CITBX_DOCKER_PREFIX" || print_critical "Assert: empty CITBX_DOCKER_PREFIX"
            for d in $(docker ps -a --filter "label=$CITBX_DOCKER_PREFIX" -q); do
                docker rm -f $d > /dev/null 2>&1 || true
            done
        }
        trap executor_docker_exit_hook EXIT SIGINT SIGTERM

        wait_before_run_job=0

        # Start a service
        start_docker_service() {
            local args=()
            local image=$1
            local name=$2
            local ip
            local pattern='\b'"$name"'\b'
            if [[ "${CITBX_DISABLED_SERVICES[*]}" =~ $pattern ]]; then
                print_note "Skipping $name service start"
                return 0
            fi
            args+=(--name "$CITBX_DOCKER_PREFIX-$name" --label "$CITBX_DOCKER_PREFIX")
            shift 2
            if [ -n "$1" ]; then
                args+=(--entrypoint "$1")
            fi
            if [ "$CITBX_SERVICE_DOCKER_PRIVILEGED" == "true" ]; then
                args+=(--privileged)
            fi
            shift || true
            print_info "Starting service $name..."
            docker run -d "${args[@]}" "${CITBX_DOCKER_RUN_ARGS[@]}" "$image" "$@"
            # Get container IP and add --add-host options
            ip=$(docker inspect $CITBX_DOCKER_PREFIX-$name | jq -r .[0].NetworkSettings.Networks.bridge.IPAddress)
            CITBX_JOB_DOCKER_RUN_ARGS+=(--add-host "$name:$ip")
            wait_before_run_job=$CITBX_WAIT_FOR_SERVICE_START
        }

        # Start services
        for p in '."'"$CI_JOB_NAME"'"' ''; do
            for s in $([ "$(gitlab_ci_query -r "$p.services | type")" != "array" ] \
                || seq 0 $(($(gitlab_ci_query -r "$p.services | length") - 1))); do
                unset service_image service_alias service_commands
                service_commands=()
                case "$(gitlab_ci_query -r "$p.services[$s] | type")" in
                    object)
                        # Read the service name/image property
                        if [ "$(gitlab_ci_query -r "$p.services[$s].name | type")" == "string" ]; then
                            service_image="$(eval echo "$(gitlab_ci_query "$p.services[$s].name")")"
                        else
                            print_critical "$s: property 'name' not found"
                        fi
                        # Read entrypoint property
                        if [ "$(gitlab_ci_query -r "$p.services[$s].entrypoint | type")" == "array" ]; then
                            for i in $(seq 0 $(gitlab_ci_query -r "$p.services[$s].entrypoint | length - 1")); do
                                service_commands+=("$(eval echo "$(gitlab_ci_query "$p.services[$s].entrypoint[$i]")")")
                            done
                        else
                            # Empty: NO entrypoint
                            service_commands+=("")
                        fi
                        # Read command property
                        if [ "$(gitlab_ci_query -r "$p.services[$s].command | type")" == "array" ]; then
                            for i in $(seq 0 $(gitlab_ci_query -r "$p.services[$s].command | length - 1")); do
                                service_commands+=("$(eval echo "$(gitlab_ci_query "$p.services[$s].command[$i]")")")
                            done
                        fi
                        # Read service alias property
                        if [ "$(gitlab_ci_query -r "$p.services[$s].alias | type")" == "string" ]; then
                            service_alias="$(eval echo "$(gitlab_ci_query "$p.services[$s].alias")")"
                        else
                            service_alias="$(echo "$service_image" | sed -E 's/:[^:\/]+//g' | sed -E 's/[^a-zA-Z0-9\._-]/__/g')"
                        fi
                        # Start service
                        start_docker_service "$service_image" "$service_alias" "${service_commands[@]}"
                        ;;
                    string)
                        service_image="$(eval echo "$(gitlab_ci_query "$p.services[$s]")")"
                        # Start service
                        start_docker_service "$service_image" "$(echo "$service_image" | sed -E 's/:[^:\/]+//g' | sed -E 's/[^a-zA-Z0-9\._-]/__/g')"
                        ;;
                    *)
                        ;;
                esac
            done
        done

        # Wait time
        if [ $wait_before_run_job -gt 0 ]; then
            print_note "Waiting $wait_before_run_job seconds before run the job..."
            sleep $wait_before_run_job
        fi

        # Add project dir mount
        CITBX_JOB_DOCKER_RUN_ARGS+=(-v "$CI_PROJECT_DIR:$CI_PROJECT_DIR:rw")
        GIRDIR_PATH=$(readlink -f $(git rev-parse --git-common-dir))
        if [ "${GIRDIR_PATH#$CI_PROJECT_DIR}" == "$GIRDIR_PATH" ]; then
            # If the git dir is ouside the project dir
            CITBX_JOB_DOCKER_RUN_ARGS+=(-v "$GIRDIR_PATH:$GIRDIR_PATH:rw")
        fi

        if [ "$CITBX_RUN_SHELL" == "true" ]; then
            print_info "Running a shell into the $CITBX_DOCKER_IMAGE docker container..."
            CITBX_JOB_DOCKER_RUN_ARGS+=(-w "$PWD")
        else
            print_info "Running the job \"$CI_JOB_NAME\" into the $CITBX_DOCKER_IMAGE docker container..."
            CITBX_JOB_DOCKER_RUN_ARGS+=(-w "$CI_PROJECT_DIR")
        fi

        # Run the docker
        docker run --rm -ti --name="$CITBX_DOCKER_PREFIX-build" --hostname="$CITBX_DOCKER_PREFIX-build" \
            -e CI=true -e GITLAB_CI=true -v /var/run/docker.sock:/var/run/docker.sock \
            "${CITBX_DOCKER_RUN_ARGS[@]}" --label "$CITBX_DOCKER_PREFIX" "${CITBX_JOB_DOCKER_RUN_ARGS[@]}" \
            -e DOCKER_RUN_EXTRA_ARGS="$(bashopts_get_def bashopts_extra_args)" "${bashopts_extra_args[@]}" \
            $CITBX_DOCKER_IMAGE "${CITBX_PRE_COMMANDS[@]}" $CITBX_JOB_SHELL -c "$CITBX_COMMANDS" \
            || exit $?
        ;;
    *)
        print_critical "Invalid or unsupported '$CITBX_JOB_EXECUTOR' executor"
        ;;
esac
