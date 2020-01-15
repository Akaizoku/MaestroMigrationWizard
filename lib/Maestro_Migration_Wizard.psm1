#Requires -Version 3.0

<#
  .SYNOPSIS
  Maestro Migration Wizard utlity library

  .DESCRIPTION
  This constitute a small library containing the different functions and proce-
  dures used by the Maestro Migration Wizard utility.

  .NOTES
  File name:      Maestro_Migration_Wizard.psm1
  Author:         Florian Carrier
  Creation date:  02/10/2018
  Last modified:  10/10/2018
  Dependencies:   - PowerShell Tool Kit (PSTK)
                  - SQL Server PowerShell Module (SQLServer or SQLPS)

  .LINK
  https://github.com/Akaizoku/PSTK

  .LINK
  https://docs.microsoft.com/en-us/sql/powershell/download-sql-server-ps-module
#>

# ------------------------------------------------------------------------------
# Global properties
# ------------------------------------------------------------------------------
function Set-GlobalProperties {
  <#
    .SYNOPSIS
    Set global properties

    .DESCRIPTION
    Set global properties

    .PARAMETER Properties
    The properties parameter corresponds to the properties to set.
  #>
  [CmdletBinding ()]
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "Properties"
    )]
    [ValidateNotNullOrEmpty ()]
    [System.Collections.Specialized.OrderedDictionary]
    $Properties
  )
  $Global:Properties = $Properties
}

# ------------------------------------------------------------------------------
# Export function
# ------------------------------------------------------------------------------
function Export-MaestroRule {
  <#
    .SYNOPSIS
    Export business rules as XML files.

    .DESCRIPTION
    Export specific set of business rules from a given environment as XML files.

    .PARAMETER Rules
    The rules parameter corresponds to the specific set of rules to export.

    .PARAMETER System
    The system parameter corresponds to the system from which to export the spe-
    cified business rules.

    .PARAMETER Directory
    The directory parameter correpsondst to the directory where to store the ex-
    ported business rules.

    .EXAMPLE
    Export-MaestroRule -Rules $Rules -System $System -Directory ".\export"

    In this example, the variables $Rules and $System are hastables containing
    respectively information about the business rules to export and the system
    to connect to. The function will then create XML files in the ".\export"
    directory.
  #>
  [CmdletBinding ()]
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "List of rules to export"
    )]
    [Alias ("List")]
    [System.Collections.Specialized.OrderedDictionary]
    $Rules,
    [Parameter (
      Position    = 2,
      Mandatory   = $true,
      HelpMessage = "System information"
    )]
    [Alias ("Src", "Source")]
    [System.Collections.Specialized.OrderedDictionary]
    $System,
    [Parameter (
      Position    = 3,
      Mandatory   = $false,
      HelpMessage = "Export directory"
    )]
    [String]
    $Directory = $Global:Properties.ExportDirectory,
    [Parameter (
      HelpMessage = "Disable SQL checks"
    )]
    [Switch]
    $NoSQL
  )
  # Output export directory
  Write-Log -Type "INFO" -Message "Export directory: $Directory"
  # Loop through rule groups
  foreach ($RuleGroup in $Rules.Values) {
    # Loop through rules
    foreach ($Rule in $RuleGroup.Values) {
      $Type     = $Rule.Type
      $Version  = $Rule.Version
      # Define file names
      $Name     = "${Type}_${Version}.xml"
      $LogName  = "Export_${Type}_${Version}_$($Global:Properties.ISOTime).xml"
      $File     = Join-Path -Path $Directory                      -ChildPath $Name
      $LogFile  = Join-Path -Path $Global:Properties.LogDirectory -ChildPath $LogName
      # Set-up Maestro exchange parameters
      $CmdArguments = @(
        "/server"   , $System.Server    ,
        "/database" , $System.Database  ,
        "/export"   , $File             ,
        "/set"      ,
        "/type"     , $Type             ,
        "/version"  , $Version          ,
        "/logfile"  , $LogFile
      )
      # Output initialisation message
      Write-Log -Type "INFO" -Message "Business rule $Type (version $Version)"
      # Check if rule exists
      if ((Find-MaestroRule -Type $Type -Version $Version -System $System) -Or $NoSQL) {
        # Export rule
        $Maestro = Invoke-MaestroExchange -Arguments $CmdArguments
        # Check if export was successful
        if ($Maestro) {
          Edit-MaestroRuleCounter -Action "increment"
          Write-Log -Type "CHECK" -Message "Business rule successfully $($Global:Properties.ActionMsg.Export) to $File"
        } else {
          # Output unknown error
          Write-Log -Type "WARN" -Message "Business rule $Type (version $Version) was not exported. Check the logs ($LogFile)"
        }
      } else {
        # Output warning message and ignore rule
        Write-Log -Type "WARN" -Message "Business rule $Type (version $Version) does not exists"
      }
    }
  }
}

# ------------------------------------------------------------------------------
# Import function
# ------------------------------------------------------------------------------
function Import-MaestroRule {
  <#
    .SYNOPSIS
    Export business rules as XML files

    .DESCRIPTION
    Export specific set of business rules from a given environment as XML files.

    .PARAMETER Rules
    The rules parameter corresponds to the specific set of rules to import.

    .PARAMETER TargetSystem
    The target system parameter corresponds to the environment to import the
    business rules to.

    .PARAMETER Prepare
    The prepare parameter is a switch to specify if the business rules have to
    be processed prior to the import.

    .PARAMETER SourceSystem
    The source sytem parameter corresponds to the original environment from
    which the business rules have been exported. It is mandatory to prepare the
    business rules for import.

    .EXAMPLE
    Import-MaestroRule -Rules $Rules -TargetSystem $System

    In this example, the (pre-processed) business rules contained in the import
    directory will be imported into the specified target system.

    .EXAMPLE
    Import-MaestroRule -Rules $Rules -SourceSystem $Origin -TargetSystem $System -Prepare

    In this example, the business rules exported from the origin system and con-
    tained in the export directory will be processed before importing them into
    the specified target system.
  #>
  [CmdletBinding ()]
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "List of rules to import"
    )]
    [System.Collections.Specialized.OrderedDictionary]
    $Rules,
    [Parameter (
      Position    = 2,
      Mandatory   = $true,
      HelpMessage = "Target system information"
    )]
    [Alias ("System")]
    [System.Collections.Specialized.OrderedDictionary]
    $TargetSystem = $Global:Properties.System,
    [Parameter (
      HelpMessage = "Defines if XML files need to be processed before being imported"
    )]
    [Switch]
    $Prepare
  )
  DynamicParam {
    if ($Prepare) {
      New-DynamicParameter -Name "SourceSystem" -Type "System.Collections.Specialized.OrderedDictionary" -Position 3 -Mandatory -Alias @("Src", "Origin")
    }
  }
  Begin {
    # Output import directory
    if ($Prepare) {
      $SourceSystem = $PSBoundParameters["SourceSystem"]
      Initialize-MaestroRule -Rules $Rules -SourceSystem $SourceSystem -TargetSystem $TargetSystem -SourceDirectory $Global:Properties.ExportDirectory -StagingDirectory $Global:Properties.TransformDirectory -TargetDirectory $Global:Properties.ImportDirectory
      Edit-MaestroRuleCounter -Action "reset"
    }
  }
  Process {
    # Select business rules to import
    Write-Log -Type "INFO" -Message "Import directory: $($Global:Properties.ImportDirectory)"
    $XMLFiles = @(Get-Object -Path $Global:Properties.ImportDirectory -Type "File" -Filter "*.xml")
    if ($XMLFiles.Count -gt 0) {
      $FilesToImport = @(Select-MaestroRule -Rules $Rules -Files $XMLFiles)
      if ($FilesToImport.Count -gt 0) {
        # Loop through files
        foreach ($File in $FilesToImport) {
          # Identify rule
          $Rule     = $File.BaseName
          $Type     = $Rule.Split("_")[0]
          $Version  = $Rule.Split("_")[1]
          # Define file names for logging
          $LogName  = "Import_${Type}_${Version}_$($Global:Properties.ISOTime).xml"
          $LogFile  = Join-Path -Path $Global:Properties.LogDirectory -ChildPath $LogName
          # Set-up Maestro exchange parameters
          $CmdArguments = @(
            "/server"         , $TargetSystem.Server    ,
            "/database"       , $TargetSystem.Database  ,
            "/import"         , $File.FullName          ,
            "/replace"        , "set"                   ,
            "/skipvalidation" , "true"                  ,
            "/logfile"        , $LogFile
          )
          # Output initialisation message
          Write-Log -Type "INFO" -Message "Business rule $Type (version $Version)"
          # Import rule
          $Maestro = Invoke-MaestroExchange -Arguments $CmdArguments
          # Check if import was successful
          if ($Maestro) {
            Edit-MaestroRuleCounter -Action "increment"
            Write-Log -Type "CHECK" -Message "Business rule $Type (version $Version) successfully $($Global:Properties.ActionMsg.Import) to Maestro"
          } else {
            # Output unknown error
            Write-Log -Type "WARN" -Message "Business rule $Type (version $Version) was not imported. Check the logs ($LogFile)"
          }
        }
      } else {
        Write-Log -Type "ERROR" -Message "No XML files corresponding to the specified business rules were found in the directory $($Global:Properties.ExportDirectory)"
        Stop-Script 1
      }
    } else {
      Write-Log -Type "ERROR" -Message "No XML files were found in the directory $($Global:Properties.ExportDirectory)"
      Stop-Script 1
    }
  }
}

# ------------------------------------------------------------------------------
# Prepare function
# ------------------------------------------------------------------------------
function Initialize-MaestroRule {
  <#
    .SYNOPSIS
    Prepare business rules for import

    .DESCRIPTION
    Prepare specific set of business rules for import using Maestro XML Prepro-
    cessor.

    .PARAMETER Rules
    The rules parameter corresponds to the specific set of rules to prepare.
  #>
  [CmdletBinding ()]
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "List of rules to prepare"
    )]
    [System.Collections.Specialized.OrderedDictionary]
    $Rules,
    [Parameter (
      Position    = 2,
      Mandatory   = $false,
      HelpMessage = "Source system information"
    )]
    [Alias ("Src", "Origin")]
    [System.Collections.Specialized.OrderedDictionary]
    $SourceSystem = $Global:Properties.Origin,
    [Parameter (
      Position    = 3,
      Mandatory   = $false,
      HelpMessage = "Target system information"
    )]
    [Alias ("System")]
    [System.Collections.Specialized.OrderedDictionary]
    $TargetSystem = $Global:Properties.System,
    [Parameter (
      Position    = 4,
      Mandatory   = $false,
      HelpMessage = "Source directory"
    )]
    [String]
    $SourceDirectory = $Global:Properties.ExportDirectory,
    [Parameter (
      Position    = 5,
      Mandatory   = $false,
      HelpMessage = "Staging area"
    )]
    [String]
    $StagingDirectory = $Global:Properties.TransformDirectory,
    [Parameter (
      Position    = 6,
      Mandatory   = $false,
      HelpMessage = "Target directory"
    )]
    [String]
    $TargetDirectory = $Global:Properties.ImportDirectory
  )
  # Select business rules to prepare for import
  Write-Log -Type "INFO" -Message "Source directory: $SourceDirectory"
  $XMLFiles = @(Get-Object -Path $SourceDirectory -Type "File" -Filter "*.xml")
  if ($XMLFiles.Count -gt 0) {
    $FilesToPrepare = @(Select-MaestroRule -Rules $Rules -Files $XMLFiles)
    if ($FilesToPrepare.Count -gt 0) {
      # XML files processing
      Write-Log -Type "INFO" -Message "Preparing XML files for import"
      $RulesReadyForProcess = Copy-MaestroRule -Files $FilesToPrepare -SourceDirectory $SourceDirectory -TargetDirectory $StagingDirectory
      if ($RulesReadyForProcess) {
        Write-Log -Type "INFO" -Message "Generating transformation manifest"
        $Manifest = Initialize-XMLTransform -SourceSystem $SourceSystem -TargetSystem $TargetSystem
        if ($Manifest) {
          Write-Log -Type "INFO" -Message "Processing XML files for import"
          $Transform = Invoke-XMLTransform -SourceDirectory $StagingDirectory -TargetDirectory $TargetDirectory -Clear
          if ($Transform) {
            for ($i=0; $i -lt $FilesToPrepare.Count; $i++) {
              Edit-MaestroRuleCounter -Action "increment"
            }
            $RuleCounter = Edit-MaestroRuleCounter -Action "get"
            Switch ($RuleCounter) {
              0       { $OutputMessage = "No XML files were $($Global:Properties.ActionMsg.Prepare)"                         }
              1       { $OutputMessage = "$RuleCounter XML file was successfully $($Global:Properties.ActionMsg.Prepare)"    }
              default { $OutputMessage = "$RuleCounter XML files were successfully $($Global:Properties.ActionMsg.Prepare)"  }
            }
            Write-Log -Type "CHECK" -Message $OutputMessage
          } else {
            Stop-Script 1
          }
        } else {
          Write-Log -Type "ERROR" -Message "An error occured while updating the transformation manifest"
          Stop-Script 1
        }
      } else {
        Write-Log -Type "ERROR" -Message "An error occured while preparing the XML files for import"
        Stop-Script 1
      }
    } else {
      Write-Log -Type "ERROR" -Message "No XML files corresponding to the specified business rules were found in the directory $SourceDirectory"
      Stop-Script 1
    }
  } else {
    Write-Log -Type "ERROR" -Message "No XML files were found in the directory $SourceDirectory"
    Stop-Script 1
  }
}

# ------------------------------------------------------------------------------
# Import function
# ------------------------------------------------------------------------------
function Invoke-XMLTransform {
  <#
    .SYNOPSIS
    Prepares XML file for import

    .DESCRIPTION
    Transforms business rules stored as XML file using the Maestro XML Pre-
    processor utility to prepare it for import.

    .PARAMETER Files
    The files parameter corresponds to the file to analyse and prepare.

    .PARAMETER Directory
    The directory parameter corresponds to the output directory for the generat-
    ed preparation file.

    .OUTPUTS
    [System.Boolean] Invoke-XMLTransform returns a boolean depending on the out-
    come of the call to Maestro XML Preprocessor utility.
  #>
  [CmdletBinding ()]
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "Directory containing the rules to process"
    )]
    [String]
    $SourceDirectory,
    [Parameter (
      Position    = 2,
      Mandatory   = $true,
      HelpMessage = "Directory to store the processed rules"
    )]
    [String]
    $TargetDirectory,
    [Parameter (
      HelpMessage = "Define if the source directory should be cleaned up after processing"
    )]
    [Switch]
    $Clear
  )
  Process {
    # Define file name for logging
    $LogName = "Transform_$($Global:Properties.ISOTime).xml"
    $LogFile = Join-Path -Path $Global:Properties.LogDirectory -ChildPath $LogName
    # Set-up Maestro XML processor parameters
    $CmdArguments = @(
      "/transform_folder" , $SourceDirectory , $TargetDirectory
      "/log"              , $LogFile
    )
    try {
      # Process XML files
      $Transform = Invoke-MaestroXMLProcessor -Arguments $CmdArguments
      return $Transform
    } catch {
      Write-Log -Type "ERROR" -Message "An error occured while preparing the XML files for import. Check the logs ($LogFile)."
      return $false
    }
  }
  End {
    # Clear preparation directry
    if ($Clear -And $SourceDirectory -ne $null) {
      Remove-Item -Path "$SourceDirectory\*" -Recurse -Force
    }
  }
}

# ------------------------------------------------------------------------------
# Import function
# ------------------------------------------------------------------------------
function Initialize-XMLTransform {
  <#
    .SYNOPSIS
    Prepares XML file for import

    .DESCRIPTION
    Transforms business rules stored as XML file using the Maestro XML Pre-
    processor utility to prepare it for import.

    .PARAMETER Files
    The files parameter corresponds to the file to analyse and prepare.

    .PARAMETER Directory
    The directory parameter corresponds to the output directory for the generat-
    ed preparation file.

    .OUTPUTS
    [System.Boolean] Initialize-XMLTransform returns a boolean depending on the out-
    come of the call to Maestro XML Preprocessor utility.
  #>
  [CmdletBinding ()]
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "Source system information"
    )]
    [Alias ("Src", "Origin")]
    [System.Collections.Specialized.OrderedDictionary]
    $SourceSystem,
    [Parameter (
      Position    = 2,
      Mandatory   = $true,
      HelpMessage = "Target system information"
    )]
    [Alias ("System")]
    [System.Collections.Specialized.OrderedDictionary]
    $TargetSystem,
    [Parameter (
      Position    = 3,
      Mandatory   = $false,
      HelpMessage = "Staging area"
    )]
    [Alias ("TransformDirectory")]
    [String]
    $StagingDirectory = $Global:Properties.TransformDirectory
  )
  $Analyse = Invoke-XMLAnalyse -Directory $StagingDirectory
  if ($Analyse) {
    $Manifest = Join-Path -Path $StagingDirectory -ChildPath $Global:Properties.Manifest
    $XML      = New-Object -TypeName System.XML.XMLDocument
    $XML.Load($Manifest)
    # Reference table for processing
    $References   = [Ordered]@{
      "Database"  = [Ordered]@{
        old       = "fsdb"
        new       = $TargetSystem.Database
      }
      "Staging"   = [Ordered]@{
        old       = $SourceSystem.Staging
        new       = $TargetSystem.Staging
      }
    }
    # Serach for values to update
    $Nodes = [Ordered]@{
      Applications  = "transformations/application_set/as_database"
      Variables     = "transformations/variable"
    }
    foreach ($Node in $Nodes.Values) {
      $Values = $XML.SelectNodes($Node)
      foreach ($Value in $Values) {
        $OldValue = $Value | Select-Object -ExpandProperty "old_value"
        foreach ($Reference in $References.Values) {
          if ($OldValue -eq $Reference.old) {
            Write-Debug "Updating ""$($Reference.old)"" to ""$($Reference.new)"""
            $Value.SetAttribute("new_value", $Reference.new)
          }
        }
      }
    }
    try {
      # Save changes to XML file
      $XML.Save($Manifest)
      return $true
    } catch {
      return $false
    }
  } else {
    # Error message already defined in Invoke-XMLAnalyse
    Stop-Script 1
  }
}

# ------------------------------------------------------------------------------
# Initialise transform XML file for import
# ------------------------------------------------------------------------------
function Invoke-XMLAnalyse {
  <#
    .SYNOPSIS
    Prepares transform XML manifest for import sequence

    .DESCRIPTION
    Generates a transform manifest as an XML file using the Maestro XML Pre-
    processor utility to prepare business rules for import.

    .PARAMETER Directory
    The directory parameter corresponds to the directory containing the business
    rules as XML files that need to be analysed.

    .OUTPUTS
    [System.Boolean] Invoke-XMLAnalyse returns a boolean depending on the out-
    come of the call to Maestro XML Preprocessor utility.
  #>
  [CmdletBinding ()]
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "Directory containing the XML files to analyse"
    )]
    [String]
    $Directory = $Global:Properties.TransformDirectory
  )
  # Define file name for logging
  $LogName  = "Analyse_$($Global:Properties.ISOTime).xml"
  $LogFile  = Join-Path -Path $Global:Properties.LogDirectory -ChildPath $LogName
  # Set-up Maestro XML processor parameters
  $CmdArguments = @(
    "/analyse_folder" , $Directory ,
    "/log"            , $LogFile
  )
  try {
    # Generate transform manifest
    $Analyse = Invoke-MaestroXMLProcessor -Arguments $CmdArguments
    return $Analyse
  } catch {
    Write-Log -Type "ERROR" -Message "An error occured while preparing the XML files for import. Check the logs ($LogFile)."
    return $false
  }
}

# ------------------------------------------------------------------------------
# Copy XML files
# ------------------------------------------------------------------------------
function Copy-MaestroRule {
  <#
    .SYNOPSIS
    Copy XML files from one location to another

    .DESCRIPTION
    Copy XML files from a specified source location to a specified target loca-
    tion

    .PARAMETER Files
    The files parameter corresponds to the files to move

    .PARAMETER Source
    The source parameter corresponds to the source directory contain-
    ing the XML files

    .PARAMETER Target
    The target parameter corresponds to the target directory where to
    copy the XML files

    .OUTPUTS
    [System.Boolean] Copy-MaestroRule returns a boolean depending on the out-
    come of the copy.
  #>
  [CmdletBinding ()]
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "XML files to move"
    )]
    [ValidateNotNullOrEmpty ()]
    [System.Collections.ArrayList]
    $Files,
    [Parameter (
      Position    = 2,
      Mandatory   = $true,
      HelpMessage = "Source directory"
    )]
    [ValidateNotNullOrEmpty ()]
    [String]
    $SourceDirectory,
    [Parameter (
      Position    = 3,
      Mandatory   = $true,
      HelpMessage = "Target directory"
    )]
    [ValidateNotNullOrEmpty ()]
    [String]
    $TargetDirectory
  )
  $Outcome = $false
  try {
    # Copy XML files to target directory
    foreach ($File in $Files) {
      $SourceFile = Join-Path -Path $SourceDirectory -ChildPath $File.Name
      if (Test-Path -Path $SourceFile) {
        $TargetFile = Join-Path -Path $TargetDirectory -ChildPath $File.Name
        Copy-Item -Path $SourceFile -Destination $TargetFile -Force
        # If at least one rule was moved, return true
        $Outcome = $true
      } else {
        Write-Log -Type "WARN" -Message "$($File.Name) was not found in directory $SourceDirectory"
      }
    }
    return $Outcome
  } catch {
    Write-Log -Type "ERROR" -Message "$_"
    return $Outcome
  }
}

# ------------------------------------------------------------------------------
# Wrapper for Copy-MaestroRule
# ------------------------------------------------------------------------------
function Move-MaestroRule {
  <#
    .SYNOPSIS
    Wrapper to monitor Copy-MaestroRule

    .DESCRIPTION
    Wrapper to monitor Copy-MaestroRule

    .PARAMETER Rules
    The rules parameter corresponds to the business rules to move

    .PARAMETER Source
    The source parameter corresponds to the source directory contain-
    ing the XML files

    .PARAMETER Target
    The target parameter corresponds to the target directory where to
    copy the XML files

    .OUTPUTS
    [System.Boolean] Move-MaestroRule returns a boolean depending on the out-
    come of the copy.
  #>
  [CmdletBinding ()]
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "List of rules to move"
    )]
    [Alias ("List")]
    [System.Collections.Specialized.OrderedDictionary]
    $Rules,
    [Parameter (
      Position    = 2,
      Mandatory   = $true,
      HelpMessage = "Source directory"
    )]
    [ValidateNotNullOrEmpty ()]
    [String]
    $Source = $Global:Properties.ImportDirectory,
    [Parameter (
      Position    = 3,
      Mandatory   = $true,
      HelpMessage = "Target directory"
    )]
    [ValidateNotNullOrEmpty ()]
    [String]
    $Target = $Global:Properties.TransformDirectory
  )
  Write-Log -Type "INFO" -Message "Source directory $Source"
  Write-Log -Type "INFO" -Message "Target directory $Target"
  # Select business rules to move
  $XMLFiles = @(Get-Object -Path $Source -Type "File" -Filter "*.xml")
  $Files    = @(Select-MaestroRule -Rules $Rules -Files $XMLFiles)
  # Move files
  foreach ($File in $Files) {
    Write-Log -Type "INFO" -Message "Moving file $($File.Name)"
    $Wrapper = New-Object -TypeName System.Collections.ArrayList
    [Void]$Wrapper.Add($File)
    $Copy = Copy-MaestroRule -Files $Wrapper -Source $Source -Target $Target
    if ($Copy) {
      Edit-MaestroRuleCounter -Action "increment"
    }
  }
  $Counter = Edit-MaestroRuleCounter -Action "get"
  if ($Counter -eq 0) {
    Write-Log -Type "ERROR" -Message "An error occured while moving files"
    Stop-Script 1
  }
}

# ------------------------------------------------------------------------------
# Preprocess XML files for import
# ------------------------------------------------------------------------------
function Invoke-MaestroXMLProcessor {
  <#
    .SYNOPSIS
    Call Maestro XML Preprocessor application

    .DESCRIPTION
    Call Maestro XML Preprocessor application using a given set of parameters.

    .PARAMETER Arguments
    The Arguments parameter contains the list of parameters to pass on to the Maestro XML Preprocessor application.
  #>
  [CmdletBinding ()]
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "Arguments for Maestro XML Preprocessor"
    )]
    [ValidateNotNullOrEmpty ()]
    [Alias ("Args")]
    [String[]]
    $Arguments
  )
  $Output = $false
  # Call Maestro Exchange command line utility
  $MaestroXMLProcessor  = Get-MaestroUtility -Utility "XMLProcessor"
  $Maestro              = & $MaestroXMLProcessor $Arguments
  if ($Maestro -notmatch "messagetype=""Error""") {
    $Output = $true
  }
  return $Output
}

# ------------------------------------------------------------------------------
# Migrate function
# ------------------------------------------------------------------------------
function Sync-MaestroRule {
  <#
    .SYNOPSIS
    Migrate business rules from one nvironment to another

    .DESCRIPTION
    Migrate specific set of business rules from a given source environment to a
    target environment

    .PARAMETER Rules
    The rules parameter corresponds to the list of business rules to migrate
    from one environment to another.

    .PARAMETER SourceSystem
    The source system parameter corresponds to the system from which to export
    specified business rules.

    .PARAMETER TargetSystem
    The target system corresponds to the system where to import the specified
    business rules.

    .EXAMPLE
    Sync-MaestroRule -Rules $Rules -SourceSystem $Origin -TargetSystem $System

    In this example, the business rules listed in $Rules will be exported from
    the origin system and successively imported into the target system.
  #>
  [CmdletBinding ()]
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "List of rules to export"
    )]
    [Alias ("List")]
    [System.Collections.Specialized.OrderedDictionary]
    $Rules,
    [Parameter (
      Position    = 2,
      Mandatory   = $true,
      HelpMessage = "Source system"
    )]
    [System.Collections.Specialized.OrderedDictionary]
    $SourceSystem,
    [Parameter (
      Position    = 3,
      Mandatory   = $true,
      HelpMessage = "Target system"
    )]
    [System.Collections.Specialized.OrderedDictionary]
    $TargetSystem
  )
  Process {
    # Export
    Write-Log -Type "INFO" -Message "Beginning export process"
    Export-MaestroRule -Rules $Rules -System $SourceSystem -Directory $Global:Properties.ExportDirectory
    Write-Log -Type "CHECK" -Message "Export successful"
    # Import
    Write-Log -Type "INFO" -Message "Beginning import process"
    Import-MaestroRule -Rules $Rules -SourceSystem $SourceSystem -TargetSystem $TargetSystem -Prepare
    Write-Log -Type "CHECK" -Message "Import successful"
  }
}

# ------------------------------------------------------------------------------
# Maestro Utilities executables
# ------------------------------------------------------------------------------
function Get-MaestroUtility {
  [CmdletBinding ()]
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "Utility"
    )]
    [ValidateSet (
      "Exchange",
      "XMLProcessor"
    )]
    [String]
    $Utility
  )
  Switch ($Utility) {
    "Exchange"      { $Executable = $Global:Properties.MaestroExchangeExe  }
    "XMLProcessor"  { $Executable = $Global:Properties.MaestroXMLProcessor }
  }
  $MaestroPath      = Join-Path -Path $Global:Properties.IISPath  -ChildPath $Global:Properties.MaestroRoot
  $MaestroDir       = Join-Path -Path $MaestroPath                -ChildPath "$($Global:Properties.MaestroInstance)_Portal"
  $MaestroExchange  = Join-Path -Path $MaestroDir                 -ChildPath $Global:Properties.MaestroDir
  $MaestroExe       = Join-Path -Path $MaestroExchange            -ChildPath $Executable
  return $MaestroExe
}

# ------------------------------------------------------------------------------
# Maestro Exchange call function
# ------------------------------------------------------------------------------
function Invoke-MaestroExchange {
  <#
    .SYNOPSIS
    Call Maestro Exchange application

    .DESCRIPTION
    Call Maestro Exchange application using a given set of parameters.

    .PARAMETER Arguments
    The Arguments parameter contains the list of parameters to pass on to the Maestro Exchange application.

    .NOTES

  #>
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "Arguments for Maestro Exchange"
    )]
    [ValidateNotNullOrEmpty ()]
    [Alias ("Args")]
    [String[]]
    $Arguments
  )
  $Output = $false
  # Call Maestro Exchange command line utility
  $MaestroExchange  = Get-MaestroUtility -Utility "Exchange"
  Start-Process -FilePath $MaestroExchange -ArgumentList $Arguments -Wait -NoNewWindow -RedirectStandardOutput "NUL"
  # Check Maestro log for errors
  for ($i = 0; $i -lt $Arguments.Length; $i++) {
    if ($Arguments[$i] -eq "/logfile") {
      $Index = $i + 1
      break
    }
  }
  if ($Index) {
    $MaestroLog = Get-Content -Path $Arguments[$Index] -Raw
    if ($MaestroLog -notmatch "Error") {
      $Output = $true
    }
  } else {
    Write-Log -Type "WARN" -Message "An error occured while calling the Maestro Exchange command line utility"
  }
  return $Output
}

# ------------------------------------------------------------------------------
# Search function
# ------------------------------------------------------------------------------
function Find-MaestroRule {
  <#
    .SYNOPSIS
    Search for a business rules in Maestro

    .DESCRIPTION
    Search for  a specific business rules in Maestro.

    .PARAMETER Type
    The Type parameter corresponds to the attribute "mex_type".

    .PARAMETER Version
    The Version parameter corresponds to the attribute "version_id".

    .EXAMPLE
    Find-MaestroRule -Type 1 -Version 1
  #>
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "mex_type"
    )]
    [ValidateNotNullOrEmpty ()]
    [String]
    $Type,
    [Parameter (
      Position    = 2,
      Mandatory   = $true,
      HelpMessage = "version_id"
    )]
    [ValidateNotNullOrEmpty ()]
    [String]
    $Version,
    [Parameter (
      Position    = 3,
      Mandatory   = $true,
      HelpMessage = "Source system"
    )]
    [ValidateNotNullOrEmpty ()]
    [System.Collections.Specialized.OrderedDictionary]
    $System = $Global:Properties.System
  )
  $SearchQuery = Join-Path -Path $Global:Properties.SQLDirectory -ChildPath $Global:Properties.SearchScript
  # Check that script exists
  if (Test-Path -Path $SearchQuery) {
    # Get SQL arguments and set system variables
    $SQLArguments = Copy-OrderedHashtable -Hashtable $Global:Properties.SQLArguments -Deep
    $SQLArguments.ServerInstance  = $System.Server
    $SQLArguments.Database        = $System.Database
    # Check that database can be reached
    $Check = Test-SQLConnection -Server $SQLArguments.ServerInstance -Database $SQLArguments.Database
    if ($Check) {
      # Amend script to use respective values
      $SQLQuery = Get-Content $SearchQuery -Raw
      $Tags     = [Ordered]@{
        Type    = [Ordered]@{
          Token = "#{mex_type}"
          Value = $Type
        }
        Version = [Ordered]@{
          Token = "#{version_id}"
          Value = $Version
        }
      }
      $SQLQuery = Set-Tags -String $SQLQuery -Tags $Tags
      # Execute SQL query
      $Search   = Invoke-SqlCmd @SQLArguments -Query $SQLQuery | Select-Object -ExpandProperty "mex_id"
      if ($Search -gt 0) {
        return $true
      } else {
        return $false
      }
    } else {
      Write-Log -Type "ERROR" -Message "Unable to connect to $($Global:Properties.Environment) database server ($($SQLArguments.ServerInstance))"
      Stop-Script 1
    }
  } else {
    Write-Log -Type "ERROR" -Message "Cannot find ""$($Global:Properties.SearchScript)"" file in directory $($Global:Properties.SQLDirectory)."
    Stop-Script 1
  }
}

# ------------------------------------------------------------------------------
# Delete function
# ------------------------------------------------------------------------------
function Remove-MaestroRule {
  <#
    .SYNOPSIS
    Delete a business rule from Maestro

    .DESCRIPTION
    Delete a specific business rule from Maestro.

    .PARAMETER Type
    The Type parameter corresponds to the attribute "mex_type".

    .PARAMETER Version
    The Version parameter corresponds to the attribute "version_id".

    .EXAMPLE
    Remove-MaestroRule -Type 1 -Version 1
  #>
  [CmdletBinding ()]
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "mex_type"
    )]
    [ValidateNotNullOrEmpty ()]
    [String]
    $Type,
    [Parameter (
      Position    = 2,
      Mandatory   = $true,
      HelpMessage = "version_id"
    )]
    [ValidateNotNullOrEmpty ()]
    [String]
    $Version,
    [Parameter (
      Position    = 3,
      Mandatory   = $true,
      HelpMessage = "System information"
    )]
    [ValidateNotNullOrEmpty ()]
    [Alias ("Src", "Source", "Environment")]
    [System.Collections.Specialized.OrderedDictionary]
    $System
  )
  # Check that script exists
  $ClearQuery = Join-Path -Path $Global:Properties.SQLDirectory -ChildPath $Global:Properties.ClearScript
  if (Test-Path -Path $ClearQuery) {
    # Get SQL arguments and set system variables
    $SQLArguments = Copy-OrderedHashtable -Hashtable $Global:Properties.SQLArguments -Deep
    $SQLArguments.ServerInstance  = $System.Server
    $SQLArguments.Database        = $System.Database
    # Check that database can be reached
    $CheckConnection = Test-SQLConnection -Server $SQLArguments.ServerInstance -Database $SQLArguments.Database
    if ($CheckConnection) {
      # Amend script to use respective values
      $SQLQuery = Get-Content $ClearQuery -Raw
      $Tags     = [Ordered]@{
        Type    = [Ordered]@{
          Token = "#{mex_type}"
          Value = $Type
        }
        Version = [Ordered]@{
          Token = "#{version_id}"
          Value = $Version
        }
      }
      $SQLQuery = Set-Tags -String $SQLQuery -Tags $Tags
      # Execute SQL query
      $Delete = Invoke-SqlCmd @SQLArguments -Query $SQLQuery | Select-Object -ExpandProperty "deleted"
      return $Delete
    } else {
      Write-Log -Type "ERROR" -Message "Unable to connect to $($Global:Properties.Environment) database server ($($SQLArguments.ServerInstance))"
      Stop-Script 1
    }
  } else {
    Write-Log -Type "ERROR" -Message "Cannot find ""$($Global:Properties.ClearScript)"" file in directory $($Global:Properties.SQLDirectory)."
    Stop-Script 1
  }
}

# ------------------------------------------------------------------------------
# Clear function
# ------------------------------------------------------------------------------
function Clear-MaestroRule {
  <#
    .SYNOPSIS
    Clear business rules from Maestro

    .DESCRIPTION
    Clear a specific set of business rules from Maestro.

    .PARAMETER Rules
    The Rules parameter contains the list of parameters to pass on to the
    Maestro Exchange application.

    .EXAMPLE
    Clear-MaestroRule -Rules @(@(("1","1"),("2","1")),@(("3","5"))) -System $System
  #>
  [CmdletBinding ()]
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "List of rules to delete"
    )]
    [Alias ("List")]
    $Rules,
    [Parameter (
      Position    = 2,
      Mandatory   = $true,
      HelpMessage = "System information"
    )]
    [ValidateNotNullOrEmpty ()]
    [Alias ("Src", "Source", "Environment")]
    [System.Collections.Specialized.OrderedDictionary]
    $System,
    [Parameter (
      HelpMessage = "Disable confirmation message"
    )]
    [Switch]
    $Confirm
  )
  Begin {
    if (!$Confirm) {
      $Caption      = "WARNING"
      $Message      = "The clear sequence will permanently remove the selected business rules from the system. Do you want to proceed?"
      $Yes          = New-Object -TypeName System.Management.Automation.Host.ChoiceDescription -ArgumentList ("&Yes", "Yes")
      $No           = New-Object -TypeName System.Management.Automation.Host.ChoiceDescription -ArgumentList ("&No" , "No")
      $Options      = [System.Management.Automation.Host.ChoiceDescription[]]($Yes, $No)
      $Confirmation = $Host.UI.PromptForChoice($Caption, $Message, $Options, 1)
      # If answer is no (index = 1)
      if ($Confirmation -eq 1) {
        Write-Log -Type "WARN" -Message "Clear sequence terminated by user"
        Stop-Script
      }
    }
  }
  Process {
    # Get SQL arguments and set system variables
    $SQLArguments = Copy-OrderedHashtable -Hashtable $Global:Properties.SQLArguments -Deep
    $SQLArguments.ServerInstance  = $System.Server
    $SQLArguments.Database        = $System.Database
    # Loop through groups of rule
    foreach ($Key in $Rules.Keys) {
      $Group = $Rules.$Key
      # Loop through rules
      foreach ($Key in $Group.Keys) {
        $Rule     = $Group.$Key
        $Type     = $Rule.Type
        $Version  = $Rule.Version
        # Check if rule exists
        if (Find-MaestroRule @Rule -System $System) {
          # Remove rule
          $Delete = Remove-MaestroRule @Rule -System $System
          if ($Delete -eq 1) {
            # Remove rule and output message
            Write-Log -Type "CHECK" -Message "The business rule $Type (version $Version) was successfully removed."
            Edit-MaestroRuleCounter -Action "increment"
          } else {
            Write-Log -Type "ERROR" -Message "An error occured while removing the business rule $Type (version $Version) from the database."
            Stop-Script 1
          }
        } else {
          # Output warning and ignore rule
          Write-Log -Type "WARN" -Message "The business rule $Type (version $Version) does not exist in the database."
        }
      }
    }
  }
}

# ------------------------------------------------------------------------------
# Rule count function
# ------------------------------------------------------------------------------
function Edit-MaestroRuleCounter {
  <#
    .SYNOPSIS
    Call Maestro Exchange application

    .DESCRIPTION
    Call Maestro Exchange application using a given set of parameters.

    .PARAMETER Arguments
    The Arguments parameter contains the list of parameters to pass on to the Maestro Exchange application.

    .EXAMPLE
    Edit-MaestroRuleCounter -Action "increment"
  #>
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "Action to execute"
    )]
    [ValidateSet (
      "decrement",
      "get",
      "increment",
      "reset"
    )]
    [String]
    $Action
  )
  Switch ($Action) {
    "decrement" { $Global:MaestroRuleCounter -= 1   }
    "get"       { return $Global:MaestroRuleCounter }
    "increment" { $Global:MaestroRuleCounter += 1   }
    "reset"     { $Global:MaestroRuleCounter  = 0   }
  }
}

# ------------------------------------------------------------------------------
# Parsing function for CSV files containing business rules IDs
# ------------------------------------------------------------------------------
function Read-MaestroRule {
  <#
    .SYNOPSIS
    Parse list of CSV files to identify business rules.

    .DESCRIPTION
    Parse list of CSV files to identify business rules.

    .PARAMETER Files
    The Files parameter should be a list of CSV files containing business rules identifiers.

    .PARAMETER Directory
    The Directory parameter should be the raltive path to the folder containing the CSV files.

    .OUTPUTS
    [System.Collections.Specialized.OrderedDictionary] Read-MaestroRule returns
    an ordered hashtable containing the business rules in their respective rule
    groups.
  #>
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "Files to read"
    )]
    [ValidateNotNullOrEmpty ()]
    [Alias ("Rules", "List")]
    [String[]]
    $Files,
    [Parameter (
      Position    = 2,
      Mandatory   = $true,
      HelpMessage = "Directory containing the files"
    )]
    [ValidateNotNullOrEmpty ()]
    [String]
    $Directory
  )
  # Create container to store rule groups
  $RuleGroups = New-Object -TypeName System.Collections.Specialized.OrderedDictionary
  $Counter    = 0
  # Loop through list of files
  foreach ($File in $Files) {
    # Check that file exists
    if ($File -like "*.csv") { $File = $File.Replace(".csv", "") }
    $CSVFile = Join-Path -Path $Directory -ChildPath "$File.csv"
    if (Test-Path -Path $CSVFile) {
      # Create New rule group container
      $RuleGroup = New-Object -TypeName System.Collections.Specialized.OrderedDictionary
      # Open and read CSV file
      Import-Csv -Path $CSVFile | foreach {
        # Identify rule type and version
        $Type     = $_.Type
        $Version  = $_.Version
        # Create rule object
        $Rule = [Ordered]@{
          Type    = "$Type"
          Version = "$Version"
        }
        # Increment rule counter
        $Counter += 1
        # Store rule into rule group
        $RuleGroup.Add($Counter, $Rule)
      }
      # Store rule group into global list of groups
      $RuleGroups.Add($File, $RuleGroup)
    } else {
      Write-Log -Type "WARN" -Message "The ""$File.csv"" file was not found in directory $Directory"
    }
  }
  # Return list of rule groups
  return $RuleGroups
}

# ------------------------------------------------------------------------------
# Function to select business rules to import
# ------------------------------------------------------------------------------
function Select-MaestroRule {
  <#
    .SYNOPSIS
    Parse list of CSV files to identify business rules and match with XML files

    .DESCRIPTION
    Parse list of CSV files to identify business rules and match with XML files

    .PARAMETER Rules
    The rules parameter should be a list of business rules to select..

    .PARAMETER Files
    The files parameter should be a list of XML files.

    .OUTPUTS
    [System.Collections.ArrayList] Select-MaestroRule returns an array-list of files.
  #>
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "Rules to select"
    )]
    [ValidateNotNullOrEmpty ()]
    [System.Collections.Specialized.OrderedDictionary]
    $Rules,
    [Parameter (
      Position    = 2,
      Mandatory   = $true,
      HelpMessage = "Files containing the rules details"
    )]
    [ValidateNotNullOrEmpty ()]
    [Alias ("List")]
    [System.Collections.ArrayList]
    $Files
  )
  $SelectedFiles = New-Object -TypeName System.Collections.ArrayList
  # Loop through groups of rules
  foreach ($Group in $Rules.Values) {
    # Loop through rules
    foreach ($Rule in $Group.Values) {
      $Check = $false
      foreach ($File in $Files) {
        # Identify rule
        $Filename = $File.BaseName
        $Type     = $Filename.Split("_")[0]
        $Version  = $Filename.Split("_")[1]
        if ($Rule.Type -eq $Type -And $Rule.Version -eq $Version) {
          [Void]$SelectedFiles.Add($File)
          $Check = $true
        }
      }
      if (!$Check) {
        Write-Log -Type "WARN" -Message "No XML file was found for business rule $($Rule.Type) (version $($Rule.Version))"
      }
    }
  }
  # TODO force array-list format
  # /!\ Does not work as expected when only one value
  return @($SelectedFiles)
}

# ------------------------------------------------------------------------------
# Build business rules
# ------------------------------------------------------------------------------
function Build-MaestroRule {
  <#
    .SYNOPSIS
    Builds business rules

    .DESCRIPTION
    Builds specified business rules.

    .PARAMETER Rules
    The rules parameter corresponds to the business rules to build.

    .NOTES
    TODO Only build specified business rules
  #>
  [CmdletBinding ()]
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "List of business rules to build"
    )]
    [ValidateNotNullOrEmpty ()]
    [Alias ("List")]
    [System.Collections.Specialized.OrderedDictionary]
    $Rules,
    [Parameter (
      Position    = 2,
      Mandatory   = $true,
      HelpMessage = "System information"
    )]
    [ValidateNotNullOrEmpty ()]
    [Alias ("Src", "Source", "Environment")]
    [System.Collections.Specialized.OrderedDictionary]
    $System = $Global:Properties.System
  )
  # Check that script exists
  $BuildScript = Join-Path -Path $Global:Properties.SQLDirectory -ChildPath $Global:Properties.BuildScript
  if (Test-Path -Path $BuildScript) {
    # Get SQL arguments and set system variables
    $SQLArguments = Copy-OrderedHashtable -Hashtable $Global:Properties.SQLArguments -Deep
    $SQLArguments.ServerInstance  = $System.Server
    $SQLArguments.Database        = $System.Database
    # Check that database can be reached
    $CheckConnection = Test-SQLConnection -Server $SQLArguments.ServerInstance -Database $SQLArguments.Database
    if ($CheckConnection) {
      # Loop through rule groups
      foreach ($RuleGroup in $Rules.Values) {
        # Loop through rules
        foreach ($Rule in $RuleGroup.Values) {
          $Type     = $Rule.Type
          $Version  = $Rule.Version
          # Replace tags and execute script
          $Tags     = [Ordered]@{
            Type    = [Ordered]@{
              Token = "#{mex_type}"
              Value = $Type
            }
            Version = [Ordered]@{
              Token = "#{version_id}"
              Value = $Version
            }
          }
          # Output initialisation message
          Write-Log -Type "INFO" -Message "Business rule $Type (version $Version)"
          $SQLQuery = Get-Content -Path $BuildScript -Raw
          $SQLQuery = Set-Tags -String $SQLQuery -Tags $Tags
          $Build    = Invoke-SqlCmd @SQLArguments -Query $SQLQuery
          # TODO add SQL return to check outcome and count rules built
          if ($true) {
            Write-Log -Type "CHECK" -Message "Business rule $Type (version $Version) was successfully built"
          } else {
            Write-Log -Type "WARN" -Message "Business rule $Type (version $Version) could not be built"
          }
        }
      }
    } else {
      Write-Log -Type "ERROR" -Message "Unable to connect to $($Global:Properties.Environment) database server ($($SQLArguments.ServerInstance))"
      Stop-Script 1
    }
  } else {
    Write-Log -Type "ERROR" -Message "Cannot find ""$($Global:Properties.BuildScript)"" file in directory $($Global:Properties.SQLDirectory)."
    Stop-Script 1
  }
}


function Test-MaestroRule {
  <#
    .SYNOPSIS
    Check that list of business rules is not empty

    .DESCRIPTION
    Ensure that the specified list of business rules is not empty

    .PARAMETER Rules
    The rules parameter corresponds to the list of business rules

    .OUTPUTS
    [System.Boolean] Test-MaestroRule returns a boolean depending if the list of
    business rules is empty or not.

    .EXAMPLE
    Test-MaestroRule -Rules $Rules

    In this example, Test-MaestroRule will check if the ordered hastables $Rules
    contains some business rules.
  #>
  [CmdletBinding ()]
  Param (
    [Parameter (
      Position    = 1,
      Mandatory   = $true,
      HelpMessage = "List of business rules to check"
    )]
    [ValidateNotNull ()]
    [System.Collections.Specialized.OrderedDictionary]
    $Rules
  )
  Process {
    $Check = $true
    if ($Rules.Count -eq 0) {
      $Check = $false
    } else {
      foreach ($RuleGroup in $Rules.GetEnumerator()) {
        if ($RuleGroup.Value -eq $null) {
          $Check = $false
        }
      }
    }
    return $Check
  }
}
