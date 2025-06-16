#!/usr/bin/bash

if [[ -z $1 ]]; then
	echo "Argument is required"
	exit 1
fi

\pushd  "$1/"  >/dev/null || exit 1
	\protoc  \
		--go_out=paths=source_relative:.       \
		--go-grpc_out=paths=source_relative:.  \
		--proto_path=.                         \
		--proto_path=/usr/include              \
		"$1.proto"  || exit 1
popd >/dev/null
