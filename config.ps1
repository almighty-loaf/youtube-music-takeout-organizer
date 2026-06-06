#############################################
# CONFIGURATION
#############################################

$overrideAlbumArtists = @{
    "Super Smash Bros. for Nintendo 3DS/Wii U" = "Nintendo"
}

# This utility only cares about Album Artists since that's how it groups the albums.
# However, YTMusic often puts contributing artists in the "Artist Name 1" column of the CSV.
# These often look like "Name1, Name2" or "Name1 / Name2" and are not consistent across
# each song, resulting in albums getting split across 5+ different folders - especially
# for compilation albums with many different artists.
#
# For this reason, any artist names that contain any of ,;/& will be grouped under
# "Various Artists" by default.
#
# !! Add exceptions here:
$albumArtists = @(
    "AC/DC",
    "Earth, Wind & Fire"
)