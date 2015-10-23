conditionally_create_user()
{
  user=$1
  user_command='
  DO LANGUAGE plpgsql
  $body$
  BEGIN
    IF NOT EXISTS (
        SELECT *
        FROM pg_catalog.pg_user
        WHERE usename = '\'"${user}"\'') THEN
      CREATE USER '"${user}"' WITH PASSWORD '"'$POSTGRES_PASSWORD'"';
    END IF;
  END
  $body$'

  echo "$user_command" | psql -U postgres
}

conditionally_create_database()
{
  database=$1
  user=$2

  count=$(psql -lqt -U postgres | cut -d \| -f 1 | grep -w $database | wc -l)
  if [ $count -eq 0 ]; then
    psql -c "CREATE DATABASE $database ENCODING 'UTF8';" -U postgres
    psql -c "GRANT ALL PRIVILEGES ON DATABASE $database TO $user;" -U postgres
  fi
}

conditionally_create_user erlangelist
conditionally_create_database erlangelist erlangelist