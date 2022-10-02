#!/usr/bin/bash
##==============================================================================
## Copyright (c) 2019-2022 Mattsoft/PoiXson
## <https://mattsoft.net> <https://poixson.com>
## Released under the AGPL 3.0
##
## Description: Auto deploy a project or website
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU Affero General Public License as
## published by the Free Software Foundation, either version 3 of the
## License, or (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU Affero General Public License for more details.
##
## You should have received a copy of the GNU Affero General Public License
## along with this program.  If not, see <https://www.gnu.org/licenses/>.
##==============================================================================
# xdeploy.sh
VERSION="{{{VERSION}}}"



source /usr/bin/pxn/scripts/common.sh  || exit 1

if [[ -z $WDIR ]]; then
	echo
	failure "Failed to find current working directory"
	failure ; exit 1
fi



# actions
VERBOSE=$NO
QUIET=$NO
NO_COLORS=$NO
IS_DRY=$NO
DO_ALL=$NO
DO_CLEAN=$NO

# project vars
PROJECT_NAME=""
PROJECT_PATH=""
PROJECT_USER=""
PROJECT_DOMAIN=""
PROJECT_REPO=""

PROJECT_FILTERS=""
PACKAGES_ALL=()
let COUNT_PRJ=0



function DisplayHelp() {
	echo -e "${COLOR_BROWN}Usage:${COLOR_RESET}"
	echo    "  xdeploy [options] <projects/websites>"
	echo
	echo -e "${COLOR_BROWN}Options:${COLOR_RESET}"
	echo -e "  ${COLOR_GREEN}-a, --all${COLOR_RESET}                 Deploy all projects/websites"
	echo -e "  ${COLOR_GREEN}-c, --clean, --cleanup${COLOR_RESET}    Cleanup workspace; delete generated files"
	echo -e "  ${COLOR_GREEN}-D, --dry${COLOR_RESET}                 Dry-run, no changes will be performed by actions"
	echo
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
	echo -e "${COLOR_BROWN}xBuild${COLOR_RESET} ${COLOR_GREEN}${VERSION}${COLOR_RESET}"
	echo
}



# ----------------------------------------



function LoadConf() {
	ProjectCleanup
	if [[ -z $1 ]]; then
		failure "LoadConf() requires file argument"
		failure ; exit 1
	fi
	if [[ "$1" != *"/xdeploy.conf" ]]; then
		failure "Invalid config file: $1"
		failure ; exit 1
	fi
	source  "$1"  || exit 1
	doProject
	ProjectCleanup
}



function Project() {
	# perform previous project
	if [[ ! -z $PROJECT_NAME ]]; then
		doProject
		ProjectCleanup
	fi
	if [[ ! -z $1 ]]; then
		PROJECT_NAME="$1"
	fi
}
function doProject() {
	if [[ -z $PROJECT_NAME ]]; then
		ProjectCleanup
		return
	fi
	# check values
	if [[ -z $PROJECT_USER ]]; then
		failure "User not set for project: $PROJECT_NAME"
		failure ; exit 1
	fi
	if [[ -z $PROJECT_DOMAIN ]]; then
		failure "Domain not set for project: $PROJECT_NAME"
		failure ; exit 1
	fi
	if [[ -z $PROJECT_REPO ]]; then
		failure "Repo not set for project: $PROJECT_NAME"
		failure ; exit 1
	fi
	# path
	PROJECT_PATH="/home/$PROJECT_USER/www"
	# deploy project/website
	if [[ $QUIET -eq $NO ]]; then
		title B "$PROJECT_NAME" "$PROJECT_DOMAIN"
		echo -e " ${COLOR_GREEN}[[${COLOR_RESET} ${COLOR_BLUE}$PROJECT_PATH${COLOR_RESET} ${COLOR_GREEN}]]${COLOR_RESET} "
		echo
	fi
	\pushd  "$PROJECT_PATH"  >/dev/null  || exit 1
		# path exists
		if [[ -d "$PROJECT_PATH/$PROJECT_DOMAIN" ]]; then
			if [[ $DO_CLEAN -eq $YES ]]; then
				echo -ne " > ${COLOR_CYAN}rm $PROJECT_DOMAIN${COLOR_RESET}"
				if [[ $IS_DRY -eq $NO ]]; then
					local c=$( \sudo -u "$PROJECT_USER"  \
						\sudo -u "$PROJECT_USER"  \
							\rm --preserve-root -Rfdv  "$PROJECT_DOMAIN"  \
								| \wc -l  || exit 1)
					echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
					echo
				fi
			fi
		fi
		# update repo
		if [[ -d "$PROJECT_PATH/$PROJECT_DOMAIN" ]]; then
			\pushd  "$PROJECT_PATH/$PROJECT_DOMAIN/"  >/dev/null  || exit 1
				echo -e " > ${COLOR_CYAN}git pull${COLOR_RESET}"
				if [[ $IS_DRY -eq $NO ]]; then
					\sudo -u "$PROJECT_USER"  \
						\git pull  || exit 1
					echo
				fi
			\popd  >/dev/null
		# clone repo
		else
			echo -e " > ${COLOR_CYAN}git clone${COLOR_RESET}"
			if [[ $IS_DRY -eq $NO ]]; then
				\sudo -u "$PROJECT_USER"  \
					\git clone  "$PROJECT_REPO"  "$PROJECT_DOMAIN"  || exit 1
				echo
			fi
		fi
		# composer install
		\pushd  "$PROJECT_PATH/$PROJECT_DOMAIN/"  >/dev/null  || exit 1
			if [[ ! -d "$PROJECT_PATH/$PROJECT_DOMAIN/cache" ]]; then
				echo -e " > ${COLOR_CYAN}mkdir cache${COLOR_RESET}"
				if [[ $IS_DRY -eq $NO ]]; then
					\sudo -u "$PROJECT_USER"  \
						\mkdir -v  "cache"  || exit 1
					echo
				fi
			fi
			echo -e " > ${COLOR_CYAN}composer install${COLOR_RESET}"
			if [[ $IS_DRY -eq $NO ]]; then
				\sudo -u "$PROJECT_USER"  \
					\composer install  || exit 1
				echo
			fi
		\popd  >/dev/null
	\popd  >/dev/null
	# project done
	echo
	PROJECTS_ALL+=("$PROJECT_NAME")
	COUNT_PRJ=$((COUNT_PRJ+1))
}



function Repo() {
	if [[ ! -z $1 ]]; then
		PROJECT_REPO="$1"
	fi
}
function User() {
	if [[ ! -z $1 ]]; then
		PROJECT_USER="$1"
	fi
}
function Domain() {
	if [[ ! -z $1 ]]; then
		PROJECT_DOMAIN="$1"
	fi
}
function ProjectCleanup() {
	PROJECT_NAME=""
	PROJECT_PATH=""
	PROJECT_USER=""
	PROJECT_DOMAIN=""
	PROJECT_REPO=""
}



# ----------------------------------------



# parse args
echo
if [[ $# -eq 0 ]]; then
	DisplayHelp
	exit 1
fi
while [ $# -gt 0 ]; do
	case "$1" in

	-D|--dry)  IS_DRY=$YES  ;;

	-a|--all)                      DO_ALL=$YES     ;;
	-c|--clean|--clear|--cleanup)  DO_CLEAN=$YES   ;;

	-v|--verbose)  VERBOSE=$YES  ;;
	-q|--quiet)    QUIET=$YES    ;;
	--color|--colors)       NO_COLORS=$NO  ; enable_colors  ;;
	--no-color|--no-colors) NO_COLORS=$YES ; disable_colors ;;
	-V|--version)  DisplayVersion ; exit 1  ;;
	-h|--help)     DisplayHelp    ; exit 1  ;;

	-*)
		failure "Unknown argument: $1"
		failure
		DisplayHelp
		exit 1
	;;
	*)
		PROJECT_FILTERS="$PROJECT_FILTERS $1"
	;;

	esac
	\shift
done

if [[ $QUIET -ne $YES ]]; then
	did_notice=$NO
	if [[ $IS_DRY -eq $YES ]]; then
		notice "Dry-run"
		did_notice=$YES
	fi
	[[ $did_notice -eq $YES ]] && echo
fi



#TODO
if [[ $DO_ALL -ne $YES ]]; then
	failure "Sorry, filtered deployment is unfinished."
	failure "Only -a is currently available."
	failure ; exit 1
fi



if [[ ! -f /xdeploy.conf ]]; then
    failure "/xdeploy.conf file not found"
    failure ; exit 1
fi
LoadConf  "/xdeploy.conf"



echo -e "${COLOR_GREEN}Finished${COLOR_RESET}"
exit 0
