class ContactController < ApplicationController
  require 'mail'
  include ViewHelper
  include ActionView::Helpers::TextHelper
  include ResultInfo
  helper_method :process_repo_info
  helper_method :process_subjects
  helper_method :process_agents

  skip_before_action :verify_authenticity_token

  # Removed langcode
  DEFAULT_RES_FACET_TYPES = %w{primary_type subjects published_agents}
  DEFAULT_RES_INDEX_OPTS = {
      'resolve[]' => ['repository:id', 'resource:id@compact_resource', 'top_container_uri_u_sstr:id'],
      'sort' => 'title_sort asc',
      'facet.mincount' => 1
  }

  DEFAULT_RES_SEARCH_OPTS = {
      'resolve[]' => ['repository:id', 'resource:id@compact_resource', 'ancestors:id@compact_resource', 'top_container_uri_u_sstr:id'],
      'facet.mincount' => 1
  }

  DEFAULT_RES_SEARCH_PARAMS = {
      q: ['*'],
      limit: 'resource',
      op: [''],
      field: ['title']
  }
  DEFAULT_RES_TYPES = %w{pui_archival_object pui_digital_object agent subject}

  DEFAULT_AC_TYPES = %w{accession}
  DEFAULT_AC_FACET_TYPES = %w{primary_type subjects published_agents repository}
  DEFAULT_AC_SEARCH_OPTS = {
      'sort' => 'title_sort asc',
      'resolve[]' => ['repository:id', 'resource:id@compact_resource', 'ancestors:id@compact_resource'],
      'facet.mincount' => 1
  }
  DEFAULT_AC_SEARCH_PARAMS = {
      :q => ['*'],
      :limit => 'accession',
      :op => ['OR'],
      :field => ['title']
  }

  def show
    @research_links = Hash.new
    # Fetching the list of repositories
    @criteria = {}
    @criteria['sort'] = 'repo_sort asc'
    @criteria['page_size'] = 100
    @search_data = archivesspace.search('primary_type:repository', 1, @criteria) || {}

    @search_data['results'].each do |repo_list|
      hash = ASUtils.json_parse(repo_list['json']) || {}
      @repo_id = hash['uri'].split('/')[-1]
      # Fetching all the resources
      @base_search = "#{@repo_id}/resources?"
      repo = archivesspace.get_record("/repositories/#{@repo_id}")
      @repo_name = repo.display_string
      search_opts = default_search_opts(DEFAULT_RES_INDEX_OPTS)
      search_opts['fq'] = ["repository:\"/repositories/#{@repo_id}\""] if @repo_id
      DEFAULT_RES_SEARCH_PARAMS.each do |k, v|
        params[k] = v unless params.fetch(k, nil)
      end
      page = Integer(params.fetch(:page, '1'))
      facet_types = %w{primary_type subjects published_agents creators}
      begin
        set_up_and_run_search(['resource'], facet_types, search_opts, params)
      rescue Exception => error
        flash[:error] = I18n.t('errors.unexpected_error')
        redirect_back(fallback_location: '/') and return
      end
      @context = repo_context(@repo_id, 'resource')
      @result_props = {
          :no_res => true
      }
      @no_statement = true
      collections_data = Array.new
      @results.records.each do |result|
        result_hash = {"ref" => resource_base_url(result), "title" => result.display_string}
        collections_data.push(result_hash)
      end
      collections_data.map! { |hsh| OpenStruct.new(hsh) }
      @research_links['collections'] = collections_data
      @research_links = OpenStruct.new @research_links
      @page_title = 'Contact Us'
    end
    render
  end

  def compose
    email_body = ''
    name = params[:name].html_safe
    email = params[:email_address]
    email_body += '<div><strong>Name</strong><br>' + name + '</div><br>'
    email_body += '<div><strong>Email</strong><br>' + email + '</div>'
    email_body += '<div>' + simple_format(params[:description].html_safe) + '</div>'

    if params.has_key?(:research_request)
      research_requests = params[:research_request]

      if research_requests.has_key?('collections')
        email_body += '<p><b>Requested Collections</b></p><ul>'
        research_requests['collections'].each do |collection|
          email_body += '<li>' + collection + '</li>'
        end
        email_body += '</ul>'
      end
    end

    if params.has_key?(:additional_links) && params[:additional_links] != ''
      email_body += '<p><b>Additional links</b></p>' +
          '<p>' + simple_format(params[:additional_links].html_safe) + '</p>'
    end

    # Set contact form sender
    contact_form_sender = AppConfig[:submitter_as_contact_form_sender] ? email : AppConfig[:contact_form_sender]

    mail = Mail.new do
      from contact_form_sender
      to [AppConfig[:contact_form_recipient], email]
      subject '(ArchivesSpace) Research Request from ' + name
      html_part do
        content_type 'text/html; charset=UTF-8'
        body email_body
      end
    end
    Mail.defaults do
      delivery_method :smtp, AppConfig[:smtp_settings]
    end
    mail.deliver
    redirect_to action: 'show'
  end
end