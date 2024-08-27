# 30-clean.sh
# --clean


if [[ " $ACTIONS " == *" clean "* ]]; then
	ACTIONS_FOUND="$ACTIONS_FOUND clean"
	[[ $QUIET -eq $NO ]] && \
		title C "Clean"
	LAST_RM_TOTAL=$RM_TOTAL
	restoreProjectTags
	# make clean
	if [[ -f "$PROJECT_PATH/Makefile.am" ]]; then
		if [[ -f "$PROJECT_PATH/Makefile" ]]; then
			\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
				echo_cmd -n "make distclean"
				if [[ $IS_DRY -eq $NO ]]; then
					c=$( \make distclean | \wc -l )
					[[ 0 -ne $? ]] && exit 1
					echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
					if [[ $c -gt 0 ]]; then
						let RM_GROUPS=$((RM_GROUPS+1))
						let RM_TOTAL=$((RM_TOTAL+c))
					fi
				else
					echo
				fi
			\popd >/dev/null
		fi
	fi
	\pushd  "$PROJECT_PATH/"  >/dev/null || return
		# remove .deps/ dirs
		RESULT=$( \find "$PROJECT_PATH" -type d -name ".deps" )
		if [[ ! -z $RESULT ]]; then
			doClean "$RESULT"
		fi
		# remove more files
		if [[ -d "$PROJECT_PATH/src/" ]]; then
			local CLEAN_FILES="autom4te.cache aclocal.m4 compile configure config.log config.guess config.status config.sub depcomp install-sh ltmain.sh Makefile Makefile.in missing"
			doClean "$CLEAN_FILES"
			\pushd  "$PROJECT_PATH/src/"  >/dev/null || return
				doClean "$CLEAN_FILES"
			\popd >/dev/null
		fi
		doClean "target build bin run rpmbuild"
		# super clean
		if [[ $DO_SUPER_CLEAN -eq $YES ]]; then
			doClean ".project .classpath .settings gradle .gradle gradlew gradlew.bat vendor"
		fi
	\popd >/dev/null
	echo
	let COUNT=$((RM_TOTAL-LAST_RM_TOTAL))
	if [[ $COUNT -gt 1 ]]; then
		echo -e " ${COLOR_CYAN}Removed ${COLOR_BLUE}${COUNT}${COLOR_CYAN} files/dirs"
		DisplayTime "Cleaned"
	# nothing to do
	elif [[ $RM_GROUPS -le 0 ]]; then
		notice "Nothing to clean.."
	fi
	COUNT_ACT=$((COUNT_ACT+1))
fi
