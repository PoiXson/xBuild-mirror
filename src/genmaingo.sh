#!/usr/bin/bash
## ================================================================================
##  GenMainGo
## Copyright (c) 2025 Mattsoft/PoiXson
## <https://mattsoft.net> <https://poixson.com>
## Released under the AGPL 3.0 + ADD-PXN-V1
##
## Description: Generates a main.go file
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
# genmaingo.sh
XBUILD_VERSION="{{{VERSION}}}"



echo
SELF="$0"
source  "/usr/bin/pxn/scripts/common.sh"  || exit 1



function DisplayHelp() {
	echo -e "${COLOR_BROWN}Usage:${COLOR_RESET}"
	echo    "  $SELF [options]"
	echo
	echo -e "${COLOR_BROWN}Options:${COLOR_RESET}"
	echo -e "  ${COLOR_GREEN}-P, --package <name>${COLOR_RESET}      App name to use in the generated main.go file"
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



# parse args
if [[ $# -eq 0 ]]; then
	DisplayHelp $NO
	exit 1
fi
while [ $# -gt 0 ]; do
	case "$1" in

	-P|--package)
		if [[ -z $2 ]] || [[ "$2" == "-"* ]]; then
			failure "--package flag requires a value"
			failure ; DisplayHelp $NO ; exit 1
		fi
		\shift
		if [[ "$1" = *" "* ]]; then
			failure "--package flag cannot contain any spaces"
			failure ; exit 1
		fi
		PackageName="$1"
	;;
	--package=*)
		NAME="${1#*=}"
		if [[ -z $NAME ]]; then
			failure "--package flag requires a value"
			failure ; DisplayHelp $NO ; exit 1
		fi
		if [[ "$NAME" = *" "* ]]; then
			failure "--package flag cannot contain any spaces"
			failure ; exit 1
		fi
		PackageName="$NAME"
	;;

	-V|--version)  DisplayVersion ; exit 1  ;;
	-h|--help)     DisplayHelp    ; exit 1  ;;
	*)
		failure "Unknown argument: $1"
		failure ; DisplayHelp ; exit 1
	;;
	esac
	\shift
done



if [[ -z $PackageName ]]; then
	failure "--package flag is required"
	failure ; DisplayHelp $NO ; exit 1
fi



OUT_FILE="$WDIR/main.go"
echo 'package main;'                  > "$OUT_FILE"
echo                                 >> "$OUT_FILE"
echo "import App \"$PackageName\";"  >> "$OUT_FILE"
echo                                 >> "$OUT_FILE"
echo                                 >> "$OUT_FILE"
echo                                 >> "$OUT_FILE"
echo 'func main() {'                 >> "$OUT_FILE"
echo -e '\tapp := App.New();'        >> "$OUT_FILE"
echo -e '\tapp.Main();'              >> "$OUT_FILE"
echo '}'                             >> "$OUT_FILE"



\grep -v '^[[:space:]]*$' "$OUT_FILE"  || exit 1
echo -e " ${COLOR_GREEN}Generated ${COLOR_BLUE}main.go${COLOR_GREEN} file${COLOR_RESET}"
echo
