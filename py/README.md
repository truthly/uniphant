# Uniphant

Uniphant is a modular and extendable Python package designed to integrate with
multiple APIs, process items using the APIs, and store the results in a
PostgreSQL database. The package is built to support a wide range of use cases
and can be customized to work with any API and data processing pipeline.

## System Overview

Uniphant is designed to be adaptable and versatile, with the capability to
integrate seamlessly with various APIs. It uses a PostgreSQL database for
storage, and each API integration has its dedicated set of tables and
functions.

The primary functionality of Uniphant includes:

- Uploading data to the respective API.
- Initiating the processing of the data.
- Retrieving the processed data.
- Storing the results in the database.

The package employs a unique design pattern with separate Python scripts for
each API method. These scripts are executed as stand-alone programs, which can
be scheduled and managed by a custom script or a task scheduler.
