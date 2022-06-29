ARG osdistro=debian
ARG oscodename=stretch

FROM $osdistro:$oscodename
LABEL maintainer="Walter Doekes <wjdoekes+maodbc@osso.nl>"
LABEL dockerfile-vcs=https://github.com/ossobv/maodbc-deb

ARG DEBIAN_FRONTEND=noninteractive

# This time no "keeping the build small". We only use this container for
# building/testing and not for running, so we can keep files like apt
# cache. We do this before copying anything and before getting lots of
# ARGs from the user. That keeps this bit cached.
RUN echo 'APT::Install-Recommends "0";' >/etc/apt/apt.conf.d/01norecommends
# We'll be ignoring "debconf: delaying package configuration, since apt-utils
#   is not installed"
RUN apt-get update -q && \
    apt-get dist-upgrade -y && \
    apt-get install -y \
        ca-certificates curl \
        build-essential devscripts dh-autoreconf dpkg-dev equivs quilt && \
    printf "%s\n" \
        QUILT_PATCHES=debian/patches QUILT_NO_DIFF_INDEX=1 \
        QUILT_NO_DIFF_TIMESTAMPS=1 'QUILT_DIFF_OPTS="--show-c-function"' \
        'QUILT_REFRESH_ARGS="-p ab --no-timestamps --no-index"' \
        >~/.quiltrc

# Apt-get prerequisites according to control file.
COPY control /build/debian/control
RUN mk-build-deps --install --remove --tool "apt-get -y" /build/debian/control

# debian, deb, stretch, maodbc, 3.1.5, '', 0osso1
ARG osdistro osdistshort oscodename upname upversion debepoch= debversion

COPY changelog /build/debian/changelog
RUN . /etc/os-release && \
    sed -i -e "1s/+[^+)]*)/+${osdistshort}${VERSION_ID})/;1s/) stable;/) ${oscodename};/" \
        /build/debian/changelog && \
    fullversion="${upversion}-${debversion}+${osdistshort}${VERSION_ID}" && \
    expected="${upname} (${debepoch}${fullversion}) ${oscodename}; urgency=medium" && \
    head -n1 /build/debian/changelog && \
    if test "$(head -n1 /build/debian/changelog)" != "${expected}"; \
    then echo "${expected}  <-- mismatch" >&2; false; fi

# Download orig, copy debian dir, check version
# https://mariadb.com/kb/en/mariadb-connector-odbc/
# https://dlm.mariadb.com/browse/odbc_connector/
RUN mkdir -p /build && \
    case $upversion in \
    3.1.16) url=https://dlm.mariadb.com/2338586/Connectors/odbc/connector-odbc-3.1.16/mariadb-connector-odbc-3.1.16-src.tar.gz;; \
    *) url=https://downloads.mariadb.com/Connectors/odbc/connector-odbc-${upversion}/mariadb-connector-odbc-${upversion}-ga-src.tar.gz;; \
    esac && \
    curl -fLsS -o /build/${upname}_${upversion}.orig.tar.gz "$url"
RUN cd /build && \
    mkdir ${upname}-${upversion} && \
    tar --strip-components=1 -C ${upname}-${upversion} -zxf "${upname}_${upversion}.orig.tar.gz" && \
    mkdir /build/${upname}-${upversion}/debian
COPY . /build/${upname}-${upversion}/debian/
RUN cp /build/debian/changelog /build/${upname}-${upversion}/debian/changelog
WORKDIR /build/${upname}-${upversion}

###############################################################################
# Build
###############################################################################
# Instead of
#   RUN DEB_BUILD_OPTIONS=parallel=6 dpkg-buildpackage -us -uc
# we split up the steps for Docker.
#
# Answer by "the paul" to question by "Dan Kegel":
# https://stackoverflow.com/questions/15079207/debhelper-deprecated-option-until
#
# Last modified by wdoekes, at 2022-06-01.
###############################################################################
# $ sed -e '/run_\(cmd\|hook\)(/!d;s/^[[:blank:]]*/  /' \
#     $(command -v dpkg-buildpackage)
#   run_hook('init', 1);
#   run_cmd('dpkg-source', @source_opts, '--before-build', '.');
#   run_hook('preclean', $preclean);
#   run_hook('source', build_has_any(BUILD_SOURCE));
#   run_cmd('dpkg-source', @source_opts, '-b', '.');
#     ^- dpkg-buildpackage --build=source
#   run_hook('build', build_has_any(BUILD_BINARY));
#   run_cmd(@debian_rules, $buildtarget) if rules_requires_root($binarytarget);
#     ^- dpkg-buildpackage -nc -T build
#   run_hook('binary', 1);
#     ^- dpkg-buildpackage -nc --build=any,all -us -uc
#   run_hook('buildinfo', 1);
#   run_cmd('dpkg-genbuildinfo', @buildinfo_opts);
#   run_hook('changes', 1);
#   run_hook('postclean', $postclean);
#   run_cmd('dpkg-source', @source_opts, '--after-build', '.');
#     ^- also done AFTER source build, so we need to --before-build again
#   run_hook('check', $check_command);
#   run_cmd($check_command, @check_opts, $chg);
#   run_hook('sign', $signsource || $signbuildinfo || $signchanges);
#   run_hook('done', 1);
#   run_cmd(@cmd);
#   run_cmd($cmd);
###############################################################################
ENV DEB_BUILD_OPTIONS=parallel=6
# (1) check build deps, clean tree, make source debs;
#     we abuse the hook to exit after the build, so we can continue without
#     having to re-do any --before-build and clean.
RUN dpkg-buildpackage --build=source --hook-buildinfo="sh -c 'exit 69'" || \
      rc=$?; test ${rc:-0} -eq 69
# (2) perform build (make);
#     /tmp/fail so we can inspect the result of a failed build if we want
RUN dpkg-buildpackage --no-pre-clean --rules-target=build || touch /tmp/fail
RUN ! test -f /tmp/fail
# (3) install stuff into temp dir, tar it up, make the deb file (make install);
#     /tmp/fail so we can inspect the result of a failed build if we want
RUN dpkg-buildpackage --no-pre-clean --build=any,all -us -uc || touch /tmp/fail
RUN ! test -f /tmp/fail
# (4) reconstruct the changes+buildinfo files, adding the source build;
#     the binary buildinfo has SOURCE_DATE_EPOCH in the Environment, we'll
#     want to keep that.
RUN changes=$(ls ../*.changes) && buildinfo=$(ls ../*.buildinfo) && \
    dpkg-genchanges -sa >$changes && \
    restore_env=$(sed -e '/^Environment:/,$!d' $buildinfo) && \
    dpkg-genbuildinfo && \
    remove_env=$(sed -e '/^Environment:/,$!d' $buildinfo) && \
    echo "$remove_env" | sed -e 's/^/-/' >&2 && \
    echo "$restore_env" | sed -e 's/^/+/' >&2 && \
    sed -i -e '/^Environment:/,$d' $buildinfo && \
    echo "$restore_env" >>$buildinfo
###############################################################################

# TODO: for bonus points, we could run quick tests here;
# for starters dpkg -i tests?

# Write output files (store build args in ENV first).
ENV oscodename=$oscodename osdistshort=$osdistshort \
    upname=$upname upversion=$upversion debversion=$debversion
RUN . /etc/os-release && fullversion=${upversion}-${debversion}+${osdistshort}${VERSION_ID} && \
    mkdir -p /dist/${upname}_${fullversion} && \
    mv /build/${upname}_${upversion}.orig.tar.gz /dist/${upname}_${fullversion}/ && \
    mv /build/*${fullversion}* /dist/${upname}_${fullversion}/ && \
    cd / && find dist/${upname}_${fullversion} -type f >&2
