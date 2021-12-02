Name    : xbuild
Version : 2.1.%{?build_number}%{!?build_number:x}
Release : 1
Summary : A tool to simplify building and managing projects in your workspace

Requires : shellscripts >= 2.0.6
Requires : bash, zip, unzip, grep
Requires : autogen autoconf libtool
Requires : /usr/bin/rpmbuild
Requires : /usr/bin/automake
Requires : composer
#Obsoletes: project-tools

BuildArch : noarch
Packager  : PoiXson <support@poixson.com>
License   : GPLv3
URL       : https://poixson.com/

Prefix: %{_bindir}/pxn/scripts
%define _rpmfilename  %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm

%description
A tool to simplify building and managing projects in your workspace.



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

# create symlinks
%{__ln_s} -f  "%{prefix}/xbuild.sh"  "%{buildroot}%{_bindir}/xbuild"  || exit 1
%{__ln_s} -f  "%{prefix}/genautotools.sh"  "%{buildroot}%{_bindir}/genautotools"  || exit 1
%{__ln_s} -f  "%{prefix}/genpom.sh"        "%{buildroot}%{_bindir}/genpom"        || exit 1
# create profile.d symlink
%{__ln_s} -f "%{prefix}/xbuild-aliases.sh"  "%{buildroot}%{_sysconfdir}/profile.d/xbuild-aliases.sh"  || exit 1



### Files ###
%files
%defattr(0555, root, root, 0755)
%{prefix}/xbuild.sh
%{prefix}/genautotools.sh
%{prefix}/genpom.sh
%{prefix}/xbuild-aliases.sh
# symlinks
%{_bindir}/xbuild
%{_bindir}/genautotools
%{_bindir}/genpom
%{_sysconfdir}/profile.d/xbuild-aliases.sh
