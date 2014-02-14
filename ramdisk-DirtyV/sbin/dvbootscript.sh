#!/system/bin/sh
# portions from franciscofranco, boype & osm0sis

# custom busybox installation shortcut
bb=/sbin/bb/busybox;

# disable sysctl.conf to prevent ROM interference with tunables
$bb mount -o rw,remount /system;
$bb [ -e /system/etc/sysctl.conf ] && $bb mv /system/etc/sysctl.conf /system/etc/sysctl.conf.dvbak;

# disable the PowerHAL since there is now a kernel-side touch boost implemented
$bb [ -e /system/lib/hw/power.tuna.so.dvbak ] || $bb cp /system/lib/hw/power.tuna.so /system/lib/hw/power.tuna.so.dvbak;
$bb [ -e /system/lib/hw/power.tuna.so ] && $bb rm /system/lib/hw/power.tuna.so;

# create and set permissions for /system/etc/init.d if it doesn't already exist
if [ ! -e /system/etc/init.d ]; then
  $bb mkdir /system/etc/init.d;
  $bb chown -R root.root /system/etc/init.d;
  $bb chmod -R 755 /system/etc/init.d;
fi;
$bb mount -o ro,remount /system;

# fix governor permissions on older underlying ramdisks
governor=reset;
while sleep 1; do
  current=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`;
  if [ $governor != $current ]; then
    governor=$current;
    for i in /sys/devices/system/cpu/cpufreq/*; do
      $bb chmod 666 $i/*;
    done;
  fi;
done&

# disable debugging
echo "0" > /sys/module/wakelock/parameters/debug_mask;
echo "0" > /sys/module/userwakelock/parameters/debug_mask;
echo "0" > /sys/module/earlysuspend/parameters/debug_mask;
echo "0" > /sys/module/alarm/parameters/debug_mask;
echo "0" > /sys/module/alarm_dev/parameters/debug_mask;
echo "0" > /sys/module/binder/parameters/debug_mask;

# timer_slack
echo 100000000 > /dev/cpuctl/apps/bg_non_interactive/timer_slack.min_slack_ns;

# wait for systemui and increase its priority
while sleep 1; do
  if [ `$bb pidof com.android.systemui` ]; then
    systemui=`$bb pidof com.android.systemui`;
    $bb renice -18 $systemui;
    $bb echo -17 > /proc/$systemui/oom_adj;
    $bb chmod 100 /proc/$systemui/oom_adj;
    exit;
  fi;
done&

# lmk whitelist for common launchers and increase launcher priority
list="com.android.launcher com.google.android.googlequicksearchbox org.adw.launcher org.adwfreak.launcher net.alamoapps.launcher com.anddoes.launcher com.android.lmt com.chrislacy.actionlauncher.pro com.cyanogenmod.trebuchet com.gau.go.launcherex com.gtp.nextlauncher com.miui.mihome2 com.mobint.hololauncher com.mobint.hololauncher.hd com.qihoo360.launcher com.teslacoilsw.launcher com.tsf.shell org.zeam";
while sleep 60; do
  for class in $list; do
    if [ `$bb pgrep $class | head -n 1` ]; then
      launcher=`$bb pgrep $class`;
      $bb echo -17 > /proc/$launcher/oom_adj;
      $bb chmod 100 /proc/$launcher/oom_adj;
      $bb renice -18 $launcher;
    fi;
  done;
  exit;
done&

