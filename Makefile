PORTNAME=	vdhcoapp
DISTVERSIONPREFIX=	v
DISTVERSION=	2.0.19
CATEGORIES=	www
MASTER_SITES=	https://github.com/aclap-dev/vdhcoapp/ \
		https://nodejs.org/dist/v${PKG_NODE_VER}/:node \
		https://github.com/kreinholz/vdhcoapp/releases/download/prefetch/:prefetch
DISTFILES=	node-v${PKG_NODE_VER}${EXTRACT_SUFX}:node \
		vdhcoapp-${DISTVERSION}-node_modules.tar.gz:prefetch

MAINTAINER=	kreinholz@gmail.com
COMMENT=	Companion Application for Video DownloadHelper browser add-on
WWW=		https://www.downloadhelper.net

LICENSE=	GPLv2

ONLY_FOR_ARCHS=	aarch64 amd64 armv6 armv7 i386 powerpc64 powerpc64le
ONLY_FOR_ARCHS_REASON=	supported build targets for www/node18

USES=		nodejs:18,build cargo pkgconfig compiler:c++11-lib gmake localbase python:build shebangfix

FETCH_DEPENDS=	npm:www/npm${NODEJS_SUFFIX}
BUILD_DEPENDS=	yq:textproc/go-yq \
		bash:shells/bash \
		pkg-config:devel/pkgconf \
		npm:www/npm${NODEJS_SUFFIX}
LIB_DEPENDS=	libgtk-3.so:x11-toolkits/gtk30 \
		libglib-2.0.so:devel/glib20
RUN_DEPENDS=	xdg-open:devel/xdg-utils \
		ffmpeg:multimedia/ffmpeg
TEST_DEPENDS=	npm:www/npm${NODEJS_SUFFIX}

USE_GITHUB=	yes
GH_ACCOUNT=	aclap-dev
GH_TUPLE?=	paulrouget:static-filepicker:v1.0.1:dist/filepicker

BUILD_WRKSRC=	${WRKSRC}/app

PORTDOCS=	README.md

OPTIONS_DEFINE=	DOCS

PKG_NODE_VER=	18.20.4
PKG_FETCH_VER=	3.5
PKG_NODE_CONFIGURE_ARGS=--without-npm \
			--without-corepack \
			--without-inspector \
			--without-intl \
			--without-dtrace
NODE_ARCH=	${ARCH:S/aarch64/arm64/:S/amd64/x64/:S/i386/ia32/}

post-extract:
#	${CP} -R ${FILESDIR}/packagejsons/* ${WRKSRC}
#	cd ${WRKSRC} && npm install
	${MV} ${WRKDIR}/node_modules ${WRKSRC}
	${CP} ${FILESDIR}/packagejsons/app/package-lock.json ${BUILD_WRKSRC}

post-patch:
	# apply FreeBSD patches for node
	for p in ${PATCHDIR}/node/patch-*;do \
		${PATCH} -s -p0 -d ${WRKDIR}/node-v${PKG_NODE_VER} < $${p}; \
	done
	# apply node patch from pkg-fetch
	${PATCH} -s -p1 -d ${WRKDIR}/node-v${PKG_NODE_VER} < \
		${WRKSRC}/node_modules/@yao-pkg/pkg-fetch/patches/node.v${PKG_NODE_VER}.cpp.patch
	# Apply substitutions to avoid hardcoding architecture in build scripts
	@${REINPLACE_CMD} -e 's|%%ARCH%%|${ARCH}|' \
		${WRKSRC}/build.sh
	@${REINPLACE_CMD} -e 's|%%NODE_ARCH%%|${NODE_ARCH}|' \
		${WRKSRC}/build.sh
	@${REINPLACE_CMD} -e 's|%%PKG_FETCH_VER%%|${PKG_FETCH_VER}|' \
		${WRKSRC}/build.sh
	@${REINPLACE_CMD} -e 's|%%PKG_NODE_VER%%|${PKG_NODE_VER}|' \
		${WRKSRC}/build.sh
	@${REINPLACE_CMD} -e 's|%%WRKDIR%%|${WRKDIR}|' \
		${WRKSRC}/build.sh
	@${REINPLACE_CMD} -e 's/%%ARCH%%/${ARCH}/g' \
		${WRKSRC}/filepicker/build.sh
	@${REINPLACE_CMD} -e 's|amd64-|x86_64-|' \
		${WRKSRC}/filepicker/build.sh

pre-build:
	# Uncomment the following 2 lines, then comment out all 7 lines under #build patched node for @yao-pkg to do rapid testing (requires placing a prebuild patched node binary in the files/ directory):
#	${MKDIR} ${WRKDIR}/.pkg-cache/v${PKG_FETCH_VER}
#	${CP} ${FILESDIR}/built-v18.20.4-freebsd-x64 ${WRKDIR}/.pkg-cache/v${PKG_FETCH_VER}/
	# build patched node for @yao-pkg (longest part of build)
	cd ${WRKDIR}/node-v${PKG_NODE_VER} && \
		${SETENV} ${CONFIGURE_ENV} CC=${CC} CXX=${CXX} ./configure ${PKG_NODE_CONFIGURE_ARGS} && \
		${SETENV} ${MAKE_ENV} ${MAKE_CMD} -j ${MAKE_JOBS_NUMBER}
	${MKDIR} ${WRKDIR}/.pkg-cache/v${PKG_FETCH_VER}
	${MV} ${WRKDIR}/node-v${PKG_NODE_VER}/out/Release/node \
		${WRKDIR}/.pkg-cache/v${PKG_FETCH_VER}/built-v${PKG_NODE_VER}-freebsd-${NODE_ARCH}
	${STRIP_CMD} ${WRKDIR}/.pkg-cache/v${PKG_FETCH_VER}/built-v${PKG_NODE_VER}-freebsd-${NODE_ARCH}
	# rebuild node modules against patched node
	cd ${BUILD_WRKSRC} && ${SETENV} ${MAKE_ENV} ELECTRON_SKIP_BINARY_DOWNLOAD=1 \
		npm rebuild --nodedir=${WRKDIR}/node-v${PKG_NODE_VER} --verbose

do-build:
	# Build filepicker
	cd ${WRKSRC}/filepicker && ./build.sh
	# Build vdhcoapp and compile into a single executable application
	cd ${WRKSRC} && ./build.sh --skip-packaging --skip-signing --skip-notary --target freebsd-${ARCH}

do-install:
	# don't strip vdhcoapp executable since it causes error
	${INSTALL_KLD} ${WRKSRC}/dist/freebsd/${ARCH}/vdhcoapp ${STAGEDIR}${PREFIX}/bin
	${INSTALL_KLD} ${WRKSRC}/dist/freebsd/${ARCH}/filepicker ${STAGEDIR}${PREFIX}/bin
	${STRIP_CMD} ${STAGEDIR}${PREFIX}/bin/filepicker

do-install-DOCS-on:
	@${MKDIR} ${STAGEDIR}${DOCSDIR}
	${INSTALL_MAN} ${PORTDOCS:S|^|${WRKSRC}/|} ${STAGEDIR}${DOCSDIR}

do-test:
	cd ${BUILD_WRKSRC} && ${SETENV} ${TEST_ENV} npm run test

regenerate-node_modules-distfile: patch
	cd ${WRKSRC} && \
	${RM} -r node_modules && \
	${MAKE_ENV} npm install --prefix ${WRKSRC} && \
	${TAR} -czf ${DISTDIR}/vdhcoapp-${DISTVERSION}-node_modules.tar.gz node_modules && \
	${ECHO} "Please upload the file ${DISTDIR}/vdhcoapp-${DISTVERSION}-node_modules.tar.gz"
	# To update vdhcoapp-${DISTVERSION}-node_modules.tar.gz:
	# 1. Comment out the second (:prefetch) DISTFILES line and remove the trailing \ from the first DISTFILES line
	# 2. Comment out the third post-extract line and uncomment the first two post-extract lines
	# 3. Run 'sudo make makesum regenerate-node_modules-distfile clean'
	# 4. Upload the archive
	# 5. Reverse the changes made in steps 1 and 2 above
	# 6. Run 'sudo make makesum' to update distinfo
	# Based on fox's www/opengist methods and instructions

.include <bsd.port.mk>
