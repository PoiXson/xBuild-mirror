#!/usr/bin/bash
##==============================================================================
## Copyright (c) 2019-2022 PoiXson, Mattsoft
## <https://poixson.com> <https://mattsoft.net>
## Released under the GPL 3.0
##
## Description: Generates files for autotools
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
# genautotools.sh
VERSION="{{{VERSION}}}"



source /usr/bin/pxn/scripts/common.sh  || exit 1
echo



if [ -z $WDIR ]; then
	failure "Failed to find current working directory"
	failure ; exit 1
fi



# load autotools.conf
if [ ! -f "$WDIR/autotools.conf" ]; then
	failure "autotools.conf file not found here"
	failure ; exit 1
fi
source "$WDIR/autotools.conf"  || exit 1



# check values
if [ -z $PROJECT_NAME ]; then
	failure "Project Name not set in autotools.conf"
	failure ; exit 1
fi
if [ -z $PROJECT_VERSION ]; then
	failure "Project Version not set in autotools.conf"
	failure ; exit 1
fi
if [ -z $PROJECT_SUPPORT ]; then
	failure "Project Support not set in autotools.conf"
	failure ; exit 1
fi
if [ -z $PROJECT_URL ]; then
	failure "Project URL not set in autotools.conf"
	failure ; exit 1
fi
if [[ -z $IS_BIN ]] || [[ $IS_BIN -ne $YES ]]; then
	IS_BIN=$NO
fi
if [[ -z $IS_STATIC_LIB ]] || [[ $IS_STATIC_LIB -ne $YES ]]; then
	IS_STATIC_LIB=$NO
fi
if [[ -z $IS_DYNAMIC_LIB ]] || [[ $IS_DYNAMIC_LIB -ne $YES ]]; then
	IS_DYNAMIC_LIB=$NO
fi
if [[ -z $FPIC_FLAG ]] || [[ $FPIC_FLAG -ne $YES ]]; then
	FPIC_FLAG=$NO
fi



### generate configure.ac
#TODO: write to tmp file and compare
OUT_FILE="$WDIR/configure.ac"
echo -n > "$OUT_FILE"  || exit 1

# project info
LINE="AC_INIT(["
if [[ $IS_STATIC_LIB -eq $YES ]] || [[ $IS_DYNAMIC_LIB -eq $YES ]]; then
	LINE="${LINE}lib"
fi
LINE="${LINE}$PROJECT_NAME], [$PROJECT_VERSION], [$PROJECT_SUPPORT])"
echo "$LINE" >> "$OUT_FILE"  || exit 1

cat >> "$OUT_FILE" <<EOF
AC_PACKAGE_URL([$PROJECT_URL])

# clear default flags
: \${CFLAGS=""}

AC_PREREQ([2.69])
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_MAKE_SET
AC_LANG(C)

EOF
[[ $? -ne 0 ]] && exit 1

# AC_CONFIG_SRCDIR - assert files exist
if [[ ! -z $EXPECT_FILES ]]; then
	echo "# expected files" >> "$OUT_FILE"
	for FILE in $EXPECT_FILES; do
		echo "AC_CONFIG_SRCDIR([$FILE])" >> "$OUT_FILE"
	done
	echo >> "$OUT_FILE"
fi

# static library
if [[ $IS_STATIC_LIB -eq $YES ]]; then
	echo "AC_DISABLE_SHARED"                >> "$OUT_FILE"  || exit 1
	echo "AC_ENABLE_STATIC"                 >> "$OUT_FILE"  || exit 1
	echo "LT_INIT([static disable-shared])" >> "$OUT_FILE"  || exit 1
	echo                                    >> "$OUT_FILE"  || exit 1

# dynamic library
elif [[ $IS_DYNAMIC_LIB -eq $YES ]]; then
	echo "AC_ENABLE_SHARED"                 >> "$OUT_FILE"  || exit 1
	echo "AC_DISABLE_STATIC"                >> "$OUT_FILE"  || exit 1
	echo "LT_INIT([shared disable-static])" >> "$OUT_FILE"  || exit 1
	echo                                    >> "$OUT_FILE"  || exit 1
fi

PEDANTIC=""
if [[ $NO_PEDANTIC -ne $YES ]]; then
	PEDANTIC=" -pedantic-errors"
fi
cat >> "$OUT_FILE" <<EOF
AM_INIT_AUTOMAKE([subdir-objects foreign])
CFLAGS="-Wall -Werror${PEDANTIC}"
AC_ARG_ENABLE([debug],
	[AS_HELP_STRING([--enable-debug],
		[enable debug data generation (default=no)])],
	[enable_debug="\$enableval"],
	[enable_debug=no])
if test "x\$enable_debug" = xyes; then
	AC_MSG_RESULT([Debug Mode])
	AC_DEFINE([DEBUG],[],[Debug Mode])
	CFLAGS="\$CFLAGS -Og -ggdb3 -Wno-uninitialized"
else
	AC_MSG_RESULT([Production Mode])
    AC_DEFINE([NDEBUG],[],[No-debug Mode])
    CFLAGS="\$CFLAGS -O3 -D_FORTIFY_SOURCE"
fi
echo -ne "\nCFLAGS=\$CFLAGS\n\n"
AC_SUBST([CFLAGS])

AC_CONFIG_FILES([Makefile])

AC_OUTPUT
EOF
[[ $? -ne 0 ]] && exit 1

LINE_COUNT=$( \cat "$OUT_FILE" | \wc -l )
notice "Generated $OUT_FILE with [$LINE_COUNT] lines"



### generate Makefile.am
OUT_FILE="$WDIR/Makefile.am"
echo -n > "$OUT_FILE"  || exit 1

# project is bin or lib
if [[ $IS_BIN -eq $YES ]]; then
	echo "bin_PROGRAMS = "${PROJECT_NAME//_/-} >> "$OUT_FILE"  || exit 1
elif [[ $IS_STATIC_LIB -eq $YES ]] || [[ $IS_DYNAMIC_LIB -eq $YES ]]; then
	echo "lib_LTLIBRARIES = lib"${PROJECT_NAME//_/-}.la >> "$OUT_FILE"  || exit 1
fi

# dependency libraries
if [[ ! -z $DEPEND_LIBS ]]; then
	if [[ $IS_STATIC_LIB -eq $YES ]] || [[ $IS_DYNAMIC_LIB -eq $YES ]]; then
		LINE="lib${PROJECT_NAME/-/_}_la_LIBADD ="
	else
		LINE="${PROJECT_NAME/-/_}_LDADD ="
	fi
	for LIB in $DEPEND_LIBS; do
		LINE="$LINE -l${LIB}"
	done
	echo "$LINE" >> "$OUT_FILE"  || exit 1
fi

# projectdir=src
if [[ $IS_BIN -eq $YES ]]; then
	echo "${PROJECT_NAME}dir = src" >> "$OUT_FILE"  || exit 1
fi

# static library
if [[ $IS_STATIC_LIB -eq $YES ]]; then
	echo "lib${PROJECT_NAME/-/_}_la_LDFLAGS = -static" >> "$OUT_FILE"  || exit 1
# dynamic library
elif [[ $IS_DYNAMIC_LIB -eq $YES ]]; then
	echo "lib${PROJECT_NAME/-/_}_la_LDFLAGS = -module -shared" >> "$OUT_FILE"  || exit 1
fi
# enable -fPIC flag
if [[ $FPIC_FLAG -eq $YES ]]; then
	echo "lib${PROJECT_NAME/-/_}_la_CFLAGS = -fPIC" >> "$OUT_FILE"  || exit 1
fi
echo >> "$OUT_FILE"  || exit 1

# testing
if [[ -f "$WDIR/tests/tests.c" ]] && [[ ! -z $TEST_BINARY ]]; then
	echo "check_PROGRAMS = $TEST_BINARY"                >> "$OUT_FILE"  || exit 1
	echo "${TEST_BINARY/-/_}_LDADD = -l${PROJECT_NAME}" >> "$OUT_FILE"  || exit 1
	echo "${TEST_BINARY/-/_}_SOURCES = tests/tests.c"   >> "$OUT_FILE"  || exit 1
	if [[ $FPIC_FLAG -eq $YES ]]; then
		echo "test_lib${PROJECT_NAME/-/_}_la_CFLAGS = -fPIC" >> "$OUT_FILE"  || exit 1
	fi
	echo >> "$OUT_FILE"  || exit 1
fi

# .c source files
if [[ ! -z $PROJECT_C_FILES ]]; then
	if [[ $IS_STATIC_LIB -eq $YES ]] || [[ $IS_DYNAMIC_LIB -eq $YES ]]; then
		LINE="lib${PROJECT_NAME/-/_}_la"
	else
		LINE="${PROJECT_NAME/-/_}"
	fi
	LINE="${LINE}_SOURCES = \\"
	echo "$LINE" >> "$OUT_FILE"  || exit 1
	LONGEST_LEN=1
	LAST_LINE=""
	for LINE in $PROJECT_C_FILES; do
		LEN=${#LINE}
		if [[ $LEN -gt $LONGEST_LEN ]]; then
			LONGEST_LEN=$LEN
		fi
		LAST_LINE="$LINE"
	done
	for FILE in $PROJECT_C_FILES; do
		PAD_LEN=$((LONGEST_LEN - ${#FILE}))
		PAD=""
		if [[ "$FILE" != "$LAST_LINE" ]]; then
			if [[ $PAD_LEN -gt 0 ]]; then
				PAD=$( eval "printf ' '%.0s {1..$PAD_LEN}" )
			fi
			PAD="$PAD \\"
		fi
		echo "	${FILE}${PAD}" >> "$OUT_FILE"  || exit 1
	done
fi

# .h header files
if [[ ! -z $PROJECT_H_FILES ]]; then
	if [[ $IS_STATIC_LIB -eq $YES ]] || [[ $IS_DYNAMIC_LIB -eq $YES ]]; then
		echo "pkginclude_HEADERS = \\" >> "$OUT_FILE"  || exit 1
	else
		echo "${PROJECT_NAME}_HEADERS = \\" >> "$OUT_FILE"  || exit 1
	fi
	LONGEST_LEN=1
	LAST_LINE=""
	for LINE in $PROJECT_H_FILES; do
		LEN=${#LINE}
		if [[ $LEN -gt $LONGEST_LEN ]]; then
			LONGEST_LEN=$LEN
		fi
		LAST_LINE="$LINE"
	done
	for FILE in $PROJECT_H_FILES; do
		PAD_LEN=$((LONGEST_LEN - ${#FILE}))
		PAD=""
		if [[ "$FILE" != "$LAST_LINE" ]]; then
			if [[ $PAD_LEN -gt 0 ]]; then
				PAD=$( eval "printf ' '%.0s {1..$PAD_LEN}" )
			fi
			PAD="$PAD \\"
		fi
		echo "	${FILE}${PAD}" >> "$OUT_FILE"  || exit 1
	done
fi

LINE_COUNT=$( \cat "$OUT_FILE" | \wc -l )
notice "Generated $OUT_FILE"
notice "containing [$LINE_COUNT] lines"



echo
exit 0
