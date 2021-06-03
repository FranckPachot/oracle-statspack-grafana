(
cd oracle-perfstat-fdw
sudo podman rm -f franck 
echo "=== build"
sudo podman build -t oracle-perfstat-fdw .  ||  exit
echo "=== images"
sudo podman images
echo "=== run"
sudo podman run -d --name franck -e POSTGRESQL_ADMIN_PASSWORD=statspack oracle-perfstat-fdw
echo "=== log"
sleep 5
sudo podman logs franck
until sudo podman logs franck | grep -C 999 "listening on IPv4 address" ; do sleep 1; done
echo "=== check"
sudo podman exec franck psql -e <<'SQL'
call  ora$perf$define_perfstat_fdw('pdb1','//database-1.clw0gescgpyk.us-east-1.rds.amazonaws.com:1521/pdb1','perfstat');
SQL
git commit -am "psql connect" && git push
)
