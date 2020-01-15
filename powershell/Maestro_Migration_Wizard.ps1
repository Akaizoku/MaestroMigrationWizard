#Requires -Version 3.0
#Requires -RunAsAdministrator

<#
  .SYNOPSIS
  Wizard for Maestro

  .DESCRIPTION
  Wizard for Maestro business rules management:
  - build:    Build business rules
  - clear:    Remove business rules from system
  - export:   Export business rules as XML files
  - import:   Import business rules from XML files
  - migrate:  Export business rules from source system and import them into the
              target system successively
  - prepare:  Process business rules (XML files) to prepare them for import

  .PARAMETER Action
  The action parameter determines the action to be performed by the wizard.

  The available actions are:
  - build:    Build business rules
  - clear:    Remove business rules from system
  - export:   Export business rules as XML files
  - import:   Import business rules from XML files
  - migrate:  Export business rules from source system and import them into the
              target system successively
  - prepare:  Process business rules (XML files) to prepare them for import

  .PARAMETER Environment
  The environment parameter corresponds to the source environment from which you
   want to export the business rules.

  The current available environments are:
  - DEV:  ALM development environment
  - TST:  ALM test environment
  - PRE:  ALM pre-production environment
  - PROD: ALM production environment

  .PARAMETER Files
  The files parameter corresponds to the list of CSV files containing the list
  of business rules to export, import, or migrate. If multiples files are to be
  included, use commas to separate them.

  .EXAMPLE
  .\Maestro_Migration_Wizard.ps1 -Action build -Environment DEV -Files custom,rules

  In this example, the Maestro Migration Wizard will build all the rules con-
  tained in the files custom.csv and rules.csv on the "DEV" environment.

  .EXAMPLE
  .\Maestro_Migration_Wizard.ps1 -Action clear -Environment DEV -Files custom,rules

  In this example, the Maestro Migration Wizard will remove all the rules con-
  tained in the files "custom.csv" and "rules.csv" from the "DEV" environment.

  .EXAMPLE
  .\Maestro_Migration_Wizard.ps1 -Action export -Environment DEV -Files custom,rules

  In this example, the Maestro Migration Wizard will export all the rules con-
  tained in the files custom.csv and rules.csv from the "DEV" environment.

  .EXAMPLE
  .\Maestro_Migration_Wizard.ps1 -Action export -Environment DEV -Files custom,rules -NoSQL

  In this example, the Maestro Migration Wizard will export all the rules con-
  tained in the files custom.csv and rules.csv from the "DEV" environment with-
  out checking first if the rules exist in the database.

  .EXAMPLE
  .\Maestro_Migration_Wizard.ps1 -Action import -Environment DEV -Files custom,rules

  In this example, the Maestro Migration Wizard will import all the rules con-
  tained in the files custom.csv and rules.csv from the "DEV" environment.

  .EXAMPLE
  .\Maestro_Migration_Wizard.ps1 -Action migrate -Environment DEV -Files custom,rules -Source OLD

  In this example, the Maestro Migration Wizard will export all the rules con-
  tained in the files custom.csv and rules.csv from the "OLD" environment, and
  import them in the "DEV" environment.

  .EXAMPLE
  .\Maestro_Migration_Wizard.ps1 -Action prepare -Environment DEV -Files custom,rules -Source OLD

  In this example, the Maestro Migration Wizard will process all the rules con-
  tained in the files custom.csv and rules.csv exported from the "OLD" environ-
  ment, and prepare them for import in the "DEV" environment.

  .NOTES
  File name:      Maestro_Migration_Wizard.ps1
  Author:         Florian Carrier
  Creation date:  15/08/2018
  Last modified:  15/04/2019
  Dependencies:   - PowerShell Tool Kit (PSTK)
                  - SQL Server PowerShell Module (SQLServer or SQLPS)

  .LINK
  https://github.com/Akaizoku/PSTK

  .LINK
  https://docs.microsoft.com/en-us/sql/powershell/download-sql-server-ps-module
#>

# ------------------------------------------------------------------------------
# Input parameters
# ------------------------------------------------------------------------------
[CmdletBinding ()]
Param (
  [Parameter (
    Position    = 1,
    Mandatory   = $true,
    HelpMessage = "Select an action to perform from the following list: build, clear, export, import, migrate, prepare."
  )]
  [ValidateSet (
    "Build",
    "Clear",
    "Export",
    "Import",
    "Migrate",
    "Prepare"
  )]
  [String]
  $Action,
  [Parameter (
    Position    = 2,
    Mandatory   = $true,
    HelpMessage = "Enter the environment to connect to"
  )]
  [ValidateNotNullOrEmpty ()]
  [Alias ("System", "Target")]
  [String]
  $Environment,
  [Parameter (
    Position    = 3,
    Mandatory   = $true,
    HelpMessage = "Enter the list of file names containing the rules to export/import (comma separated)"
  )]
  [ValidateNotNullOrEmpty ()]
  [Alias ("Rules", "List")]
  [String[]]
  $Files,
  # TODO remove if use of dynamic parameter
  [Parameter (
    Position    = 4,
    Mandatory   = $false,
    HelpMessage = "Source system containing the business rules"
  )]
  [ValidateNotNullOrEmpty ()]
  [Alias ("Origin")]
  [String]
  $Source,
  [Parameter (
    HelpMessage = "Define if the business rules have to be processed when importing"
  )]
  [Switch]
  $Prepare,
  [Parameter (
    HelpMessage = "Define if the export has to be done without any SQL checks"
  )]
  [Switch]
  $NoSQL
)
# # Add source system to process XML files after export
# DynamicParam {
#   $List = @("Migrate", "Prepare")
#   if ($Action -in $List -Or ($Action -eq "Import" -And $Prepare)) {
#     New-DynamicParameter -Name "Source" -Type "String" -Position 4 -Mandatory -HelpMessage "Source system containing the business rules"
#   } elseif ($Action -eq "Export") {
#     New-DynamicParameter -Name "NoSQL" -Type "Switch" -HelpMessage "Define if the export has to be done without any SQL checks"
#   }
# }
Begin {
  # ----------------------------------------------------------------------------
  # Global variables
  # ----------------------------------------------------------------------------
  # General
  $Path             = Split-Path -Path $MyInvocation.MyCommand.Definition
  $ParentPath       = Split-Path -Path $Path -Parent
  $WorkingDirectory = $ParentPath
  $ScriptName       = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
  # Configuration
  $LibDirectory     = Join-Path -Path $WorkingDirectory -ChildPath "lib"
  $ConfDirectory    = Join-Path -Path $WorkingDirectory -ChildPath "conf"
  $INIProperties    = "default.ini"
  $CustomProperties = "custom.ini"

  # ----------------------------------------------------------------------------
  # Required modules
  # ----------------------------------------------------------------------------
  # PowerShell Tool Kit
  try {
    Import-Module -Name "PSTK" -ErrorAction "Stop"
    Write-Log -Type "CHECK" -Message "The PSTK module was successfully loaded."
  } catch {
    try {
      Import-Module -Name (Join-Path -Path $LibDirectory -ChildPath "PSTK") -ErrorAction "Stop"
      Write-Log -Type "CHECK" -Message "The PSTK module was successfully loaded from the library directory."
    } catch {
      Throw "The PSTK library could not be loaded. Make sure it has been made available on the machine or manually put it in the ""$LibDirectory"" directory"
    }
  }
  # SQL Server
  if (!$NoSQL) {
    try {
      Import-Module -Name "SQLServer" -ErrorAction "Stop"
      Write-Log -Type "CHECK" -Message "The SQLServer module was successfully loaded."
    } catch {
      try {
        Write-Log -Type "WARN" -Message "The SQLServer module could not be loaded. Using SQLPS as a fallback."
        Push-Location
        Import-Module -Name "SQLPS" -DisableNameChecking -ErrorAction "Stop"
        Pop-Location
        Write-Log -Type "CHECK" -Message "The SQLPS module was successfully loaded."
      } catch {
        Write-Log -Type "ERROR" -Message "Neither the SQLServer or SQLPS modules could be loaded."
      }
    }
  }

  # ----------------------------------------------------------------------------
  # Configuration
  # ----------------------------------------------------------------------------
  # General settings
  $Properties = Get-Properties -File $INIProperties -Directory $ConfDirectory -Custom $CustomProperties
  # Check and update paths
  $RelativePaths        = [Ordered]@{
    ConfDirectory       = $Properties.ConfDirectory
    LibDirectory        = $Properties.LibDirectory
    LogDirectory        = $Properties.LogDirectory
    ExportDirectory     = $Properties.ExportDirectory
    ImportDirectory     = $Properties.ImportDirectory
    TransformDirectory  = $Properties.TransformDirectory
    CSVDirectory        = $Properties.CSVDirectory
    ScriptDirectory     = $Properties.ScriptDirectory
    SQLDirectory        = $Properties.SQLDirectory
  }
  foreach ($RelativePath in $RelativePaths.GetEnumerator()) {
    $AbsolutePath = Join-Path -Path $WorkingDirectory -ChildPath $RelativePath.Value
    if (-Not (Test-Path -Path $AbsolutePath)) {           
        Write-Log -Type "WARN" -Message "Path not found: $AbsolutePath"
        Write-Log -Type "INFO" -Message "Creating $AbsolutePath"
        New-Item -ItemType "Directory" -Path $AbsolutePath | Out-Null
    }
    $Properties.($RelativePath.Key) = $AbsolutePath
  }

  # Start time of the script execution
  $GlobalStartTime  = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
  $ISOTime          = Get-Date -Format "yyyy-MM-dd_HHmmss"
  # Start transcript
  $FormattedAction  = Format-String -String $Action -Format "TitleCase"
  $Transcript       = Join-Path -Path $Properties.LogDirectory -ChildPath "${ScriptName}_${FormattedAction}_${ISOTime}.log"
  Start-Script -Transcript $Transcript
  # System settings
  $Environments = Get-Properties -File $Properties.ServerProperties -Directory $Properties.ConfDirectory -Section
  # Check that user input is in the list
  if (-Not $Environments.$Environment) {
    Write-Log -Type "ERROR" -Message "The ""$Environment"" environment is not defined in $($Properties.ServerProperties)"
    Stop-Script 1
  }
  # Define system
  $System = $Environments.$Environment
  # Check source environment
  # TODO comment if use of dynamic parameter
  if ($Prepare -And !$Source) {
    Write-Log -Type "ERROR" -Message "The source environment (-Source) must be specified when the prepare switch is used"
    Stop-Script 1
  }
  # TODO uncomment if use of dynamic parameter
  # $Source = $PSBoundParameters["Source"]
  if ($Source) {
    if (-Not $Environments.$Source) {
      Write-Log -Type "ERROR" -Message "The ""$Source"" environment is not defined in $($Properties.ServerProperties)"
      Stop-Script 1
    }
    # Define source system
    $Origin = $Environments.$Source
  }
  # Check system properties
  $Missing = Compare-Properties -Properties $System -Required $Properties.ServerParameters
  if ($Missing.Count -gt 0) {
    foreach ($Property in $Missing) {
      Write-Log -Type "ERROR" -Message "$Property parameter not found in $($Properties.ServerProperties) for $($Environment.ToUpper()) environment"
    }
    Stop-Script 1
  }
  # Counter for number of rules
  $MaestroRuleCounter = 0
  # SQL commands arguments
  $SQLArguments       = [Ordered]@{
    ServerInstance    = $System.Server
    Database          = $System.Database
    QueryTimeOut      = 3600
    ConnectionTimeOut = 600
  }
  # Action specific outputs
  $ActionMsg  = [Ordered]@{
    "build"   = "built"
    "clear"   = "removed"
    "export"  = "exported"
    "import"  = "imported"
    "migrate" = "migrated"
    "prepare" = "prepared"
  }
  # Action specific outputs
  $ActionSequence = [Ordered]@{
    "build"   = "build"
    "clear"   = "clear"
    "export"  = "export"
    "import"  = "import"
    "migrate" = "migration"
    "prepare" = "preparation"
  }
  # Check Maestro engine path
  if ($Properties.MaestroEngine -eq "remote" -And $Source) {
    $MaestroInstance = $Origin.Database
  } else {
    $MaestroInstance = $System.Database
  }

  # ----------------------------------------------------------------------------
  # Store variables into global properties
  # ----------------------------------------------------------------------------
  $Properties.Add("Action"          , $FormattedAction                      )
  $Properties.Add("Environment"     , $Environment.ToUpper()                )
  $Properties.Add("Environments"    , $Environments                         )
  $Properties.Add("System"          , $System                               )
  $Properties.Add("Origin"          , $Origin                               )
  $Properties.Add("ISOTime"         , $ISOTime                              )
  $Properties.Add("SQLArguments"    , $SQLArguments                         )
  $Properties.Add("ActionMsg"       , $ActionMsg                            )
  $Properties.Add("MaestroInstance" , $MaestroInstance.Replace("_fsdb", "") )

  # ----------------------------------------------------------------------------
  # Modules
  # ----------------------------------------------------------------------------
  # PSTK and SQLPS are loaded autmatically by the "Require" tag
  $Maestro = Join-Path -Path $LibDirectory -ChildPath $ScriptName
  Import-Module -Name $Maestro -DisableNameChecking -Force
  # ----------------------------------------------------------------------------
  # Set global properties
  Set-GlobalProperties -Properties $Properties
}
Process {
  # Reset counter
  Edit-MaestroRuleCounter -Action "reset"
  # Output initialisation message
  Write-Log -Type "INFO" -Message "Connecting to $($Properties.Environment) environment ($($System.Server))"
  Write-Log -Type "INFO" -Message "Initiating $($ActionSequence.$Action) sequence"
  # Parse list of rules
  $Rules = Read-MaestroRule -Files $Files -Directory $Properties.CSVDirectory
  if (-Not (Test-MaestroRule -Rules $Rules)) {
    Write-Log -Type "WARN" -Message "No business rules were specified. Check the content of the specified CSV files ($Files)."
  } else {
    # Determine course of action
    Switch ($Action) {
      # Build business rules
      "Build"   { Build-MaestroRule -Rules $Rules -System $System }
      # Delete business rules from server
      "Clear"   { Clear-MaestroRule -Rules $Rules -System $System -Confirm }
      # Export rules fom source environment to XML
      "Export"  { Export-MaestroRule -Rules $Rules -System $System -NoSQL:$NoSQL }
      # Import rules fom XML to target environment
      "Import"  {
        if ($Prepare) { Import-MaestroRule -Rules $Rules -SourceSystem $Origin -TargetSystem $System -Prepare:$Prepare }
        else          { Import-MaestroRule -Rules $Rules -TargetSystem $System }
      }
      # Migrate rules fom source environment to target environment
      "Migrate" { Sync-MaestroRule -Rules $Rules -SourceSystem $Origin -TargetSystem $System }
      # Use Maestro XML Preprocessor to prepare XML files for import
      "Prepare" { Initialize-MaestroRule -Rules $Rules -SourceSystem $Origin -TargetSystem $System }
    }
  }
  # End of process output
  Write-Log -Type "INFO" -Message "End of $($ActionSequence.$Action) sequence"
  $GlobalEndTime  = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
  $ExecutionTime  = New-Timespan -Start $GlobalStartTime -End $GlobalEndTime
  $RuleCounter    = Edit-MaestroRuleCounter -Action "get"
  Switch ($RuleCounter) {
    0       { $OutputMessage = "No business rules were $($ActionMsg.$Action)"                         }
    1       { $OutputMessage = "$RuleCounter business rule was successfully $($ActionMsg.$Action)"    }
    default { $OutputMessage = "$RuleCounter business rules were successfully $($ActionMsg.$Action)"  }
  }
  Write-Log -Type "CHECK" -Message $OutputMessage
  Write-Log -Type "INFO"  -Message "Total execution time: $ExecutionTime"
}
End {    
  Stop-Script
}
