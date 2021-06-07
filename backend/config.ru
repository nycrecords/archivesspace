require "aspace_gems"
ASpaceGems.setup

require './app/main'

def app
  ArchivesSpaceService
end

require 'rack/protection'

map "/" do
  use Rack::Protection, :except => :remote_token
  run ArchivesSpaceService
end
