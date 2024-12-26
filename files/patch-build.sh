--- build.sh.orig	2024-02-19 06:21:13 UTC
+++ build.sh
@@ -1,4 +1,4 @@
-#!/bin/bash
+#!/usr/local/bin/bash
 
 set -euo pipefail
 cd $(dirname $0)/
@@ -25,6 +25,9 @@ case $host_os in
 host_arch=$(uname -m)
 
 case $host_os in
+  FreeBSD)
+    host_os="freebsd"
+    ;;
   Linux)
     host_os="linux"
     ;;
@@ -75,6 +78,7 @@ case $target in
 done
 
 case $target in
+  freebsd-amd64 | \
   linux-i686 | \
   linux-aarch64 | \
   linux-x86_64 | \
@@ -168,8 +172,6 @@ filepicker_target=filepicker-$target$exe_extension
 
 
 filepicker_target=filepicker-$target$exe_extension
-ffmpeg_target=ffmpeg-$package_ffmpeg_build_version-$target
-ffmpeg_target_dir=ffmpeg-$target
 if [ $target_os == "win7" ]; then
   node_os="windows"
   ffmpeg_target=ffmpeg-$package_ffmpeg_build_version-windows-$target_arch
@@ -193,6 +195,10 @@ fi
 if [ $target == "linux-x86_64" ]; then
   deb_arch="amd64"
 fi
+if [ $target == "freebsd-amd64" ]; then
+  node_os="freebsd"
+  filepicker_target=filepicker-freebsd-$target_arch$exe_extension
+fi
 
 if [ $publish == 1 ]; then
   files=(
@@ -328,77 +334,50 @@ if [ ! $skip_bundling == 1 ]; then
     declare -a opts=("$dist_dir/bundled.js")
   fi
 
-  log "Bundling Node binary with code"
-  pkg "${opts[@]}" \
-    --target node$target_node-$node_os-$node_arch \
-    --output $target_dist_dir/$package_binary_name$exe_extension
+#  log "Bundling Node binary with code"
+#  npx pkg "${opts[@]}" \
+#    --target node$target_node-$node_os \
+#    --output $target_dist_dir/$package_binary_name$exe_extension
 else
   log "Skipping bundling"
 fi
 
+cp filepicker/dist/$filepicker_target $dist_dir
+
 if [[ ! -f $dist_dir/$filepicker_target ]]; then
-  log "Retrieving filepicker"
-  filepicker_url_base="https://github.com/paulrouget/static-filepicker/releases/download/"
-  filepicker_url=$filepicker_url_base/v$package_filepicker_build_version/$filepicker_target
-  wget -c $filepicker_url -O $dist_dir/$filepicker_target
-  chmod +x $dist_dir/$filepicker_target
+  log "Could not find filepicker--please ensure filepicker_$target exists in $dist_dir and try again."
+  exit 1
 fi
 
 cp $dist_dir/$filepicker_target $target_dist_dir/filepicker$exe_extension
 
-if [[ ! -d $dist_dir/$ffmpeg_target_dir ]]; then
-  log "Retrieving ffmpeg"
-  ffmpeg_url_base="https://github.com/aclap-dev/ffmpeg-static-builder/releases/download/"
-  ffmpeg_url=$ffmpeg_url_base/v$package_ffmpeg_build_version/$ffmpeg_target.tar.bz2
-  ffmpeg_tarball=$dist_dir/$ffmpeg_target.tar.bz2
-  wget --show-progress -c -O $ffmpeg_tarball $ffmpeg_url
-  (cd $dist_dir && tar -xf $ffmpeg_tarball)
-fi
-
-cp $dist_dir/$ffmpeg_target_dir/ffmpeg$exe_extension \
-  $dist_dir/$ffmpeg_target_dir/ffprobe$exe_extension \
-  $target_dist_dir/
-
 if [ ! $skip_packaging == 1 ]; then
 
   log "Packaging v$meta_version for $target"
 
   # ===============================================
-  # LINUX
+  # FREEBSD
   # ===============================================
-  if [ $target_os == "linux" ]; then
-    mkdir -p $target_dist_dir/deb/opt/$package_binary_name
-    mkdir -p $target_dist_dir/deb/DEBIAN
+  if [ $target_os == "freebsd" ]; then
+    mkdir -p $target_dist_dir
     # --------------------------------
     # Variation: No ffmpeg shipped
     # --------------------------------
     cp LICENSE.txt README.md app/node_modules/open/xdg-open \
       $target_dist_dir/filepicker \
       $target_dist_dir/$package_binary_name \
-      $target_dist_dir/deb/opt/$package_binary_name
 
-    yq ".package.deb" ./config.toml -o yaml | \
-      yq e ".package = \"${meta_id}.noffmpeg\"" |\
-      yq e ".conflicts = \"${meta_id}\"" |\
-      yq e ".description = \"${meta_description} (with system ffmpeg)\"" |\
-      yq e ".architecture = \"${deb_arch}\"" |\
-      yq e ".depends = \"ffmpeg\"" |\
-      yq e ".version = \"${meta_version}\"" > $target_dist_dir/deb/DEBIAN/control
-
     ejs -f $target_dist_dir/config.json ./assets/linux/prerm.ejs \
-      > $target_dist_dir/deb/DEBIAN/prerm
-    chmod +x $target_dist_dir/deb/DEBIAN/prerm
+      > $target_dist_dir//prerm
+    chmod +x $target_dist_dir//prerm
 
     ejs -f $target_dist_dir/config.json ./assets/linux/postinst.ejs \
-      > $target_dist_dir/deb/DEBIAN/postinst
-    chmod +x $target_dist_dir/deb/DEBIAN/postinst
+      > $target_dist_dir/postinst
+    chmod +x $target_dist_dir/postinst
 
-    log "Building noffmpeg.deb file"
-    dpkg-deb --build $target_dist_dir/deb $target_dist_dir/$out_noffmpeg_deb_file
-
     rm -rf $target_dist_dir/$package_binary_name-$meta_version
     mkdir $target_dist_dir/$package_binary_name-$meta_version
-    cp $target_dist_dir/deb/opt/$package_binary_name/* \
+    cp $target_dist_dir/$package_binary_name/* \
       $target_dist_dir/$package_binary_name-$meta_version
     log "Building .tar.bz2 file"
     tar_extra=""
@@ -407,51 +386,7 @@ if [ ! $skip_packaging == 1 ]; then
     fi
     (cd $target_dist_dir && tar -cvjS $tar_extra -f $out_noffmpeg_bz2_file $package_binary_name-$meta_version)
 
-    # --------------------------------
-    # Variation: ffmpeg binary shipped
-    # --------------------------------
-    rm -rf $target_dist_dir/deb
-    mkdir -p $target_dist_dir/deb/opt/$package_binary_name
-    mkdir -p $target_dist_dir/deb/DEBIAN
-
-    cp LICENSE.txt README.md app/node_modules/open/xdg-open \
-      $target_dist_dir/$package_binary_name \
-      $target_dist_dir/filepicker \
-      $target_dist_dir/ffmpeg \
-      $target_dist_dir/ffprobe \
-      $target_dist_dir/deb/opt/$package_binary_name
-
-    yq ".package.deb" ./config.toml -o yaml | \
-      yq e ".package = \"${meta_id}\"" |\
-      yq e ".conflicts = \"${meta_id}.noffmpeg\"" |\
-      yq e ".description = \"${meta_description} (with builtin ffmpeg.)\"" |\
-      yq e ".architecture = \"${deb_arch}\"" |\
-      yq e ".version = \"${meta_version}\"" > $target_dist_dir/deb/DEBIAN/control
-
-    ejs -f $target_dist_dir/config.json ./assets/linux/prerm.ejs \
-      > $target_dist_dir/deb/DEBIAN/prerm
-    chmod +x $target_dist_dir/deb/DEBIAN/prerm
-
-    ejs -f $target_dist_dir/config.json ./assets/linux/postinst.ejs \
-      > $target_dist_dir/deb/DEBIAN/postinst
-    chmod +x $target_dist_dir/deb/DEBIAN/postinst
-
-    log "Building .deb file"
-    dpkg-deb --build $target_dist_dir/deb $target_dist_dir/$out_deb_file
-
     rm -rf $target_dist_dir/$package_binary_name-$meta_version
-    mkdir $target_dist_dir/$package_binary_name-$meta_version
-    cp $target_dist_dir/deb/opt/$package_binary_name/* \
-      $target_dist_dir/$package_binary_name-$meta_version
-    log "Building .tar.bz2 file"
-    tar_extra=""
-    if [ $host_os == "mac" ]; then
-      tar_extra="--no-xattrs --no-mac-metadata"
-    fi
-    (cd $target_dist_dir && tar -cvjS $tar_extra -f $out_bz2_file $package_binary_name-$meta_version)
-
-    rm -rf $target_dist_dir/$package_binary_name-$meta_version
-    rm -rf $target_dist_dir/deb
   fi
 
   # ===============================================
