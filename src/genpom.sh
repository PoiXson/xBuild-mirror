#!/usr/bin/bash
##==============================================================================
## Copyright (c) 2019-2024 Mattsoft/PoiXson
## <https://mattsoft.net> <https://poixson.com>
## Released under the AGPL 3.0
##
## Description: Generates pom.xml files for maven
##
## Example:
## > curl --output configer-install.sh https://configer.online/install.sh
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

if [[ -z $WDIR ]]; then
	echo
	failure "Failed to find current working directory"
	failure ; exit 1
fi



COMPILE_FOR_JAVA_VERSION="21"

MAVEN_VERSIONS_FILE="maven-versions.conf"
SHADE=$NO
SNAPSHOT=$YES

OUT_VERSION=""
OUT_PROPS=""
OUT_PROPS_DEPS=""
OUT_PROPS_PLUGINS=""
OUT_PLUGINS=""
OUT_DEPS=""
OUT_REPOS=""
OUT_RES=""
OUT_BIN=""



function DisplayHelp() {
	echo -e "${COLOR_BROWN}Usage:${COLOR_RESET}"
	echo    "  genpom [options] <group>"
	echo
	echo -e "${COLOR_BROWN}Options:${COLOR_RESET}"
	echo -e "  ${COLOR_GREEN}-R, --release [version]${COLOR_RESET}   Build a production release"
	echo -e "  ${COLOR_GREEN}-S, --snapshot [version]${COLOR_RESET}  Build a snapshot"
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
		SNAPSHOT=$NO
		if [[ ! -z $2 ]] && [[ "$2" != "-"* ]]; then
			\shift
			OUT_VERSION="$1"
		fi
	;;
	-S|--snapshot)
		SNAPSHOT=$YES
		if [[ ! -z $2 ]] && [[ "$2" != "-"* ]]; then
			\shift
			OUT_VERSION="$1"
		fi
	;;
	--release=*)   OUT_VERSION=${1#*=}  ;;
	--snapshot=*)  OUT_VERSION=${1#*=}  ;;
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
	OUT_PROPS="$OUT_PROPS"$'\t\t'"<$1>$2</$1>"$'\n'
}
function AddPropDep() {
	local KEY="${1//./-}"
	local VAL="$2"
	OUT_PROPS_DEPS="$OUT_PROPS_DEPS"$'\t\t'"<$KEY>$VAL</$KEY>"$'\n'
}
function AddPropPlugin() {
	OUT_PROPS_PLUGINS="$OUT_PROPS_PLUGINS"$'\t\t'"<$1>$2</$1>"$'\n'
}



function AddDep() {
	local GROUP="$1"
	local ARTIFACT="$2"
	shift ; shift
	local SCOPE=""
	local VERSION=""
	while [ $# -gt 0 ]; do
		case "$1" in
		"scope="*)   SCOPE="${1#*scope=}"   ;;
		"version="*) VERSION="${1#*scope=}" ;;
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
	OUT_DEPS+=$( \cat <<EOF
		<dependency>
			<artifactId>$ARTIFACT</artifactId>
			<groupId>$GROUP</groupId>
			<version>\${${ARTIFACT//./-}-version}</version>
EOF
	)
	OUT_DEPS+=$'\n'
	if [[ ! -z $SCOPE ]]; then
		OUT_DEPS="$OUT_DEPS"$'\t\t\t'"<scope>$SCOPE</scope>"$'\n'
	fi
	OUT_DEPS="$OUT_DEPS"$'\t\t'"</dependency>"$'\n'
}

function AddRepo() {
	local NAME="$1"
	local URL="$2"
	shift ; shift
	local ALLOW_SNAPSHOTS=$NO
	while [ $# -gt 0 ]; do
		case "$1" in
		"snap"|"snaps"|"snapshot"|"snapshots"|"SNAP"|"SNAPS"|"SNAPSHOT"|"SNAPSHOTS")
			ALLOW_SNAPSHOTS=$YES
			;;
		*)
			failure "Unknown repository argument: $1"
			failure ; exit 1
		;;
		esac
		shift
	done
	if [[ -z $NAME ]]; then
		failure "Repo Name argument is required"
		failure ; exit 1
	fi
	if [[ -z $URL ]]; then
		failure "Repo URL argument is required"
		failure ; exit 1
	fi
	ENABLE_SNAPSHOTS="false"
	if [[ $ALLOW_SNAPSHOTS -eq $YES ]]; then
		ENABLE_SNAPSHOTS="true"
	fi
	OUT_REPOS+=$( \cat <<EOF
		<repository>
			<id>$NAME</id>
			<url>$URL</url>
			<releases>
				<enabled>true</enabled>
			</releases>
			<snapshots>
				<enabled>$ENABLE_SNAPSHOTS</enabled>
			</snapshots>
		</repository>
EOF
	)
	OUT_REPOS+=$'\n'
}

function AddRes() {
	if [[ -z $1 ]]; then
		failure "AddRes requires a file argument to include"
		failure ; exit 1
	fi
	OUT_RES="$OUT_RES"$'\t\t\t\t\t'"<include>$1</include>"$'\n'
}
function AddBin() {
	if [[ -z $1 ]]; then
		failure "AddBin requires a file argument to include"
		failure ; exit 1
	fi
	OUT_BIN="$OUT_BIN"$'\t\t\t\t\t'"<include>$1</include>"$'\n'
}



FIND_DEP_BY_ARTIFACT=""
FIND_DEP_BY_GROUP=""
FOUND_DEP_VERSION=""
function FindDepVersion() {
	FIND_DEP_BY_GROUP="$1"
	FIND_DEP_BY_ARTIFACT="$2"
	FOUND_DEP_VERSION=""
	# home dir
	if [[ -e "~/$MAVEN_VERSIONS_FILE" ]]; then
		source "~/$MAVEN_VERSIONS_FILE"  || exit 1
		[[ ! -z $FOUND_DEP_VERSION ]] && return
		DID_SOMETHING=$YES
	fi
	# search current dir and parents
	local P="$WDIR"
	for i in {0..5}; do
		[[ $i -gt 0 ]] && \
			P="$P/.."
		if [[ -e "$P/$MAVEN_VERSIONS_FILE" ]]; then
			source  "$P/$MAVEN_VERSIONS_FILE"  || exit 1
			[[ ! -z $FOUND_DEP_VERSION ]] && return
			DID_SOMETHING=$YES
		fi
	done
	# /etc
	if [[ -e "/etc/$MAVEN_VERSIONS_FILE" ]]; then
		source "/etc/$MAVEN_VERSIONS_FILE"  || exit 1
		[[ ! -z $FOUND_DEP_VERSION ]] && return
		DID_SOMETHING=$YES
	fi
	# /etc/java
	if [[ -e "/etc/java/$MAVEN_VERSIONS_FILE" ]]; then
		source "/etc/java/$MAVEN_VERSIONS_FILE"  || exit 1
		[[ ! -z $FOUND_DEP_VERSION ]] && return
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



if [[ ! -z $VERSION ]]; then
	failure "Version in conf not supported"
	failure ; exit 1
fi
if [[ ! -z $OUT_VERSION ]]; then
	[[ "$OUT_VERSION" == *"SNAPSHOT"* ]] && \
		SNAPSHOT=$YES
fi
if [[ "$OUT_VERSION" == *"-"* ]]; then
	OUT_VERSION=${OUT_VERSION%%-*}
fi
if [[ $SNAPSHOT -eq $YES ]]; then
	OUT_VERSION="$OUT_VERSION-SNAPSHOT"
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

# maven version plugin
FindDepVersion  "org.apache.maven.plugins"  "maven-enforcer-plugin"
AddPropPlugin  "maven-enforcer-plugin-version"  "$FOUND_DEP_VERSION"

# versions plugin
FindDepVersion  "org.codehaus.mojo"  "versions-maven-plugin"
AddPropPlugin  "versions-maven-plugin-version"  "$FOUND_DEP_VERSION"

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
	FindDepVersion  "org.junit.jupiter"  "junit-jupiter"
	AddPropPlugin  "junit-jupiter-version"  "$FOUND_DEP_VERSION"

	# surefire
	FindDepVersion  "org.apache.maven.plugins"  "maven-surefire-plugin"
	AddPropPlugin  "surefire-version"  "$FOUND_DEP_VERSION"

	# jacoco
	FindDepVersion  "org.jacoco"  "jacoco-maven-plugin"
	AddPropPlugin  "jacoco-version"  "$FOUND_DEP_VERSION"

	# jxr - cross reference
	FindDepVersion  "org.apache.maven.jxr"  "jxr"
	AddPropPlugin  "jxr-version"  "$FOUND_DEP_VERSION"

	# reports
	FindDepVersion  "org.apache.maven.plugins"  "maven-project-info-reports-plugin"
	AddPropPlugin  "project-info-reports-version"  "$FOUND_DEP_VERSION"

fi



# temp file
OUT_FILE=$( \mktemp )
RESULT=$?
if [[ $RESULT -ne 0 ]] \
|| [[ -z $OUT_FILE  ]]; then
	failure "Failed to create a temp file"
	failure ; exit 1
fi



# generate pom.xml
echo -n >"$OUT_FILE"
TIMESTAMP=$( \date )
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
	<version>$OUT_VERSION</version>
	<packaging>jar</packaging>
EOF
[[ -z $URL  ]] || echo $'\t'"<url>$URL</url>"                  >>"$OUT_FILE"
[[ -z $DESC ]] || echo $'\t'"<description>$DESC</description>" >>"$OUT_FILE"
if [[ ! -z $ORG_NAME ]] || [[ ! -z $ORG_URL ]]; then
	echo -e "\t<organization>"                                 >>"$OUT_FILE"
	[[ -z $ORG_NAME ]] || echo $'\t\t'"<name>$ORG_NAME</name>" >>"$OUT_FILE"
	[[ -z $ORG_URL  ]] || echo $'\t\t'"<url>$ORG_URL</url>"    >>"$OUT_FILE"
	echo -e "\t</organization>"                                >>"$OUT_FILE"
fi

# properties
\cat >>"$OUT_FILE" <<EOF
	<properties>
		<project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
		<project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
EOF
if [[ ! -z $LICENSE ]]; then
	echo $'\t\t'"<project.license>$LICENSE</project.license>" >>"$OUT_FILE"
fi
\cat >>"$OUT_FILE" <<EOF
		<java.version>$COMPILE_FOR_JAVA_VERSION</java.version>
		<maven.compiler.release>$COMPILE_FOR_JAVA_VERSION</maven.compiler.release>
		<maven.compiler.source>$COMPILE_FOR_JAVA_VERSION</maven.compiler.source>
		<maven.compiler.target>$COMPILE_FOR_JAVA_VERSION</maven.compiler.target>
EOF
if [[ ! -z $OUT_PROPS ]]; then
	echo -ne "\n\n"   >>"$OUT_FILE"
	echo "$OUT_PROPS" >>"$OUT_FILE"
fi
if [[ ! -z $OUT_PROPS_PLUGINS ]]; then
	echo -e "\n\t\t<!-- Maven Plugins -->" >>"$OUT_FILE"
	echo -n "$OUT_PROPS_PLUGINS"           >>"$OUT_FILE"
fi
if [[ ! -z $OUT_PROPS_DEPS ]]; then
	echo -e "\n\t\t<!-- Dependencies -->" >>"$OUT_FILE"
	echo -n "$OUT_PROPS_DEPS"             >>"$OUT_FILE"
fi
echo -e "\t</properties>" >>"$OUT_FILE"

# scm
if [[ ! -z $REPO_URL ]] || [[ ! -z $REPO_PUB ]] || [[ ! -z $REPO_DEV ]]; then
	echo -e "\t<scm>" >>"$OUT_FILE"
	[[ -z $REPO_URL ]] || echo $'\t\t'"<url>$REPO_URL</url>"                                 >>"$OUT_FILE"
	[[ -z $REPO_PUB ]] || echo $'\t\t'"<connection>$REPO_PUB</connection>"                   >>"$OUT_FILE"
	[[ -z $REPO_DEV ]] || echo $'\t\t'"<developerConnection>$REPO_DEV</developerConnection>" >>"$OUT_FILE"
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
if [[ -e "$WDIR/resources/" ]]; then
	if [[ ! -z $OUT_RES ]] \
	|| [[ ! -z $OUT_BIN ]]; then
		echo -e "\t\t<resources>" >> "$OUT_FILE"
		if [[ ! -z $OUT_RES ]]; then
\cat >>"$OUT_FILE" <<EOF
			<resource>
				<directory>resources/</directory>
				<filtering>true</filtering>
				<includes>
EOF
echo -n "$OUT_RES" >> "$OUT_FILE"
\cat >>"$OUT_FILE" <<EOF
				</includes>
			</resource>
EOF
		fi
		if [[ ! -z $OUT_BIN ]]; then
\cat >>"$OUT_FILE" <<EOF
			<resource>
				<directory>resources/</directory>
				<filtering>false</filtering>
				<includes>
EOF
echo -n "$OUT_BIN" >> "$OUT_FILE"
\cat >>"$OUT_FILE" <<EOF
				</includes>
			</resource>
EOF
		fi
		echo -e "\t\t</resources>" >> "$OUT_FILE"
	fi
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

echo -e "\t\t<plugins>" >>"$OUT_FILE"

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
					<encoding>\${project.build.sourceEncoding}</encoding>
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
					<source>${COMPILE_FOR_JAVA_VERSION}</source>
					<target>${COMPILE_FOR_JAVA_VERSION}</target>
					<encoding>\${project.build.sourceEncoding}</encoding>
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
echo -e "\t\t\t</plugin>" >>"$OUT_FILE"

# maven version plugin
\cat >>"$OUT_FILE" <<EOF
			<!-- Maven Version Enforcer Plugin -->
			<plugin>
				<groupId>org.apache.maven.plugins</groupId>
				<artifactId>maven-enforcer-plugin</artifactId>
				<version>\${maven-enforcer-plugin-version}</version>
				<inherited>true</inherited>
				<executions>
					<execution>
						<id>enforce-maven-version</id>
						<goals>
							<goal>enforce</goal>
						</goals>
						<configuration>
							<rules>
								<requireMavenVersion>
									<version>3.8.5</version>
								</requireMavenVersion>
							</rules>
							<fail>true</fail>
						</configuration>
					</execution>
				</executions>
			</plugin>
EOF

# versions plugin - https://www.mojohaus.org/versions/versions-maven-plugin/index.html
\cat >>"$OUT_FILE" <<EOF
			<!-- Versions Plugin -->
			<plugin>
				<groupId>org.codehaus.mojo</groupId>
				<artifactId>versions-maven-plugin</artifactId>
				<version>\${versions-maven-plugin-version}</version>
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
					<additionalConfig>
						<file>
							<name>.settings/org.eclipse.core.resources.prefs</name>
							<content>
								<![CDATA[eclipse.preferences.version=1\${line.separator}encoding/<project>=\${project.build.sourceEncoding}\${line.separator}]]>
							</content>
						</file>
					</additionalConfig>
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
						<filter>
							<artifact>*</artifact>
							<excludes>
								<exclude>META-INF/*.RSA</exclude>
								<exclude>META-INF/*.SF</exclude>
							</excludes>
						</filter>
					</filters>
				</configuration>
			</plugin>
EOF
fi

# jUnit
if [[ -e "$WDIR/tests/" ]]; then
	AddDep  "org.junit.jupiter"  "junit-jupiter"  scope=test
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
			<!-- JaCoCo - Code Coverage -->
			<plugin>
				<groupId>org.jacoco</groupId>
				<artifactId>jacoco-maven-plugin</artifactId>
				<version>\${jacoco-version}</version>
				<executions>
					<execution>
						<goals>
							<goal>prepare-agent</goal>
						</goals>
					</execution>
					<execution>
						<id>report</id>
						<phase>test</phase>
						<goals>
							<goal>report</goal>
						</goals>
					</execution>
				</executions>
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
	echo -e "\t<repositories>"   >>"$OUT_FILE"
	echo -n "$OUT_REPOS"         >>"$OUT_FILE"
	echo -e "\t</repositories>"  >>"$OUT_FILE"
fi

# dependencies
if [[ ! -z $OUT_DEPS ]]; then
	echo -e "\t<dependencies>"   >>"$OUT_FILE"
	echo -n "$OUT_DEPS"          >>"$OUT_FILE"
	echo -e "\t</dependencies>"  >>"$OUT_FILE"
fi

if [[ -e "$WDIR/tests/" ]]; then
\cat >>"$OUT_FILE" <<EOF
	<reporting>
		<plugins>
			<!-- JaCoCo - Code Coverage -->
			<plugin>
				<groupId>org.jacoco</groupId>
				<artifactId>jacoco-maven-plugin</artifactId>
				<version>\${jacoco-version}</version>
				<reportSets>
					<reportSet>
						<reports>
							<report>report</report>
						</reports>
					</reportSet>
				</reportSets>
			</plugin>
			<!-- Reports Plugin -->
			<plugin>
				<groupId>org.apache.maven.plugins</groupId>
				<artifactId>maven-project-info-reports-plugin</artifactId>
				<version>\${project-info-reports-version}</version>
				<configuration>
					<dependencyLocationsEnabled>false</dependencyLocationsEnabled>
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
HASH_NEW=""
HASH_OLD=""
DATA_NEW=$( \grep -v "<\!-- Generated: " "$OUT_FILE" 2>/dev/null )
if [[ ! -z $DATA_NEW ]]; then HASH_NEW=$( echo "$DATA_NEW" | \md5sum ) ; HASH_NEW="${HASH_NEW%%\ *}" ; fi
if [[ -f "$WDIR/pom.xml" ]]; then
	DATA_OLD=$( \grep -v "<\!-- Generated: " "$WDIR/pom.xml" 2>/dev/null )
	if [[ ! -z $DATA_OLD ]]; then HASH_OLD=$( echo "$DATA_OLD" | \md5sum ) ; HASH_OLD="${HASH_OLD%%\ *}" ; fi
fi
if [[ -z $HASH_NEW ]]; then
	failure "Failed to hash new file"
	failure ; exit 1
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
