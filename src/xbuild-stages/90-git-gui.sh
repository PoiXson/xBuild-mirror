# 90-git-gui.sh
# --gg


if [[ " $ACTIONS " == *" git-gui "* ]]; then
	ACTIONS_FOUND="$ACTIONS_FOUND git-gui"
	if [[ -d "$PROJECT_PATH/.git" ]]; then
		\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
			if [[ $IS_DRY -eq $NO ]]; then
				GIT_CONFIG_FILE="$PROJECT_PATH/.git/config"
				if [[ -f "$GIT_CONFIG_FILE" ]]; then
#TODO: move this to a config file
GIT_GUI_GEOMETRY="1920x2061+1920+0 231 223"
					if \grep -q  "^\s*geometry\s*=\s*$GIT_GUI_GEOMETRY$"  "$GIT_CONFIG_FILE"; then
						:
					# modify existing line
					elif \grep -q  "^\s*geometry\s*="  "$GIT_CONFIG_FILE"; then
						echo " [modifying existing geometry line..]"
						echo_cmd "sed -i |geometry=*|geometry=$GIT_GUI_GEOMETRY|  $GIT_CONFIG_FILE"
						\sed -i  "s|^\s*geometry\s*=.*|\tgeometry = $GIT_GUI_GEOMETRY|"  "$GIT_CONFIG_FILE"  || exit 1
					# add new line
					elif \grep -q  "^\[gui\]$"  "$GIT_CONFIG_FILE"; then
						echo " [adding geometry line..]"
						echo_cmd "sed -i /[gui]/ geometry=$GIT_GUI_GEOMETRY  $GIT_CONFIG_FILE"
						\sed -i  "/^\[gui\]/a \\\tgeometry = $GIT_GUI_GEOMETRY"  "$GIT_CONFIG_FILE"  || exit 1
					# add new gui section
					else
						echo " [adding gui section and geometry line..]"
						echo_cmd "echo \"[gui] geometry=$GIT_GUI_GEOMETRY\" >>$GIT_CONFIG_FILE"
						echo -ne  "\n[gui]\n\tgeometry = $GIT_GUI_GEOMETRY"  >>"$GIT_CONFIG_FILE"  || exit 1
					fi
				fi
			fi
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
