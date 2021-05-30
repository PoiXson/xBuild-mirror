#!/usr/bin/bash
##===============================================================================
## Copyright (c) 2019-2021 PoiXson, Mattsoft
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
## =============================================================================
# xbuild.sh

source /usr/bin/pxn/scripts/common.sh  || exit 1



if [ -z $WDIR ]; then
	echo
	failure "Failed to find current working directory"
	echo
	exit 1
fi



function DisplayHelp() {
	echo -e "${COLOR_BROWN}Usage:${COLOR_RESET}"
	echo    "  xbuild [options] <group>"
	echo
	echo -e "${COLOR_BROWN}Workspace Groups:${COLOR_RESET}"
	let count=0
	for FILE in $( \ls -1v "$WDIR/"*.dev 2>/dev/null | \sort --version-sort ); do
		NAME="${FILE%%.dev}"
		NAME="${NAME##*/}"
		echo -e "  ${COLOR_GREEN}$NAME${COLOR_RESET}"
		count=$((count+1))
	done
	if [[ $count -eq 0 ]]; then
		echo "  No .dev or build.conf files found here"
	fi
	echo
	echo -e "${COLOR_BROWN}Options:${COLOR_RESET}"
	echo -e "  ${COLOR_GREEN}-a, --all${COLOR_RESET}                 Use all .dev files found"
	echo -e "  ${COLOR_GREEN}--binonly${COLOR_RESET}                 Build binary projects only"
	echo -e "  ${COLOR_GREEN}--webonly${COLOR_RESET}                 Build web projects only"
	echo
	echo -e "  ${COLOR_GREEN}-c, --clean, --cleanup${COLOR_RESET}    Cleanup workspace; delete generated files"
	echo
	echo -e "  ${COLOR_GREEN}--pp, --pull-push${COLOR_RESET}         Run 'git pull' and 'git push'"
	echo -e "  ${COLOR_GREEN}--gg, --git-gui${COLOR_RESET}           Open git-gui for each project"
	echo
	echo -e "  ${COLOR_GREEN}--config, --configure${COLOR_RESET}     Configure projects, with autotools or composer"
	echo -e "  ${COLOR_GREEN}--build, --compile${COLOR_RESET}        Compile the projects"
	echo -e "  ${COLOR_GREEN}-d, --debug-flags${COLOR_RESET}         Build with debug flags"
	echo -e "  ${COLOR_GREEN}-n, --build-number${COLOR_RESET}        Build number to use for builds and packages"
	echo -e "  ${COLOR_GREEN}--tests${COLOR_RESET}                   Compile and run tests for the project"
	echo -e "  ${COLOR_GREEN}--dist, --distribute${COLOR_RESET}      Build distributable packages"
	echo -e "  ${COLOR_GREEN}--deploy <path>${COLOR_RESET}           Sets the destination path for finished binaries"
	echo
	echo -e "  ${COLOR_GREEN}-D, --dry${COLOR_RESET}                 Dry-run, no changes will be performed by actions"
	echo -e "  ${COLOR_GREEN}-v, --verbose${COLOR_RESET}             Enable debug logs"
	echo -e "  ${COLOR_GREEN}-h, --help${COLOR_RESET}                Display this help message and exit"
	echo
	exit 1
}



# parse args
echo
if [[ $# -eq 0 ]]; then
	DisplayHelp
	exit 1
fi
DEV_FILES=""
DO_ALL=$NO
ONLY_BIN=$NO
ONLY_WEB=$NO
DO_CLEAN=$NO
DO_PP=$NO
DO_GG=$NO
DO_CONFIG=$NO
DO_BUILD=$NO
DO_TESTS=$NO
DO_DIST=$NO
DEPLOY_PATH=""
IS_DRY=$NO
BUILD_NUMBER=""
DEBUG_FLAGS=$NO
VERBOSE=$NO
while [ $# -gt 0 ]; do
	case "$1" in
	# all project groups
	-a|--all)
		DO_ALL=$YES
	;;
	# build binary projects only
	--binonly)
		ONLY_BIN=$YES
	;;
	# build web projects only
	--webonly)
		ONLY_WEB=$YES
	;;
	# cleanup
	-c|--clean|--cleanup)
		DO_CLEAN=$YES
	;;
	# git pull/push
	--pp|--pull-push|--push-pull)
		DO_PP=$YES
	;;
	# git-gui
	--gg|--git-gui)
		DO_GG=$YES
	;;
	# --configure
	--config|--configure)
		DO_CONFIG=$YES
	;;
	# --build
	--build|--compile)
		DO_BUILD=$YES
	;;
	# debug flags
	-d|--debug-flag|--debug-flags)
		DEBUG_FLAGS=$YES
	;;
	# build number
	-n|--build-number)
		\shift
		BUILD_NUMBER="$1"
	;;
	--build-number=*)
		BUILD_NUMBER="${1#*=}"
	;;
	# build tests
	--test|--tests|--testing)
		DO_TESTS=$YES
	;;
	# make distributable packages
	--dist|--distribute)
		DO_DIST=$YES
	;;
	# deploy finished binaries
	--deploy)
		shift
		DEPLOY_PATH="$1"
	;;
	# dry mode
	-D|--dry)
		IS_DRY=$YES
	;;
	# verbose logging
	-v|--verbose)
		VERBOSE=$YES
	;;
	# display help
	-h|--help)
		DisplayHelp
		exit 1
	;;
	-*)
		failure "Unknown argument: $1"
		echo
		DisplayHelp
		exit 1
	;;
	*)
		if [[ -f "$WDIR/$1" ]]; then
			DEV_FILES="$DEV_FILES $WDIR/$1"
		elif [[ -f "$WDIR/${1}.dev" ]]; then
			DEV_FILES="$DEV_FILES $WDIR/${1}.dev"
		else
			FILE=$( \ls -1v "$WDIR/"*"-${1}.dev" 2>/dev/null | \sort --version-sort | \head -n1 )
			if [[ ! -z $FILE ]]; then
				DEV_FILES="$DEV_FILES $FILE"
			else
				COUNT=$( \ls -1 "$WDIR/"*.dev 2>/dev/null | \wc -l )
				if [[ $COUNT -eq 0 ]]; then
					failure "No project group .dev files found here"
				else
					failure "Unknown project group: $1"
				fi
				echo
				exit 1
			fi
		fi
	;;
	esac
	\shift
done



if [[ -z $DEPLOY_PATH ]]; then
	DEPLOY_PATH="$WDIR/target"
fi



did_notice=$NO
if [[ $IS_DRY -eq $YES ]]; then
	notice "Dry-run"
	did_notice=$YES
fi
if [[ $DEBUG_FLAGS -eq $YES ]]; then
	notice "Enable debug flags"
	did_notice=$YES
fi
if [[ $DO_DIST -eq $YES ]]; then
	notice "Deploy to: $DEPLOY_PATH"
	did_notice=$YES
fi
[[ $did_notice -eq $YES ]] && echo
if [[ $DO_ALL -eq $YES ]]; then
	DEV_FILES=$( \ls -1v "$WDIR/"*.dev 2>/dev/null | \sort --version-sort )
fi
if [[ ! -z $DEV_FILES ]]; then
	echo "Using files:"
	for FILE in $DEV_FILES; do
		echo -e "  ${COLOR_GREEN}"${FILE##*/}"${COLOR_RESET}"
	done
	echo
fi



# project vars
PROJECT_NAME=""
PROJECT_PATH=""
REPO=""

let COUNT_PRJ=0
let COUNT_OPS=0

TIME_START=$( \date "+%s%N" )
let TIME_START_PRJ=0
let TIME_LAST=0



function DisplayTime() {
	TIME_CURRENT=$( \date "+%s%N" )
	ELAPSED=$( echo "scale=3;($TIME_CURRENT - $TIME_LAST) / 1000 / 1000 / 1000" | bc )
	if [[ "$ELAPSED" == "."* ]]; then
		ELAPSED="0$ELAPSED"
	fi
	echo -e " ${COLOR_CYAN}$1 in $ELAPSED seconds${COLOR_RESET}"
	echo
	TIME_LAST=$TIME_CURRENT
}
function DisplayTimeProject() {
	TIME_CURRENT=$( \date "+%s%N" )
	ELAPSED=$( echo "scale=3;($TIME_CURRENT - $TIME_START_PRJ) / 1000 / 1000 / 1000" | bc )
	if [[ "$ELAPSED" == "."* ]]; then
		ELAPSED="0$ELAPSED"
	fi
	echo -e " ${COLOR_CYAN}Finished project in $ELAPSED seconds: $PROJECT_NAME${COLOR_RESET}"
	echo
}



# --clean
function doClean() {
	title C "Clean" "$PROJECT_NAME"
	let count=0
	let rm_groups=0
	# make clean
	if [[ $ONLY_WEB -eq $NO ]]; then
		if [ -f "$PROJECT_PATH/Makefile.am" ]; then
			if [ -f "$PROJECT_PATH/Makefile" ]; then
				\pushd "$PROJECT_PATH/" >/dev/null || exit 1
					echo -ne " > ${COLOR_CYAN}make distclean..${COLOR_RESET}"
					rm_groups=$((rm_groups+1))
					if [[ $IS_DRY -eq $NO ]]; then
						c=$( \make distclean | \wc -l )
						[[ 0 -ne $? ]] && exit 1
						[[ $c -gt 0 ]] && count=$((count+c))
						echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
					else
						echo
					fi
				\popd >/dev/null
			fi
			\pushd "$PROJECT_PATH/" >/dev/null || exit 1
				# remove .deps/ dirs
				RESULT=$( \find "$PROJECT_PATH" -type d -name .deps )
				for ENTRY in $RESULT; do
					if [[ -f "$ENTRY" ]]; then
						echo -ne " > ${COLOR_CYAN}rm ${ENTRY}..${COLOR_RESET}"
						rm_groups=$((rm_groups+1))
						if [[ $IS_DRY -eq $NO ]]; then
							c=$( \rm -v "$ENTRY" | \wc -l )
							[[ 0 -ne $? ]] && exit 1
							[[ $c -gt 0 ]] && count=$((count+c))
							echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
						else
							echo
						fi
					fi
					if [[ -d "$ENTRY" ]]; then
						echo -ne " > ${COLOR_CYAN}rm ${ENTRY}..${COLOR_RESET}"
						rm_groups=$((rm_groups+1))
						if [[ $IS_DRY -eq $NO ]]; then
							c=$( \rm -vrf --preserve-root "$ENTRY" | \wc -l )
							[[ 0 -ne $? ]] && exit 1
							[[ $c -gt 0 ]] && count=$((count+c))
							echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
						else
							echo
						fi
					fi
				done
				# remove more files
				CLEAN_PATHS=". src"
				CLEAN_FILES="autom4te.cache aclocal.m4 compile configure config.log config.guess config.status config.sub depcomp install-sh ltmain.sh Makefile Makefile.in missing"
				for DIR in $CLEAN_PATHS; do
					\pushd "$DIR/" >/dev/null || continue
						for ENTRY in $CLEAN_FILES; do
							if [[ -f "$ENTRY" ]]; then
								c=$( \rm -v "$ENTRY" | \wc -l )
								[[ 0 -ne $? ]] && exit 1
								[[ $c -gt 0 ]] && count=$((count+c))
							fi
							if [[ -d "$ENTRY" ]]; then
								c=$( \rm -vrf --preserve-root "$ENTRY" | \wc -l )
								[[ 0 -ne $? ]] && exit 1
								[[ $c -gt 0 ]] && count=$((count+c))
							fi
						done
					\popd >/dev/null
				done
			\popd >/dev/null
		fi
		# clean rpm project
		if [ -d "$PROJECT_PATH/rpmbuild" ]; then
			\pushd "$PROJECT_PATH/" >/dev/null || exit 1
				echo -ne " > ${COLOR_CYAN}rm rpmbuild..${COLOR_RESET}"
				rm_groups=$((rm_groups+1))
				if [[ $IS_DRY -eq $NO ]]; then
					c=$( \rm -vrf --preserve-root rpmbuild | wc -l )
					[[ 0 -ne $? ]] && exit 1
					[[ $c -gt 0 ]] && count=$((count+c))
					echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
				else
					echo
				fi
			\popd >/dev/null
		fi
	fi
	# clean php project
	if [[ $ONLY_BIN -eq $NO ]]; then
		if [ -f "$PROJECT_PATH/composer.json" ]; then
			if [ -d "$PROJECT_PATH/vendor" ]; then
				\pushd "$PROJECT_PATH/" >/dev/null || exit 1
					echo -ne " > ${COLOR_CYAN}rm vendor..${COLOR_RESET}"
					rm_groups=$((rm_groups+1))
					if [[ $IS_DRY -eq $NO ]]; then
						c=$( \rm -vrf --preserve-root vendor | wc -l )
						[[ 0 -ne $? ]] && exit 1
						[[ $c -gt 0 ]] && count=$((count+c))
						echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
					else
						echo
					fi
				\popd >/dev/null
			fi
		fi
	fi
	# nothing to do
	if [[ $count -gt 0 ]]; then
		echo
		if [[ $rm_groups -gt 1 ]]; then
			echo "Removed $count files"
		fi
		DisplayTime "Cleaned"
	elif [[ $rm_groups -le 0 ]]; then
		notice "Nothing to clean.."
		echo
	fi
	COUNT_OPS=$((COUNT_OPS+1))
}



# --pp
function doPullPush() {
	# clone repo
	if [[ ! -e "$PROJECT_PATH" ]]; then
		if [[ -z $REPO ]]; then
			failure "Project repo not set: $PROJECT_NAME"
			exit 1
		fi
		title C "Clone" "$PROJECT_NAME"
		echo "Path: $PROJECT_PATH"
		echo
		\pushd "$WDIR/" >/dev/null  || exit 1
			# git clone
			echo -e " > ${COLOR_CYAN}git clone ${REPO}${COLOR_RESET}"
			if [[ $IS_DRY -eq $NO ]]; then
				\git clone "$REPO" "$PROJECT_NAME"  || exit 1
			fi
			echo
		\popd >/dev/null
		COUNT_OPS=$((COUNT_OPS+1))
		return
	fi
	if [[ ! -d "$PROJECT_PATH/.git" ]]; then
		notice ".git/ not found, skipping"
	fi
	title C "Pull/Push" "$PROJECT_NAME"
	echo "Path: $PROJECT_PATH"
	echo
	\pushd "$PROJECT_PATH/" >/dev/null  || exit 1
		# git pull
		echo -e " > ${COLOR_CYAN}git pull${COLOR_RESET}"
		if [[ $IS_DRY -eq $NO ]]; then
			\git pull  || exit 1
			echo
		fi
		# git push
		echo -e " > ${COLOR_CYAN}git push${COLOR_RESET}"
		if [[ $IS_DRY -eq $NO ]]; then
			\git push  || exit 1
			echo
		fi
	\popd >/dev/null
	COUNT_OPS=$((COUNT_OPS+1))
}



# --gg
function doGitGUI() {
	if [[ ! -d "$PROJECT_PATH/.git" ]]; then
		return
	fi
	# git-gui
	\pushd "$WDIR/$PROJECT_NAME/" >/dev/null  || exit 1
		echo -ne " > ${COLOR_CYAN}git-gui${COLOR_RESET}"
		if [[ $IS_DRY -eq $NO ]]; then
			/usr/libexec/git-core/git-gui &
			GG_PID=$!
			echo -e " ${COLOR_BLUE}$GG_PID${COLOR_RESET}"
			\sleep 0.2
		else
			echo
		fi
		echo
	\popd >/dev/null
	COUNT_OPS=$((COUNT_OPS+1))
}



function doConfig() {
	did_something=$NO
#	# run make-symlinks.sh if exists
#	if [ -f "$PROJECT_PATH/make-symlinks.sh" ]; then
#		title C "Make Symlinks"
#		echo "Path: $PROJECT_PATH"
#		\pushd "$PROJECT_PATH/" >/dev/null || exit 1
#			sh  "$PROJECT_PATH/make-symlinks.sh"  || exit 1
#		\popd >/dev/null
#		echo
#	fi
	if [[ $ONLY_WEB -eq $NO ]]; then
		# generate automake files
		if [ -f "$PROJECT_PATH/autotools.conf" ]; then
			title C "genautotools" "$PROJECT_NAME"
			echo "Path: $PROJECT_PATH"
			echo
			\pushd "$PROJECT_PATH/" >/dev/null || exit 1
				echo -e " > ${COLOR_CYAN}genautotools${COLOR_RESET}"
				if [[ $IS_DRY -eq $NO ]]; then
					\genautotools  || exit 1
				fi
			\popd >/dev/null
		fi
		# automake
		if [ -f "$PROJECT_PATH/configure.ac" ]; then
			title C "Configure" "$PROJECT_NAME"
			echo "Path: $PROJECT_PATH"
			\pushd "$PROJECT_PATH/" >/dev/null || exit 1
				echo -e " > ${COLOR_CYAN}autoreconf -v --install${COLOR_RESET}"
				if [[ $IS_DRY -eq $NO ]]; then
					\autoreconf -v --install  || exit 1
				fi
			\popd >/dev/null
			echo
			did_something=$YES
		fi
	fi
	if [[ $ONLY_BIN -eq $NO ]]; then
		# composer
		if [ -f "$PROJECT_PATH/composer.json" ]; then
			\pushd "$PROJECT_PATH/" >/dev/null || exit 1
				if [[ $DEBUG_FLAG -eq $YES ]] \
				|| [[ ! -f "$PROJECT_PATH/composer.lock" ]]; then
					title C "Composer Update"
					echo "Path: $PROJECT_PATH"
					echo -e " > ${COLOR_CYAN}composer update${COLOR_RESET}"
					if [[ $IS_DRY -eq $NO ]]; then
						\composer update  || exit 1
					fi
				else
					title C "Composer Install"
					echo "Path: $PROJECT_PATH"
					echo -e " > ${COLOR_CYAN}composer install${COLOR_RESET}"
					if [[ $IS_DRY -eq $NO ]]; then
						\composer install  || exit 1
					fi
				fi
			\popd >/dev/null
			echo
			did_something=$YES
		fi
	fi
	# nothing to do
	if [ $did_something -eq $YES ]; then
		DisplayTime "Configured"
		COUNT_OPS=$((COUNT_OPS+1))
	else
		notice "Nothing found to configure.."
		echo
	fi
}



function doBuild() {
	did_something=$NO
	title C "Build" "$PROJECT_NAME"
	echo "Path: $PROJECT_PATH"
	echo
	# automake
	if [[ $ONLY_WEB -eq $NO ]]; then
		if [ -f "$PROJECT_PATH/configure" ]; then
			\pushd "$PROJECT_PATH/" >/dev/null || exit 1
				CONFIGURE_DEBUG_FLAG=""
				if [[ $DEBUG_FLAGS -eq $YES ]]; then
					CONFIGURE_DEBUG_FLAG="--enable-debug"
				fi
				echo -e " > ${COLOR_CYAN}configure ${CONFIGURE_DEBUG_FLAG}${COLOR_RESET}"
				if [[ $IS_DRY -eq $NO ]]; then
					./configure $CONFIGURE_DEBUG_FLAG  || exit 1
				fi
			\popd >/dev/null
			echo
			did_something=$YES
		fi
		# make
		if [ -f "$PROJECT_PATH/Makefile" ]; then
			\pushd "$PROJECT_PATH/" >/dev/null || exit 1
				echo -e " > ${COLOR_CYAN}make${COLOR_RESET}"
				if [[ $IS_DRY -eq $NO ]]; then
					\make  || exit 1
				fi
			\popd >/dev/null
			echo
			did_something=$YES
		fi
		# maven
		if [ -f "$PROJECT_PATH/pom.xml" ]; then
			\pushd "$PROJECT_PATH/" >/dev/null || exit 1
				echo -e " > ${COLOR_CYAN}mvn clean install${COLOR_RESET}"
				if [[ $IS_DRY -eq $NO ]]; then
					\mvn clean install  || exit 1
				fi
			\popd >/dev/null
			echo
			did_something=$YES
		fi
	fi
	# nothing to do
	if [[ $did_something -eq $YES ]]; then
		DisplayTime "Built"
		COUNT_OPS=$((COUNT_OPS+1))
	else
		notice "Nothing found to build.."
		echo
	fi
}



function doTests() {
	did_something=$NO
	title C "Testing" "$PROJECT_NAME"
	echo "Path: $PROJECT_PATH"
	echo
	# make check
	if [ -f "$PROJECT_PATH/Makefile" ]; then
		\pushd "$PROJECT_PATH/" >/dev/null || exit 1
			echo -e " > ${COLOR_CYAN}make check${COLOR_RESET}"
			if [[ $IS_DRY -eq $NO ]]; then
				\make check  || exit 1
			fi
		\popd >/dev/null
		echo
#TODO: exec test program
		did_something=$YES
	fi
	# phpunit
	if [ -f "$PROJECT_PATH/phpunit.xml" ]; then
		\pushd "$PROJECT_PATH/" >/dev/null || exit 1
			echo -e " > ${COLOR_CYAN}phpunit${COLOR_RESET}"
			if [[ $IS_DRY -eq $NO ]]; then
				\phpunit  || exit 1
			fi
		\popd >/dev/null
		echo
		did_something=$YES
	fi
	# nothing to do
	if [[ $did_something -eq $YES ]]; then
		DisplayTime "Tested"
		COUNT_OPS=$((COUNT_OPS+1))
	else
		notice "Nothing found to test.."
		echo
	fi
}



function doDist() {
	did_something=$NO
	title C "Package" "$PROJECT_NAME"
	echo "Path: $PROJECT_PATH"
	echo
	# make dist
	if [ -f "$PROJECT_PATH/Makefile" ]; then
		\pushd "$PROJECT_PATH/" >/dev/null || exit 1
			echo -e " > ${COLOR_CYAN}make dist${COLOR_RESET}"
			if [[ $IS_DRY -eq $NO ]]; then
				\make dist  || exit 1
			fi
		\popd >/dev/null
		echo
		did_something=$YES
	fi
	# find .spec file
	SPEC_FILE_COUNT=$( \ls -1 "$PROJECT_PATH/"*.spec 2>/dev/null | \wc -l )
	if [ $SPEC_FILE_COUNT -gt 1 ]; then
		failure "$SPEC_FILE_COUNT .spec files were found here"
		exit 1
	fi
	SPEC_FILE=""
	SPEC_NAME=""
	if [ $SPEC_FILE_COUNT -eq 1 ]; then
		SPEC_FILE=$( \ls -1 "$PROJECT_PATH/"*.spec )
		SPEC_NAME="${SPEC_FILE%.*}"
		SPEC_NAME="${SPEC_NAME##*/}"
	fi
	# build rpm
	if [ ! -z $SPEC_FILE ]; then
		# remove previous build root
		if [ -d "$PROJECT_PATH/rpmbuild" ]; then
			echo -ne " > ${COLOR_CYAN}rm rpmbuild..${COLOR_RESET}"
			\pushd "$PROJECT_PATH" >/dev/null  || exit 1
				c=$( \rm -Rvf --preserve-root rpmbuild/ | \wc -l )
				[[ 0 -ne $? ]] && exit 1
				echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
			\popd >/dev/null
		fi
		# make build root dirs
		echo -ne " > ${COLOR_CYAN}mkdir rpmbuild..${COLOR_RESET}"
		c=$( \mkdir -pv "$PROJECT_PATH"/rpmbuild/{BUILD,BUILDROOT,SOURCES,SPECS,RPMS,SRPMS,TMP} | \wc -l )
		[[ 0 -ne $? ]] && exit 1
		echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
		if [[ $IS_DRY -eq $NO ]]; then
			\cp -vf  "$SPEC_FILE"  "$PROJECT_PATH/rpmbuild/SPECS/"  || exit 1
		fi
		PACKAGES=""
		\pushd "$PROJECT_PATH/rpmbuild/" >/dev/null  || exit 1
			echo -e " > ${COLOR_CYAN}rpmbuild${COLOR_RESET}"
			if [[ $IS_DRY -eq $NO ]]; then
				if [[ ! -z $DEPLOY_PATH ]]; then
					DEPLOY_PATH="$WDIR/target"
				fi
				if [[ ! -e "$DEPLOY_PATH/" ]]; then
					\mkdir -pv "$DEPLOY_PATH/"  || exit 1
				fi
				\rpmbuild \
					${BUILD_NUMBER:+ --define="build_number $BUILD_NUMBER"} \
					--define="_topdir $PROJECT_PATH/rpmbuild" \
					--define="_tmppath $PROJECT_PATH/rpmbuild/TMP" \
					--define="_binary_payload w9.gzdio" \
					--undefine=_disable_source_fetch \
					-bb "SPECS/${SPEC_NAME}.spec" \
						|| exit 1
				\pushd "$PROJECT_PATH/rpmbuild/RPMS/" >/dev/null  || exit 1
					PACKAGES=$( \ls -1 *.rpm )
				\popd >/dev/null
				if [[ -z $PACKAGES ]]; then
					failure "Failed to find finished rpm packages: $PROJECT_PATH/rpmbuild/RPMS/"
					exit 1
				fi
				PACKAGES_ALL="$PACKAGES_ALL $PACKAGES"
				for ENTRY in $PACKAGES; do
					\cp -fv  "$PROJECT_PATH/rpmbuild/RPMS/$ENTRY"  "$DEPLOY_PATH/"  || exit 1
				done
			fi
		\popd >/dev/null
		echo
		echo "-----------------------------------------------"
		echo " Packages ready for distribution:"
		for ENTRY in $PACKAGES; do
			echo "   $ENTRY"
		done
		echo "-----------------------------------------------"
		echo
		did_something=$YES
	fi
	# nothing to do
	if [[ $did_something -eq $YES ]]; then
		DisplayTime "Distributable"
		COUNT_OPS=$((COUNT_OPS+1))
	else
		notice "Nothing found to distribute.."
		echo
	fi
}



function Project() {
	if [[ ! -z $PROJECT_NAME ]]; then
		doProject
		DisplayTimeProject
	fi
	doCleanupVars
	if [[ ! -z $1 ]]; then
		PROJECT_NAME="$1"
		PROJECT_PATH="$WDIR/$PROJECT_NAME"
	fi
}
function Repo() {
	if [[ ! -z $1 ]]; then
		REPO="$1"
	fi
}

function doCleanupVars() {
	PROJECT_NAME=""
	PROJECT_PATH=""
	REPO=""
	TIME_START_PRJ=$( \date "+%s%N" )
	TIME_LAST=$TIME_START_PRJ
}

function doProject() {
	if [[ -z $PROJECT_NAME ]] || [[ -z $PROJECT_PATH ]]; then
		return
	fi
	echo
	title B "$PROJECT_NAME"
	echo
	# --clean
	[[ $DO_CLEAN  -eq $YES ]] && doClean
	# --pp
	[[ $DO_PP     -eq $YES ]] && doPullPush
	# --config
	[[ $DO_CONFIG -eq $YES ]] && doConfig
	# --build
	[[ $DO_BUILD  -eq $YES ]] && doBuild
	# --tests
	[[ $DO_TESTS  -eq $YES ]] && doTests
	# --dist
	[[ $DO_DIST   -eq $YES ]] && doDist
	# --gg
	[[ $DO_GG     -eq $YES ]] && doGitGUI
	# project done
	COUNT_PRJ=$((COUNT_PRJ+1))
}



if [[ $DO_CLEAN -eq $YES ]]; then
	COUNT=$( \ls -1 "$WDIR/"*.rpm 2>/dev/null | \wc -l )
	if [[ $COUNT -gt 0 ]]; then
		\rm -fv "$WDIR/"*.rpm
	fi
fi

# group.dev files
if [[ ! -z $DEV_FILES ]]; then
	doCleanupVars
	for FILE in $DEV_FILES; do
		source "$FILE"  || exit 1
		# last project in .dev file
		Project
	done

# xbuild.conf project file
elif [[ -f "$WDIR/xbuild.conf" ]]; then
	doCleanupVars
	source "$WDIR/xbuild.conf"  || exit 1
	# last project in .dev file
	Project
fi



echo
echo
echo -e "${COLOR_GREEN}===============================================${COLOR_RESET}"
echo
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

TIME_END=$(date +%s%N)
ELAPSED=$( echo "scale=3;($TIME_END - $TIME_START) / 1000 / 1000 / 1000" | \bc )
[[ "$ELAPSED" == "."* ]] && ELAPSED="0$ELAPSED"
echo -e "${COLOR_GREEN}Finished in $ELAPSED seconds${COLOR_RESET}"
echo

if [[ ! -z $PACKAGES_ALL ]]; then
	echo -e "${COLOR_BLUE} Packages ready for distribution:${COLOR_RESET}"
	for ENTRY in $PACKAGES_ALL; do
		echo -e "${COLOR_BLUE}   $ENTRY${COLOR_RESET}"
	done
	echo
fi

exit 0
