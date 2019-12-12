ARG osdistro=debian
ARG oscodename=stretch

FROM $osdistro:$oscodename
LABEL maintainer="Walter Doekes <wjdoekes+maodbc@osso.nl>"

ARG DEBIAN_FRONTEND=noninteractive

# This time no "keeping the build small". We only use this container for
# building/testing and not for running, so we can keep files like apt
# cache.
RUN echo 'APT::Install-Recommends "0";' >/etc/apt/apt.conf.d/01norecommends
#RUN sed -i -e 's:deb.debian.org:apt.osso.nl:;s:security.debian.org:apt.osso.nl/debian-security:' /etc/apt/sources.list
RUN apt-get update -q
RUN apt-get install -y apt-utils
RUN apt-get dist-upgrade -y
RUN apt-get install -y \
    ca-certificates curl wget \
    build-essential dpkg-dev quilt dh-autoreconf binutils-dev \
    libssl-dev unixodbc-dev cmake

# Download orig, copy debian dir, check version
RUN mkdir -p /build
ARG upversion
RUN curl --fail "https://downloads.mariadb.com/Connectors/odbc/connector-odbc-${upversion}/mariadb-connector-odbc-${upversion}-ga-src.tar.gz" \
    >/build/maodbc_${upversion}.orig.tar.gz
RUN cd /build && \
    mkdir maodbc-${upversion} && \
    tar --strip-components=1 -C maodbc-${upversion} -zxf "maodbc_${upversion}.orig.tar.gz" && \
    mkdir /build/maodbc-${upversion}/debian
COPY . /build/maodbc-${upversion}/debian/
WORKDIR /build/maodbc-${upversion}

# debian, deb, stretch, maodbc, 3.1.5, '', 0osso1
ARG osdistro
ARG osdistshort
ARG oscodename
ARG upname
ARG debepoch=
ARG debversion

RUN . /etc/os-release && \
    fullversion="${upversion}-${debversion}+${osdistshort}${VERSION_ID}" && \
    expected="${upname} (${debepoch}${fullversion}) ${oscodename}; urgency=low" && \
    head -n1 debian/changelog && \
    if test "$(head -n1 debian/changelog)" != "${expected}"; \
    then echo "${expected}  <-- mismatch" >&2; false; fi
RUN dpkg-buildpackage -us -uc -sa

# TODO: for bonus points, we could run quick tests here;
# for starters dpkg -i tests?

# Write output files (store build args in ENV first).
ENV oscodename=$oscodename osdistshort=$osdistshort \
    upname=$upname upversion=$upversion debversion=$debversion
RUN . /etc/os-release && fullversion=${upversion}-${debversion}+${osdistshort}${VERSION_ID} && \
    mkdir -p /dist/${upname}_${fullversion} && \
    mv /build/*${fullversion}* /dist/${upname}_${fullversion}/ && \
    mv /build/${upname}_${upversion}.orig.tar.gz /dist/${upname}_${fullversion}/ && \
    cd / && find dist/${upname}_${fullversion} -type f >&2
