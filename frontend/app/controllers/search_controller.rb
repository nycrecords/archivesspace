require 'advanced_query_builder'

class SearchController < ApplicationController

  set_access_control  "view_repository" => [:do_search, :advanced_search, :search_subject_types, :search_agent_types]
  MAX_RAW_SEARCH_RESULTS = 9999
  include ExportHelper

  def advanced_search
    criteria = params_for_backend_search

    queries = advanced_search_queries.reject{|field|
      (field["value"].nil? || field["value"] == "") && !field["empty"]
    }

    if not queries.empty?
      criteria["aq"] = AdvancedQueryBuilder.build_query_from_form(queries).to_json
      criteria['facet[]'] = SearchResultData.BASE_FACETS
    end



    respond_to do |format|
      format.json {
        @search_data = Search.all(session[:repo_id], criteria)
        render :json => @search_data
      }
      format.js {
        @search_data = Search.all(session[:repo_id], criteria)
        if params[:listing_only]
          render_aspace_partial :partial => "search/listing"
        else
          render_aspace_partial :partial => "search/results"
        end
      }
      format.html {
        @search_data = Search.all(session[:repo_id], criteria)
        render "search/do_search"
      }
      format.csv {
        uri = "/repositories/#{session[:repo_id]}/search"
        csv_response( uri, Search.build_filters(criteria), "#{I18n.t('search_results.title').downcase}." )
      }
    end
  end

  def do_search
    @search_data = Search.all(session[:repo_id], params_for_backend_search.merge({"facet[]" => SearchResultData.BASE_FACETS.concat(params[:facets]||[]).uniq}))

    respond_to do |format|
      format.json {
        render :json => @search_data
      }
      format.js {
        if params[:listing_only]
          render_aspace_partial :partial => "search/listing"
        else
          render_aspace_partial :partial => "search/results"
        end
      }
      format.html {
        # default render
      }
      format.csv {
        criteria = params_for_backend_search.merge({"facet[]" => SearchResultData.BASE_FACETS})
        uri = "/repositories/#{session[:repo_id]}/search"
        csv_response( uri, Search.build_filters(criteria), "#{I18n.t('search_results.title').downcase}." )
      }
    end
  end

  def search_subject_types

    subject_types = Search.all(session[:repo_id], params_for_backend_search.merge({"facet[]" => SearchResultData.BASE_FACETS.concat([]).uniq,"type[]" => ["subject"],"page_size"=>MAX_RAW_SEARCH_RESULTS}))
    subject_types = JSON.parse(subject_types.to_json)
    term_types_hash = Hash.new{|hsh,key| hsh[key] = [] }
    subject_types['search_data']['results'].each do |result|
      parsed_result = JSON.parse(result['json'])
      term_types_hash[parsed_result['title']].push(parsed_result['terms'][0]['term_type'])
    end
    render :json => term_types_hash
  end

  def search_agent_types

    @search_data = Search.all(session[:repo_id], params_for_backend_search.merge({"facet[]" => SearchResultData.BASE_FACETS.concat(params[:facets]||[]).uniq,"page_size"=>MAX_RAW_SEARCH_RESULTS}))
    search_results = JSON.parse(@search_data.to_json)
    result_hash = Hash.new
    search_results['search_data']['results'].each do |result|
      result_hash.merge!({result['title'] => result['primary_type']})
    end
    render :json => result_hash

  end



end
