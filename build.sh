(
cd FDW_build
podman rm -f franck 
echo "=== build"
podman build -t oracle_fdw . 
echo "=== run"
podman run -d --name franck oracle_fdw
echo "=== log"
until podman logs franck | grep -C 999 "listening on IPv4 address" ; do sleep 1; done
echo "=== check"
podman exec -t franck psql -e -c "select version();" | grep "compiled by gcc" && git commit -am "psql connect" && git push
)
