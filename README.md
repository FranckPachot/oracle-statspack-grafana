(this is in alpha work mode, draft from a previous PoC, but you can try and comments are welcome)

The goal is to see this without licensing Diagnostic Pack:

![screenshot](./screenshots/Screenshot%202021-06-09%20142921.jpg)
![screenshot](./screenshots/Screenshot%202021-06-09%20142450.jpg)

# oracle-statspack-grafana
Using PostgreSQL Foreign Data Wrapper to read Oracle Statspack metrics from Grafana

## Build the image for the PostgreSQL Oracle_FDW gateway
```
(cd oracle-perfstat-fdw && docker build -t oracle-perfstat-fdw .)
```
You may prefer not to expose the 5432 port as you can connect with docker exec -it psql oraperfstat oraperfstat

Note that you can also pull the image I've built:
```
docker pull docker.io/pachot/oracle-perfstat-fdw
```

## Run the image for the PostgreSQL Oracle_FDW gateway
```
docker network create oracle-perfstat-fdw
docker run -p 5432:5432 --network oracle-perfstat-fdw -d -e POSTGRESQL_ADMIN_PASSWORD=franck --name oracle-perfstat-fdw oracle-perfstat-fdw
```
This creates a networ and container running the PostgreSQL database with Oracle Foreign Data Wrapper
The postgresql password, and the oraperfstat one, are POSTGRESQL_ADMIN_PASSWORD (default: postgres)

The container runs PostgreSQL with Laurenz Albe's Oracle Foreign Data Wrapper (using Oracle instantClient) and provides a procedure to create Foreign Data Wrapper tables, here is an example:
```
docker exec oracle-perfstat-fdw psql -e oraperfstat oraperfstat <<'SQL'
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

# Example with PMM and Oracle XE

## run Percona Management Server
You can use this from Grafana, declaring a PostgreSQL source, preferably creating a user with the right privileges. 

We need only Grafana but Percona Managment Server contains Grafana and other components to monitor databases, easy to install:
```
docker pull percona/pmm-server:2
docker create --volume /srv --name pmm-data percona/pmm-server:2 /bin/true
docker run --detach --restart always --publish 443:443 --network oracle-perfstat-fdw --volumes-from pmm-data --name pmm-server percona/pmm-server:2
```

## Declare Data Source in Grafana

Then you can access Grafana on 443 port and declare a PostgreSQL source:
- Name: Oracle Perf Stat (which I set as default)
- Host: oracle-perfstat-fdw:5432
- Database: oraperfstat
- User:oraperfstat
- Password: POSTGRESQL_ADMIN_PASSWORD (as defined above)
- SSL Mode: disable


![screenshot](./screenshots/Screenshot%202021-06-09%20142159.jpg)

Note that if you run rootless (podman) and get *Error: cannot join CNI networks if running rootless: invalid argument* when starting containers with *--network oracle-perfstat-fdw* you can use the host name rather than the container name as the PostgreSQL host and the port you redirected with *-p 5432:5432*

## Import dashboards

examples of dashboards are in the grafana subdir, you can import them

![screenshot](./screenshots/Screenshot%202021-06-09%20142233.jpg)

## Create an Oracle XE database
and install Statspack

```
docker run -d -p 1521:1521 --network oracle-perfstat-fd -e ORACLE_PASSWORD=franck gvenzl/oracle-xe --name oraclexe
docker exec -t oraclexe <<'SQL'
sqlplus -L sys/oracle@//localhost/XE as sysdba @ ?/rdbms/admin/spcreate
perfstat
SYSAUX
TEMP
exec statspack.snap(i_snap_level=>7);
exec for i in 1..100 loop dbms_stats.gather_system_stats('NOWORKLOAD'); dbms_stats.gather_database_stats; statspack.snap(i_snap_level=>7); end loop;
quit
SQL
```

You should see something in Grafana...
