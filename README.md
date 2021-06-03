# oracle-statspack-grafana
Using PostgreSQL Foreign Data Wrapper to read Oracle Statspack metrics from Grafana

## Build the image for the PostgreSQL Oracle_FDW gateway
```
(cd oracle-perfstat-fdw && podman build -t oracle-perfstat-fdw && podman run -d -e POSTGRESQL_ADMIN_PASSWORD=franck --name oracle-perfstat-fdw oracle-perfstat-fdw )
```

This container runs PostgreSQL with Laurenz Albe's Oracle Foreign Data Wrapper (using Oracle instantClient) and provides a procedure to create Foreign Data Wrapper tables, here is an example:
```
podman exec oracle-perfstat-fdw psql -e <<'SQL'
select oraperfstat$define_fdw('pdb1','database-1.clw0gescgpyk.us-east-1.rds.amazonaws.com:1521/pdb1','perfstat','password');
select  oraperfstat$define_fdw('poc_dev15','//aix712p02:15001/DEV15','MON_ASH','MON_ASH_1234');
SQL
```
This creates the views to query Statspack.


