#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.1.10
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=/opt/toolchain/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    git am ${FINDER_APP_DIR}/dtc-Remove-redundant-YYLOC-global-declaratio.patch
    # TODO: Add your kernel build steps here


    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -j4 all

fi

echo "Adding the Image in outdir"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"

echo "Adding the Image in outdir"
cp linux-stable/arch/${ARCH}/boot/Image .
ls -lah ./Image

if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories

if [ ! -d "${OUTDIR}/rootfs" ]
then
    mkdir ${OUTDIR}/rootfs
    cd ${OUTDIR}/rootfs
    mkdir \
        bin \
        dev \
        etc \
        home \
        lib \
        lib64 \
        proc \
        sbin \
        sys \
        tmp \
        usr \
        usr/bin \
        usr/lib \
        usr/sbin \
        var \
        var/log
fi


cd "$OUTDIR"

if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
else
    cd busybox
fi

if [ ! -e ./busybox ]; then
    make   distclean
    make   defconfig
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
fi

# TODO: Make and install busybox
BUSYBOX_BINARY="${OUTDIR}/rootfs/bin/busybox"
if [ ! -e "${BUSYBOX_BINARY}" ]; then
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX="${OUTDIR}/rootfs" install
fi




# TODO: Add library dependencies to rootfs

# Add library dependencies to rootfs
echo
echo "Intalling busybox dependencies in /lib/ and /lib64/"
GCC_SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)

INTERPRETER=$(${CROSS_COMPILE}readelf -a ${BUSYBOX_BINARY} | grep "program interpreter" | sed 's|.*program interpreter: \(/.*\)].*|\1|')
# Alternatively:
#   _INTERPRETER="/lib/ld-linux-aarch64.so.1"
echo "  Interpeter:"
echo "    ${INTERPRETER}"
cp ${GCC_SYSROOT}/${INTERPRETER} ${OUTDIR}/rootfs/${INTERPRETER}

SHARED_LIBS=$(${CROSS_COMPILE}readelf -a ${BUSYBOX_BINARY} | grep "Shared library" | sed 's|.*Shared library: \[\(.*\)].*|\1|')
# Alternatively:
#   _SHARED_LIBS=\
#   "libm.so.6
#   libresolv.so.2
#   libc.so.6"
echo "  Shared libraries:"
while IFS= read -r lib; do
    echo "    $lib"
    cp ${GCC_SYSROOT}/lib64/${lib} ${OUTDIR}/rootfs/lib64/
done <<< "$SHARED_LIBS"
cd ${OUTDIR}/rootfs


# TODO: Make device nodes
# Make device nodes
# mknod <name> <type> <major> <minor>
echo
echo "Populating /dev/"
cd ${OUTDIR}/rootfs
sudo mknod -m 666 dev/null c 1 3
sudo mknod -m 600 dev/console c 5 1

# TODO: Clean and build the writer utility
# Clean and build the writer utility
cd ${FINDER_APP_DIR}
make   clean
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
echo
echo "Populating /home/"
cp -r -t "${OUTDIR}/rootfs/home/" \
    conf/ \
    autorun-qemu.sh \
    finder.sh \
    finder-test.sh \
    writer
cd ${OUTDIR}/rootfs  

# TODO: Chown the root directory
sudo chown -R root:root *
echo "Copy initramfs/ into archive..."
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
# TODO: Create initramfs.cpio.gz
echo "Compressing initramfs.cpio..."
cd ${OUTDIR}
gzip -f initramfs.cpio

echo "Done"
ls -lah ./initramfs.cpio.gz