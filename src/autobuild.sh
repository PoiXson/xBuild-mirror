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
# autobuild.sh

source /usr/bin/pxn/scripts/common.sh  || exit 1



PWD=$( pwd )
if [ -z $PWD ]; then
	echo
	failure "Failed to find current working directory"
	echo
	exit 1
fi



function DisplayHelp() {
	echo -e "${COLOR_BROWN}Usage:${COLOR_RESET}"
	echo    "  autobuild [options] <actions>"
	echo
	echo -e "${COLOR_BROWN}Actions:${COLOR_RESET}"
	echo -e "  ${COLOR_GREEN}clean${COLOR_RESET}      Clean the project, removing build files"
	echo -e "  ${COLOR_GREEN}config${COLOR_RESET}     Generate files needed to build the project"
	echo -e                             "               autoreconf or composer"
	echo -e "  ${COLOR_GREEN}build${COLOR_RESET}      Compile the project; using tools such as "
	echo -e                             "               make or mvn"
	echo -e "  ${COLOR_GREEN}test${COLOR_RESET}       Perform testing"
	echo -e                             "               make check or phpunit"
	echo -e "  ${COLOR_GREEN}dist${COLOR_RESET}       Build distributable packages"
	echo -e                             "               make dist or rpmbuild"
	echo -e "  ${COLOR_GREEN}run${COLOR_RESET}        Run the application which was just built"
	echo -e                             "               anything after this is used as an argument for the app"
	echo
	echo -e "${COLOR_BROWN}Options:${COLOR_RESET}"
	echo -e "  ${COLOR_GREEN}-n, --build-number${COLOR_RESET}     Build number to use for packaging"
	echo -e "  ${COLOR_GREEN}-A, --no-multi${COLOR_RESET}         Disable use of automulti.conf"
	echo -e "  ${COLOR_GREEN}-D, --debug-flags${COLOR_RESET}      Build with debug flags"
	echo                                "                           note: defaults to 'x'"
	echo -e "  ${COLOR_GREEN}-d, --debug${COLOR_RESET}            Enable debug logs"
	echo -e "  ${COLOR_GREEN}-h, --help${COLOR_RESET}             Display this help message and exit"
	echo
	exit 1
}
did_something_session=$NO
TIME_START=0
TIME_LAST=0



function display_time() {
	TIME_CURRENT=$( \date +%s%N )
	elapsed=$( echo "scale=3;($TIME_CURRENT - $TIME_LAST) / 1000 / 1000 / 1000" | bc )
	if [[ "$elapsed" == "."* ]]; then
		elapsed="0$elapsed"
	fi
	echo -e " ${COLOR_CYAN}$1 in $elapsed seconds${COLOR_RESET}"
	echo
	TIME_LAST=$TIME_CURRENT
}



# clean
function doClean() {
	if [[ -z $1 ]]; then
		PTH="$PWD"
	else
		PTH="$PWD/$1"
	fi
	title C "Clean"
	did_something=$NO
	# make clean project
	if [ -f "$PTH/Makefile.am" ]; then
		if [ -f "$PTH/Makefile" ]; then
			\pushd "$PTH" >/dev/null || exit 1
				\make distclean
			\popd >/dev/null
			echo
			did_something=$YES
		fi
		let count=0
		\pushd "$PTH" >/dev/null || exit 1
			# remove .deps dirs
			RESULT=$( \find "$PTH" -type d -name .deps )
			for ENTRY in $RESULT; do
				[[ -f "$ENTRY" ]] && \rm -v                   "$ENTRY" && count=$((count+1))
				[[ -d "$ENTRY" ]] && \rm -vrf --preserve-root "$ENTRY" && count=$((count+1))
			done
			# remove more files
			CLEAN_PATHS=". src"
			CLEAN_FILES="autom4te.cache aclocal.m4 compile configure config.log config.guess config.status config.sub depcomp install-sh ltmain.sh Makefile Makefile.in missing"
			for DIR in $CLEAN_PATHS; do
				\pushd "$DIR" >/dev/null || continue
					for ENTRY in $CLEAN_FILES; do
						[[ -f "$ENTRY" ]] && \rm -v                   "$ENTRY" && count=$((count+1))
						[[ -d "$ENTRY" ]] && \rm -vrf --preserve-root "$ENTRY" && count=$((count+1))
					done
				\popd >/dev/null
			done
		\popd >/dev/null
		if [ $count -gt 0 ]; then
			echo
			did_something=$YES
		fi
	fi
	# clean rpm project
	if [ -d "$PTH/rpmbuild" ]; then
		\pushd "$PTH" >/dev/null || exit 1
			\rm -vrf --preserve-root rpmbuild
		\popd >/dev/null
		echo
		did_something=$YES
	fi
	# clean php project
	if [ -f "$PTH/composer.json" ]; then
		if [ -d "$PTH/vendor" ]; then
			\pushd "$PTH" >/dev/null || exit 1
				\rm -vrf --preserve-root vendor
			\popd >/dev/null
			echo
			did_something=$YES
		fi
	fi
	# nothing to do
	if [ $did_something -eq $YES ]; then
		display_time "Cleaned"
		#did_something_session=$YES
	else
		notice "Nothing to clean.."
		echo
	fi
	# clean only is ok, don't fail
	did_something_session=$YES
}



# auto configure
function doConfig() {
	if [[ -z $1 ]]; then
		PTH="$PWD"
	else
		PTH="$PWD/$1"
	fi
	if [ -f "$PTH/make-symlinks.sh" ]; then
		title C "Make Symlinks"
		\pushd "$PTH" >/dev/null || exit 1
			sh  "$PTH/make-symlinks.sh"  || exit 1
		\popd >/dev/null
		echo
	fi
	did_something=$NO
	if [ -f "$PTH/autotools.conf" ]; then
		title C "genautotools"
		\pushd "$PTH" >/dev/null || exit 1
			\genautotools
		\popd >/dev/null
		echo
	fi
	# automake
	if [ -f "$PTH/configure.ac" ]; then
		title C "Configure"
		\pushd "$PTH" >/dev/null || exit 1
			\autoreconf -v --install  || exit 1
		\popd >/dev/null
		echo
		did_something=$YES
	fi
	# composer
	if [ -f "$PTH/composer.json" ]; then
		\pushd "$PTH" >/dev/null || exit 1
		if [[ $DEBUG_FLAG -eq $YES ]] \
		|| [[ ! -f "$PTH/composer.lock" ]]; then
			title C "Composer Update"
			\composer update  || exit 1
		else
			title C "Composer Install"
			\composer install  || exit 1
		fi
		\popd >/dev/null
		echo
		did_something=$YES
	fi
	# nothing to do
	if [ $did_something -eq $YES ]; then
		display_time "Configured"
		did_something_session=$YES
	else
		notice "Nothing found to configure.."
		echo
	fi
}



# build
function doBuild() {
	if [[ -z $1 ]]; then
		PTH="$PWD"
	else
		PTH="$PWD/$1"
	fi
	title C "Build"
	did_something=$NO
	# automake
	if [ -f "$PTH/configure" ]; then
		\pushd "$PTH" >/dev/null || exit 1
			if [ $DEBUG_FLAGS -eq $YES ]; then
				./configure --enable-debug  || exit 1
			else
				./configure                 || exit 1
			fi
		\popd >/dev/null
		echo
		did_something=$YES
	fi
	# make
	if [ -f "$PTH/Makefile" ]; then
		\pushd "$PTH" >/dev/null || exit 1
			\make  || exit 1
		\popd >/dev/null
		echo
		did_something=$YES
	fi
	# maven
	if [ -f "$PTH/pom.xml" ]; then
		\pushd "$PTH" >/dev/null || exit 1
			\mvn clean install  || exit 1
		\popd >/dev/null
		echo
		did_something=$YES
	fi
	# nothing to do
	if [ $did_something -eq $YES ]; then
		display_time "Built"
		did_something_session=$YES
	else
		notice "Nothing found to build.."
		echo
	fi
}



# testing
function doTests() {
	if [[ -z $1 ]]; then
		PTH="$PWD"
	else
		PTH="$PWD/$1"
	fi
	title C "Testing"
	did_something=$NO
	# make check
	if [ -f "$PTH/Makefile" ]; then
		\pushd "$PTH" >/dev/null || exit 1
			\make check  || exit 1
		\popd >/dev/null
		echo

#TODO: exec test program

#		did_something=$YES
	fi
	# phpunit
	if [ -f "$PTH/phpunit.xml" ]; then
		\pushd "$PTH" >/dev/null || exit 1
			\phpunit  || exit 1
		\popd >/dev/null
		echo
		did_something=$YES
	fi
	# nothing to do
	if [ $did_something -eq $YES ]; then
		display_time "Tested"
		did_something_session=$YES
	else
		notice "Nothing found to test.."
		echo
	fi
}



# distribute
function doDist() {
	if [[ -z $1 ]]; then
		PTH="$PWD"
	else
		PTH="$PWD/$1"
	fi
	did_something=$NO
	# make dist
	if [ -f "$PTH/Makefile" ]; then
		title C "Distribute"
		\pushd "$PTH" >/dev/null || exit 1
			\make dist  || exit 1
		\popd >/dev/null
		echo
		did_something=$YES
	fi
	# find .spec file
	SPEC_FILE_COUNT=$( \ls -1 "$PTH/"*.spec 2>/dev/null | \wc -l )
	if [ $SPEC_FILE_COUNT -gt 1 ]; then
		failure "$SPEC_FILE_COUNT .spec files were found here"
		exit 1
	fi
	SPEC_FILE=""
	SPEC_NAME=""
	if [ $SPEC_FILE_COUNT -eq 1 ]; then
		SPEC_FILE=$( \ls -1 "$PTH/"*.spec )
		SPEC_NAME="${SPEC_FILE%%.*}"
		SPEC_NAME="${SPEC_NAME##*/}"
	fi
	# build rpm
	if [ ! -z $SPEC_FILE ]; then
		title C "RPM Build"
		\mkdir -p "$PTH"/rpmbuild/{BUILD,BUILDROOT,SOURCES,SPECS,RPMS,SRPMS,TMP}  || exit 1
		\cp -vf  "$SPEC_FILE"  "$PTH/rpmbuild/SPECS/"  || exit 1
		\pushd "$PTH/rpmbuild/" >/dev/null  || exit 1
			\rpmbuild \
				${BUILD_NUMBER:+ --define="build_number $BUILD_NUMBER"} \
				--define="_topdir $PTH/rpmbuild" \
				--define="_tmppath $PTH/rpmbuild/TMP" \
				--define="_binary_payload w9.gzdio" \
				--undefine=_disable_source_fetch \
				-bb "SPECS/${SPEC_NAME}.spec" \
					|| exit 1
		\popd >/dev/null
		\pushd "$PTH/rpmbuild/RPMS/" >/dev/null  || exit 1
			PACKAGES=$( \ls -1 *.rpm )
		\popd >/dev/null
		if [[ -z $PACKAGES ]]; then
			failure "Failed to find finished rpm packages: $PTH/rpmbuild/RPMS/"
			exit 1
		fi
		PACKAGES_ALL="$PACKAGES_ALL $PACKAGES"
		for ENTRY in $PACKAGES; do
			\cp -fv  "$PTH/rpmbuild/RPMS/$ENTRY"  "$PWD/"  || exit 1
		done
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
	if [ $did_something -eq $YES ]; then
		display_time "Distributable"
		did_something_session=$YES
	else
		title C "Distribute"
		notice "Nothing to distribute.."
		echo
	fi
}



# run
function doRun() {
	if [[ -z $1 ]]; then
		PTH="$PWD"
	else
		PTH="$PWD/$1"
	fi
	shift
	if [ ! -f "$PTH/test.sh" ]; then
		echo "test.sh not found, cannot run from here"
		exit 1
	fi
	title C "Running.."
	\pushd "$PTH" >/dev/null || exit 1
		echo " v v v v v v v v v v "
		sh test.sh "$@"
		echo " ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ "
	\popd >/dev/null
}



# parse args
echo
if [ $# -eq 0 ]; then
	DisplayHelp
	exit 1
fi
ACTIONS=""
NO_MULTI=$NO
DEBUG_FLAGS=$NO
RUN_ARGS=""
PACKAGES_ALL=""
while [ $# -gt 0 ]; do
	case "$1" in
	# build number
	-n|--build-number)
		\shift
		BUILD_NUMBER="$1"
	;;
	--build-number=*)
		BUILD_NUMBER="${1#*=}"
	;;
	-A|--no-multi)
		NO_MULTI=$YES
	;;
	-D|--debug-flag|--debug-flags)
		DEBUG_FLAGS=$YES
	;;
	# debug mode
	-d|--debug)
		DEBUG=$YES
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
		ACTIONS="$ACTIONS $1"
		# everything after this is an argument for the app
		if [ "$1" == "run" ]; then
			shift
			while [ $# -gt 0 ]; do
				if [ -z $RUN_ARGS ]; then
					RUN_ARGS="$1"
				else
					RUN_ARGS="$RUN_ARGS $1"
				fi
				shift
			done
			break;
		fi
	;;
	esac
	\shift
done
if [ $DEBUG_FLAGS -eq $YES ]; then
	notice "Enabled debug flags"
	echo
fi



# perform actions
function PROJECT() {
	TIME_START=$( \date "+%s%N" )
	TIME_LAST=$TIME_START
	if [[ ! -z $1 ]]; then
		title B "$1"
		echo
	fi
	for ACT in $ACTIONS; do
		case "$ACT" in
		clean)  doClean  $1 ;;
		config) doConfig $1 ;;
		build)  doBuild  $1 ;;
		test)   doTests  $1 ;;
		dist)   doDist   $1 ;;
		run)    doRun "$1" $RUN_ARGS ;;
		*)
			failure "Unknown action: $ACT"
			echo
			exit 1
		;;
		esac
	done
}

# multiple projects
if [[ -f "$PWD/automulti.conf"  ]] \
&& [[ $NO_MULTI -eq $NO ]]; then
	source "$PWD/automulti.conf" || exit 1
# one project
else
	PROJECT
fi



if [ $did_something_session -ne $YES ]; then
	failure "Did nothing"
	echo
	exit 1
fi
TIME_END=$( \date +%s%N )
elapsed=$( echo "scale=3;($TIME_END - $TIME_START) / 1000 / 1000 / 1000" | bc )
[[ "$elapsed" == "."* ]] && \
	elapsed="0$elapsed"
echo -e " ${COLOR_BROWN}Finished in $elapsed seconds${COLOR_RESET}"
echo
if [[ ! -z $PACKAGES_ALL ]]; then
	echo -e "${COLOR_CYAN}===============================================${COLOR_RESET}"
	echo -e " ${COLOR_CYAN}Packages:${COLOR_RESET}"
	for ENTRY in $PACKAGES_ALL; do
		echo -e "   ${COLOR_BROWN}$ENTRY${COLOR_RESET}"
	done
	echo -e "${COLOR_CYAN}===============================================${COLOR_RESET}"
	echo
fi
exit 0
