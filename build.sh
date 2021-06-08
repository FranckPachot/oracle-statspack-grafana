(
cd oracle-perfstat-fdw
sudo docker rm -f franck 
echo "=== build"
sudo docker build -t oracle-perfstat-fdw .  ||  exit
echo "=== images"
sudo docker images
echo "=== run"
sudo docker run -d --name franck -e POSTGRESQL_ADMIN_PASSWORD=statspack oracle-perfstat-fdw
echo "=== log"
sleep 5
sudo docker logs franck
until sudo docker logs franck | grep -C 999 "listening on IPv4 address" ; do sleep 1; done
echo "=== check"
sudo docker exec franck psql -e <<'SQL'
 select  oraperfstat$define_fdw('pdb1','//localhost:1521/DEV15','PERFSTAT','password',true,true);
 select * from oraperfstat$available_servers();
 explain analyze select * from system_events;
SQL
git commit -am "psql connect" && git push
sudo docker tag oracle-perfstat-fdw pachot/oracle-perfstat-fdw
sudo docker login docker.io
sudo docker push pachot/oracle-perfstat-fdw
)
