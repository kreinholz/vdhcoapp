# Unofficial/custom FreeBSD Port of Video DownloadHelper's Companion App

Video DownloadHelper is a popular web browser add-on/extension that, well, helps download videos from the web.

https://www.downloadhelper.net/

Certain features are unavailable directly from the browser add-on:

- file writing API
- launching default video player application on a data file
- converting videos

These features may be added to the browser add-on by installing the Companion App, vdhcoapp.

Executable binary installers are available for Windows, Mac, and Linux. Source code is GPL-2.0 and available here:

https://github.com/aclap-dev/vdhcoapp

I made an unofficial/custom FreeBSD Port that builds and installs the Companion App, which can then be registered with the browser add-on.

Note: this was primarily for educational purposes--to see if I could make it work--and not necessarily the most practical project. While the filepicker component of vdhcoapp is written in Rust, vdhcoapp is a Node.js application compiled into a single executable application. That means building a patched version of node on FreeBSD, then bundling it with the Node.js application and compiling it all into a single binary file. If that sounds like a good idea, keep in mind that node is not small, and constitutes a lot of overhead for what would otherwise be a small, lightweight application.

The Linux version of vdhcoapp works quite well on FreeBSD thanks to the Linuxulator. However, this Port makes it possible to build a FreeBSD native version of vdhcoapp and its filepicker component. The 'install' and 'uninstall' scripts bundled into the vdhcoapp binary work as well, so there is no need for the Linux version of vdhcoapp at all.

There are still some problems to solve with this custom Port: I based a lot of my work on the security/bitwarden-cli port as well as the port maintainer, tagattie's, blog post here:

https://blog.c6h12o6.org/post/freebsd-electron-app/

While vdhcoapp is NOT an Electron app, it does share certain features in common with one, which made the above invaluable in figuring out how to compile the bundled Node.js sources into a single executable application.

I've tested building for amd64 and i386. It should also build on both 32 and 64-bit ARM, as well as 64-bit PPC, but I haven't tested building for those platforms.
