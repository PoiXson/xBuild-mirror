#!/usr/bin/bash
## ================================================================================
##  xImplement
## Copyright (c) 2025 Mattsoft/PoiXson
## <https://mattsoft.net> <https://poixson.com>
## Released under the AGPL 3.0 + ADD-PXN-V1
##
## Description: Copy skel files in a git repo from one place to other places and
##              keep them updated.
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
# ximplement.sh
XBUILD_VERSION="{{{VERSION}}}"



echo
SELF="$0"
source  "/usr/bin/pxn/scripts/common.sh"  || exit 1



function DisplayHelp() {
	local FULL=$1
	echo -e "${COLOR_BROWN}Usage:${COLOR_RESET}"
	echo    "  $SELF [options] [src-path] [dest-path]"
	echo
	echo -e "${COLOR_BROWN}Options:${COLOR_RESET}"
	echo -e "  ${COLOR_GREEN}-D, --dry${COLOR_RESET}                 Dry-run, no changes will be performed by actions"
	echo -e "  ${COLOR_GREEN}-v, --verbose${COLOR_RESET}             Enable debug logs"
	echo -e "  ${COLOR_GREEN}-q, --quiet${COLOR_RESET}               Hide extra logs"
	echo -e "  ${COLOR_GREEN}--colors${COLOR_RESET}                  Enable console colors"
	echo -e "  ${COLOR_GREEN}--no-colors${COLOR_RESET}               Disable console colors"
	echo -e "  ${COLOR_GREEN}-V, --version${COLOR_RESET}             Display the version"
	echo -e "  ${COLOR_GREEN}-h, --help${COLOR_RESET}                Display this help message and exit"
	echo
	exit 1
}

function DisplayVersion() {
	echo -e "${COLOR_BROWN}xBuild${COLOR_RESET} ${COLOR_GREEN}$XBUILD_VERSION${COLOR_RESET}"
	echo
}



# -------------------------------------------------------------------------------



VERBOSE=$NO
QUIET=$NO
NO_COLORS=$NO
IS_DRY=$NO

PROJECT_NAME=""
PROJECT_NAME_LOWER=""
PROJECT_TITLE=""
PROJECT_SERVER=""

PATH_SRC=""
PATH_DST=""

let COUNT_TOTAL=0
let COUNT_COPY=0

HASH_RESULT=""
let COUNT_HEAD_LINES=0
S=""



function CopyIfDiff() {
	if [[ -z $1 ]]; then
		failure "CopyIfDiff() function requires arguments"
		failure ; exit 1
	fi
	local TYPE=""
	case "$1" in
	bin) TYPE="bin" ; \shift ;;
	txt) TYPE="txt" ; \shift ;;
	tag) TYPE="tag" ; \shift ;;
	*) ;;
	esac
	local FILE_SRC="$1"
	local FILE_DST="$2"
	local HASH_SRC=""
	local HASH_DST=""
	local HASH_HEAD_LINES=0
	if [[ -z $FILE_SRC ]]; then
		failure "File SRC is required"
		failure ; exit 1
	fi
	if [[ -z $FILE_DST ]]; then
		failure "File DST is required"
		failure ; exit 1
	fi
	if [[ "$FILE_SRC" == "$FILE_DST" ]]; then
		failure "Source is the same as destination"
		failure ; exit 1
	fi
	local PATH_DST=${FILE_DST%/*}
	if [[ -z $PATH_DST ]]; then
		failure "Failed to detect destination dir"
		failure ; exit 1
	fi
	if [[ ! -d "$PATH_DST" ]]; then
		failure "Destination dir not found: $PATH_DST"
		failure ; exit 1
#		echo_cmd  "mkdir  $PATH_DST"
#		\mkdir -p  "$PATH_DST"  || exit 1
	fi
	local FILE=$( \basename "$FILE_DST" )
	local FILE_SRC_ORIGINAL="$FILE_SRC"
	local FILE_TMP=""
	if [[ "$TYPE" == "tag" ]]; then
		FILE_TMP=$( \mktemp )
		if [[ -z $FILE_TMP ]]; then
			failure "Failed to create a temp file"
			failure ; exit 1
		fi
		[[ $VERBOSE -eq $YES ]] && \
			echo_cmd  "cp  $FILE  $FILE_TMP"
		\cp  "$FILE_SRC"  "$FILE_TMP"  || exit 1
		DoTags  "$FILE_TMP"            || exit 1
		FILE_SRC="$FILE_TMP"
	fi
	DoHashFile  "$TYPE"  "$FILE_SRC"  || exit 1 ; HASH_SRC="$HASH_RESULT" ; HASH_HEAD_LINES=$COUNT_HEAD_LINES
	DoHashFile  "$TYPE"  "$FILE_DST"  || exit 1 ; HASH_DST="$HASH_RESULT"
	if [[ -z $HASH_SRC ]]; then
		failure "Failed to hash SRC: $FILE_SRC"
		failure ; exit 1
	fi
	local STATE=""
	# [+] extract new file
	if [[ -z $HASH_DST ]]; then
		STATE="+"
	# [=] match
	elif [[ "$HASH_SRC" == "$HASH_DST" ]]; then
		STATE="="
	# [U] update
	else
		STATE="U"
	fi
	# log file state
	case "$STATE" in
	"=") echo -ne   "   ${COLOR_BLUE}[=] " ;;
	"+") echo -ne  "   ${COLOR_GREEN}[+] " ;;
	"U") echo -ne "   ${COLOR_YELLOW}[U] " ;;
	*) ;;
	esac
	echo -ne "${COLOR_CYAN}"
	# needs extracting
	if [[ "$STATE" == "+" ]] \
	|| [[ "$STATE" == "U" ]]; then
		if [[ $IS_DRY -eq $NO ]]; then
			\cp -v  "$FILE_SRC"  "$FILE_DST"  || exit 1
			echo -ne "${COLOR_RESET}"
		else
			echo -e "dry-cp  SRC -> $FILE${COLOR_RESET}"
		fi
		if [[ $VERBOSE -eq $YES ]]; then
			echo -e "     ${COLOR_CYAN}SRC:  ${COLOR_GREEN}$HASH_SRC  ${COLOR_CYAN}$FILE_SRC_ORIGINAL${COLOR_RESET}"
			echo -e "     ${COLOR_CYAN}DST:  ${COLOR_GREEN}${HASH_DST:- - - - - - <missing> - - - - -  }  ${COLOR_CYAN}$FILE_DST${COLOR_RESET}"
		fi
		COUNT_COPY=$((COUNT_COPY+1))
	# existing file is ok
	else
		echo -e "$FILE${COLOR_RESET}"
	fi
	COUNT_TOTAL=$((COUNT_TOTAL+1))
	# remove temp file
	if [[ ! -z $FILE_TMP ]]; then
		if [[ $VERBOSE -eq $YES ]]; then
			echo -n "    "
			echo_cmd  "rm $FILE_TMP"
		fi
		\rm -f  --preserve-root  "$FILE_TMP"
	fi
}



function DoTags() {
	local FILE="$1"
	if [[ -z $FILE ]]; then
		failure "DoTags() function requires arguments"
		failure ; exit 1
	fi
	local TIMESTAMP=$( \date )
	\sed -i                                          "s/{{""{TIMESTAMP}}}/$TIMESTAMP/"            "$FILE"  || exit 1
	if [[ ! -z $PROJECT_SERVER     ]]; then \sed -i  "s/{{""{SERVER}}}/$PROJECT_SERVER/"          "$FILE"  || exit 1 ; fi
	if [[ ! -z $PROJECT_TITLE      ]]; then \sed -i  "s/{{""{TITLE}}}/$PROJECT_TITLE/"            "$FILE"  || exit 1 ; fi
	if [[ ! -z $PROJECT_NAME       ]]; then \sed -i  "s/{{""{NAME}}}/$PROJECT_NAME/"              "$FILE"  || exit 1 ; fi
	if [[ ! -z $PROJECT_NAME_LOWER ]]; then \sed -i  "s/{{""{NAME-LOWER}}}/$PROJECT_NAME_LOWER/"  "$FILE"  || exit 1 ; fi
}



function DoHashFile() {
	HASH_RESULT=""
	COUNT_HEAD_LINES=0
	local TYPE=""
	local FILE=""
	if [[ -z $1 ]]; then
		FILE=""
	elif [[ -z $2 ]]; then
		FILE="$1"
	else
		TYPE="$1"
		FILE="$2"
	fi
	if [[ -z $FILE ]]; then
		failure "DoHashFile() function requires file argument"
		failure ; exit 1
	fi
	[[ -z $TYPE ]] && TYPE="bin"
	# file doesn't exist
	[[ ! -e $FILE ]] && return 0
	case "$TYPE" in
	# binary file
	bin)
		HASH_RESULT=$( \md5sum "$FILE" )
		local RESULT=$?
		[[ $RESULT -ne 0   ]] && return $RESULT
		[[ -z $HASH_RESULT ]] && return 1
		[[ "$HASH_RESULT" == *" "* ]] && \
			HASH_RESULT="${HASH_RESULT%% *}"
		return $?
	;;
	# text file
	txt|tag)
		local FILE_TMP=""
		local IS_HEAD=$YES
		local FIRST=$YES
		while \read LINE || [[ -n $LINE ]]; do
			# head
			if [[ $IS_HEAD -eq $YES ]]; then
				case "$LINE" in
					"")     ;;
					"//"*)  ;;
					"/\*"*) ;;
					"#"*)   ;;
					*) IS_HEAD=$NO ;;
				esac
			fi
			# head
			if [[ $IS_HEAD -eq $YES ]]; then
				COUNT_HEAD_LINES=$((COUNT_HEAD_LINES+1))
			# body
			else
				# no comment header
				if [[ $FIRST -eq $YES ]]; then
					HASH_RESULT=$( \md5sum "$FILE" )
					local RESULT=$?
					[[ $RESULT -ne 0   ]] && return $RESULT
					[[ -z $HASH_RESULT ]] && return 1
					[[ "$HASH_RESULT" == *" "* ]] && \
						HASH_RESULT="${HASH_RESULT%% *}"
					return $?
				fi
				if [[ -z $FILE_TMP ]]; then
					FILE_TMP=$( \mktemp )
					if [[ -z $FILE_TMP ]]; then
						failure "Failed to create a temp file"
						failure ; exit 1
					fi
				fi
				echo  "$LINE"  >>"$FILE_TMP"
			fi
			FIRST=$NO
		done < "$FILE"
		[[ -z $FILE_TMP ]] && return 0
		HASH_RESULT=$( \md5sum "$FILE_TMP" )
		local RESULT=$?
		local FLAG_VERB_QUIET=""
		[[ $VERBOSE -eq $YES ]] && \
			echo_cmd  "rm $FILE_TMP"
		\rm -f --preserve-root  "$FILE_TMP"
		[[ $RESULT -ne 0   ]] && return $RESULT
		[[ -z $HASH_RESULT ]] && return 1
		[[ "$HASH_RESULT" == *" "* ]] && \
			HASH_RESULT="${HASH_RESULT%% *}"
		return 0
	;;
	*)
		failure "Unknown file type: $TYPE"
		failure ; exit 1
	;;
	esac
}



# -------------------------------------------------------------------------------
# parse args



while [ $# -gt 0 ]; do
	case "$1" in

	-D|--dry|--dry-run) IS_DRY=$YES ;;

	-v|--verbose)           VERBOSE=$YES ;;
	-q|--quiet)             QUIET=$YES   ;;
	--color|--colors)       NO_COLORS=$NO  ; enable_colors  ;;
	--no-color|--no-colors) NO_COLORS=$YES ; disable_colors ;;
	-V|--version) DisplayVersion  ; exit 1 ;;
	-h|--help)    DisplayHelp     ; exit 1 ;;

	-*)
		failure "Unknown flag: $1"
		failure ; DisplayHelp ; exit 1
	;;
	*)
		if [[ -z $PATH_SRC ]]; then
			PATH_SRC="$1"
		elif [[ -z $PATH_DST ]]; then
			PATH_DST="$1"
		else
			failure "Unknown argument: $1"
			failure ; exit 1
		fi
	;;

	esac
	\shift
done



DID_NOTICE=$NO
if [[ $IS_DRY -eq $YES ]]; then
	DID_NOTICE=$YES
	notice "Dry-run"
fi
[[ $DID_NOTICE -eq $YES ]] && echo



# source/destination paths
if [[ -z $PATH_SRC ]]; then
	PATH_SRC="$WDIR/../skel"
fi
if [[ -z $PATH_DST ]]; then
	PATH_DST="$WDIR"
fi
REAL_PATH_SRC=$( \realpath "$PATH_SRC" )
REAL_PATH_DST=$( \realpath "$PATH_DST" )
if [[ -z $REAL_PATH_SRC ]]; then
	failure "Failed to find resource SRC: $PATH_SRC"
	failure ; exit 1
fi
if [[ -z $REAL_PATH_DST ]]; then
	failure "Failed to find resource DST: $PATH_DST"
	failure ; exit 1
fi

echo -e " Source:      ${COLOR_CYAN}$REAL_PATH_SRC${COLOR_RESET}"
echo -e " Destination: ${COLOR_CYAN}$REAL_PATH_DST${COLOR_RESET}"
echo

if [[ "$REAL_PATH_SRC" == "$REAL_PATH_DST" ]]; then
	failure "Source is the same as destination"
	failure ; exit 1
fi



# load ximplement.conf
FOUND_FILE=$NO
# from current dir
if [[ -f "$WDIR/ximplement.conf" ]]; then
	source  "$WDIR/ximplement.conf"  || exit 1
	FOUND_FILE=$YES
fi
# from destination path
if [[ "$REAL_PATH_DST" != "$WDIR"         ]] \
&& [[ -f "$REAL_PATH_DST/ximplement.conf" ]]; then
	source  "$REAL_PATH_DST/ximplement.conf"  || exit 1
	FOUND_FILE=$YES
fi
# from source path
if [[ -f "$REAL_PATH_SRC/ximplement.conf" ]]; then
	source  "$REAL_PATH_SRC/ximplement.conf"  || exit 1
	FOUND_FILE=$YES
fi
# ximplement.conf not found
if [[ $FOUND_FILE -eq $NO ]]; then
	failure "ximplement.conf file not found in source path: $REAL_PATH_SRC"
	failure ; exit 1
fi



# -------------------------------------------------------------------------------
# finished



echo
echo -e  " ${COLOR_GREEN}Finished!${COLOR_RESET}"
[[ $COUNT_TOTAL -eq 1 ]] && S="" || S="s" ; echo -e " ${COLOR_GREEN}Found ${COLOR_BLUE}$COUNT_TOTAL${COLOR_GREEN} file$S${COLOR_RESET}"
[[ $COUNT_COPY  -eq 1 ]] && S="" || S="s" ; echo -e " ${COLOR_GREEN}Copied ${COLOR_BLUE}$COUNT_COPY${COLOR_GREEN} file$S${COLOR_RESET}"
echo

exit 0
