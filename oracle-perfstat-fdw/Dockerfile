# 140.238.211.75
# podman rm -f franck ; podman build -t oracle_fdw . ; podman run -d --name franck oracle_fdw
# podman logs franck ; podman exec -it franck bash
#
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
#RUN cd /var/tmp/oracle_fdw-ORACLE_FDW_2_3_0; export ORACLE_HOME=/usr/include/oracle/21/client64 ; export LD_LIBRARY_PATH=/usr/lib/oracle/21/client64/lib ; make ; make install
RUN echo "franck::0:0:root:/root:/bin/bash" >> /etc/passwd

ENV POSTGRESQL_ADMIN_PASSWORD postgresql
user postgres
ADD oracle-perfstat-fdw.sql /var/tmp
# RUN echo "psql < /var/tmp/oracle-perfstat-fdw.sql"
# container-entrypoint run-postgresql
#RUN echo "" >> /usr/bin/run-postgresql
#FROM centos
#USER root
# Oracle Instant Client
#RUN yum install -y https://download.oracle.com/otn_software/linux/instantclient/oracle-instantclient-basic-linuxx64.rpm
# PostgreSQL
# curl -s https://ftp.postgresql.org/pub/source/v13.3/postgresql-13.3.tar.gz | tar -zxf -
#RUN dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
#RUN dnf -qy module disable postgresql
#RUN dnf install -y postgresql13-server
#RUN /usr/pgsql-13/bin/postgresql-13-setup initdb
# Oracle FDW
#RUN wget -c https://github.com/laurenz/oracle_fdw/archive/refs/tags/ORACLE_FDW_2_3_0.zip && unzip ORACLE_FDW_2_3_0.zip && rm ORACLE_FDW_2_3_0.zip
#RUN git clone https://github.com/laurenz/oracle_fdw.git
#RUN ( cd oracle_fdw && make && make install)
#
# this fails # RUN yum update -y
#
### ok: ##
#
#
#
#
#RUN yum install -y git make yum-config-manager
#
#RUN yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
#RUN yum-config-manager --enable ol7_developer_EPEL ol7_developer | grep -i baseurl
#RUN yum -y install postgresql13 postgresql13-server postgresql13-odbc postgresql13-devel
##postgresql-devel 
#ENV POSTGRESQL_ADMIN_PASSWORD postgres
#RUN git clone https://github.com/laurenz/oracle_fdw.git
#RUN ( cd oracle_fdw && make )
#USER postgres

#RUN yum install -y https://download.oracle.com/otn_software/linux/instantclient/oracle-instantclient-basic-linuxx64.rpm
#UN type psql
#FROM docker.io/library/postgres:latest
#RUN dpkg -l | grep libaio1 > /dev/null || apt-get install -y libaio1
#FROM docker.io/library/centos/postgresql
#RUN wget -c https://download.oracle.com/otn_software/linux/instantclient/instantclient-basiclite-linuxx64.zip
#RUN ls -alrt /etc
#RUN cat /etc/os-release
#ADD https://download.oracle.com/otn_software/linux/instantclient/instantclient-basic-linuxx64.zip /tmp
#RUN apt-get install -y git unzip
#RUN unzip /tmp/instantclient-basic-linuxx64.zip
