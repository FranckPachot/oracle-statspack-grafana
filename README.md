# oracle-statspack-grafana
Using PostgreSQL Foreign Data Wrapper to read Oracle Statspack metrics from Grafana

## Build the image for the PostgreSQL Oracle_FDW gateway
(cd FDW_build && podman build -t oracle_fdw && podman run -d --name oracle_fdw oracle_fdw )

This container runs PostgreSQL with Laurenz Albe's Oracle Foreign Data Wrapper (using Oracle instantClient)
