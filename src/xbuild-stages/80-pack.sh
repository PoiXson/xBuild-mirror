# 80-pack.sh
# --pack


if [[ " $ACTIONS " == *" pack "* ]]; then
	ACTIONS_FOUND="$ACTIONS_FOUND pack"
	local did_something=$NO
	doProjectTags
	[[ $QUIET -eq $NO ]] && \
		title C  "Package"  "$PROJECT_NAME"
	# make dist
	if [[ -f "$PROJECT_PATH/Makefile" ]]; then
		\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
			echo_cmd "make dist"
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
		SPEC_FILE=$( \ls -1 "$PROJECT_PATH/"*.spec )
		SPEC_NAME=${SPEC_FILE%.*}
		SPEC_NAME=${SPEC_NAME##*/}
	fi
	# build rpm
	if [[ ! -z $SPEC_FILE ]]; then
		# rm rpmbuild/
		if [[ -d "$PROJECT_PATH/rpmbuild" ]]; then
			echo_cmd -n "rm rpmbuild"
			if [[ $IS_DRY -eq $NO ]]; then
				\pushd  "$PROJECT_PATH"  >/dev/null  || exit 1
					local c=$( \rm -Rvf --preserve-root rpmbuild/ | \wc -l )
					[[ 0 -ne $? ]] && exit 1
					echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
				\popd >/dev/null
			else
				echo
			fi
		fi
		# make build root dirs
		echo_cmd -n "mkdir rpmbuild/.."
		local c=$( \mkdir -pv "$PROJECT_PATH"/rpmbuild/{BUILD,BUILDROOT,SOURCES,SPECS,RPMS,SRPMS,TMP} | \wc -l )
		[[ 0 -ne $? ]] && exit 1
		echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
		echo_cmd "cp  "${SPEC_FILE##*/}"  rpmbuild/SPECS/"
		if [[ $IS_DRY -eq $NO ]]; then
			\cp -vf  "$SPEC_FILE"  "$PROJECT_PATH/rpmbuild/SPECS/"  || exit 1
		fi
		local PACKAGES=""
		local PACKAGES_DEB=""
		\pushd  "$PROJECT_PATH/rpmbuild/"  >/dev/null  || exit 1
			if [[ -z $TARGET_PATH ]]; then
				failure "Target path not set"
				failure ; exit 1
			fi
			echo_cmd "rpmbuild"                                              \
				${BUILD_NUMBER:+"     --define=build_number $BUILD_NUMBER"}  \
				"     --define=_topdir $PROJECT_PATH/rpmbuild"               \
				"     --define=_tmppath $PROJECT_PATH/rpmbuild/TMP"          \
				"     --define=_binary_payload w9.gzdio"                     \
				"     --undefine=_disable_source_fetch"                      \
				"     -bb SPECS/${SPEC_NAME}.spec"
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
				\pushd  "$PROJECT_PATH/rpmbuild/RPMS/"  >/dev/null  || exit 1
					PACKAGES=$( \ls -1 *.rpm )
				\popd >/dev/null
				if [[ -z $PACKAGES ]]; then
					failure "Failed to find finished rpm packages: $PROJECT_PATH/rpmbuild/RPMS/"
					failure ; exit 1
				fi
				for ENTRY in $PACKAGES; do
					PACKAGES_ALL+=("$TARGET_PATH/$ENTRY")
					echo_cmd "cp  rpmbuild/RPMS/$ENTRY  $TARGET_PATH"
					\cp -fv  "$PROJECT_PATH/rpmbuild/RPMS/$ENTRY"  "$TARGET_PATH/"  || exit 1
				done
#TODO
#				if [[ -e /usr/bin/alien  ]] \
#				&& [[ $DO_ALIEN -eq $YES ]]; then
#					\pushd  "$TARGET_PATH/"  >/dev/null  || exit 1
#						for ENTRY in $PACKAGES; do
#							if [[ "$ENTRY" == *".noarch.rpm" ]]; then
#								echo
#								echo_cmd "alien --to-deb --scripts $ENTRY"
#								if [[ $IS_DRY -eq $NO ]]; then
#									\fakeroot \alien  -v --to-deb --scripts  "$ENTRY"  || exit 1
#								fi
#							fi
#						done
#						PACKAGES_DEB=$( \ls -1 *.deb )
#						for ENTRY in $PACKAGES_DEB; do
#							PACKAGES_ALL+=("$TARGET_PATH/$ENTRY")
#						done
#					\popd >/dev/null
#				fi
			fi
		\popd >/dev/null
		echo
		echo -e " ${COLOR_CYAN}-----------------------------------------------${COLOR_RESET}"
		echo -e " ${COLOR_CYAN}Packages finished:${COLOR_RESET}"
		if [[ $IS_DRY -eq $NO ]]; then
			for ENTRY in $PACKAGES; do
				echo -e "   ${COLOR_CYAN}$ENTRY${COLOR_RESET}"
			done
		else
			echo -e "   ${COLOR_CYAN}DRY${COLOR_RESET}"
		fi
		echo -e " ${COLOR_CYAN}-----------------------------------------------${COLOR_RESET}"
		local did_something=$YES
	fi
	# nothing to do
	if [[ $did_something -eq $YES ]]; then
		DisplayTime "Package"
		COUNT_ACT=$((COUNT_ACT+1))
	else
		notice "Nothing found to package.."
		echo
	fi
fi
