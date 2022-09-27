#!/usr/bin/bash
##==============================================================================
## Copyright (c) 2019-2022 Mattsoft/PoiXson
## <https://mattsoft.net> <https://poixson.com>
## Released under the AGPL 3.0
##
## Description: Auto compile a project and build rpms
##
## Example:
## > curl --output configer-install.sh https://configer.io/install.sh
## > sh configer-install.sh --wizard
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
DO_RECURSIVE=$NO
IS_DRY=$NO
DEBUG_FLAGS=$NO
DO_BIN_ONLY=$NO
DO_WEB_ONLY=$NO
DO_PP=$NO
DO_GG=$NO
DO_CLEAN=$NO
DO_CONFIG=$NO
DO_BUILD=$NO
DO_TESTS=$NO
DO_PACK=$NO

BUILD_NUMBER=""
BUILD_RELEASE=$NO
TARGET_PATH=""
PROJECT_FILTERS=""

# project vars
PROJECT_NAME=""
PROJECT_VERSION=""
PROJECT_PATH=""
CURRENT_PATH="$WDIR"
PROJECT_REPO=""
PROJECT_ALIASES=""
PROJECT_PHAR=$NO
PROJECT_PHAR_DIRS=""
PROJECT_GITIGNORE=""
PROJECT_TAG_FILES=""
PROJECT_TAGS_DONE=$NO

PACKAGES_ALL=()
let COUNT_PRJ=0
let COUNT_OPS=0

TIME_START=$( \date "+%s%N" )
let TIME_START_PRJ=0
let TIME_LAST=0



function DisplayHelp() {
	echo -e "${COLOR_BROWN}Usage:${COLOR_RESET}"
	echo    "  xbuild [options] <group>"
	echo
	echo -e "${COLOR_BROWN}Options:${COLOR_RESET}"
	echo -e "  ${COLOR_GREEN}-r, --recursive${COLOR_RESET}           Recursively load xbuild.conf files"
	echo -e "  ${COLOR_GREEN}-D, --dry${COLOR_RESET}                 Dry-run, no changes will be performed by actions"
	echo -e "  ${COLOR_GREEN}-d, --debug-flags${COLOR_RESET}         Build with debug flags"
	echo -e "  ${COLOR_GREEN}-R, --release${COLOR_RESET}             Build a production release"
	echo -e "  ${COLOR_GREEN}-n, --build-number <n>${COLOR_RESET}    Build number to use for builds and packages"
	echo -e                             "                              default: x"
	echo -e "  ${COLOR_GREEN}--target <path>${COLOR_RESET}           Sets the destination path for finished binaries"
	echo -e                             "                              default: target/"
	echo
	echo -e "  ${COLOR_GREEN}--binonly${COLOR_RESET}                 Build binary projects only"
	echo -e "  ${COLOR_GREEN}--webonly${COLOR_RESET}                 Build web projects only"
	echo
	echo -e "  ${COLOR_GREEN}--pp, --pull-push${COLOR_RESET}         Run 'git pull' and 'git push'"
	echo -e "  ${COLOR_GREEN}--gg, --git-gui${COLOR_RESET}           Open git-gui for each project"
	echo
	echo -e "  ${COLOR_GREEN}-c, --clean, --cleanup${COLOR_RESET}    Cleanup workspace; delete generated files"
	echo -e "  ${COLOR_GREEN}-C, --config, --configure${COLOR_RESET} Configure projects, with autotools or composer"
	echo -e "  ${COLOR_GREEN}-b, --build, --compile${COLOR_RESET}    Compile the projects"
	echo -e "  ${COLOR_GREEN}--tests${COLOR_RESET}                   Compile and run tests for the project"
	echo -e "  ${COLOR_GREEN}-p, --pack, --package${COLOR_RESET}     Build distributable packages"
	echo
	echo -e "  ${COLOR_GREEN}--cb${COLOR_RESET}                      Config, build"
	echo -e "  ${COLOR_GREEN}--cbp${COLOR_RESET}                     Config, build, pack"
	echo -e "  ${COLOR_GREEN}--ccb${COLOR_RESET}                     Clean, config, build"
	echo -e "  ${COLOR_GREEN}--cbtp${COLOR_RESET}                    Config, build, test, pack"
	echo -e "  ${COLOR_GREEN}--ccbp${COLOR_RESET}                    Clean, config, build, pack"
	echo -e "  ${COLOR_GREEN}--ccbtp${COLOR_RESET}                   Clean, config, build, test, pack"
	echo
	echo -e "  ${COLOR_GREEN}--dev${COLOR_RESET}                     Sets flags commonly used for development builds"
	echo -e                             "                              Shortcut to: -v -r --debug --cbp"
	echo -e "  ${COLOR_GREEN}--ci <n>${COLOR_RESET}                  Sets flags commonly used for continuous integration"
	echo -e                             "                              Shortcut to: -v -r -R -n <n> --clean --build --test --pack"
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



function DisplayTime() {
	[[ $QUIET -eq $YES ]] && return
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
	[[ $QUIET -eq $YES ]] && return
	TIME_CURRENT=$( \date "+%s%N" )
	ELAPSED=$( echo "scale=3;($TIME_CURRENT - $TIME_START_PRJ) / 1000 / 1000 / 1000" | bc )
	if [[ "$ELAPSED" == "."* ]]; then
		ELAPSED="0$ELAPSED"
	fi
	echo
	echo -e " ${COLOR_CYAN}Finished project in $ELAPSED seconds: $PROJECT_NAME${COLOR_RESET}"
	echo ; echo
}



function MakeSymlink() {
	if [[ -z $1 ]]; then
		failure "MakeSymlink() requires arguments"
		failure ; exit 1
	fi
	echo -ne " > ${COLOR_CYAN}Symlink: "
	local RESULT=0
	if [[ $IS_DRY -eq $NO ]]; then
		if [[ -z $2 ]]; then
			\ln -svf "$1"
		else
			\ln -svf "$1" "$2"
		fi
		RESULT=$?
	else
		echo "$1 -> $2"
	fi
	echo -ne "$COLOR_RESET"
	[[ $RESULT ]] || exit 1
}



# ----------------------------------------



# --pp
function doPullPush() {
	[[ -z $PROJECT_REPO ]] && \
	[[ ! -d "$PROJECT_PATH/.git" ]] && \
		return
	# clone repo
	if [[ ! -e "$PROJECT_PATH" ]]; then
		[[ $QUIET -eq $NO ]] && \
			title C "$PROJECT_NAME" "Clone"
		\pushd "$CURRENT_PATH/" >/dev/null  || exit 1
			local CLONE_PATH=${PROJECT_PATH##*/}
			# git clone
			echo -e " > ${COLOR_CYAN}git clone  $PROJECT_REPO  $CLONE_PATH${COLOR_RESET}"
			if [[ $IS_DRY -eq $NO ]]; then
				\git clone "$PROJECT_REPO" "$CLONE_PATH"  || exit 1
			fi
			echo
		\popd >/dev/null
		COUNT_OPS=$((COUNT_OPS+1))
		return
	fi
	[[ $QUIET -eq $NO ]] && \
		title C "$PROJECT_NAME" "Pull/Push"
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
	[[ ! -d "$PROJECT_PATH/.git" ]] \
		&& return
	# git-gui
	\pushd "$PROJECT_PATH/" >/dev/null  || exit 1
		echo -ne " > ${COLOR_CYAN}git-gui${COLOR_RESET}"
		if [[ $IS_DRY -eq $NO ]]; then
			/usr/libexec/git-core/git-gui &
			local GG_PID=$!
			echo -e " ${COLOR_BLUE}$GG_PID${COLOR_RESET}"
			\sleep 0.2
		else
			echo
		fi
		echo
	\popd >/dev/null
	COUNT_OPS=$((COUNT_OPS+1))
}



# --clean
function doClean() {
	[[ $QUIET -eq $NO ]] && \
		title C "$PROJECT_NAME" "Clean"
	let count=0
	let rm_groups=0
	restoreProjectTags
	# make clean
	if [[ $DO_WEB_ONLY -eq $NO ]]; then
		if [[ -f "$PROJECT_PATH/Makefile.am" ]]; then
			if [[ -f "$PROJECT_PATH/Makefile" ]]; then
				\pushd "$PROJECT_PATH/" >/dev/null || exit 1
					echo -ne " > ${COLOR_CYAN}make distclean${COLOR_RESET}"
					let rm_groups=$((rm_groups+1))
					if [[ $IS_DRY -eq $NO ]]; then
						local c=$( \make distclean | \wc -l )
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
						let rm_groups=$((rm_groups+1))
						if [[ $IS_DRY -eq $NO ]]; then
							local c=$( \rm -v "$ENTRY" | \wc -l )
							[[ 0 -ne $? ]] && exit 1
							[[ $c -gt 0 ]] && count=$((count+c))
							echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
						else
							echo
						fi
					fi
					if [[ -d "$ENTRY" ]]; then
						echo -ne " > ${COLOR_CYAN}rm -rf ${ENTRY}${COLOR_RESET}"
						let rm_groups=$((rm_groups+1))
						if [[ $IS_DRY -eq $NO ]]; then
							local c=$( \rm -vrf --preserve-root "$ENTRY" | \wc -l )
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
								echo -ne " > ${COLOR_CYAN}rm ${ENTRY}${COLOR_RESET}"
								if [[ $IS_DRY -eq $NO ]]; then
									local c=$( \rm -v "$ENTRY" | \wc -l )
									[[ 0 -ne $? ]] && exit 1
									[[ $c -gt 0 ]] && count=$((count+c))
									echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
								else
									echo
								fi
							fi
							if [[ -d "$ENTRY" ]]; then
								echo -ne " > ${COLOR_CYAN}rm -rf ${ENTRY}${COLOR_RESET}"
								if [[ $IS_DRY -eq $NO ]]; then
									local c=$( \rm -vrf --preserve-root "$ENTRY" | \wc -l )
									[[ 0 -ne $? ]] && exit 1
									[[ $c -gt 0 ]] && count=$((count+c))
									echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
								else
									echo
								fi
							fi
						done
					\popd >/dev/null
				done
			\popd >/dev/null
		fi
		# clean rpm project
		if [[ -d "$PROJECT_PATH/rpmbuild" ]]; then
			\pushd "$PROJECT_PATH/" >/dev/null || exit 1
				echo -ne " > ${COLOR_CYAN}rm -rf rpmbuild${COLOR_RESET}"
				let rm_groups=$((rm_groups+1))
				if [[ $IS_DRY -eq $NO ]]; then
					local c=$( \rm -vrf --preserve-root rpmbuild | wc -l )
					[[ 0 -ne $? ]] && exit 1
					[[ $c -gt 0 ]] && count=$((count+c))
					echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
				else
					echo
				fi
			\popd >/dev/null
		fi
		# clean target/
		if [[ -d "$PROJECT_PATH/target" ]]; then
			# defer clean root target/
			if [[ "$PROJECT_PATH/target" != "$TARGET_PATH" ]]; then
				\pushd "$PROJECT_PATH/" >/dev/null || exit 1
					echo -ne " > ${COLOR_CYAN}rm -rf target${COLOR_RESET}"
					let rm_groups=$((rm_groups+1))
					if [[ $IS_DRY -eq $NO ]]; then
						local c=$( \rm -vrf --preserve-root target | wc -l )
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
	# clean php project
	if [[ $DO_BIN_ONLY -eq $NO ]]; then
		if [[ -f "$PROJECT_PATH/composer.json" ]]; then
			# clean vendor/
			if [[ -d "$PROJECT_PATH/vendor" ]]; then
				\pushd "$PROJECT_PATH/" >/dev/null || exit 1
					echo -ne " > ${COLOR_CYAN}rm -rf vendor${COLOR_RESET}"
					let rm_groups=$((rm_groups+1))
					if [[ $IS_DRY -eq $NO ]]; then
						local c=$( \rm -vrf --preserve-root vendor | wc -l )
						[[ 0 -ne $? ]] && exit 1
						[[ $c -gt 0 ]] && count=$((count+c))
						echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
					else
						echo
					fi
				\popd >/dev/null
			fi
			# clean phar
			if [[ $PROJECT_PHAR -eq $YES ]]; then
				# clean build-phar/
				if [[ -d "$PROJECT_PATH/build-phar" ]]; then
					\pushd "$PROJECT_PATH/" >/dev/null || exit 1
						echo -ne " > ${COLOR_CYAN}rm -rf build-phar${COLOR_RESET}"
						let rm_groups=$((rm_groups+1))
						if [[ $IS_DRY -eq $NO ]]; then
							local c=$( \rm -vrf --preserve-root build-phar | wc -l )
							[[ 0 -ne $? ]] && exit 1
							[[ $c -gt 0 ]] && count=$((count+c))
							echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
						else
							echo
						fi
					\popd >/dev/null
				fi
				# clean project.phar
				\ls *.phar >/dev/null 2>/dev/null && {
					echo -ne " > ${COLOR_CYAN}rm -f *.phar${COLOR_RESET}"
					let rm_groups=$((rm_groups+1))
					if [[ $IS_DRY -eq $NO ]]; then
						local c=$( \rm -vrf --preserve-root *.phar | wc -l )
						[[ 0 -ne $? ]] && exit 1
						[[ $c -gt 0 ]] && count=$((count+c))
						echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
					fi
				}
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
		if [[ $DO_WEB_ONLY -eq $YES ]]; then
			echo "web only; skipping.."
		elif [[ $DO_BIN_ONLY -eq $YES ]]; then
			echo "bin only; skipping.."
		else
			notice "Nothing to clean.."
		fi
		echo
	fi
	COUNT_OPS=$((COUNT_OPS+1))
}



# --config
function doConfig() {
	did_something=$NO
	# .gitignore
	if [[ -f "$PROJECT_PATH/.gitignore" ]] \
	&& [[ $BUILD_RELEASE -eq $NO ]]; then
		local OUT_FILE=$( mktemp )
		local RESULT=$?
		if [[ $RESULT -ne 0 ]] || [[ -z $OUT_FILE ]]; then
			failure "Failed to create a temp file for .gitignore"
			failure ; exit $RESULT
		fi
		if [[ ! -z $PROJECT_GITIGNORE ]]; then
			for ENTRY in $PROJECT_GITIGNORE; do
				echo "$ENTRY" >>"$OUT_FILE"
			done
			echo >>"$OUT_FILE"
		fi
		\cat /etc/xbuild/gitignore >>"$OUT_FILE" || exit 1
		local HASH_A=$( \cat "$OUT_FILE"                | \md5sum )
		local HASH_B=$( \cat "$PROJECT_PATH/.gitignore" | \md5sum )
		if [[ "$HASH_A" != "$HASH_B" ]]; then
			title C "Updating .gitignore.."
			echo -e " > ${COLOR_CYAN}cat $OUT_FILE > $PROJECT_PATH/.gitignore${COLOR_RESET}"
			if [[ $IS_DRY -eq $NO ]]; then
				\cat  "$OUT_FILE"  >"$PROJECT_PATH/.gitignore"  || exit 1
			fi
			did_something=$YES
		fi
		\rm -f "$OUT_FILE"
	fi
	doProjectTags
	if [[ $DO_WEB_ONLY -eq $NO ]] \
	&& [[ $BUILD_RELEASE -eq $NO ]]; then
		# generate automake files
		if [[ -f "$PROJECT_PATH/autotools.conf" ]]; then
			[[ $QUIET -eq $NO ]] && \
				title C "$PROJECT_NAME" "Generate autotools"
			\pushd "$PROJECT_PATH/" >/dev/null || exit 1
				echo -e " > ${COLOR_CYAN}genautotools${COLOR_RESET}"
				if [[ $IS_DRY -eq $NO ]]; then
					\genautotools  || exit 1
				fi
			\popd >/dev/null
			echo
			did_something=$YES
		fi
		# automake
		if [[ -f "$PROJECT_PATH/configure.ac" ]]; then
			[[ $QUIET -eq $NO ]] && \
				title C "$PROJECT_NAME" "autoreconf"
			\pushd "$PROJECT_PATH/" >/dev/null || exit 1
				echo -e " > ${COLOR_CYAN}autoreconf -v --install${COLOR_RESET}"
				if [[ $IS_DRY -eq $NO ]]; then
					\autoreconf -v --install  || exit 1
				fi
			\popd >/dev/null
			echo
			did_something=$YES
		fi
		# generate pom.xml file
		if [[ -f "$PROJECT_PATH/pom.conf" ]]; then
			[[ $QUIET -eq $NO ]] && \
				title C "$PROJECT_NAME" "Generate pom"
			\pushd "$PROJECT_PATH/" >/dev/null || exit 1
				echo -e " > ${COLOR_CYAN}genpom${COLOR_RESET}"
				if [[ $IS_DRY -eq $NO ]]; then
					genpom  || exit 1
				fi
			\popd >/dev/null
			echo
			did_something=$YES
		fi
		# generate .spec file
		if [[ -f "$PROJECT_PATH/spec.conf" ]]; then
			[[ $QUIET -eq $NO ]] && \
				title C "$PROJECT_NAME" "Generate spec"
			\pushd "$PROJECT_PATH/" >/dev/null || exit 1
				echo -e " > ${COLOR_CYAN}genspec${COLOR_RESET}"
				if [[ $IS_DRY -eq $NO ]]; then
					genspec  || exit 1
				fi
			\popd >/dev/null
			echo
			did_something=$YES
		fi
	fi
	if [[ $DO_BIN_ONLY -eq $NO ]]; then
		# composer
		if [[ -f "$PROJECT_PATH/composer.json" ]]; then
			\pushd "$PROJECT_PATH/" >/dev/null || exit 1
				# configure for release
				if [[ $BUILD_RELEASE -eq $YES ]] \
				&& [[ -f "$PROJECT_PATH/composer.lock" ]]; then
					[[ $QUIET -eq $NO ]] && \
						title C "$PROJECT_NAME" "Composer Install"
					echo -e " > ${COLOR_CYAN}composer install -a -o --no-dev --prefer-dist${COLOR_RESET}"
					if [[ $IS_DRY -eq $NO ]]; then
						\composer install --no-dev --prefer-dist --classmap-authoritative --optimize-autoloader  || exit 1
					fi
				# configure for dev
				else
					if [[ $DEBUG_FLAGS -eq $YES ]] \
					|| [[ ! -f "$PROJECT_PATH/composer.lock" ]]; then
						[[ $QUIET -eq $NO ]] && \
							title C "$PROJECT_NAME" "Composer Update"
						echo -e " > ${COLOR_CYAN}composer update${COLOR_RESET}"
						if [[ $IS_DRY -eq $NO ]]; then
							\composer update  || exit 1
						fi
					else
						[[ $QUIET -eq $NO ]] && \
							title C "$PROJECT_NAME" "Composer Install"
						echo -e " > ${COLOR_CYAN}composer install${COLOR_RESET}"
						if [[ $IS_DRY -eq $NO ]]; then
							\composer install  || exit 1
						fi
					fi
				fi
			\popd >/dev/null
			echo
			did_something=$YES
		fi
	fi
	# nothing to do
	if [[ $did_something -eq $YES ]]; then
		DisplayTime "Configured"
		COUNT_OPS=$((COUNT_OPS+1))
	else
		[[ $QUIET -eq $NO ]] && \
			title C "$PROJECT_NAME" "Configure"
		if [[ $DO_WEB_ONLY -eq $YES ]]; then
			echo "web only; skipping.."
		elif [[ $DO_BIN_ONLY -eq $YES ]]; then
			echo "bin only; skipping.."
		else
			notice "Nothing found to configure.."
		fi
		echo
	fi
}



# --build
function doBuild() {
	did_something=$NO
	doProjectTags
	[[ $QUIET -eq $NO ]] && \
		title C "$PROJECT_NAME" "Build"
	# automake
	if [[ $DO_WEB_ONLY -eq $YES ]]; then
		echo "web only; skipping.."
	else
		if [[ -f "$PROJECT_PATH/configure" ]]; then
			\pushd "$PROJECT_PATH/" >/dev/null || exit 1
				CONFIGURE_DEBUG_FLAGS=""
				if [[ $DEBUG_FLAGS -eq $YES ]]; then
					CONFIGURE_DEBUG_FLAGS="--enable-debug"
				fi
				echo -e " > ${COLOR_CYAN}configure ${CONFIGURE_DEBUG_FLAGS}${COLOR_RESET}"
				if [[ $IS_DRY -eq $NO ]]; then
					./configure $CONFIGURE_DEBUG_FLAGS  || exit 1
				fi
			\popd >/dev/null
			echo
			did_something=$YES
		fi
		# make
		if [[ -f "$PROJECT_PATH/Makefile" ]]; then
			\pushd "$PROJECT_PATH/" >/dev/null || exit 1
				# make
				echo -e " > ${COLOR_CYAN}make${COLOR_RESET}"
				if [[ $IS_DRY -eq $NO ]]; then
					\make  || exit 1
				fi
				# make install
				if [[ -d "$PROJECT_PATH/.libs/" ]]; then
					echo
					echo -e " > ${COLOR_CYAN}make install${COLOR_RESET}"
					if [[ $IS_DRY -eq $NO ]]; then
						\sudo \make install  || exit 1
						echo
					fi
				fi
			\popd >/dev/null
			echo
			did_something=$YES
		fi
		# maven
		if [[ -f "$PROJECT_PATH/pom.xml" ]]; then
			\pushd "$PROJECT_PATH/" >/dev/null || exit 1
				echo -e " > ${COLOR_CYAN}mvn clean install${COLOR_RESET}"
				if [[ $IS_DRY -eq $NO ]]; then
					\mvn clean install  || exit 1
				fi
			\popd >/dev/null
			echo
			did_something=$YES
		fi
		# rust/cargo
		if [[ -f "$PROJECT_PATH/Cargo.toml" ]]; then
			\pushd "$PROJECT_PATH/" >/dev/null || exit 1
				if [[ $BUILD_RELEASE -eq $YES ]]; then
					echo -e " > ${COLOR_CYAN}cargo build --release --timings${COLOR_RESET}"
					if [[ $IS_DRY -eq $NO ]]; then
						if [[ $DEBUG_FLAGS -eq $YES ]]; then
							\cargo update  || exit 1
						fi
						\cargo build --release --timings  || exit 1
					fi
					echo -e " > ${COLOR_CYAN}grcov . -s . --binary-path ./target/release/ " \
						"-t html --branch --ignore-not-existing -o ./coverage/${COLOR_RESET}"
#TODO
#					if [[ $IS_DRY -eq $NO ]]; then
#						\grcov . -s .  \
#							--binary-path ./target/release/         \
#							-t html --branch --ignore-not-existing  \
#							-o ./coverage/
#					fi
				else
					echo -e " > ${COLOR_CYAN}cargo build${COLOR_RESET}"
					if [[ $IS_DRY -eq $NO ]]; then
						\cargo build  || exit 1
					fi
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



# --test
function doTests() {
	did_something=$NO
	doProjectTags
	[[ $QUIET -eq $NO ]] && \
		title C "$PROJECT_NAME" "Testing"
	# make check
	if [[ -f "$PROJECT_PATH/Makefile" ]]; then
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
	if [[ -f "$PROJECT_PATH/phpunit.xml" ]]; then
		\pushd "$PROJECT_PATH/" >/dev/null || exit 1
			echo -e " > ${COLOR_CYAN}phpunit${COLOR_RESET}"
			if [[ $IS_DRY -eq $NO ]]; then
				"$PROJECT_PATH"/vendor/bin/phpunit --coverage-html coverage/html  || exit 1
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



# --pack
function doPack() {
	local did_something=$NO
	doProjectTags
	[[ $QUIET -eq $NO ]] && \
		title C "$PROJECT_NAME" "Package"
	# build phar
	if [[ $PROJECT_PHAR -eq $YES ]]; then
		local CP_FLAGS=" -a"
		if [[ $DEBUG_FLAGS -eq $YES ]]; then
			local CP_FLAGS=" -L --copy-contents"
		fi
		# rm build-phar/
		if [[ -d build-phar ]]; then
			echo -ne " > ${COLOR_CYAN}rm -Rf build-phar${COLOR_RESET}"
			if [[ $IS_DRY -eq $NO ]]; then
				\pushd "$PROJECT_PATH" >/dev/null  || exit 1
					local c=$( \rm -Rvf --preserve-root build-phar | \wc -l )
					[[ 0 -ne $? ]] && exit 1
					echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
				\popd >/dev/null
			fi
		fi
		# mkdir build-phar/
		echo -e " > ${COLOR_CYAN}mkdir build-phar${COLOR_RESET}"
		if [[ $IS_DRY -eq $NO ]]; then
			\mkdir -v  build-phar/  || exit 1
		fi
		# cp composer.json/lock
		echo -ne " > ${COLOR_CYAN}cp$CP_FLAGS -v composer.{json,lock} build-phar/${COLOR_RESET}"
		if [[ $IS_DRY -eq $NO ]]; then
			local c=$( \cp$CP_FLAGS -v  composer.{json,lock}  build-phar/ | \wc -l )
			[[ 0 -ne $? ]] && exit 1
			echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
		fi
		# cp src/
		echo -ne " > ${COLOR_CYAN}cp$CP_FLAGS -vR src build-phar/${COLOR_RESET}"
		if [[ $IS_DRY -eq $NO ]]; then
			local c=$( \cp$CP_FLAGS -vR  src  build-phar/ | \wc -l )
			[[ 0 -ne $? ]] && exit 1
			echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
		fi
		# cp vendor/
		echo -ne " > ${COLOR_CYAN}cp$CP_FLAGS -vR vendor build-phar/${COLOR_RESET}"
		if [[ $IS_DRY -eq $NO ]]; then
			local c=$( \cp$CP_FLAGS -vR  vendor  build-phar/ | \wc -l )
			[[ 0 -ne $? ]] && exit 1
			echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
		fi
		# cp more/
		if [[ ! -z $PROJECT_PHAR_DIRS ]]; then
			for D in $PROJECT_PHAR_DIRS; do
				echo -e " > ${COLOR_CYAN}cp$CP_FLAGS -vR $D build-phar/${COLOR_RESET}"
				if [[ $IS_DRY -eq $NO ]]; then
					local c=$( \cp$CP_FLAGS -vR  "$D"  build-phar/ | \wc -l )
					[[ 0 -ne $? ]] && exit 1
					echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
				fi
			done
		fi
		# build phar
		echo -e " > ${COLOR_CYAN}phar-composer  build  build-phar${COLOR_RESET}"
		if [[ $IS_DRY -eq $NO ]]; then
			/usr/bin/php -d phar.readonly=off  \
			vendor/bin/phar-composer  build  build-phar  \
				|| exit 1
		fi
	fi
	# make dist
	if [[ -f "$PROJECT_PATH/Makefile" ]]; then
		\pushd "$PROJECT_PATH/" >/dev/null || exit 1
			echo -e " > ${COLOR_CYAN}make dist${COLOR_RESET}"
			if [[ $IS_DRY -eq $NO ]]; then
				\make dist  || exit 1
			fi
		\popd >/dev/null
		echo
		local did_something=$YES
	fi
	# find .spec file
	local SPEC_FILE_COUNT=$( \ls -1 "$PROJECT_PATH/"*.spec 2>/dev/null | \wc -l )
	if [[ $SPEC_FILE_COUNT -gt 1 ]]; then
		failure "$SPEC_FILE_COUNT .spec files were found here"
		failure ; exit 1
	fi
	local SPEC_FILE=""
	local SPEC_NAME=""
	if [[ $SPEC_FILE_COUNT -eq 1 ]]; then
		local SPEC_FILE=$( \ls -1 "$PROJECT_PATH/"*.spec )
		local SPEC_NAME=${SPEC_FILE%.*}
		local SPEC_NAME=${SPEC_NAME##*/}
	fi
	# build rpm
	if [[ -d rpmbuild ]]; then
		echo -ne " > ${COLOR_CYAN}rm rpmbuild${COLOR_RESET}"
		if [[ $IS_DRY -eq $NO ]]; then
			\pushd "$PROJECT_PATH" >/dev/null  || exit 1
				local c=$( \rm -Rvf --preserve-root rpmbuild/ | \wc -l )
				[[ 0 -ne $? ]] && exit 1
				echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
			\popd >/dev/null
		fi
	fi
	if [[ ! -z $SPEC_FILE ]]; then
		# rm rpmbuild/
		if [[ -d "$PROJECT_PATH/rpmbuild" ]]; then
			echo -ne " > ${COLOR_CYAN}rm rpmbuild${COLOR_RESET}"
			if [[ $IS_DRY -eq $NO ]]; then
				\pushd "$PROJECT_PATH" >/dev/null  || exit 1
					local c=$( \rm -Rvf --preserve-root rpmbuild/ | \wc -l )
					[[ 0 -ne $? ]] && exit 1
					echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
				\popd >/dev/null
			fi
		fi
		# make build root dirs
		echo -ne " > ${COLOR_CYAN}mkdir rpmbuild${COLOR_RESET}"
		local c=$( \mkdir -pv "$PROJECT_PATH"/rpmbuild/{BUILD,BUILDROOT,SOURCES,SPECS,RPMS,SRPMS,TMP} | \wc -l )
		[[ 0 -ne $? ]] && exit 1
		echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
		echo -e " > ${COLOR_CYAN}cp  "${SPEC_FILE##*/}"  rpmbuild/SPECS/${COLOR_RESET}"
		if [[ $IS_DRY -eq $NO ]]; then
			\cp -vf  "$SPEC_FILE"  "$PROJECT_PATH/rpmbuild/SPECS/"  || exit 1
		fi
		local PACKAGES=""
		\pushd "$PROJECT_PATH/rpmbuild/" >/dev/null  || exit 1
			if [[ -z $TARGET_PATH ]]; then
				failure "Target path not set"
				failure ; exit 1
			fi
			echo -e \
				" > ${COLOR_CYAN}rpmbuild\n"  \
				${BUILD_NUMBER:+"     --define=build_number $BUILD_NUMBER\n"}  \
				"     --define=_topdir $PROJECT_PATH/rpmbuild\n"               \
				"     --define=_tmppath $PROJECT_PATH/rpmbuild/TMP\n"          \
				"     --define=_binary_payload w9.gzdio\n"                     \
				"     --undefine=_disable_source_fetch\n"                      \
				"     -bb SPECS/${SPEC_NAME}.spec\n"                           \
				"${COLOR_RESET}"
			if [[ $IS_DRY -eq $NO ]]; then
				if [[ ! -e "$TARGET_PATH/" ]]; then
					\mkdir -pv "$TARGET_PATH/"  || exit 1
				fi
				\rpmbuild \
					${BUILD_NUMBER:+ --define="build_number $BUILD_NUMBER"} \
					--define="_topdir $PROJECT_PATH/rpmbuild" \
					--define="_tmppath $PROJECT_PATH/rpmbuild/TMP" \
					--define="_binary_payload w9.gzdio" \
					--undefine=_disable_source_fetch \
					-bb "SPECS/${SPEC_NAME}.spec" \
						|| exit 1
				echo
				\pushd "$PROJECT_PATH/rpmbuild/RPMS/" >/dev/null  || exit 1
					PACKAGES=$( \ls -1 *.rpm )
				\popd >/dev/null
				if [[ -z $PACKAGES ]]; then
					failure "Failed to find finished rpm packages: $PROJECT_PATH/rpmbuild/RPMS/"
					failure ; exit 1
				fi
				for ENTRY in $PACKAGES; do
					PACKAGES_ALL+=("$TARGET_PATH/$ENTRY")
					echo -e " > ${COLOR_CYAN}cp  rpmbuild/RPMS/$ENTRY  $TARGET_PATH${COLOR_RESET}"
					\cp -fv  "$PROJECT_PATH/rpmbuild/RPMS/$ENTRY"  "$TARGET_PATH/"  || exit 1
				done
			fi
		\popd >/dev/null
		echo
		echo -e "${COLOR_CYAN}-----------------------------------------------${COLOR_RESET}"
		echo -e "${COLOR_CYAN} Packages finished:${COLOR_RESET}"
		if [[ $IS_DRY -eq $NO ]]; then
			for ENTRY in $PACKAGES; do
				echo -e "   ${COLOR_CYAN}$ENTRY${COLOR_RESET}"
			done
		else
			echo -e "   ${COLOR_CYAN}DRY${COLOR_RESET}"
		fi
		echo -e "${COLOR_CYAN}-----------------------------------------------${COLOR_RESET}"
		local did_something=$YES
	fi
	# nothing to do
	if [[ $did_something -eq $YES ]]; then
		DisplayTime "Package"
		COUNT_OPS=$((COUNT_OPS+1))
	else
		notice "Nothing found to package.."
		echo
	fi
}



# ----------------------------------------



function Version() {
	if [[ ! -z $1 ]]; then
		if [[ -z $BUILD_NUMBER ]]; then
			PROJECT_VERSION="$1"
		else
			PROJECT_VERSION=${1/x/$BUILD_NUMBER}
		fi
	fi
}

function Path() {
	if [[ ! -z $1 ]]; then
		PROJECT_PATH="$1"
	fi
}

function Repo() {
	if [[ ! -z $1 ]]; then
		PROJECT_REPO="$1"
	fi
}

function Alias() {
	if [[ ! -z $1 ]]; then
		PROJECT_ALIASES="$PROJECT_ALIASES $1"
	fi
}

function TagFile() {
	if [[ ! -z $1 ]]; then
		PROJECT_TAG_FILES="$PROJECT_TAG_FILES $1"
	fi
}

function AddIgnore() {
	if [[ ! -z $1 ]]; then
		PROJECT_GITIGNORE="$PROJECT_GITIGNORE $1"
	fi
}

function AddPhar() {
	if [[ -d "$1" ]]; then
		failure "Path not found, cannot add to phar: $1"
		failure ; exit 1
	fi
	PROJECT_PHAR_DIRS="$PROJECT_PHAR_DIRS $1"
}


function LoadConf() {
	ProjectCleanup
	if [[ -z $1 ]]; then
		failure "LoadConf() requires file argument"
		failure ; exit 1
	fi
	if [[ "$1" != *"/xbuild.conf" ]]; then
		failure "Invalid config file: $1"
		failure ; exit 1
	fi
	local LAST_PATH="$CURRENT_PATH"
	CURRENT_PATH=${1%/*}
	\pushd "$CURRENT_PATH" >/dev/null  || exit 1
		# load xbuild.conf
		source "$CURRENT_PATH/xbuild.conf" || exit 1
		# last project in conf file
		doProject
		ProjectCleanup
	\popd >/dev/null
	CURRENT_PATH="$LAST_PATH"
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
				echo -e " > ${COLOR_CYAN}rm -fv $F${COLOR_RESET}"
			[[ $IS_DRY -eq $NO ]] && \
				\rm -fv  "$PROJECT_PATH/$F"  || exit 1
		else
			[[ $VERBOSE -eq $YES ]] && \
				echo -e " > ${COLOR_CYAN}mv -v $F ${F}.xbuild_temp${COLOR_RESET}"
			[[ $IS_DRY -eq $NO ]] && \
				\mv -v  "$PROJECT_PATH/$F"  "$PROJECT_PATH/${F}.xbuild_temp"  || exit 1
		fi
		[[ $VERBOSE -eq $YES ]] && \
			echo -e " > ${COLOR_CYAN}cp -v ${F}.xbuild_temp $F${COLOR_RESET}"
		[[ $IS_DRY -eq $NO ]] && \
			\cp -v  "$PROJECT_PATH/${F}.xbuild_temp"  "$PROJECT_PATH/$F"  || exit 1
		# tags
		if [[ ! -z $PROJECT_VERSION ]]; then
			# special case for rust/cargo
			if [[ "$PROJECT_PATH/$F" == *"/Cargo.toml" ]]; then
				if [[ ! -z $BUILD_NUMBER ]] && [[ "$BUILD_NUMBER" != "x" ]]; then
					local VERS_GUESS=${PROJECT_VERSION%.*}".0"
					[[ $VERBOSE -eq $YES ]] && \
						echo -e " > ${COLOR_CYAN}sed -i 's/$VERS_GUESS/$PROJECT_VERSION/' $F${COLOR_RESET}"
					[[ $IS_DRY -eq $NO ]] && \
						\sed -i  "s/$VERS_GUESS/$PROJECT_VERSION/"  "$PROJECT_PATH/$F"  || exit 1
				fi
			# {{{VERSION}}}
			else
				[[ $VERBOSE -eq $YES ]] && \
					echo -e " > ${COLOR_CYAN}sed -i 's/{{""{VERSION}}}/$PROJECT_VERSION/' $F${COLOR_RESET}"
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
				\rm -f  "$PROJECT_PATH/$F"  || exit 1
			fi
			\mv  "$PROJECT_PATH/${F}.xbuild_temp"  "$PROJECT_PATH/$F"  || exit 1
		fi
	done
	[[ $VERBOSE -eq $YES ]] && \
		echo
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
	if [[ $QUIET -eq $NO ]] && [[ "$PROJECT_PATH" != "$CURRENT_PATH" ]]; then
		title B "$PROJECT_NAME"
		echo -e " ${COLOR_GREEN}>${COLOR_RESET} ${COLOR_BLUE}$PROJECT_PATH${COLOR_RESET}"
		echo
	fi
#TODO: improve this
	if [[ ! -z $PROJECT_VERSION ]]; then
		echo -e "Version: $COLOR_GREEN$PROJECT_VERSION$COLOR_RESET"
	fi
	# --pp
	[[ $DO_PP -eq $YES ]] && doPullPush
	# --gg
	[[ $DO_GG -eq $YES ]] && doGitGUI
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
			ProjectCleanup
			return
		fi
	fi
	# project in current path
	# --clean
	[[ $DO_CLEAN  -eq $YES ]] && doClean
	# --config
	[[ $DO_CONFIG -eq $YES ]] && doConfig
	# --build
	[[ $DO_BUILD  -eq $YES ]] && doBuild
	# --tests
	[[ $DO_TESTS  -eq $YES ]] && doTests
	# --pack
	[[ $DO_PACK   -eq $YES ]] && doPack
	# project done
	COUNT_PRJ=$((COUNT_PRJ+1))
	DisplayTimeProject
	ProjectCleanup
}

function ProjectCleanup() {
	restoreProjectTags
	PROJECT_NAME=""
	PROJECT_VERSION=""
	PROJECT_PATH=""
	PROJECT_REPO=""
	PROJECT_ALIASES=""
	PROJECT_PHAR=$NO
	PROJECT_PHAR_FILES=""
	PROJECT_GITIGNORE=""
	PROJECT_TAG_FILES=""
	PROJECT_TAGS_DONE=$NO
	TIME_START_PRJ=$( \date "+%s%N" )
	TIME_LAST=$TIME_START_PRJ
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

	-r|--recursive)  DO_RECURSIVE=$YES   ;;
	-D|--dry)        IS_DRY=$YES         ;;
	-R|--release)    BUILD_RELEASE=$YES  ;;
	-d|--debug|--debug-flag|--debug-flags)  DEBUG_FLAGS=$YES  ;;
	-n|--build-number)
		if [[ "$2" == "-"* ]]; then
			failure "--build-number flag requires a value"
			failure ; DisplayHelp ; exit 1
		fi
		\shift
		BUILD_NUMBER="$1"
	;;
	--build-number=*)
		BUILD_NUMBER=${1#*=}
		if [[ -z $BUILD_NUMBER ]]; then
			failure "--build-number flag requires a value"
			failure ; DisplayHelp ; exit 1
		fi
	;;
	--target)
		if [[ "$2" == "-"* ]]; then
			failure "--target flag requires a value"
			failure ; DisplayHelp ; exit 1
		fi
		\shift
		TARGET_PATH="$1"
	;;
	--target=*)
		TARGET_PATH=${1#*=}
		if [[ -z $TARGET_PATH ]]; then
			failure "--target flag requires a value"
			failure ; DisplayHelp ; exit 1
		fi
	;;

	--binonly)  DO_BIN_ONLY=$YES  ;;
	--webonly)  DO_WEB_ONLY=$YES  ;;

	--pp|--pull-push|--push-pull)  DO_PP=$YES  ;;
	--gg|--git-gui)                DO_GG=$YES  ;;

	-c|--clean|--clear|--cleanup)  DO_CLEAN=$YES   ;;
	-C|--config|--configure)       DO_CONFIG=$YES  ;;
	-b|--build|--compile)          DO_BUILD=$YES   ;;
	--test|--tests|--testing)      DO_TESTS=$YES   ;;
	-p|--pack|--package)           DO_PACK=$YES    ;;

	--cb)     DO_CONFIG=$YES ; DO_BUILD=$YES  ;;
	--cbp)    DO_CONFIG=$YES ; DO_BUILD=$YES  ; DO_PACK=$YES  ;;
	--ccb)    DO_CLEAN=$YES  ; DO_CONFIG=$YES ; DO_BUILD=$YES ;;
	--cbtp)   DO_CONFIG=$YES ; DO_BUILD=$YES  ; DO_TESTS=$YES ; DO_PACK=$YES  ;;
	--ccbp)   DO_CLEAN=$YES  ; DO_CONFIG=$YES ; DO_BUILD=$YES ; DO_PACK=$YES  ;;
	--ccbtp)  DO_CLEAN=$YES  ; DO_CONFIG=$YES ; DO_BUILD=$YES ; DO_TESTS=$YES ; DO_PACK=$YES  ;;

	--dev)
		DO_CONFIG=$YES ; DO_BUILD=$YES ; DO_PACK=$YES
		DEBUG_FLAGS=$YES ; DO_RECURSIVE=$YES ; VERBOSE=$YES
	;;
	--ci)
		if [[ "$2" == "-"* ]]; then
			failure "--ci flag requires a value"
			failure ; DisplayHelp ; exit 1
		fi
		DO_CLEAN=$YES ; DO_CONFIG=$YES ; DO_BUILD=$YES
		DO_TESTS=$YES ; DO_PACK=$YES   ; VERBOSE=$YES
		DO_RECURSIVE=$YES ; BUILD_RELEASE=$YES
		\shift
		BUILD_NUMBER="$1"
	;;

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

if [[ ! -f "$WDIR/xbuild.conf" ]]; then
	failure "xbuild.conf not found here"
	failure ; exit 1
fi

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
	if [[ $BUILD_RELEASE -eq $YES ]]; then
		notice "Production Mode"
		did_notice=$YES
		if [[ $DEBUG_FLAGS -eq $YES ]]; then
			warning "Production mode and debug mode are active at the same time"
		fi
	fi
	if [[ $DO_PACK -eq $YES ]]; then
		notice "Deploy to: $TARGET_PATH"
		did_notice=$YES
	fi
	if [[ $DO_BIN_ONLY -eq $YES ]]; then
		notice "Bin Only"
		did_notice=$YES
	fi
	if [[ $DO_WEB_ONLY -eq $YES ]]; then
		notice "Web Only"
		did_notice=$YES
	fi
	[[ $did_notice -eq $YES ]] && echo

	if [[ ! -z $PROJECT_FILTERS ]]; then
		echo "Filters:"
		for FILTER in $PROJECT_FILTERS; do
			echo -e "  ${COLOR_BLUE}"${FILTER##*/}"${COLOR_RESET}"
		done
#TODO
warning "Filters are unfinished and unsupported"
		echo
	fi
fi



# clean root target/
if [[ $DO_CLEAN -eq $YES ]]; then
	if [[ ! -z $TARGET_PATH ]] \
	&& [[ -d "$TARGET_PATH" ]]; then
		echo -ne " > ${COLOR_CYAN}rm -rf target${COLOR_RESET}"
		if [[ $IS_DRY -eq $NO ]]; then
			c=$( \rm -vrf --preserve-root target | wc -l )
			[[ 0 -ne $? ]] && exit 1
			echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
		fi
	fi
fi



# start loading
LoadConf "$WDIR/xbuild.conf"



if [[ $QUIET -eq $NO ]]; then
	echo -e "${COLOR_GREEN}===============================================${COLOR_RESET}"
	echo
	if [[ $COUNT_OPS -le 0 ]]; then
		warning "No actions performed"
		warning ; exit 1
	fi
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
	echo -e "${COLOR_BLUE} Packages finished:${COLOR_RESET}"
	for ENTRY in ${PACKAGES_ALL[@]}; do
		echo -e "${COLOR_BLUE}   "${ENTRY##*/}"${COLOR_RESET}"
	done
	echo
fi

exit 0
