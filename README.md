# YouTube Music Takeout Organizer

## Problem
If you uploaded your personal music files to YouTube Music and have now downloaded them through Google Takeout, you will have noticed that a ton of file metadata is inconsistently missing. In some cases, only clobbered filenames remain (e.g. track numbers have been removed, certain characters are replaced with underscores).

The Takeout data does include a CSV file that contains the list of exported songs, including columns for title, album, artists, and duration. However, it is left to the user to manually reorganize and retag the files.

This is extremely cumbersome when you are dealing with thousands of songs.

## Solution
This PowerShell script will reorganize the files in an `Album Artist > Album > Song` folder hierarchy within the music folder root. Any files that aren't able to be organized will remain at the root for manual processing.

## How It Works
This script parses the CSV one row at a time, determines which file is the best match, and then uses the `Artist Name 1` and `Album Title` columns to move it to the correct destination folder.

When a song name is unique, this can be handled trivially. When there are multiple songs with the same name, or multiple songs share the same clobbered filename, the CSV data will be compared to the available file metadata. The song duration is usually enough to identify a particular file, but when artist or album are present, those are required to match as well.

Although the `Artist Name 1` column is often the album artist, in some cases it is instead a list of contributing artists. To avoid organizing affected files incorrectly, these songs will be skipped unless the artist name is added to an exception list.

## How to Use 
1. Extract all of the zip files into a single directory. Find the folder with the music files and `music uploads metadata.csv`, generally under<br>`Takeout\YouTube and YouTube Music\music (library and uploads)`.
2. Open this CSV and review the data for accuracy.
    - Pay particular attention to the values in the `Artist 1` column. In the rare cases where the album artist name actually has commas, slashes, ampersands, and/or semicolons in their name, open the script and add them to the `$artistNamesWithSpecialChars` array at the top of the file. In other cases, you might decide to replace the value with the appropriate album artist.
    - To find these, you can run this pipeline:
        ````pwsh
        Import-Csv "yourpath\music uploads metadata.csv" | Group-Object "Artist Name 1" | Where-Object {$_.Name -match '[,&\/]'}
        ````

3. Invoke the script from the terminal with the following arguments:
   - `MusicPath` **(Required)** - the path to the immediate directory containing the music files
   - `Verbose` - include to show messages whenever a song can't be organized

    For example:
    ```pwsh
    .\organizer.ps1 -MusicPath "yourpath\music (library and uploads)" -Verbose
    ```

4. Spot-check the folders to make sure that the artists and albums were identified correctly, and make any necessary adjustments.
   - If your library contains soundtracks with songs credited to a single artist, that artist probably received their own folder.
5. Manually organize any remaining unprocessed files.
6. Update file names and metadata as necessary. (Mp3Tag, MusicBrainz Picard, etc.)
7. Move the folders to their final destination.
8. ***Highly Recommended*** - Create a proper backup strategy for your music so that you never have to export from YTM again. 😉

## Limitations
- This script can only read file metadata within Windows, which can result in more files being skipped when run on Linux or macOS.
- When multiple songs have the same name and duration, it might not be possible to distinguish them. This is most likely for scenarios where song are effectively duplicates, perhaps one from the original album and another from a "Greatest Hits" compilation.
  - To review and address potential cases manually before running the script, you can run this pipeline:
    ```pwsh
    Import-Csv "yourpath\music uploads metadata.csv" | Group-Object "Song Title" | Where-Object { $_.Count -gt 1}
    ```
- There are some instances where song durations in the CSV are incorrect and do not match the durations of their respective files. There is a 3 second window to account for this, but any larger discrepancies might result in files being skipped.
- This script is not designed to be run multiple times on the same dataset.
- 
## TODO
- Figure out why it says that 6 files were organized on re-run when nothing changed
  
## Enhancement Opportunities
- Make this script more cross-platform by using TagLib# or ffprobe to read file metadata
- Automatically populate missing file metadata from the CSV
- Add a second pass through the CSV that attempts to handle "stragglers" which couldn't originally be matched, but can now that there is only one viable candidate
- Remove organized songs from the CSV after completion, to make manual cleanup simpler and allow the script to be run multiple times
- More intelligently handle a list of contributing artists by matching on album name instead?
- Detect multi-artist compilation/soundtrack albums where each individual song has a single artist, and group them under one artist folder