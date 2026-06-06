[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$MusicPath
)

# Sources
. .\config.ps1
. .\helpers.ps1

$csvPath = Join-Path $MusicPath "music uploads metadata.csv"

$numFilesOrganized = 0
$numFilesSkipped = 0
$numFilesNotFound = 0
$numFilesErrored = 0


#############################################
# LOAD AND VALIDATE DATA
#############################################

# Verify paths
if (-not (Test-Path $MusicPath)) { Write-Error "Music path not found: $MusicPath"; exit }
if (-not (Test-Path $csvPath)) { Write-Error "music uploads metadata.csv not found in music path: $MusicPath"; exit }

# Load CSV data
$csvData = Import-Csv -Path $csvPath
$safeTitleCounts = Get-SafeTitleCountMap $csvData

# Load files, excluding the CSV metadata files
$musicFiles = Get-ChildItem -Path $MusicPath -File | Where-Object { -not $_.Name.EndsWith(".csv") }

if (!$musicFiles.Count) { Write-Error "No music files found in the directory: $MusicPath"; exit }

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
    $csvSongTitle = $row.'Song Title'
    $csvAlbumTitle = $row.'Album Title'
    $csvArtistName = $row.'Artist Name 1'
    $csvDuration = $row.Duration

    # Require at least Song Title and Artist Name for matching
    if (-not $csvSongTitle -or -not $csvArtistName) { 
        Write-Verbose "Skipping song with missing title or artist, see CSV row $rowIndex" 
        $numFilesSkipped++ 
        continue 
    }

    if ($overrideAlbumArtists.ContainsKey($csvAlbumTitle)) {
        $csvArtistName = $overrideAlbumArtists[$csvAlbumTitle]
        Write-Verbose "Overriding artist name for album ""$csvAlbumTitle"" to ""$csvArtistName"""
    }

    # Skip artists with commas or slashes in their name that aren't
    # in the allowed list, since these need to be fixed manually
    elseif ((Test-ArtistNameMightBeList $csvArtistName) `
            -and -not ($albumArtists -contains $csvArtistName)) {
        #Write-Verbose "Skipping song with apparent list of artists: $csvArtistName"
        #$numFilesSkipped++

        Write-Verbose "Treating ""$csvArtistName"" as ""Various Artists"""
        $csvArtistName = "Various Artists"
        continue
    }

    # Sanitize for file system matching and folder creation
    $safeSongTitle = ConvertTo-SafeFileName $csvSongTitle
    $safeArtist = ConvertTo-SafeFolderName $csvArtistName
    $safeAlbum = if ($csvAlbumTitle) { ConvertTo-SafeFolderName $csvAlbumTitle } else { "Unknown Album" }

    # 2. Identify Potential Files
    # Matches "Title", "Title(1)", "Title(2)" etc. (No space before parenthesis)
    $escapedTitle = [regex]::Escape($safeSongTitle)
    $candidates = $musicFiles | Where-Object { $_.BaseName -match "^$escapedTitle(\(\d+\))?$" }

    if (-not $candidates) {
        Write-Verbose "No file candidates found for: $csvSongTitle"
        $numFilesNotFound++
        continue
    }

    $targetFile = $null


    # 3. Filter using metadata as needed

    # If there's only one candidate, use it. Requiring the map count to agree helps
    # prevent false positives in a partially-organized dataset
    if ($candidates.Count -eq 1 -and $safeTitleCounts[$safeSongTitle] -eq 1) {
        $targetFile = $candidates[0]
    }

    # If there's more than one candidate, we can check against the CSV metadata  
    else {              
        $csvSeconds = Convert-CsvDurationToSeconds $csvDuration

        foreach ($file in $candidates) {
            $meta = Get-FileMetadata $file.FullName

            # Check Title
            if ($meta.Title -and ($meta.Title -ne $csvSongTitle)) {
                continue
            }

            # Check Album
            if ($meta.Album -and ($meta.Album -ne $csvAlbumTitle)) {
                continue
            }

            # Check Album Artist
            if ($meta.AlbumArtist -and ($meta.AlbumArtist -ne $csvArtistName)) {
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

        try {
            if (-not (Test-Path $destPath)) {
                New-Item -ItemType Directory -Path $destPath | Out-Null
            }

            Move-Item -Path $targetFile.FullName -Destination $destPath -Force -ErrorAction Stop
            
            Write-Debug "Moved: $($targetFile.Name) -> $safeArtist\$safeAlbum"
            
            $numFilesOrganized++
        }
        catch {
            Write-Error "Failed to move ""$csvSongTitle"" to $destPath"
            $numFilesErrored++
        }
    }
    else {
        Write-Verbose "No valid file match found for: $csvSongTitle"
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