CREATE OR REPLACE FUNCTION remote_ip()
RETURNS inet
STABLE
LANGUAGE sql
AS $$
/*
  This function is compatible with PostgREST.

  See: https://postgrest.org/en/v7.0.0/api.html#accessing-request-headers-cookies-and-jwt-claims

  If using nginx, you also need to add this line to your nginx.conf:
    proxy_set_header X_Forwarded_For $remote_addr;

  See nginx.conf in this repo for a complete example.
*/
SELECT current_setting('request.header.X_Forwarded_For', TRUE)::inet
$$;
