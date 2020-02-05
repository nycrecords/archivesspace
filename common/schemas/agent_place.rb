{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",

    "properties" => {
      "place_role_enum" => {"type" => "string", "dynamic_enum" => "place_role_enum"},

      "dates" => {
        "type" => "array",
        "items" => {"type" => "JSONModel(:structured_date_label) object"}
      },

      "notes" => {
        "type" => "array",
        "items" => {"type" => [{"type" => "JSONModel(:note_text) object"},
                               {"type" => "JSONModel(:note_citation) object"}]},
      },

      "id"                        => {"type" => "integer", "required" => false},
      "subjects" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "subtype" => "ref",
          "properties" => {
            "ref" => {
              "type" => "JSONModel(:subject) uri",
              "ifmissing" => "error"
            },
            "_resolved" => {
              "type" => "object",
              "readonly" => "true"
            }
          }
        }
      },
    },
  },
}