# 40-config.sh
# --config


if [[ " $ACTIONS " == *" config "* ]]; then
	ACTIONS_FOUND="$ACTIONS_FOUND config"
	# version not set
	if [[ -z $PROJECT_VERSION ]]; then
		[[ $QUIET -eq $NO ]] && \
			title C "Configure"
		notice "Skipping config - project version not detected"
		echo
		return
	fi
	did_something=$NO
	doProjectTags
	# run commands
	for ENTRY in "${RUN_CONFIG[@]}"; do
		notice "Running: $ENTRY"
		if [[ $IS_DRY -eq $NO ]]; then
			. "$ENTRY" || exit 1
		fi
	done
	if [[ $DO_CI -eq $NO ]]; then
		# .gitignore
		if [[ -f "$PROJECT_PATH/.gitignore" ]]; then
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
				echo_cmd "cat $OUT_FILE > $PROJECT_PATH/.gitignore"
				if [[ $IS_DRY -eq $NO ]]; then
					\cat  "$OUT_FILE"  >"$PROJECT_PATH/.gitignore"  || exit 1
				fi
				did_something=$YES
			fi
			\rm -f "$OUT_FILE"
		fi
		# .gitattributes
		if [[ -f "$PROJECT_PATH/.gitattributes" ]]; then
			local OUT_FILE=$( mktemp )
			local RESULT=$?
			if [[ $RESULT -ne 0 ]] || [[ -z $OUT_FILE ]]; then
				failure "Failed to create a temp file for .gitattributes"
				failure ; exit $RESULT
			fi
			if [[ ! -z $PROJECT_GITATTRIB ]]; then
				for ENTRY in $PROJECT_GITATTRIB; do
					echo "$ENTRY" >>"$OUT_FILE"
				done
				echo >>"$OUT_FILE"
			fi
			\cat /etc/xbuild/gitattributes >>"$OUT_FILE" || exit 1
			local HASH_A=$( \cat "$OUT_FILE"                    | \md5sum )
			local HASH_B=$( \cat "$PROJECT_PATH/.gitattributes" | \md5sum )
			if [[ "$HASH_A" != "$HASH_B" ]]; then
				title C "Updating .gitattributes.."
				echo_cmd "cat $OUT_FILE > $PROJECT_PATH/.gitattributes"
				if [[ $IS_DRY -eq $NO ]]; then
					\cat  "$OUT_FILE"  >"$PROJECT_PATH/.gitattributes"  || exit 1
				fi
				did_something=$YES
			fi
			\rm -f "$OUT_FILE"
		fi
		# automake
		if [[ $DO_CI -eq $NO ]]; then
			# generate automake files
			if [[ -f "$PROJECT_PATH/autotools.conf" ]]; then
				[[ $QUIET -eq $NO ]] && \
					title C "Generate autotools"
				\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
					echo_cmd -n "genautotools"
					if [[ $IS_DRY -eq $NO ]]; then
						\genautotools  || exit 1
					else
						echo
					fi
				\popd >/dev/null
				echo
				did_something=$YES
			fi
			# automake
			if [[ -f "$PROJECT_PATH/configure.ac" ]]; then
				[[ $QUIET -eq $NO ]] && \
					title C "autoreconf"
				\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
					echo_cmd "autoreconf -v --install"
					if [[ $IS_DRY -eq $NO ]]; then
						\autoreconf -v --install  || exit 1
					fi
				\popd >/dev/null
				echo
				did_something=$YES
			fi
		fi
		# generate pom.xml file
		if [[ -f "$PROJECT_PATH/pom.conf" ]]; then
			[[ $QUIET -eq $NO ]] && \
				title C "Generate pom"
			\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
				# configure for release
				if [[ $ALLOW_RELEASE   -eq $YES ]] \
				&& [[ $PROJECT_RELEASE -eq $YES ]]; then
					echo_cmd -n "genpom --release $PROJECT_VERSION"
					if [[ $IS_DRY -eq $NO ]]; then
						\genpom  --release $PROJECT_VERSION  || exit 1
					else
						echo
					fi
				# configure for snapshot
				else
					local SNAPSHOT=""
					[[ -z $PROJECT_VERSION ]] || \
						SNAPSHOT="--snapshot $PROJECT_VERSION"
					echo_cmd -n "genpom $SNAPSHOT"
					if [[ $IS_DRY -eq $NO ]]; then
						\genpom  $SNAPSHOT  || exit 1
					else
						echo
					fi
				fi
			\popd >/dev/null
			echo
			did_something=$YES
		fi
		# generate .spec file
		if [[ -f "$PROJECT_PATH/spec.conf" ]]; then
			[[ $QUIET -eq $NO ]] && \
				title C "Generate spec"
			\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
				echo_cmd -n "genspec"
				if [[ $IS_DRY -eq $NO ]]; then
					\genspec  || exit 1
				else
					echo
				fi
			\popd >/dev/null
			echo
			did_something=$YES
		fi
		# composer
		if [[ -f "$PROJECT_PATH/composer.json" ]]; then
			\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
				# configure for release
				if [[ $ALLOW_RELEASE   -eq $YES ]] \
				&& [[ $PROJECT_RELEASE -eq $YES ]] \
				&& [[ -f "$PROJECT_PATH/composer.lock" ]]; then
					[[ $QUIET -eq $NO ]] && \
						title C "Composer Install"
					echo_cmd "composer install -a -o --no-dev --prefer-dist"
					if [[ $IS_DRY -eq $NO ]]; then
						\composer install --no-dev --prefer-dist --classmap-authoritative --optimize-autoloader  || exit 1
					fi
				# configure for dev
				else
					if [[ $DEBUG_FLAGS -eq $YES ]] \
					|| [[ ! -f "$PROJECT_PATH/composer.lock" ]]; then
						[[ $QUIET -eq $NO ]] && \
							title C "Composer Update"
						echo_cmd "composer update"
						if [[ $IS_DRY -eq $NO ]]; then
							\composer update  || exit 1
						fi
					else
						[[ $QUIET -eq $NO ]] && \
							title C "Composer Install"
						echo_cmd "composer install"
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
		COUNT_ACT=$((COUNT_ACT+1))
	else
		[[ $QUIET -eq $NO ]] && \
			title C "Configure"
		notice "Nothing found to configure.."
		echo
	fi
fi
