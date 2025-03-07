#!/usr/bin/bash
## ================================================================================
##  Gradle-DL
## Copyright (c) 2024-2025 Mattsoft/PoiXson
## <https://mattsoft.net> <https://poixson.com>
## Released under the AGPL 3.0 + ADD-PXN-V1
##
## Description: Downloads and prepares gradle files
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
# gradle-dl.sh
XBUILD_VERSION="{{{VERSION}}}"



echo
SELF="$0"
source  "/usr/bin/pxn/scripts/common.sh"         || exit 1
source  "/usr/bin/pxn/scripts/gradle-common.sh"  || exit 1



# only as root
if [[ $EUID -ne 0 ]]; then
	failure "Run this script as root"
	echo " > sudo $0 $@"
	failure ; exit 1
fi



function DisplayHelp() {
	echo -e "${COLOR_BROWN}Usage:${COLOR_RESET}"
	echo    "  $SELF [options]"
	echo
	echo -e "${COLOR_BROWN}Options:${COLOR_RESET}"
	echo -e "  ${COLOR_GREEN}-d, --dl, --download${COLOR_RESET}      Download Gradle"
	echo -e "  ${COLOR_GREEN}-f, --force${COLOR_RESET}               Force downloading Gradle; replace if already existing"
	echo -e "  ${COLOR_GREEN}-l, --list${COLOR_RESET}                List the currently installed Gradle versions"
	echo
	echo -e "  ${COLOR_GREEN}-V, --gradle-version=<V>${COLOR_RESET}  Gradle version to use (current, nightly, release-nightly)"
	echo
	echo -e "  ${COLOR_GREEN}-V, --version${COLOR_RESET}             Display the version"
	echo -e "  ${COLOR_GREEN}-h, --help${COLOR_RESET}                Display this help message and exit"
	echo
	exit 1
}

function DisplayVersion() {
	echo -e "${COLOR_BROWN}xBuild${COLOR_RESET} ${COLOR_GREEN}$XBUILD_VERSION${COLOR_RESET}"
	echo
}



# ----------------------------------------



DO_DOWNLOAD=$NO
DO_FORCE=$NO

FORCE_GRADLE_VERSION=""



# ----------------------------------------
# parse args



if [[ $# -eq 0 ]]; then
	DisplayHelp $NO
	exit 1
fi
while [ $# -gt 0 ]; do
	case "$1" in

	-d|--dl|--download) DO_DOWNLOAD=$YES ;;
	-f|--force)         DO_FORCE=$YES    ;;

	-l|--list)
		\ls -1  /var/lib/gradle/  || exit 1
		echo
		exit 0
	;;

	-V|--gradle-version|--gradleversion)
		if [[ -z $2 ]] || [[ "$2" == "-"* ]]; then
			failure "--name flag requires a value"
			failure ; DisplayHelp $NO ; exit 1
		fi
		\shift
		if [[ "$1" = *" "* ]]; then
			failure "--gradle-version flag cannot contain any spaces"
			failure ; exit 1
		fi
		FORCE_GRADLE_VERSION="$1"
	;;
	--gradle-version=*|--gradleversion=*)
		VERS="${1#*=}"
		if [[ -z $VERS ]]; then
			failure "--gradle-version flag requires a value"
			failure ; DisplayHelp $NO ; exit 1
		fi
		if [[ "$VERS" = *" "* ]]; then
			failure "--gradle-version flag cannot contain any spaces"
			failure ; exit 1
		fi
		FORCE_GRADLE_VERSION="$VERS"
	;;

	-v|--verbose)           VERBOSE=$YES                    ;;
	-q|--quiet)             QUIET=$YES                      ;;
	--color|--colors)       NO_COLORS=$NO  ; enable_colors  ;;
	--no-color|--no-colors) NO_COLORS=$YES ; disable_colors ;;
	-V|--version)           DisplayVersion   ; exit 1       ;;
	-h|--help)              DisplayHelp $YES ; exit 1       ;;

	-*)
		failure "Unknown flag: $1"
		failure ; DisplayHelp $NO ; exit 1
	;;
	*)
		failure "Unknown argument: $1"
		failure ; DisplayHelp $NO ; exit 1
	;;

	esac
	\shift
done



# create /var/lib/gradle
if [[ ! -d /var/lib/gradle ]]; then
	echo_cmd "mkdir /var/lib/gradle"
	\mkdir -v  /var/lib/gradle  || exit 1
fi



FetchGradleVersion  "$FORCE_GRADLE_VERSION"

# download gradle
if [[ $DO_DOWNLOAD -eq $YES ]]; then
	DownloadGradle
	\alternatives --install  /usr/bin/gradle  gradle  \
		"/var/lib/gradle/gradle-${GRADLE_VERSION}/bin/gradle"  99  \
			|| exit 1
fi



if [[ -e "/var/lib/gradle/gradle-$GRADLE_VERSION" ]]; then
	echo
	echo -e " ${COLOR_GREEN}Finished downloading Gradle $GRADLE_VERSION${COLOR_RESET}"
	echo
else
	failure "Failed to download Gradle $GRADLE_VERSION"
	failure ; exit 1
fi
