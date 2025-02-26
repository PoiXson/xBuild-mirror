#!/usr/bin/bash
## ================================================================================
##  xBuild
## Copyright (c) 2019-2025 Mattsoft/PoiXson
## <https://mattsoft.net> <https://poixson.com>
## Released under the AGPL 3.0 + ADD-PXN-V1
##
## Description: Auto compile a project and build rpms
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
# xbuild.sh
XBUILD_VERSION="{{{VERSION}}}"



BUILD_STAGES_PATH="/etc/xbuild/stages"



echo
SELF="$0"
source  "/usr/bin/pxn/scripts/common.sh"  || exit 1



function DisplayHelp() {
	local FULL=$1
	echo -e "${COLOR_BROWN}Usage:${COLOR_RESET}"
	echo    "  xbuild [options] <group>"
	echo
	echo -e "${COLOR_BROWN}Options:${COLOR_RESET}"
	echo -e "  ${COLOR_GREEN}-r, --recursive${COLOR_RESET}           Recursively load xbuild.conf files"
	if [[ $FULL -eq $YES ]]; then
	echo -e "  ${COLOR_GREEN}-R, --not-recursive${COLOR_RESET}       Don't recursively load xbuild.conf files"
	fi
	echo -e "  ${COLOR_GREEN}-n, --build-number <n>${COLOR_RESET}    Build number to use for builds and packages"
	if [[ $FULL -eq $YES ]]; then
	echo -e "  ${COLOR_GREEN}-d, --debug-flags${COLOR_RESET}         Build with debug flags"
	echo -e "  ${COLOR_GREEN}--target <path>${COLOR_RESET}           Sets the destination path for finished binaries"
	echo                                "                              default: target/"
	echo -e "  ${COLOR_GREEN}-F, --filter <project>${COLOR_RESET}    Skip all projects except these"
	echo
	echo -e "  ${COLOR_GREEN}--deb${COLOR_RESET}                     Build .deb packages with alien"
	echo -e "  ${COLOR_GREEN}--no-deb${COLOR_RESET}                  Skip building .deb packages"
	fi
	echo
	echo -e "  ${COLOR_GREEN}--pp, --pull-push${COLOR_RESET}         Run git clone/pull/push"
	echo -e "  ${COLOR_GREEN}--pull${COLOR_RESET}                    Run git pull"
	echo -e "  ${COLOR_GREEN}--push${COLOR_RESET}                    Run git push"
	echo -e "  ${COLOR_GREEN}--gg, --git-gui${COLOR_RESET}           Open git-gui for each project"
	echo
	echo -e "  ${COLOR_GREEN}-c, --clean, --cleanup${COLOR_RESET}    Cleanup workspace; delete generated files"
	echo -e "  ${COLOR_GREEN}-C, --config, --configure${COLOR_RESET} Configure projects, with autotools or composer"
	echo -e "  ${COLOR_GREEN}-b, --build, --compile${COLOR_RESET}    Compile the projects"
	[[ $FULL -eq $YES ]] && \
	echo -e "  ${COLOR_GREEN}--tests${COLOR_RESET}                   Compile and run tests for the project"
	echo -e "  ${COLOR_GREEN}-p, --pack, --package${COLOR_RESET}     Build distributable packages"
	if [[ $FULL -eq $YES ]]; then
	echo -e "  ${COLOR_GREEN}-u, --super-clean${COLOR_RESET}         Remove more files than a simple clean"
	echo
	echo -e "  ${COLOR_GREEN}--cb${COLOR_RESET}                      Config, build"
	echo -e "  ${COLOR_GREEN}--cbp${COLOR_RESET}                     Config, build, pack"
	echo -e "  ${COLOR_GREEN}--ccb${COLOR_RESET}                     Clean, config, build"
	echo -e "  ${COLOR_GREEN}--cbtp${COLOR_RESET}                    Config, build, test, pack"
	echo -e "  ${COLOR_GREEN}--ccbp${COLOR_RESET}                    Clean, config, build, pack"
	echo -e "  ${COLOR_GREEN}--ccbtp${COLOR_RESET}                   Clean, config, build, test, pack"
	echo
	echo -e "  ${COLOR_GREEN}--ci <n>${COLOR_RESET}                  Detect if the latest git commit is a tag"
	echo                                "                              and sets flags commonly used for continuous integration"
	echo                                "                              Shortcut to: -v -r -n <n> --deb --clean --build --test --pack"
	echo
	fi
	echo -e "  ${COLOR_GREEN}-D, --dry${COLOR_RESET}                 Dry-run, no changes will be performed by actions"
	echo -e "  ${COLOR_GREEN}-v, --verbose${COLOR_RESET}             Enable debug logs"
	if [[ $FULL -eq $YES ]]; then
	echo -e "  ${COLOR_GREEN}-q, --quiet${COLOR_RESET}               Hide extra logs"
	echo -e "  ${COLOR_GREEN}--colors${COLOR_RESET}                  Enable console colors"
	echo -e "  ${COLOR_GREEN}--no-colors${COLOR_RESET}               Disable console colors"
	echo -e "  ${COLOR_GREEN}-V, --version${COLOR_RESET}             Display the version"
	fi
	echo -e "  ${COLOR_GREEN}-h, --help${COLOR_RESET}                Display this help message and exit"
	[[ $FULL -eq $NO ]] && \
	echo -e " ${COLOR_BLUE}truncated.. use --help for more flags${COLOR_RESET}"
	echo
	exit 1
}

function DisplayVersion() {
	echo -e "${COLOR_BROWN}xBuild${COLOR_RESET} ${COLOR_GREEN}$XBUILD_VERSION${COLOR_RESET}"
	echo
}



# ----------------------------------------



ACTIONS=""
ACTIONS_FOUND=""
VERBOSE=$NO
QUIET=$NO
NO_COLORS=$NO
DO_RECURSIVE=$NO
DO_ALIEN=$NO
DO_CI=$NO
DO_SUPER_CLEAN=$NO
IS_DRY=$NO
DEBUG_FLAGS=$NO

BUILD_NUMBER=""
TARGET_PATH=""
PROJECT_FILTERS=""
PROJECT_FILTERS_FOUND=""
PACKAGES_ALL=()
XBUILD_FAILED=$NO

# project vars
PROJECT_NAME="<NULL>"
PROJECT_PATH=""
PROJECT_REPO=""
PROJECT_VERSION=""
PROJECT_RELEASE=$NO
PROJECT_GITIGNORE=""
PROJECT_GITIGNOREEND=""
PROJECT_GITATTRIB=""
PROJECT_TAG_FILES=""
PROJECT_TAGS_DONE=$NO
CURRENT_PATH="$WDIR"
ALLOW_RELEASE=$NO
RUN_CONFIG=()
RUN_BUILD=()

TIME_START=$( \date "+%s%N" )
let TIME_START_PRJ=0
let TIME_LAST=0
let COUNT_PRJ=0
let COUNT_ACT=0
let RM_GROUPS=0
let RM_TOTAL=0



function DisplayTime() {
	[[ $QUIET -eq $YES ]] && return
	local TIME_CURRENT=$( \date "+%s%N" )
	local ELAPSED=$( echo "scale=3;($TIME_CURRENT - $TIME_LAST) / 1000 / 1000 / 1000" | bc )
	[[ "$ELAPSED" == "."* ]] && \
		ELAPSED="0$ELAPSED"
	echo -e " ${COLOR_CYAN}$1 in ${COLOR_GREEN}${ELAPSED}${COLOR_CYAN} seconds${COLOR_RESET}"
	echo
	TIME_LAST=$TIME_CURRENT
}
function DisplayTimeProject() {
	[[ $QUIET -eq $YES ]] && return
	local TIME_CURRENT=$( \date "+%s%N" )
	local ELAPSED=$( echo "scale=3;($TIME_CURRENT - $TIME_START_PRJ) / 1000 / 1000 / 1000" | bc )
	[[ "$ELAPSED" == "."* ]] && \
		ELAPSED="0$ELAPSED"
	echo -e " ${COLOR_CYAN}Finished project in ${COLOR_GREEN}${ELAPSED}${COLOR_CYAN} seconds: ${PROJECT_NAME}${COLOR_RESET}"
	echo -e " ${COLOR_CYAN}--------------------------------------------------${COLOR_RESET}"
	echo
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
function AddIgnoreEnd() {
	if [[ -z $1 ]]; then
		failure "AddIgnoreEnd value is missing for project: $PROJECT_NAME"
		failure ; exit 1
	fi
	PROJECT_GITIGNOREEND="$PROJECT_GITIGNOREEND $1"
}
function AddGitAttrib() {
	if [[ -z $1 ]]; then
		failure "AddGitAttrib value is missing for project: $PROJECT_NAME"
		failure ; exit 1
	fi
	PROJECT_GITATTRIB="$PROJECT_GITATTRIB $1"
}



function RunConfig() {
	if [[ ! -z $1 ]]; then
		RUN_CONFIG+=("$*")
	fi
}
function RunBuild() {
	if [[ ! -z $1 ]]; then
		RUN_BUILD+=("$*")
	fi
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



function doClean() {
	local RM_FILES=$YES
	local RM_DIRS=$YES
	let COUNT=0
	while [ $# -gt 0 ]; do
		case "$1" in
		-f) RM_FILES=$NO  ;;
		-F) RM_FILES=$YES ;;
		-d) RM_DIRS=$NO   ;;
		-D) RM_DIRS=$YES  ;;
		*)
			for ENTRY in $1; do
				# file
				if [[ $RM_FILES -eq $YES ]]  \
				&& [[ -f "$ENTRY"        ]]; then
					echo_cmd -n "rm $ENTRY"
					if [[ $IS_DRY -eq $NO ]]; then
						local c=$( \rm -fv "$ENTRY" | \wc -l )
						[[ 0 -ne $? ]] && exit 1
						[[ $c -gt 0 ]] && COUNT=$((COUNT+c))
						echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
					else
						local c=$( \ls -1 "$ENTRY" | \wc -l )
						[[ $c -gt 0 ]] && COUNT=$((COUNT+c))
						echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
					fi
				# dir
				elif [[ $RM_FILES -eq $YES ]]  \
				&&   [[ -d "$ENTRY"        ]]; then
					echo_cmd -n "rm -R $ENTRY"
					if [[ $IS_DRY -eq $NO ]]; then
						local c=$( \rm -Rfv "$ENTRY" | \wc -l )
						[[ 0 -ne $? ]] && exit 1
						[[ $c -gt 0 ]] && COUNT=$((COUNT+c))
						echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
					else
						local c=$( \tree "$ENTRY" | \wc -l )
						[[ $c -gt 0 ]] && COUNT=$((COUNT+c))
						echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
					fi
				fi
			done
		;;
		esac
		\shift
	done
	if [[ $COUNT -gt 0 ]]; then
		let RM_GROUPS=$((RM_GROUPS+1))
		let RM_TOTAL=$((RM_TOTAL+COUNT))
	fi
}



function Project() {
	if [[ -z $PROJECT_NAME ]]; then
		failure "Project name not set"
		failure ; exit 1
	fi
	# perform previous project
	doProject
	CleanupProjectVars
	# configure next project
	[[ ! -z $1 ]] && PROJECT_NAME="$1"
}

function doProject() {
	if [[ -z $PROJECT_NAME ]] \
	|| [[ "$PROJECT_NAME" = "<NULL>" ]]; then
		CleanupProjectVars
		return
	fi
	PROJECT_FILTERS_FOUND="$PROJECT_FILTERS_FOUND $PROJECT_NAME"
	if [[ ! -z $PROJECT_FILTERS ]]; then
		if [[ " $PROJECT_FILTERS " != *" $PROJECT_NAME "* ]]; then
			notice "Skipping filtered: $PROJECT_NAME"
			CleanupBackupVars
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
	# recursive - xbuild.conf file in sub dir
	if [[ -f "$PROJECT_PATH/xbuild.conf" ]]; then
		if [[ "$PROJECT_PATH" != "$CURRENT_PATH" ]]; then
			if [[ $DO_RECURSIVE -eq $YES ]]; then
				[[ $VERBOSE -eq $YES ]] && \
					notice "Recursive: $PROJECT_PATH"
				LoadConf "$PROJECT_PATH/xbuild.conf"
			else
				[[ $VERBOSE -eq $YES ]] && \
					notice "Skipping recursive"
			fi
			CleanupProjectVars
			return
		fi
	fi
	if [[ $QUIET -eq $NO ]]; then
		echo
		title B  "$PROJECT_NAME"
		echo
		echo -e " ${COLOR_GREEN}>${COLOR_RESET} ${COLOR_BLUE}${PROJECT_PATH}${COLOR_RESET}"
		if [[ ! -z $PROJECT_VERSION ]]; then
			local SNAPSHOT=""
			if [[ $ALLOW_RELEASE   -eq $NO ]] \
			|| [[ $PROJECT_RELEASE -eq $NO ]]; then
				SNAPSHOT="-SNAPSHOT"
			fi
			notice "Version: ${COLOR_GREEN}${PROJECT_VERSION}${SNAPSHOT}${COLOR_RESET}"
		fi
		echo
	fi
	# run build stages
	for ENTRY in $( \ls -1 -v "$BUILD_STAGES_PATH" ); do
		source "$BUILD_STAGES_PATH/$ENTRY"
	done
	# project finished
	COUNT_PRJ=$((COUNT_PRJ+1))
	DisplayTimeProject
	CleanupProjectVars
}

function CleanupProjectVars() {
	restoreProjectTags
	PROJECT_NAME="<NULL>"
	PROJECT_PATH=""
	PROJECT_REPO=""
	PROJECT_GITIGNORE=""
	PROJECT_GITIGNOREEND=""
	PROJECT_GITATTRIB=""
	PROJECT_TAG_FILES=""
	PROJECT_TAGS_DONE=$NO
	PROJECT_RELEASE=$NO
	RUN_CONFIG=()
	RUN_BUILD=()
	TIME_START_PRJ=$( \date "+%s%N" )
	TIME_LAST=$( \date "+%s%N" )
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
	local LAST_IS_RELEASE=$PROJECT_RELEASE
	CURRENT_PATH="${1%/*}"
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
	PROJECT_RELEASE=$LAST_IS_RELEASE
}



function DetectGitTag() {
	local DIR="$1"
	[[   -z  $DIR       ]] && return
	[[ ! -d "$DIR"      ]] && return
	\pushd  "$DIR/"  >/dev/null  || exit 1
		echo_cmd "git describe --tags --exact-match"
		local TAG=$( \git describe --tags --exact-match  2>/dev/null )
		local RESULT=$?
		# release
		if [[ $RESULT -eq 0 ]] \
		&& [[ ! -z $TAG ]]; then
			PROJECT_RELEASE=$YES
			PROJECT_VERSION="$TAG"
			notice "Found current tag: $TAG"
		# snapshot
		else
			PROJECT_RELEASE=$NO
			echo_cmd "git describe --tags --abbrev=0"
			TAG=$( \git describe --tags --abbrev=0  2>/dev/null )
			RESULT=$?
			if [[ $RESULT -eq 0 ]] \
			&& [[ ! -z $TAG ]]; then
				PROJECT_VERSION="$TAG"
				notice "Found last tag: $TAG"
			else
				PROJECT_VERSION="0.1.1"
				notice "Project has no tags"
				notice "Defaulting to $PROJECT_VERSION"
			fi
		fi
		echo
	\popd >/dev/null
	# snapshot version
	if [[ $ALLOW_RELEASE   -eq $NO ]] \
	|| [[ $PROJECT_RELEASE -eq $NO ]]; then
		# build number
		if [[ ! -z $BUILD_NUMBER    ]] \
		&& [[ ! -z $PROJECT_VERSION ]]; then
			local VERS="$PROJECT_VERSION"
			if [[ "$VERS" == *"-SNAPSHOT" ]]; then
				VERS=${VERS%-*}
				PROJECT_RELEASE=$NO
			fi
			if [[ "$VERS" == *"-"* ]]; then
				VERS=${VERS%-*}
			fi
			VERS=${VERS%.*}
			PROJECT_VERSION="${VERS}.${BUILD_NUMBER}"
		fi
	fi
	if [[ -z $PROJECT_VERSION ]]; then
		failure "Version not detected"
		failure ; exit 1
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
				echo_cmd "rm -f $F"
			[[ $IS_DRY -eq $NO ]] && \
				\rm -fv  "$PROJECT_PATH/$F"  || exit 1
		else
			[[ $VERBOSE -eq $YES ]] && \
				echo_cmd "mv $F ${F}.xbuild_temp"
			[[ $IS_DRY -eq $NO ]] && \
				\mv -v  "$PROJECT_PATH/$F"  "$PROJECT_PATH/${F}.xbuild_temp"  || exit 1
		fi
		[[ $VERBOSE -eq $YES ]] && \
			echo_cmd "cp ${F}.xbuild_temp $F"
		[[ $IS_DRY -eq $NO ]] && \
			\cp -v  "$PROJECT_PATH/${F}.xbuild_temp"  "$PROJECT_PATH/$F"  || exit 1
		# tags
		if [[ ! -z $PROJECT_VERSION ]]; then
			# special case for rust/cargo
			if [[ "$F" == "/Cargo.toml" ]] \
			|| [[ "$F" == "/Cargo.lock" ]]; then
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



if [[ $# -eq 0 ]]; then
	DisplayHelp $NO
	exit 1
fi
while [ $# -gt 0 ]; do
	case "$1" in

	-r|--recursive)                        DO_RECURSIVE=$YES ;;
	-R|--not-recursive)                    DO_RECURSIVE=$NO  ;;
	-D|--dry|--dry-run)                    IS_DRY=$YES       ;;
	-d|--debug|--debug-flag|--debug-flags) DEBUG_FLAGS=$YES  ;;

	-n|--build-number)
		if [[ -z $2 ]] || [[ "$2" == "-"* ]]; then
			failure "--build-number flag requires a value"
			failure ; DisplayHelp $NO ; exit 1
		fi
		\shift
		BUILD_NUMBER="$1"
	;;
	-n*) BUILD_NUMBER="${1#-n}" ;;
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

	--deb)    DO_ALIEN=$YES ;;
	--no-deb) DO_ALIEN=$NO  ;;

	--pp|--pull-push|--push-pull|pp|pull-push) ACTIONS="$ACTIONS pull-push" ;;
	--pull)                                    ACTIONS="$ACTIONS pull"      ;;
	--push)                                    ACTIONS="$ACTIONS push"      ;;
	--gg|--git-gui|gg|git-gui)                 ACTIONS="$ACTIONS git-gui"   ;;

	-c|--clean|--clear|--cleanup|clean|cleanup)  ACTIONS="$ACTIONS clean"  ;;
	-C|--config|--configure|config|configure)    ACTIONS="$ACTIONS config" ;;
	-b|--build|--compile|build|compile)          ACTIONS="$ACTIONS build"  ;;
	--test|--tests|--testing|test|tests|testing) ACTIONS="$ACTIONS test"   ;;
	-p|--pack|--package|pack|package)            ACTIONS="$ACTIONS pack"   ;;

	-u|--superclean|--super-clean|--deepclean|--deep-clean|--extraclean|--extra-clean)
		DO_SUPER_CLEAN=$YES ; ACTIONS="$ACTIONS clean" ;;

	--cb)    ACTIONS="$ACTIONS config build"                 ;;
	--cbp)   ACTIONS="$ACTIONS config build pack"            ;;
	--ccb)   ACTIONS="$ACTIONS clean config build"           ;;
	--cbtp)  ACTIONS="$ACTIONS config build test pack"       ;;
	--ccbp)  ACTIONS="$ACTIONS clean config build pack"      ;;
	--ccbtp) ACTIONS="$ACTIONS clean config build test pack" ;;

	--ci)
		if [[ -z $2 ]] || [[ "$2" == "-"* ]]; then
			failure "--ci flag requires a build number"
			failure ; DisplayHelp $NO ; exit 1
		fi
		\shift
		BUILD_NUMBER="$1"
		ACTIONS="$ACTIONS clean config build test pack"
		DO_CI=$YES ; DO_RECURSIVE=$YES ; DO_ALIEN=$YES
		VERBOSE=$YES ; ALLOW_RELEASE=$YES
	;;
	--ci=*)
		BUILD_NUMBER="${1#*=}"
		if [[ -z $BUILD_NUMBER ]]; then
			failure "--ci flag requires a build number"
			failure ; DisplayHelp $NO ; exit 1
		fi
		ACTIONS="$ACTIONS clean config build test pack"
		DO_CI=$YES ; DO_RECURSIVE=$YES ; DO_ALIEN=$YES
		VERBOSE=$YES ; ALLOW_RELEASE=$YES
	;;

	-v|--verbose) VERBOSE=$YES ;;
	-q|--quiet)   QUIET=$YES   ;;
	--color|--colors)       NO_COLORS=$NO  ; enable_colors  ;;
	--no-color|--no-colors) NO_COLORS=$YES ; disable_colors ;;
	-V|--version) DisplayVersion   ; exit 1 ;;
	-h|--help)    DisplayHelp $YES ; exit 1 ;;

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



# default target path
if [[ -z $TARGET_PATH ]]; then
	TARGET_PATH="$WDIR/target"
fi

if [[ ! -f "$WDIR/xbuild.conf" ]]; then
	failure "xbuild.conf not found here"
	failure ; exit 1
fi

did_notice=$NO
if [[ "$SELF" != "/usr/"* ]]; then
	F="$WDIR/${SELF%/*}/xbuild-stages"
	if [[ -d "$F" ]]; then
		did_notice=$YES
		BUILD_STAGES_PATH="$F"
		notice "Using local stage scripts: $F"
	fi
fi
if [[ $QUIET -ne $YES ]]; then
	if [[ $IS_DRY -eq $YES ]]; then
		did_notice=$YES
		notice "Dry-run"
	fi
	if [[ $DEBUG_FLAGS -eq $YES ]]; then
		did_notice=$YES
		notice "Enable debug flags"
	fi
	if [[ $DO_CI -eq $YES ]]; then
		did_notice=$YES
		notice "Continuous Integration Mode"
		if [[ $DEBUG_FLAGS -eq $YES ]]; then
			warning "Production mode and debug mode are active at the same time"
		fi
	fi
	if [[ " $ACTIONS " == *" pack "* ]]; then
		did_notice=$YES
		notice "Deploy to: $TARGET_PATH"
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
fi
[[ $did_notice -eq $YES ]] && echo



CleanupProjectVars



if [[ " $ACTIONS " == *" clean "* ]]; then
	[[ $QUIET -eq $NO ]] && \
		title C  "Clean"
	LAST_RM_TOTAL=$RM_TOTAL
	\pushd  "$WDIR/"  >/dev/null || return
		doClean  "target build bin run rpmbuild"
		if [[ $DO_SUPER_CLEAN -eq $YES ]]; then
			doClean  ".project .classpath .settings gradle .gradle gradlew gradlew.bat vendor"
		fi
	\popd >/dev/null
	echo
	let COUNT=$((RM_TOTAL-LAST_RM_TOTAL))
	if [[ $COUNT -gt 1 ]]; then
		echo -e " ${COLOR_CYAN}Removed ${COLOR_BLUE}${COUNT}${COLOR_CYAN} files/dirs${COLOR_RESET}"
		DisplayTime "Cleaned"
	fi
fi



# run everything
LoadConf "$WDIR/xbuild.conf"



# ----------------------------------------
# finished



if [[ $QUIET -eq $NO ]]; then
	echo -e " ${COLOR_GREEN}===============================================${COLOR_RESET}"
fi
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
	if [[ " $ACTIONS_FOUND " != *" $ACT "* ]]; then
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



echo -ne " ${COLOR_GREEN}Performed ${COLOR_BLUE}${COUNT_ACT}${COLOR_GREEN} operation"
[[ $COUNT_ACT -gt 1 ]] && echo -n "s"
[[ $COUNT_PRJ -gt 1 ]] && echo -ne " on ${COLOR_BLUE}${COUNT_PRJ}${COLOR_GREEN} projects"
echo -e "${COLOR_RESET}"

if [[ $RM_GROUPS -gt 0 ]] \
|| [[ $RM_TOTAL  -gt 0 ]]; then
	echo -e " ${COLOR_GREEN}Removed ${COLOR_BLUE}${RM_TOTAL}${COLOR_GREEN} files/dirs in ${COLOR_BLUE}${RM_GROUPS}${COLOR_GREEN} groups"
fi

TIME_END=$( \date "+%s%N" )
ELAPSED=$( echo "scale=3;($TIME_END - $TIME_START) / 1000 / 1000 / 1000" | \bc )
[[ "$ELAPSED" == "."* ]] && ELAPSED="0$ELAPSED"
echo -e " ${COLOR_GREEN}Finished in $ELAPSED seconds${COLOR_RESET}"
if [[ $IS_DRY -eq $YES ]]; then
	echo
	notice "Dry-run"
fi
if [[ " $ACTIONS " == *" pack "* ]]; then
	did_notice=$YES
	notice "Deploy to: $TARGET_PATH"
fi
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
