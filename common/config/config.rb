###############################################################################
## This file shows the ArchivesSpace configuration values used for DORIS.
##
## Note that there is no need to uncomment these unless you plan to change the
## value from its default.
###############################################################################

# Plug-ins to load. They will load in the order specified
AppConfig[:plugins] = ['local',  'lcnaf', 'aspace-doris-public']

# The following determine which 'tabs' are on the main horizontal menu
AppConfig[:pui_hide][:repositories] = true
AppConfig[:pui_hide][:digital_objects] = true
AppConfig[:pui_hide][:accessions] = true

# Enable / disable PUI resource/archival object page actions
AppConfig[:pui_page_actions_cite] = false
AppConfig[:pui_page_actions_request] = false