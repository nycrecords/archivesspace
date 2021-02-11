# frozen_string_literal: true

require_relative 'lib/aspace_oauth'
require_relative 'lib/nycid'

oauth_definitions = AppConfig[:authentication_sources].find_all do |as|
  as[:model] == 'ASOauth'
end
unless oauth_definitions.any?
  raise 'OmniAuth plugin enabled but no definitions provided =('
end

# also used for ui [refactor]
AppConfig[:oauth_definitions] = oauth_definitions
ArchivesSpace::Application.extend_aspace_routes(
  File.join(File.dirname(__FILE__), 'routes.rb')
)
require 'omniauth'

Rails.application.config.middleware.use OmniAuth::Builder do
  oauth_definitions.each do |oauth_definition|
    verify_ssl = oauth_definition.fetch(:verify_ssl, true)
    config = oauth_definition[:config]
    if oauth_definition.key? :metadata_parser_url
      idp_metadata_parser = OneLogin::RubySaml::IdpMetadataParser.new
      idp_metadata        = idp_metadata_parser.parse_remote_to_hash(
        oauth_definition[:metadata_parser_url], verify_ssl
      )
      config = idp_metadata.merge(config)
    end
    if config.key? :security
      # replace strings with constants for *_method
      [:digest_method, :signature_method].each do |m|
        if config[:security].key? m
          config[:security][m] = config[:security][m].constantize
        end
      end
    end
    provider oauth_definition[:provider], config
    $stdout.puts "REGISTERED OAUTH PROVIDER WITH CONFIG: #{config}"
  end
end

Rails.application.config.after_initialize do
  class WelcomeController < ApplicationController
    set_access_control  :public => [:index]

    def index
      info = JSONModel::HTTP::get_json('/')
      view_context.database_warning( info )

      if session[:user] && @repositories.length === 0
        if user_can?('create_repository')
          flash.now[:info] = I18n.t("repository._frontend.messages.create_first_repository")
        else
          flash.now[:info] = I18n.t("repository._frontend.messages.no_access_to_repositories")
        end
      end

      if session[:user] && params[:guid]
        user_id = session[:user_uri].split('/').last
        @user = JSONModel(:user).find(user_id)
        if @user.guid.blank?
          @user.guid = params[:guid]
          @user.save
        end
      end
    end
  end
end