class ArchivesSpaceService < Sinatra::Base

  RESOLVE_LIST = ["subjects", "related_resources", "linked_agents", "revision_statements", "container_locations", "digital_object", "classifications", "related_agents", "resource", "parent", "creator", "linked_instances", "linked_records", "related_accessions", "linked_events", "linked_events::linked_records", "linked_events::linked_agents", "top_container", "container_profile", "location_profile", "owner_repo", "agent_places", "agent_occupations", "agent_functions", "agent_topics", "agent_resources", "places"]

  Endpoint.post('/merge_requests/subject')
    .description("Carry out a merge request against Subject records")
    .params(["merge_request",
             JSONModel(:merge_request), "A merge request",
             :body => true])
    .permissions([:merge_subject_record])
    .returns([200, :updated]) \
  do
    target, victims = parse_references(params[:merge_request])

    ensure_type(target, victims, 'subject')

    Subject.get_or_die(target[:id]).assimilate(victims.map {|v| Subject.get_or_die(v[:id])})

    json_response(:status => "OK")
  end

  Endpoint.post('/merge_requests/container_profile')
    .description("Carry out a merge request against Container Profile records")
    .example('shell') do
    <<~SHELL
    curl -H 'Content-Type: application/json' \\
        -H "X-ArchivesSpace-Session: $SESSION" \\
        -d '{"uri": "merge_requests/container_profile", "target": {"ref": "/container_profiles/1" },"victims": [{"ref": "/container_profiles/2"}]}' \\
        "http://localhost:8089/merge_requests/container_profile"
    SHELL
    end
    .example('python') do
    <<~PYTHON
    from asnake.client import ASnakeClient
    client = ASnakeClient()
    client.authorize()
    client.post('/merge_requests/container_profile',
            json={
                'uri': 'merge_requests/container_profile',
                'target': {
                    'ref': '/container_profiles/1'
                  },
                'victims': [
                    {
                        'ref': '/container_profiles/2'
                    }
                  ]
                }
          )
    PYTHON
    end
    .params(["merge_request",
             JSONModel(:merge_request), "A merge request",
             :body => true])
    .permissions([:update_container_profile_record])
    .returns([200, :updated]) \
  do
    target, victims = parse_references(params[:merge_request])

    ensure_type(target, victims, 'container_profile')

    ContainerProfile.get_or_die(target[:id]).assimilate(victims.map {|v| ContainerProfile.get_or_die(v[:id])})

    json_response(:status => "OK")
  end

  Endpoint.post('/merge_requests/top_container')
    .description("Carry out a merge request against Top Container records")
    .example('shell') do
    <<-SHELL
curl -H 'Content-Type: application/json' \\
    -H "X-ArchivesSpace-Session: $SESSION" \\
    -d '{"uri": "merge_requests/top_container", "target": {"ref": "/repositories/2/top_containers/1" },"victims": [{"ref": "/repositories/2/top_containers/2"}]}' \\
    "http://localhost:8089/merge_requests/top_container?repo_id=2"
    SHELL
    end
    .example('python') do
    <<~PYTHON
    from asnake.client import ASnakeClient
    client = ASnakeClient()
    client.authorize()
    client.post('/merge_requests/top_container?repo_id=2',
            json={
                'uri': 'merge_requests/top_container',
                'target': {
                    'ref': '/repositories/2/top_containers/80'
                  },
                'victims': [
                    {
                        'ref': '/repositories/2/top_containers/171'
                    }
                  ]
                }
          )
    PYTHON
    end
    .params(["repo_id", :repo_id],
            ["merge_request",
             JSONModel(:merge_request), "A merge request",
             :body => true])
    .permissions([:manage_container_record])
    .returns([200, :updated]) \
  do
    target, victims = parse_references(params[:merge_request])

    check_repository(target, victims, params[:repo_id])
    ensure_type(target, victims, 'top_container')

    TopContainer.get_or_die(target[:id]).assimilate(victims.map {|v| TopContainer.get_or_die(v[:id])})

    json_response(:status => "OK")

  end


  Endpoint.post('/merge_requests/agent')
    .description("Carry out a merge request against Agent records")
    .params(["merge_request",
             JSONModel(:merge_request), "A merge request",
             :body => true])
    .permissions([:merge_agent_record])
    .returns([200, :updated]) \
  do
    target, victims = parse_references(params[:merge_request])

    if (victims.map {|r| r[:type]} + [target[:type]]).any? {|type| !AgentManager.known_agent_type?(type)}
      raise BadParamsException.new(:merge_request => ["Agent merge request can only merge agent records"])
    end

    agent_model = AgentManager.model_for(target[:type])
    agent_model.get_or_die(target[:id]).assimilate(victims.map {|v|
                                                     AgentManager.model_for(v[:type]).get_or_die(v[:id])
                                                   })

    json_response(:status => "OK")
  end

  Endpoint.post('/merge_requests/agent_detail')
  .description("Carry out a detailed merge request against Agent records")
  .params(["dry_run", BooleanParam, "If true, don't process the merge, just display the merged record", :optional => true],
          ["merge_request_detail",
             JSONModel(:merge_request_detail), "A detailed merge request",
             :body => true])
  .permissions([:merge_agent_record])
  .returns([200, :updated]) \
  do
    target, victims = parse_references(params[:merge_request_detail])
    selections = parse_selections(params[:merge_request_detail].selections)

    if (victims.map {|r| r[:type]} + [target[:type]]).any? {|type| !AgentManager.known_agent_type?(type)}
      raise BadParamsException.new(:merge_request_detail => ["Agent merge request can only merge agent records"])
    end
    agent_model = AgentManager.model_for(target[:type])
    target = agent_model.get_or_die(target[:id])
    victim = agent_model.get_or_die(victims[0][:id])
    if params[:dry_run]
      target = agent_model.to_jsonmodel(target)
      victim = agent_model.to_jsonmodel(victim)
      new_target = merge_details(target, victim, selections, params)
      result = resolve_references(new_target, RESOLVE_LIST)

      json_response(resolve_references(result, RESOLVE_LIST))
    else
      target_json = agent_model.to_jsonmodel(target)
      victim_json = agent_model.to_jsonmodel(victim)
      new_target = merge_details(target_json, victim_json, selections, params)

      target.assimilate((victims.map {|v|
                                       AgentManager.model_for(v[:type]).get_or_die(v[:id])
                                     }))

      #update lock version which may have happened during call to #assimilate
      target_json_updated = agent_model.to_jsonmodel(target)
      new_target['lock_version'] = target_json_updated['lock_version']

      if selections != {}
        begin
          target.update_from_json(new_target)
        rescue => e
          STDERR.puts "EXCEPTION!"
          STDERR.puts e.message
        end
      end

      json_response(:status => "OK")
    end
  end

  Endpoint.post('/merge_requests/resource')
    .description("Carry out a merge request against Resource records")
    .params(["repo_id", :repo_id],
            ["merge_request",
             JSONModel(:merge_request), "A merge request",
             :body => true])
    .permissions([:merge_archival_record])
    .returns([200, :updated]) \
  do
    target, victims = parse_references(params[:merge_request])

    check_repository(target, victims, params[:repo_id])
    ensure_type(target, victims, 'resource')

    Resource.get_or_die(target[:id]).assimilate(victims.map {|v| Resource.get_or_die(v[:id])})

    json_response(:status => "OK")
  end


  Endpoint.post('/merge_requests/digital_object')
    .description("Carry out a merge request against Digital_Object records")
    .params(["repo_id", :repo_id],
            ["merge_request",
             JSONModel(:merge_request), "A merge request",
             :body => true])
    .permissions([:merge_archival_record])
    .returns([200, :updated]) \
  do
    target, victims = parse_references(params[:merge_request])

    check_repository(target, victims, params[:repo_id])
    ensure_type(target, victims, 'digital_object')

    DigitalObject.get_or_die(target[:id]).assimilate(victims.map {|v| DigitalObject.get_or_die(v[:id])})

    json_response(:status => "OK")
  end


  private

  def parse_references(request)
    target = JSONModel.parse_reference(request.target['ref'])
    victims = request.victims.map {|victim| JSONModel.parse_reference(victim['ref'])}

    [target, victims]
  end

  def check_repository(target, victims, repo_id)
    repo_uri = JSONModel(:repository).uri_for(repo_id)

    if ([target] + victims).any? {|r| r[:repository] != repo_uri}
      raise BadParamsException.new(:merge_request => ["All records to merge must be in the repository specified"])
    end
  end


  def ensure_type(target, victims, type)
    if (victims.map {|r| r[:type]} + [target[:type]]).any? {|t| t != type}
      raise BadParamsException.new(:merge_request => ["This merge request can only merge #{type} records"])
    end
  end

  def parse_selections(selections, path=[], all_values={})
    selections.each_pair do |k, v|
      path << k
      case v
        when String
          if v === "REPLACE"
            all_values.merge!({"#{path.join(".")}" => "#{v}"})
            path.pop
          else
            path.pop
            next
          end
        when Hash then parse_selections(v, path, all_values)
        when Array then v.each_with_index do |v2, index|
          path << index
          parse_selections(v2, path, all_values)
        end
        path.pop
        else
          path.pop
          next
      end
    end
    path.pop
    return all_values
  end

  # when merging, set the agent id foreign key (e.g, agent_person_id, agent_family_id...) from the victim to the target
  def set_agent_id(target_id, subrecord)
    if subrecord['agent_person_id']
      subrecord['agent_person_id'] = target_id

    elsif subrecord['agent_family_id']
      subrecord['agent_family_id'] = target_id

    elsif subrecord['agent_corporate_entity_id']
      subrecord['agent_corporate_entity_id'] = target_id

    elsif subrecord['agent_software_id']
      subrecord['agent_software_id'] = target_id

    # this section updates related_agents ids
    elsif subrecord['agent_person_id_0']
      subrecord['agent_person_id_0'] = target_id
      
    elsif subrecord['agent_family_id_0']
      subrecord['agent_family_id_0'] = target_id

    elsif subrecord['agent_corporate_entity_id_0']
      subrecord['agent_corporate_entity_id_0'] = target_id
    end
    
  end

  def merge_details(target, victim, selections, params)
    target[:linked_events] = []
    victim[:linked_events] = []

    subrec_add_replacements = []
    field_replacements = []
    victim_values = {}
    values_from_params = params[:merge_request_detail].selections

    # this code breaks selections into arrays like this:
    # ["agent_record_identifiers", 1, "append"] // add entire subrec
    # ["agent_record_controls", 0, "replace"] // replace entire subrec
    # ["agent_record_controls", 0, "maintenance_status_enum"] // replace field
    # ["agent_record_controls", 0, "publication_status_enum"] // replace field
    # ["agent_record_controls", 0, "maintenance_agency"]
    # and then creates data structures for the subrecords to append, replace entirely, and replace by field.
    selections.each_key do |key|
      path = key.split(".")
      path_fix = []
      path.each do |part|
        if part.length === 1
          part = part.to_i
        elsif (part.length === 2) and (part.start_with?('1'))
          part = part.to_i
        end
        path_fix.push(part)
      end

      subrec_name = path_fix[0]
      victim_values[subrec_name] = values_from_params[subrec_name]

      # subrec level add/replace 
      if path_fix[2] == "append" || path_fix[2] == "replace"
        subrec_add_replacements.push(path_fix)

      # field level replace
      else
        field_replacements.push(path_fix)
      end
    end

    merge_details_subrec(target, victim, subrec_add_replacements, victim_values)
    merge_details_replace_field(target, victim, field_replacements, victim_values)

    target['title'] = target['names'][0]['sort_name']
    target
  rescue => e
    STDERR.puts "EXCEPTION!"
    STDERR.puts e.inspect

  end

  # do field replace operations
  def merge_details_replace_field(target, victim, selections, values)
    selections.each do |path_fix|
      subrec_name = path_fix[0]
      # this is the index of the order the user arranged the subrecs in the form, not the order of the subrecords in the DB.
      ind         = path_fix[1]
      field       = path_fix[2]

      subrec_id = values[subrec_name][ind]["id"]
      subrec_index = find_subrec_index_in_victim(victim, subrec_name, subrec_id)

      target[subrec_name][ind][field] = victim[subrec_name][subrec_index][field]
    end
  end


  # do subrec replace operations
  def merge_details_subrec(target, victim, selections, values)
    selections.each do |path_fix|
      subrec_name = path_fix[0]
      # this is the index of the order the user arranged the subrecs in the form, not the order of the subrecords in the DB.
      ind         = path_fix[1] 
      mode        = path_fix[2]

      subrec_id = values[subrec_name][ind]["id"]
      subrec_index = find_subrec_index_in_victim(victim, subrec_name, subrec_id)

      replacer = victim[subrec_name][subrec_index]

      # notes are a special case because of the way they store JSON in a db field. So Reordering is not supported, and we can assume the position in the merge request is the position in the victims notes subrecord JSON.
      if subrec_name == "notes"
        replacer = victim["notes"][ind]
        to_append = process_subrecord_for_merge(target, replacer, subrec_name, mode, ind)

        target[subrec_name].push(process_subrecord_for_merge(target, replacer, subrec_name, mode, ind))
      elsif mode == "replace"
        target[subrec_name][ind] = process_subrecord_for_merge(target, replacer, subrec_name, mode, ind)
      elsif mode == "append"
        target[subrec_name].push(process_subrecord_for_merge(target, replacer, subrec_name, mode, ind))
      end

    end
  end

  # we don't know how the user reordered the subrecords on the merge form,
  # so find the index with the right data given the ID of the right thing to replace/add by searching for it.
  def find_subrec_index_in_victim(victim, subrec_name, subrec_id)
    ind = nil
    victim[subrec_name].each_with_index do |subrec, i|
      if subrec["id"] == subrec_id
        ind = i
        break
      end
    end

    return ind
  end

  # before we can merge a subrecord, we need to update the IDs, tweak things to prevent validation issues, etc
  def process_subrecord_for_merge(target, subrecord, jsonmodel_type, mode, ind)
    target_id = target['id']

    if jsonmodel_type == 'names'
      # an agent name can only have one authorized or display name.
      # make sure the name being merged in doesn't conflict with this

      # if appending, always disable fields that validate across a set. If replacing, always keep values from target 
      if mode == "append"
        subrecord['authorized']      = false
        subrecord['is_display_name'] = false
      elsif mode == "replace"
        subrecord['authorized']      = target['names'][ind]['authorized']
        subrecord['is_display_name'] = target['names'][ind]['is_display_name']
      end

    elsif jsonmodel_type == 'agent_record_identifiers'
      # same with agent_record_identifiers being marked as primary, we can only have one

      if mode == "append"
        subrecord['primary_identifier'] = false

      elsif mode == "replace"
        subrecord['primary_identifier'] = target['agent_record_identifiers'][ind]['primary_identifier']
      end
    end

    set_agent_id(target_id, subrecord)

    return subrecord
  end

  # don't try to replace these values from victim to target when merging, ever!
  def skippable_record_key?(k)
    k == "agent_person_id" ||
    k == "agent_family_id" ||
    k == "agent_corporate_entity_id" ||
    k == "agent_software_id" ||
    k == "created_by" ||
    k == "last_modified_by" ||
    k == "create_time" ||
    k == "system_mtime" ||
    k == "user_mtime" ||
    k == "lock_version" ||
    k == "primary_identifier" || # only one primary identifier allowed in set 
    k == "jsonmodel_type"
  end

  # NOTE: this code is a duplicate of the auto_generate code for creating sort name
  # in the name_person, name_family, name_software, name_corporate_entity models
  # Consider refactoring when continued work done on the agents model enhancements
  def preview_sort_name(target)
    result = ""

    case target['jsonmodel_type']
    when 'name_person'
      if target["name_order"] === "inverted"
        result << target["primary_name"] if target["primary_name"]
        result << ", #{target["rest_of_name"]}" if target["rest_of_name"]
      elsif target["name_order"] === "direct"
        result << target["rest_of_name"] if target["rest_of_name"]
        result << " #{target["primary_name"]}" if target["primary_name"]
      else
        result << target["primary_name"] if target["primary_name"]
      end

      result << ", #{target["prefix"]}" if target["prefix"]
      result << ", #{target["suffix"]}" if target["suffix"]
      result << ", #{target["title"]}" if target["title"]
      result << ", #{target["number"]}" if target["number"]
      result << " (#{target["fuller_form"]})" if target["fuller_form"]
      result << ", #{target["dates"]}" if target["dates"]
    when 'name_corporate_entity'
      result << "#{target["primary_name"]}" if target["primary_name"]
      result << ". #{target["subordinate_name_1"]}" if target["subordinate_name_1"]
      result << ". #{target["subordinate_name_2"]}" if target["subordinate_name_2"]

      grouped = [target["number"], target["dates"]].reject{|v| v.nil?}
      result << " (#{grouped.join(" : ")})" if not grouped.empty?
    when 'name_family'
      result << target["family_name"] if target["family_name"]
      result << ", #{target["prefix"]}" if target["prefix"]
      result << ", #{target["dates"]}" if target["dates"]
    when 'name_software'
      result << "#{target["manufacturer"]} " if target["manufacturer"]
      result << "#{target["software_name"]}" if target["software_name"]
      result << " #{target["version"]}" if target["version"]
    end

    result << " (#{target["qualifier"]})" if target["qualifier"]
    result << " (#{target["sort_name_date_string"]})" if target["sort_name_date_string"]

    result.lstrip!

    if result.length > 255
      return result[0..254]
    else
      return result
    end

  end
end
