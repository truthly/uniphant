-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION uniphant" to load this file. \quit

CREATE SCHEMA IF NOT EXISTS api;
GRANT USAGE ON SCHEMA api TO web_anon;
GRANT USAGE ON SCHEMA webauthn TO web_anon;
GRANT web_anon TO postgrest;
