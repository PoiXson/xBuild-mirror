#!/usr/bin/bash
##===============================================================================
## Copyright (c) 2020-2021 PoiXson, Mattsoft
## <https://poixson.com> <https://mattsoft.net>
## Released under the GPL 3.0
##
## Description: Script to manage a workspace of projects
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
# workspace.sh

source /usr/bin/pxn/scripts/common.sh



PWD=$(pwd)
if [ -z $PWD ]; then
	failure "Failed to find current working directory"
	exit 1
fi



function DisplayHelp() {
	echo -e "${COLOR_BROWN}Usage:${COLOR_RESET}"
	echo    "  workspace [options] <workspace-groups>"
	echo
	echo -e "${COLOR_BROWN}Workspace Groups:${COLOR_RESET}"
	let count=0
	for FILE in $( \ls -1v "$PWD/"*.dev 2>/dev/null ); do
		NAME="${FILE%%.dev}"
		NAME="${NAME##*/}"
		echo -e "  ${COLOR_GREEN}$NAME${COLOR_RESET}"
		count=$((count+1))
	done
	if [ $count -eq 0 ]; then
		echo "  No .dev files found here"
	fi
	echo
	echo -e "${COLOR_BROWN}Options:${COLOR_RESET}"
	echo -e "  ${COLOR_GREEN}-a, --all${COLOR_RESET}                   Use all .dev files found"
	echo -e "  ${COLOR_GREEN}-D, --debug-flags${COLOR_RESET}           Build with debug flags"
	echo
	echo -e "  ${COLOR_GREEN}-c, --clean, --cleanup${COLOR_RESET}      Cleanup workspace; delete generated files"
	echo
	echo -e "  ${COLOR_GREEN}-p, --pp, --pull-push${COLOR_RESET}       Run 'git pull' and 'git push'"
	echo -e "  ${COLOR_GREEN}-g, --gg, --git-gui${COLOR_RESET}         Open git-gui for each project"
	echo
	echo -e "  ${COLOR_GREEN}-b, --build, --compile${COLOR_RESET}      Compile the projects"
	echo -e "  ${COLOR_GREEN}-i, --dist, --distribute${COLOR_RESET}    Build distributable packages"
	echo
	echo -e "  ${COLOR_GREEN}-d, --debug${COLOR_RESET}                 Enable debug logs"
	echo -e "  ${COLOR_GREEN}-h, --help${COLOR_RESET}                  Display this help message and exit"
	echo
	exit 1
}



function Workspace() {
	if [ ! -z $WS_NAME ]; then
		doWorkspace
	fi
	if [ ! -z $1 ]; then
		WS_NAME="$1"
	fi
}

function doWorkspaceCleanup() {
	# reset workspace vars
	WS_NAME=""
	WS_REPO=""
	\sleep 0.4
}

function doWorkspace() {
	if [ -z $WS_NAME ]; then
		return
	fi
	title B "$WS_NAME"
	echo
	did_something=$NO
	fresh_clone=$NO

	# project dir not found
	if [[ ! -d "$PWD/$WS_NAME" ]]; then
		# clone repo
		if [[ $DO_PP -eq $YES ]] \
		&& [[ ! -z $WS_REPO ]]; then
			title C "Cloning repo.."
			\git clone "$WS_REPO" "$WS_NAME"  || exit 1
			did_something=$YES
			count_ops=$((count_ops+1))
			fresh_clone=$YES
		else
			notice "bypassed - project not found"
			echo
			return;
		fi
		echo
	fi

	# cleanup
	if [ $DO_CLEAN -eq $YES ]; then
		\pushd "$PWD/$WS_NAME/" >/dev/null  || exit 1
			\autobuild clean  || exit 1
			did_something=$YES
			count_ops=$((count_ops+1))
		\popd >/dev/null
		echo
	fi

	# git pull/push
	if [[ $DO_PP -eq $YES ]] \
	&& [[ $fresh_clone -eq $NO ]]; then
		if [ -d "$PWD/$WS_NAME/.git" ]; then
			\pushd "$PWD/$WS_NAME/" >/dev/null  || exit 1
				# git pull
				title C "pull"
				\git pull  || exit 1
				# git push
				title C "push"
				\git push  || exit 1
				did_something=$YES
				count_ops=$((count_ops+1))
			\popd >/dev/null
			echo
		else
			notice "bypass - .git/ not found"
		fi
	fi

	# update static files
	if [ -f "$PWD/.gitignore" ]; then
		\cp  "$PWD/.gitignore"  "$PWD/$WS_NAME/"  || exit 1
	fi
	if [ -f "$PWD/.gitattributes" ]; then
		\cp  "$PWD/.gitattributes"  "$PWD/$WS_NAME/"  || exit 1
	fi
	if [ -f "$PWD/phpunit.xml" ]; then
		if [ -f "$PWD/$WS_NAME/phpunit.xml" ]; then
			\cp  "$PWD/phpunit.xml"  "$PWD/$WS_NAME/"  || exit 1
		fi
	fi

	# build/compile
	if [ $DO_BUILD -eq $YES ]; then
		\pushd "$PWD/$WS_NAME/" >/dev/null  || exit 1
			\autobuild config build  || exit 1
			did_something=$YES
			count_ops=$((count_ops+1))
		\popd >/dev/null
		echo
	fi

	# distributable
	if [ $DO_DIST -eq $YES ]; then
		\pushd "$PWD/$WS_NAME/" >/dev/null  || exit 1
			\autobuild dist  || exit 1
			did_something=$YES
			count_ops=$((count_ops+1))
		\popd >/dev/null
		if [ -d "$PWD/rpms" ]; then
			\cp -v  "$PWD/$WS_NAME/rpmbuild/RPMS/"*.rpm  "$PWD/rpms/"  || exit 1
		fi
		echo
	fi

	# git-gui
	if [ $DO_GG -eq $YES ]; then
		if [ -d "$PWD/$WS_NAME/.git" ]; then
			\pushd "$PWD/$WS_NAME/" >/dev/null  || exit 1
				/usr/libexec/git-core/git-gui &
				echo "git-gui "$!
				\sleep 0.2
				echo
				did_something=$YES
				count_ops=$((count_ops+1))
			\popd >/dev/null
		fi
	fi

	if [ $did_something -eq $NO ]; then
		echo "Nothing to do.."
		echo
	else
		count_prg=$((count_prg+1))
	fi
	# cleanup vars
	doWorkspaceCleanup
}



# parse args
echo
if [ $# -eq 0 ]; then
	DisplayHelp
	exit 1
fi
DEV_FILES=""
DEBUG_FLAGS=$NO
DO_CLEAN=$NO
DO_PP=$NO
DO_GG=$NO
DO_BUILD=$NO
DO_DIST=$NO
while [ $# -gt 0 ]; do
	case "$1" in
	# all workspace groups
	-a|--all)
		DEV_FILES=$( \ls -1v *.dev 2>/dev/null )
	;;
	# debug mode
	-D|--debug-flag|--debug-flags)
		DEBUG_FLAGS=$YES
	;;
	# cleanup
	-c|--clean|--cleanup)
		DO_CLEAN=$YES
	;;
	# git pull/push
	-p|--pp|--pull-push|--push-pull)
		DO_PP=$YES
	;;
	# git-gui
	-g|--gg|--git-gui)
		DO_GG=$YES
	;;
	# --build
	-b|--build|--compile)
		DO_BUILD=$YES
	;;
	# --dist
	-i|--dist|--distribute)
		DO_DIST=$YES
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
		if [ -f "$1" ]; then
			DEV_FILES="${DEV_FILES} $1"
		elif [ -f "${1}.dev" ]; then
			DEV_FILES="${DEV_FILES} ${1}.dev"
		elif [ -f *"-${1}.dev" ]; then
			DEV_FILES="${DEV_FILES} "$( ls -1v *"${1}.dev" 2>/dev/null | head -n1 )
		else
			count=$( \ls -1 *.dev 2>/dev/null | wc -l )
			if [[ $count -eq 0 ]]; then
				failure "No workspace group .dev files found here"
			else
				failure "Unknown workspace group: $1"
			fi
			echo
			exit 1
		fi
	;;
	esac
	\shift
done



# no options selected
if	[[ $DO_CLEAN -ne $YES ]] && \
	[[ $DO_PP    -ne $YES ]] && \
	[[ $DO_GG    -ne $YES ]] && \
	[[ $DO_BUILD -ne $YES ]] && \
	[[ $DO_DIST  -ne $YES ]]; then
		failure "No actions selected"
		echo
		DisplayHelp
		exit 1
fi
if [[ -z $DEV_FILES ]]; then
	failure "No workspace group .dev selected"
	echo
	DisplayHelp
	exit 1
fi



# install .gitconfig file
if [ -f "./.gitconfig" ]; then
	\cp -fv "./.gitconfig" ~/  || exit 1
fi



function LoadDevSource() {
	doWorkspaceCleanup
	dev="$1"
	if [[ ! -f "$PWD/$dev" ]]; then
		failure "File not found: $dev"
		echo
		exit 1
	fi
	# load .dev file
	source "$PWD/$dev"  || exit 1
	# perform work on projects
	Workspace
}

# perform actions
let count_prg=0
let count_ops=0
for DEV in $DEV_FILES; do
	LoadDevSource "$DEV"
done



if [[ $count_prg -eq 0 ]] \
&& [[ $count_ops -eq 0 ]]; then
	warning "No actions performed"
else
	echo -e " ${COLOR_GREEN}Performed $count_ops operations on $count_prg projects${COLOR_RESET}"
fi



echo -e "${COLOR_BLUE}Done${COLOR_RESET}"
echo
exit 0
