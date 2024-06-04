DO
$do$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'app') THEN
      PERFORM dblink_exec('CREATE DATABASE "app"');
END IF;
END
$do$;
