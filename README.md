# oracle-statspack-grafana
Using PostgreSQL Foreign Data Wrapper to read Oracle Statspack metrics from Grafana

## Build the image for the PostgreSQL Oracle_FDW gateway
```
(cd oracle-perfstat-fdw && podman build -t oracle-perfstat-fdw && podman run -d -e POSTGRESQL_ADMIN_PASSWORD=franck --name oracle-perfstat-fdw oracle-perfstat-fdw )
```

This container runs PostgreSQL with Laurenz Albe's Oracle Foreign Data Wrapper (using Oracle instantClient) and provides a procedure to create Foreign Data Wrapper tables, here is an example:
```
podman exec oracle-perfstat-fdw psql -e oraperfstat oraperfstat <<'SQL'
select  oraperfstat$define_fdw('pdb1','//server:1521/PDB1','perfstat','password',true,true);
SQL
```
This creates the views to query Statspack.


