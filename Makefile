IMAGE=ceibal-tero
IMAGE_DESC=Ceibal Tero
BASE_DIR=$(shell pwd)
CUSTOM_INITRD=$(BASE_DIR)/custom-initrd
CUSTOM_INSTALL_FS=$(BASE_DIR)/custom-fs
CUSTOM=$(BASE_DIR)/custom
SOURCE_ARCH=amd64
SOURCE_ISO=ubuntu-14.04.3-server-${SOURCE_ARCH}.iso
SOURCE_URL=http://releases.ubuntu.com/14.04/$(SOURCE_ISO)
TARGET_ISO=$(BASE_DIR)/$(IMAGE).iso
TARGET_ISO_FILENAME=$(shell basename ${TARGET_ISO})
BUILD_DIR=$(BASE_DIR)/build
IMAGE_TARGET_DIR=$(BUILD_DIR)/$(IMAGE)-target
IMAGE_SOURCE_DIR=$(BUILD_DIR)/$(IMAGE)-source
IMAGE_INITRD=$(BUILD_DIR)/initrd.gz
IMAGE_SOURCE_FS=$(BUILD_DIR)/filesystem-source
IMAGE_TARGET_FS=$(BUILD_DIR)/filesystem-target
IMAGE_FS=$(BUILD_DIR)/filesystem.squashfs
IMAGE_FS_SIZE=$(BUILD_DIR)/filesystem.size
IMAGE_FS_MANIFEST=$(BUILD_DIR)/filesystem.manifest
VM_ISOS_DIR=/var/lib/isos/
VM_IMAGES_DIR=/var/lib/libvirt/images

.SUFFIXES:

all: $(TARGET_ISO)
build-initrd: $(IMAGE_INITRD)
build-filesystem: $(IMAGE_FS)
build-iso: $(TARGET_ISO)

$(IMAGE_SOURCE_FS): $(BUILD_DIR)/.source_fs.tmstamp
$(BUILD_DIR)/.source_fs.tmstamp: $(IMAGE_SOURCE_DIR)/install/filesystem.squashfs
	sudo rm -rf "${IMAGE_SOURCE_FS}"
	sudo unsquashfs -d "${IMAGE_SOURCE_FS}" "${IMAGE_SOURCE_DIR}/install/filesystem.squashfs"
	touch "$@"

$(IMAGE_FS_SIZE): $(IMAGE_SOURCE_FS) $(shell find "${CUSTOM_INSTALL_FS}" -type f)
	sudo rm -rf "${IMAGE_TARGET_FS}"
	sudo rsync -aHAX "${IMAGE_SOURCE_FS}/" "${IMAGE_TARGET_FS}/"
	sudo cp -rT "${CUSTOM_INSTALL_FS}/" "${IMAGE_TARGET_FS}/"
	sudo du -sx --block-size=1 "${IMAGE_TARGET_FS}" | cut -f1 > "${IMAGE_FS_SIZE}"
	sudo chroot "${IMAGE_TARGET_FS}" dpkg-query -W --showformat='$${Package} $${Version}\n' > "${IMAGE_FS_MANIFEST}"

$(IMAGE_FS): $(IMAGE_FS_SIZE)
	sudo mksquashfs "${IMAGE_TARGET_FS}" "${IMAGE_FS}" -b 1048576

$(IMAGE_INITRD): $(shell find "${CUSTOM_INITRD}" -type f)
	mkdir -p "${BUILD_DIR}/initrd-build"
	cd "${BUILD_DIR}/initrd-build" && \
		gzip -dc "${IMAGE_SOURCE_DIR}/install/initrd.gz" | sudo cpio -imd --no-absolute-filenames; \
		sudo cp -rT "${CUSTOM_INITRD}/" ./; \
		find . | sudo cpio --quiet -o -H newc | gzip -9 > "${IMAGE_INITRD}";

$(TARGET_ISO): $(IMAGE_TARGET_DIR) $(IMAGE_FS) $(IMAGE_INITRD) $(shell find custom -type f)
	sudo cp --no-preserve ownership,mode -rT "${CUSTOM}" "${IMAGE_TARGET_DIR}"
	#sudo cp "${IMAGE_INITRD}" "${IMAGE_TARGET_DIR}/install/initrd.gz"
	sudo cp --no-preserve ownership,mode "${IMAGE_FS_SIZE}" "${IMAGE_TARGET_DIR}/install/filesystem.size"
	sudo cp --no-preserve ownership,mode "${IMAGE_FS_MANIFEST}" "${IMAGE_TARGET_DIR}/install/filesystem.manifest"
	sudo cp --no-preserve ownership,mode "${IMAGE_FS}" "${IMAGE_TARGET_DIR}/install/filesystem.squashfs"
	cd $(IMAGE_TARGET_DIR) && find -type f -print0 | sudo xargs -0 md5sum | grep -v isolinux/boot.cat | sudo tee md5sum.txt > /dev/null
	# Build EFI bootable images if grub/efi is available.
	if [ -d ${IMAGE_TARGET_DIR}/boot/grub/efi.img ]; then \
		sudo mkisofs -U -A "CeibalTero" -V "${IMAGE_DESC}" -volset "CeibalTero" \
			-J -joliet-long -r -v -T -o "${TARGET_ISO}" \
			-b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot \
			-boot-load-size 4 -boot-info-table -eltorito-alt-boot \
			-e boot/grub/efi.img -no-emul-boot "${IMAGE_TARGET_DIR}"; \
			sudo isohybrid --uefi "${TARGET_ISO}"; \
	else \
		sudo mkisofs -U -A "CeibalTero" -V "${IMAGE_DESC}" -volset "CeibalTero" \
			-J -joliet-long -r -v -T -o "${TARGET_ISO}" \
			-b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot \
			-boot-load-size 4 -boot-info-table \
			-no-emul-boot "${IMAGE_TARGET_DIR}"; \
			sudo isohybrid "${TARGET_ISO}"; \
	fi;

$(IMAGE_SOURCE_DIR)/install/filesystem.squashfs: $(BUILD_DIR)/.source.tmstamp
$(IMAGE_SOURCE_DIR): $(BUILD_DIR)/.source.tmstamp
$(BUILD_DIR)/.source.tmstamp: $(SOURCE_ISO)
	mkdir -p "${IMAGE_SOURCE_DIR}"
	sudo mount -o loop "${SOURCE_ISO}" "${IMAGE_SOURCE_DIR}"
	touch "$@"

$(IMAGE_TARGET_DIR): $(IMAGE_SOURCE_DIR)
	mkdir -p "${IMAGE_TARGET_DIR}"
	cp -rT "${IMAGE_SOURCE_DIR}/" "${IMAGE_TARGET_DIR}/"

$(SOURCE_ISO):
	wget "${SOURCE_URL}"

vm: $(TARGET_ISO)
	-sudo virsh destroy "${IMAGE}"
	-sudo virsh undefine "${IMAGE}"
	sudo mkdir -p "${VM_IMAGES_DIR}"
	sudo mkdir -p "${VM_ISOS_DIR}"
	sudo rm -rf "${VM_IMAGES_DIR}/${IMAGE}.img"
	sudo cp  "${TARGET_ISO}" "${VM_ISOS_DIR}/${TARGET_ISO_FILENAME}"
	sudo fallocate -l 8192M "${VM_IMAGES_DIR}/${IMAGE}.img"
	sudo virt-install --ram 1024 --name "${IMAGE}" -f "${VM_IMAGES_DIR}/${IMAGE}.img" --accelerate --cdrom "${VM_ISOS_DIR}/${TARGET_ISO_FILENAME}" --os-type=linux #--graphics spice

clean:
	if mount | grep "${IMAGE_SOURCE_DIR}" 2>&1; then \
		sudo umount "${IMAGE_SOURCE_DIR}"; \
	fi
	sudo rm -rf "${BUILD_DIR}"
	sudo rm -rf "${TARGET_ISO}"
