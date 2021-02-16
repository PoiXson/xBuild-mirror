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



PWD=$(pwd)
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
	echo -e "  ${COLOR_GREEN}clean${COLOR_RESET}                  Clean the project, removing build files"
	echo -e "  ${COLOR_GREEN}config${COLOR_RESET}                 Generate files needed to build the project"
	echo -e                             "                           autoreconf or composer"
	echo -e "  ${COLOR_GREEN}build${COLOR_RESET}                  Compile the project; using tools such as "
	echo -e                             "                           make or mvn"
	echo -e "  ${COLOR_GREEN}test${COLOR_RESET}                   Perform testing"
	echo -e                             "                           make check or phpunit"
	echo -e "  ${COLOR_GREEN}dist${COLOR_RESET}                   Build distributable packages"
	echo -e                             "                           make dist or rpmbuild"
	echo -e "  ${COLOR_GREEN}run${COLOR_RESET}                    Run the application which was just built"
	echo -e                             "                           anything after this is used as an argument for the app"
	echo
	echo -e "${COLOR_BROWN}Options:${COLOR_RESET}"
	echo -e "  ${COLOR_GREEN}-n, --build-number${COLOR_RESET}     Build number to use for packaging"
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
	TIME_CURRENT=$(date +%s%N)
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
	title C "Clean"
	did_something=$NO
	# make clean project
	if [ -f "$PWD/Makefile.am" ]; then
		if [ -f "$PWD/Makefile" ]; then
			\make distclean
			echo
			did_something=$YES
		fi
		# remove .deps dirs
		RESULT=$( \find "$PWD" -type d -name .deps )
		let count=0
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
		if [ $count -gt 0 ]; then
			echo
			did_something=$YES
		fi
	fi
	# clean rpm project
	if [ ! -z $SPEC_FILE ]; then
		if [ -d "$PWD/rpmbuild" ]; then
			\rm -vrf --preserve-root rpmbuild
			echo
			did_something=$YES
		fi
	fi
	# clean php project
	if [ -f "$PWD/composer.json" ]; then
		if [ -d "$PWD/vendor" ]; then
			\rm -vrf --preserve-root vendor
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
	if [ -f "$PWD/make-symlinks.sh" ]; then
		title C "Make Symlinks"
		sh  "$PWD/make-symlinks.sh"  || exit 1
		echo
	fi
	title C "Configure"
	did_something=$NO
	if [ -f "$PWD/autotools.conf" ]; then
		\genautotools
		echo
	fi
	# automake
	if [ -f "$PWD/configure.ac" ]; then
		\autoreconf -v --install  || exit 1
		echo
		did_something=$YES
	fi
	# composer
	if [ -f "$PWD/composer.json" ]; then
		if [[ $DEBUG_FLAG -eq $YES ]] \
		|| [[ ! -f "$PWD/composer.lock" ]]; then
			\composer update  || exit 1
		else
			\composer install  || exit 1
		fi
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
	title C "Build"
	did_something=$NO
	# automake
	if [ -f "$PWD/configure" ]; then
		if [ $DEBUG_FLAGS -eq $YES ]; then
			./configure --enable-debug  || exit 1
		else
			./configure                 || exit 1
		fi
		echo
		did_something=$YES
	fi
	# make
	if [ -f "$PWD/Makefile" ]; then
		\make  || exit 1
		echo
		did_something=$YES
	fi
	# maven
	if [ -f "$PWD/pom.xml" ]; then
		\mvn clean install  || exit 1
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
	title C "Testing"
	did_something=$NO
	# make check
	if [ -f "$PWD/Makefile" ]; then
		\make check  || exit 1
		echo

#TODO: exec test program

#		did_something=$YES
	fi
	# phpunit
	if [ -f "$PWD/phpunit.xml" ]; then
		\phpunit  || exit 1
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
	did_something=$NO
	# make dist
	if [ -f "$PWD/Makefile" ]; then
		title C "Distribute"
		\make dist  || exit 1
		echo
		did_something=$YES
	fi
	# build rpm
	if [ ! -z $SPEC_FILE ]; then
		title C "RPM Build"
		\mkdir -p "$PWD"/rpmbuild/{BUILD,BUILDROOT,SOURCES,SPECS,RPMS,SRPMS,TMP}  || exit 1
		\cp -vf  "$SPEC_FILE"  "$PWD/rpmbuild/SPECS/"  || exit 1
		\pushd "$PWD/rpmbuild/" >/dev/null  || exit 1
			\rpmbuild \
				${BUILD_NUMBER:+ --define="build_number $BUILD_NUMBER"} \
				--define="_topdir $PWD" \
				--define="_tmppath $PWD/TMP" \
				--define="_binary_payload w9.gzdio" \
				-bb "SPECS/${SPEC_NAME}.spec" \
					|| exit 1
		\popd >/dev/null
		\cp -f  "$PWD/rpmbuild/RPMS/"*.rpm  "$PWD/"  || exit 1
		echo "==============================================="
		echo "Packages ready for distribution:"
		\ls -1 "$PWD/rpmbuild/RPMS/"  || exit 1
		echo "==============================================="
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
	if [ ! -f "$PWD/test.sh" ]; then
		echo "test.sh not found, cannot run from here"
		exit 1
	fi
	title C "Running.."
	echo " v v v v v v v v v v "
	sh test.sh "$@"
	echo " ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ "
}



# find .spec file
SPEC_FILE_COUNT=$(\ls -1 "$PWD/"*.spec 2>/dev/null | \wc -l)
if [ $SPEC_FILE_COUNT -eq 1 ]; then
	SPEC_FILE=$(\ls -1 "$PWD/"*.spec)
	SPEC_NAME="${SPEC_FILE%%.*}"
	SPEC_NAME="${SPEC_NAME##*/}"
elif [ $SPEC_FILE_COUNT -gt 1 ]; then
	warning "$SPEC_FILE_COUNT .spec files were found here"
fi



# parse args
echo
if [ $# -eq 0 ]; then
	DisplayHelp
	exit 1
fi
ACTIONS=""
DEBUG_FLAGS=$NO
RUN_ARGS=""
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
TIME_START=$(date +%s%N)
TIME_LAST=$TIME_START
for ACT in $ACTIONS; do
	case "$ACT" in
	clean)  doClean  ;;
	config) doConfig ;;
	build)  doBuild  ;;
	test)   doTests  ;;
	dist)   doDist   ;;
	run)    doRun $RUN_ARGS ;;
	*)
		failure "Unknown action: $ACT"
		echo
		exit 1
	;;
	esac
done



if [ $did_something_session -ne $YES ]; then
	failure "Did nothing"
	echo
	exit 1
fi
TIME_END=$(date +%s%N)
elapsed=$( echo "scale=3;($TIME_END - $TIME_START) / 1000 / 1000 / 1000" | bc )
[[ "$elapsed" == "."* ]] && \
	elapsed="0$elapsed"
echo -e " ${COLOR_BROWN}Finished in $elapsed seconds${COLOR_RESET}"
echo
exit 0
