-- create foreign data wrapper to oracle
create extension oracle_fdw;
create foreign data wrapper ora$perf$fdw_utf8 handler oracle_fdw_handler validator oracle_fdw_validator options (nls_lang 'american_america.AL32UTF8');
-- create schema ora$perf$;
drop schema if exists ora$perf$ cascade;
create schema if not exists ora$perf$;
--
drop view if exists ora$perf$union_all_view_creation;
create or replace view ora$perf$union_all_view_creation as
with t as (
 select * from information_schema.foreign_tables
 where foreign_table_catalog=current_database()
 and foreign_table_schema like 'ora$perf$%' and foreign_table_schema=foreign_server_name
 and foreign_table_name like 'ora$perf$%'
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
drop procedure if exists ora$perf$define_perfstat_fdw;
create procedure ora$perf$define_perfstat_fdw(name text,service text, password text, drop_if_exists boolean default true)
language plpgsql as $PROCEDURE$
declare
 prefix text = 'ora$perf$';
 tables record;
begin
  begin
  execute 'create foreign data wrapper "'||prefix||'oracle_fdw_utf8" handler oracle_fdw_handler validator oracle_fdw_validator options (nls_lang ''american_america.AL32UTF8'')';
  exception when others then null;
  end;
 if drop_if_exists then
  execute 'drop schema if exists "'||prefix||name||'" cascade';
  execute 'drop user mapping if exists for postgres server "'||prefix||name||'"';
  execute 'drop server if exists "'||prefix||name||'" cascade';
 end if;
 -- create all FDW for this server
 execute 'create server if not exists "'||prefix||name||'" foreign data wrapper "'||prefix||'oracle_fdw_utf8" options (dbserver '''||service||''')';
 execute 'create user mapping if not exists for postgres server "'||prefix||name||'" options (user ''PERFSTAT'', password '''||password||''')';
 execute 'create schema if not exists "'||prefix||name||'"';
 execute 'import foreign schema "PERFSTAT" from server "'||prefix||name||'" into "'||prefix||name||'" options (readonly ''true'', prefetch ''1000'', case ''lower'')';
 -- create union all views
 for tables in select * from ora$perf$union_all_view_creation
 loop
  execute 'create or replace view "'||tables.table_name||'" as '||tables.select_statement;
 end loop;
end;
$PROCEDURE$;

