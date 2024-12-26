--- app/src/native-autoinstall.js.orig	2024-12-26 18:09:51 UTC
+++ app/src/native-autoinstall.js
@@ -159,7 +159,7 @@ async function install_uninstall(uninstall = false) {
   if (platform == "darwin") {
     let mode = GetMode();
     SetupFiles("mac", mode, uninstall);
-  } else if (platform == "linux") {
+  } else if (platform == "freebsd") {
     let mode = GetMode();
     if (mode == "user") {
       await PrepareFlatpak();
