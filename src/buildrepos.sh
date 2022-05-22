#!/usr/bin/bash
##==============================================================================
## Copyright (c) 2019-2022 PoiXson, Mattsoft
## <https://poixson.com> <https://mattsoft.net>
## Released under the GPL 3.0
##
## Description: Auto compile a project and build rpm's
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.
##==============================================================================
# buildrepos.sh
VERSION="{{{VERSION}}}"



source /usr/bin/pxn/scripts/common.sh  || exit 1



if [[ -z $WDIR ]]; then
	echo
	failure "Failed to find current working directory"
	failure ; exit 1
fi



function DisplayHelp() {
	echo -e "${COLOR_BROWN}Usage:${COLOR_RESET}"
	echo    "  buildrepos [options] [path]"
	echo
	echo -e "${COLOR_BROWN}Repos:${COLOR_RESET}"
	let count=0
#	for FILE in $( \ls -1v "$WDIR/"*.dev 2>/dev/null | \sort --version-sort ); do
#		NAME="${FILE%%.dev}"
#		NAME="${NAME##*/}"
#		echo -e "  ${COLOR_GREEN}$NAME${COLOR_RESET}"
#		count=$((count+1))
#	done
#	if [[ $count -eq 0 ]]; then
#		echo "  No .dev or xbuild.conf files found here"
#	fi
	echo
	echo -e "${COLOR_BROWN}Options:${COLOR_RESET}"
	echo -e "  ${COLOR_GREEN}-a, --all${COLOR_RESET}                 Use all .dev files found"
	echo -e "  ${COLOR_GREEN}-D, --dry${COLOR_RESET}                 Dry-run, no changes will be performed by actions"
	echo -e "  ${COLOR_GREEN}-c, --clean, --cleanup${COLOR_RESET}    Cleanup workspace; delete generated files"
	echo
	echo -e "  ${COLOR_GREEN}-v, --verbose${COLOR_RESET}             Enable debug logs"
	echo -e "  ${COLOR_GREEN}-V, --version${COLOR_RESET}             Display the version"
	echo -e "  ${COLOR_GREEN}-h, --help${COLOR_RESET}                Display this help message and exit"
	echo
	exit 1
}

function DisplayVersion() {
	echo -e "${COLOR_BROWN}BuildRepos${COLOR_RESET} ${COLOR_GREEN}${VERSION}${COLOR_RESET}"
	echo
}



# parse args
echo
if [[ $# -eq 0 ]]; then
	DisplayHelp
	exit 1
fi
REPO_PATHS=""
DO_ALL=$NO
IS_DRY=$NO
DO_CLEAN=$NO
VERBOSE=$NO
while [ $# -gt 0 ]; do
	case "$1" in
	# all repos
	-a|--all)
		DO_ALL=$YES
	;;
	# cleanup
	-c|--clean|--cleanup)
		DO_CLEAN=$YES
	;;
	# dry mode
	-D|--dry)
		IS_DRY=$YES
	;;
	# verbose logging
	-v|--verbose)
		VERBOSE=$YES
	;;
	# display version
	-V|--version)
		DisplayVersion
		exit 1
	;;
	# display help
	-h|--help)
		DisplayHelp
		exit 1
	;;
	-*)
		failure "Unknown argument: $1"
		failure
		DisplayHelp
		exit 1
	;;
	*)
		if [[ -e "$WDIR/$1" ]]; then
			REPO_PATHS="$REPO_PATHS $1"
		else
			failure "Unknown repo path: $1"
			failure ; exit 1
		fi
	;;
	esac
	\shift
done



did_notice=$NO
if [[ $IS_DRY -eq $YES ]]; then
	notice "Dry-run"
	did_notice=$YES
fi
[[ $did_notice -eq $YES ]] && echo



FIND_REPO=""
FOUND_REPO=$NO

let COUNT_OPS=0



function CreateRepo() {
	if [[ -z $1 ]] || [[ "$1" == "ALL" ]]; then
		FIND_REPO=""
	else
		FIND_REPO="$1"
	fi
	doCleanupVars
	FOUND_REPO=$NO
	source "$WDIR/repos.conf"  || exit 1
	REPO
}

function doCleanupVars() {
	REPO_NAME=""
}

function REPO() {
	if [[  ! -z $REPO_NAME ]]; then
		doREPO
		doCleanupVars
	fi
	if [[ ! -z $1 ]]; then
		REPO_NAME="$1"
	fi
}

function doREPO() {
	if [[ -z $REPO_NAME ]]; then
		doCleanupVars
		return
	fi
	if [[ ! -z $FIND_REPO ]]; then
		# already found
		if [[ $FOUND_REPO -ne $NO ]]; then
			return
		fi
		# found repo
		if [[ "$FIND_REPO" == "$REPO_NAME" ]]; then
			FOUND_REPO=$YES
		# not a match
		else
			return
		fi
	fi
	COUNT_OPS=$((COUNT_OPS+1))
	title C "Building Repo" "$REPO_NAME"
	echo
	if [[ ! -e "$WDIR/$REPO_NAME" ]]; then
		failure "Repo not found: $REPO_NAME"
		failure ; exit 1
	fi
	\pushd "$WDIR/$REPO_NAME"  >/dev/null  || exit 1
		\createrepo . -v --pretty --workers 6  || exit 1
	\popd  >/dev/null
	echo
	doCleanupVars
}



if [[ ! -e "$WDIR/repos.conf" ]]; then
	failure "repos.conf file not found here"
	failure ; exit 1
fi

if [[ $DO_ALL -eq $YES ]]; then
	CreateRepo ALL
else
	for REPO in $REPO_PATHS; do
		CreateRepo "$REPO"
	done
fi



echo -e "${COLOR_GREEN}===============================================${COLOR_RESET}"
echo

if [[ $COUNT_OPS -le 0 ]]; then
	warning "No actions performed"
	echo
	DisplayHelp
	exit 1
fi

echo -ne "${COLOR_GREEN}Performed $COUNT_OPS operation"
[[ $COUNT_OPS -gt 1 ]] && echo -n "s"
[[ $COUNT_PRJ -gt 1 ]] && echo -ne " on $COUNT_PRJ projects"
echo -e "${COLOR_RESET}"

echo
exit 0
