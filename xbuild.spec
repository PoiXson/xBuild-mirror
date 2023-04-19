Name    : xbuild
Summary : A tool to simplify building and managing projects in your workspace
Version : 2.1.%{?build_number}%{!?build_number:x}
Release : 1
BuildArch : noarch
Prefix: %{_bindir}/pxn/scripts
%define _rpmfilename  %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm

License  : AGPLv3
Packager : PoiXson <support@poixson.com>
URL      : https://poixson.com/

Requires : pxnscripts >= 2.1.0
Requires : bash, bc, zip, unzip, grep
Recommends: rpmbuild, fakeroot, alien, composer
Recommends: automake, autogen, autoconf, libtool

%package -n xdeploy
Summary  : Auto deploy a project or website
Requires : pxnscripts >= 2.1.0
Requires : git, composer

%package -n xbuild-repos
Summary  : Setup and maintain a yum/dnf repo
Provides : xbuild-repo
Requires : pxnscripts >= 2.1.0
Requires : bash
Recommends: createrepo_c, dpkg-dev

%description
A tool to simplify building and managing projects in your workspace.

%description -n xdeploy
Auto deploy a project or website

%description -n xbuild-repos
A tool to simplify setting up a yum/dnf repository.



### Install ###
%install
echo
echo "Install.."

# create dirs
%{__install} -d -m 0755  \
	"%{buildroot}%{prefix}/"                     \
	"%{buildroot}%{_sysconfdir}/profile.d/"      \
	"%{buildroot}%{_sysconfdir}/xbuild/"         \
	"%{buildroot}%{_sysconfdir}/xbuild/stages/"  \
		|| exit 1

\pushd  "%{_topdir}/../src/"  >/dev/null  || exit 1
	# /usr/bin/
	%{__install} -m 0644  "xbuild.sh"        "%{buildroot}%{_bindir}/xbuild"        || exit 1
	%{__install} -m 0644  "xdeploy.sh"       "%{buildroot}%{_bindir}/xdeploy"       || exit 1
	%{__install} -m 0644  "genautotools.sh"  "%{buildroot}%{_bindir}/genautotools"  || exit 1
	%{__install} -m 0644  "genpom.sh"        "%{buildroot}%{_bindir}/genpom"        || exit 1
	%{__install} -m 0644  "genspec.sh"       "%{buildroot}%{_bindir}/genspec"       || exit 1
	%{__install} -m 0644  "buildrepos.sh"    "%{buildroot}%{_bindir}/buildrepos"    || exit 1
	# /etc/profile.d/
	%{__install} -m 0644  "etc-profile.d-xbuild.sh"      "%{buildroot}%{_sysconfdir}/profile.d/xbuild.sh"      || exit 1
	%{__install} -m 0644  "etc-profile.d-xdeploy.sh"     "%{buildroot}%{_sysconfdir}/profile.d/xdeploy.sh"     || exit 1
	%{__install} -m 0644  "etc-profile.d-buildrepos.sh"  "%{buildroot}%{_sysconfdir}/profile.d/buildrepos.sh"  || exit 1
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
	%{__install} -m 0644  "xdeploy-example.conf"  "%{buildroot}/xdeploy.conf"  || exit 1
	# /etc/
	%{__install} -m 0644  "maven-versions.conf.example"  "%{buildroot}%{_sysconfdir}/"  || exit 1
	%{__install} -m 0644  ".gitignore"  "%{buildroot}%{_sysconfdir}/xbuild/gitignore"   || exit 1
\popd  >/dev/null



### Files ###
%files
%defattr(0555, root, root, 0755)
%{_bindir}/xbuild
%{_bindir}/genautotools
%{_bindir}/genpom
%{_bindir}/genspec
%{_sysconfdir}/profile.d/xbuild.sh
%{_sysconfdir}/maven-versions.conf.example
%dir %{_sysconfdir}/xbuild/
%dir %{_sysconfdir}/xbuild/stages/
%attr(0644,-,-) %config(noreplace) %{_sysconfdir}/xbuild/gitignore
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
%{_bindir}/buildrepos
%{_sysconfdir}/profile.d/buildrepos.sh
