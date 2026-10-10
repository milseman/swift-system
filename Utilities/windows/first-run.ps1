<#
.SYNOPSIS
Builds and tests swift-system on Windows, for the first Windows run of system-next.

.DESCRIPTION
Run it from a clone of swift-system (it finds the clone from its own path,
Utilities\windows). It runs, in the clone, one after another:

  1. swift package describe     the package as a Windows host's manifest declares it
  2. swift build                the libraries
  3. swift build --build-tests  the test targets too; if that fails, each test
                                target alone (swift build --target X), to show which
                                ones don't compile
  4. swift test --skip-build    every test
  5. swift test --skip-build --filter <suite>, for each Windows-only suite, one at
                                a time, so that a crash in one doesn't hide the rest

It writes everything to one log, .build\windows-first-run-<date>-<time>.log in the
clone, shows each command's output as it runs, and prints a summary at the end. A
step that runs longer than its time-out is stopped (taskkill /T on its own process
tree) and counted as timed out.

It changes nothing outside the clone: SwiftPM's caches and configuration are
pointed into the clone's .build (--manifest-cache local, --cache-path,
--config-path, --security-path), and environment changes are the script's own.
On a Windows host the package has no package dependencies, so SwiftPM fetches
nothing. It needs no administrator rights. The tests themselves make and remove
their own temporary files under %TEMP% and use sockets on loopback only; see
README.md.

Exit status: 0 when every step passed, 1 otherwise.

.PARAMETER BuildTimeoutMinutes
The time-out of each build step. Default 60.

.PARAMETER TestTimeoutMinutes
The time-out of the run of every test. Default 60.

.PARAMETER SuiteTimeoutMinutes
The time-out of each Windows-only suite's run. Default 15.

.PARAMETER SkipSuites
Leaves out step 5.

.PARAMETER ListOnly
Prints the steps, with the Windows-only suites found, and runs nothing.

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File Utilities\windows\first-run.ps1

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File Utilities\windows\first-run.ps1 -ListOnly
#>

#Requires -Version 5.1
[CmdletBinding()]
param(
  [int] $BuildTimeoutMinutes = 60,
  [int] $TestTimeoutMinutes = 60,
  [int] $SuiteTimeoutMinutes = 15,
  [switch] $SkipSuites,
  [switch] $ListOnly
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
if (-not (Test-Path -LiteralPath (Join-Path $Root 'Package.swift'))) {
  throw "first-run: no Package.swift in $Root; run the script from a clone of swift-system."
}
$BuildDir = Join-Path $Root '.build'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogPath = Join-Path $BuildDir "windows-first-run-$Stamp.log"
# Each step's output goes here first, so that it can be shown as it comes, and
# then into the log; the file is deleted after each step.
$StepPath = Join-Path $BuildDir "windows-first-run-$Stamp.step"
# SwiftPM's shared cache, configuration and security directories, which it
# would otherwise keep under the user's profile.
$SwiftPMDir = Join-Path $BuildDir 'windows-first-run-swiftpm'
$SwiftPMOptions = ('--manifest-cache local --cache-path "{0}" --config-path "{1}" --security-path "{2}"' -f
  (Join-Path $SwiftPMDir 'cache'), (Join-Path $SwiftPMDir 'config'), (Join-Path $SwiftPMDir 'security'))

# ------------------------------------------------------------------ the log

$Log = $null

function Write-Line([string] $Text) {
  Write-Host $Text
  if ($null -ne $Log) { $Log.WriteLine($Text) }
}

# A short command's output, standard error included, for the log's header.
# Windows PowerShell turns a native command's standard error into error
# records, which stop the script under 'Stop', hence 'Continue' here.
function Get-CommandText([string] $File, [string[]] $Arguments) {
  $saved = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $lines = & $File @Arguments 2>&1
    return ((@($lines) | ForEach-Object { "$_" }) -join [Environment]::NewLine).Trim()
  } catch {
    return "(failed: $_)"
  } finally {
    $ErrorActionPreference = $saved
  }
}

# Stops a process and the processes it started: the step's cmd.exe, swift and
# what swift runs.
function Stop-ProcessTree([int] $ProcessId) {
  $saved = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $null = & taskkill.exe /T /F /PID $ProcessId 2>&1
  } finally {
    $ErrorActionPreference = $saved
  }
}

function Get-RegistryValue([string] $Path, [string] $Name) {
  try {
    return (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name
  } catch {
    return $null
  }
}

# ------------------------------------------------------------------ the suites

# The Windows-only suites: the test types of the files in SystemTests and
# SystemWinSocksTests whose first condition is `#if os(Windows)`, each as a
# filter that selects its tests, `Module\.Type/` (XCTest's names are
# Module.Class/test and swift-testing's Module.Suite/test()).
function Get-WindowsOnlySuites {
  $suites = New-Object System.Collections.Generic.List[string]
  foreach ($module in @('SystemTests', 'SystemWinSocksTests')) {
    $directory = Join-Path $Root "Tests\$module"
    if (-not (Test-Path -LiteralPath $directory)) { continue }
    foreach ($file in @(Get-ChildItem -LiteralPath $directory -Filter '*.swift' | Sort-Object Name)) {
      $text = [System.IO.File]::ReadAllText($file.FullName)
      $first = [regex]::Match($text, '(?m)^#if .*$')
      if (-not $first.Success -or $first.Value.Trim() -ne '#if os(Windows)') { continue }
      $classes = [regex]::Matches($text,
        '(?m)^[ \t]*(?:(?:final|private|fileprivate|internal|public)[ \t]+)*class[ \t]+(\w+)[ \t]*:[ \t]*XCTestCase\b')
      $structs = [regex]::Matches($text,
        '(?m)^[ \t]*@Suite\b[^\n]*\n(?:[ \t]*@[^\n]*\n)*[ \t]*(?:(?:private|fileprivate|internal|public|final)[ \t]+)*(?:struct|class|enum|actor)[ \t]+(\w+)')
      foreach ($match in @($classes) + @($structs)) {
        $filter = '{0}\.{1}/' -f $module, $match.Groups[1].Value
        if (-not $suites.Contains($filter)) { $suites.Add($filter) }
      }
    }
  }
  return ,$suites
}

# ------------------------------------------------------------------ results

# The totals the last XCTest and swift-testing summaries in a step's output
# give, and the tests they report as failed.
function Get-TestReport([string] $Text) {
  $report = [ordered]@{ XCTest = $null; Testing = $null; Total = 0; Failed = @() }
  $xctest = [regex]::Matches($Text,
    'Executed (\d+) tests?, with (?:(\d+) tests? skipped and )?(\d+) failures? \((\d+) unexpected\)')
  if ($xctest.Count -gt 0) {
    $m = $xctest[$xctest.Count - 1]
    $skipped = '0'
    if ($m.Groups[2].Success) { $skipped = $m.Groups[2].Value }
    $report.XCTest = 'XCTest {0} tests, {1} skipped, {2} failures' -f $m.Groups[1].Value, $skipped, $m.Groups[3].Value
    $report.Total += [int]$m.Groups[1].Value
  }
  $testing = [regex]::Matches($Text,
    'Test run with (\d+) tests?(?: in (\d+) suites?)? (passed|failed) after [\d.]+ seconds?(?: with (\d+) issues?)?')
  if ($testing.Count -gt 0) {
    $m = $testing[$testing.Count - 1]
    $issues = ''
    if ($m.Groups[4].Success) { $issues = ', {0} issues' -f $m.Groups[4].Value }
    $report.Testing = 'swift-testing {0} tests, {1}{2}' -f $m.Groups[1].Value, $m.Groups[3].Value, $issues
    $report.Total += [int]$m.Groups[1].Value
  }
  $failed = New-Object System.Collections.Generic.List[string]
  foreach ($m in [regex]::Matches($Text, "Test Case '([^']+)' failed")) { $failed.Add($m.Groups[1].Value) }
  foreach ($m in [regex]::Matches($Text, '(?m)Test (\S.*?\)) failed after')) { $failed.Add($m.Groups[1].Value) }
  $report.Failed = @($failed | Select-Object -Unique)
  return $report
}

# Runs `swift <arguments>` in the clone through cmd.exe, which writes its
# output and errors, in order, to the step's file; shows the file as it grows;
# stops the process tree at the time-out; and adds the output to the log.
function Invoke-Swift {
  param([string] $Name, [string] $Arguments, [int] $TimeoutMinutes, [switch] $Tests, [switch] $Suite)

  $command = "swift $Arguments $SwiftPMOptions"
  Write-Line ''
  Write-Line ('=' * 78)
  Write-Line "== $Name"
  Write-Line "== $command"
  Write-Line ('=' * 78)
  if (Test-Path -LiteralPath $StepPath) { Remove-Item -LiteralPath $StepPath -Force }

  $started = Get-Date
  $deadline = $started.AddMinutes($TimeoutMinutes)
  $process = Start-Process -FilePath $env:ComSpec -WorkingDirectory $Root -NoNewWindow -PassThru `
    -ArgumentList ('/d /s /c "{0} > "{1}" 2>&1"' -f $command, $StepPath)
  # Holding the handle keeps the exit code readable after the process ends.
  $null = $process.Handle

  $decoder = [System.Text.Encoding]::UTF8.GetDecoder()
  $bytes = New-Object byte[] 65536
  $chars = New-Object char[] 65540
  $position = [long]0
  $output = New-Object System.Text.StringBuilder
  $timedOut = $false
  $waitsAfterKill = 0
  while ($true) {
    $exited = $process.WaitForExit(500)
    if (Test-Path -LiteralPath $StepPath) {
      $stream = $null
      try {
        # cmd.exe shares its redirection's file for reading.
        $stream = [System.IO.File]::Open($StepPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read,
          [System.IO.FileShare]::ReadWrite)
        $null = $stream.Seek($position, [System.IO.SeekOrigin]::Begin)
        while (($count = $stream.Read($bytes, 0, $bytes.Length)) -gt 0) {
          $position += $count
          $charCount = $decoder.GetChars($bytes, 0, $count, $chars, 0)
          $chunk = [string]::new($chars, 0, $charCount)
          [void]$output.Append($chunk)
          Write-Host -NoNewline $chunk
        }
      } catch [System.IO.IOException] {
        # Not readable this time; the next pass reads from the same place.
      } finally {
        if ($null -ne $stream) { $stream.Dispose() }
      }
    }
    if ($exited) { break }
    if ($timedOut) {
      # taskkill has run; give the tree a few seconds to go, then stop waiting.
      $waitsAfterKill += 1
      if ($waitsAfterKill -ge 20) { break }
      continue
    }
    if ((Get-Date) -gt $deadline) {
      $timedOut = $true
      $processId = $process.Id
      $message = "first-run: $Name has run for $TimeoutMinutes minutes; stopping it (taskkill /T /F /PID $processId)"
      Write-Host ''
      Write-Host $message
      [void]$output.AppendLine('').AppendLine($message)
      Stop-ProcessTree $processId
    }
  }
  $seconds = [int]((Get-Date) - $started).TotalSeconds
  $exitCode = $null
  if ($process.HasExited) { $exitCode = $process.ExitCode }

  $text = $output.ToString()
  if ($null -ne $Log) {
    $Log.Write($text)
    if ($text.Length -gt 0 -and -not $text.EndsWith("`n")) { $Log.WriteLine() }
  }
  if (Test-Path -LiteralPath $StepPath) { Remove-Item -LiteralPath $StepPath -Force }

  $report = $null
  if ($Tests) { $report = Get-TestReport $text }
  if ($timedOut) {
    $status = 'timed out'
  } elseif ($exitCode -ne 0) {
    $status = 'failed'
  } elseif ($Suite -and $report.Total -eq 0) {
    # A filter that matches nothing passes with no tests.
    $status = 'selected nothing'
  } else {
    $status = 'passed'
  }
  if (-not $Tests -and $status -eq 'failed' -and $text -match "is not recognized as an internal or external command") {
    $status = 'failed (no swift on PATH)'
  }

  $details = @()
  $failed = @()
  if ($null -ne $report) {
    $failed = @($report.Failed)
    if ($null -ne $report.XCTest) { $details += $report.XCTest }
    if ($null -ne $report.Testing) { $details += $report.Testing }
    if ($null -eq $report.XCTest -and $null -eq $report.Testing -and $status -ne 'passed') {
      $details += 'no test summary in its output (a crash?)'
    }
  }
  Write-Line ("== {0}: {1} in {2}s (exit {3}){4}" -f $Name, $status, $seconds, $exitCode,
    $(if ($details.Count -gt 0) { '; ' + ($details -join '; ') } else { '' }))

  return [pscustomobject]@{
    Name = $Name; Command = $command; Status = $status; Seconds = $seconds; ExitCode = $exitCode
    Details = ($details -join '; ')
    Failed = $failed
  }
}

# ------------------------------------------------------------------ the run

$suites = Get-WindowsOnlySuites

if ($ListOnly) {
  Write-Host "Clone: $Root"
  Write-Host "Log:   $LogPath (not written: -ListOnly)"
  Write-Host ''
  Write-Host "  manifest      swift package describe $SwiftPMOptions"
  Write-Host "  build         swift build $SwiftPMOptions"
  Write-Host "  build-tests   swift build --build-tests $SwiftPMOptions"
  Write-Host "                (if it fails: swift build --target X, for SystemTests, SystemWinSocksTests and MemberImportVisibility)"
  Write-Host "  test          swift test --skip-build $SwiftPMOptions"
  if (-not $SkipSuites) {
    Write-Host ("  {0} Windows-only suites, each: swift test --skip-build --filter <suite> ..." -f $suites.Count)
    foreach ($suite in $suites) { Write-Host "    $suite" }
  }
  exit 0
}

if (-not (Test-Path -LiteralPath $BuildDir)) { $null = New-Item -ItemType Directory -Path $BuildDir }
$Log = New-Object System.IO.StreamWriter($LogPath, $false, (New-Object System.Text.UTF8Encoding($false)))
$Log.AutoFlush = $true

$results = New-Object System.Collections.Generic.List[object]
try {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $elevated = ([Security.Principal.WindowsPrincipal] $identity).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
  $version = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
  Write-Line "swift-system's first Windows run, $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
  Write-Line "Clone:            $Root"
  Write-Line "Log:              $LogPath"
  Write-Line ("Windows:          {0} {1}, build {2}.{3}, {4}" -f (Get-RegistryValue $version 'ProductName'),
    (Get-RegistryValue $version 'DisplayVersion'), (Get-RegistryValue $version 'CurrentBuild'),
    (Get-RegistryValue $version 'UBR'), $env:PROCESSOR_ARCHITECTURE)
  Write-Line "PowerShell:       $($PSVersionTable.PSVersion)"
  Write-Line "Elevated:         $elevated (the run needs no administrator rights)"
  Write-Line ("Developer Mode:   {0} (symbolic-link tests skip without it)" -f
    (Get-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' 'AllowDevelopmentWithoutDevLicense'))
  Write-Line ("Long paths:       {0} (LongPathsEnabled)" -f
    (Get-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled'))
  Write-Line "Time-outs:        build $BuildTimeoutMinutes min, tests $TestTimeoutMinutes min, each suite $SuiteTimeoutMinutes min"
  if ($null -ne (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Line ("Commit:           {0}" -f (Get-CommandText 'git' @('--no-optional-locks', '-C', $Root, 'log', '-1',
      '--format=%H %s')))
    Write-Line ("Branch:           {0}" -f (Get-CommandText 'git' @('--no-optional-locks', '-C', $Root, 'rev-parse',
      '--abbrev-ref', 'HEAD')))
    $changes = Get-CommandText 'git' @('--no-optional-locks', '-C', $Root, 'status', '--porcelain',
      '--untracked-files=no')
    if ($changes.Length -eq 0) { $changes = '(none)' }
    Write-Line "Changes:          $changes"
  } else {
    Write-Line 'Commit:           (no git on PATH)'
  }
  if ($null -eq (Get-Command swift -ErrorAction SilentlyContinue)) {
    Write-Line 'first-run: no swift on PATH; install a Swift toolchain, open a new terminal, and run this again.'
    exit 1
  }
  Write-Line "Swift:"
  Write-Line (Get-CommandText 'swift' @('--version'))
  Write-Line ("Windows-only suites found: {0}" -f $suites.Count)

  $results.Add((Invoke-Swift -Name 'manifest' -Arguments 'package describe' -TimeoutMinutes $BuildTimeoutMinutes))
  $results.Add((Invoke-Swift -Name 'build' -Arguments 'build' -TimeoutMinutes $BuildTimeoutMinutes))
  $buildTests = Invoke-Swift -Name 'build-tests' -Arguments 'build --build-tests' -TimeoutMinutes $BuildTimeoutMinutes
  $results.Add($buildTests)
  if ($buildTests.Status -ne 'passed') {
    foreach ($target in @('SystemTests', 'SystemWinSocksTests', 'MemberImportVisibility')) {
      $results.Add((Invoke-Swift -Name "build $target" -Arguments "build --target $target" `
        -TimeoutMinutes $BuildTimeoutMinutes))
    }
    Write-Line ''
    Write-Line 'first-run: the tests didn''t build, so none ran.'
  } else {
    $results.Add((Invoke-Swift -Name 'test' -Arguments 'test --skip-build' -TimeoutMinutes $TestTimeoutMinutes -Tests))
    if (-not $SkipSuites) {
      foreach ($suite in $suites) {
        $results.Add((Invoke-Swift -Name "suite $suite" -Arguments "test --skip-build --filter $suite" `
          -TimeoutMinutes $SuiteTimeoutMinutes -Tests -Suite))
      }
    }
  }

  # ---------------------------------------------------------------- summary
  Write-Line ''
  Write-Line ('=' * 78)
  Write-Line '== Summary'
  Write-Line ('=' * 78)
  foreach ($result in $results) {
    $line = '{0,-54} {1,-17} {2,6}s' -f $result.Name, $result.Status, $result.Seconds
    if ($result.Details.Length -gt 0) { $line += '  ' + $result.Details }
    Write-Line $line
  }
  $failedTests = @($results | ForEach-Object { $_.Failed } | Where-Object { $_ } | Select-Object -Unique)
  if ($failedTests.Count -gt 0) {
    Write-Line ''
    Write-Line ("Failed tests ({0}):" -f $failedTests.Count)
    foreach ($name in $failedTests) { Write-Line "  $name" }
  }
  $problems = @($results | Where-Object { $_.Status -ne 'passed' })
  Write-Line ''
  if ($problems.Count -eq 0) {
    Write-Line "first-run: every step passed. The log is $LogPath"
    $status = 0
  } else {
    Write-Line ("first-run: {0} of {1} steps didn't pass. The log is $LogPath" -f $problems.Count, $results.Count)
    $status = 1
  }
} finally {
  if ($null -ne $Log) { $Log.Dispose() }
  if (Test-Path -LiteralPath $StepPath) { Remove-Item -LiteralPath $StepPath -Force }
}
exit $status
