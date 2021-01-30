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

source /usr/bin/pxn/scripts/common.sh



PWD=$(pwd)
if [ -z $PWD ]; then
	failure "Failed to find current working directory"
	exit 1
fi



function DisplayHelp() {
	echo -e "${COLOR_BROWN}Usage:${COLOR_RESET}"
	echo    "  autobuild [options]"
	echo
	echo -e "${COLOR_BROWN}Actions:${COLOR_RESET}"
	echo -e "  ${COLOR_GREEN}clean${COLOR_RESET}                  Clean the project, removing build files"
	echo -e "  ${COLOR_GREEN}config${COLOR_RESET}                 "
	echo -e "  ${COLOR_GREEN}build${COLOR_RESET}                  Compile the project"
	echo -e "  ${COLOR_GREEN}dist${COLOR_RESET}                   "
	echo
	echo -e "${COLOR_BROWN}Options:${COLOR_RESET}"
	echo -e "  ${COLOR_GREEN}-n, --build-number${COLOR_RESET}     Build number to use for packaging"
	echo                                "                           note: defaults to 'x'"
	echo -e "  ${COLOR_GREEN}-d, --debug${COLOR_RESET}            Build with debug flags"
	echo
	echo -e "  ${COLOR_GREEN}-h, --help${COLOR_RESET}             Display this help message and exit"
	echo
	exit 1
}



# clean
function doClean() {
	title "Clean"
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
		count=0
		for ENTRY in $RESULT; do
			[[ -f "$ENTRY" ]] && \rm -v                   "$ENTRY" && count=$((count+1))
			[[ -d "$ENTRY" ]] && \rm -vrf --preserve-root "$ENTRY" && count=$((count+1))
		done
		# remove more files
		CLEAN_PATHS=". src"
		CLEAN_FILES="autom4te.cache aclocal.m4 compile configure depcomp install-sh Makefile.in missing"
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
	if [ $did_something -eq $NO ]; then
		echo "Nothing to do.."
		echo
	fi
}



# auto configure
function doConfig() {
	title "Auto-Configure"
	if [[ ! -f"$PWD/configure.ac" ]]; then
		notice "configure.ac file not found, skipping.."
		echo
		return
	fi
	if [[ ! -f "$PWD/Makefile.am" ]]; then
		notice "Makefile.am file not found, skipping.."
		echo
		return
	fi
	\autoreconf -v --install  || exit 1
	echo
}



# build
function doBuild() {
	title "Build"
	did_something=$NO
	if [ -f "$PWD/configure" ]; then
		if [ $DEBUG -eq $YES ]; then
			./configure --enable-debug  || exit 1
		else
			./configure                 || exit 1
		fi
		echo
	fi
	if [ -f "$PWD/Makefile" ]; then
		\make  || exit 1
		echo
		did_something=$YES
	fi
	if [ $did_something -eq $NO ]; then
		notice "Nothing found to build.."
		echo
	fi
}



# distribute
function doDist() {
	did_something=$NO
	# make dist
	if [ -f "$PWD/Makefile" ]; then
		title "Distribute"
		\make dist       || exit 1
		\make distcheck  || exit 1
		echo
		did_something=$YES
	fi
	# build rpm
	if [ ! -z $SPEC_FILE ]; then
		title "RPM Build"
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
		echo "==============================================="
		echo "Packages ready for distribution:"
		\ls -lAsh "$PWD/rpmbuild/RPMS/"  || exit 1
		echo "==============================================="
		echo
		did_something=$YES
	fi
	if [ $did_something -eq $NO ]; then
		title "Distribute"
		echo "Nothing to do.."
		echo
	fi
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
	;;
	esac
	\shift
done



# perform actions
for ACT in $ACTIONS; do
	case "$ACT" in
	clean)
		doClean
	;;
	config)
		doConfig
	;;
	build)
		doBuild
	;;
	dist)
		doDist
	;;
	*)
		failure "Unknown action: $ACT"
		echo
		exit 1
	;;
	esac
done



echo -e "${COLOR_BROWN}Done${COLOR_RESET}"
exit 0
