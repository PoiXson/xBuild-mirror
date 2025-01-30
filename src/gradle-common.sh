#!/usr/bin/bash
## ================================================================================
##  Gradle-Common
## Copyright (c) 2024-2025 Mattsoft/PoiXson
## <https://mattsoft.net> <https://poixson.com>
## Released under the AGPL 3.0 + ADD-PXN-V1
##
## Description: Common functions for Gradle
##
## ================================================================================
##
## This program is free software: you can redistribute it and/or modify it under
## the terms of the GNU Affero General Public License + ADD-PXN-V1 as published by
## the Free Software Foundation, either version 3 of the License, or (at your
## option) any later version, with the addition of ADD-PXN-V1.
##
## This program is distributed in the hope that it will be useful, but WITHOUT ANY
## WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
## PARTICULAR PURPOSE.
##
## See the GNU Affero General Public License for more details
## <http://www.gnu.org/licenses/agpl-3.0.en.html> and Addendum ADD-PXN-V1
## <https://dl.poixson.com/ADD-PXN-V1.txt>
##
## **ADD-PXN-V1 - Addendum to the GNU Affero General Public License (AGPL)**
## This Addendum is an integral part of the GNU Affero General Public License
## (AGPL) under which this software is licensed. By using, modifying, or
## distributing this software, you agree to the following additional terms:
##
## 1. **Source Code Availability:** Any distribution of the software, including
##    modified versions, must include the complete corresponding source code. This
##    includes all modifications made to the original source code.
## 2. **Free of Charge and Accessible:** The source code and any modifications to
##    the source code must be made available to all with reasonable access to the
##    internet, free of charge. No fees may be charged for access to the source
##    code or for the distribution of the software, whether in its original or
##    modified form. The source code must be accessible in a manner that allows
##    users to easily obtain, view, and modify it. This can be achieved by
##    providing a link to a publicly accessible repository (e.g., GitHub, GitLab)
##    or by including the source code directly with the distributed software.
## 3. **Documentation of Changes:** When distributing modified versions of the
##    software, you must provide clear documentation of the changes made to the
##    original source code. This documentation should be included with the source
##    code, and should be easily accessible to users.
## 4. **No Additional Restrictions:** You may not impose any additional
##    restrictions on the rights granted by the AGPL or this Addendum. All
##    recipients of the software must have the same rights to use, modify, and
##    distribute the software as granted under the AGPL and this Addendum.
## 5. **Acceptance of Terms:** By using, modifying, or distributing this software,
##    you acknowledge that you have read, understood, and agree to comply with the
##    terms of the AGPL and this Addendum.
## ================================================================================
# gradle-common.sh



GRADLE_VERSION=""
GRADLE_DL_URL=""



function FetchGradleVersion() {
	local ARG_VERSION="$1"
	[[ -z $ARG_VERSION ]] && ARG_VERSION="current"
	local GRADLE_VERSION_DATA=""
	local VERSION_URL=""
	local RESULT=$( echo "$ARG_VERSION" | grep [0-9] )
	if [[ -z $result ]]; then
		VERSION_URL="https://services.gradle.org/versions/$ARG_VERSION"
		GRADLE_VERSION_DATA=$( curl -sSL "$VERSION_URL" )
	else
		VERSION_URL="https://services.gradle.org/versions/all"
		GRADLE_VERSION_DATA=$( \
			\curl -sSL "$VERSION_URL"  \
				| \sed ':a;N;$!ba;s/\n//g'                  \
				| \sed 's/\(},\)\? *{/\n/g'                 \
				| \grep "\"version\" *: *\"$ARG_VERSION\""  \
			)
	fi
	if [[ "$GRADLE_VERSION_DATA" == "<"* ]]; then
		failure "Failed to fetch gradle versions json; got html"
		failure ; exit 1
	fi
	GRADLE_VERSION=$( echo $GRADLE_VERSION_DATA | \sed "s/.*\"version\" *: *\"\([^\"]*\)\".*/\1/" )
	GRADLE_DL_URL=$( echo $GRADLE_VERSION_DATA | \sed "s/.*\"downloadUrl\" *: *\"\([^\"]*\)\".*/\1/" | \sed 's/\\\\//g' )
	if [[ -z $GRADLE_VERSION ]]; then
		failure "Invalid gradle version: $ARG_VERSION"
		failure ; exit 1
	fi
	if [[ -z $GRADLE_DL_URL ]]; then
		failure "Gradle $GRADLE_VERSION <${ARG_VERSION}> download not found"
		failure ; exit 1
	fi
}



function DownloadGradle() {
	# check existing
	if [[ $DO_FORCE -ne $YES ]] \
	&& [[ -e "/var/lib/gradle/gradle-$GRADLE_VERSION" ]]; then
		echo "Found existing: /var/lib/gradle/gradle-$GRADLE_VERSION"
		echo ; exit 11
	fi
	# download gradle
	info "Downloading Gradle $GRADLE_VERSION from $GRADLE_DL_URL"
	echo
	local GRADLE_ZIP=$( mktemp )
	if [[ -z $GRADLE_ZIP ]]; then
		failure "Failed to create a temp file for gradle download"
		failure ; exit 1
	fi
	echo_cmd "curl -L  $GRADLE_DL_URL  -o $PWD/$GRADLE_ZIP"
	\curl -L  "$GRADLE_DL_URL"  -o "$GRADLE_ZIP"  || exit 1
	echo
	# extract
	info "Extracting Gradle.."
	echo
	echo_cmd "unzip -uo -d /var/lib/gradle/  $GRADLE_ZIP"
	\unzip -o  -d "/var/lib/gradle/"  "$GRADLE_ZIP"  || exit 1
	echo
	# remove temp files
	if [[ ! -z $GRADLE_ZIP ]] \
	&& [[ -f "$GRADLE_ZIP" ]]; then
		echo_cmd "rm -fv  $GRADLE_ZIP"
		\rm -fv  "$GRADLE_ZIP"
	fi
}
