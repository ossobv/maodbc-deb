OSSO build of the maodbc.so MariaDB SQL ODBC Connector
======================================================

*NOTE: This package is obsolete now that there is odbc-mariadb in vanilla
Debian/Ubuntu.*


Docker build
------------

Just do::

    ./Dockerfile.build

And it will create the build files in ``Dockerfile.out/``.

For example::

    $ dpkg-deb -c Dockerfile.out/bullseye/maodbc_3.1.16-0osso0+deb11/libmaodbc_3.1.16-0osso0+deb11_amd64.deb
     682,624  /usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so
       9,357  /usr/share/doc/libmaodbc/COPYING.gz
         291  /usr/share/doc/libmaodbc/README
         720  /usr/share/doc/libmaodbc/changelog.Debian.gz
          96  /usr/share/libmaodbc/odbcinst.ini
           0  /usr/lib/x86_64-linux-gnu/odbc/libmyodbc.so -> libmaodbc.so



TODO
----

* Add basic tests at the end of the docker build.
* Check the odbcinst.ini flags (like Threading=0) and whether they
  actually do anything in the maodbc driver.
* Check that the SSL we compiled against actually works.
