CREATE OR REPLACE FUNCTION effective_domain()
RETURNS text
STABLE
LANGUAGE sql
AS $$
/*
  This function is compatible with PostgREST.

  See: https://postgrest.org/en/v7.0.0/api.html#accessing-request-headers-cookies-and-jwt-claims

  We could have used a regex to extract the host from the URL,
  but since ts_debug() has this capability, let's use it.
  The only annoyance is the special case when there is no TLD,
  such as for "http://localhost", in which case the returned alias
  is "asciiweord", which is why we need the "WHERE COUNT = 1"
  wrapper, to ensure not more than one row matched,
  which would be ambiguous.
*/
SELECT token FROM (
  SELECT token, COUNT(*) OVER ()
  FROM ts_debug(current_setting('request.header.origin', TRUE))
  WHERE alias IN ('host','asciiword')
) AS X WHERE COUNT = 1
$$;
