Name    : xbuild
Summary : A tool to simplify building and managing projects in your workspace
Version : 2.1.%{?build_number}%{!?build_number:x}
Release : 1
BuildArch : noarch
Prefix: %{_bindir}/pxn/scripts
%define _rpmfilename  %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm

License   : GPLv3
Packager  : PoiXson <support@poixson.com>
URL       : https://poixson.com/

Requires : shellscripts >= 2.0.8
Requires : bash, zip, unzip, grep
#Requires : autogen autoconf libtool
#Requires : /usr/bin/rpmbuild
#Requires : /usr/bin/automake
#Requires : composer
#Obsoletes: project-tools

%package -n xbuild-repo
Summary : Setup and maintain a yum/dnf repo
Requires : shellscripts >= 2.0.8
Requires : bash, createrepo_c

%description
A tool to simplify building and managing projects in your workspace.

%description -n xbuild-repo
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

# copy files
%{__install} -m 0644  "%{_topdir}/../src/"*.sh  "%{buildroot}%{prefix}/"  || exit 1
%{__install} -m 0644  "%{_topdir}/../maven-versions.conf.example"  "%{buildroot}%{_sysconfdir}/"  || exit 1

# {{{version}}} tag
\sed -i  's/{{{VERSION}}}/%{version}/'  "%{buildroot}%{prefix}/xbuild.sh"        || exit 1
\sed -i  's/{{{VERSION}}}/%{version}/'  "%{buildroot}%{prefix}/genautotools.sh"  || exit 1
\sed -i  's/{{{VERSION}}}/%{version}/'  "%{buildroot}%{prefix}/genpom.sh"        || exit 1
\sed -i  's/{{{VERSION}}}/%{version}/'  "%{buildroot}%{prefix}/genspec.sh"       || exit 1
\sed -i  's/{{{VERSION}}}/%{version}/'  "%{buildroot}%{prefix}/buildrepos.sh"    || exit 1

# create symlinks
%{__ln_s} -f  "pxn/scripts/xbuild.sh"        "%{buildroot}%{_bindir}/xbuild"        || exit 1
%{__ln_s} -f  "pxn/scripts/genautotools.sh"  "%{buildroot}%{_bindir}/genautotools"  || exit 1
%{__ln_s} -f  "pxn/scripts/genpom.sh"        "%{buildroot}%{_bindir}/genpom"        || exit 1
%{__ln_s} -f  "pxn/scripts/genspec.sh"       "%{buildroot}%{_bindir}/genspec"       || exit 1
%{__ln_s} -f  "pxn/scripts/buildrepos.sh"    "%{buildroot}%{_bindir}/buildrepos"    || exit 1
# create profile.d symlink
%{__ln_s} -f "../..%{prefix}/xbuild-aliases.sh"  "%{buildroot}%{_sysconfdir}/profile.d/xbuild-aliases.sh"  || exit 1



### Files ###
%files
%defattr(0555, root, root, 0755)
%{prefix}/xbuild.sh
%{prefix}/genspec.sh
%{prefix}/genautotools.sh
%{prefix}/genpom.sh
%{_sysconfdir}/maven-versions.conf.example
%{prefix}/xbuild-aliases.sh
# symlinks
%{_bindir}/xbuild
%{_bindir}/genspec
%{_bindir}/genautotools
%{_bindir}/genpom
%{_sysconfdir}/profile.d/xbuild-aliases.sh

%files -n xbuild-repo
%defattr(0555, root, root, 0755)
%{prefix}/buildrepos.sh
# symlinks
%{_bindir}/buildrepos
