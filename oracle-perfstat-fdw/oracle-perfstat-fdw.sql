create extension oracle_fdw;
create foreign data wrapper ora_fdw_utf8
 handler oracle_fdw_handler validator oracle_fdw_validator
 options (nls_lang 'american_america.AL32UTF8');
 
-- this function encapsulates a short select on one Statspack table (stats$database_instance) to check that the server is available  
 
create function oraperfstat$available_servers()
returns table (name text, version text, platform text, instance_name text, db_name text, host_name text, startup_time date,error_message text) language plpgsql as $FUNCTION$
declare 
 t record;
begin
 for t in select foreign_server_name from information_schema.foreign_servers where foreign_server_catalog='oraperfstat'
 loop
  name:=t.foreign_server_name;
  error_message='';
  begin
   -- mybe run some session settings there?  
   --perform oracle_execute(t.foreign_server_name,'alter session set CLIENT_RESULT_CACHE_SIZE=1048576 CLIENT_RESULT_CACHE_LAG=60');
   execute format($SQL$
           select version,platform_name platform,instance_name,db_name,host_name, startup_time
           from %I.database_instance 
           order by startup_time desc fetch first 1 rows only
   $SQL$,t.foreign_server_name)
   into version,platform,instance_name,db_name, host_name, startup_time;
   return next;
   exception when others then error_message:=SQLERRM; return next; 
  end;
 end loop;
end;
$FUNCTION$;
drop view if exists oraperfstat$union_all_view_creation;

-- this view creates a UNION ALL view for all servers

create or replace view oraperfstat$union_all_view_creation as
with t as (
 select * from information_schema.foreign_tables
 where foreign_table_catalog=current_database() -- this database
 and foreign_table_schema=foreign_server_name   -- where we create one schema per server
 and foreign_server_name in ( select name from oraperfstat$available_servers() )
),
     c as (
 select replace(table_schema,'ora$perf$','') as server,table_schema,table_name,column_name,ordinal_position
 from information_schema.columns where (table_catalog, table_schema, table_name) in (
  select foreign_table_catalog,foreign_table_schema,foreign_table_name from t
 )
),
     a as (
 select table_name,column_name,min(ordinal_position) as ordinal_position from c group by table_name,column_name
),
     u as (
select table_schema,table_name
 ,'select '''||server||''' as server,'||string_agg(
 case when c.column_name is null then 'null' else '"'||c.column_name||'"' end ||' as "'||a.column_name||'"'
 ,',' order by a.ordinal_position)
 ||' from "'||table_schema||'"."'||table_name||'"' select_statement
 from c right outer join a using(table_name,column_name)
 group by server,table_schema,table_name
)
select table_name,string_agg(select_statement ,' union all ' order by table_schema) select_statement
from u group by table_name
;

-- this function use the previous view to create the UNION ALL views

create function oraperfstat$create_views(
 drop_if_exists boolean default true)
--returns int
returns table(output text)
language plpgsql as $PROCEDURE$
declare
 tables record;
 --number_of_views int :=0;
begin
 for tables in select * from oraperfstat$union_all_view_creation
 loop
  execute 'create or replace view "'||tables.table_name||'" as '||tables.select_statement;
  --number_of_views:=number_of_views+1;
  return query select '===> explain select * from "'||tables.table_name||'"';
  return query execute 'explain select * from "'||tables.table_name||'"';
 end loop;
 --return number_of_views;
end;
$PROCEDURE$; 

-- this creates everything when adding a new server: a schema, foreign data tables  

create function oraperfstat$define_fdw(
 name text,service text, username text, password text, drop_server boolean default false, create_server boolean default false)
returns table(defined_fdw text, message text)
language plpgsql as $PROCEDURE$
declare
 prefix text = '';
 tables record;
 number_of_views int :=0;
begin
 if drop_server then
	  execute 'drop schema if exists "'||prefix||name||'" cascade';
	  execute 'drop user mapping if exists for oraperfstat server "'||prefix||name||'"';
	  execute 'drop server if exists "'||prefix||name||'" cascade';
 end if;	
 if create_server then
	 -- I create my FDW in case it does not exist because I want to set the NLS_LANG (not sure it is a good idea)
	 begin
	  execute 'create foreign data wrapper "'||prefix||'oracle_fdw_utf8" handler oracle_fdw_handler validator oracle_fdw_validator options (nls_lang ''american_america.AL32UTF8'')';
	 exception when others then null;
	 end;
	 -- create all FDW for this server
	 execute 'create schema if not exists "'||prefix||name||'"';
	 execute 'grant select on all tables in schema "'||prefix||name||'" to oraperfstat';
	 execute 'create server if not exists "'||prefix||name||'" foreign data wrapper "'||prefix||'oracle_fdw_utf8" options (dbserver '''||service||''',isolation_level ''read_only'')';
	 execute 'create user mapping if not exists for oraperfstat server "'||prefix||name||'" options (user '''||username||''', password '''||password||''')';
	 execute 'grant usage on foreign server "'||prefix||name||'" to oraperfstat';
	 -- import all tables just in case, but better to build specific optimized queries
	 execute format($DDL$
	  import foreign schema "PERFSTAT" limit to ("stats$snapshot", "stats$system_event", "stats$sysstat")  
	  from server %I into %I options (readonly 'true', prefetch '1000', case 'lower')
	 $DDL$
	 , prefix||name --> foreign server name
	 , prefix||name --> foreign schema name
	 );
	 execute format($DDL$
	  import foreign schema "SYS" limit to ("v_$event_name") 
	  from server %I into %I options (readonly 'true', prefetch '1000', case 'lower')
	 $DDL$
	 , prefix||name --> foreign server name
	 , prefix||name --> foreign schema name
	 );
	 -- not sure it is a good idea however, even if FDW wrapper is nice, let's build queries
	 
	 ------------------------------------------------------------------------------------------------------------------------------------------------------
	 ------- database_instance: info from v$database and v$instance 
	 ------- used to select a server with tags (dashboard variables) and to check available servers with oraperfstat$available_servers"()
	 ------------------------------------------------------------------------------------------------------------------------------------------------------
	 
	  execute format($DDL$
	  create foreign table if not exists %I.%I (%s) server %I options (readonly 'true', table $QUERY$(%s)$QUERY$ )
	 $DDL$
	 , prefix||name       --> foreign schema name
	 , 'database_instance'    --> foreign table name
	 , 'version text, platform_name text, instance_name text, db_name text, host_name text, startup_time date'    --> foreign column description
	 , prefix||name --> foreign server name
	 ,$SQL$
			   select version,platform_name,instance_name,db_name,host_name, startup_time
			   from stats$database_instance
			   where (dbid,instance_number) = (select dbid,instance_number from v$database, v$instance)
	 $SQL$
	 );
	 
	 ------------------------------------------------------------------------------------------------------------------------------------------------------
	 ------- system_events: info from v$system_events plus CPU from v$sysstat, as well as db time in order to add the unaccounted time
	 ------------------------------------------------------------------------------------------------------------------------------------------------------
	 
	 execute format($DDL$
	  create foreign table if not exists %I.%I (%s) server %I options (readonly 'true', table $QUERY$(%s)$QUERY$ )
	 $DDL$
	 , prefix||name       --> foreign schema name
	 , 'system_events'    --> foreign table name
	 , 'time timestamp,elapsed interval,snap_id numeric, sessions numeric, status text,wait_class text, event text'    --> foreign column description
	 , prefix||name --> foreign server name
	 ,$SQL$
	   select sys_extract_utc(cast(snap_time as timestamp)) as "time",elapsed,snap_id--,db_name,host_name
	   -- DB time - time waited - CPU time = Wait for CPU 
	   ,round(case when event='DB time' then 
		 time_waited_s-sum(case when event='DB time' then time_waited_s when wait_class!='Idle' then -time_waited_s 
		 end) over (partition by dbid,instance_number,snap_id) else time_waited_s end / elapsed_s ,2) "sessions" 
	   , case wait_class when 'Idle' then 'Inactive' else 'Active' end "status"
	   ,nvl(wait_class,'CPU') "wait_class"
	   ,case when event='DB time' then 'Other DB time' else event end event
	   from (
		select dbid,instance_number,snap_id
		,snap_time
		,(snap_time-lag(snap_time)over(partition by dbid,instance_number order by snap_id))*24*60*60 elapsed_s 
		,(cast(snap_time as timestamp)-lag(cast(snap_time as timestamp))over(partition by dbid,instance_number order by snap_id)) elapsed 
		--,db_name,host_name,platform_name,instance_name,version
		from STATS$SNAPSHOT 
		--join (select dbid, instance_number,db_name,host_name,platform_name,instance_name,version, startup_time from STATS$DATABASE_INSTANCE) 
		--using (dbid, instance_number, startup_time)
	   ) outer join (
	   select dbid,instance_number,snap_id
		,wait_class,event
		,(time_waited_micro-lag(time_waited_micro) over (partition by dbid,instance_number,event order by snap_id))/1e6 time_waited_s
		,total_waits
	   from STATS$SYSTEM_EVENT join V$EVENT_NAME using(event_id) --where wait_class not in ('Idle')
	   union all
	   select dbid,instance_number,snap_id,
		null  wait_class,case name when 'CPU used by this session' then 'CPU' else name end event,
		(value-lag(value) over (partition by dbid,instance_number,name order by snap_id))/1e2 time_waited_s 
		,null total_waits
	   from STATS$SYSSTAT where name in ('CPU used by this session','DB time') 
	  ) using (dbid,instance_number,snap_id) 
	  where elapsed_s>0 and time_waited_s/elapsed_s>0.01
	 $SQL$
	 );
	 
	 ------------------------------------------------------------------------------------------------------------------------------------------------------
	 ------- sql_summary: info from v$sqlstat
	 ------- used for Top SQL dashboard
	 ------------------------------------------------------------------------------------------------------------------------------------------------------

	 
	 execute format($DDL$
	  create foreign table if not exists %I.%I (%s) server %I options (readonly 'true', table $QUERY$(%s)$QUERY$ )
	 $DDL$
	 , prefix||name       --> foreign schema name
	 , 'sql_summary'    --> foreign table name
	 , '
	   time timestamp, snap_id numeric, db_name text, host_name text, command_name text,sql_id text, old_hash_value numeric, text_subset text, module text
	   , elapsed_s numeric
	   , executions numeric, sorts numeric, fetches numeric, px_servers_executions numeric, end_of_fetch_count numeric
	   , loads numeric, invalidations numeric, parse_calls numeric, disk_reads numeric, direct_writes numeric, buffer_gets numeric
	   , plsql_exec_time numeric, java_exec_time numeric, rows_processed numeric, cpu_time numeric, elapsed_time numeric
	   '    --> foreign column description
	 , prefix||name --> foreign server name
	 ,$SQL$
	   select sys_extract_utc(cast("time" as timestamp)) as "time", snap_id, db_name,host_name
	   , nvl(command_name,'unknown') command_name,sql_id, old_hash_value, text_subset, module, elapsed_s
	   , executions-nvl(lag(executions)over(partition by dbid,instance_number,text_subset,old_hash_value,text_subset,address,sql_id order by snap_id),0) executions
	   , sorts-nvl(lag(sorts)over(partition by dbid,instance_number,text_subset,old_hash_value,text_subset,address,sql_id order by snap_id),0) sorts
	   , fetches-nvl(lag(fetches)over(partition by dbid,instance_number,text_subset,old_hash_value,text_subset,address,sql_id order by snap_id),0) fetches
	   , px_servers_executions-nvl(lag(px_servers_executions)over(partition by dbid,instance_number,text_subset,old_hash_value,text_subset,address,sql_id order by snap_id),0) px_servers_executions
	   , end_of_fetch_count-nvl(lag(end_of_fetch_count)over(partition by dbid,instance_number,text_subset,old_hash_value,text_subset,address,sql_id order by snap_id),0) end_of_fetch_count
	   , loads-nvl(lag(loads)over(partition by dbid,instance_number,text_subset,old_hash_value,text_subset,address,sql_id order by snap_id),0) loads
	   , invalidations-nvl(lag(invalidations)over(partition by dbid,instance_number,text_subset,old_hash_value,text_subset,address,sql_id order by snap_id),0) invalidations
	   , parse_calls-nvl(lag(parse_calls)over(partition by dbid,instance_number,text_subset,old_hash_value,text_subset,address,sql_id order by snap_id),0) parse_calls
	   , disk_reads-nvl(lag(disk_reads)over(partition by dbid,instance_number,text_subset,old_hash_value,text_subset,address,sql_id order by snap_id),0) disk_reads
	   , direct_writes-nvl(lag(direct_writes)over(partition by dbid,instance_number,text_subset,old_hash_value,text_subset,address,sql_id order by snap_id),0) direct_writes
	   , buffer_gets-nvl(lag(buffer_gets)over(partition by dbid,instance_number,text_subset,old_hash_value,text_subset,address,sql_id order by snap_id),0) buffer_gets
	   , plsql_exec_time-nvl(lag(plsql_exec_time)over(partition by dbid,instance_number,text_subset,old_hash_value,text_subset,address,sql_id order by snap_id),0) plsql_exec_time
	   , java_exec_time-nvl(lag(java_exec_time)over(partition by dbid,instance_number,text_subset,old_hash_value,text_subset,address,sql_id order by snap_id),0) java_exec_time
	   , rows_processed-nvl(lag(rows_processed)over(partition by dbid,instance_number,text_subset,old_hash_value,text_subset,address,sql_id order by snap_id),0) rows_processed
	   , cpu_time-nvl(lag(cpu_time)over(partition by dbid,instance_number,text_subset,old_hash_value,text_subset,address,sql_id order by snap_id),0) cpu_time
	   , elapsed_time-nvl(lag(elapsed_time)over(partition by dbid,instance_number,text_subset,old_hash_value,text_subset,address,sql_id order by snap_id),0) elapsed_time
	   from (
		select dbid,instance_number,snap_id,startup_time,snap_time "time"
		,case when lag(snap_time)over(partition by dbid,instance_number order by snap_id) > startup_time then (snap_time-lag(snap_time)over(partition by dbid,instance_number order by snap_id))*24*60*60 end elapsed_s
		,db_name,host_name,platform_name,instance_name,version
		from STATS$SNAPSHOT join (select dbid, instance_number,db_name,host_name,platform_name,instance_name,version, startup_time from STATS$DATABASE_INSTANCE) using (dbid, instance_number, startup_time)
	   ) join (
	   select dbid,instance_number,snap_id
	   , command_type,address,sql_id, old_hash_value, text_subset, module
	   , executions, sorts, fetches, px_servers_executions, end_of_fetch_count
	   , loads, invalidations, parse_calls, disk_reads, direct_writes, buffer_gets
	   , plsql_exec_time, java_exec_time, rows_processed, cpu_time, elapsed_time 
		 from STATS$SQL_SUMMARY --left outer join (select old_hash_value,sql_id,command_type,text_subset from STATS$SQLTEXT) using (old_hash_value,sql_id,command_type)
	  ) using (dbid,instance_number,snap_id)
	  left outer join (select action command_type, name command_name from audit_actions ) using(command_type)
	  where elapsed_s>0 and executions>0
	 $SQL$
	 );  
	 
	 ------------------------------------------------------------------------------------------------------------------------------------------------------
	 ------- sql_plan: info from v$sqlplan wirh a call to dbms_xplan
	 ------------------------------------------------------------------------------------------------------------------------------------------------------

	 -- I create a view here to be able to use dbms_xplan on it.
	 perform oracle_execute(prefix||name,'create or replace view ORAPERFSTAT$SQL_PLAN as select STATS$SQL_PLAN.*, cast(null as date) timestamp from STATS$SQL_PLAN');
	 perform oracle_execute(prefix||name,'comment on table ORAPERFSTAT$SQL_PLAN is ''view created with additional timetamp column to be used with dbms_xplan.display''');
	 execute format($DDL$
	  create foreign table if not exists %I.%I (%s) server %I options (readonly 'true', table $QUERY$(%s)$QUERY$ )
	 $DDL$
	 , prefix||name       --> foreign schema name
	 , 'sql_plan'    --> foreign table name
	 , 'sql_id text, plan_hash_value numeric, plan_table_output text, last_active_time date, plan text'    --> foreign column description
	 , prefix||name --> foreign server name||
	 ,$SQL$
	  select sql_id,plan_hash_value,'' plan_table_output, last_active_time
	   ,dbms_xplan.display_plan('ORAPERFSTAT$SQL_PLAN',null,'all +outline -predicate','plan_hash_value='||plan_hash_value,'text') plan
	   from (
	   select sql_id,plan_hash_value,max(last_active_time) last_active_time from STATS$SQL_PLAN_USAGE group by sql_id,plan_hash_value
	  )--,table(dbms_xplan.display('ORAPERFSTAT$SQL_PLAN',null,'advanced','plan_hash_value='||plan_hash_value)) 
	 $SQL$
	 );
	 
	 ------------------------------------------------------------------------------------------------------------------------------------------------------
	 ------- sql_text: lines from sql text
	 ------------------------------------------------------------------------------------------------------------------------------------------------------


	 execute format($DDL$
	  create foreign table if not exists %I.%I (%s) server %I options (readonly 'true', table $QUERY$(%s)$QUERY$ )
	 $DDL$
	 , prefix||name       --> foreign schema name
	 , 'sql_text'         --> foreign table name
	 , 'sql_id text, piece numeric, sql_text text, last_snap_time date'    --> foreign column description
	 , prefix||name --> foreign server name
	 ,$SQL$
	  select sql_id,piece,sql_text, snap_time last_snap_time from STATS$SQLTEXT join STATS$SNAPSHOT on STATS$SQLTEXT.last_snap_id=STATS$SNAPSHOT.snap_id
	 $SQL$
	 );



	-- the following are ugly and would deserve better 
	execute 'create foreign table if not exists "'||prefix||name||'".'
	 ||'"xxxdatabase_instances" (time timestamp, db_name text, host_name text,platform_name text,instance_name text,version text)'
	 ||' server "'||prefix||name||'" options (readonly ''true'', prefetch ''1000'', table ''('||$SQL$
	 select startup_time "time",db_name,host_name,platform_name,instance_name,version
	  from STATS$DATABASE_INSTANCE
	 $SQL$||')'')';
	 
	 execute 'create foreign table if not exists "'||prefix||name||'".'
	 ||'"xxsystem_events" (time timestamp, db_name text, host_name text, sessions numeric, status text,wait_class text, event text)'
	 ||' server "'||prefix||name||'" options (readonly ''true'', prefetch ''1000'', table ''('||$SQL$
	 select "time",db_name,host_name
	-- DB time - time waited - CPU time = Wait for CPU 
	 ,round(case when event=''DB time'' then time_waited_s-sum(case when event=''DB time'' then time_waited_s when wait_class!=''Idle'' then -time_waited_s end) over (partition by dbid,instance_number,snap_id) else time_waited_s end / elapsed_s ,2) "sessions" 
	 , case wait_class when ''Idle'' then ''Inactive'' else ''Active'' end "status"
	 ,nvl(wait_class,''CPU'') "wait_class"
	 ,case when event=''DB time'' then ''Other DB time'' else event end event
	 from (
	  select dbid,instance_number,snap_id
	  ,snap_time "time",(snap_time-lag(snap_time)over(partition by dbid,instance_number order by snap_id))*24*60*60 elapsed_s 
	  ,db_name,host_name,platform_name,instance_name,version
	  from STATS$SNAPSHOT join (select dbid, instance_number,db_name,host_name,platform_name,instance_name,version, startup_time from STATS$DATABASE_INSTANCE) using (dbid, instance_number, startup_time)
	 ) outer join (
	 select dbid,instance_number,snap_id
	  ,wait_class,event
	  ,(time_waited_micro-lag(time_waited_micro) over (partition by dbid,instance_number,event order by snap_id))/1e6 time_waited_s
	  ,total_waits
	 from STATS$SYSTEM_EVENT join V$EVENT_NAME using(event_id) --where wait_class not in (''Idle'')
	 union all
	 select dbid,instance_number,snap_id,
	  null  wait_class,case name when ''CPU used by this session'' then ''CPU'' else name end event,
	  (value-lag(value) over (partition by dbid,instance_number,name order by snap_id))/1e2 time_waited_s 
	  ,null total_waits
	 from STATS$SYSSTAT where name in (''CPU used by this session'',''DB time'') 
	) using (dbid,instance_number,snap_id) 
	where elapsed_s>0 and time_waited_s/elapsed_s>0.01
	 $SQL$||')'')';
	 --execute 'import foreign schema "PERFSTAT" from server "'||prefix||name||'" into "'||prefix||name||'" options (readonly ''true'', prefetch ''1000'', case ''lower'')';
	 -- create union all views
	 --for tables in select * from oraperfstat$union_all_view_creation
	 --loop
	  --execute 'create or replace view "'||tables.table_name||'" as '||tables.select_statement;
	  --number_of_views:=number_of_views+1;
	 --end loop;
	 --return number_of_views;
	 --select oraperfstat$create_views();
 end if; -- that the end of create
-- in all case we re-create the views 
 perform oraperfstat$create_views(); 
 return query select srvname::text , case when srvname=prefix||name and create_server then ' (added sucessfully)' else '' end  from pg_foreign_server;
 --return format('%s successfully added as FDW server %I with tables in schema %I.',name,prefix||name,prefix||name);
end;
$PROCEDURE$;
