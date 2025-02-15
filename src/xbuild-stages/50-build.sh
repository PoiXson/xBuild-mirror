# 50-build.sh
# --build


if [[ " $ACTIONS " == *" build "* ]]; then
	ACTIONS_FOUND="$ACTIONS_FOUND build"
	did_something=$NO
	[[ $QUIET -eq $NO ]] && \
		title C  "Build"  "$PROJECT_NAME"
	doProjectTags
	# run commands
	for ENTRY in "${RUN_BUILD[@]}"; do
		notice "Running: $ENTRY"
		if [[ $IS_DRY -eq $NO ]]; then
			eval  "$ENTRY"  || exit 1
			did_something=$YES
		fi
	done
	# automake
	if [[ -f "$PROJECT_PATH/configure" ]]; then
		\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
			CONFIGURE_DEBUG_FLAGS=""
			if [[ $DEBUG_FLAGS -eq $YES ]]; then
				CONFIGURE_DEBUG_FLAGS="--enable-debug"
			fi
			echo_cmd "configure ${CONFIGURE_DEBUG_FLAGS}"
			if [[ $IS_DRY -eq $NO ]]; then
				./configure $CONFIGURE_DEBUG_FLAGS  || exit 1
			fi
		\popd >/dev/null
		echo
		did_something=$YES
	fi
	# make
	if [[ -f "$PROJECT_PATH/Makefile" ]]; then
		\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
			# make
			echo_cmd "make"
			if [[ $IS_DRY -eq $NO ]]; then
				\make  || exit 1
			fi
			# make install
			if [[ -d "$PROJECT_PATH/.libs/" ]]; then
				echo
				echo_cmd "make install"
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
		\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
			# generate temp release pom.xml
			if [[ $DO_CI -eq $YES             ]] \
			&& [[ -f "$PROJECT_PATH/pom.conf" ]]; then
				if [[ -z $PROJECT_VERSION ]]; then
					failure "Project version not detected"
					failure ; exit 1
				fi
				echo_cmd "mv  pom.xml  pom.xml.xbuild-save"
				if [[ $IS_DRY -eq $NO ]]; then
					\mv -v \
						"$PROJECT_PATH/pom.xml"             \
						"$PROJECT_PATH/pom.xml.xbuild-save" \
							|| exit 1
				fi
				SNAPSHOT_OR_RELEASE=""
				if [[ $ALLOW_RELEASE   -eq $YES ]] \
				&& [[ $PROJECT_RELEASE -eq $YES ]]; then
					SNAPSHOT_OR_RELEASE="--release"
				else
					SNAPSHOT_OR_RELEASE="--snapshot"
				fi
				echo_cmd -n "genpom $SNAPSHOT_OR_RELEASE $PROJECT_VERSION"
				if [[ $IS_DRY -eq $NO ]]; then
					\genpom  $SNAPSHOT_OR_RELEASE  $PROJECT_VERSION  || exit 1
				else
					echo
				fi
			fi
			FLAGS=""
			if [[ $DEBUG_FLAGS -eq $YES ]]; then
				FLAGS="--update-snapshots"
			fi
			if [[ $DO_CI -eq $YES ]]; then
				[[ -z $FLAGS ]] || FLAGS="$FLAGS "
				FLAGS="${FLAGS}--no-transfer-progress"
			fi
			[[ -z $FLAGS ]] || FLAGS=" $FLAGS "
			# build
			echo_cmd "mvn $FLAGS clean install"
			if [[ $IS_DRY -eq $NO ]]; then
				\mvn $FLAGS clean install  || exit 1
			fi
			# restore pom.xml
			if [[ $DO_CI -eq $YES             ]] \
			&& [[ -f "$PROJECT_PATH/pom.conf" ]]; then
				echo_cmd "rm  pom.xml"
				if [[ $IS_DRY -eq $NO ]]; then
					\rm -vf --preserve-root  "$PROJECT_PATH/pom.xml"  || exit 1
				fi
				echo_cmd "mv  pom.xml.xbuild-save  pom.xml"
				if [[ $IS_DRY -eq $NO ]]; then
					\mv -v  "$PROJECT_PATH/pom.xml.xbuild-save"  "$PROJECT_PATH/pom.xml"  || exit 1
				fi
			fi
		\popd >/dev/null
		echo
		did_something=$YES
	fi
	# gradle
	if [[ -f "$PROJECT_PATH/build.gradle" ]]; then
		\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
			# build
			echo_cmd "gradle build"
			if [[ $IS_DRY -eq $NO ]]; then
				\gradle  build  || exit 1
				echo
			fi
		\popd >/dev/null
		[[ $IS_DRY -eq $YES ]] && echo
		did_something=$YES
	fi
	# rust/cargo
	if [[ -f "$PROJECT_PATH/Cargo.toml" ]]; then
		\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
			if [[ $DO_CI -eq $YES ]]; then
				echo_cmd "cargo build --release --timings --locked"
				if [[ $IS_DRY -eq $NO ]]; then
					\cargo build --release --timings  --locked  || exit 1
				fi
			else
				if [[ $DEBUG_FLAGS -eq $YES ]]; then
					echo_cmd "cargo update"
					if [[ $IS_DRY -eq $NO ]]; then
						\cargo update  || exit 1
					fi
				fi
#TODO
#				echo_cmd "grcov . -s . --binary-path ./target/release/ "  \
#					"-t html --branch --ignore-not-existing -o ./coverage/"
#				if [[ $IS_DRY -eq $NO ]]; then
#					\grcov . -s .  \
#						--binary-path ./target/release/         \
#						-t html --branch --ignore-not-existing  \
#						-o ./coverage/
#				fi
				echo_cmd "cargo build"
				if [[ $IS_DRY -eq $NO ]]; then
					\cargo build  || exit 1
				fi
			fi
		\popd >/dev/null
		echo
		did_something=$YES
	fi
	# nothing to do
	if [[ $did_something -eq $YES ]]; then
		DisplayTime "Built"
		COUNT_ACT=$((COUNT_ACT+1))
	else
		notice "Nothing found to build.."
		echo
	fi
fi
