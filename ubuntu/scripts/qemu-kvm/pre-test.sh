#!/bin/sh

AVOCADO_URL="https://github.com/avocado-framework/avocado.git"
AVOCADO_VT_URL="https://github.com/joyxu/avocado-vt.git"
QEMU_URL="https://github.com/hisilicon/qemu.git"

cd ~/

#build and install qemu
echo "................................................"
echo "#qemu: get the latest qemu to build and install#"
echo "................................................"
if [ ! -e qemu.git ]; then
	wget -c http://192.168.3.100:8083/qemu.git.tar.bz2
	tar xjf qemu.git.tar.bz2
fi

cd qemu.git
git fetch && git fetch -t
BRANCH=$(git describe --abbrev=0 --tags)
echo "checkout the latest qeumu tag: "$BRANCH
git checkout -b $BRANCH
git submodule update --init dtc
./configure --target-list=aarch64-softmmu
make -j32
make install
cd ..
ln -s /usr/local/bin/qemu-system-aarch64 /usr/local/bin/qemu-kvm

#build and install avocado
echo "................................................"
echo "#avocado: get the latest avocado to build and install#"
echo "................................................"
pip install -I aexpect

mkdir -p avocado_test
cd avocado_test

if [ ! -e avocado ]; then
	wget http://192.168.3.100:8083/avocado.tar.bz2
	tar xjf avocado.tar.bz2
fi

cd avocado
git fetch && git fetch -t
make requirements
python setup.py install
cd ..

#build and install avocado-vt
echo "................................................"
echo "#avocado-vt: get the latest avocado-vt to build and install#"
echo "................................................"
if [ ! -e avocado-vt ]; then
	wget http://192.168.3.100:8083/avocado-vt.tar.bz2
	tar xjf avocado-vt.tar.bz2
fi
cd avocado-vt
git fetch && git fetch -t
BRANCH=$(git for-each-ref --sort=-committerdate refs --count=1 --format='%(refname:short)')
echo "checkout the latest avocado-vt branch: "$BRANCH
git checkout -b latest $BRANCH
git reset --hard $BRANCH
make requirements
python setup.py install

cd ../avocado
make link
rm -rf /var/lib/avocado/data/avocado-vt/backends/qemu/cfg/
avocado vt-bootstrap --vt-type qemu --vt-guest-os Ubuntu.16.04-server --vt-no-downloads
cp /usr/share/AAVMF/AAVMF_VARS.fd /var/lib/avocado/data/avocado-vt/images/ubuntu-16.04-lts-aarch64_AAVMF_VARS.fd
