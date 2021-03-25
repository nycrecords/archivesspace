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

# Maximum results and number of search results on a page
AppConfig[:pui_search_results_page_size] = 9999
AppConfig[:max_page_size] = 9999
AppConfig[:pui_global_search_results_page_size] = 50

# SMTP Settings
AppConfig[:contact_form_recipient] = ''
AppConfig[:contact_form_sender] = 'no-reply@records.nyc.gov'
AppConfig[:smtp_settings] = {
  address: 'localhost',
  port: 25,
  authentication: 'plain',
  openssl_verify_mode: 'none'
}

AppConfig[:db_url] = "jdbc:mysql://localhost:3306/archivesspace?user=root&password=root@123&useUnicode=true&characterEncoding=UTF-8&allowPublicKeyRetrieval=true&useSSL=false"