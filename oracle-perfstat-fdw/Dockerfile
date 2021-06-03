FROM docker.io/centos/postgresql-12-centos8:latest
USER root
RUN yum install -y https://download.oracle.com/otn_software/linux/instantclient/185000/oracle-instantclient18.5-basic-18.5.0.0.0-3.x86_64.rpm
RUN yum install -y https://download.oracle.com/otn_software/linux/instantclient/185000/oracle-instantclient18.5-devel-18.5.0.0.0-3.x86_64.rpm
ADD https://github.com/laurenz/oracle_fdw/archive/refs/tags/ORACLE_FDW_2_3_0.zip /var/tmp
RUN unzip -qd /var/tmp /var/tmp/ORACLE_FDW_2_3_0.zip
RUN yum install -y make gcc libpq-devel postgresql-devel postgresql-contrib postgresql-server-devel redhat-rpm-config
RUN cd /var/tmp/oracle_fdw-ORACLE_FDW_2_3_0 && make && make install
RUN echo $(dirname $(find / -name libclntsh.so 2>/dev/null | tail)) > /etc/ld.so.conf.d/oracle.conf ; ldconfig
RUN ln -s /usr/lib64/libnsl.so.2 /usr/lib64/libnsl.so.1
RUN sed -ie "/pg_ctl stop/s?^?psql < /var/tmp/oracle-perfstat-fdw.sql ; ?" /usr/bin/run-postgresql
RUN echo "franck::0:0:root:/root:/bin/bash" >> /etc/passwd
ENV POSTGRESQL_ADMIN_PASSWORD postgresql
user postgres
ADD oracle-perfstat-fdw.sql /var/tmp
