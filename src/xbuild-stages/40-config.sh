# 40-config.sh
# --config


if [[ " $ACTIONS " == *" config "* ]]; then
	ACTIONS_FOUND="$ACTIONS_FOUND config"
	# version not set
	if [[ -z $PROJECT_VERSION ]]; then
		[[ $QUIET -eq $NO ]] && \
			title C  "Configure"  "$PROJECT_NAME"
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
	# stub files
	if [[ $DO_CI -eq $NO ]]; then
		FILES_EXIST=$NO
		for FILE in \
				/etc/xbuild/stubs/.* \
				/etc/xbuild/stubs/*; do
			FILENAME=${FILE##*/}
			if [[ "$FILENAME" == "app.properties" ]]; then
				FILENAME="resources/$FILENAME"
			fi
			# has file
			if [[ ! -z $FILENAME               ]] \
			&& [[ -f "$PROJECT_PATH/$FILENAME" ]]; then
				FILES_EXIST=$YES
				SRC_FILE="$FILE"
				TMP_FILE=""
				# files needing temp
				case "$FILENAME" in
				".gitignore")
					if [[ ! -z $PROJECT_GITIGNORE    ]] \
					|| [[ ! -z $PROJECT_GITIGNOREEND ]]; then
						TMP_FILE=$( mktemp )
						RESULT=$?
						if [[ $RESULT -ne 0 ]] || [[ -z $TMP_FILE ]]; then
							failure "Failed to create a temp file for $FILENAME"
							failure ; exit $RESULT
						fi
						# prepend
						if [[ ! -z $PROJECT_GITIGNORE    ]]; then
							for ENTRY in $PROJECT_GITIGNORE; do
								echo "$ENTRY" >>"$TMP_FILE"
							done
							echo >>"$TMP_FILE"
						fi
						# default content
						\cat  "$FILE"  >>"$TMP_FILE"  || exit 1
						# append
						if [[ ! -z $PROJECT_GITIGNOREEND ]]; then
							echo >>"$TMP_FILE"
							for ENTRY in $PROJECT_GITIGNOREEND; do
								echo "$ENTRY" >>"$TMP_FILE"
							done
						fi
					fi
					;;
				".gitattributes")
					if [[ ! -z $PROJECT_GITATTRIB ]]; then
						TMP_FILE=$( mktemp )
						RESULT=$?
						if [[ $RESULT -ne 0 ]] || [[ -z $TMP_FILE ]]; then
							failure "Failed to create a temp file for $FILENAME"
							failure ; exit $RESULT
						fi
						# prepend
						for ENTRY in $PROJECT_GITATTRIB; do
							echo "$ENTRY" >>"$TMP_FILE"
						done
						echo >>"$TMP_FILE"
						# default content
						\cat  "$FILE"  >>"$TMP_FILE"  || exit 1
					fi
					;;
				"phpunit.xml")
					TMP_FILE=$( mktemp )
					RESULT=$?
					if [[ $RESULT -ne 0 ]] || [[ -z $TMP_FILE ]]; then
						failure "Failed to create a temp file for $FILENAME"
						failure ; exit $RESULT
					fi
					DATA=$( \cat "$FILE" )
					if [[ -z $DATA ]]; then
						failure "Failed to load /etc/xbuild/phpunit_xml"
						failure ; exit 1
					fi
					if [[ -e "$PROJECT_PATH/tests/bootstrap.php" ]]; then
						DATA=${DATA/<BOOTSTRAP>/tests\/bootstrap.php}
					else
						DATA=${DATA/<BOOTSTRAP>/vendor\/autoload.php}
					fi
					echo "$DATA" >>"$TMP_FILE" || exit 1
					;;
				esac
				if [[ ! -z $TMP_FILE ]]; then
					SRC_FILE="$TMP_FILE"
				fi
				echo_cmd "md5sum $FILENAME"
				HASH_SRC=$( \cat "$SRC_FILE"               | \md5sum )
				HASH_DST=$( \cat "$PROJECT_PATH/$FILENAME" | \md5sum )
				if [[ "$HASH_SRC" != "$HASH_DST" ]]; then
					title C  "Updating $FILENAME .."
					echo_cmd "cat $SRC_FILE > $PROJECT_PATH/$FILENAME"
					if [[ $IS_DRY -eq $NO ]]; then
						\cat  "$SRC_FILE"  >"$PROJECT_PATH/$FILENAME"  || exit 1
						did_something=$YES
					fi
				fi
				# cleanup temp
				if [[ ! -z $TMP_FILE ]]; then
					\rm -f  "$TMP_FILE"
				fi
			fi
			# end has file
		done
		if [[ $FILES_EXIST -eq $YES ]]; then
			echo
		fi
		# end stub FILE
		# automake
		if [[ $DO_CI -eq $NO ]]; then
			# generate automake files
			if [[ -f "$PROJECT_PATH/autotools.conf" ]]; then
				[[ $QUIET -eq $NO ]] && \
					title C  "Generate autotools"  "$PROJECT_NAME"
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
					title C  "autoreconf"  "$PROJECT_NAME"
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
				title C  "Generate pom"  "$PROJECT_NAME"
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
					SNAPSHOT=""
					[[ -z $PROJECT_VERSION ]] || \
						SNAPSHOT="--snapshot $PROJECT_VERSION"
					echo_cmd -n "genpom $SNAPSHOT"
					if [[ $IS_DRY -eq $NO ]]; then
						\genpom  $SNAPSHOT  || exit 1
					else
						echo
					fi
#TODO: capture the output of this
					# check for dependency updates
					if [[ $DEBUG_FLAGS -eq $YES ]]; then
						[[ $QUIET -eq $NO ]] && \
							title C  "Check dependency updates"  "$PROJECT_NAME"
						echo_cmd "mvn versions:display-dependency-updates versions:display-plugin-updates"
						if [[ $IS_DRY -eq $NO ]]; then
							\mvn  versions:display-dependency-updates  versions:display-plugin-updates
						fi
					fi
				fi
			\popd >/dev/null
			echo
			did_something=$YES
		fi
		# generate .spec file
		if [[ -f "$PROJECT_PATH/spec.conf" ]]; then
			[[ $QUIET -eq $NO ]] && \
				title C  "Generate spec"  "$PROJECT_NAME"
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
						title C  "Composer Install"  "$PROJECT_NAME"
					echo_cmd "composer install -a -o --no-dev --prefer-dist"
					if [[ $IS_DRY -eq $NO ]]; then
						\composer install --no-dev --prefer-dist --classmap-authoritative --optimize-autoloader  || exit 1
					fi
				# configure for dev
				else
					if [[ $DEBUG_FLAGS -eq $YES ]] \
					|| [[ ! -f "$PROJECT_PATH/composer.lock" ]]; then
						[[ $QUIET -eq $NO ]] && \
							title C  "Composer Update"  "$PROJECT_NAME"
						echo_cmd "composer update"
						if [[ $IS_DRY -eq $NO ]]; then
							\composer update  || exit 1
						fi
					else
						[[ $QUIET -eq $NO ]] && \
							title C  "Composer Install"  "$PROJECT_NAME"
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
			title C  "Configure"
		notice "Nothing found to configure.."
		echo
	fi
fi
