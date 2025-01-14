# 10-pull-push.sh


if [[ ! -z $PROJECT_REPO ]] \
|| [[ -d "$PROJECT_PATH/.git" ]]; then

	# pull/push
	if [[ -e "$PROJECT_PATH" ]]; then
		DO_PULL=$NO
		DO_PUSH=$NO

		# --pp
		if [[ " $ACTIONS " == *" pull-push "* ]]; then
			ACTIONS_FOUND="$ACTIONS_FOUND pull-push"
			[[ $QUIET -eq $NO ]] && \
				title C  "Pull/Push"  "$PROJECT_NAME"
			DO_PULL=$YES
			DO_PUSH=$YES
		# --pull
		elif [[ " $ACTIONS " == *" pull "* ]]; then
			ACTIONS_FOUND="$ACTIONS_FOUND pull"
			[[ $QUIET -eq $NO ]] && \
				title C  "Pull"  "$PROJECT_NAME"
			DO_PULL=$YES
		# --push
		elif [[ " $ACTIONS " == *" push "* ]]; then
			ACTIONS_FOUND="$ACTIONS_FOUND push"
			[[ $QUIET -eq $NO ]] && \
				title C  "Push"  "$PROJECT_NAME"
			DO_PUSH=$YES
		fi

		# git pull
		if [[ $DO_PULL -eq $YES ]]; then
			\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
				echo_cmd "git pull"
				if [[ $IS_DRY -eq $NO ]]; then
					\git pull  || exit 1
					echo
				fi
			\popd >/dev/null
			COUNT_ACT=$((COUNT_ACT+1))
		fi

		# git push
		if [[ $DO_PUSH -eq $YES ]]; then
			\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
				echo_cmd "git push"
				if [[ $IS_DRY -eq $NO ]]; then
					\git push  || exit 1
					echo
				fi
				echo_cmd "git push --tags"
				if [[ $IS_DRY -eq $NO ]]; then
					\git push   --tags  || exit 1
					echo
				fi
			\popd >/dev/null
			COUNT_ACT=$((COUNT_ACT+2))
		fi

	# clone repo
	else
		DO_CLONE=$NO

		# --pp
		if [[ " $ACTIONS " == *" pull-push "* ]]; then
			ACTIONS_FOUND="$ACTIONS_FOUND pull-push"
			DO_CLONE=$YES
		# --pull
		elif [[ " $ACTIONS " == *" pull "* ]]; then
			ACTIONS_FOUND="$ACTIONS_FOUND pull"
			DO_CLONE=$YES
		fi

		# git clone
		if [[ $DO_CLONE -eq $YES ]]; then
			[[ $QUIET -eq $NO ]] && \
				title C  "Clone"  "$PROJECT_NAME"
			\pushd  "$CURRENT_PATH/"  >/dev/null  || exit 1
				CLONE_PATH="${PROJECT_PATH##*/}"
				# git clone
				echo_cmd "git clone  $PROJECT_REPO  $CLONE_PATH"
				if [[ $IS_DRY -eq $NO ]]; then
					\git clone  "$PROJECT_REPO"  "$CLONE_PATH"  || exit 1
				fi
				echo
				COUNT_ACT=$((COUNT_ACT+1))
			\popd >/dev/null
		fi

	fi

fi
