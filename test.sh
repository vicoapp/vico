#!/bin/sh
if test -n "$1"; then
	arg=$1
	if test -n "$2"; then
		arg="$arg/$2"
	fi
	export OTHER_TEST_FLAGS="-SenTest $arg"
fi
xcodebuild -configuration Debug -target ViltvodleTests
