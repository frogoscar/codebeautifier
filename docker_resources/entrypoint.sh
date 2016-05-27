#! /usr/bin/env sh

usage() {
	echo "Usage:"
	echo "docker run -it -v <path_to_project>:/var/input ercom/codebeautifier:latest [check|format] <filename>"
	echo "where:"
	echo "   path_to_project: path to your project sources"
	echo "   filename: the file to be checked (path relative to your project)"
	echo "See code beatifier help to look at advanced options bellow:"
	/usr/bin/codebeautifier --help
}

echo "0:$0 1:$1 2:$2"

if [ x"$1" = x"--help" ]; then
	usage
	exit 0
fi

if [ x"$1" = x"unittest" ]; then
	cd /opt
	if ! /usr/bin/unittest; then
		echo "Unit test failed !"
		cat /opt/unittest.log
		exit 1
	else
		exit 0
	fi
fi

if [ x"$1" != x"check" -a x"$1" != x"format" ]; then
	echo "Unknow command"
	usage
	exit 1
fi

if [ ! -d /var/input ]; then
	echo "Please mount the project path as a volume."
	usage
	exit 1
fi

/usr/bin/codebeautifier $1 /var/input/$2
exit $?
