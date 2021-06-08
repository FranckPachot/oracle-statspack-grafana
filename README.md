# oracle-statspack-grafana
Using PostgreSQL Foreign Data Wrapper to read Oracle Statspack metrics from Grafana

## Build the image for the PostgreSQL Oracle_FDW gateway
```
(cd oracle-perfstat-fdw && podman build -t oracle-perfstat-fdw . && podman run -p 5432:5432 -d -e POSTGRESQL_ADMIN_PASSWORD=franck --name oracle-perfstat-fdw oracle-perfstat-fdw )
```

The postgresql password, and the oraperfstat one, are POSTGRESQL_ADMIN_PASSWORD (default: postgres)

This container runs PostgreSQL with Laurenz Albe's Oracle Foreign Data Wrapper (using Oracle instantClient) and provides a procedure to create Foreign Data Wrapper tables, here is an example:
```
podman exec oracle-perfstat-fdw psql -e oraperfstat oraperfstat <<'SQL'
select  oraperfstat$define_fdw('pdb1','//server:1521/PDB1','perfstat','password',true,true);
SQL
```
This creates the views to query Statspack.
You can use it from Grafana, preferably creating a user with the right privileges.

## run Percona Management Server
We need only Grafana but Percoma Managment Server contains Grafana and other conpmonents to monitor databases, easy to install:
```
pdman pull percona/pmm-server:2
podman create --volume /srv --name pmm-data percona/pmm-server:2 /bin/true
podnam run --detach --restart always --publish 443:443 --volumes-from pmm-data --name pmm-server percona/pmm-server:2
```
