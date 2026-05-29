# YouTube Music Takeout Organizer

## Problem
If you upload your personal music files to YouTube Music and later download them through Google Takeout, you'll discover that much if not all of the metadata has been stripped. In some cases, only clobbered filenames remain.

The Takeout data does include a csv file that contains the list of exported songs, including columns for title, album, artist, and duration. However, they leave it to the user to associate the files with the csv rows, reorganize the files, and retag them with the appropriate metadata.

## Solution
This PowerShell script will parse the CSV and do its best to create an `Album Artist > Album > Song` filesystem hierarchy within the music folder root.

Any files that lack sufficient information to organize will remain at the root.

## Usage
Extract all of the zip files into a single directory. Then invoke `organizer.ps1` from the terminal with the following arguments:

`-MusicPath` **(Required)** - the path to the folder containing the music files and the `music uploads metadata.csv` file. This will be named something like `music (library and uploads)`.

`-ShowWarnings` **(Optional, Default=$false)** - whether to output warnings when files can't be processed

## Caveats
- When multiple songs have the same name, it might not be possible to determine which artist or album they belong to. This script will do its best to break ties by correlating CSV rows to file metadata.
- Running the script 

## TODO
- Figure out why it says that 6 files were organized on re-run when nothing changed
- Populate missing file metadata from the CSV?