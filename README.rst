OSSO build of the maodbc.so MariaDB SQL ODBC Connector
======================================================

Get source::

    # Get source from https://downloads.mariadb.org/connector-odbc/
    # and rename to maodbc_VERSION.orig.tar.gz; e.g.:
    wget -O maodbc_3.1.5.orig.tar.gz \
      https://downloads.mariadb.com/Connectors/odbc/connector-odbc-3.1.5/mariadb-connector-odbc-3.1.5-ga-src.tar.gz
    # 3.1.5 has md5sum b59e048596cbd131f2d94c4cecbc2684

    # Extract:
    tar zxf maodbc_3.1.5.orig.tar.gz
    cd mariadb-connector-odbc-3.1.5-ga-src

Setup ``debian/`` dir::

    git clone https://github.com/ossobv/maodbc-deb.git debian

Optionally alter ``debian/changelog`` and then build::

    dpkg-buildpackage -us -uc -sa


Docker build
------------

Or you can just do::

    ./Dockerfile.build

And it will create the build files in ``Dockerfile.out/``.


TODO
----

* Add basic tests at the end of the docker build.
* Check the odbcinst.ini flags (like Threading=0) and whether they
  actually do anything in the maodbc driver.
* Check that the SSL we compiled against actually works.
