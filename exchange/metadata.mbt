///|
pub fn encoding_name(encoding : @xpt.Encoding) -> String {
  match encoding {
    @xpt.Ascii => "ascii"
    @xpt.Windows1252 => "windows-1252"
  }
}

///|
pub fn parse_encoding(name : String) -> @xpt.Encoding raise @xpt.XptError {
  match name {
    "ascii" => @xpt.Ascii
    "windows-1252" => @xpt.Windows1252
    _ => @xpt.fail("encoding", "unsupported encoding: \{name}")
  }
}

///|
pub fn format_json(
  f : @xpt.DisplayFormat,
  encoding : @xpt.Encoding,
) -> Json raise @xpt.XptError {
  {
    "name": @xpt.text_field(f.name, encoding),
    "width": f.width,
    "decimals": f.decimals,
    "justification": f.justification,
  }
}

///|
pub fn variable_json(
  v : @xpt.VariableMetadata,
  encoding : @xpt.Encoding,
) -> Json raise @xpt.XptError {
  {
    "name": @xpt.text_field(v.name, @xpt.Ascii),
    "label": @xpt.text_field(v.label, encoding),
    "type": if v.kind == @xpt.Number {
      "numeric"
    } else {
      "character"
    },
    "width": v.width,
    "position": v.position,
    "number": v.number,
    "hash": v.hash,
    "format": format_json(v.format, encoding),
    "informat": format_json(v.informat, encoding),
  }
}

///|
pub fn dataset_json(
  meta : @xpt.DatasetMetadata,
  encoding : @xpt.Encoding,
) -> Json raise @xpt.XptError {
  let variables : Array[Json] = []
  for v in meta.variables {
    variables.push(variable_json(v, encoding))
  }
  {
    "name": @xpt.text_field(meta.name, @xpt.Ascii),
    "label": @xpt.text_field(meta.label, encoding),
    "dataset_type": @xpt.text_field(meta.dataset_type, encoding),
    "version": @xpt.text_field(meta.version, @xpt.Ascii),
    "os": @xpt.text_field(meta.os, @xpt.Ascii),
    "created": @xpt.text_field(meta.created, @xpt.Ascii),
    "modified": @xpt.text_field(meta.modified, @xpt.Ascii),
    "descriptor_size": meta.descriptor_size,
    "row_width": meta.row_width,
    "variables": variables,
  }
}

///|
pub fn library_json(meta : @xpt.LibraryMetadata) -> Json raise @xpt.XptError {
  {
    "version": @xpt.text_field(meta.version, @xpt.Ascii),
    "os": @xpt.text_field(meta.os, @xpt.Ascii),
    "created": @xpt.text_field(meta.created, @xpt.Ascii),
    "modified": @xpt.text_field(meta.modified, @xpt.Ascii),
  }
}

///|
pub fn diagnostic_json(d : @xpt.Diagnostic) -> Json {
  {
    "kind": d.kind,
    "offset": d.offset.map(integer_json).unwrap_or(Json::null()),
    "member": d.dataset.map(Json::string).unwrap_or(Json::null()),
    "row": d.row.map(integer_json).unwrap_or(Json::null()),
    "variable": d.variable.map(Json::string).unwrap_or(Json::null()),
    "reason": d.reason,
  }
}

///|
/// Keep exact decimal JSON integers; core Int64 ToJson intentionally uses strings.
pub fn integer_json(n : Int64) -> Json {
  Json::number(n.to_double(), repr=n.to_string())
}
