# 140.238.211.75
# podman rm -f franck ; podman build -t oracle_fdw . ; podman run -d --name franck oracle_fdw
# podman logs franck ; podman exec -it franck bash
#
FROM docker.io/centos/postgresql-12-centos8:latest
FROM oraclelinux
USER root
#
# this fails # RUN yum update -y
#
RUN yum install -y https://download.oracle.com/otn_software/linux/instantclient/oracle-instantclient-basic-linuxx64.rpm
RUN yum install -y git make
#
#postgresql-devel 
ENV POSTGRESQL_ADMIN_PASSWORD postgres
USER postgres
RUN git clone https://github.com/laurenz/oracle_fdw.git
RUN ( cd oracle_fdw && make )

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
