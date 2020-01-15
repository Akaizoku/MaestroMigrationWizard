# Maestro Migration Wizard

Maestro Migration Wizard is a PowerShell utility for OneSumX Financial Studio. It provides automated features to build, export, import, migrate, or remove business rules from Maestro.

## Table of contents

<!-- TOC depthFrom:2 depthTo:6 withLinks:1 updateOnSave:1 orderedList:1 -->

1.  [Table of contents](#table-of-contents)
2.  [Pre-requisites](#pre-requisites)
3.  [Usage](#usage)
4.  [Business rules](#business-rules)
    1.  [CSV File](#csv-file)
    2.  [SQL query](#sql-query)
5.  [Configuration](#configuration)
    1.  [Server configuration](#server-configuration)
    2.  [Script configuration](#script-configuration)
6.  [Parameters](#parameters)
    1.  [Action](#action)
        1.  [Build](#build)
        2.  [Clear](#clear)
        3.  [Export](#export)
        4.  [Import](#import)
        5.  [Migrate](#migrate)
        6.  [Prepare](#prepare)
    2.  [Environment](#environment)
    3.  [Files](#files)
    4.  [Source](#source)
    5.  [Switches](#switches)
        1.  [Prepare](#prepare)
        2.  [NoSQL](#nosql)
7.  [Examples](#examples)
    1.  [Build example](#build-example)
    2.  [Clear example](#clear-example)
    3.  [Export example](#export-example)
        1.  [Export with database check](#export-with-database-check)
        2.  [Export without database check](#export-without-database-check)
    4.  [Import examples](#import-examples)
        1.  [Standard import](#standard-import)
        2.  [Import with processing](#import-with-processing)
    5.  [Migrate example](#migrate-example)
    6.  [Prepare example](#prepare-example)
8.  [Folder structure](#folder-structure)
9.  [Logs](#logs)
    1.  [Master log](#master-log)
    2.  [Additional logs](#additional-logs)
10. [Common issues](#common-issues)

<!-- /TOC -->

<div style="page-break-after: always;"></div>

## Pre-requisites

Maestro Migration Wizard is a PowerShell script that has two dependencies. This means that it relies on the two following libraries to operate correctly:

-   PowerShell Tool Kit: [`PSTK`][pstk]
-   SQL Server PowerShell Module: [`SQLPS`][sqlps] or the newer [`SQLServer`][sqlps]

It also requires `PowerShell v3.0`.

## Usage

1.  Amend the `server.ini` configuration file located under the `conf` folder.
2.  If needed, add custom configuration to the `custom.ini` configuration file in the same configuration folder.
3.  Run `Maestro_Migration_Wizard.ps1` script located under the `powershell` folder with the proper parameters:
    1.  Action to execute:
        -   Build
        -   Clear
        -   Export
        -   Import
        -   Migrate
        -   Prepare
    2.  Environment to use
    3.  CSV file(s) containing the list of business rules to use
    4.  (**Optional**) Source environment when preparing for import or migrating
    5.  (**Optional**) Switches:
        -   Flag if the business rules need to be processed before import (`-Prepare`)
        -   Flag if the database checks need to be skipped before export (`-NoSQL`)
4.  Check the logs

**Remark:** The script uses SQL Server Integrated Security to communicate with the OneSumX Financial Studio database. This means that it has to be run with a Windows user that has the correct access rights to query (select and delete) the database.

## Business rules

In order to specify which business rules need to be exported, imported, or cleared, one or multiple CSV (Coma Separated Values) files must be created containing unique pairs of values allowing to identify the business rules.

### CSV File

The files must contain both business rules type and version as described below:

| Type | Version |
| ---: | ------: |
|    1 |       1 |
|    2 |       1 |

-   Type corresponds to the business rule `mex_type`;
-   Version corresponds to the business rule `version_id`.

**Remark:** When importing a business rule that already exists in the target environment, if the version number is greater, it will automatically set the new version as current. Otherwise, the latest version will remain active.

**Warning:** The current version of the utility require the first line of the CSV file to contain the header ("Type, Version").

### SQL query

You can easily generate a list of business rules to import using the SQL (Structured Query Language) query that can be found in the `sql` directory under the name `select_rule.sql`.

```sql
SELECT    mex_type    AS 'Type',
          version_id  AS 'Version'
FROM      t_mex_type
WHERE     is_current = 1
ORDER BY  mex_type ASC;
```

**Remark:** Add a `WHERE` clause to select only the business rules that are required.

## Configuration

All necessary configuration is done by amending the following configuration files in the configuration folder:

-   `custom.ini`
-   `server.ini`

### Server configuration

The `server.ini` file contains the configuration for each servers. It contains four properties:

| Property | Descripton                                                                                  |
| -------- | ------------------------------------------------------------------------------------------- |
| Archive  | Name of the archive database                                                                |
| Database | Name of the main OneSumX Financial Studio database                                          |
| Server   | Database server (and instance if applicable) hosting the OneSumX Financial Studio databases |
| Staging  | Name of the staging database                                                                |

**Remark:** Each environment is delimited using sections.

Below is an example of the configuration for the development environment:

```ini
# Local environment
[localhost]
Archive   = OneSumXFS_fsdb_archive
Database  = OneSumXFS_fsdb
Server    = localhost
Staging   = FS_staging
```

### Script configuration

The default configuration of the utility is stored into `default.ini`. This file should not be amended. All custom configuration must be made in the `custom.ini` file. Any customisation done in that file will override the default values.

Below is an example of configuration file:

```ini
[Paths]
# Configuration directory
ConfDirectory       = \conf
# Directory containing the libraries
LibDirectory        = \lib

[Filenames]
# Server properties
ServerProperties    = server.ini
# Custom configuration
CustomProperties    = custom.ini
```

**Remark:** Sections (and comments) are ignored in these configuration files. You can make use of them for improved readability.

## Parameters

### Action

The _action_ parameter takes six possible values:

-   Build
-   Clear
-   Export
-   Import
-   Migrate
-   Prepare

#### Build

The _build_ option will build the business rules in Maestro.

#### Clear

The _clear_ option removes specified business rules from the database, and thus, the Maestro application.

**Warning:** This will permanently remove the specified business rules from the system. It is recommended to make a back-up (or export) beforehand.

#### Export

The _export_ option generates XML (eXtensible Markup Language) files containing the business rules data. These files can be later used to import the business rules into a different environment. The target directory for the export is set by the `ExportDirectory` parameter.

**Remark:** The default behaviour of the export sequence is to check that the specified business rule exists in the database before starting the export. This requires the `SQLServer` (or `SQLPS`) module to communicate with the database. In case these are not available, the `-NoSQL` switch allows you to skip that step and directly try to export the business rules from the source system.

#### Import

The _import_ option creates new business rules in Maestro based on XML files containing the business rules data. The source directory for the XML files containing the business rules to import is set by the `ImportDirectory` parameter.

The _prepare_ flag is available when importing to call the prepare action before launching the import sequence.

#### Migrate

The _migrate_ option successively exports, prepares, and imports the specified business rules from the source system to the target environment.

It first exports the business rules as XML files in the export directory (`ExportDirectory`), then process them in the staging area (`TransformDirectory`), and finally move them to the import directory (`ImportDirectory`) while importing them in Maestro.

#### Prepare

The _prepare_ option call the Maestro XML Preprocessor to prepare the XML files for import. It requires the _origin_ parameter to be filled so as to replace the values from the source system by the respective ones for the target environment.

It isolates the specified business rules in the staging area (`TransformDirectory`), process them using the Maestro XML Preprocessor, and creates ready-for-import XML files in the import directory (`ImportDirectory`).

### Environment

The _environment_ parameter defines the system to use. The specified environment must be defined with its attributes in the `server.ini` configuration file.

### Files

The _files_ parameter corresponds to one or multiple CSV files containing the identifiers for the business rules to build, export, import, or clear. The directory for the CSV files containing the list of business rules is set by the `CSVDirectory` parameter.

**Remark:** The file extension (`.csv`) is not necessary.

### Source

The _source_ parameter defines the source system from which the business rules are extracted. The specified environment must be defined with its attributes in the `server.ini` configuration file.

### Switches

#### Prepare

The `Prepare` switch defines if the business rules have to be processed prior to the import into the target system. If effectively calls the `Prepare` action before launching the import sequence.

**Remark:** This switch only has an effect when used with the `Import` action.

#### NoSQL

The `NoSQL` switch defines if the database checks should be skipped prior to launching the export sequence. Use this if no SQL Server modules are available.

**Remark:** This switch only is only available with the `Exports` action.

## Examples

For more information, use `Get-Help .\Maestro_Migration_Wizard.ps1`.

### Build example

`.\Maestro_Migration_Wizard.ps1 -Action build -Environment "DEV" -Files custom,rules`

In this example, the Maestro Migration Wizard will build all the rules specified in the files `custom.csv` and `rules.csv` on the `DEV` environment.

### Clear example

`.\Maestro_Migration_Wizard.ps1 -Action clear -Environment "DEV" -Files custom,rules`

In this example, the Maestro Migration Wizard will remove all the rules specified in the files "custom`.csv"` and "`rules.csv"` from the `DEV` environment.

### Export example

#### Export with database check

`.\Maestro_Migration_Wizard.ps1 -Action export -Environment "DEV" -Files custom,rules`

In this example, the Maestro Migration Wizard will export all the rules specified in the files `custom.csv` and `rules.csv` from the `DEV` environment if they exists in the database.

#### Export without database check

`.\Maestro_Migration_Wizard.ps1 -Action export -Environment DEV -Files custom,rules -NoSQL`

In this example, the Maestro Migration Wizard will export all the rules specified in the files `custom.csv` and `rules.csv` from the `DEV` environment without checking first if they exists in the database.

### Import examples

#### Standard import

`.\Maestro_Migration_Wizard.ps1 -Action import -Environment "TST" -Files custom,rules`

In this example, the Maestro Migration Wizard will import all the rules specified in the files `custom.csv` and `rules.csv`, if the corresponding XML files are available in the import directory (`ImportDirectory`), to the `TST` environment.

**Remark:** The XML files need to be prepared first.

#### Import with processing

`.\Maestro_Migration_Wizard.ps1 -Action import -Environment "TST" -Files custom,rules -Source "DEV" -Prepare`

In this example, the Maestro Migration Wizard will prepare all the rules previously exported from the `DEV` environment specified in the files `custom.csv` and `rules.csv`, if the corresponding XML files are available in the export directory (`ExportDirectory`), and import them to the `TST` environment.

### Migrate example

`.\Maestro_Migration_Wizard.ps1 -Action migrate -Environment "TST" -Files custom,rules -Source "DEV"`

In this example, the Maestro Migration Wizard will export all the rules specified in the files `custom.csv` and `rules.csv` that exist on the `DEV` environment, process them, then import them in the `TST` environment.

### Prepare example

`.\Maestro_Migration_Wizard.ps1 -Action prepare -Environment "TST" -Files custom,rules -Source "DEV"`

In this example, the Maestro Migration Wizard will process all the rules specified in the files `custom.csv` and `rules.csv` that were previously exported from the `DEV` environment into the export directory (`ExportDirectory`), to prepare them for import in the `TST` environment.

## Folder structure

```powershell
.\MaestroMigrationWizard
+---conf
+---etc
|   +---csv
|   +---export
|   +---import
|   \---transform
+---lib
+---logs
+---powershell
\---sql
```

## Logs

Multiple logs are generated during the execution of the Maestro Migration Wizard utility. All of them are stored in the `logs` directory.

### Master log

A transcript is generated when the script is run and records every output.

The format of the log file is as follow: `Maestro_Migration_Wizard_<Action>_<YYYY-MM-DD>_<HHmmss>.log`.

Below is an example of the generated file:

```log
**********************
Windows PowerShell transcript start
Start time: 20181109123335
Username: TEST\zflorian.carrier
RunAs User: TEST\zflorian.carrier
Machine: TDC1APP013 (Microsoft Windows NT 10.0.14393.0)
Host Application: C:\Windows\system32\WindowsPowerShell\v1.0\PowerShell_ISE.exe
Process ID: 16504
PSVersion: 5.1.14393.2515
PSEdition: Desktop
PSCompatibleVersions: 1.0, 2.0, 3.0, 4.0, 5.0, 5.1.14393.2515
BuildVersion: 10.0.14393.2515
CLRVersion: 4.0.30319.42000
WSManStackVersion: 3.0
PSRemotingProtocolVersion: 2.3
SerializationVersion: 1.1.0.1
**********************
Transcript started, output file is D:\MaestroMigrationWizard\logs\Maestro_Migration_Wizard_Import_2018-11-09_123335.log
2018-11-09 12:33:35	INFO	Connecting to TST environment (TDC1SQL023)
2018-11-09 12:33:36	INFO	Initiating import sequence
2018-11-09 12:33:36	INFO	Source directory: D:\MaestroMigrationWizard\etc\export
2018-11-09 12:33:36	INFO	Preparing XML files for import
2018-11-09 12:33:38	INFO	Generating transformation manifest
2018-11-09 12:33:51	INFO	Processing XML files for import
2018-11-09 12:35:49	CHECK	198 XML files were successfully prepared
2018-11-09 12:35:49	INFO	Import directory: D:\MaestroMigrationWizard\etc\import
2018-11-09 12:35:49	INFO	Business rule 6 (version 1)
2018-11-09 12:35:57	CHECK	Business rule 6 (version 1) successfully imported to Maestro
2018-11-09 12:35:57	INFO	Business rule 4601 (version 1)
2018-11-09 12:36:06	CHECK	Business rule 4601 (version 1) successfully imported to Maestro
[...]
2018-11-09 12:44:22	WARN	Business rule 999980 (version 1) was not imported. Check the logs (D:\MaestroMigrationWizard\logs\Import_999980_1_2018-11-09_123335.xml)
2018-11-09 12:44:22	INFO	Business rule 40250010 (version 20600)
[...]
2018-11-09 13:00:29	CHECK	Business rule 461000008 (version 1) successfully imported to Maestro]
2018-11-09 13:00:29	INFO	End of import sequence
2018-11-09 13:00:29	CHECK	197 business rules were successfully imported
2018-11-09 13:00:29	INFO	Total execution time: 00:26:54
**********************
Windows PowerShell transcript end
End time: 20181109130029
**********************
```

### Additional logs

Some additional logs are generated by the Maestro Exchange command line utility during the export and import sequences.

These follow the following explicit formats:

-   `Export_<Type>_<Version>_<YYYY-MM-DD>_<HHmmss>.xml`
-   `Import_<Type>_<Version>_<YYYY-MM-DD>_<HHmmss>.xml`
-   `Transform_<YYYY-MM-DD>_<HHmmss>.xml`

Below is an example of an import log:

```xml
<?xml version="1.0" encoding="utf-8"?>
<loginfo>
  <header>
    <filename>~Import_1_1_2018-09-26_144337_17244</filename>
    <fullpath>C:\MaestroMigrationWizard\logs\~Import_1_1_2018-09-26_144337_17244.xml</fullpath>
    <logpath>C:\MaestroMigrationWizard\logs</logpath>
    <assembly_version name="WoltersKluwer.CorLib">4.0.99.0</assembly_version>
    <assembly_version name="Maestro.Main.Exchange.Command">3.8.99.0</assembly_version>
    <current_directory>C:\MaestroMigrationWizard\powershell</current_directory>
    <user_name>Florian.Carrier</user_name>
    <clr_version>4.0.30319.42000</clr_version>
    <machine>UKWS04282-01</machine>
    <os_version>Microsoft Windows NT 6.2.9200.0</os_version>
  </header>
  <messages>
    <message timestamp="26/09/2018 14:43:37" thread="1" messagetype="Info">Executing command Import - LogFile : C:\MaestroMigrationWizard\logs\Import_1_1_2018-09-26_144337.xml ConsoleOn : False SkipSyntaxValidation : True XmlFile : C:\MaestroMigrationWizard\etc\import\1_1.xml</message>
    <message timestamp="26/09/2018 14:43:37" thread="1" messagetype="Info">Retrieving metadata...</message>
    <message timestamp="26/09/2018 14:43:52" thread="5" messagetype="Info">Reading C:\MaestroMigrationWizard\etc\import\1_1.xml...</message>
    <message timestamp="26/09/2018 14:43:52" thread="1" messagetype="Info">Uploading content to database...</message>
  </messages>
</loginfo>
```

<div style="page-break-after: always;"></div>

## Common issues

| Error level | Error message                                                                                                                                                                                                                                                                         | Explanation                                                                                                                                                                            |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ERROR       | `Parameter` parameter not found in server.ini for `Environment` environment                                                                                                                                                                                                           | The specified parameter is missing from the environment configuration in the server configuration file.                                                                                |
| ERROR       | `PropertyFile` not found in directory `ConfDirectory`                                                                                                                                                                                                                                 | The specified property file was not found in the configuration folder. Check the path or put back the file at that location.                                                           |
| ERROR       | An error occured while removing the business rule `X` (version `Y`) from the database.                                                                                                                                                                                                | An unknown error occured while trying to remove the specified business rule from the database. Try again, or remove it manually.                                                       |
| ERROR       | Cannot find "`SQLScript`" file in directory `SQLDirectory`.                                                                                                                                                                                                                           | The specified SQL script is missing from the SQL directory. Put it back in the folder.                                                                                                 |
| ERROR       | Neither the SQLServer or SQLPS modules could be found.                                                                                                                                                                                                                                | No SQL Server PowerShell module was found. If trying to export, use the `-NoSQL` switch to bypass the database checks, or install either `SQLServer` or `SQLPS` module on the machine. |
| ERROR       | Path not found: `Path`                                                                                                                                                                                                                                                                | The specified path does not exist. Check the configuration files.                                                                                                                      |
| ERROR       | The "`Environment`" environment is not defined in server.ini                                                                                                                                                                                                                          | The specified environment does not exist in the server configuration file. Check the environment name or add it to the file.                                                           |
| ERROR       | The `Action` feature is not yet available                                                                                                                                                                                                                                             | The specified action is still under development. Contact the developer for more information.                                                                                           |
| ERROR       | Throw "The PSTK library could not be found. Make sure it has been made available on the machine or manually put it in the "`LibraryDirectory`" directory"                                                                                                                                          | Make sure that the PowerShell Tool Kit library is available in the PowerShell modules repository or in the local library folder.                                                       |
| ERROR       | Unable to connect to `Environment` database server (`ServerName`)                                                                                                                                                                                                                     | The database server or the database itself is not accessible.                                                                                                                          |
| WARN        | Business rule `X` (version `Y`) does not exists                                                                                                                                                                                                                                       | The specified business rule does not exist in the database and cannot be exported.                                                                                                     |
| WARN        | Business rule `X` (version `Y`) was not  imported. Check the logs (`LogPath`)                                                                                                                                                                                                         | An error occured while trying to import the specified business rule using Maestro Exchange command line utility. Check the logs.                                                       |
| WARN        | Business rule `X` (version `Y`) was not exported. Check the logs (`LogPath`)                                                                                                                                                                                                          | An error occured while trying to export the specified business rule using Maestro Exchange command line utility. Check the logs.                                                       |
| WARN        | No XML file was found for business rule `X` (version `Y`)                                                                                                                                                                                                                             | No XML file was found in the `ImportDirectory` for the specified business rule.                                                                                                        |
| WARN        | The `CSVFile` file was not found in directory `CSVDirectory`                                                                                                                                                                                                                          | The specified CSV was not found in the CSV directory. Check the name of the file or create one.                                                                                        |
| WARN        | The `Property` property defined in `CustomPropertyFile` is unknown                                                                                                                                                                                                                    | The specified property has not been recognised as a script configuration. Check the spelling or remove it from the custom configuration file.                                          |
| WARN        | The SQLServer module could not be found. Using SQLPS as a fallback.                                                                                                                                                                                                                   | The `SQLServer` module is not available so the deprecated `SQLPS` module will be used instead. No actio required.                                                                      |
| WARN        | No business rules were specified. Check the content of the specified CSV files (`CSVFiles`).                                                                                                                                                                                          | The specified CSV files do not contain any business rules identifiers or their format are incorrect. Check their content.                                                              |
| WARNING     | The names of some imported commands from the module 'SQLPS' include unapproved verbs that might make them less discoverable. To find the commands with unapproved verbs, run the Import-Module command again with the Verbose parameter. For a list of approved verbs, type Get-Verb. | The `SQLPS` module does not follow Microsoft's own guidelines. The `-DisableNameChecking` option is used when importing the module but the `Require` tag still triggers the warning.   |

<!-- Links -->

[pstk]: https://github.com/Akaizoku/PSTK "PowerShell Tool Kit repository"

[sqlps]: https://docs.microsoft.com/en-us/sql/powershell/download-sql-server-ps-module "SQL Server PowerShell Module"
