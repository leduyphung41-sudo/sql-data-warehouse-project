/*
=============================================================
Create Database and Schemas
=============================================================
Script Purpose:
    This script creates a new database named 'DataWarehouse'.
    If the database already exists, it is dropped and recreated.
    It also creates three schemas/databases: bronze, silver, and gold.

WARNING:
    Running this script will drop the entire 'DataWarehouse' database if it exists.
    All data will be permanently deleted.
=============================================================
*/

DROP DATABASE IF EXISTS DataWarehouse;

CREATE DATABASE DataWarehouse;

USE DataWarehouse;

DROP DATABASE IF EXISTS bronze;
DROP DATABASE IF EXISTS silver;
DROP DATABASE IF EXISTS gold;

CREATE DATABASE bronze;
CREATE DATABASE silver;
CREATE DATABASE gold;
