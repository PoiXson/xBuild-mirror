Name    : xbuild
Summary : A tool to simplify building and managing projects in your workspace
Version : 2.1.%{?build_number}%{!?build_number:x}
Release : 1

Requires   : pxnscripts >= 2.1.0
Requires   : bash, bc, zip, unzip, grep
Recommends : rpmbuild, fakeroot, alien, composer
Recommends : automake, autogen, autoconf, libtool

BuildArch : noarch
Packager  : PoiXson <support@poixson.com>
License   : AGPLv3
URL       : https://poixson.com/

Prefix: %{_bindir}/pxn/scripts
%define _rpmfilename  %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm



%package -n xdeploy
Summary  : Auto deploy a project or website
Requires : pxnscripts >= 2.1.0
Requires : git, composer



%package -n xbuild-repos
Summary  : Setup and maintain yum/dnf and apt software repositories
Provides : xbuild-repo
Requires : pxnscripts >= 2.1.0
Requires : bash, gnupg
Recommends: createrepo_c, dpkg-dev



%description
A tool to simplify building and managing projects in your workspace.

%description -n xdeploy
Auto deploy a project or website.

%description -n xbuild-repos
Setup and maintain yum/dnf and apt software repositories.



### Install ###
%install
echo
echo "Install.."

# create dirs
%{__install} -d -m 0755  \
	"%{buildroot}%{prefix}/"                     \
	"%{buildroot}%{_sysconfdir}/profile.d/"      \
	"%{buildroot}%{_sysconfdir}/java/"           \
	"%{buildroot}%{_sysconfdir}/xbuild/"         \
	"%{buildroot}%{_sysconfdir}/xbuild/stages/"  \
	"%{buildroot}%{_sysconfdir}/xbuild/stubs/"   \
		|| exit 1

# /usr/bin/
\pushd  "%{_topdir}/../src/"  >/dev/null  || exit 1
	# tools
	%{__install} -m 0644  "xbuild.sh"        "%{buildroot}%{_bindir}/xbuild"        || exit 1
	%{__install} -m 0644  "xdeploy.sh"       "%{buildroot}%{_bindir}/xdeploy"       || exit 1
	%{__install} -m 0644  "genautotools.sh"  "%{buildroot}%{_bindir}/genautotools"  || exit 1
	%{__install} -m 0644  "genpom.sh"        "%{buildroot}%{_bindir}/genpom"        || exit 1
	%{__install} -m 0644  "genspec.sh"       "%{buildroot}%{_bindir}/genspec"       || exit 1
	%{__install} -m 0644  "xbuild-repos.sh"  "%{buildroot}%{_bindir}/xbuild-repos"  || exit 1
	%{__install} -m 0644  "gradle-dl.sh"     "%{buildroot}%{_bindir}/gradle-dl"     || exit 1
	# /usr/bin/pxn/scripts/
	%{__install} -m 0644  \
		"gradle-common.sh"  \
			"%{buildroot}%{prefix}/"  || exit 1
\popd  >/dev/null

# /etc/profile.d/
\pushd  "%{_topdir}/../src/profile.d/"  >/dev/null  || exit 1
	%{__install} -m 0644  "xbuild.sh"        "%{buildroot}%{_sysconfdir}/profile.d/xbuild.sh"        || exit 1
	%{__install} -m 0644  "xdeploy.sh"       "%{buildroot}%{_sysconfdir}/profile.d/xdeploy.sh"       || exit 1
	%{__install} -m 0644  "xbuild-repos.sh"  "%{buildroot}%{_sysconfdir}/profile.d/xbuild-repos.sh"  || exit 1
\popd  >/dev/null
\pushd  "%{_topdir}/../src/xbuild-stages/"  >/dev/null  || exit 1
	%{__install} -m 0644  "10-pull-push.sh"  "%{buildroot}%{_sysconfdir}/xbuild/stages/"  || exit 1
	%{__install} -m 0644  "30-clean.sh"      "%{buildroot}%{_sysconfdir}/xbuild/stages/"  || exit 1
	%{__install} -m 0644  "40-config.sh"     "%{buildroot}%{_sysconfdir}/xbuild/stages/"  || exit 1
	%{__install} -m 0644  "50-build.sh"      "%{buildroot}%{_sysconfdir}/xbuild/stages/"  || exit 1
	%{__install} -m 0644  "70-test.sh"       "%{buildroot}%{_sysconfdir}/xbuild/stages/"  || exit 1
	%{__install} -m 0644  "80-pack.sh"       "%{buildroot}%{_sysconfdir}/xbuild/stages/"  || exit 1
	%{__install} -m 0644  "90-git-gui.sh"    "%{buildroot}%{_sysconfdir}/xbuild/stages/"  || exit 1
\popd  >/dev/null
\pushd  "%{_topdir}/../"  >/dev/null  || exit 1
	# /etc/xbuild/
	%{__install} -m 0644  "xdeploy-example.conf"         "%{buildroot}/xdeploy.conf"         || exit 1
	%{__install} -m 0644  "maven-versions.conf.example"  "%{buildroot}%{_sysconfdir}/java/"  || exit 1
	# /etc/xbuild/stubs/
	%{__install} -m 0644  \
		".gitignore"            \
		".gitattributes"        \
		"stubs/app.properties"  \
		"stubs/phpunit.xml"     \
		"%{buildroot}%{_sysconfdir}/xbuild/stubs/"  \
			|| exit 1
\popd  >/dev/null



%post
if [[ -e "/etc/java/" ]]; then
	if [[ -e "/etc/java/maven.conf" ]]; then
		\pushd  "/etc/java/"  >/dev/null  || exit 1
			\mv -v maven.conf maven.conf.old
		\popd  >/dev/null
	fi
	echo  "JAVA_HOME=""/usr/lib/jvm/java-latest"  \
		> "/etc/java/maven.conf"  || exit 1
	\chmod -c 0644 /etc/java/maven.conf  || exit 1
fi



%postun
if [[ $1 -eq 0 ]]; then
	\alternatives --remove-all gradle
fi



### Files ###
%files
%defattr(0555, root, root, 0755)
%{_bindir}/xbuild
%{_bindir}/genautotools
%{_bindir}/genpom
%{_bindir}/genspec
%{prefix}/gradle-common.sh
%{_bindir}/gradle-dl
%{_sysconfdir}/profile.d/xbuild.sh
%attr(0644,-,-) %{_sysconfdir}/java/maven-versions.conf.example
%dir %{_sysconfdir}/xbuild/
# stubs
%dir %{_sysconfdir}/xbuild/stubs/
%attr(0644,-,-) %config(noreplace) %{_sysconfdir}/xbuild/stubs/.gitignore
%attr(0644,-,-) %config(noreplace) %{_sysconfdir}/xbuild/stubs/.gitattributes
%attr(0644,-,-) %config(noreplace) %{_sysconfdir}/xbuild/stubs/app.properties
%attr(0644,-,-) %config(noreplace) %{_sysconfdir}/xbuild/stubs/phpunit.xml
# build stages
%dir %{_sysconfdir}/xbuild/stages/
%attr(0644,-,-) %{_sysconfdir}/xbuild/stages/10-pull-push.sh
%attr(0644,-,-) %{_sysconfdir}/xbuild/stages/30-clean.sh
%attr(0644,-,-) %{_sysconfdir}/xbuild/stages/40-config.sh
%attr(0644,-,-) %{_sysconfdir}/xbuild/stages/50-build.sh
%attr(0644,-,-) %{_sysconfdir}/xbuild/stages/70-test.sh
%attr(0644,-,-) %{_sysconfdir}/xbuild/stages/80-pack.sh
%attr(0644,-,-) %{_sysconfdir}/xbuild/stages/90-git-gui.sh

%files -n xdeploy
%defattr(0555, root, root, 0755)
%{_bindir}/xdeploy
%{_sysconfdir}/profile.d/xdeploy.sh
%attr(0600,-,-) %config(noreplace) /xdeploy.conf

%files -n xbuild-repos
%defattr(0555, root, root, 0755)
%{_bindir}/xbuild-repos
%{_sysconfdir}/profile.d/xbuild-repos.sh
