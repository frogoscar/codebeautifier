#! /usr/bin/env bash

if [ ! -z $1 ]; then
	CB=$1
else
	CB=$(which codebeautifier)
fi

if [ -z $CB ]; then
	echo "Code beautifier not found."
	exit 1
fi
if [ ! -e $CB ]; then
	echo "Code beautifier is not executable."
	exit 1
fi

expect_ok() {
	msg=$1
	cmd=$2
	
	echo -n "$msg... "
	echo "RUNNING: $cmd ($msg)" >> unittest.log
	if ! $cmd >>unittest.log 2>&1; then
		echo "Failed"
		echo "Failure ($cmd)" >> unittest.log
		exit 1
	else
		echo "Done"
	fi
}

expect_nok() {
	msg=$1
	cmd=$2
	
	echo -n "$msg... "
	echo "RUNNING: $cmd ($msg)" >> unittest.log
	if $cmd >>unittest.log 2>&1; then
		echo "Failed"
		echo "Failure ($cmd)" >> unittest.log
		exit 1
	else
		echo "Done"
	fi
}

rm -f unittest.log
expect_ok "Python correctly formed" "$CB check -S tests/python_file.py"

expect_nok "Python malformed" "$CB check -S tests/python_file_fail.py"
cp tests/python_file_fail.py tests/python_file_fixed.py
expect_ok "Python, format malformed source" "$CB format tests/python_file_fixed.py"
expect_ok "Python, check fixed source" "$CB check -S tests/python_file_fixed.py"

expect_ok "Python, shebang correctly formed 1" "$CB check -S tests/python_shebang_ok_1"
expect_ok "Python, shebang correctly formed 2" "$CB check -S tests/python_shebang_ok_2"
expect_ok "Python, shebang correctly formed 3" "$CB check -S tests/python_shebang_ok_3"

# Expect ok but with a warning about file format which is not recognized. For now we just check the exit code.
expect_nok "Python, shebang malformed 1" "$CB check -S tests/python_shebang_fail_1"
expect_nok "Python, shebang malformed 2" "$CB check -S tests/python_shebang_fail_2"
expect_nok "Python, shebang malformed 3" "$CB check -S tests/python_shebang_fail_3"

expect_ok "C++ correctly formed" "$CB check -S tests/file.cpp"
expect_nok "C++ malformed" "$CB check -S tests/file_fail_1.cpp"
cp tests/file_fail_1.cpp tests/file_fixed_1.cpp
expect_ok "Format C++ malformed" "$CB format tests/file_fixed_1.cpp"
expect_ok "Check C++ formatted" "$CB check -S tests/file_fixed_1.cpp"

expect_ok "Java correctly formed" "$CB check -S tests/JavaOk.java"
expect_nok "Java malformed" "$CB check -S tests/JavaFail.java"
