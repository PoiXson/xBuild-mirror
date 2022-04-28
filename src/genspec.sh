#!/usr/bin/bash
##==============================================================================
## Copyright (c) 2019-2022 PoiXson, Mattsoft
## <https://poixson.com> <https://mattsoft.net>
## Released under the GPL 3.0
##
## Description: Generates project.spec files to build rpm packages
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.
##==============================================================================
# genspec.sh

source /usr/bin/pxn/scripts/common.sh  || exit 1
echo



if [ -z $WDIR ]; then
	failure "Failed to find current working directory"
	echo >&2 ; exit 1
fi



# defaults
ARCH="noarch"
URL="https://poixson.com"
PREFIX="%{_bindir}"
OWNER="root"
DEF_ATTR_FILE="0400"
DEF_ATTR_DIR="0500"



OUT_REQUIRES=""

function AddRequires() {
	OUT_REQUIRES="${OUT_REQUIRES}Requires: $1"
}
function AddBuildRequires() {
	OUT_REQUIRES="${OUT_REQUIRES}BuildRequires: $1"
}
function AddConflicts() {
	OUT_REQUIRES="${OUT_REQUIRES}Conflicts: $1"
}



# load spec.conf
if [[ ! -f "$WDIR/spec.conf" ]]; then
	failure "spec.conf file not found here"
	echo >&2 ; exit 1
fi
source "$WDIR/spec.conf"  || exit 1



# check values
if [[ -z $NAME ]]; then
	failure "Name not set"
	echo >&2 ; exit 1
fi
if [[ -z $VERSION ]]; then
	failure "Version not set"
	echo >&2 ; exit 1
fi

if [[ -z $SUMMARY ]]; then
	failure "Summary not set"
	echo >&2 ; exit 1
fi
if [[ -z $DESCRIPTION ]]; then
	DESCRIPTION="$SUMMARY"
fi



# temp file
OUT_FILE=$( mktemp )
RESULT=$?
if [[ $RESULT -ne 0 ]] || [[ -z $OUT_FILE ]]; then
	failure "Failed to create a temp file"
	echo >&2 ; exit $RESULT
fi

# generate .spec file
echo -n >"$OUT_FILE"
TIMESTAMP=$( date )
\cat >>"$OUT_FILE" <<EOF
# Generated: $TIMESTAMP
Name    : $NAME
Version : $VERSION
Release : 1
Summary : $SUMMARY

EOF

if [[ ! -z $OUT_REQUIRES ]]; then
	echo "$OUT_REQUIRES" >>"$OUT_FILE"
fi

\cat >>"$OUT_FILE" <<EOF
BuildArch : $ARCH
Packager  : PoiXson <support@poixson.com>
License   : GPLv3
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
HASH_NEW=$( \grep -v "# Generated: " "$OUT_FILE"          | \md5sum )
HASH_OLD=$( \grep -v "# Generated: " "$WDIR/${NAME}.spec" | \md5sum )
HASH_NEW="${HASH_NEW%%\ *}"
HASH_OLD="${HASH_OLD%%\ *}"
if [[ -z $HASH_NEW ]] || [[ -z $HASH_OLD ]]; then
	failure "Failed to diff temp file with existing file"
	echo >&2 ; exit $RESULT
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
