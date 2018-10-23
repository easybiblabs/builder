module Response
  def json_response(object, status = 200)
    status status
    object.to_json
  end
end