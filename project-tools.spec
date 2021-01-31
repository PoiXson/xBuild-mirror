Name    : project-tools
Version : 2.0.%{?build_number}%{!?build_number:x}
Release : 1
Summary : A collection of commonly used scripts for building and managing software projects

Requires : shellscripts
Requires : bash, zip, unzip, grep
Suggests : rpmbuild, automake, composer

BuildArch : noarch
Packager  : PoiXson <support@poixson.com>
License   : GPLv3
URL       : https://poixson.com/

Prefix: %{_bindir}/pxn/scripts
%define _rpmfilename  %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm

%description
A collection of commonly used scripts for building and managing software projects.



### Install ###
%install
echo
echo "Install.."

# delete existing rpm's
%{__rm} -fv --preserve-root  "%{_rpmdir}/%{name}-"*.rpm

# create dirs
%{__install} -d -m 0755  "%{buildroot}%{prefix}/"                 || exit 1
%{__install} -d -m 0755  "%{buildroot}%{_sysconfdir}/profile.d/"  || exit 1

# copy files
%{__install} -m 0644  "%{_topdir}/../src/"*.sh  "%{buildroot}%{prefix}/"  || exit 1

# create symlinks
%{__ln_s} -f  "%{prefix}/workspace.sh"  "%{buildroot}%{_bindir}/workspace"  || exit 1
%{__ln_s} -f  "%{prefix}/autobuild.sh"  "%{buildroot}%{_bindir}/autobuild"  || exit 1
# create profile.d symlink
%{__ln_s} -f "%{prefix}/project-tools-aliases.sh"  "%{buildroot}%{_sysconfdir}/profile.d/project-tools-aliases.sh"  || exit 1



### Files ###
%files
%defattr(0555, root, root, 0755)
%dir %{prefix}/
%{prefix}/workspace.sh
%{prefix}/autobuild.sh
%{prefix}/project-tools-aliases.sh
# symlinks
%{_bindir}/workspace
%{_bindir}/autobuild
%{_sysconfdir}/profile.d/project-tools-aliases.sh
