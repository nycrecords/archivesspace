class AgentContact < Sequel::Model(:agent_contact)
  include ASModel
  plugin :validation_helpers

  many_to_one :agent_person

end
