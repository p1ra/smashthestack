require 'tire/http/clients/curb'

Tire.configure do
  # logger $stdout
  # logger Rails.logger.instance_variable_get(:@logger).instance_variable_get(:@log_dest), level: 'debug'
  client Tire::HTTP::Client::Curb
  url "http://localhost:9200"
end

module Boolean  
  def self.parse(value)
    return value unless value.is_a? String
    value != '0'
  end
end

module Tire
  module DSL
    #ALTERED: added multi search support
    # Perform a multi-search
    #
    # @see http://www.elasticsearch.org/guide/reference/api/multi-search.html
    def msearch(options = {}, &block)
      Search::Msearch.new(options, &block)
    end
    def multi(queries=[])
      return [] if queries.empty?
      msearch{ |s| queries.each{ |query| s.query query } }.results
    end
  end
  module Search
    class Query
      def wildcard(field, value)
        @value = {wildcard: {field => "*#{value}*"}}
      end
      def text_phrase(field, value)
        @value = {text_phrase: {field => value}}
      end
      def text_phrase_prefix(field, value)
        @value = {text_phrase_prefix: {field => value}}
      end      
    end
    class Facet
      def terms(field, options={})
        all_terms = options.delete(:all_terms) || false
        @value = { :terms => { :field => field, :all_terms => all_terms }.update(options) }
        self
      end
    end
    #ALTERED: added type accessor
    class Search
      attr_reader :types
    end
    #ALTERED: added multi search support
    class Msearch
      def results
        @results  || (perform; @results)
      end

      def response
        @response || (perform; @response)
      end

      def url
        Configuration.url + @path
      end

      def params
        @options.empty? ? '' : '?' + @options.to_param
      end

      def to_curl
        %Q|curl -X GET "#{url}#{params.empty? ? '?' : params.to_s + '&'}pretty=true" -d '#{to_json}'|
      end

      def logged(error=nil)
        if Configuration.logger

          Configuration.logger.log_request '_msearch', '', to_curl

          took = @json['took']  rescue nil
          code = @response.code rescue nil

          if Configuration.logger.level.to_s == 'debug'
            # FIXME: Depends on RestClient implementation
            body = if @json
                     defined?(Yajl) ? Yajl::Encoder.encode(@json, :pretty => true) : MultiJson.encode(@json)
                   else
                     @response.body rescue nil
                   end
          else
            body = ''
          end

          Configuration.logger.log_response code || 'N/A', took || 'N/A', body || 'N/A'
        end
      end
      # Create a new msearch instance
      #
      # @param [Hash] options which will be used to construct a URL query
      attr_reader :parts
      def initialize(options = {}, &block)
        @options = options
        @parts = []
        @path = '/_msearch'
        instance_eval(&block) if block_given?
      end

      def query(query)
        @parts << query
      end

      # The msearch body
      def to_json
        @parts.map do |query|
          [{index: query.indices.first}.to_json, query.to_json]
        end.flatten.join("\n")+"\n"
      end

      # Perform the msearch. The results are returned as Array<Tire::Results::Collection>
      #
      # @return [Tire::Search::Msearch] self
      def perform
        @response = Configuration.client.get(self.url + self.params, self.to_json)
        if @response.failure?
          STDERR.puts "[REQUEST FAILED] #{self.to_curl}\n"
          raise SearchRequestFailed, @response.to_s
        end
        @json     = MultiJson.decode(@response.body)
        @results  = @json['responses'].map {|response| Results::Collection.new(response, @options)}
        return self
      ensure
        logged
      end
    end
  end
  module Model
    module Search
      module ClassMethods      
        #ALTERED: removed search from automatically gathering results so they can be appended to multi-queries
        def search(*args, &block)
          return unless block
          raw_query = query(*args, &block)          
          return raw_query if args.first[:raw]
          klass.call_associate query(*args, &block).results, args.first[:include]
        end
        
        #ALTERED: removed search from automatically gathering results so they can be appended to multi-queries        
        def query(*args, &block)
          default_options = {:type => document_type, :index => index.name}

          if block_given?
            options = args.shift || {}
          else
            query, options = args
            options ||= {}
          end

          sort      = Array( options[:order] || options[:sort] )
          options   = default_options.update(options)

          s = Tire::Search::Search.new(options.delete(:index), options)
          options[:per_page] ||= 10
          s.size( options[:per_page].to_i )
          s.from( options[:page].to_i <= 1 ? 0 : (options[:per_page].to_i * (options[:page].to_i-1)) ) if options[:page]
          s.sort do
            sort.each do |t|
              field_name, direction = t.split(' ')
              by field_name, direction
            end
          end unless sort.empty?

          if block_given?
            block.arity < 1 ? s.instance_eval(&block) : block.call(s)
          else
            s.query { string query }
            # TODO: Actualy, allow passing all the valid options from
            # <http://www.elasticsearch.org/guide/reference/api/search/uri-request.html>
            s.fields Array(options[:fields]) if options[:fields]
          end
        end
      end
    end
    module Persistence
      class << self
        alias included_old included
        def included(base)
          included_old(base)
          base.class_eval{ define_model_callbacks :validation }
        end
      end
      module Storage
        module InstanceMethods
          def freeze
            attributes.freeze
            self
          end
          def save(arg=nil)
            return false unless valid?
            run_callbacks :save do
              # Document#id is set in the +update_elasticsearch_index+ method,
              # where we have access to the JSON response
            end
            self
          end
        end
      end
      module Finders
        module ClassMethods          
          #ALTERED: added associations loading
          def associates(*args)
            options = args.last.is_a?(Hash)? args.pop : {}
            @associated_class_collections = args
            @associated_class_collections.each do |klass, real_klass=klass.to_s.classify.safe_constantize, name=name.underscore| 
              define_method(klass.to_s.pluralize) do |args={}|
                @prefetch ||= {}
                result = @prefetch[klass] if @prefetch[klass]
                result ||= real_klass.search(args){ |s| s.query{ |q| q.term "#{name}_id".to_sym, id } }
                result = options[:default].call if !result.is_a?(Tire::Search::Search) && (result.nil? || result.empty?) && options[:default]
                result
              end
              define_method("add_#{klass.to_s}"){ |args={}| real_klass.create(args.merge("#{name}_id".to_sym => id)) }
              define_method("remove_#{klass.to_s}"){ |id| real_klass.find(id).destroy rescue false}
              define_method(klass.to_s){ |id| real_klass.find(id) }
              alias_method "update_#{klass.to_s}", "add_#{klass.to_s}"
            end
          end
         
          #ALTERED: added associations loading
          def associate(*args)
            options = args.last.is_a?(Hash)? args.pop : {}
            @klass_alias ||= {}
            @associated_classes = args
            @associated_classes.each do |klass|
              @klass_alias[klass] = options[:as] || klass 
              attr_accessor @klass_alias[klass]
            end
            self.before_update_elasticsearch_index Proc.new{self.class.call_associate [self]}
          end
          
          #ALTERED: added assoications loading          
          def call_associate(results, prefetch=[])
            flatten = !results.is_a?(Tire::Results::Collection)
            results = [results].flatten if flatten
            load_associations results, prefetch
            flatten ? results.first : results
          end
          
          #ALTERED: added assoications loading          
          def load_associations(results, prefetchs)
            p_queries = prefetch_queries prefetchs, results
            a_queries = association_queries results
            objects = Tire.multi (p_queries+a_queries)
            prefetch_results prefetchs, results, objects[0...p_queries.size]
            association_results results, objects[p_queries.size..-1]            
          end
          
          #ALTERED: added assoications loading                    
          def prefetch_queries(prefetchs, results)
            return [] unless prefetchs && !prefetchs.empty? && !results.empty?          
            results.to_a.product(prefetchs).map{ |result, prefetch| result.send prefetch.to_s.pluralize, raw:true, per_page:9999999 }
          end

          #ALTERED: added assoications loading                              
          def prefetch_results(prefetchs, results, objects, all_objects=objects.map(&:results).flatten)
            return unless prefetchs && !prefetchs.empty?
            results.to_a.product(prefetchs).each do |result, prefetch|
              hash = result.instance_variable_get(:@prefetch) || {}
              result.instance_variable_set :@prefetch, hash if hash.empty?
              hash[prefetch] = all_objects.select{ |object| object.class.name.underscore == prefetch.to_s && object.send("#{name.underscore}_id") == result.id }
            end
          end
          
          #ALTERED: added assoications loading                    
          def association_queries(results)
            return [] unless @associated_classes && !@associated_classes.empty? && !results.empty?
            @associated_classes.map{ |klass| association_query klass, results }
          end
          
          #ALTERED: added assoications loading          
          def association_query(klass, results, real_klass=klass.to_s.classify.safe_constantize)
            real_klass.search(raw: true, per_page: 9999999){ |s| s.query{ |q| q.ids results.map(&"#{@klass_alias[klass]}_id".to_sym).uniq, klass } }
          end
          
          #ALTERED: added assoications loading               
          def association_results(results, objects)
            return unless @associated_classes && !@associated_classes.empty?
            @associated_classes.zip(objects).each{ |klass, object| association_result klass, results, object }
          end          
          
          #ALTERED: added assoications loading          
          def association_result(klass, results, objects)
            results.each{ |result| result.send "#{@klass_alias[klass]}=", objects.find{ |object| result.send("#{@klass_alias[klass]}_id") == object.id } }            
          end
          
          def all(args={})
            search(args){ query { all } }
          end  
                
          def find *args
            # TODO: Options like `sort`
            old_wrapper = Tire::Configuration.wrapper
            Tire::Configuration.wrapper self
            options = args.last.is_a?(Hash)? args.pop : {}
            flattened_args = args.flatten
            results = if args.first.is_a? Array
              Tire::Search::Search.new(index.name) do |search|
                search.query do |query|
                  query.ids(flattened_args, document_type)
                end
                search.size flattened_args.size
              end.results
            else
              case args = flattened_args.pop
              when Fixnum, String
                index.retrieve document_type, args
              when :all, :first
                send(args)
              else
                raise ArgumentError, "Please pass either ID as Fixnum or String, or :all, :first as an argument"
              end
            end
            #ALTERED: added assoications loading            
            call_associate results, options[:include]
          ensure
            Tire::Configuration.wrapper old_wrapper
          end
        end
      end
      module Attributes
        module InstanceMethods
          def __update_attributes(attributes)
            attributes.each { |name, value| send "#{name}=", __cast_value(name, value) if respond_to? "#{name}=" }
          end
          def __cast_value(name, value)
            case
            when klass = self.class.property_types[name.to_sym]
              if klass.is_a?(Array) && value.is_a?(Array)
                value.map { |v| klass.first.new(v) }
              elsif klass == Fixnum
                value.to_i
              elsif klass == Boolean
                Boolean.parse value
              else
                klass.new(value)
              end
            when value.is_a?(Hash)
              Hashr.new(value)
            else
              # Strings formatted as <http://en.wikipedia.org/wiki/ISO8601> are automatically converted to Time
              value = Time.parse(value) if value.is_a?(String) && value =~ /^\d{4}[\/\-]\d{2}[\/\-]\d{2}T\d{2}\:\d{2}\:\d{2}Z$/
              value
            end
          end          
        end
        module ClassMethods
          def property(name, options = {})
            # Define attribute reader:
            define_method("#{name}") do
              value = instance_variable_get(:"@#{name}")
              value ||= self.class.property_defaults[name.to_sym]
              # ALTERED: added ability to use proc for default value
              value = value.call if value.respond_to? :call
              value
            end

            # Define attribute writer:
            define_method("#{name}=") do |value|
              instance_variable_set(:"@#{name}", value)
            end

            # Save the property in properties array:
            properties << name.to_s unless properties.include?(name.to_s)

            # Define convenience <NAME>? method:
            define_query_method      name.to_sym

            # ActiveModel compatibility. NEEDED?
            define_attribute_methods [name.to_sym]

            # Save property default value (when relevant):
            unless (default_value = options.delete(:default)).nil?
              property_defaults[name.to_sym] = default_value
            end

            # Save property casting (when relevant):
            property_types[name.to_sym] = options[:class] if options[:class]

            # Store mapping for the property:
            mapping[name] = options
            self
          end
        end
      end
    end
  end
 module Results
    class Collection
      def results
        @results ||= begin
                       hits = @response['hits']['hits']
                       unless @options[:load]
                         if @wrapper == Hash
                           hits
                         else
                           hits.map do |h|
                document = {}

                # Update the document with content and ID
                document = h['_source'] ? document.update( h['_source'] || {} ) : document.update( __parse_fields__(h['fields']) )
                document.update( {'id' => h['_id']} )

                # Update the document with meta information
                ['_score', '_type', '_index', '_version', 'sort', 'highlight'].each { |key| document.update( {key => h[key]} || {} ) }

                # ALTERED: added ability to load class for type automatically
                @wrapper = document['_type'].camelize.constantize rescue @wrapper

                # Return an instance of the "wrapper" class
                @wrapper.new(document)
              end
                         end
                       else
                         return [] if hits.empty?

                         type  = @response['hits']['hits'].first['_type']
                         raise NoMethodError, "You have tried to eager load the model instances, " +
                           "but Tire cannot find the model class because " +
                           "document has no _type property." unless type

                         begin
                           klass = type.camelize.constantize
                         rescue NameError => e
                           raise NameError, "You have tried to eager load the model instances, but " +
                             "Tire cannot find the model class '#{type.camelize}' " +
                             "based on _type '#{type}'.", e.backtrace
                         end

                         ids   = @response['hits']['hits'].map { |h| h['_id'] }
                         records =  @options[:load] === true ? klass.find(ids) : klass.find(ids, @options[:load])

                         # Reorder records to preserve order from search results
                         ids.map { |id| records.detect { |record| record.id.to_s == id.to_s } }
                       end
                     end
      end
    end
  end
end
