--- app/src/native-autoinstall.js.orig	2025-01-23 19:43:10 UTC
+++ app/src/native-autoinstall.js
@@ -159,11 +159,8 @@ async function install_uninstall(uninstall = false) {
   if (platform == "darwin") {
     let mode = GetMode();
     SetupFiles("mac", mode, uninstall);
-  } else if (platform == "linux") {
+  } else if (platform == "freebsd") {
     let mode = GetMode();
-    if (mode == "user") {
-      await PrepareFlatpak();
-    }
     SetupFiles("linux", mode, uninstall);
   } else {
     DisplayMessage("Installation from command line not supported on " + os.platform());
