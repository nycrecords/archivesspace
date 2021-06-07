require "aspace_gems"
ASpaceGems.setup

require './app/main'

def app
  ArchivesSpaceService
end

require 'rack/protection'

map "/" do
  use Rack::Protection, :except => [:remote_token, :session_hijacking], :permitted_origins => [AppConfig[:frontend_proxy_url], AppConfig[:frontend_url], AppConfig[:public_proxy_url], AppConfig[:public_url], 'https://accounts-nonprd.nyc.gov']
  run ArchivesSpaceService
end
