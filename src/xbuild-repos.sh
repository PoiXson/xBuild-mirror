#!/usr/bin/bash
## ================================================================================
##  xBuild-Repos
## Copyright (c) 2019-2025 Mattsoft/PoiXson
## <https://mattsoft.net> <https://poixson.com>
## Released under the AGPL 3.0 + ADD-PXN-V1
##
## Description: Automates updating yum/dnf and apt repositories
##
## Example:
## > curl --output configer-install.sh https://configer.online/install.sh
## > sh configer-install.sh --wizard
##
## ================================================================================
##
## This program is free software: you can redistribute it and/or modify it under
## the terms of the GNU Affero General Public License + ADD-PXN-V1 as published by
## the Free Software Foundation, either version 3 of the License, or (at your
## option) any later version, with the addition of ADD-PXN-V1.
##
## This program is distributed in the hope that it will be useful, but WITHOUT ANY
## WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
## PARTICULAR PURPOSE.
##
## See the GNU Affero General Public License for more details
## <http://www.gnu.org/licenses/agpl-3.0.en.html> and Addendum ADD-PXN-V1
## <https://dl.poixson.com/ADD-PXN-V1.txt>
##
## **ADD-PXN-V1 - Addendum to the GNU Affero General Public License (AGPL)**
## This Addendum is an integral part of the GNU Affero General Public License
## (AGPL) under which this software is licensed. By using, modifying, or
## distributing this software, you agree to the following additional terms:
##
## 1. **Source Code Availability:** Any distribution of the software, including
##    modified versions, must include the complete corresponding source code. This
##    includes all modifications made to the original source code.
## 2. **Free of Charge and Accessible:** The source code and any modifications to
##    the source code must be made available to all with reasonable access to the
##    internet, free of charge. No fees may be charged for access to the source
##    code or for the distribution of the software, whether in its original or
##    modified form. The source code must be accessible in a manner that allows
##    users to easily obtain, view, and modify it. This can be achieved by
##    providing a link to a publicly accessible repository (e.g., GitHub, GitLab)
##    or by including the source code directly with the distributed software.
## 3. **Documentation of Changes:** When distributing modified versions of the
##    software, you must provide clear documentation of the changes made to the
##    original source code. This documentation should be included with the source
##    code, and should be easily accessible to users.
## 4. **No Additional Restrictions:** You may not impose any additional
##    restrictions on the rights granted by the AGPL or this Addendum. All
##    recipients of the software must have the same rights to use, modify, and
##    distribute the software as granted under the AGPL and this Addendum.
## 5. **Acceptance of Terms:** By using, modifying, or distributing this software,
##    you acknowledge that you have read, understood, and agree to comply with the
##    terms of the AGPL and this Addendum.
## ================================================================================
# xbuild-repos.sh
XBUILD_REPOS_VERSION="{{{VERSION}}}"



echo
SELF="$0"
source  "/usr/bin/pxn/scripts/common.sh"  || exit 1



function DisplayHelp() {
	echo -e "${COLOR_BROWN}Usage:${COLOR_RESET}"
	echo    "  $SELF [options] [path]"
	echo
	echo -e "${COLOR_BROWN}Options:${COLOR_RESET}"
	echo -e "  ${COLOR_GREEN}-a, --all${COLOR_RESET}                 Use all .dev files found"
	echo -e "  ${COLOR_GREEN}-D, --dry${COLOR_RESET}                 Dry-run, no changes will be performed by actions"
	echo -e "  ${COLOR_GREEN}-c, --clean, --cleanup${COLOR_RESET}    Cleanup workspace; delete generated files"
	echo
	echo -e "  ${COLOR_GREEN}-v, --verbose${COLOR_RESET}             Enable debug logs"
	echo -e "  ${COLOR_GREEN}-V, --version${COLOR_RESET}             Display the version"
	echo -e "  ${COLOR_GREEN}-h, --help${COLOR_RESET}                Display this help message and exit"
	echo
	exit 1
}

function DisplayVersion() {
	echo -e "${COLOR_BROWN}xRepos${COLOR_RESET} ${COLOR_GREEN}$XBUILD_REPOS_VERSION${COLOR_RESET}"
	echo
}



# ----------------------------------------



GPG_PATH="$HOME/.gpg-package-signing"

FILTER_PATHS=""
DO_CLEAN=$NO
IS_DRY=$NO
VERBOSE=$NO

REPO_TYPE=""
ORG_NAME=""
KEY_EMAIL=""
KEY_ID=""

REPO_PATH=""
let COUNT_OPS=0



function REPO() {
	if [[ -z $REPO_TYPE ]]; then
		failure "Repo type not set in repos.conf"
		failure ; exit 1
	fi
	if [[ ! -z $REPO_PATH ]]; then
		if [[ " $FILTER_PATHS " == *" ALL "*        ]] \
		|| [[ " $FILTER_PATHS " == *" $REPO_PATH "* ]]; then
			COUNT_OPS=$((COUNT_OPS+1))
			title C "Building $REPO_TYPE Repo" "$REPO_PATH"
			echo
			if [[ ! -e "$WDIR/$REPO_PATH" ]]; then
				failure "Repo not found: $REPO_PATH"
				failure ; exit 1
			fi
			case "$REPO_TYPE" in
			# yum/dnf repo
			rpm) doREPO_RPM ;;
#TODO
#			# apt repo
#			deb) doREPO_DEB ;;
			*)
				failure "Unknown repo type: $REPO_TYPE"
				failure ; exit 1 ;;
			esac
			echo ; echo
			doCleanupVars
		fi
	fi
	# store next
	if [[ ! -z $1 ]]; then
		REPO_PATH="$1"
	fi
}

function doREPO_RPM() {
	[[ -z $REPO_PATH ]] && return
	\pushd "$WDIR/$REPO_PATH"  >/dev/null  || exit 1
		echo_cmd "createrepo . -v --pretty --workers 6"
		if [[ $IS_DRY -eq $NO ]]; then
			\createrepo . -v --pretty --workers 6  || exit 1
		fi
	\popd  >/dev/null
}

#TODO
#function doREPO_DEB() {
#	[[ -z $REPO_PATH ]] && return
#	prepare_gpg_keys
#	\pushd "$WDIR/$REPO_PATH"  >/dev/null  || exit 1
#		# Release file
#		if [[ ! -e Release ]]; then
#			echo_cmd "cat >Release"
#			if [[ $IS_DRY -eq $NO ]]; then
##TODO: set Suite and Codename
#				\cat >"Release" <<EOF
#Origin: $ORG_NAME
#Label: $REPO_PATH
#Suite: unstable
#Codename: unstable
#Architectures: all
#Components: main
#Description $ORG_NAME $REPO_PATH
#EOF
#			fi
#			echo_cmd "gpg --clearsign -o InRelease Release"
#			if [[ $IS_DRY -eq $NO ]]; then
#				\gpg --homedir "$GPG_PATH" \
#					--clearsign -o InRelease Release \
#						|| exit 1
#			fi
#		fi
#		# scan for .deb packages
#		echo_cmd "dpkg-scanpackages --type deb --multiversion" \
#			"| \gzip -9c > Packages.gz"
#		if [[ $IS_DRY -eq $NO ]]; then
#			\dpkg-scanpackages --type deb --multiversion . /dev/null \
#				| \gzip -9c > "Packages.gz" \
#					|| exit 1
#		fi
#		# sign packages
#		for ENTRY in $( /usr/bin/ls *.deb ); do
#			if [[ ! -e "${ENTRY}.sig" ]]; then
#				echo "Signing: $ENTRY"
#				echo_cmd "gpg --default-key $KEY_ID" \
#					"--armor --output ${ENTRY}.sig" \
#					"--detach-sig     ${ENTRY}"
#				if [[ $IS_DRY -eq $NO ]]; then
#					gpg --no-default-keyring \
#						--homedir "$GPG_PATH"           \
#						--default-key "$KEY_ID"         \
#						--armor --output "${ENTRY}.sig" \
#						--detach-sig     "${ENTRY}"     \
#							|| exit 1
#				fi
#			fi
#		done
#	\popd  >/dev/null
#}



function prepare_gpg_keys() {
	if [[ -z $GPG_PATH ]]; then
		failure "gpg path not set"
		failure ; exit 1
	fi
	# .gpg directory
	if [[ ! -e "$GPG_PATH" ]]; then
		if [[ ! -z $KEY_ID ]]; then
			failure "gpg key id set but path doesn't exist: $GPG_PATH"
			failure ; exit 1
		fi
		echo_cmd "mkdir $GPG_PATH"
		if [[ $IS_DRY -eq $NO ]]; then
			\mkdir -v  "$GPG_PATH"  || exit 1
		fi
		echo_cmd "chmod 0700 $GPG_PATH"
		if [[ $IS_DRY -eq $NO ]]; then
			\chmod -c  0700  "$GPG_PATH"  || exit 1
		fi
	fi
	notice "using: $GPG_PATH"
	# list keys
	echo_cmd "gpg --list-keys"
	\gpg --homedir "$GPG_PATH" --list-keys  || exit 1
	let count=0
	for ENTRY in $( \gpg --homedir "$GPG_PATH" --list-keys | \grep '^      ' ); do
		[[ -z $KEY_ID   ]] && KEY_ID="$ENTRY"
		[[ $count -eq 0 ]] && echo "Keys:"
		echo " $ENTRY"
		count=$((count+1))
	done
	if [[ -z $KEY_ID ]]; then
		# generate key
		if [[ $count -eq 0 ]]; then
			notice "Generating a gpg key.."
			local TMP_FILE=$( \mktemp )
			if [[   -z  $TMP_FILE  ]] \
			|| [[ ! -f "$TMP_FILE" ]]; then
				failure "Failed to create a temp file for gpg batch"
				failure ; exit 1
			fi
			echo_cmd "cat >$TMP_FILE"
			if [[ $IS_DRY -eq $NO ]]; then
				echo "%echo Generating a basic OpenPGP key" > "$TMP_FILE"
				if [[ -z $KEY_PASS ]]; then
					echo "%no-protection" >> "$TMP_FILE"
				fi
				\cat >>"$TMP_FILE" <<EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: "$ORG_NAME"
Name-Comment: "$ORG_NAME Software Repo"
Name-Email: "$KEY_EMAIL"
Expire-Date: 0
EOF
				if [[ ! -z $KEY_PASS ]]; then
					echo "Passphrase: \"$KEY_PASS\"" >> "$TMP_FILE"
				fi
				\cat >>"$TMP_FILE" <<EOF
%commit
%echo done
EOF
			fi
			echo_cmd "gpg --gen-key --batch batch"
			if [[ $IS_DRY -eq $NO ]]; then
				\gpg --no-default-keyring \
					--homedir "$GPG_PATH"         \
					--gen-key --batch "$TMP_FILE" \
						|| exit 1
				let count=0
				for ENTRY in $( \gpg --homedir "$GPG_PATH" --list-keys | \grep '^      ' ); do
					[[ -z $KEY_ID   ]] && KEY_ID="$ENTRY"
					[[ $count -eq 0 ]] && echo "Keys:"
					echo " $ENTRY"
					count=$((count+1))
				done
				if [[ $count -eq 0 ]]; then
					failure "Failed to generate a gpg key"
					failure ; exit 1
				elif [[ $count -gt 1 ]]; then
					failure "More than one key found after generating?"
					failure ; exit 1
				fi
			fi
			echo_cmd "rm -fv $TMP_FILE"
			if [[ $IS_DRY -eq $NO ]]; then
				\rm --preserve-root -fv "$TMP_FILE"
			fi
		# more than one key found
		elif [[ $count -gt 1 ]]; then
			failure "More than one gpg key found, please set KEY_ID in repos.conf"
			failure ; exit 1
		fi
	fi
	if [[ -z $KEY_ID ]]; then
		failure "Failed to generate and detect a gpg key"
		failure ; exit 1
	fi
	# export public key
	if [[ ! -e "$WDIR/$REPO_PATH/pubkey.gpg" ]]; then
		notice "Export public key.."
		echo_cmd "gpg --armor --output pubkey.gpg --export $KEY_ID"
		if [[ $IS_DRY -eq $NO ]]; then
			\gpg --no-default-keyring \
				--homedir "$GPG_PATH"                          \
				--armor --output "$WDIR/$REPO_PATH/pubkey.gpg" \
				--export "$KEY_ID"                             \
					|| exit 1
		fi
	fi
}



function doCleanupVars() {
	REPO_PATH=""
}



# parse args
if [[ $# -eq 0 ]]; then
	DisplayHelp
	exit 1
fi
while [ $# -gt 0 ]; do
	case "$1" in
	-a|--all)              FILTER_PATHS="ALL $FILTER_PATHS" ;; # all repos
	-c|--clean|--cleanup)  DO_CLEAN=$YES                    ;; # cleanup
	-D|--dry)              IS_DRY=$YES                      ;; # dry mode
	-v|--verbose)          VERBOSE=$YES                     ;; # verbose logging
	-V|--version)          DisplayVersion ; exit 1          ;; # display version
	-h|--help)             DisplayHelp    ; exit 1          ;; # display help
	-*)
		failure "Unknown argument: $1"
		failure ; DisplayHelp ; exit 1 ;;
	*)
		if [[ -e "$WDIR/$1" ]]; then
			FILTER_PATHS="$FILTER_PATHS $1"
		else
			failure "Unknown repo path: $1"
			failure ; exit 1
		fi
	;;
	esac
	\shift
done



did_notice=$NO
if [[ $IS_DRY -eq $YES ]]; then
	notice "Dry-run"
	did_notice=$YES
fi
[[ $did_notice -eq $YES ]] && echo



if [[ ! -e "$WDIR/repos.conf" ]]; then
	failure "repos.conf file not found here"
	failure ; exit 1
fi

# load repos.conf
doCleanupVars
source  "$WDIR/repos.conf"  || exit 1
# do last
REPO



echo -e "${COLOR_GREEN}===============================================${COLOR_RESET}"
echo

if [[ $COUNT_OPS -le 0 ]]; then
	warning "No actions performed"
	echo
	DisplayHelp
	exit 1
fi

echo -ne "${COLOR_GREEN}Performed $COUNT_OPS operation"
[[ $COUNT_OPS -gt 1 ]] && echo -n "s"
[[ $COUNT_PRJ -gt 1 ]] && echo -ne " on $COUNT_PRJ projects"
echo -e "${COLOR_RESET}"

echo
exit 0
