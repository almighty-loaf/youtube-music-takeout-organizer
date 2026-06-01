[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$MusicPath
)


#############################################
# CONFIGURATION
#############################################

# If the "Artist Name 1" column of the CSV contains commas, slashes, ampersands, or semicolons, they are 
# probably delimiters for contributing artists. We only care about album artists, so we will ignore these 
# rows unless specified here
#
# You may add more entries here as needed for your own music library
$artistNamesWithSpecialChars = @(
    "AC/DC",
    "Earth, Wind & Fire"
)


#############################################
# HELPER FUNCTIONS
#############################################

# Regex pattern that represent characters that YTM replaces with underscores in file names
# e.g. song title "Who can it be now?" is "Who can it be now_.mp3"
# Hardcode to the Windows limitations since that's what the source data abides by
function UnderscoreCharsRegex {
    '[\\/:*?"''<>|]'
}

# Function to read MP3 metadata properties
# Only works for Windows since it relies on Shell.Application COM object, but could be
# extended to support other OSes by using a different method (e.g. TagLib# or ffprobe)
# superuser.com/questions/704575
# stackoverflow.com/questions/22382010/what-options-are-available-for-shell32-folder-getdetailsof
function Get-FileMetadata {
    param ([string]$filePath)

    if (!$shell) { 
        $title = ""
        $album = ""
        $albumArtist = ""
        $duration = ""
    }
    else {
        $folder = $shell.Namespace((Split-Path $filePath))
        $file = $folder.ParseName((Split-Path $filePath -Leaf))

        # Standard property indices for Windows
        $title = $folder.GetDetailsOf($file, 21)
        $album = $folder.GetDetailsOf($file, 14)
        $albumArtist = $folder.GetDetailsOf($file, 13)
        $duration = $folder.GetDetailsOf($file, 27)
    }
    
    return [PSCustomObject]@{
        Title          = $title
        Album          = $album
        AlbumArtist    = $albumArtist
        DurationString = $duration
    }
}

# Function to parse "XhYmZs" format (e.g., "1h20s", "3m40s") to seconds
# stackoverflow.com/questions/75834505
function Convert-CsvDurationToSeconds {
    param ([string]$durationString)

    if ([string]::IsNullOrEmpty($DurationString)) {
        return $null
    }

    # Regex allows optional h, m, s segments
    # Could use [timespan]::ParseExact but then I have to enumerate every permutation of "hh:mm:ss", "mm:ss", "ss" etc.
    if ($durationString -match "^((?<h>\d+)h)?((?<m>\d+)m)?((?<s>\d+(?:\.\d+)?)s)?$") {
        $totalSeconds = 0
        if ($Matches.h) { $totalSeconds += [int]$Matches.h * 3600 }
        if ($Matches.m) { $totalSeconds += [int]$Matches.m * 60 }
        if ($Matches.s) { $totalSeconds += [double]$Matches.s }
        return $totalSeconds
    }
    return $null
}

# Function to parse standard shell duration (mm:ss or hh:mm:ss) to seconds
function Convert-ShellDurationToSeconds {
    param ([string]$durationString)
    if (-not $durationString) { return $null }

    $parts = $durationString.Split(':')
    if ($parts.Count -eq 2) {
        return ([int]$parts[0] * 60) + [double]$parts[1]
    }
    elseif ($parts.Count -eq 3) {
        return ([int]$parts[0] * 3600) + ([int]$parts[1] * 60) + [double]$parts[2]
    }
    # assume it's just seconds if there's only one part
    return [int]$durationString
}

# Function to sanitize file or folder names by replacing invalid characters with underscores
# and removing trailing dots and spaces (since those are not allowed in Windows file/folder names)
function ConvertTo-SafeFileOrFolderName {
    param ([string]$name)    
    return ($name -replace (UnderscoreCharsRegex), '_').TrimEnd('.', ' ')
}

# Function that calculates the count of unique song titles after they have been sanitized
# Output is a map of title->count
function Get-SafeTitleCountMap {
    param ([array]$csvData)

    $map = @{}
    foreach ($row in $csvData) {
        $safeSongTitle = ConvertTo-SafeFileOrFolderName $row.'Song Title'

        if (!$safeSongTitle) { continue }
        $map[$safeSongTitle] = $map[$safeSongTitle] + 1
    }
    return $map
}

# Function to check if an artist name contains special characters that would require manual fixing
function Test-ArtistNameContainsSpecialChars {
    param ([string]$artistName)
    return ($artistName -match "[,\/&;]")
}

#############################################
# SETUP
#############################################

$numFilesOrganized = 0
$numFilesSkipped = 0
$numFilesNotFound = 0
$numFilesErrored = 0

$csvPath = Join-Path $MusicPath "music uploads metadata.csv"

# Verify paths
if (-not (Test-Path $MusicPath)) { Write-Error "Music path not found: $MusicPath"; exit }
if (-not (Test-Path $csvPath)) { Write-Error "CSV not found: $csvPath"; exit }

# Load CSV data
$csvData = Import-Csv -Path $csvPath
$safeTitleCounts = Get-SafeTitleCountMap $csvData

# Load files, excluding the CSV metadata files
$musicFiles = Get-ChildItem -Path $MusicPath -File | Where-Object { -not $_.Name.EndsWith(".csv") }

if (-not $musicFiles.Count) { Write-Error "No music files found in the directory: $MusicPath"; exit }

# Initialize Shell for reading MP3 metadata
try {
    $shell = New-Object -ComObject Shell.Application
}
catch {
    Write-Warning "Running on non-Windows host. Existing file metadata won't be considered when there are multiple files with the same name."
}


#############################################
# MAIN PROCESSING LOOP
#############################################

$rowIndex = 0   # starting at 0 allows the first run of the loop to increment past the header row
foreach ($row in $csvData) {
    $rowIndex++

    # 1. Extract and Sanitize Data
    $csvsafeSongTitle = $row.'Song Title'
    $csvAlbumTitle = $row.'Album Title'
    $csvArtistName = $row.'Artist Name 1'
    $csvDuration = $row.Duration

    # Require at least Song Title and Artist Name for matching
    if (-not $csvsafeSongTitle -or -not $csvArtistName) { 
        Write-Verbose "Skipping song with missing title or artist, see CSV row $rowIndex" 
        $numFilesSkipped++ 
        continue 
    }

    # Skip artists with commas or slashes in their name that aren't
    # in the allowed list, since these need to be fixed manually
    if (Test-ArtistNameContainsSpecialChars $csvArtistName `
            -and -not ($artistNamesWithSpecialChars -contains $csvArtistName)) {
        Write-Verbose "Skipping song with apparent list of artists: $csvArtistName"
        $numFilesSkipped++
        continue
    }

    # Sanitize for file system matching and folder creation
    $safesafeSongTitle = ConvertTo-SafeFileOrFolderName $csvsafeSongTitle
    $safeArtist = ConvertTo-SafeFileOrFolderName $csvArtistName
    $safeAlbum = if ($csvAlbumTitle) { ConvertTo-SafeFileOrFolderName $csvAlbumTitle } else { "Unknown Album" }

    # 2. Identify Potential Files
    # Matches "Title", "Title(1)", "Title(2)" etc. (No space before parenthesis)
    $escapedTitle = [regex]::Escape($safesafeSongTitle)
    $candidates = $musicFiles | Where-Object { $_.BaseName -match "^$escapedTitle(\(\d+\))?$" }

    if (-not $candidates) {
        Write-Verbose "No file candidates found for: $csvsafeSongTitle"
        $numFilesNotFound++
        continue
    }

    $targetFile = $null

    # 3. Filter using metadata as needed

    # If there's only one candidate, use it. Requiring the map count to agree helps
    # prevent false positives in a partially-organized dataset
    if ($candidates.Count -eq 1 -and $safeTitleCounts[$safesafeSongTitle] -eq 1) {
        $targetFile = $candidates[0]
    }

    # If there's more than one candidate, we can check against the CSV metadata  
    else {              
        $csvSeconds = Convert-CsvDurationToSeconds $csvDuration

        foreach ($file in $candidates) {
            $meta = Get-FileMetadata $file.FullName

            # Check Title
            if ($meta.Title -and $meta.Title -ne $csvsafeSongTitle) {
                continue
            }

            # Check Album
            if ($meta.Album -and $meta.Album -ne $csvAlbumTitle) {
                continue
            }

            # Check Album Artist
            if ($meta.AlbumArtist -and $meta.AlbumArtist -ne $csvArtistName) {
                continue
            }

            # Check Duration (tolerance of 5 seconds since YTM data is not exactly accurate)
            if ($csvSeconds -and $meta.DurationString) {
                $fileSeconds = Convert-ShellDurationToSeconds $meta.DurationString

                if ($fileSeconds -and [Math]::Abs($fileSeconds - $csvSeconds) -gt 5) {
                    continue
                }
            }
            else {
                # If we don't even have duration data, we can't be sure this is the correct file, so skip it
                continue
            }

            # Found the correct file
            $targetFile = $file
            break 
        }
    }    

    # 4. Move File
    if ($targetFile) {
        $destPath = Join-Path $MusicPath $safeArtist $safeAlbum

        # if (-not(Test-Path $destPath -IsValid)) {
        #     Write-Error "Skipping song with invalid destination path: $destPath."
        #     $numFilesErrored++
        #     continue
        # }

        try {
            if (-not (Test-Path $destPath)) {
                New-Item -ItemType Directory -Path $destPath | Out-Null
            }

            Move-Item -Path $targetFile.FullName -Destination $destPath #-Force
            # Write-Host "Moved: $($targetFile.Name) -> $safeArtist\$safeAlbum"
            $numFilesOrganized++
        }
        catch {
            Write-Error "Failed to move song to $destPath"
            $numFilesErrored++
        }
    }
    else {
        Write-Verbose "No valid file match found for: $csvsafeSongTitle"
        $numFilesNotFound++
    }
}


#############################################
# SUMMARY
#############################################

if ($numFilesOrganized -gt 0) { Write-Host "Files organized: $numFilesOrganized" }    
if ($numFilesSkipped -gt 0) { Write-Host "Files skipped: $numFilesSkipped" }
if ($numFilesNotFound -gt 0) { Write-Host "Files not found: $numFilesNotFound" }
if ($numFilesErrored -gt 0) { Write-Host "Files that couldn't be moved: $numFilesErrored" }