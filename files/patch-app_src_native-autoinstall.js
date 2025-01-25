--- app/src/native-autoinstall.js.orig	2025-01-24 16:16:23 UTC
+++ app/src/native-autoinstall.js
@@ -116,11 +116,6 @@ async function SetupFiles(platform, mode, uninstall) {
       try {
         console.log(`Writing ${op.path}`);
         let dir = path.dirname(op.path);
-        try {
-          await fs.mkdir(dir, { recursive: true });
-        } catch (_) {
-          // With node 10, this fails if directory exists.
-        }
         const data = new Uint8Array(Buffer.from(op.content));
         await fs.writeFile(op.path, data);
       } catch (err) {
@@ -159,11 +154,8 @@ async function install_uninstall(uninstall = false) {
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
