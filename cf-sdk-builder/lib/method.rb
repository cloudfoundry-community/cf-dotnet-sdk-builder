module SDKBuilder
  class Method
    attr_reader :name, :description, :parameters, :return, :http_method, :route, :explanation, :request, :endpoint, :fields

    def initialize(name, endpoint, raw_method)
      unless name
        raise 'A method cannot be initialized without a name.'
      end

      unless raw_method
        raise "Method #{name} cannot be initialized without raw data."
      end

      @raw = raw_method
      @fields = get_fields
      @name = name
      @description = raw_method['description']
      @explanation = raw_method['explanation']

      @endpoint = endpoint
      @request = (raw_method["requests"] && raw_method["requests"]["request"]) ? raw_method["requests"]["request"][0] : nil

      if (@request && @request["request_path"].end_with?("/"))
        @route = raw_method["route"].chomp("/") + "/"
      else
        @route = raw_method["route"].chomp("/")
      end

      @parameters = url_parameters + request_parameters

      @return = return_value
      @http_method = @raw['http_method']
    end

    private

    def url_parameters
      route = @raw['route']
      Method.get_route_params(route).map do |param|
        SDKBuilder::Parameter.new(param, self, "The #{param} parameter is used as a part of the request URL: '#{route}'")
      end
    end

    def get_fields
      fields = {}
      if @raw && @raw['fields'] && @raw['fields']['field']
        @raw['fields']['field'].each do |field|
          if field["valid_values"]
            fields[field["name"]] = Array(field["valid_values"]["valid_value"])[0]
          elsif field["example_values"]
            fields[field["name"]] = Array(field["example_values"]["example_value"])[0]
          else
            fields[field["name"]] = nil
          end
        end
      end
      fields
    end

    # TODI: vladi: this might need to be return_type
    def return_value
      requests = @raw['requests']

      if requests
        request = requests['request'].first

        if request['response_body']
          response_body = request['response_body']

          # TODO: vladi: we need to flag DataClass instances that are incapsulated, so we know how to generate code
          if response_body.is_json?
            obj = JSON.parse(response_body)

            raw_entity = obj.to_json

            if !obj.is_a?(Array)
              if obj['resources']
                raw_entity = [obj['resources'].inject(&:deep_merge)['entity']].to_json
              elsif obj['entity']
                raw_entity = obj['entity'].to_json
              end
            end
            # TODO: vladi: put a description of some sorts in here
            SDKBuilder::Parameter.new('@return', self, '', raw_entity)
          else
            # TODO: vladi: put a description of some sorts in here
            SDKBuilder::Parameter.new('@return', self, '', request['response_body'])
          end
        else
          nil
        end
      else
        nil
      end
    end

    def request_parameters
      requests = @raw['requests']

      if requests
        request = requests['request'].first

        if request['request_body']
          [SDKBuilder::Parameter.new('value', self, 'An object instance that is serialized and sent as the request body.', request['request_body'])]
        else
          []
        end
      else
        []
      end
    end

    def self.get_route_params(route)
      route.split('/').select { |part| part.start_with? ':' }.map { |param| param.gsub(/:/, '') }
    end

    def self.get_string_format_route(route)
      idx = -1
      pieces = route.split('/').map do |part|
        if part.start_with?(':')
          idx = idx + 1
          "{#{idx}}"
        else
          part
        end
      end

      pieces.join('/')
    end
  end
end
