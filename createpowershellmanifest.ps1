param (
    [string]$ModuleName,
    [string]$Source = "",
    [string]$Output = "",
    [string]$Imports,
    [string]$Assemblies = "",
    [string]$Debug = 'false'
)
try
{
    Write-Host "::group::Starting the Create PowerShell Module task..."
    Write-Host "::group::Setting up variables"

    [bool]$Debug = [System.Convert]::ToBoolean($Debug)

    Write-Host "DebugMode Enabled : $($Debug)"
    Write-Host "Root: $($PWD)"
    Write-Host "Workspace: $( $env:GITHUB_WORKSPACE)"
    (Get-ChildItem $env:GITHUB_WORKSPACE -Recurse).FullName

    if ([string]::IsNullOrEmpty($Source))
    {
        $sourcePath = "$($env:GITHUB_WORKSPACE)"
    }
    else
    {
        $sourcePath = "$($env:GITHUB_WORKSPACE)\$($Source)"
    }

    if ([string]::IsNullOrEmpty($Output))
    {
        $outputPath = "$($env:GITHUB_WORKSPACE)\output"
    }
    else
    {
        $outputPath = "$($env:GITHUB_WORKSPACE)\$($Output)"
    }

    $ManifestRoot = Get-ChildItem -Path $SourcePath -Filter "$($ModuleName).psd1" -Recurse
    $ModuleRoot = $ManifestRoot.Parent
    $ManifestPath = "$($outputPath)\$($ModuleName).psd1"

    if ($Debug)
    {
        Write-Host "ModuleName   : $($ModuleName)"
        Write-Host "SourcePath   : $($sourcePath)"
        Write-Host "OutputPath   : $($outputPath)"
        Write-Host "ManifestPath : $($ManifestPath)"
        Write-Host "ModuleRoot   : $($ModuleRoot)"
        Write-Host "Imports      : $($imports)"
        Write-Host "Assemblies   : $($Assemblies)"
    }

    $importFolders = $imports.Split(',')

    if ([string]::IsNullOrEmpty($Assemblies))
    {
        $AssemblyDirectories = @()
    }
    else
    {
        $AssemblyDirectories = $Assemblies.Split(',')
    }

    Write-Host "::endgroup::"
    Write-Host "::group::Install BuildHelpers module"
    if (-not (Get-Module -ListAvailable -Name BuildHelpers))
    {
        Install-Module -Name BuildHelpers -Scope CurrentUser -Force
    }
    Import-Module BuildHelpers
    Write-Host "::endgroup::"

    Write-Host "::group::Updating manifest at [$($ManifestPath)]"
    Copy-Item "$($ModuleRoot)\$($ModuleName).psd1" -Destination $outputPath -ErrorAction Stop
    Write-Host "Copied module manifest to destination"
    Write-Host "::endgroup::"

    Write-Host "::group::Collecting Functions"
    $Functions = @()

    foreach ($importFolder in $importFolders)
    {
        if (Test-Path "$($ModuleRoot)\$($importFolder)")
        {
            Write-Host "Processing public functions in folder: $($importFolder)"
            $FileList = Get-ChildItem "$($ModuleRoot)\$($importFolder)\*.ps1" -Exclude "*.Tests.ps1"
            foreach ($File in $FileList)
            {
                $Code = Get-Content -Path $File.FullName -Raw
                $Function = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$null, [ref]$null).FindAll({
                    param($ast)
                    $ast -is [System.Management.Automation.Language.FunctionDefinitionAst]
                }, $true)
                if ($Debug)
                {
                    Write-Host "$($Function.Name)"
                }
                $Functions += $Function.Name
            }
        }
        else
        {
            Write-Host "##[warning]Public function folder not found: $($importFolder)"
        }
    }
    Write-Host "::endgroup::"

    Write-Host "::group::Collecting Assemblies"
    if ($AssemblyDirectories.Count -gt 0)
    {
        $RequiredAssemblies = @()
        foreach ($Assembly in $AssemblyDirectories)
        {
            $AssemblyDestinationPath = "$($outputPath)\assemblies\$($Assembly)"
            Write-Host "Processing assemblies in directory: $($Assembly)"
            $AssemblyFile = Get-Item -Path (((Get-ChildItem -Path "$($AssemblyDestinationPath)").GetFiles("*$($Assembly)*").FullName) | Where-Object { $_.EndsWith('dll') })
            $AssemblyPath = $AssemblyFile.FullName.Replace("$($outputPath)\", '')
            $RequiredAssemblies += $AssemblyPath
            Write-Host "Found DLL: $AssemblyPath"
        }

        Write-Host "Updating manifest metadata"
        Update-Metadata -Path $ManifestPath -PropertyName RequiredAssemblies -Value $RequiredAssemblies
        Write-Host "Updated RequiredAssemblies in manifest"
    }
    else
    {
        Write-Host "##[warning]No assembly directories specified, skipping RequiredAssemblies update"
    }
    Write-Host "::endgroup::"

    Write-Host "::group::Updating Manifest"
    Update-Metadata -Path $ManifestPath -PropertyName FunctionsToExport -Value $Functions
    Write-Host "Updated FunctionsToExport in manifest"
    Write-Host "::endgroup::"
    Write-Host "::endgroup::"
}
catch
{
    Write-Host "##[error]An error occurred: $($_.Exception.Message)"
    exit 1
}