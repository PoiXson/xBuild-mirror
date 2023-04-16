# 10-pull-push.sh
# --pp


if [[ " $ACTIONS " == *" pull-push "* ]]; then
	if [[ ! -z $PROJECT_REPO ]] \
	|| [[ -d "$PROJECT_PATH/.git" ]]; then
		# clone repo
		if [[ ! -e "$PROJECT_PATH" ]]; then
			[[ $QUIET -eq $NO ]] && \
				title C "Clone"
			\pushd  "$CURRENT_PATH/"  >/dev/null  || exit 1
				local CLONE_PATH="${PROJECT_PATH##*/}"
				# git clone
				echo_cmd "git clone  $PROJECT_REPO  $CLONE_PATH"
				if [[ $IS_DRY -eq $NO ]]; then
					\git clone  "$PROJECT_REPO"  "$CLONE_PATH"  || exit 1
				fi
				echo
			\popd >/dev/null
			COUNT_ACT=$((COUNT_ACT+1))
			return
		fi
		[[ $QUIET -eq $NO ]] && \
			title C "Pull/Push"
		\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
			# git pull
			echo_cmd "git pull"
			if [[ $IS_DRY -eq $NO ]]; then
				\git pull  || exit 1
				echo
			fi
			# git push
			echo_cmd "git push"
			if [[ $IS_DRY -eq $NO ]]; then
				\git push  || exit 1
				echo
			fi
		\popd >/dev/null
		COUNT_ACT=$((COUNT_ACT+1))
		ACTIONS_DONE="$ACTIONS_DONE pull-push"
	fi
fi
