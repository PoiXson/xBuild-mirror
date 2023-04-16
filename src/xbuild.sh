#!/usr/bin/bash
##==============================================================================
## Copyright (c) 2019-2023 Mattsoft/PoiXson
## <https://mattsoft.net> <https://poixson.com>
## Released under the AGPL 3.0
##
## Description: Auto compile a project and build rpms
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
# xbuild.sh
XBUILD_VERSION="{{{VERSION}}}"



source /usr/bin/pxn/scripts/common.sh  || exit 1

if [[ -z $WDIR ]]; then
	echo
	failure "Failed to find current working directory"
	failure ; exit 1
fi



function DisplayHelp() {
	local FULL=$1
	echo -e "${COLOR_BROWN}Usage:${COLOR_RESET}"
	echo    "  xbuild [options] <group>"
	echo
	echo -e "${COLOR_BROWN}Options:${COLOR_RESET}"
	if [[ $FULL -eq $YES ]]; then
	echo -e "  ${COLOR_GREEN}-r, --recursive${COLOR_RESET}           Recursively load xbuild.conf files"
	echo -e "  ${COLOR_GREEN}-D, --dry${COLOR_RESET}                 Dry-run, no changes will be performed by actions"
	echo -e "  ${COLOR_GREEN}-d, --debug-flags${COLOR_RESET}         Build with debug flags"
	echo -e "  ${COLOR_GREEN}-R, --release${COLOR_RESET}             Build a production release"
	echo -e "  ${COLOR_GREEN}-n, --build-number <n>${COLOR_RESET}    Build number to use for builds and packages"
	echo                                "                              default: x"
	echo -e "  ${COLOR_GREEN}--target <path>${COLOR_RESET}           Sets the destination path for finished binaries"
	echo                                "                              default: target/"
	echo -e "  ${COLOR_GREEN}-F, --filter <project>${COLOR_RESET}    Skip all projects except these"
	echo
	echo -e "  ${COLOR_GREEN}--deb${COLOR_RESET}                     Build .deb packages with alien"
	echo -e "  ${COLOR_GREEN}--no-deb${COLOR_RESET}                  Skip building .deb packages"
	echo
	fi
	echo -e "  ${COLOR_GREEN}--pp, --pull-push${COLOR_RESET}         Run 'git pull' and 'git push'"
	echo -e "  ${COLOR_GREEN}--gg, --git-gui${COLOR_RESET}           Open git-gui for each project"
	echo
	if [[ $FULL -eq $YES ]]; then
	echo -e "  ${COLOR_GREEN}-c, --clean, --cleanup${COLOR_RESET}    Cleanup workspace; delete generated files"
	echo -e "  ${COLOR_GREEN}-C, --config, --configure${COLOR_RESET} Configure projects, with autotools or composer"
	echo -e "  ${COLOR_GREEN}-b, --build, --compile${COLOR_RESET}    Compile the projects"
	echo -e "  ${COLOR_GREEN}--tests${COLOR_RESET}                   Compile and run tests for the project"
	echo -e "  ${COLOR_GREEN}-p, --pack, --package${COLOR_RESET}     Build distributable packages"
	echo -e "  ${COLOR_GREEN}-i, --ide${COLOR_RESET}                 Create IDE project imports (while building)"
	echo
	echo -e "  ${COLOR_GREEN}--cb${COLOR_RESET}                      Config, build"
	echo -e "  ${COLOR_GREEN}--cbp${COLOR_RESET}                     Config, build, pack"
	echo -e "  ${COLOR_GREEN}--ccb${COLOR_RESET}                     Clean, config, build"
	echo -e "  ${COLOR_GREEN}--cbtp${COLOR_RESET}                    Config, build, test, pack"
	echo -e "  ${COLOR_GREEN}--ccbp${COLOR_RESET}                    Clean, config, build, pack"
	echo -e "  ${COLOR_GREEN}--ccbtp${COLOR_RESET}                   Clean, config, build, test, pack"
	echo
	fi
	echo -e "  ${COLOR_GREEN}-v, --verbose${COLOR_RESET}             Enable debug logs"
	echo -e "  ${COLOR_GREEN}-q, --quiet${COLOR_RESET}               Hide extra logs"
	if [[ $FULL -eq $YES ]]; then
	echo -e "  ${COLOR_GREEN}--colors${COLOR_RESET}                  Enable console colors"
	echo -e "  ${COLOR_GREEN}--no-colors${COLOR_RESET}               Disable console colors"
	fi
	echo -e "  ${COLOR_GREEN}-V, --version${COLOR_RESET}             Display the version"
	echo -e "  ${COLOR_GREEN}-h, --help${COLOR_RESET}                Display this help message and exit"
	if [[ $FULL -ne $YES ]]; then
	echo -e " ${COLOR_GREEN}truncated.. use --help for more flags${COLOR_RESET}"
	fi
	echo
	exit 1
}

function DisplayVersion() {
	echo -e "${COLOR_BROWN}xBuild${COLOR_RESET} ${COLOR_GREEN}$XBUILD_VERSION${COLOR_RESET}"
	echo
}



# ----------------------------------------



ACTIONS=""
ACTIONS_DONE=""
VERBOSE=$NO
QUIET=$NO
NO_COLORS=$NO
DO_RECURSIVE=$NO
DO_ALIEN=$YES
IS_DRY=$NO
DEBUG_FLAGS=$NO

BUILD_NUMBER=""
BUILD_RELEASE=$NO
TARGET_PATH=""
PROJECT_FILTERS=""
PROJECT_FILTERS_FOUND=""
PACKAGES_ALL=()

# project vars
PROJECT_NAME=""
PROJECT_PATH=""
PROJECT_REPO=""
PROJECT_VERSION=""
PROJECT_SNAPSHOT=""
PROJECT_GITIGNORE=""
PROJECT_TAG_FILES=""
PROJECT_TAGS_DONE=$NO
CURRENT_PATH="$WDIR"

TIME_START=$( \date "+%s%N" )
let TIME_START_PRJ=0
let TIME_LAST=0
let COUNT_PRJ=0
let COUNT_ACT=0



function DisplayTime() {
	[[ $QUIET -eq $YES ]] && return
	TIME_CURRENT=$( \date "+%s%N" )
	ELAPSED=$( echo "scale=3;($TIME_CURRENT - $TIME_LAST) / 1000 / 1000 / 1000" | bc )
	[[ "$ELAPSED" == "."* ]] && \
		ELAPSED="0$ELAPSED"
	echo -e " ${COLOR_CYAN}$1 in $ELAPSED seconds${COLOR_RESET}"
	echo
	TIME_LAST=$TIME_CURRENT
}
function DisplayTimeProject() {
	[[ $QUIET -eq $YES ]] && return
	TIME_CURRENT=$( \date "+%s%N" )
	ELAPSED=$( echo "scale=3;($TIME_CURRENT - $TIME_START_PRJ) / 1000 / 1000 / 1000" | bc )
	[[ "$ELAPSED" == "."* ]] && \
		ELAPSED="0$ELAPSED"
	echo -e " ${COLOR_CYAN}Finished project in $ELAPSED seconds: $PROJECT_NAME${COLOR_RESET}"
	echo -e " ${COLOR_CYAN}--------------------------------------------------${COLOR_RESET}"
	echo
}



function echo_cmd() {
	local N=""
	if [[ "$1" == "-n" ]]; then
		N="-n"
		\shift
	fi
	echo $N -e  " ${COLOR_GREEN}>${COLOR_RESET} ${COLOR_CYAN}$@${COLOR_RESET}"
}



function Path() {
	if [[ -z $1 ]]; then
		failure "Path value is missing for project: $PROJECT_NAME"
		failure ; exit 1
	fi
	PROJECT_PATH="$1"
}
function Repo() {
	if [[ -z $1 ]]; then
		failure "Repo value is missing for project: $PROJECT_NAME"
		failure ; exit 1
	fi
	PROJECT_REPO="$1"
}
function TagFile() {
	if [[ -z $1 ]]; then
		failure "TagFile value is missing for project: $PROJECT_NAME"
		failure ; exit 1
	fi
	PROJECT_TAG_FILES="$PROJECT_TAG_FILES $1"
}
function AddIgnore() {
	if [[ -z $1 ]]; then
		failure "AddIgnore value is missing for project: $PROJECT_NAME"
		failure ; exit 1
	fi
	PROJECT_GITIGNORE="$PROJECT_GITIGNORE $1"
}



function CopyFile() {
	if [[ -z $1 ]] || [[ -z $2 ]]; then
		failure "CopyFile() requires arguments"
		failure ; exit 1
	fi
	if [[ -e "$1" ]]; then
		echo_cmd -n "Copy: "
		echo -ne "${COLOR_CYAN}"
		local RESULT=0
		if [[ $IS_DRY -eq $NO ]]; then
			\cp  -fv --preserve=all  "$1" "$2"
			RESULT=$?
		else
			echo "$1 -> $2"
		fi
		echo -ne "$COLOR_RESET"
		[[ $RESULT -eq 0 ]] || exit 1
	else
		warning "File not found for copy: $1"
	fi
}

function MakeSymlink() {
	if [[ -z $1 ]]; then
		failure "MakeSymlink() requires arguments"
		failure ; exit 1
	fi
	if [[ ! -e "$1" ]]; then
		warning "File not found for symlink: $1"
	fi
	echo_cmd -n "Symlink: "
	echo -ne "${COLOR_CYAN}"
	local RESULT=0
	if [[ $IS_DRY -eq $NO ]]; then
		if [[ -z $2 ]]; then
			\ln  -svfL  "$1"
		else
			\ln  -svfL  "$1"  "$2"
		fi
		RESULT=$?
	else
		echo "$1 -> $2"
	fi
	echo -ne "$COLOR_RESET"
	[[ $RESULT -eq 0 ]] || exit 1
}



function Project() {
	# perform previous project
	if [[ ! -z $PROJECT_NAME ]]; then
		doProject
		CleanupProjectVars
	fi
	if [[ ! -z $1 ]]; then
		PROJECT_NAME="$1"
	fi
}

function doProject() {
	if [[ -z $PROJECT_NAME ]]; then
		CleanupProjectVars
		return
	fi
	PROJECT_FILTERS_FOUND="$PROJECT_FILTERS_FOUND $PROJECT_NAME"
	if [[ ! -z $PROJECT_FILTERS ]]; then
		if [[ " $PROJECT_FILTERS " != *" $PROJECT_NAME "* ]]; then
			notice "Skipping filtered: $PROJECT_NAME"
			return
		fi
	fi
	if [[ -z $PROJECT_PATH ]]; then
		# project in named path
		if [[ -f "$CURRENT_PATH/$PROJECT_NAME/xbuild.conf" ]]; then
			PROJECT_PATH="$CURRENT_PATH/$PROJECT_NAME"
		# current path
		else
			PROJECT_PATH="$CURRENT_PATH"
		fi
	else
		# current path
		if [[ $PROJECT_PATH == "." ]]; then
			PROJECT_PATH="$CURRENT_PATH"
		# defined path
		else
			PROJECT_PATH="$CURRENT_PATH/$PROJECT_PATH"
		fi
	fi
#	if [[ $QUIET -eq $NO ]] && [[ "$PROJECT_PATH" != "$CURRENT_PATH" ]]; then
	if [[ $QUIET -eq $NO ]]; then
		title B "$PROJECT_NAME"
		echo -e " ${COLOR_GREEN}>${COLOR_RESET} ${COLOR_BLUE}${PROJECT_PATH}${COLOR_RESET}"
		if [[ ! -z $PROJECT_VERSION ]]; then
			notice "Version: ${COLOR_GREEN}$PROJECT_VERSION${COLOR_RESET}"
# $PROJECT_SNAPSHOT
		fi
		echo
	fi
	# recursive



#TODO





	for ENTRY in $( \ls -1 -v "/zcode/apr/xBuild/src/xbuild-stages/" ); do
		source "/zcode/apr/xBuild/src/xbuild-stages/$ENTRY"
	done
}

function CleanupProjectVars() {
	restoreProjectTags
	PROJECT_NAME=""
	PROJECT_PATH=""
	PROJECT_REPO=""
	PROJECT_GITIGNORE=""
	PROJECT_TAG_FILES=""
	PROJECT_TAGS_DONE=$NO
	TIME_START_PRJ=$( \date "+%s%N" )
	TIME_LAST=$TIME_START_PRJ
}



function LoadConf() {
	CleanupProjectVars
	if [[ -z $1 ]]; then
		failure "LoadConf() requires file argument"
		failure ; exit 1
	fi
	if [[ "$1" != *"/xbuild.conf" ]]; then
		failure "Invalid config file: $1"
		failure ; exit 1
	fi
	local LAST_PATH="$CURRENT_PATH"
	local LAST_VERSION="$PROJECT_VERSION"
	local LAST_SNAPSHOT="$PROJECT_SNAPSHOT"
	CURRENT_PATH="${1%/*}"
	PROJECT_VERSION=""
	PROJECT_SNAPSHOT=""
	DetectGitTag "$CURRENT_PATH"
	\pushd  "$CURRENT_PATH"  >/dev/null  || exit 1
		# load xbuild.conf
		source "$CURRENT_PATH/xbuild.conf" || exit 1
		# last project in conf file
		doProject
		CleanupProjectVars
	\popd >/dev/null
	CURRENT_PATH="$LAST_PATH"
	PROJECT_VERSION="$LAST_VERSION"
	PROJECT_SNAPSHOT="$LAST_SNAPSHOT"
}



function DetectGitTag() {
	local DIR="$1"
	[[   -z  $DIR  ]] && return
	[[ ! -d "$DIR" ]] && return
	\pushd  "$DIR/"  >/dev/null  || exit 1
		echo_cmd "git describe --tags --exact-match"
		if [[ $IS_DRY -eq $NO ]]; then
			local TAG=$( \git describe --tags --exact-match  2>/dev/null )
			RESULT=$?
			if [[ $RESULT -ne 0 ]]; then
				failure "Failed to detect latest commit tag"
				failure ; exit 1
			fi
			# snapshot
			if [[ -z $TAG ]]; then
				[[ $DO_AUTO -eq $YES ]] \
					&& BUILD_RELEASE=$NO
				echo_cmd "git describe --tags --abbrev=0"
				TAG=$( \git describe --tags --abbrev=0  2>/dev/null )
				RESULT=$?
				if [[ $RESULT -eq 0 ]]; then
					PROJECT_VERSION="$TAG-SNAPSHOT"
				else
					PROJECT_VERSION="0.1.1"
					notice "Project has no tags"
					notice "Defaulting to $PROJECT_VERSION"
					echo
				fi
			# release
			else
				notice "Found tag: $TAG"
				echo
				[[ $DO_AUTO -eq $YES ]] \
					&& BUILD_RELEASE=$YES
				PROJECT_VERSION="$TAG"
			fi
		fi
	\popd >/dev/null
	# build number
	if [[ ! -z $BUILD_NUMBER    ]] \
	&& [[ ! -z $PROJECT_VERSION ]] \
	&& [[ "$PROJECT_VERSION" != "SNAPSHOT" ]]; then
		local VERS="$PROJECT_VERSION"
		local IS_SNAP=$NO
		if [[ "$VERS" == *"-SNAPSHOT" ]]; then
			VERS=${VERS%-*}
			IS_SNAP=$YES
		fi
		if [[ "$VERS" == *"-"* ]]; then
			VERS=${VERS%-*}
		fi
		VERS=${VERS%.*}
		PROJECT_VERSION="${VERS}.${BUILD_NUMBER}"
	fi
}



function doProjectTags() {
	[[ $PROJECT_TAGS_DONE -eq $YES ]] && return
	PROJECT_TAGS_DONE=$YES
	for F in $PROJECT_TAG_FILES; do
		[[ $VERBOSE -eq $YES ]] && \
			notice "Replacing tags in: $F"
		if [[ ! -f "$PROJECT_PATH/$F" ]] \
		&& [[ ! -f "$PROJECT_PATH/${F}.xbuild_temp" ]]; then
			failure "File not found: $F"
			failure ; exit 1
		fi
#TODO: handle dry
		# file already tagged
		if [[ -e "$PROJECT_PATH/${F}.xbuild_temp" ]]; then
			[[ $VERBOSE -eq $YES ]] && \
				notice "File already exists: ${F}.xbuild_temp"
			# restore original
			[[ $VERBOSE -eq $YES ]] && \
				echo_cmd "rm -fv $F"
			[[ $IS_DRY -eq $NO ]] && \
				\rm -fv  "$PROJECT_PATH/$F"  || exit 1
		else
			[[ $VERBOSE -eq $YES ]] && \
				echo_cmd "mv -v $F ${F}.xbuild_temp"
			[[ $IS_DRY -eq $NO ]] && \
				\mv -v  "$PROJECT_PATH/$F"  "$PROJECT_PATH/${F}.xbuild_temp"  || exit 1
		fi
		[[ $VERBOSE -eq $YES ]] && \
			echo_cmd "cp -v ${F}.xbuild_temp $F"
		[[ $IS_DRY -eq $NO ]] && \
			\cp -v  "$PROJECT_PATH/${F}.xbuild_temp"  "$PROJECT_PATH/$F"  || exit 1
		# tags
		if [[ ! -z $PROJECT_VERSION ]]; then
			# special case for rust/cargo
			if [[ "$PROJECT_PATH/$F" == *"/Cargo.toml" ]]; then
				if [[ ! -z $BUILD_NUMBER ]] && [[ "$BUILD_NUMBER" != "x" ]]; then
					local VERS_GUESS=${PROJECT_VERSION%.*}".0"
					[[ $VERBOSE -eq $YES ]] && \
						echo_cmd "sed -i 's/$VERS_GUESS/$PROJECT_VERSION/' $F"
					[[ $IS_DRY -eq $NO ]] && \
						\sed -i  "s/$VERS_GUESS/$PROJECT_VERSION/"  "$PROJECT_PATH/$F"  || exit 1
				fi
			# {VERSION} tag
			else
				[[ $VERBOSE -eq $YES ]] && \
					echo_cmd "sed -i 's/{{""{VERSION}}}/$PROJECT_VERSION/' $F"
				[[ $IS_DRY -eq $NO ]] && \
					\sed -i  "s/{{""{VERSION}}}/$PROJECT_VERSION/"  "$PROJECT_PATH/$F"  || exit 1
			fi
		fi
	done
	[[ $VERBOSE -eq $YES ]] && \
		echo
}
function restoreProjectTags() {
	[[ $PROJECT_TAGS_DONE -ne $YES ]] && return
	for F in $PROJECT_TAG_FILES; do
		[[ $VERBOSE -eq $YES ]] && \
			notice "Restoring tags in: $F"
		if [[ -e "$PROJECT_PATH/${F}.xbuild_temp" ]]; then
			if [[ -e "$PROJECT_PATH/$F" ]]; then
				echo_cmd "rm -f  $PROJECT_PATH/$F"
				\rm -f  "$PROJECT_PATH/$F"  || exit 1
			fi
			echo_cmd "mv  $PROJECT_PATH/$F.xbuild_temp  $PROJECT_PATH/$F"
			\mv  "$PROJECT_PATH/${F}.xbuild_temp"  "$PROJECT_PATH/$F"  || exit 1
		fi
	done
	[[ $VERBOSE -eq $YES ]] && \
		echo
}



# ----------------------------------------
# parse args



echo
if [[ $# -eq 0 ]]; then
	DisplayHelp $YES
	exit 1
fi
while [ $# -gt 0 ]; do
	case "$1" in

	-r|--recursive)  DO_RECURSIVE=$YES   ;;
	-D|--dry)        IS_DRY=$YES         ;;
	-R|--release)    BUILD_RELEASE=$YES  ;;
	-d|--debug|--debug-flag|--debug-flags)  DEBUG_FLAGS=$YES  ;;

	-n|--build-number)
		if [[ -z $2 ]] || [[ "$2" == "-"* ]]; then
			failure "--build-number flag requires a value"
			failure ; DisplayHelp $NO ; exit 1
		fi
		\shift
		BUILD_NUMBER="$1"
	;;
	-n*)  BUILD_NUMBER="${1#-n}"  ;;
	--build-number=*)
		BUILD_NUMBER="${1#*=}"
		if [[ -z $BUILD_NUMBER ]]; then
			failure "--build-number flag requires a value"
			failure ; DisplayHelp $NO ; exit 1
		fi
	;;

	--target)
		if [[ -z $2 ]] || [[ "$2" == "-"* ]]; then
			failure "--target flag requires a value"
			failure ; DisplayHelp $NO ; exit 1
		fi
		\shift
		TARGET_PATH="$1"
	;;
	--target=*)
		TARGET_PATH="${1#*=}"
		if [[ -z $TARGET_PATH ]]; then
			failure "--target flag requires a value"
			failure ; DisplayHelp $NO ; exit 1
		fi
	;;

	-F|--filter)
		if [[ -z $2 ]] || [[ "$2" == "-"* ]]; then
			failure "--filter flag requires a value"
			failure ; DisplayHelp $NO ; exit 1
		fi
		\shift
		PROJECT_FILTERS="$PROJECT_FILTERS $1"
	;;
	--filter=*)
		FILTER="${1#*=}"
		if [[ -z $FILTER ]]; then
			failure "--filter flag requires a value"
			failure ; DisplayHelp $NO ; exit 1
		fi
		PROJECT_FILTERS="$PROJECT_FILTERS $FILTER"
	;;

	--deb)     DO_ALIEN=$YES  ;;
	--no-deb)  DO_ALIEN=$NO   ;;

	--pp|--pull-push|--push-pull|pp|pull-push)  ACTIONS="$ACTIONS pull-push"  ;;
	--gg|--git-gui|gg|git-gui)                  ACTIONS="$ACTIONS git-gui"    ;;

	-c|--clean|--clear|--cleanup|clean|cleanup)  ACTIONS="$ACTIONS clean"   ;;
	-C|--config|--configure|config|configure)    ACTIONS="$ACTIONS config"  ;;
	-b|--build|--compile|build|compile)          ACTIONS="$ACTIONS build"   ;;
	--test|--tests|--testing|test|tests|testing) ACTIONS="$ACTIONS test"    ;;
	-p|--pack|--package|pack|package)            ACTIONS="$ACTIONS pack"    ;;
	-i|--ide|ide)                                ACTIONS="$ACTIONS ide"     ;;

	--cb)    ACTIONS="$ACTIONS config build"                  ;;
	--cbp)   ACTIONS="$ACTIONS config build pack"             ;;
	--ccb)   ACTIONS="$ACTIONS clean config build"            ;;
	--cbtp)  ACTIONS="$ACTIONS config build test pack"        ;;
	--ccbp)  ACTIONS="$ACTIONS clean config build pack"       ;;
	--ccbtp) ACTIONS="$ACTIONS clean config build test pack"  ;;

	-v|--verbose)  VERBOSE=$YES  ;;
	-q|--quiet)    QUIET=$YES    ;;
	--color|--colors)       NO_COLORS=$NO  ; enable_colors  ;;
	--no-color|--no-colors) NO_COLORS=$YES ; disable_colors ;;
	-V|--version)  DisplayVersion   ; exit 1  ;;
	-h|--help)     DisplayHelp $YES ; exit 1  ;;

	-*)
		failure "Unknown flag: $1"
		failure ; DisplayHelp $NO
		exit 1
	;;
	*)
		failure "Unknown argument: $1"
		failure ; DisplayHelp $NO
		exit 1
	;;

	esac
	\shift
done



# default target path
if [[ -z $TARGET_PATH ]]; then
	TARGET_PATH="$WDIR/target"
fi

if [[ $QUIET -ne $YES ]]; then
	did_notice=$NO
	if [[ $IS_DRY -eq $YES ]]; then
		notice "Dry-run"
		did_notice=$YES
	fi
	if [[ $DEBUG_FLAGS -eq $YES ]]; then
		notice "Enable debug flags"
		did_notice=$YES
	fi
#	if [[ $DO_AUTO -eq $YES ]]; then
#		notice "Auto Mode"
#		did_notice=$YES
#		if [[ $DEBUG_FLAGS -eq $YES ]]; then
#			warning "Production mode and debug mode are active at the same time"
#		fi
#	elif [[ $BUILD_RELEASE -eq $YES ]]; then
#		notice "Production Mode"
#		did_notice=$YES
#		if [[ $DEBUG_FLAGS -eq $YES ]]; then
#			warning "Production mode and debug mode are active at the same time"
#		fi
#	fi
	if [[ $DO_PACK -eq $YES ]]; then
		notice "Deploy to: $TARGET_PATH"
		did_notice=$YES
	fi
	if [[ ! -z $PROJECT_FILTERS ]]; then
		did_notice=$YES
		if [[ "$PROJECT_FILTERS" == " "*" "* ]]; then
			notice "Filters:"
			for FILTER in $PROJECT_FILTERS; do
				notice "  ${COLOR_BLUE}${FILTER##*/}${COLOR_RESET}"
			done
		else
			notice "Filter:${COLOR_BLUE}${PROJECT_FILTERS}${COLOR_RESET}"
		fi
	fi
	[[ $did_notice -eq $YES ]] && echo
fi



if [[ ! -f "$WDIR/xbuild.conf" ]]; then
	failure "xbuild.conf not found here"
	failure ; exit 1
fi
LoadConf "$WDIR/xbuild.conf"



if [[ $QUIET -eq $NO ]]; then
	echo -e " ${COLOR_GREEN}===============================================${COLOR_RESET}"
fi
XBUILD_FAILED=$NO
# unknown filter
FILTERED_NOT_FOUND=$NO
for FILTER in $PROJECT_FILTERS; do
	if [[ " $PROJECT_FILTERS_FOUND " != *" $FILTER "* ]]; then
		FILTERED_NOT_FOUND=$YES
		XBUILD_FAILED=$YES
		warning "Project not found: $FILTER"
	fi
done
# unknown action
ACTION_NOT_FOUND=$NO
for ACT in $ACTIONS; do
	if [[ " $ACTIONS_DONE " != *" $ACT "* ]]; then
		ACTION_NOT_FOUND=$YES
		XBUILD_FAILED=$YES
		warning "Unknown action: $ACT"
	fi
done
# did nothing
if [[ $QUIET -eq $NO ]]; then
	if [[ $COUNT_ACT -le 0 ]]; then
		XBUILD_FAILED=$YES
		warning "No actions performed"
	fi
fi
if [[ $XBUILD_FAILED -eq $YES ]]; then
	warning
fi



echo -ne " ${COLOR_GREEN}Performed $COUNT_ACT operation"
[[ $COUNT_ACT -gt 1 ]] && echo -n "s"
[[ $COUNT_PRJ -gt 1 ]] && echo -ne " on $COUNT_PRJ projects"
echo -e "${COLOR_RESET}"

TIME_END=$(date +%s%N)
ELAPSED=$( echo "scale=3;($TIME_END - $TIME_START) / 1000 / 1000 / 1000" | \bc )
[[ "$ELAPSED" == "."* ]] && ELAPSED="0$ELAPSED"
echo -e " ${COLOR_GREEN}Finished in $ELAPSED seconds${COLOR_RESET}"
echo

if [[ ! -z $PACKAGES_ALL ]]; then
	echo -e " ${COLOR_BLUE}Packages finished:${COLOR_RESET}"
	for ENTRY in ${PACKAGES_ALL[@]}; do
		echo -e "   ${COLOR_BLUE}"${ENTRY##*/}"${COLOR_RESET}"
	done
	echo
fi

if [[ $XBUILD_FAILED -eq $YES ]]; then
	exit 1
fi
exit 0
