#!/bin/bash

set -e

unset GPG_AGENT_INFO
GPG_PUBLIC_KEY_FILENAME="__GPG_KEYFILE__.gpg"
GPG_PASSPHRASE=$(cat -)

while getopts "a:d:k:p:r:" opt; do
    case "$opt" in
    a)  action=${OPTARG}
	;;
    d)  distro=${OPTARG}
	;;
    k)	keyname=${OPTARG}
	;;
    p)	package_stage_path=${OPTARG}
	;;
    r)  repo_path=${OPTARG}
        ;;
    h)  usage 0
	;;
    esac
done

# Put the rest of the cmdline into releases 
shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift
releases=$*

usage() {
    echo -ne "USAGE:\n\tgen_repo -d distro -a (create|update) -k __gpg_keyname__ -p /path/to/packages_stage_folder/ -r /path/to/repo release_name another_release_name\n"
    exit "${1}"
}

# Some basic sanity checks
[[ "${distro}" == "" ]] && \
    echo "ERROR: Please specify the distro via (-d) for APT repo (e.g. debian / ubuntu)" && \
    usage 1
[[ "${repo_path}" == "" ]] && \
    echo "ERROR: Please specify the path via (-r) where you'd like to have your APT repo" && \
    usage 1
[[ "${releases}" == "" ]] && \
    echo "ERROR: I see no releases. Please specify some." && \
    usage 1
# Check that we received supported action otherwise fail early
case ${action} in 
    create)
	;;
    update)
	[[ "${package_stage_path}" == "" ]] && \
	    echo "ERROR: Please specify the package stage path via (-p) from where new packages will be uploaded into APT repo" && \
	    usage 1
	[[ "${keyname}" == "" ]] && \
	    echo "ERROR: Please specify the GPG keyname via (-d) for APT repo sign" && \
	    usage 1
	;;
    *)
	echo "ERROR: I see unsupported action ${action} to be performed. Please select one of create / update." && \
	usage
	;;
esac

create() {
    # Create repo path and .cache subfolder
    mkdir -p "${repo_path}/${distro}"; cd "${repo_path}/${distro}"; mkdir -p .cache

    cat > ../apt-ftparchive.conf <<"EOF"
Dir {
        ArchiveDir ".";
        CacheDir "./.cache";
};
Default {
        Packages::Compress ". gzip bzip2";
        Contents::Compress ". gzip bzip2";
};
TreeDefault {
        BinCacheDB "packages-$(SECTION)-$(ARCH).db";
	Directory "pool/$(DIST)/$(SECTION)";
        Packages "$(DIST)/$(SECTION)/binary-$(ARCH)/Packages";
        Contents "$(DIST)/Contents-$(ARCH)";
};
EOF

    for release in ${releases}; do
        mkdir -p "pool/dists/${release}/main"
        mkdir -p "dists/${release}/main/binary-amd64"
        cat > "../apt-release.${release}.conf" <<EOF
APT::FTPArchive::Release::Codename "${release}";
APT::FTPArchive::Release::Origin "deb.example.com";
APT::FTPArchive::Release::Components "main";
APT::FTPArchive::Release::Label "Example DEB repo";
APT::FTPArchive::Release::Architectures "amd64";
APT::FTPArchive::Release::Suite "${release}";
EOF
        cat >> ../apt-ftparchive.conf << EOF
Tree "dists/${release}" {
        Sections "main";
        Architectures "amd64";
}
EOF
    done
    gpg -o "${GPG_PUBLIC_KEY_FILENAME}" --armor --export "${keyname}"
    echo "SUCCESS: Repo structure created successfully! Check the ${repo_path}/${distro}"
}

update() {
    cd "${repo_path}/${distro}"
   
    for release in ${releases}; do 
	if [[ ! -d "${package_stage_path}/${release}" ]]; then
	    echo "WARNING: Cannot find staging package path for release: ${release}. Skipping upload of new packages into the APT repo."
	    continue
	fi
	find "${package_stage_path}/${release}" -iname '*.deb' -exec cp {} "pool/dists/${release}/main/" \;
    done
    
    apt-ftparchive generate ../apt-ftparchive.conf
    for release in ${releases}; do
        apt-ftparchive -c "../apt-release.${release}.conf" release "dists/${release}" > "dists/${release}/Release"
        rm -f dists/"${release}"/{Release.gpg,InRelease}
        # Sign Release file into Release.gpg (separate signature file)
        gpg2 --pinentry-mode loopback --no-tty --batch --passphrase "${GPG_PASSPHRASE}" --sign --default-key "${keyname}" -abs -o "dists/${release}/Release.gpg" "dists/${release}/Release"
        # Sign Release file into InRelease (contains GPG signature inside)
        gpg2 --pinentry-mode loopback --no-tty --batch --passphrase "${GPG_PASSPHRASE}" --clearsign --default-key "${keyname}" -o "dists/${release}/InRelease" "dists/${release}/Release"
    done
}

$action
