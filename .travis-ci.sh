#!/bin/bash
# from: http://www.tomaz.me/2013/12/02/running-travis-ci-tests-on-arm.html
# Based on a test script from avsm/ocaml repo https://github.com/avsm/ocaml

CHROOT_DIR=/tmp/arm-chroot
MIRROR=https://rcn-ee.com/rootfs/2015-06-11/debian-8.1-console-armhf-2015-06-11.tar.xz
VERSION=jessie
CHROOT_ARCH=armhf

# Debian package dependencies for the host
HOST_DEPENDENCIES="debootstrap qemu-user-static binfmt-support sbuild"

# Debian package dependencies for the chrooted environment
GUEST_DEPENDENCIES="pv"

# Command used to run the tests
TEST_COMMAND="uname -a"

function setup_arm_chroot {
    # Host dependencies
    sudo apt-get update -qq
    sudo apt-get install -qq -y ${HOST_DEPENDENCIES}

    # Create chrooted environment
    sudo mkdir -p ${CHROOT_DIR}
    wget  ${MIRROR}
    sudo tar xf debian-8.1-console-armhf-2015-06-11.tar.xz
    sudo tar xf debian-8.1-console-armhf-2015-06-11/armhf-rootfs-debian-jessie.tar -C ${CHROOT_DIR}
    # Create file with environment variables which will be used inside chrooted
    # environment
    echo "export ARCH=${ARCH}" > envvars.sh
    echo "export TRAVIS_BUILD_DIR=${TRAVIS_BUILD_DIR}" >> envvars.sh
    chmod a+x envvars.sh

    # Install dependencies inside chroot
    sudo cp /usr/bin/qemu-arm-static ${CHROOT_DIR}/usr/bin/
  #  sudo chroot ${CHROOT_DIR} apt-get update
  #  sudo chroot ${CHROOT_DIR} apt-get --allow-unauthenticated install \
  #      -qq -y ${GUEST_DEPENDENCIES}

    # Create build dir and copy travis build files to our chroot environment
    sudo mkdir -p ${CHROOT_DIR}/${TRAVIS_BUILD_DIR}
    sudo rsync -av ${TRAVIS_BUILD_DIR}/ ${CHROOT_DIR}/${TRAVIS_BUILD_DIR}/

    sudo mount -o bind /proc ${CHROOT_DIR}/proc

    # workaround where chroot does not resolve dns with standard servers
    echo 'nameserver 208.67.222.222' |  sudo tee ${CHROOT_DIR}/etc/resolv.conf
    echo 'nameserver 208.67.220.220' | sudo tee --append ${CHROOT_DIR}/etc/resolv.conf

    # Indicate chroot environment has been set up
    sudo touch ${CHROOT_DIR}/.chroot_is_done
    ls ${CHROOT_DIR}
    # Call ourselves again which will cause tests to run
    sudo chroot ${CHROOT_DIR} bash -c "./.travis-ci.sh"
}

if [ -e "/.chroot_is_done" ]; then
  # We are inside ARM chroot
  echo "Running inside chrooted environment"

  . ./envvars.sh
  env
  echo "Building..."
  echo "Environment: $(uname -a)"
  ./build.sh
else
  if [ "${ARCH}" = "arm" ]; then
    # ARM test run, need to set up chrooted environment first
#    env
    echo '-----------------------'
    echo "Setting up chrooted ARM environment"
    setup_arm_chroot
  fi
fi

${TEST_COMMAND}

if [ -e "/.chroot_is_done" ]; then
  ./lib/unmount.sh
fi