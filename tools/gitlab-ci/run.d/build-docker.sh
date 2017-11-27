
citbx_use "dockerimg"

job_define() {
    # Set default docker build image name
    test -n "$BUILD_DOCKER_IMAGE_NAME" || BUILD_DOCKER_IMAGE_NAME="docker"
}
