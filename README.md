# YouTube Music Takeout Organizer

## Problem
If you upload your personal music files to YouTube Music and later download them through Google Takeout, you might discover that metadata has been inconsistently removed on a per-file basis. In some cases, only clobbered filenames remain (e.g. track numbers have been removed, certain characters are replaced with underscores).

The Takeout data does include a CSV file that contains the list of exported songs, including columns for title, album, artists, and duration. However, it is left to the user to manually reorganize and retag the files.

## Solution
This PowerShell script will reorganize the files in an `Album Artist > Album > Song` filesystem hierarchy within the music folder root. Any files that lack sufficient information to organize will remain at the root for manual processing.

## How It Works
This script parses the CSV one row at a time, determines which file is the best match, and then uses the `Artist Name 1` and `Album Title` columns to move it to the correct destination folder.

When a song name is unique, this can be handled trivially. When there are multiple songs with the same name, or multiple songs share the same clobbered filename, the CSV data will be compared to the available file metadata. The song duration is usually enough to identify a particular file, but when artist or album are present, those are required to match as well.

Although the `Artist Name 1` column is often the album artist, in some cases it is instead a list of contributing artists. To avoid organizing affected files incorrectly, these songs will be skipped unless the artist name is added to an exception list.

## How to Use 
1. Extract all of the zip files into a single directory. Find the folder with the music files and `music uploads metadata.csv`, generally under `Takeout\YouTube and YouTube Music\music (library and uploads)`
2. Open that CSV and review the data for accuracy. Pay particular attention to the values in the `Artist 1` column. In cases where the album artist has commas, slashes, ampersands, and/or semicolons in their name, open the script and add them to the `$artistNamesWithSpecialChars` array at the top of the file. In other cases, you might decide to replace the list with the appropriate album artist.
    - To find these, you can run this pipeline:
        ````pwsh
        Import-Csv "yourpath\music uploads metadata.csv" | Group-Object "Artist Name 1" | Where-Object {$_.Name -match '[,&\/]'}
        ````

3. Invoke the script from the terminal with the following arguments:
   - `MusicPath` **(Required)** - the path to the immediate directory containing the music files
   - `ShowWarnings` **(Optional, Default=$false)** - whether to output warnings when files can't be processed

    For example:
    ```pwsh
    .\organizer.ps1 -MusicPath "yourpath\music (library and uploads)" -ShowWarnings $true
    ```

4. Spot-check the folders to make sure that the artists and albums were identified correctly, and make any necessary adjustments
5. Manually organize any remaining unprocessed files
6. Update file metadata as necessary (Mp3Tag, MusicBrainz Picard, etc.)
7. Move the folders to their final destination

## Limitations
- When multiple songs have the same name and duration, it might not be possible to distinguish them. This is most likely for scenarios where song are effectively duplicates, perhaps one from the original album and another from a "Greatest Hits" compilation.
  - To review and address potential cases manually before running the script, you can run this pipeline:
    ```pwsh
    Import-Csv "yourpath\music uploads metadata.csv" | Group-Object "Song Title" | Where-Object { $_.Count -gt 1}
    ```
- There are some instances where song durations in the CSV are incorrect and do not match the durations of their respective files. There is a 3 second window to account for this, but any larger discrepancies might result in files being skipped
- This script cannot read file metadata outside of a Windows environment, which can result in more files being skipped
- This script does not keep an audit trail and is not designed to be run on already-processed files

## TODO
- Figure out why it says that 6 files were organized on re-run when nothing changed
- Populate missing file metadata from the CSV
- After script completes, make a copy of original CSV, and replace the base one with just the remaining songs
- Make an undo script that re-flattens the files and restores the CSV from backup
- Do something smart with contributing artist list by matching on album name instead?
- Detect multi-artist albums that don't use 
- Multi-pass loop to check for files that couldn't be disambiguated at first, but can after further processing