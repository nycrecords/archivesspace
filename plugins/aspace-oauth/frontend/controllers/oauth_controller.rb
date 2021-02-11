# frozen_string_literal: true

class OauthController < ApplicationController
  skip_before_action :unauthorised_access
  skip_before_action :verify_authenticity_token
  include JSONModel

  # IMPLEMENTS: /auth/:provider/callback
  # Successful authentication populates the auth_hash with data
  # that is written to the system tmpdir. This is used to verify
  # the user for the backend and then deleted.
  def create
    saml_attrs = request.env['omniauth.auth'].extra.response_object.attributes
    nycidwebservices = NYCID::NYCIDWebServices.new

    if saml_attrs[:nycExtEmailValidationFlag] == 'False'
      email_validation_status = nycidwebservices.check_email_validation_status(saml_attrs[:GUID])
      if email_validation_status == false
        redirect_to nycidwebservices.validate_email(saml_attrs[:mail])
        return
      end
    end

    # Get the User Attributes from NYC.ID
    user_json = nycidwebservices.search_user(saml_attrs[:GUID])

    # Get the domain for the Users' email address
    email_domain = user_json['email'].split('@').last

    # Users whose email domain is in the approved list are not allowed to login
    unless AppConfig[:approved_domains].include?(email_domain)
      flash[:error] = 'Authentication error, unable to login. Your email address is not in the list approved domains.'
      redirect_to controller: :welcome, action: :index
      return
    end

    pw      = "aspace-oauth-#{auth_hash[:provider]}-#{SecureRandom.uuid}"
    pw_path = File.join(Dir.tmpdir, pw)
    backend_session = nil

    uid = auth_hash.uid
    email = user_json["email"]
    username = user_json["email"]
    guid = user_json["id"]
    puts "Received callback for: [uid: #{uid}], [email: #{email}]"

    if username && email
      username = username.split('@')[0] # usernames cannot be email addresses
      auth_hash[:info][:username] = username # set username, checked in backend
      auth_hash[:info][:email] = email # ensure email is set in info
      File.open(pw_path, 'w') { |f| f.write(JSON.generate(auth_hash)) }
      backend_session = User.login(username, pw)
    end

    if backend_session
      User.establish_session(self, backend_session, username)
      load_repository_list
    else
      flash[:error] = 'Authentication error, unable to login.'
    end

    File.delete pw_path if File.exist? pw_path
    redirect_to controller: :welcome, action: :index, guid: guid
  end

  def failure
    flash[:error] = params[:message]
    redirect_to controller: :welcome, action: :index
  end

  def cas_logout
    reset_session
    redirect_to AspaceOauth.cas_logout_url
  end

  def saml_logout
    reset_session
    redirect_to AspaceOauth.saml_logout_url
  end

  protected

  def auth_hash
    request.env['omniauth.auth']
  end
end