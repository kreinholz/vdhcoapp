--- build.sh.orig	2024-10-04 14:48:43 UTC
+++ build.sh
@@ -1,4 +1,4 @@
-#!/bin/bash
+#!/usr/local/bin/bash
 
 set -euo pipefail
 cd $(dirname $0)/
@@ -25,8 +25,8 @@ case $host_os in
 host_arch=$(uname -m)
 
 case $host_os in
-  Linux)
-    host_os="linux"
+  FreeBSD)
+    host_os="freebsd"
     ;;
   Darwin)
     host_os="mac"
@@ -45,7 +45,7 @@ skip_notary=0
 skip_signing=0
 skip_bundling=0
 skip_notary=0
-target_node=18
+target_node=22
 
 while [[ "$#" -gt 0 ]]; do
   case $1 in
@@ -75,6 +75,7 @@ case $target in
 done
 
 case $target in
+  freebsd-%%ARCH%% | \
   linux-i686 | \
   linux-aarch64 | \
   linux-x86_64 | \
@@ -116,26 +117,12 @@ else
     error "Wrong version of Node (expected v10)"
   fi
 else
-  if [[ $(node -v) != v18.* ]]
+  if [[ $(node -v) != v22.* ]]
   then
-    error "Wrong version of Node (expected v18)"
+    error "Wrong version of Node (expected v22)"
   fi
 fi
 
-if ! [ -x "$(command -v esbuild)" ]; then
-  log "Installing esbuild"
-  npm install -g esbuild
-fi
-
-if ! [ -x "$(command -v pkg)" ]; then
-  log "Installing pkg"
-  if [ $target_node == 10 ]; then
-    npm install -g pkg@4.4.9
-  else
-    npm install -g pkg
-  fi
-fi
-
 if [ $target_node == 10 ]; then
   if [[ $(pkg -v) != 4.4.9 ]]
   then
@@ -143,11 +130,6 @@ fi
   fi
 fi
 
-if ! [ -x "$(command -v ejs)" ]; then
-  log "Installing ejs"
-  npm install -g ejs
-fi
-
 if [ ! -d "app/node_modules" ]; then
   (cd app/ ; npm install)
 fi
@@ -168,8 +150,6 @@ filepicker_target=filepicker-$target$exe_extension
 
 
 filepicker_target=filepicker-$target$exe_extension
-ffmpeg_target=ffmpeg-$package_ffmpeg_build_version-$target
-ffmpeg_target_dir=ffmpeg-$target
 if [ $target_os == "win7" ]; then
   node_os="windows"
   ffmpeg_target=ffmpeg-$package_ffmpeg_build_version-windows-$target_arch
@@ -193,6 +173,10 @@ fi
 if [ $target == "linux-x86_64" ]; then
   deb_arch="amd64"
 fi
+if [ $target == "freebsd-%%ARCH%%" ]; then
+  node_os="freebsd"
+  filepicker_target=filepicker-freebsd-$target_arch$exe_extension
+fi
 
 if [ $publish == 1 ]; then
   files=(
@@ -315,7 +299,7 @@ if [ ! $skip_bundling == 1 ]; then
       "--define:import.meta.url=_importMetaUrl")
   fi
 
-  NODE_PATH=app/src:$target_dist_dir esbuild ./app/src/main.js \
+  NODE_PATH=app/src:$target_dist_dir npx esbuild ./app/src/main.js \
     "${opts[@]}" \
     --format=cjs \
     --bundle --platform=node \
@@ -330,35 +314,21 @@ if [ ! $skip_bundling == 1 ]; then
   fi
 
   log "Bundling Node binary with code"
-  pkg "${opts[@]}" \
-    --target node$target_node-$node_os-$node_arch \
+  PKG_NODE_PATH=%%WRKDIR%%/.pkg-cache/v%%PKG_FETCH_VER%%/built-v%%PKG_NODE_VER%%-freebsd-%%NODE_ARCH%% npx pkg "${opts[@]}" \
+    --target node$target_node-$node_os \
     --output $target_dist_dir/$package_binary_name$exe_extension
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
+  log "Could not find filepicker--please ensure $filepicker_target exists in $dist_dir and try again."
+  exit 1
 fi
 
 cp $dist_dir/$filepicker_target $target_dist_dir/filepicker$exe_extension
-
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
 
 if [ ! $skip_packaging == 1 ]; then
 
