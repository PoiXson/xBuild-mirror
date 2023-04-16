# 50-build.sh
# --build


if [[ " $ACTIONS " == *" build "* ]]; then
	did_something=$NO
	[[ $QUIET -eq $NO ]] && \
		title C "Build"
	doProjectTags
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
			if [[ $BUILD_RELEASE -eq $YES ]] \
			|| [[ $DO_AUTO       -eq $YES ]]; then
				echo_cmd "mv  pom.xml  pom.xml.xbuild-save"
				if [[ $IS_DRY -eq $NO ]]; then
					\mv -v  "$PROJECT_PATH/pom.xml"  "$PROJECT_PATH/pom.xml.xbuild-save"  || exit 1
				fi
				local SNAP_RELEASE=""
				if [[ $BUILD_RELEASE -eq $YES ]]; then
					SNAP_RELEASE="--release"
				else
					SNAP_RELEASE="--snapshot"
				fi
				echo_cmd -n "genpom $SNAP_RELEASE $PROJECT_VERSION"
				if [[ $IS_DRY -eq $NO ]]; then
					\genpom  $SNAP_RELEASE  $PROJECT_VERSION  || exit 1
				else
					echo
				fi
			fi
			# build
			echo_cmd "mvn clean install"
			if [[ $IS_DRY -eq $NO ]]; then
				\mvn  --no-transfer-progress  clean install  || exit 1
			fi
			# ide projects
			echo_cmd "mvn eclipse:eclipse"
			if [[ $IS_DRY -eq $NO ]]; then
				\mvn  --no-transfer-progress  eclipse:eclipse  || exit 1
			fi
			# restore pom.xml
			if [[ $BUILD_RELEASE -eq $YES ]] \
			|| [[ $DO_AUTO       -eq $YES ]]; then
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
	# rust/cargo
	if [[ -f "$PROJECT_PATH/Cargo.toml" ]]; then
		\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
			if [[ $BUILD_RELEASE -eq $YES ]]; then
				echo_cmd "cargo build --release --timings"
				if [[ $IS_DRY -eq $NO ]]; then
					\cargo build --release --timings  || exit 1
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
	ACTIONS_DONE="$ACTIONS_DONE build"
fi
