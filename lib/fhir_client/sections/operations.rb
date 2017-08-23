module FHIR
  module Sections
    module Operations
      # DSTU 2 Operations: http://hl7.org/implement/standards/FHIR-Develop/operations.html

      # Concept Translation	[base]/ConceptMap/$translate | [base]/ConceptMap/[id]/$translate

      # Closure Table Maintenance	[base]/$closure

      # Fetch Patient Record	[base]/Patient/$everything | [base]/Patient/[id]/$everything
      # http://hl7.org/implement/standards/FHIR-Develop/patient-operations.html#everything
      # Fetches resources for a given patient record, scoped by a start and end time, and returns a Bundle of results
      def fetch_patient_record(id = nil, startTime = nil, endTime = nil, method = 'GET', format = @default_format)
        fetch_record(id, [startTime, endTime], method, FHIR::Patient, format)
      end

      def fetch_encounter_record(id = nil, method = 'GET', format = @default_format)
        fetch_record(id, [nil, nil], method, FHIR::Encounter, format)
      end

      def fetch_record(id = nil, time = [nil, nil], method = 'GET', klass = FHIR::Patient, format = @default_format)
        options = { resource: klass, format: format, operation: { name: :fetch_patient_record, method: method } }
        options.deep_merge!(id: id) unless id.nil?
        options[:operation][:parameters] = {} if options[:operation][:parameters].nil?
        options[:operation][:parameters][:start] = { type: 'Date', value: time.first } unless time.first.nil?
        options[:operation][:parameters][:end] = { type: 'Date', value: time.last } unless time.last.nil?

        if options[:operation][:method] == 'GET'
          reply = get resource_url(options), fhir_headers(options)
        else
          # create Parameters body
          if options[:operation] && options[:operation][:parameters]
            p = FHIR::Parameters.new
            options[:operation][:parameters].each do |key, value|
              parameter = FHIR::Parameters::Parameter.new.from_hash(name: key.to_s)
              parameter.method("value#{value[:type]}=").call(value[:value])
              p.parameter << parameter
            end
          end
          reply = post resource_url(options), p, fhir_headers(options)
        end

        reply.resource = parse_reply(FHIR::Bundle, format, reply)
        reply.resource_class = options[:resource]
        reply
      end

      # Build Questionnaire	[base]/Profile/$questionnaire | [base]/Profile/[id]/$questionnaire

      # Populate Questionnaire	[base]/Questionnaire/$populate | [base]/Questionnaire/[id]/$populate

      # Value Set Expansion	[base]/ValueSet/$expand | [base]/ValueSet/[id]/$expand
      # http://hl7.org/implement/standards/FHIR-Develop/valueset-operations.html#expand
      # The definition of a value set is used to create a simple collection of codes suitable for use for data entry or validation.
      def value_set_expansion(params = {}, format = @default_format)
        options = { resource: FHIR::ValueSet, operation: { name: :value_set_expansion } }
        options.deep_merge!(params)
        terminology_operation(options, format)
      end

      # Value Set based Validation	[base]/ValueSet/$validate | [base]/ValueSet/[id]/$validate
      # http://hl7.org/implement/standards/FHIR-Develop/valueset-operations.html#validate
      # Validate that a coded value is in the set of codes allowed by a value set.
      def value_set_code_validation(params = {}, format = @default_format)
        options = { resource: FHIR::ValueSet, operation: { name: :value_set_based_validation } }
        options.deep_merge!(params)
        terminology_operation(options, format)
      end

      # Concept Look Up [base]/CodeSystem/$lookup
      def code_system_lookup(params = {}, format = @default_format)
        options = { resource: FHIR::CodeSystem, operation: { name: :code_system_lookup } }
        options.deep_merge!(params)
        terminology_operation(options, format)
      end

      # ConceptMap Translation
      def concept_map_translate(params = {}, format = @default_format)
        options = { resource: FHIR::ConceptMap, operation: { name: :concept_map_translate } }
        options.deep_merge!(params)
        terminology_operation(options, format)
      end

      # ConceptMap Closure Table Maintenance
      def closure_table_maintenance(params = {}, format = @default_format)
        options = { operation: { name: :closure_table_maintenance } }
        options.deep_merge!(params)
        terminology_operation(options, format)
      end

      def terminology_operation(params = {}, format = @default_format)
        options = { format: format }
        # params = [id, code, system, version, display, coding, codeableConcept, date, abstract]
        options.deep_merge!(params)

        if options[:operation][:method] == 'GET'
          reply = get resource_url(options), fhir_headers(options)
        else
          # create Parameters body
          if options[:operation] && options[:operation][:parameters]
            p = FHIR::Parameters.new
            options[:operation][:parameters].each do |key, value|
              parameter = FHIR::Parameters::Parameter.new.from_hash(name: key.to_s)
              parameter.method("value#{value[:type]}=").call(value[:value])
              p.parameter << parameter
            end
          end
          reply = post resource_url(options), p, fhir_headers(options)
        end

        reply.resource = parse_reply(options[:resource], format, reply)
        reply.resource_class = options[:resource]
        reply
      end

      def match(resource, options = {}, format = @default_format)
        options.merge!(resource: resource.class, match: true, format: format)
        params = FHIR::Parameters.new
        add_resource_parameter(params, 'resource', resource)
        add_parameter(params, 'onlyCertainMatches', 'Boolean', options[:onlyCertainMatches]) unless options[:onlyCertainMatches].nil?
        add_parameter(params, 'count', 'Integer', options[:matchCount]) if options[:matchCount].is_a?(Integer)
        post resource_url(options), params, fhir_headers(options)
      end

      #
      # Validate resource payload.
      #
      # @param resourceClass
      # @param resource
      # @param id
      # @return
      #
      # public <T extends Resource> AtomEntry<OperationOutcome> validate(Class<T> resourceClass, T resource, String id);

      def validate(resource, options = {}, format = @default_format)
        options.merge!(resource: resource.class, validate: true, format: format)
        params = FHIR::Parameters.new
        add_resource_parameter(params, 'resource', resource)
        add_parameter(params, 'profile', 'Uri', options[:profile_uri]) unless options[:profile_uri].nil?
        post resource_url(options), params, fhir_headers(options)
      end

      def validate_existing(resource, id, options = {}, format = @default_format)
        options.merge!(resource: resource.class, id: id, validate: true, format: format)
        params = FHIR::Parameters.new
        add_resource_parameter(params, 'resource', resource)
        add_parameter(params, 'profile', 'Uri', options[:profile_uri]) unless options[:profile_uri].nil?
        post resource_url(options), params, fhir_headers(options)
      end

      private

      def add_parameter(params, name, type, value)
        params.parameter ||= []
        parameter = FHIR::Parameters::Parameter.new.from_hash(name: name)
        parameter.method("value#{type}=").call(value)
        params.parameter << parameter
      end

      def add_resource_parameter(params, name, resource)
        params.parameter ||= []
        parameter = FHIR::Parameters::Parameter.new.from_hash(name: name)
        parameter.resource = resource
        params.parameter << parameter
      end

    end
  end
end
