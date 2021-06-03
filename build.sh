(
#cd FDW_build
sudo podman rm -f franck 
echo "=== build"
sudo podman build -t oracle_fdw .  ||  exit
echo "=== images"
sudo podman images
echo "=== run"
sudo podman run -d --name franck -e POSTGRESQL_ADMIN_PASSWORD=statspack oracle_fdw
echo "=== log"
sleep 5
sudo podman logs franck
until sudo podman logs franck | grep -C 999 "listening on IPv4 address" ; do sleep 1; done
echo "=== check"
sudo podman exec -t franck psql -e -c "select version();" | grep "compiled by gcc" && git commit -am "psql connect" && git push
)
