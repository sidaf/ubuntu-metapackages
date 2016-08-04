#!/bin/bash

## START CONFIG ##

PUBLIC_KEY="CAE172DB"

## END CONFIG ##

if ! (dpkg -l | grep -iq equivs); then
  echo "[!] The 'equivs' package does not appear to be installed, quitting..."
  exit 1
fi

if ! (dpkg -l | grep -iq debsigs); then
  echo "[!] The 'debsigs' package does not appear to be installed, quitting..."
  exit 1
fi

echo "[*] Creating directory structure ..."
mkdir -p dists/kali/main/binary-{i386,amd64}
mkdir -p pool

if test -n "$(find ./equivs/ -maxdepth 1 -name '*.cfg' -print -quit)"; then
  echo "[*] Building meta packages ..."
  for file in $(ls -1 equivs/*.cfg)
  do
    echo "  - $file"
    cd pool
    equivs-build ../$file > /dev/null
    cd ..
  done
else
  echo "[*] No meta package configuration files found, skipping ..."
fi

if test -n "$(find ./pool/ -maxdepth 1 -name '*.deb' -print -quit)"; then
  echo "[*] Signing packages ..."
  for file in $(ls -1 pool/*.deb)
  do
    echo "  - $file"
    debsigs --sign=origin -k $PUBLIC_KEY $file
  done

  echo "[*] Generating Packages and Packages.gz files ..."
  apt-ftparchive --arch i386 packages ./pool/ /dev/null pool | tee dists/kali/main/binary-i386/Packages | gzip > dists/kali/main/binary-i386/Packages.gz
  apt-ftparchive --arch amd64 packages ./pool/ /dev/null pool | tee dists/kali/main/binary-amd64/Packages | gzip > dists/kali/main/binary-amd64/Packages.gz

  cd dists/kali

  echo "[*] Generating the Release file ..."
  apt-ftparchive release . > Release

  echo "[*] Signing the Release file ..."
  gpg --yes --armor --local-user $PUBLIC_KEY --output Release.gpg --detach-sig Release

  echo "[*] Generating the InRelease file ..."
  gpg --yes --clearsign --local-user $PUBLIC_KEY --output InRelease Release

  cd ../../

  echo "[*] Exporting the gpg public key for the repository to a file ..."
  gpg --armor --export CAE172DB > repository.key

  echo ""
  echo "[+] Run the following command to enable this repostory on the local system:"
  echo ""
  echo "echo \"deb file://$(pwd) kali main\" > /etc/apt/sources.list.d/local.list"
  echo ""
  echo "[+] Import the repository public GPG key:"
  echo ""
  echo "apt-key add $(pwd)/repository.key"
  echo ""
  echo "[+] Update apt index to recognise the new repository:"
  echo ""
  echo "apt update"
  echo ""
else
  echo "[!] No deb packages found, quitting..."
  exit 1
fi
