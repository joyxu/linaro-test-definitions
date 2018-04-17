#!/bin/sh

CONFIGURATION_FILE=test-qemu-ubuntu-${1}.cfg

#replace the ubuntu kernel with latest release kernel
tamper_guest()
{
    guest=$1
    if [ ! -r $guest ]; then
        echo "can not find guest image file then skip"
        exit 0
    fi

    qemu-nbd -c /dev/nbd0 $guest
    sleep 2
    mount /dev/nbd0p1 /mnt/
    mv /mnt/boot/vmlinuz-4.4.0-97-generic /mnt/boot/vmlinuz-4.4.0-97-generic.orig
    mv Image /mnt/boot/vmlinuz-4.4.0-97-generic
    umount /mnt
    sync
    qemu-nbd -d /dev/nbd0
}

parse_result()
{
	RESULT_FILE="$1"

	command -v lava-test-case
	lava_test_case="$?"

	if [ -f "${RESULT_FILE}" ]; then
	    while read -r line; do
	    	if echo "${line}" | egrep -iq "^\(.*+ (pass|fail|skip|error)+ .*+ .*"; then
		    test="$(echo "${line}" | awk '{print $2}')"
		    result="$(echo "${line}" | awk '{print $3}')"
		    [ "$result" = "ERROR" ] && result="FAIL"
		    measurement="$(echo "${line}" | awk '{print substr($4, 2)}')"
		    units="$(echo "${line}" | awk '{print substr($5,1,1)}')"

		    if [ "${lava_test_case}" -eq 0 ]; then
			lava-test-case "${test}" --result "${result}" --measurement "${measurement}" --units "${units}"
		    else
		       echo "<TEST_CASE_ID=${test} RESULT=${result} UNITS=${units} MEASUREMENT=${measurement}>"
		    fi
		fi
	    done < "${RESULT_FILE}"
	else
	    echo "WARNING: result file is missing!"
	fi
}

FILE_SERVER_URL="http://192.168.3.100:8083/"
KERNEL_IMAGE_SUFFIX="arm64-defconfig%2Bplinth-config/"
GUEST_UBUNTU_IMAGE="xenial-server-cloudimg-arm64-uefi1.img"
OUTPUT_DIR="/root/avocado/job-results/"
OUTPUT_FILE="stdout_$(date +%Y%m%d%H%M%S)"
DOWNLOAD_FILE="wget --no-clobber --progress=dot -e dotbytes=2M --no-check-certificate"
QUERY_RELEASE_KERNEL_DIR=$(lynx -dump -listonly ${FILE_SERVER_URL}"/plinth/" | grep http | grep -E release-plinth | sort -ud | tail -1 | rev | cut -d' ' -f1 | rev | sed -r 's/%2B/+/g')

#download kernel image
echo "................................................"
echo "#avocado-vt: download the latest plinth kernel image"
echo "................................................"
$($DOWNLOAD_FILE ${QUERY_RELEASE_KERNEL_DIR}${KERNEL_IMAGE_SUFFIX}"Image")

#download ubuntu rootfs image
echo "................................................"
echo "#avocado-vt: get the guest Ubuntu rootfs image#"
echo "................................................"
$($DOWNLOAD_FILE ${FILE_SERVER_URL}${GUEST_UBUNTU_IMAGE})
tamper_guest xenial-server-cloudimg-arm64-uefi1.img
rm -rf /var/lib/avocado/data/avocado-vt/images/ubuntu-16.04-lts-aarch64*
cp ${GUEST_UBUNTU_IMAGE} /var/lib/avocado/data/avocado-vt/images/ubuntu-16.04-lts-aarch64.qcow2
cp /usr/share/AAVMF/AAVMF_VARS.fd /var/lib/avocado/data/avocado-vt/images/ubuntu-16.04-lts-aarch64_AAVMF_VARS.fd

#run avocado test suite
echo "................................................"
echo "#avocado-vt: run the virtualization test cases#"
echo "................................................"
mkdir -p ${OUTPUT_DIR}
cd /var/lib/avocado/data/avocado-vt/backends/qemu/cfg
echo "avocado run --vt-type qemu --vt-guest-os Ubuntu.16.04-server.aarch64 --vt-config ./${CONFIGURATION_FILE} 2>&1 | tee -a ${OUTPUT_DIR}${OUTPUT_FILE}.log"
avocado run --vt-type qemu --vt-guest-os Ubuntu.16.04-server.aarch64 --vt-config ./${CONFIGURATION_FILE} 2>&1 | tee -a ${OUTPUT_DIR}${OUTPUT_FILE}.log

if [ $1 = "computing" ]; then
	echo "................................................"
	echo "#avocado-vt: run the kvm unit test test cases#"
	echo "................................................"
	/root/avocado_test/avocado/contrib/testsuites/run-kvm-unit-test.sh 2>&1 | tee -a ${OUTPUT_DIR}${OUTPUT_FILE}.log
fi

echo "................................................"
echo "#avocado-vt: parse the virtualization test result#"
echo "................................................"
parse_result ${OUTPUT_DIR}${OUTPUT_FILE}.log
cd "/root/avocado/job-results"
mv  ${OUTPUT_DIR}${OUTPUT_FILE}.log latest/
rm avocado-vt-result.tar.bz2
tar -hcjf avocado-vt-result.tar.bz2 ${OUTPUT_DIR}latest
