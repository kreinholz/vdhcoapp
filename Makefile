PORTNAME=	vdhcoapp
DISTVERSIONPREFIX=	v
DISTVERSION=	2.0.19
CATEGORIES=	www
MASTER_SITES=	https://github.com/aclap-dev/vdhcoapp/ \
		https://nodejs.org/dist/v${PKG_NODE_VER}/:node
DISTFILES=	node-v${PKG_NODE_VER}${EXTRACT_SUFX}:node \
		${PREFETCH_FILE}:prefetch

PREFETCH_FILE=	vdhcoapp-${DISTVERSION}-node_modules.tgz
#PREFETCH_TIMESTAMP=	1735144817

MAINTAINER=	kreinholz@gmail.com
COMMENT=	Companion Application for Video DownloadHelper browser add-on
WWW=		https://www.downloadhelper.net

LICENSE=	GPLv2

BUILD_DEPENDS=	yq:textproc/go-yq \
		bash:shells/bash \
		cargo:lang/rust \
		pkg-config:devel/pkgconf \
		npm${NODEJS_SUFFIX}>0:www/npm${NODEJS_SUFFIX}

RUN_DEPENDS=	xdg-open:devel/xdg-utils

LIB_DEPENDS=	libuv.so:devel/libuv \
		libbrotlidec.so:archivers/brotli \
		libbrotlienc.so:archivers/brotli \
		libcares.so:dns/c-ares \
		libnghttp2.so:www/libnghttp2 \
		libgtk-3.so:x11-toolkits/gtk30 \
		libglib-2.0.so:devel/glib20

USES=		nodejs:18,build pkgconfig compiler:c++11-lib gmake localbase python:build shebangfix

USE_GITHUB=	yes
GH_ACCOUNT=	aclap-dev
GH_TUPLE?=	paulrouget:static-filepicker:v1.0.1:dist/filepicker

BUILD_WRKSRC=	${WRKSRC}/app

PORTDOCS=	README.md

OPTIONS_DEFINE=	DOCS

PKG_NODE_VER=	18.20.4
PKG_FETCH_VER=	3.5
PKG_NODE_CONFIGURE_ARGS=--shared-brotli \
			--shared-cares \
			--shared-libuv \
			--shared-nghttp2 \
			--shared-zlib
NODE_ARCH=	${ARCH:S/aarch64/arm64/:S/amd64/x64/:S/i386/ia32/}

pre-fetch:
	# Only create the PREFETCH_FILE if not found
	if [ -f ${DISTDIR}/${PREFETCH_FILE} ]; then \
		${MKDIR} ${WRKDIR}/node-modules-cache; \
		${CP} -R ${FILESDIR}/packagejsons/* ${WRKDIR}/node-modules-cache; \
		cd ${WRKDIR}/node-modules-cache && \
		${SETENV} HOME=${WRKDIR} \
			npm ci --ignore-scripts --no-progress --no-audit --no-fund; \
		${FIND} ${WRKDIR}/node-modules-cache -depth 1 -print | \
			${GREP} -v node_modules | ${XARGS} ${RM} -r; \
		${FIND} ${WRKDIR}/node-modules-cache -type d -exec ${CHMOD} 755 {} ';'; \
		cd ${WRKDIR}/node-modules-cache && \
		${MTREE_CMD} -cbnSp node_modules | ${MTREE_CMD} -C | ${SED} \
			-e 's:time=[0-9.]*:time=${PREFETCH_TIMESTAMP}.000000000:' \
			-e 's:\([gu]id\)=[0-9]*:\1=0:g' \
			-e 's:flags=.*:flags=none:' \
			-e 's:^\.:./node_modules:' > node-modules-cache.mtree; \
		${TAR} -cz --options 'gzip:!timestamp' \
			-f ${DISTDIR}/${PREFETCH_FILE} \
			@node-modules-cache.mtree; \
		${RM} -r ${WRKDIR}; \
	fi

post-extract:
	${MV} ${WRKDIR}/node_modules ${WRKSRC}

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
	@${REINPLACE_CMD} -e 's|%%ARCH%%|${ARCH}|' \
		${WRKSRC}/filepicker/build.sh
	@${REINPLACE_CMD} -e 's|amd64-|x86_64-|' \
		${WRKSRC}/filepicker/build.sh

pre-build:
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
	# don't strip executable since it causes error
	${INSTALL_KLD} ${WRKSRC}/dist/freebsd/${ARCH}/vdhcoapp ${STAGEDIR}${PREFIX}/bin
	${INSTALL_KLD} ${WRKSRC}/dist/freebsd/${ARCH}/filepicker ${STAGEDIR}${PREFIX}/bin

do-install-DOCS-on:
	@${MKDIR} ${STAGEDIR}${DOCSDIR}
	${INSTALL_MAN} ${PORTDOCS:S|^|${WRKSRC}/|} ${STAGEDIR}${DOCSDIR}

do-test:
	cd ${BUILD_WRKSRC} && ${SETENV} ${TEST_ENV} npm run test

.include <bsd.port.mk>
