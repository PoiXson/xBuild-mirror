# 90-git-gui.sh
# --gg


if [[ " $ACTIONS " == *" git-gui "* ]]; then
	ACTIONS_FOUND="$ACTIONS_FOUND git-gui"
	if [[ -d "$PROJECT_PATH/.git" ]]; then
		\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
			echo_cmd -n "git-gui"
			if [[ $IS_DRY -eq $NO ]]; then
				/usr/libexec/git-core/git-gui &
				GG_PID=$!
				echo -e " ${COLOR_BLUE}${GG_PID}${COLOR_RESET}"
				\sleep 0.2
			else
				echo
			fi
			echo
			COUNT_ACT=$((COUNT_ACT+1))
		\popd >/dev/null
	fi
fi
