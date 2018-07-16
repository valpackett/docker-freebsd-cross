FROM alpine:3.8
LABEL maintainer "Val Packett <val@packett.cool>"

# Install pkg on Linux to download dependencies into the FreeBSD root
RUN apk add --no-cache curl gcc pkgconf make autoconf automake libtool musl-dev xz-dev bzip2-dev zlib-dev fts-dev libbsd-dev openssl-dev libarchive-dev libarchive-tools
RUN mkdir /pkg && \
	curl -L https://github.com/freebsd/pkg/archive/1.10.5.tar.gz | \
		bsdtar -xf - -C /pkg && \
	cd /pkg/pkg-* && \
	./autogen.sh && \
	CFLAGS="-D__BEGIN_DECLS='' -D__END_DECLS='' -DALLPERMS='S_ISUID|S_ISGID|S_ISVTX|S_IRWXU|S_IRWXG|S_IRWXO' -Droundup2='roundup'" \
		LDFLAGS="-lfts" ./configure && \
	touch /usr/include/sys/unistd.h && \
	touch /usr/include/sys/sysctl.h && \
	make -j4 install && \
	cd / && \
	rm -rf /pkg /usr/local/sbin/pkg2ng

# Download FreeBSD base, extract libs/includes and pkg keys
RUN mkdir /freebsd && \
	curl https://download.freebsd.org/ftp/releases/amd64/11.2-RELEASE/base.txz | \
		bsdtar -xf - -C /freebsd ./lib ./usr/lib ./usr/libdata ./usr/include ./usr/share/keys ./etc

# Configure pkg (usage: pkg -r /freebsd install ...)
RUN mkdir -p /freebsd/usr/local/etc && \
	echo 'ABI = "FreeBSD:11:amd64"; REPOS_DIR = ["/freebsd/etc/pkg"]; REPO_AUTOUPDATE = NO; RUN_SCRIPTS = NO;' > /freebsd/usr/local/etc/pkg.conf
RUN ln -s /freebsd/usr/share/keys /usr/share/keys
RUN pkg -r /freebsd update

# Install clang to cross-compile
RUN apk add --no-cache clang
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
