# ceibal-image-trusty

Crea imagenes para equipos Ceibal basadas en Ubuntu 14.04.3.

## Dependencias

Para construir la imagen:
* make
* wget (para obtener el .iso base)
* squashfs-tools (`mksquashfs`, `unsquashfs`)
* genisoimage (`mkisofs`)
* syslinux (`isohybrid`)
* rsync

Para probar la imagen dentro de una VM:
* util-linux
* virt-install
* libvirt-client

## Crear imagen

Para crear una imagen ejecutar:

    make

La imagen sera creada como `ceibal-tero.iso`. Puede copiarse a un pendrive con:

    dd if=ceibal-tero.iso of=</dev/USBDRIVE>

Para probar la imagen dentro de una maquina virtual, ejecutar:

    make vm

## Proceso de creacion

Para crear la imagen se realizan los siguientes pasos:

1. Baja el .iso original (ubuntu-14.04.3-server-amd64.iso)
2. Monta el .iso, y se copia el contenido a otro directorio.
3. Abre el install/filesystem.sqashfs de la imagen original y se sobreescribe su contenido con los archivos de `custom-fs/`.
4. Abre el install/initrd.gz de la imagen original y se sobreescribe su contenido con los archivos de `custom-initrd/`.
5. Sobreescribe el contenido de la imagen con los archivos de `custom/` y se copian los nuevos `filesystem.squashfs`, `filesystem.size`, `filesystem.manifest` e `initrd.gz`.
6. Calcula el md5 para cada archivo y remplaza el md5sum.txt

La instalacion de la imagen esta automaizada de acuerdo a `custom/ceibal.seed`, `custom/ceibal.cfg`.
