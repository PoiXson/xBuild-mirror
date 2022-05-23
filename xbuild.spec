Name    : xbuild
Summary : A tool to simplify building and managing projects in your workspace
Version : 2.1.%{?build_number}%{!?build_number:x}
Release : 1
BuildArch : noarch
Prefix: %{_bindir}/pxn/scripts
%define _rpmfilename  %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm

License  : GPLv3
Packager : PoiXson <support@poixson.com>
URL      : https://poixson.com/

Requires : pxnscripts >= 2.1.0
Requires : bash, bc, zip, unzip, grep
#Requires : autogen autoconf libtool
#Requires : /usr/bin/rpmbuild
#Requires : /usr/bin/automake
#Requires : composer
#Obsoletes: project-tools

%package -n xbuild-repos
Summary  : Setup and maintain a yum/dnf repo
Provides : xbuild-repo
Requires : pxnscripts >= 2.1.0
Requires : bash, createrepo_c

%description
A tool to simplify building and managing projects in your workspace.

%description -n xbuild-repos
A tool to simplify setting up a yum/dnf repository.



### Install ###
%install
echo
echo "Install.."

# create dirs
%{__install} -d -m 0755  \
	"%{buildroot}%{prefix}/"                 \
	"%{buildroot}%{_sysconfdir}/profile.d/"  \
		|| exit 1

# /usr/bin/
%{__install} -m 0644  "%{_topdir}/../src/xbuild.sh"        "%{buildroot}%{_bindir}/xbuild"        || exit 1
%{__install} -m 0644  "%{_topdir}/../src/genautotools.sh"  "%{buildroot}%{_bindir}/genautotools"  || exit 1
%{__install} -m 0644  "%{_topdir}/../src/genpom.sh"        "%{buildroot}%{_bindir}/genpom"        || exit 1
%{__install} -m 0644  "%{_topdir}/../src/genspec.sh"       "%{buildroot}%{_bindir}/genspec"       || exit 1
%{__install} -m 0644  "%{_topdir}/../src/buildrepos.sh"    "%{buildroot}%{_bindir}/buildrepos"    || exit 1
# /etc/profile.d/
%{__install} -m 0644  "%{_topdir}/../src/etc-profile.d-xbuild.sh"      "%{buildroot}%{_sysconfdir}/profile.d/xbuild.sh"      || exit 1
%{__install} -m 0644  "%{_topdir}/../src/etc-profile.d-buildrepos.sh"  "%{buildroot}%{_sysconfdir}/profile.d/buildrepos.sh"  || exit 1
# /etc/
%{__install} -m 0644  "%{_topdir}/../maven-versions.conf.example"  "%{buildroot}%{_sysconfdir}/"  || exit 1

# {{{version}}} tag
\sed -i  's/{{{VERSION}}}/%{version}/'  "%{buildroot}%{_bindir}/xbuild"        || exit 1
\sed -i  's/{{{VERSION}}}/%{version}/'  "%{buildroot}%{_bindir}/genautotools"  || exit 1
\sed -i  's/{{{VERSION}}}/%{version}/'  "%{buildroot}%{_bindir}/genpom"        || exit 1
\sed -i  's/{{{VERSION}}}/%{version}/'  "%{buildroot}%{_bindir}/genspec"       || exit 1
\sed -i  's/{{{VERSION}}}/%{version}/'  "%{buildroot}%{_bindir}/buildrepos"    || exit 1



### Files ###
%files
%defattr(0555, root, root, 0755)
%{_bindir}/xbuild
%{_bindir}/genautotools
%{_bindir}/genpom
%{_bindir}/genspec
%{_sysconfdir}/profile.d/xbuild.sh
%{_sysconfdir}/maven-versions.conf.example

%files -n xbuild-repos
%defattr(0555, root, root, 0755)
%{_bindir}/buildrepos
%{_sysconfdir}/profile.d/buildrepos.sh
