class IdpLogoutController < ApplicationController
  set_access_control  "view_repository" => [:index, :show],
                      "manage_repository" => [:defaults, :update_defaults]

  def show
    @title = "Logout"
    @idp_logout_url = AppConfig[:idp_logout_url]
    reset_session
    render template: "idp_logout/show.html.erb"
  end
end