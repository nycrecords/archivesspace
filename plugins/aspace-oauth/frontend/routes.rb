# frozen_string_literal: true

ArchivesSpace::Application.routes.draw do
  scope AppConfig[:frontend_proxy_prefix] do
    # OMNIAUTH GENERATED ROUTES:
    # OMNIAUTH:      /auth/:provider
    # OMNIAUTH-SAML: /auth/saml/metadata
    # OMNIAUTH-SAML: /auth/saml/slo
    # OMNIAUTH-SAML: /auth/saml/spslo

    get  format('%s/:provider/callback', AppConfig[:auth_path_prefix]),  to: 'oauth#create'
    post format('%s/:provider/callback', AppConfig[:auth_path_prefix]),  to: 'oauth#create'
    get  format('%s/failure', AppConfig[:auth_path_prefix]),             to: 'oauth#failure'
    get  format('%s/cas_logout', AppConfig[:auth_path_prefix]),          to: 'oauth#cas_logout'
    get  format('%s/saml_logout', AppConfig[:auth_path_prefix]),         to: 'oauth#saml_logout'
  end
end
