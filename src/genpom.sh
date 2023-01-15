#!/usr/bin/bash
##==============================================================================
## Copyright (c) 2019-2023 Mattsoft/PoiXson
## <https://mattsoft.net> <https://poixson.com>
## Released under the AGPL 3.0
##
## Description: Generates pom.xml files for maven
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
# genpom.sh
GENPOM_VERSION="{{{VERSION}}}"



source /usr/bin/pxn/scripts/common.sh  || exit 1



if [ -z $WDIR ]; then
	echo
	failure "Failed to find current working directory"
	failure ; exit 1
fi



MAVEN_VERSIONS_FILE="maven-versions.conf"
SHADE=$NO
SNAPSHOT="-SNAPSHOT"

OUT_VERSION=""
OUT_PROPS=""
OUT_PROPS_DEPS=""
OUT_PROPS_PLUGINS=""
OUT_PLUGINS=""
OUT_DEPS=""
OUT_REPOS=""
OUT_RES=""



function DisplayHelp() {
	echo -e "${COLOR_BROWN}Usage:${COLOR_RESET}"
	echo    "  genpom [options] <group>"
	echo
	echo -e "${COLOR_BROWN}Options:${COLOR_RESET}"
	echo -e "  ${COLOR_GREEN}-R, --release [version]${COLOR_RESET}   Build a production release"
	echo
	echo -e "  ${COLOR_GREEN}-V, --version${COLOR_RESET}             Display the version"
	echo -e "  ${COLOR_GREEN}-h, --help${COLOR_RESET}                Display this help message and exit"
	echo
	exit 1
}

function DisplayVersion() {
	echo -e "${COLOR_BROWN}GenPom${COLOR_RESET} ${COLOR_GREEN}${GENPOM_VERSION}${COLOR_RESET}"
	echo
}



# parse args
echo
while [ $# -gt 0 ]; do
	case "$1" in
	-R|--release)
		SNAPSHOT=""
		if [[ ! -z $2 ]] && [[ "$2" != "-"* ]]; then
			\shift
			OUT_VERSION="$1"
		fi
	;;
	--release=*)   OUT_VERSION=${1#*=}  ;;
	-V|--version)  DisplayVersion ; exit 1  ;;
	-h|--help)     DisplayHelp    ; exit 1  ;;
	*)
		failure "Unknown argument: $1"
		failure
		DisplayHelp
		exit 1
	;;
	esac
	\shift
done



function AddProp() {
	OUT_PROPS="$OUT_PROPS\t\t<$1>$2</$1>\n"
}
function AddPropDep() {
	OUT_PROPS_DEPS="$OUT_PROPS_DEPS\t\t<$1>$2</$1>\n"
}
function AddPropPlugin() {
	OUT_PROPS_PLUGINS="$OUT_PROPS_PLUGINS\t\t<$1>$2</$1>\n"
}



function AddDep() {
	local GROUP="$1"
	local ARTIFACT="$2"
	shift ; shift
	local SCOPE=""
	local VERSION=""
	while [ $# -gt 0 ]; do
		case "$1" in
		"scope="*)
			SCOPE="${1#*scope=}"
		;;
		"version="*)
			VERSION="${1#*scope=}"
		;;
		*)
			failure "Unknown dependency argument: $1"
			failure ; exit 1
		;;
		esac
		shift
	done
	if [[ -z $GROUP ]]; then
		failure "Dependency group not set"
		failure ; exit 1
	fi
	if [[ -z $ARTIFACT ]]; then
		failure "Dependency artifact not set"
		failure ; exit 1
	fi
	if [[ -z $VERSION ]]; then
		FindDepVersion  "$GROUP"  "$ARTIFACT"
		VERSION="$FOUND_DEP_VERSION"
	fi
	if [[ -z $VERSION ]]; then
		failure "Unknown version for: $GROUP $ARTIFACT"
		failure ; exit 1
	fi
	AddPropDep  "$ARTIFACT-version"  "$VERSION"
	if [[ -z $SCOPE ]]; then
		if [[ $SHADE -ne $YES ]]; then
			SCOPE="provided"
		fi
	fi
	OUT_DEPS="$OUT_DEPS\t\t<dependency>\n"
	OUT_DEPS="$OUT_DEPS\t\t\t<artifactId>$ARTIFACT</artifactId>\n"
	OUT_DEPS="$OUT_DEPS\t\t\t<groupId>$GROUP</groupId>\n"
	OUT_DEPS="$OUT_DEPS\t\t\t<version>\${$ARTIFACT-version}</version>\n"
	[[ -z $SCOPE ]] || \
	OUT_DEPS="$OUT_DEPS\t\t\t<scope>$SCOPE</scope>\n"
	OUT_DEPS="$OUT_DEPS\t\t</dependency>\n"
}

function AddRepo() {
	local NAME="$1"
	local URL="$2"
	if [[ -z $NAME ]]; then
		failure "Repo Name argument is required"
		failure ; exit 1
	fi
	if [[ -z $URL ]]; then
		failure "Repo URL argument is required"
		failure ; exit 1
	fi
	OUT_REPOS="$OUT_REPOS\t\t<repository>\n"
	OUT_REPOS="$OUT_REPOS\t\t\t<id>$NAME</id>\n"
	OUT_REPOS="$OUT_REPOS\t\t\t<url>$URL</url>\n"
	OUT_REPOS="$OUT_REPOS\t\t\t<snapshots>\n"
	OUT_REPOS="$OUT_REPOS\t\t\t\t<enabled>true</enabled>\n"
	OUT_REPOS="$OUT_REPOS\t\t\t</snapshots>\n"
	OUT_REPOS="$OUT_REPOS\t\t</repository>\n"
}

function AddRes() {
	if [[ -z $1 ]]; then
		failure "AddRes requires a file argument to include"
		failure ; exit 1
	fi
	OUT_RES="$OUT_RES\t\t\t\t\t<include>$1</include>\n"
}



FIND_DEP_BY_ARTIFACT=""
FIND_DEP_BY_GROUP=""
FOUND_DEP_VERSION=""
function FindDepVersion() {
	FIND_DEP_BY_GROUP="$1"
	FIND_DEP_BY_ARTIFACT="$2"
	FOUND_DEP_VERSION=""
	local DID_SOMETHING=$NO
	# current working dir
	if [[ -e "$WDIR/$MAVEN_VERSIONS_FILE" ]]; then
		source "$WDIR/$MAVEN_VERSIONS_FILE"  || exit 1
		DID_SOMETHING=$YES
	fi
#TODO: automate with for loop
	# up one
	if [[ -e "$WDIR/../$MAVEN_VERSIONS_FILE" ]]; then
		source "$WDIR/../$MAVEN_VERSIONS_FILE"  || exit 1
		DID_SOMETHING=$YES
	fi
	# up two
	if [[ -e "$WDIR/../../$MAVEN_VERSIONS_FILE" ]]; then
		source "$WDIR/../../$MAVEN_VERSIONS_FILE"  || exit 1
		DID_SOMETHING=$YES
	fi
	# home dir
	if [[ -e "~/$MAVEN_VERSIONS_FILE" ]]; then
		source "~/$MAVEN_VERSIONS_FILE"  || exit 1
		DID_SOMETHING=$YES
	fi
	# /etc
	if [[ -e "/etc/$MAVEN_VERSIONS_FILE" ]]; then
		source "/etc/$MAVEN_VERSIONS_FILE"  || exit 1
		DID_SOMETHING=$YES
	fi
	if [[ $DID_SOMETHING -ne $YES ]]; then
		failure "File not found: $MAVEN_VERSIONS_FILE"
		failure ; exit 1
	fi
	if [[ -z $FOUND_DEP_VERSION ]]; then
		failure "Dependency version unknown: $FIND_DEP_BY_GROUP $FIND_DEP_BY_ARTIFACT"
		failure ; exit 1
	fi
}
function ADD_VERSION() {
	# already found
	[[ -z $FOUND_DEP_VERSION ]] || return
	# required arguments
	[[ -z $FIND_DEP_BY_ARTIFACT ]] && return;
	[[ -z $FIND_DEP_BY_GROUP    ]] && return;
	# found match
	if [[ "$1" == "$FIND_DEP_BY_GROUP" ]]; then
		if [[ "$2" == "$FIND_DEP_BY_ARTIFACT" ]]; then
			FOUND_DEP_VERSION="$3"
		fi
	fi
}



# load pom.conf
if [[ ! -f "$WDIR/pom.conf" ]]; then
	failure "pom.conf file not found here"
	failure ; exit 1
fi
source "$WDIR/pom.conf"  || exit 1



# override version with conf
if [[ ! -z $VERSION ]]; then
	if [[ -z $OUT_VERSION ]]; then
		notice "Using version from conf"
	else
		failure "Overriding version with conf"
	fi
	OUT_VERSION="$VERSION"
fi



# check values
if [[ -z $NAME ]]; then
	failure "Name not set"
	failure ; exit 1
fi
if [[ -z $ARTIFACT ]]; then
	failure "Artifact not set"
	failure ; exit 1
fi
if [[ -z $GROUP ]]; then
	failure "Group not set"
	failure ; exit 1
fi
if [[ -z $OUT_VERSION ]]; then
	failure "Version not set"
	failure ; exit 1
fi



# resources
if [[ -e "$WDIR/resources/" ]] \
|| [[ -e "$WDIR/testresources/" ]]; then
	FindDepVersion  "org.apache.maven.plugins"  "maven-resources-plugin"
	AddPropPlugin  "maven-resources-plugin-version"  "$FOUND_DEP_VERSION"
fi

# java compiler plugin
FindDepVersion  "org.apache.maven.plugins"  "maven-compiler-plugin"
AddPropPlugin  "maven-compiler-plugin-version"  "$FOUND_DEP_VERSION"

# jar plugin
FindDepVersion  "org.apache.maven.plugins"  "maven-jar-plugin"
AddPropPlugin  "maven-jar-plugin-version"  "$FOUND_DEP_VERSION"

# source plugin
FindDepVersion  "org.apache.maven.plugins"  "maven-source-plugin"
AddPropPlugin  "maven-source-plugin-version"  "$FOUND_DEP_VERSION"

# eclipse plugin
FindDepVersion  "org.apache.maven.plugins"  "maven-eclipse-plugin"
AddPropPlugin  "maven-eclipse-plugin-version"  "$FOUND_DEP_VERSION"

# git commit id plugin
FindDepVersion  "pl.project13.maven"  "git-commit-id-plugin"
AddPropPlugin  "git-commit-id-version"  "$FOUND_DEP_VERSION"

# shade jar
if [[ $SHADE -eq $YES ]]; then
	FindDepVersion  "org.apache.maven.plugins"  "maven-shade-plugin"
	AddPropPlugin  "maven-shade-plugin-version"  "$FOUND_DEP_VERSION"
fi

if [[ -e "$WDIR/tests/" ]]; then

	# junit
	FindDepVersion  "junit"  "junit"
	AddPropPlugin  "junit-version"  "$FOUND_DEP_VERSION"

	# surefire
	FindDepVersion  "org.apache.maven.plugins"  "maven-surefire-plugin"
	AddPropPlugin  "surefire-version"  "$FOUND_DEP_VERSION"

	# cobertura
	FindDepVersion  "org.codehaus.mojo"  "cobertura-maven-plugin"
	AddPropPlugin  "cobertura-version"  "$FOUND_DEP_VERSION"

	# jxr - cross reference
	FindDepVersion  "org.apache.maven.jxr"  "jxr"
	AddPropPlugin  "jxr-version"  "$FOUND_DEP_VERSION"

	# reports
	FindDepVersion  "org.apache.maven.plugins"  "maven-project-info-reports-plugin"
	AddPropPlugin  "project-info-reports-version"  "$FOUND_DEP_VERSION"

fi



# temp file
OUT_FILE=$( mktemp )
RESULT=$?
if [[ $RESULT -ne 0 ]] || [[ -z $OUT_FILE ]]; then
	failure "Failed to create a temp file"
	failure ; exit $RESULT
fi

# generate pom.xml
echo -n >"$OUT_FILE"
TIMESTAMP=$( date )
\cat >>"$OUT_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!-- Generated: $TIMESTAMP -->
<project xmlns="http://maven.apache.org/POM/4.0.0"
		xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
		xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
	<modelVersion>4.0.0</modelVersion>
	<name>$NAME</name>
	<artifactId>$ARTIFACT</artifactId>
	<groupId>$GROUP</groupId>
	<version>$OUT_VERSION$SNAPSHOT</version>
	<packaging>jar</packaging>
EOF
[[ -z $URL  ]] || echo -e "\t<url>$URL</url>"                  >>"$OUT_FILE"
[[ -z $DESC ]] || echo -e "\t<description>$DESC</description>" >>"$OUT_FILE"
if [[ ! -z $ORG_NAME ]] || [[ ! -z $ORG_URL ]]; then
	echo -e "\t<organization>"                                 >>"$OUT_FILE"
	[[ -z $ORG_NAME ]] || echo -e "\t\t<name>$ORG_NAME</name>" >>"$OUT_FILE"
	[[ -z $ORG_URL  ]] || echo -e "\t\t<url>$ORG_URL</url>"    >>"$OUT_FILE"
	echo -e "\t</organization>"                                >>"$OUT_FILE"
fi

# properties
\cat >>"$OUT_FILE" <<EOF
	<properties>
		<project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
		<maven.compiler.source>1.8</maven.compiler.source>
		<maven.compiler.target>1.8</maven.compiler.target>

EOF
if [[ ! -z $OUT_PROPS ]]; then
	echo -e "$OUT_PROPS" >>"$OUT_FILE"
fi
if [[ ! -z $OUT_PROPS_PLUGINS ]]; then
	echo -e "\t\t<!-- Maven Plugins -->" >>"$OUT_FILE"
	echo -e "$OUT_PROPS_PLUGINS"   >>"$OUT_FILE"
fi
if [[ ! -z $OUT_PROPS_DEPS ]]; then
	echo -e "\t\t<!-- Dependencies -->" >>"$OUT_FILE"
	echo -e "$OUT_PROPS_DEPS"           >>"$OUT_FILE"
fi
echo -e "\t</properties>" >>"$OUT_FILE"

# scm
if [[ ! -z $REPO_URL ]] || [[ ! -z $REPO_PUB ]] || [[ ! -z $REPO_DEV ]]; then
	echo -e "\t<scm>" >>"$OUT_FILE"
	[[ -z $REPO_URL ]] || echo -e "\t\t<url>$REPO_URL</url>"                                 >>"$OUT_FILE"
	[[ -z $REPO_PUB ]] || echo -e "\t\t<connection>$REPO_PUB</connection>"                   >>"$OUT_FILE"
	[[ -z $REPO_DEV ]] || echo -e "\t\t<developerConnection>$REPO_DEV</developerConnection>" >>"$OUT_FILE"
	echo -e "\t</scm>" >>"$OUT_FILE"
fi

# issue tracking
if [[ ! -z $BUG_TRACK_NAME ]] && [[ ! -z $BUG_TRACK_URL ]]; then
\cat >>"$OUT_FILE" <<EOF
	<issueManagement>
		<system>$BUG_TRACK_NAME</system>
		<url>$BUG_TRACK_URL</url>
	</issueManagement>
EOF
fi

# ci
if [[ ! -z $CI_NAME ]] && [[ ! -z $CI_URL ]]; then
\cat >>"$OUT_FILE" <<EOF
	<ciManagement>
		<system>$CI_NAME</system>
		<url>$CI_URL</url>
	</ciManagement>
EOF
fi

# build
\cat >>"$OUT_FILE" <<EOF
	<build>
		<directory>target/</directory>
		<sourceDirectory>src/</sourceDirectory>
		<outputDirectory>target/classes/</outputDirectory>
		<finalName>\${project.name}-\${project.version}</finalName>
EOF

if [[ -e "$WDIR/tests/" ]]; then
	echo -e "\t\t<testSourceDirectory>tests/</testSourceDirectory>" >>"$OUT_FILE"
fi

# resources
if [[ -e "$WDIR/resources/" ]] \
&& [[ ! -z $OUT_RES         ]]; then
#TODO: includes/excludes arrays
\cat >>"$OUT_FILE" <<EOF
		<resources>
			<resource>
				<directory>resources/</directory>
				<filtering>true</filtering>
				<includes>
EOF
if [[ ! -z $OUT_RES ]]; then
	echo -ne $OUT_RES >> "$OUT_FILE"
fi
\cat >>"$OUT_FILE" <<EOF
				</includes>
			</resource>
		</resources>
EOF
fi
if [[ -e "$WDIR/testresources/" ]]; then
\cat >>"$OUT_FILE" <<EOF
		<testResources>
			<testResource>
				<directory>testresources/</directory>
			</testResource>
		</testResources>
EOF
fi

echo -e "\t\t<plugins>\n" >>"$OUT_FILE"

# resources
if [[ -e "$WDIR/resources/" ]] \
|| [[ -e "$WDIR/testresources/" ]]; then
\cat >>"$OUT_FILE" <<EOF
			<!-- Resource Plugin -->
			<plugin>
				<artifactId>maven-resources-plugin</artifactId>
				<groupId>org.apache.maven.plugins</groupId>
				<version>\${maven-resources-plugin-version}</version>
				<configuration>
					<nonFilteredFileExtensions>
						<nonFilteredFileExtension>png</nonFilteredFileExtension>
						<nonFilteredFileExtension>so</nonFilteredFileExtension>
						<nonFilteredFileExtension>dll</nonFilteredFileExtension>
					</nonFilteredFileExtensions>
				</configuration>
			</plugin>
EOF
fi

# java compiler plugin
\cat >>"$OUT_FILE" <<EOF
			<!-- Compiler Plugin -->
			<plugin>
				<groupId>org.apache.maven.plugins</groupId>
				<artifactId>maven-compiler-plugin</artifactId>
				<version>\${maven-compiler-plugin-version}</version>
				<configuration>
					<source>11</source>
					<target>11</target>
				</configuration>
			</plugin>

EOF

# jar plugin
\cat >>"$OUT_FILE" <<EOF
			<!-- Jar Plugin -->
			<plugin>
				<groupId>org.apache.maven.plugins</groupId>
				<artifactId>maven-jar-plugin</artifactId>
				<version>\${maven-jar-plugin-version}</version>
EOF
# main class
if [[ ! -z $MAINCLASS ]]; then
\cat >>"$OUT_FILE" <<EOF
				<!-- Main Class -->
				<configuration>
					<archive>
						<manifest>
							<mainClass>$MAINCLASS</mainClass>
						</manifest>
					</archive>
				</configuration>
EOF
fi
\cat >>"$OUT_FILE" <<EOF
			</plugin>

EOF

# source plugin
\cat >>"$OUT_FILE" <<EOF
			<!-- Source Plugin -->
			<plugin>
				<groupId>org.apache.maven.plugins</groupId>
				<artifactId>maven-source-plugin</artifactId>
				<version>\${maven-source-plugin-version}</version>
				<configuration>
					<finalName>\${project.name}-\${project.version}</finalName>
					<attach>false</attach>
				</configuration>
				<executions>
					<execution>
						<id>attach-sources</id>
						<goals>
							<goal>jar</goal>
						</goals>
					</execution>
				</executions>
			</plugin>

EOF

# eclipse plugin
\cat >>"$OUT_FILE" <<EOF
			<!-- Eclipse Plugin -->
			<plugin>
				<groupId>org.apache.maven.plugins</groupId>
				<artifactId>maven-eclipse-plugin</artifactId>
				<version>\${maven-eclipse-plugin-version}</version>
				<configuration>
					<projectNameTemplate>\${project.name}</projectNameTemplate>
					<downloadSources>true</downloadSources>
					<downloadJavadocs>true</downloadJavadocs>
				</configuration>
			</plugin>

EOF

# git commit id plugin
\cat >>"$OUT_FILE" <<EOF
			<!-- Commit-ID Plugin -->
			<plugin>
				<groupId>pl.project13.maven</groupId>
				<artifactId>git-commit-id-plugin</artifactId>
				<version>\${git-commit-id-version}</version>
				<executions>
					<execution>
						<id>get-the-git-infos</id>
						<goals>
							<goal>revision</goal>
						</goals>
						<phase>validate</phase>
					</execution>
				</executions>
				<configuration>
					<dotGitDirectory>.git/</dotGitDirectory>
				</configuration>
			</plugin>

EOF

# shade jar
if [[ $SHADE -eq $YES ]]; then
\cat >>"$OUT_FILE" <<EOF
			<!-- Shade Plugin -->
			<plugin>
				<groupId>org.apache.maven.plugins</groupId>
				<artifactId>maven-shade-plugin</artifactId>
				<version>\${maven-shade-plugin-version}</version>
				<executions>
					<execution>
						<phase>package</phase>
						<goals>
							<goal>shade</goal>
						</goals>
					</execution>
				</executions>
				<configuration>
					<dependencyReducedPomLocation>\${project.basedir}/target/dependency-reduced-pom.xml</dependencyReducedPomLocation>
					<filters>
					</filters>
				</configuration>
			</plugin>

EOF
fi

# jUnit
if [[ -e "$WDIR/tests/" ]]; then
	AddDep  "junit"  "junit"  scope=test
\cat >>"$OUT_FILE" <<EOF
			<!-- Surefire Plugin -->
			<plugin>
				<groupId>org.apache.maven.plugins</groupId>
				<artifactId>maven-surefire-plugin</artifactId>
				<version>\${surefire-version}</version>
				<configuration>
					<useFile>false</useFile>
					<parallel>methods</parallel>
					<threadCount>4</threadCount>
					<trimStackTrace>false</trimStackTrace>
				</configuration>
			</plugin>

			<!-- Cobertura Plugin -->
			<plugin>
				<groupId>org.codehaus.mojo</groupId>
				<artifactId>cobertura-maven-plugin</artifactId>
				<version>\${cobertura-version}</version>
				<configuration>
					<quiet>true</quiet>
				</configuration>
			</plugin>

			<!-- JXR - Cross Reference -->
			<plugin>
				<groupId>org.apache.maven.jxr</groupId>
				<artifactId>jxr</artifactId>
				<version>\${jxr-version}</version>
			</plugin>

			<!-- Reports -->
			<plugin>
				<groupId>org.apache.maven.plugins</groupId>
				<artifactId>maven-project-info-reports-plugin</artifactId>
				<version>\${project-info-reports-version}</version>
			</plugin>

EOF
fi

\cat >>"$OUT_FILE" <<EOF
		</plugins>
	</build>
EOF

# 3rd party repositories
if [[ ! -z $OUT_REPOS ]]; then
	echo -e "\t<repositories>"  >>"$OUT_FILE"
	echo -en "$OUT_REPOS"       >>"$OUT_FILE"
	echo -e "\t</repositories>" >>"$OUT_FILE"
fi

# dependencies
if [[ ! -z $OUT_DEPS ]]; then
	echo -e "\t<dependencies>"  >>"$OUT_FILE"
	echo -en "$OUT_DEPS"        >>"$OUT_FILE"
	echo -e "\t</dependencies>" >>"$OUT_FILE"
fi

if [[ -e "$WDIR/tests/" ]]; then
\cat >>"$OUT_FILE" <<EOF
	<reporting>
		<plugins>
			<!-- Reports Plugin -->
			<plugin>
				<groupId>org.apache.maven.plugins</groupId>
				<artifactId>maven-project-info-reports-plugin</artifactId>
				<version>\${project-info-reports-version}</version>
				<configuration>
					<dependencyLocationsEnabled>false</dependencyLocationsEnabled>
				</configuration>
			</plugin>
			<!-- Cobertura Plugin -->
			<plugin>
				<groupId>org.codehaus.mojo</groupId>
				<artifactId>cobertura-maven-plugin</artifactId>
				<version>\${cobertura-version}</version>
				<configuration>
					<formats>
						<format>html</format>
						<format>xml</format>
					</formats>
				</configuration>
			</plugin>
			<!-- Cross-Reference Plugin -->
			<plugin>
				<groupId>org.apache.maven.plugins</groupId>
				<artifactId>maven-jxr-plugin</artifactId>
				<version>\${jxr-version}</version>
			</plugin>
		</plugins>
	</reporting>
EOF
fi

echo "</project>" >>"$OUT_FILE"



# diff
HASH_NEW=$( \grep -v "<\!-- Generated: " "$OUT_FILE"     | \md5sum )
HASH_OLD=$( \grep -v "<\!-- Generated: " "$WDIR/pom.xml" | \md5sum )
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
	\cp -fv  "$OUT_FILE"  "$WDIR/pom.xml"  || exit 1
	notice "Generated pom.xml file"
fi
notice "containing [$LINE_COUNT] lines"
\rm  --preserve-root -f  "$OUT_FILE"



echo
exit 0
