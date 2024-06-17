# 30-clean.sh
# --clean


if [[ " $ACTIONS " == *" clean "* ]]; then
	ACTIONS_FOUND="$ACTIONS_FOUND clean"
	[[ $QUIET -eq $NO ]] && \
		title C "Clean"
	let count=0
	let rm_groups=0
	restoreProjectTags
	# make clean
	if [[ -f "$PROJECT_PATH/Makefile.am" ]]; then
		if [[ -f "$PROJECT_PATH/Makefile" ]]; then
			\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
				echo_cmd -n "make distclean"
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
		\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
			# remove .deps/ dirs
			RESULT=$( \find "$PROJECT_PATH" -type d -name .deps )
			for ENTRY in $RESULT; do
				if [[ -f "$ENTRY" ]]; then
					echo_cmd -n "rm ${ENTRY}.."
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
					echo_cmd -n "rm -rf $ENTRY"
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
				\pushd  "$DIR/"  >/dev/null || continue
					for ENTRY in $CLEAN_FILES; do
						if [[ -f "$ENTRY" ]]; then
							echo_cmd -n "rm $ENTRY"
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
							echo_cmd -n "rm -rf $ENTRY"
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
		\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
			echo_cmd -n "rm -rf rpmbuild"
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
	if [[ "$WDIR" != "$PROJECT_PATH" ]] \
	&& [[ -d "$PROJECT_PATH/target" ]]; then
		\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
			echo_cmd -n "rm -rf target"
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
	# clean gradle
	if [[ -d "$PROJECT_PATH/gradle" ]]; then
		\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
			echo_cmd -n "rm -rf  gradle"
			let rm_groups=$((rm_groups+1))
			if [[ $IS_DRY -eq $NO ]]; then
				local c=$( \rm -vrf --preserve-root  gradle .gradle gradlew gradlew.bat  | wc -l )
				[[ 0 -ne $? ]] && exit 1
				[[ $c -gt 0 ]] && count=$((count+c))
				echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
			else
				echo
			fi
		\popd >/dev/null
	fi
	# clean build
	if [[ -d "$PROJECT_PATH/build" ]]; then
		\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
			echo_cmd -n "rm -rf  build"
			let rm_groups=$((rm_groups+1))
			if [[ $IS_DRY -eq $NO ]]; then
				local c=$( \rm -vrf --preserve-root  build  | wc -l )
				[[ 0 -ne $? ]] && exit 1
				[[ $c -gt 0 ]] && count=$((count+c))
				echo -e " ${COLOR_BLUE}${c}${COLOR_RESET}"
			else
				echo
			fi
		\popd >/dev/null
	fi
	# clean php project
	if [[ -f "$PROJECT_PATH/composer.json" ]]; then
		# clean vendor/
		if [[ -d "$PROJECT_PATH/vendor" ]]; then
			\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
				echo_cmd -n "rm -rf vendor"
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
	COUNT_ACT=$((COUNT_ACT+1))
fi
