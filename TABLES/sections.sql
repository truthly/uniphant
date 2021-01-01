CREATE TABLE sections (
section_id integer NOT NULL GENERATED ALWAYS AS IDENTITY,
section_name text NOT NULL,
PRIMARY KEY (section_id),
UNIQUE (section_name)
);

SELECT pg_catalog.pg_extension_config_dump('sections', '');
