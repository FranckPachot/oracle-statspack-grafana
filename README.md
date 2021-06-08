# oracle-statspack-grafana
Using PostgreSQL Foreign Data Wrapper to read Oracle Statspack metrics from Grafana

## Build the image for the PostgreSQL Oracle_FDW gateway
```
(cd oracle-perfstat-fdw && podman build -t oracle-perfstat-fdw . && podman run -p 5432:5432 -d -e POSTGRESQL_ADMIN_PASSWORD=franck --name oracle-perfstat-fdw oracle-perfstat-fdw )
```
You may prefer not to expose the 5432 port as you can connect with docker exec -it psql oraperfstat oraperfstat

## Build the image for the PostgreSQL Oracle_FDW gateway
```
docker network create oracle-perfstat-fdw
docker run -p 5432:5432 --network oracle-perfstat-fdw -d -e POSTGRESQL_ADMIN_PASSWORD=franck --name oracle-perfstat-fdw oracle-perfstat-fdw
```
This creates a networ and container running the PostgreSQL database with Oracle Foreign Data Wrapper
The postgresql password, and the oraperfstat one, are POSTGRESQL_ADMIN_PASSWORD (default: postgres)

The container runs PostgreSQL with Laurenz Albe's Oracle Foreign Data Wrapper (using Oracle instantClient) and provides a procedure to create Foreign Data Wrapper tables, here is an example:
```
podman exec oracle-perfstat-fdw psql -e oraperfstat oraperfstat <<'SQL'
select  oraperfstat$define_fdw('pdb1','//server:1521/PDB1','perfstat','password',true,true);
SQL
```
This creates the views to query Statspack on the database.
- 1st argument is the internal name.
- 2nd argument is the Oracle connection string
- 3rd argument is the user that has access to Statspack views (can be perfstat)
- 4th argument is the user password
- 5th argument default to false, drops the FDW server if set to true
- 6th argument defaults to true, creates the FDW server

## run Percona Management Server
You can use this from Grafana, declaring a PostgreSQL source, preferably creating a user with the right privileges. 

We need only Grafana but Percoma Managment Server contains Grafana and other components to monitor databases, easy to install:
```
docker pull percona/pmm-server:2
docker create --volume /srv --name pmm-data percona/pmm-server:2 /bin/true
docker run --detach --restart always --publish 443:443 --network oracle-perfstat-fdw --volumes-from pmm-data --name pmm-server percona/pmm-server:2
```

## declare Data Source in Grafana

Then you can access Grafana on 443 port and declare a PostgreSQL source:
- Name: Oracle Perf Stat (which I set as default)
- Host: oracle-perfstat-fdw:5432
- User: postgres
- Password: POSTGRESQL_ADMIN_PASSWORD (as defined above)
- SSL Mode: disable

## import dashboards
