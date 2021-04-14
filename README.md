# simple-debrepo

Simple tooling to create a simple tooling around DEB APT repos (either Ubuntu or Debian). You know ... when you need something really quick ...

Before proceeding further please read the [Requirements part](README.md#Requirements).

## Create a simple repo

The `manage_apt_repo.sh` is a simple script that is able to perform 2 things:

### Create APT repository

To create a basic APT structure run the following command:
```
bash manage_apt_repo.sh -d __distro__ -a create -k __gpg_keyname__ -r /path/to/repo release_name another_release_name
### or with exact values
bash genrepo.sh -r /srv/debrepo -k 'apt-sign-key@example.com' -a create -d debian stretch buster
```

It will create following structure with basic APT structure:
```
debrepo/
├── apt-ftparchive.conf
├── apt-release.buster.conf
├── apt-release.stretch.conf
└── debian
    ├── dists
    │   ├── buster
    │   │   └── main
    │   │       └── binary-amd64
    │   └── stretch
    │       └── main
    │           └── binary-amd64
    ├── __GPG_KEYFILE__.gpg
    └── pool
        └── dists
            ├── buster
            │   └── main
            └── stretch
                └── main
```

to make things work nicely let's proceed with the update part where we upload packages into the repo and sign the repo `Release` with GPG key.

### Update APT repository content

To upload packages, update `Release` information and sign the repo `Release` file proceed with the following command:
```
echo "__GPG_PASSPHRASE__" | bash manage_apt_repo.sh -d __distro__ -a update -k __gpg_keyname__ -p /path/to/packages_stage_folder/ -r /path/to/repo release_name another_release_name
### Or with exact values
echo "__GPG_PASSPHRASE__" | bash manage_apt_repo.sh -r /srv/debrepo -k 'apt-sign-key@example.com' -p /tmp -a update -d debian stretch buster
```

It will automatically search for all `*.deb` files in `/tmp/{stretch,buster}` folders and adds the into respective folders in `pool/dists` folders per their release name. In case there'll be no package it won't copy anything.
Once done with package uploads the script updates the repo metadata files (`Contents`, `Release`) and signs the repo `Release` file with provided GPG key so it becomes "trusted" for 3rd parties.

## Requirements 

To make the `simple-debrepo` work you'll need to have existing GPG key secured 
by passphrase present on the machine, where you're about to run the script.

You may create one with `gpg --full-generate-key`, it will be stored locally under `~/.gnupg/` ... but feel free to follow a ton of Google search links and howtos.
