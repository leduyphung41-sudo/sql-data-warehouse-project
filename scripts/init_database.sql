/*
===============================================================================
Init: Create bronze / silver / gold databases (MySQL)
===============================================================================
Purpose:
    MySQL does not have SQL Server-style schemas inside one database, so each
    layer of the medallion architecture gets its own database instead:
    bronze.<table>, silver.<table>, gold.<view>.

WARNING:
    This script DROPS the bronze/silver/gold databases if they already exist.
    Only run it on a fresh/dev instance, never against data you care about.
===============================================================================
*/

DROP DATABASE IF EXISTS bronze;
DROP DATABASE IF EXISTS silver;
DROP DATABASE IF EXISTS gold;

CREATE DATABASE bronze CHARACTER SET utf8mb4;
CREATE DATABASE silver CHARACTER SET utf8mb4;
CREATE DATABASE gold   CHARACTER SET utf8mb4;

