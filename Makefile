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

USE_GNOME+=	gtk30 glib20

LIB_DEPENDS=	libuv.so:devel/libuv \
		libbrotlidec.so:archivers/brotli \
		libbrotlienc.so:archivers/brotli \
		libcares.so:dns/c-ares \
		libnghttp2.so:www/libnghttp2

USES=		nodejs:18,build pkgconfig compiler:c++11-lib gmake localbase python:build shebangfix gnome

USE_GITHUB=	yes
GH_ACCOUNT=	aclap-dev
GH_TUPLE?=	paulrouget:static-filepicker:v1.0.1:dist/filepicker

BUILD_WRKSRC=	${WRKSRC}/app/

PLIST_FILES=	dist/vdhcoapp \
		dist/filepicker

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

do-build:
	# Build filepicker
	cd ${WRKSRC}/filepicker && ./build.sh
	# Build vdhcoapp
	cd ${WRKSRC} && ./build.sh --skip-packaging --skip-signing --skip-notary --target freebsd-${ARCH}
	# Compile vhdcoapp into a single executable application
#	cd ${WRKSRC} && ${SETENV} ${MAKE_ENV} PKG_NODE_PATH=${WRKDIR}/.pkg-cache/v${PKG_FETCH_VER}/built-v${PKG_NODE_VER}-freebsd-${NODE_ARCH} \
#		npx pkg --format=cjs --bundle --platform=node --tree-shaking=true --alias:electron=electron2 --target node${NODEJS_VERSION}-freebsd-${NODE_ARCH} --output ./dist/vdhcoapp ./dist/bundled.js

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
