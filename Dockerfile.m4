m4_changequote([[, ]])

##################################################
## "build" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/debian:sid-slim]], [[FROM docker.io/debian:sid-slim]]) AS build
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectorm/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		bison \
		build-essential \
		ca-certificates \
		cmake \
		flex \
		git \
		libacl1-dev \
		libblkid-dev \
		libcap-dev \
		libjemalloc-dev \
		liburcu-dev \
		ninja-build \
		pkg-config \
		uuid-dev \
	&& rm -rf /var/lib/apt/lists/*

ARG NFS_GANESHA_TREEISH=V5.7
ARG NFS_GANESHA_REMOTE=https://github.com/nfs-ganesha/nfs-ganesha.git
RUN mkdir /tmp/nfs-ganesha/
WORKDIR /tmp/nfs-ganesha/
RUN git clone "${NFS_GANESHA_REMOTE:?}" ./
RUN git checkout "${NFS_GANESHA_TREEISH:?}"
RUN git submodule update --init --recursive
# Fixes https://bugs.gentoo.org/902995
RUN git -C ./src/libntirpc/ cherry-pick -n 1f9bb775d02b8b894f12d8408e35275e329b2da6
RUN cmake -G Ninja -S ./src/ -B ./build/ \
		-D CMAKE_BUILD_TYPE=Release \
		-D CMAKE_INSTALL_PREFIX=/usr/local \
		-D CMAKE_INSTALL_BINDIR=/usr/local/bin \
		-D CMAKE_INSTALL_LIBDIR=/usr/local/lib \
		-D CMAKE_INSTALL_INCLUDEDIR=/usr/local/include \
		-D SYSCONFDIR=/etc \
		-D SYSSTATEDIR=/var \
		-D RUNTIMEDIR=/run \
		-D ALLOCATOR=jemalloc \
		-D USE_FSAL_VFS=ON \
		-D ENABLE_VFS_POSIX_ACL=ON \
		-D USE_FSAL_MEM=ON \
		-D USE_FSAL_PROXY_V4=OFF \
		-D USE_FSAL_PROXY_V3=OFF \
		-D USE_FSAL_LUSTRE=OFF \
		-D USE_FSAL_LIZARDFS=OFF \
		-D USE_FSAL_KVSFS=OFF \
		-D USE_FSAL_CEPH=OFF \
		-D USE_FSAL_RGW=OFF \
		-D USE_FSAL_XFS=OFF \
		-D USE_FSAL_GPFS=OFF \
		-D USE_FSAL_GLUSTER=OFF \
		-D USE_FSAL_NULL=OFF \
		-D USE_DBUS=OFF \
		-D USE_NFSIDMAP=OFF \
		-D USE_MONITORING=OFF \
		-D USE_CAPS=ON \
		-D USE_BLKID=ON \
		-D USE_GSS=OFF \
		-D USE_9P=OFF \
		-D USE_NFS3=OFF \
		-D USE_RQUOTA=OFF \
		-D USE_RADOS_RECOV=OFF \
		-D USE_ADMIN_TOOLS=OFF \
		-D USE_GUI_ADMIN_TOOLS=OFF \
		-D USE_MAN_PAGE=OFF \
		-D RPCBIND=OFF \
		../src/
RUN ninja -C ./build/ install

###################################################
### "main" stage
###################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/debian:sid-slim]], [[FROM docker.io/debian:sid-slim]]) AS main
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectorm/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		catatonit \
		libacl1 \
		libblkid1 \
		libcap2 \
		libjemalloc2 \
		libtirpc-common \
		liburcu8 \
		libuuid1 \
	&& rm -rf /var/lib/apt/lists/*

ENV PATH=/usr/local/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH}

RUN mkdir -p /var/lib/nfs/ganesha/

COPY --from=build --chown=root:root /usr/local/ /usr/local/
COPY --chown=root:root --chmod=644 ./config/ganesha/ /etc/ganesha/

EXPOSE 2049/tcp

ENTRYPOINT ["/usr/bin/catatonit", "--", "/usr/local/bin/ganesha.nfsd"]
CMD ["-F", "-x", "-L", "/dev/stdout", "-f", "/etc/ganesha/ganesha.conf"]
