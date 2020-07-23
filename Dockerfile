FROM alpine:3.12
LABEL maintainer "Val Packett <val@packett.cool>"

# Install pkg on Linux to download dependencies into the FreeBSD root
RUN apk add --no-cache curl clang gcc pkgconf make autoconf automake libtool musl-dev xz-dev bzip2-dev zlib-dev zstd-dev lz4-dev expat-dev acl-dev fts-dev libbsd-dev openssl-dev libarchive-dev libarchive-tools
RUN mkdir /pkg && \
	curl -L https://github.com/freebsd/pkg/archive/c98721ebb5bf1d1f4425dfa418764864d824b5b0.tar.gz | \
		bsdtar -xf - -C /pkg && \
	cd /pkg/pkg-* && \
	ln -sf clang /usr/bin/cc && cc --version && \
	export CFLAGS="-Wno-cpp -Wno-switch -D__BEGIN_DECLS='' -D__END_DECLS='' -DDEFFILEMODE='S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP|S_IROTH|S_IWOTH' -D__GLIBC__" && \
	export LDFLAGS="-lfts" && \
	./configure --with-libarchive.pc && \
	touch /usr/include/sys/unistd.h && \
	touch /usr/include/sys/sysctl.h && \
	sed -i'' -e '/#include "pkg.h"/i#include <bsd/stdlib.h>' libpkg/pkg_jobs_conflicts.c && \
	sed -i'' -e '/#include.*cdefs.h>/i#include <fcntl.h>' libpkg/flags.c && \
	sed -i'' -e '/#include <stdio.h>/i#include <stdarg.h>' libpkg/xmalloc.h && \
	make -j4 && \
	mkdir -p /usr/local/etc && \
	make -j4 install && \
	cd / && \
	rm -rf /pkg /usr/local/sbin/pkg2ng && \
	unset CFLAGS LDFLAGS

# Download FreeBSD base, extract libs/includes and pkg keys
RUN mkdir /freebsd && \
	curl https://download.freebsd.org/ftp/releases/amd64/11.4-RELEASE/base.txz | \
		bsdtar -xf - -C /freebsd ./lib ./usr/lib ./usr/libdata ./usr/include ./usr/share/keys ./etc

# Configure pkg (usage: pkg -r /freebsd install ...)
RUN mkdir -p /freebsd/usr/local/etc && \
	echo 'ABI = "FreeBSD:11:amd64"; REPOS_DIR = ["/freebsd/etc/pkg"]; REPO_AUTOUPDATE = NO; RUN_SCRIPTS = NO;' > /freebsd/usr/local/etc/pkg.conf
RUN ln -s /freebsd/usr/share/keys /usr/share/keys
RUN pkg -r /freebsd update

# Make clang symlinks to cross-compile
ADD clang-links.sh /tmp/clang-links.sh
RUN bash /tmp/clang-links.sh && \
	rm /tmp/clang-links.sh && \
	ln -s libstdc++.so.6 /usr/lib/libstdc++.so
# clang++ should be able to find stdc++ (necessary for meson checks even without building any c++ code)

# Configure pkg-config
ENV PKG_CONFIG_LIBDIR /freebsd/usr/libdata/pkgconfig:/freebsd/usr/local/libdata/pkgconfig
ENV PKG_CONFIG_SYSROOT_DIR /freebsd

# Configure meson (usage: meson build --cross-file freebsd)
# note: meson is not installed here, do it in your dockerfile
ADD meson.cross /usr/local/share/meson/cross/freebsd
