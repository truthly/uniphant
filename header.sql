-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION uniphant" to load this file. \quit

CREATE SCHEMA AUTHORIZATION api;

GRANT USAGE ON SCHEMA webauthn TO api;
GRANT REFERENCES ON TABLE webauthn.credentials TO api;
GRANT SELECT ON webauthn.credential_challenges TO api;
GRANT SELECT ON webauthn.credentials TO api;

SET ROLE api;
