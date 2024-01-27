m4_changequote([[, ]])

##################################################
## "main" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/debian:sid-slim]], [[FROM docker.io/debian:sid-slim]]) AS main
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectorm/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		catatonit \
		dbus-daemon \
		dbus-system-bus-common \
		netbase \
		nfs-ganesha \
		nfs-ganesha-vfs \
		rpcbind \
		runit \
	&& rm -rf /var/lib/apt/lists/*

ENV SVDIR=/etc/service/

COPY --chown=root:root --chmod=644 ./config/ganesha/ /etc/ganesha/
COPY --chown=root:root --chmod=755 ./scripts/service/ /etc/service/

EXPOSE 2049/tcp

ENTRYPOINT ["/usr/bin/catatonit", "--", "/usr/bin/runsvdir"]
CMD ["-P", "/etc/service/"]
