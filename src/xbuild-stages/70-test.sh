# 70-test.sh
# --test


if [[ " $ACTIONS " == *" test "* ]]; then
	ACTIONS_FOUND="$ACTIONS_FOUND test"
	did_something=$NO
	doProjectTags
	[[ $QUIET -eq $NO ]] && \
		title C "Testing"
	# make check
	if [[ -f "$PROJECT_PATH/Makefile" ]]; then
		\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
			echo_cmd "make check"
			if [[ $IS_DRY -eq $NO ]]; then
				\make check  || exit 1
			fi
		\popd >/dev/null
		echo
#TODO: exec test program
		did_something=$YES
	fi
	# phpunit
	if [[ -f "$PROJECT_PATH/phpunit.xml" ]]; then
		\pushd  "$PROJECT_PATH/"  >/dev/null  || exit 1
			echo_cmd "phpunit"
			if [[ $IS_DRY -eq $NO ]]; then
				"$PROJECT_PATH"/vendor/bin/phpunit --coverage-html coverage/html  || exit 1
			fi
		\popd >/dev/null
		echo
		did_something=$YES
	fi
	# nothing to do
	if [[ $did_something -eq $YES ]]; then
		DisplayTime "Tested"
		COUNT_ACT=$((COUNT_ACT+1))
	else
		notice "Nothing found to test.."
		echo
	fi
fi
