# -*- mode: makefile -*-
CACHEROOT := $(HOME)/CACHE
TMPDIR := $(shell dirname $(shell mktemp -u))
NPROCS := $(shell nproc)
GNUPGHOME := $(shell mktemp --tmpdir -u -d gnupg.XXXXXXXXX)
GPG := GNUPGHOME=$(GNUPGHOME) gpg --batch --no -v

include toolchain.mk
include libz.mk
include libpcre.mk
include libcrypto.mk

SHADOWSOCKS_LIBEV_VERSION := 2.5.6
SHADOWSOCKS_LIBEV_TARBALL = $(CACHEROOT)/shadowsocks-libev-$(SHADOWSOCKS_LIBEV_VERSION).tar.gz
SHADOWSOCKS_LIBEV_SOURCE := $(shell mktemp -u -d --tmpdir shadowsocks-libev.XXXXXXXXXX)
SHADOWSOCKS_LIBEV_PATCHES := $(wildcard $(PWD)/patch/*.patch)
SHADOWSOCKS_LIBEV_TARGET_DIR := $(HOME)
SHADOWSOCKS_LIBEV := shadowsocks-libev-$(SHADOWSOCKS_LIBEV_VERSION)-$(TOOLCHAIN)-$(CRYPTO_LIBRARY)
SHADOWSOCKS_LIBEV_INSTALL := $(SHADOWSOCKS_LIBEV_TARGET_DIR)/$(SHADOWSOCKS_LIBEV)
SHADOWSOCKS_LIBEV_PACKAGE := $(SHADOWSOCKS_LIBEV_INSTALL).tar.gz
SHADOWSOCKS_LIBEV_CHECKSUM := $(SHADOWSOCKS_LIBEV_INSTALL).sha256sum
SHADOWSOCKS_LIBEV_CHECKSUM_SIG := $(SHADOWSOCKS_LIBEV_INSTALL).sha256sum.sig


package: $(SHADOWSOCKS_LIBEV_PACKAGE) $(SHADOWSOCKS_LIBEV_CHECKSUM) $(SHADOWSOCKS_LIBEV_CHECKSUM_SIG)

compile: $(SHADOWSOCKS_LIBEV_INSTALL)

$(SHADOWSOCKS_LIBEV_TARBALL):
	wget --continue -O "$(SHADOWSOCKS_LIBEV_TARBALL).wget" "https://github.com/shadowsocks/shadowsocks-libev/archive/v$(SHADOWSOCKS_LIBEV_VERSION).tar.gz"
	mv "$(SHADOWSOCKS_LIBEV_TARBALL).wget" "$(SHADOWSOCKS_LIBEV_TARBALL)"

$(SHADOWSOCKS_LIBEV_INSTALL): $(SHADOWSOCKS_LIBEV_TARBALL) $(TOOLCHAIN_INSTALL) $(ZLIB_INSTALL) $(PCRE_INSTALL) $(LIBCRYPTO_INSTALL)
	mkdir -p "$(SHADOWSOCKS_LIBEV_SOURCE)"
	tar zxf "$(SHADOWSOCKS_LIBEV_TARBALL)" --strip-components 1 -C "$(SHADOWSOCKS_LIBEV_SOURCE)"
	(cd "$(SHADOWSOCKS_LIBEV_SOURCE)" && $(foreach patchfile,$(SHADOWSOCKS_LIBEV_PATCHES),patch -p1 < $(patchfile)))
	(\
cd "$(SHADOWSOCKS_LIBEV_SOURCE)" && \
$(MKFLAGS) $(MKENV) ./configure --host=$(HOST_COMPILER) --prefix=$(SHADOWSOCKS_LIBEV_INSTALL) \
--disable-ssp --disable-dependency-tracking --disable-shared --enable-static --disable-documentation \
--with-pcre=$(PCRE_INSTALL) --with-zlib=$(ZLIB_INSTALL) \
--with-crypto-library=$(CRYPTO_LIBRARY) --with-$(CRYPTO_LIBRARY)=$(LIBCRYPTO_INSTALL) &&\
$(MKFLAGS) make -j $(NPROCS) && make install \
)
	(cd "$(TMPDIR)" && rm -rf shadowsocks-libev.*)

$(SHADOWSOCKS_LIBEV_PACKAGE): $(SHADOWSOCKS_LIBEV_INSTALL)
	(\
cd "$(SHADOWSOCKS_LIBEV_TARGET_DIR)" && \
tar zcvf "$(SHADOWSOCKS_LIBEV_PACKAGE).progress" "$(SHADOWSOCKS_LIBEV)" && \
mv "$(SHADOWSOCKS_LIBEV_PACKAGE).progress" "$(SHADOWSOCKS_LIBEV_PACKAGE)" \
)

$(SHADOWSOCKS_LIBEV_CHECKSUM): $(SHADOWSOCKS_LIBEV_PACKAGE) $(SHADOWSOCKS_LIBEV_INSTALL)
	(\
cd "$(SHADOWSOCKS_LIBEV_TARGET_DIR)" && \
sha256sum -b `basename $(SHADOWSOCKS_LIBEV_PACKAGE)` `find $(SHADOWSOCKS_LIBEV) -type f` > "$(SHADOWSOCKS_LIBEV_CHECKSUM).progress" && \
mv "$(SHADOWSOCKS_LIBEV_CHECKSUM).progress" "$(SHADOWSOCKS_LIBEV_CHECKSUM)" \
)

$(SHADOWSOCKS_LIBEV_CHECKSUM_SIG): $(SHADOWSOCKS_LIBEV_CHECKSUM)
	mkdir -p "$(GNUPGHOME)"
	chmod 700 "$(GNUPGHOME)"
	$(GPG) --import ./.priv/F84FC08D.key
	$(GPG) --default-key F84FC08D -a --textmode -o $(SHADOWSOCKS_LIBEV_CHECKSUM_SIG) --sign $(SHADOWSOCKS_LIBEV_CHECKSUM)
	cat "$(SHADOWSOCKS_LIBEV_CHECKSUM_SIG)"
	(cd "$(TMPDIR)" && rm -rf gnupg.*)

.PHONY: package compile
