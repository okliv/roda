# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The capture_erb plugin allows you to capture the content of a block
    # in an ERB template, and return it as a value, instead of
    # injecting the template block into the template output.
    #
    #   <% value = capture_erb do %>
    #     Some content here.
    #   <% end %>
    #
    # +capture_erb+ can be used inside other methods that are called
    # inside templates.  It can be combined with the inject_erb plugin
    # to wrap template blocks with arbitrary output and then inject the
    # wrapped output into the template.
    #
    # If the output buffer object responds to +capture+ and is not
    # an instance of String (e.g. when +erubi/capture_block+ is being
    # used as the template engine), this will call +capture+ on the
    # output buffer object, instead of setting the output buffer object
    # temporarily to a new object.
    module CaptureERB
      def self.load_dependencies(app)
        app.plugin :render
      end

      module InstanceMethods
        # Temporarily replace the ERB output buffer
        # with an empty string, and then yield to the block.
        # Return the value of the block, converted to a string.
        # Restore the previous ERB output buffer before returning.
        def capture_erb(&block)
          outvar = render_opts[:template_opts][:outvar]
          buf_was = instance_variable_get(outvar)

          if buf_was.respond_to?(:capture) && !buf_was.instance_of?(String)
            buf_was.capture(&block)
          else
            begin
              instance_variable_set(outvar, String.new)
              yield.to_s
            ensure
              instance_variable_set(outvar, buf_was) if outvar && buf_was
            end
          end
        end
      end
    end

    register_plugin(:capture_erb, CaptureERB)
  end
end
