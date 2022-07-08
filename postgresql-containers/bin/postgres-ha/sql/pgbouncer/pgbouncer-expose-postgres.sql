/**
 * Copyright 2016 - 2021 Percona, LLC
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

/**
 * pgbouncer-expose-superusers.sql replaces pgbouncer.get_auth function
 * to allow users with SUPERUSER privilege to connect through PgBouncer.
 */

/**
 * The "get_auth" function allows us to return the appropriate login credentials
 * for a user that is using a password based authentication method so it can work
 * with pgbouncer's "auth_query" parameter.
 *
 * See: http://www.pgbouncer.org/config.html#auth_query
 */
CREATE OR REPLACE FUNCTION pgbouncer.get_auth(username TEXT)
RETURNS TABLE(username TEXT, password TEXT) AS
$$
  SELECT rolname::TEXT, rolpassword::TEXT
  FROM pg_authid
  WHERE
    (pg_authid.rolname = $1 AND pg_authid.rolname = 'postgres') OR
    (
        NOT pg_authid.rolsuper AND
        NOT pg_authid.rolreplication AND
        pg_authid.rolcanlogin AND
        pg_authid.rolname <> 'pgbouncer' AND (
            pg_authid.rolvaliduntil IS NULL OR
            pg_authid.rolvaliduntil >= CURRENT_TIMESTAMP
        ) AND
        pg_authid.rolname = $1
    );
$$
LANGUAGE SQL STABLE SECURITY DEFINER;
