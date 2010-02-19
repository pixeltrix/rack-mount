require 'rack/mount/utils'
require 'forwardable'

module Rack::Mount
  module Generation
    module RouteSet
      # Adds generation related concerns to RouteSet.new.
      def initialize(*args)
        @named_routes = {}
        @generation_key_analyzer = Analysis::Frequency.new

        super
      end

      # Adds generation aspects to RouteSet#add_route.
      def add_route(*args)
        route = super
        @named_routes[route.name] = route if route.name
        @generation_key_analyzer << route.generation_keys
        route
      end

      # Generates a url from Rack env and identifiers or significant keys.
      #
      # To generate a url by named route, pass the name in as a +Symbol+.
      #   url(env, :dashboard) # => "/dashboard"
      #
      # Additional parameters can be passed in as a hash
      #   url(env, :people, :id => "1") # => "/people/1"
      #
      # If no name route is given, it will fall back to a slower
      # generation search.
      #   url(env, :controller => "people", :action => "show", :id => "1")
      #     # => "/people/1"
      def url(env, *args)
        named_route, params = nil, {}

        case args.length
        when 2
          named_route, params = args[0], args[1].dup
        when 1
          if args[0].is_a?(Hash)
            params = args[0].dup
          else
            named_route = args[0]
          end
        else
          raise ArgumentError
        end

        only_path = params.delete(:only_path)
        recall = env[@parameters_key] || {}

        unless result = generate([:host, :path_info], named_route, params, recall,
            :parameterize => lambda { |name, param| Utils.escape_uri(param) })
          return
        end

        parts, params = result
        return unless parts

        params.each do |k, v|
          if v
            params[k] = v
          else
            params.delete(k)
          end
        end

        req = RequestProxy.new(@request_class.new(env), {
          :host => parts[0],
          :path_info => parts[1],
          :query_string => Utils.build_nested_query(params)
        })
        only_path ? reconstruct_path(req) : reconstruct_url(req)
      end

      def generate(method, *args) #:nodoc:
        raise 'route set not finalized' unless @generation_graph

        named_route, params, recall, options = extract_params!(*args)
        merged = recall.merge(params)
        route = nil

        if named_route
          if route = @named_routes[named_route.to_sym]
            recall = route.defaults.merge(recall)
            url = route.generate(method, params, recall, options)
            [url, params]
          else
            raise RoutingError, "#{named_route} failed to generate from #{params.inspect}"
          end
        else
          keys = @generation_keys.map { |key|
            if k = merged[key]
              k.to_s
            else
              nil
            end
          }
          @generation_graph[*keys].each do |r|
            next unless r.significant_params?
            if url = r.generate(method, params, recall, options)
              return [url, params]
            end
          end

          raise RoutingError, "No route matches #{params.inspect}"
        end
      end

      def rehash #:nodoc:
        @generation_keys  = build_generation_keys
        @generation_graph = build_generation_graph

        super
      end

      private
        def expire!
          @generation_keys = @generation_graph = nil
          @generation_key_analyzer.expire!
          super
        end

        def flush!
          @generation_key_analyzer = nil
          super
        end

        def build_generation_graph
          build_nested_route_set(@generation_keys) { |k, i|
            throw :skip unless @routes[i].significant_params?

            if k = @generation_key_analyzer.possible_keys[i][k]
              k.to_s
            else
              nil
            end
          }
        end

        def build_generation_keys
          @generation_key_analyzer.report
        end

        def extract_params!(*args)
          case args.length
          when 4
            named_route, params, recall, options = args
          when 3
            if args[0].is_a?(Hash)
              params, recall, options = args
            else
              named_route, params, recall = args
            end
          when 2
            if args[0].is_a?(Hash)
              params, recall = args
            else
              named_route, params = args
            end
          when 1
            if args[0].is_a?(Hash)
              params = args[0]
            else
              named_route = args[0]
            end
          else
            raise ArgumentError
          end

          named_route ||= nil
          params  ||= {}
          recall  ||= {}
          options ||= {}

          [named_route, params.dup, recall.dup, options.dup]
        end

        class RequestProxy
          def initialize(request, params)
            @_request, @_params = request, params
          end

          def method_missing(sym, *args, &block)
            @_params[sym] || @_request.send(sym, *args, &block)
          end
        end

        # TODO: Make this block configurable
        def reconstruct_path(req)
          url = "#{req.script_name}#{req.path_info}"
          url << "?#{req.query_string}" unless req.query_string.empty?
          url
        end

        # TODO: Make this block configurable
        def reconstruct_url(req)
          url = "#{req.scheme}://#{req.host}"

          scheme, port = req.scheme, req.port
          if scheme == "https" && port != 443 ||
              scheme == "http" && port != 80
            url << ":#{port}"
          end

          url << req.script_name + req.path_info
          url << "?#{req.query_string}" unless req.query_string.empty?

          url
        end
    end
  end
end
