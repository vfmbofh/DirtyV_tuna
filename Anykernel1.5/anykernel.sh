# AnyKernel Ramdisk Mod Script 
# osm0sis @ xda-developers

ramdisk=/tmp/anykernel/ramdisk;
bin=/tmp/anykernel/tools;
split_img=/tmp/anykernel/split_img;
patch=/tmp/anykernel/patch;

cd $ramdisk;
chmod -R 755 $bin $ramdisk;
mkdir -p $split_img;

# dump boot and extract ramdisk
dd if=/dev/block/platform/omap/omap_hsmmc.0/by-name/boot of=/tmp/anykernel/boot.img;
$bin/unpackbootimg -i /tmp/anykernel/boot.img -o $split_img;
gunzip -c $split_img/boot.img-ramdisk.gz | cpio -i;

# init.rc
cp init.rc init.rc~;
if [ -z "$(grep "cpuctl cpu,timer_slack" init.rc)" ]; then
  sed -i 's#mount cgroup none /dev/cpuctl cpu#mount cgroup none /dev/cpuctl cpu,timer_slack#' init.rc;
fi;

if [ -z "$(grep "run-parts" init.rc)" ]; then
  echo -ne "\n" >> init.rc;
  cat $patch/init >> init.rc;
  echo -ne "\n" >> init.rc;
fi;  

# init.tuna.rc
if [ -z "$(grep "dvbootscript" init.tuna.rc)" ]; then
  cp init.tuna.rc init.tuna.rc~;
  echo -ne "\n" >> init.tuna.rc;
  cat $patch/init.tuna >> init.tuna.rc;
  echo -ne "\n" >> init.tuna.rc;
fi;

# init.superuser.rc
if [ -f init.superuser.rc ]; then
  cp init.superuser.rc init.superuser.rc~;
  if [ -z "$(grep "SuperSU daemonsu" init.superuser.rc)" ]; then
    sed -i 's/# su daemon/\n# Superuser su_daemon/' init.superuser.rc;
    echo "$(cat $patch/init.superuser init.superuser.rc)" > init.superuser.rc;
    echo -ne "\n" >> init.superuser.rc;
  fi;
else
  cp $patch/init.superuser.rc init.superuser.rc;
  chmod 750 init.superuser.rc;
  line=$((`grep -n "on post-fs-data" init.rc | cut -d: -f1` + 1));
  sed -i $line's#^#    import /init.superuser.rc\n\n#' init.rc;
fi;

# fstab.tuna
if [ -z "$(grep "usbdisk" fstab.tuna)" ]; then
  cp fstab.tuna fstab.tuna~;
  echo -e "# USB storage device" >> fstab.tuna;
  echo -e "/devices/platform/omap/musb-omap2430/musb-hdrc          auto                vfat      defaults                                              voldmanaged=usbdisk:auto\n\n" >> fstab.tuna;
fi;

# repack ramdisk then build and write image
find . | cpio -o -H newc | gzip > /tmp/anykernel/ramdisk-new.cpio.gz;
$bin/mkbootimg --kernel /tmp/anykernel/zImage --ramdisk /tmp/anykernel/ramdisk-new.cpio.gz --base 0x`cat /tmp/anykernel/split_img/boot.img-base` --output /tmp/anykernel/boot-new.img;
dd if=/tmp/anykernel/boot-new.img of=/dev/block/platform/omap/omap_hsmmc.0/by-name/boot;

