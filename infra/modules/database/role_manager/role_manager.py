import itertools
import json
import logging
import os
from operator import itemgetter
from typing import Optional

import boto3
from pg8000.native import Connection, identifier, literal

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    if event == "check":
        return check()
    elif event == "drop":
        return drop()
    else:
        return manage()

def manage():
    """Manage database roles, schema, and privileges"""

    logger.info("Running command 'manage' to manage database roles, schema, and privileges")
    conn = connect_as_master_user()

    logger.info("Current database configuration")
    prev_roles = get_roles(conn)
    print_roles(prev_roles)

    prev_schema_privileges = get_schema_privileges(conn)
    print_schema_privileges(prev_schema_privileges)

    configure_database(conn)

    logger.info("New database configuration")

    new_roles = get_roles(conn)
    print_roles(new_roles)

    new_schema_privileges = get_schema_privileges(conn)
    print_schema_privileges(new_schema_privileges)

    return {
        "roles": new_roles,
        "roles_with_groups": get_roles_with_groups(conn),
        "schema_privileges": {
            schema_name: schema_acl
            for schema_name, schema_acl
            in new_schema_privileges
        },
    }

def check():
    """Check that database roles, schema, and privileges were
    properly configured
    """
    logger.info("Running command 'check' to check database roles, schema, and privileges")
    app_username = os.environ.get("APP_USER")
    migrator_username = os.environ.get("MIGRATOR_USER")
    schema_name = os.environ.get("DB_SCHEMA")
    app_conn = connect_using_iam(app_username)
    migrator_conn = connect_using_iam(migrator_username)
    
    check_search_path(migrator_conn, schema_name)
    check_migrator_create_table(migrator_conn, app_username)
    check_app_use_table(app_conn)
    cleanup_migrator_drop_table(migrator_conn)

    return {"success": True}

def drop():
    """Drop schema"""
    logger.info("Running command 'drop_schema' to reset the schema")
    migrator_username = os.environ.get("MIGRATOR_USER")
    migrator_conn = connect_using_iam(migrator_username)
    schema_name = os.environ.get("DB_SCHEMA")
    drop_schema(migrator_conn, schema_name)

    return {"success": True}

def check_search_path(migrator_conn: Connection, schema_name: str):
    logger.info("Checking that search path is %s", schema_name)
    assert migrator_conn.run("SHOW search_path") == [[schema_name]]


def check_migrator_create_table(migrator_conn: Connection, app_username: str):
    logger.info("Checking that migrator is able to create tables and grant access to app user: %s", app_username)
    migrator_conn.run("CREATE TABLE IF NOT EXISTS temporary(created_at TIMESTAMP)")
    migrator_conn.run(f"GRANT ALL PRIVILEGES ON temporary TO {identifier(app_username)}")
    

def check_app_use_table(app_conn: Connection):
    logger.info("Checking that app is able to read and write from the table")
    app_conn.run("INSERT INTO temporary (created_at) VALUES (NOW())")
    app_conn.run("SELECT * FROM temporary")
    
    
def cleanup_migrator_drop_table(migrator_conn: Connection):
    logger.info("Cleaning up the table that migrator created")
    migrator_conn.run("DROP TABLE IF EXISTS temporary")

def drop_schema(migrator_conn: Connection, schema_name: str):
    logger.info(f"Dropping schema: {schema_name}")
    migrator_conn.run(f"DROP SCHEMA IF EXISTS {identifier(schema_name)} CASCADE")

def connect_as_master_user() -> Connection:
    user = os.environ["DB_USER"]
    host = os.environ["DB_HOST"]
    port = os.environ["DB_PORT"]
    database = os.environ["DB_NAME"]
    param_name = os.environ["DB_PASSWORD_PARAM_NAME"]
    password = get_password(param_name)

    logger.info("Connecting to database: user=%s host=%s port=%s database=%s", user, host, port, database)
    return Connection(user=user, host=host, port=port, database=database, password=password, ssl_context=True)


def connect_using_iam(user: str) -> Connection:
    client = boto3.client("rds")
    host = os.environ["DB_HOST"]
    port = os.environ["DB_PORT"]
    database = os.environ["DB_NAME"]
    token = client.generate_db_auth_token(
        DBHostname=host, Port=port, DBUsername=user
    )
    logger.info("Connecting to database: user=%s host=%s port=%s database=%s", user, host, port, database)
    return Connection(user=user, host=host, port=port, database=database, password=token, ssl_context=True)

def get_password(param_name: str) -> str:
    raw_result = get_ssm_param(param_name)

    # RDS managed secrets via secrets manager will be a JSON payload with
    # "username" and "password" keys, so if can parse as JSON, we'll try to
    # extract just the password, otherwise return the param value as-is
    try:
        parsed_result = json.loads(raw_result)
    except json.JSONDecodeError:
        return raw_result

    if not isinstance(parsed_result, dict):
        return raw_result

    return parsed_result.get("password")

def get_ssm_param(param_name: str) -> str:
    ssm = boto3.client("ssm", region_name=os.environ["AWS_REGION"])
    logger.info(f"Fetching from parameter store: {param_name}")
    result = ssm.get_parameter(
        Name=param_name,
        WithDecryption=True,
    )
    return result["Parameter"]["Value"]


def get_roles(conn: Connection) -> list[str]:
    return [row[0] for row in conn.run("SELECT rolname "
                                       "FROM pg_roles "
                                       "WHERE rolname NOT LIKE 'pg_%' "
                                       "AND rolname NOT LIKE 'rds%'")]


def get_roles_with_groups(conn: Connection) -> dict[str, str]:
    roles_groups = conn.run("SELECT u.rolname AS user, g.rolname AS group \
                            FROM pg_roles u \
                            INNER JOIN pg_auth_members a ON u.oid = a.member \
                            INNER JOIN pg_roles g ON g.oid = a.roleid \
                            ORDER BY user ASC")
    
    result = {}
    for user, groups in itertools.groupby(roles_groups, itemgetter(0)):
        result[user] = ",".join(map(itemgetter(1), groups))
    return result


# Get schema access control lists. The format of the ACLs is abbreviated. To interpret
# what the ACLs mean, see the Postgres documentation on Privileges:
# https://www.postgresql.org/docs/current/ddl-priv.html
def get_schema_privileges(conn: Connection) -> list[tuple[str, str]]:
    return [(row[0], row[1]) for row in conn.run("SELECT nspname, nspacl \
                                                 FROM pg_namespace \
                                                 WHERE nspname NOT LIKE 'pg_%' \
                                                 AND nspname <> 'information_schema'")]


def configure_database(conn: Connection) -> None:
    logger.info("Configuring database")
    app_username = os.environ.get("APP_USER")
    migrator_username = os.environ.get("MIGRATOR_USER")
    schema_name = os.environ.get("DB_SCHEMA")
    database_name = os.environ.get("DB_NAME")
    grant_app_user_iam = os.environ.get("GRANT_APP_USER_IAM") == "true"
    allow_app_manage_schema = os.environ.get("ALLOW_APP_MANAGE_SCHEMA") == "true"

    # If an app user password is defined, retrieve it
    app_user_password = None
    if app_user_password_param_name := os.environ.get("APP_PASSWORD_PARAM_NAME"):
        app_user_password = get_password(app_user_password_param_name)

    logger.info("Revoking default access on public schema")
    conn.run("REVOKE CREATE ON SCHEMA public FROM PUBLIC")
    logger.info("Revoking database access from public role")
    conn.run(f"REVOKE ALL ON DATABASE {identifier(database_name)} FROM PUBLIC")
    logger.info("Setting default search path to schema=%s", schema_name)
    conn.run(f"ALTER DATABASE {identifier(database_name)} SET search_path TO {identifier(schema_name)}")

    logger.info("Configuring roles")
    configure_role(conn, migrator_username, database_name)
    configure_role(conn, app_username, database_name, app_user_password, grant_app_user_iam)
    configure_schema(conn, schema_name, migrator_username, app_username, allow_app_manage_schema)


def configure_role(conn: Connection, username: str, database_name: str, password: Optional[str] = None, grant_iam_role: bool = True) -> None:
    logger.info(f"Configuring role: username={username}")

    if not password:
        logger.info(f"Create role without password: {username=}")
        conn.run(
            f"""
            DO $$
            BEGIN
                CREATE USER {identifier(username)};
                EXCEPTION WHEN DUPLICATE_OBJECT THEN
                RAISE NOTICE 'user already exists';
            END
            $$;
            """
        )
    else:
        logger.info("Create role with password: username=%s", username)
        conn.run(
            f"""
            DO $$
            BEGIN
                CREATE USER {identifier(username)} WITH PASSWORD {literal(password)};
                EXCEPTION WHEN DUPLICATE_OBJECT THEN
                RAISE NOTICE 'user already exists';
                ALTER ROLE {identifier(username)} WITH PASSWORD {literal(password)};
            END
            $$;
            """
        )

    role = "rds_iam"
    if grant_iam_role:
        logger.info(f"Grant role: {role=}, {username=}")
        conn.run(f"GRANT {identifier(role)} TO {identifier(username)}")
    else:
        logger.info(f"Revoke role: {role=}, {username=}")
        conn.run(f"REVOKE {identifier(role)} FROM {identifier(username)}")

    logger.info(f"Grant connect: {database_name=}, {username=}")
    conn.run(f"GRANT CONNECT ON DATABASE {identifier(database_name)} TO {identifier(username)}")

def configure_schema(conn: Connection, schema_name: str, migrator_username: str, app_username: str, allow_app_manage_schema: bool = False) -> None:
    logger.info("Configuring schema")

    logger.info("Creating schema: schema_name=%s", schema_name)
    conn.run(f"CREATE SCHEMA IF NOT EXISTS {identifier(schema_name)}")

    logger.info("Changing schema owner: schema_name=%s owner=%s", schema_name, migrator_username)
    conn.run(f"ALTER SCHEMA {identifier(schema_name)} OWNER TO {identifier(migrator_username)}")

    # Need pgcrypto for uuid generation in Rails
    logger.info("Creating pgcrypto extension")
    conn.run("CREATE EXTENSION IF NOT EXISTS pgcrypto")

    # In most cases, the `app` role only needs USAGE access. This is the default.
    # In some cases, it needs to manage the schema, so we optionally grant ALL access.
    schema_privileges = "USAGE"
    if allow_app_manage_schema:
        schema_privileges = "ALL"
        # Grant the `app` role any default privileges for future database objects.
        logger.info(f"Granting schema privileges for future objects: {schema_name=} role={app_username} {schema_privileges=}")
        conn.run(
            f"ALTER DEFAULT PRIVILEGES IN SCHEMA {identifier(schema_name)} GRANT {identifier(schema_privileges)} ON TABLES TO {identifier(app_username)}"
        )
        conn.run(
            f"ALTER DEFAULT PRIVILEGES IN SCHEMA {identifier(schema_name)} GRANT {identifier(schema_privileges)} ON SEQUENCES TO {identifier(app_username)}"
        )
        conn.run(
            f"ALTER DEFAULT PRIVILEGES IN SCHEMA {identifier(schema_name)} GRANT {identifier(schema_privileges)} ON ROUTINES TO {identifier(app_username)}"
        )

    # Grant the `app` role privileges.
    logger.info(f"Granting schema privileges: {schema_name=} role={app_username} {schema_privileges=}")
    conn.run(f"GRANT {schema_privileges} ON SCHEMA {identifier(schema_name)} TO {identifier(app_username)}")


def print_roles(roles: list[str]) -> None:
    logger.info("Roles")
    for role in roles:
        logger.info(f"Role info: name={role}")


def print_schema_privileges(schema_privileges: list[tuple[str, str]]) -> None:
    logger.info("Schema privileges")
    for schema_name, schema_acl in schema_privileges:
        logger.info(f"Schema info: name={schema_name} acl={schema_acl}")