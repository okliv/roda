# frozen-string-literal: true

require 'tilt'
# :nocov:
raise 'Tilt version does not support coverable templates' unless Tilt::Template.method_defined?(:compiled_path=)
# :nocov:

#
class Roda
  module RodaPlugins
    # The render_coverage plugin builds on top of the render plugin
    # and sets compiled_path on created templates.  This allows
    # Ruby's coverage library before Ruby 3.2 to consider code created
    # by templates. You may not need this plugin on Ruby 3.2+, since
    # on Ruby 3.2+, coverage can consider code loaded with +eval+.
    # This plugin is only supported when using tilt 2.1+, since it
    # requires the compiled_path supported added in tilt 2.1. 
    #
    # By default, the render_coverage plugin will use +coverage/views+
    # as the directory containing the compiled template files.  You can
    # change this by passing the :dir option when loading the plugin.
    # By default, the plugin will set the compiled_path by taking the
    # template file path, stripping off any of the allowed_paths used
    # by the render plugin, and converting slashes to dashes. You can
    # override the allowed_paths to strip by passing the :strip_paths
    # option when loading the plugin.  Paths outside :strip_paths (or
    # the render plugin allowed_paths if :strip_paths is not set) will
    # not have a compiled_path set.
    #
    # Due to how Ruby's coverage library works in regards to loading
    # a compiled template file with identical code more than once,
    # it may be beneficial to run coverage testing with the
    # +RODA_RENDER_COMPILED_METHOD_SUPPORT+ environment variable set
    # to +no+ if using this plugin.
    module RenderCoverage
      def self.load_dependencies(app, opts=OPTS)
        app.plugin :render
      end

      # Use the :dir option to set the directory to store the compiled
      # template files, and the :strip_paths directory for paths to
      # strip.
      def self.configure(app, opts=OPTS)
        app.opts[:render_coverage_strip_paths] = opts[:strip_paths].map{|f| File.expand_path(f)} if opts.has_key?(:strip_paths)
        coverage_dir = app.opts[:render_coverage_dir] = opts[:dir] || app.opts[:render_coverage_dir] || 'coverage/views'
        Dir.mkdir(coverage_dir) unless File.directory?(coverage_dir)
      end

      module ClassMethods
        # Set a compiled path on the created template, if the path for
        # the template is in one of the allowed_views.
        def create_template(opts, template_opts)
          template = super
          return template if opts[:template_block]

          path = File.expand_path(opts[:path])
          (self.opts[:render_coverage_strip_paths] || render_opts[:allowed_paths]).each do |dir|
            if path.start_with?(dir + '/')
              template.compiled_path = File.join(self.opts[:render_coverage_dir], path[dir.length+1, 10000000].gsub('/', '-'))
              break
            end
          end

          template
        end
      end

      module InstanceMethods
        private

        # Convert template paths to real paths to try to ensure the same template is cached.
        def template_path(opts)
          path = super

          if File.file?(path)
            File.realpath(path)
          else
            path
          end
        end
      end
    end

    register_plugin(:render_coverage, RenderCoverage)
  end
end
