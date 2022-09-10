#!/usr/bin/bash
##==============================================================================
## Copyright (c) 2019-2022 Mattsoft/PoiXson
## <https://mattsoft.net> <https://poixson.com>
## Released under the AGPL 3.0
##
## Description: Generates project.spec files to build rpm packages
##
## Example:
## > curl --output configer-install.sh https://configer.io/install.sh
## > sh configer-install.sh --wizard
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU Affero General Public License as
## published by the Free Software Foundation, either version 3 of the
## License, or (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU Affero General Public License for more details.
##
## You should have received a copy of the GNU Affero General Public License
## along with this program.  If not, see <https://www.gnu.org/licenses/>.
##==============================================================================
# genspec.sh
XBUILD_VERSION="{{{VERSION}}}"



source /usr/bin/pxn/scripts/common.sh  || exit 1
echo



if [ -z $WDIR ]; then
	failure "Failed to find current working directory"
	failure ; exit 1
fi



# defaults
ARCH="noarch"
LICENSE="GPLv3"
URL="https://poixson.com"
PREFIX="%{_bindir}"
OWNER="root"
DEF_ATTR_FILE="0400"
DEF_ATTR_DIR="0500"



OUT_POSTHEAD=""

function AddRequires() {
	OUT_POSTHEAD="${OUT_POSTHEAD}Requires: $1
"
}
function AddBuildRequires() {
	OUT_POSTHEAD="${OUT_POSTHEAD}BuildRequires: $1
"
}
function AddConflicts() {
	OUT_POSTHEAD="${OUT_POSTHEAD}Conflicts: $1
"
}
function AddProvides() {
	OUT_POSTHEAD="${OUT_POSTHEAD}Provides: $1
"
}
function AddObsoletes() {
	OUT_POSTHEAD="${OUT_POSTHEAD}Obsoletes: $1
"
}



# load spec.conf
if [[ ! -f "$WDIR/spec.conf" ]]; then
	failure "spec.conf file not found here"
	failure ; exit 1
fi
source "$WDIR/spec.conf"  || exit 1



# check values
if [[ -z $NAME ]]; then
	failure "Name not set"
	failure ; exit 1
fi
if [[ -z $VERSION ]]; then
	failure "Version not set"
	failure ; exit 1
fi

if [[ -z $SUMMARY ]]; then
	failure "Summary not set"
	failure ; exit 1
fi
if [[ -z $DESCRIPTION ]]; then
	DESCRIPTION="$SUMMARY"
fi



# temp file
OUT_FILE=$( mktemp )
RESULT=$?
if [[ $RESULT -ne 0 ]] || [[ -z $OUT_FILE ]]; then
	failure "Failed to create a temp file"
	failure ; exit $RESULT
fi

# generate .spec file
echo -n >"$OUT_FILE"
TIMESTAMP=$( date )
\cat >>"$OUT_FILE" <<EOF
# Generated: $TIMESTAMP
Name    : $NAME
Version : $VERSION
EOF
if [[ $ARCH == "noarch" ]]; then
	echo "Release : 1"         >>"$OUT_FILE"
else
	echo "Release : 1%{dist}"  >>"$OUT_FILE"
fi
\cat >>"$OUT_FILE" <<EOF
Summary : $SUMMARY

EOF

if [[ ! -z $OUT_POSTHEAD ]]; then
	echo "$OUT_POSTHEAD" >>"$OUT_FILE"
fi

\cat >>"$OUT_FILE" <<EOF
BuildArch : $ARCH
Packager  : PoiXson <support@poixson.com>
License   : $LICENSE
URL       : $URL

Prefix: $PREFIX
%define _rpmfilename  %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm

%description
$DESCRIPTION



### Install ###
%install
echo
echo "Install.."

# delete existing rpm's
%{__rm} -fv --preserve-root  "%{_rpmdir}/%{name}-"*.rpm

EOF

GEN_INSTALL

echo -ne "\n\n\n" >>"$OUT_FILE"
\cat >>"$OUT_FILE" <<EOF
### Files ###
%files
%defattr($DEF_ATTR_FILE, $OWNER, $OWNER, $DEF_ATTR_DIR)
EOF

GEN_FILES



# diff
HASH_NEW=$( \grep -v "# Generated: " "$OUT_FILE"            | \md5sum )
HASH_OLD=$( \grep -v "# Generated: " "${WDIR}/${NAME}.spec" | \md5sum )
HASH_NEW="${HASH_NEW%%\ *}"
HASH_OLD="${HASH_OLD%%\ *}"
if [[ -z $HASH_NEW ]] || [[ -z $HASH_OLD ]]; then
	failure "Failed to diff temp file with existing file"
	failure ; exit $RESULT
fi



LINE_COUNT=$( \cat "$OUT_FILE" | \wc -l )
if [[ "$HASH_NEW" == "$HASH_OLD" ]]; then
	notice "Existing file is up to date"
else
	\cp -fv  "$OUT_FILE"  "$WDIR/${NAME}.spec"  || exit 1
	notice "Generated ${NAME}.spec file"
fi
notice "containing [$LINE_COUNT] lines"
\rm  --preserve-root -f  "$OUT_FILE"



echo
exit 0
