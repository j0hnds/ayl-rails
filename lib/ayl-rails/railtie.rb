module Ayl

  class Railtie < ::Rails::Railtie

    # The hooks to be created/installed on ActiveRecord::Base
    HOOKS = [ :after_update, :after_create, :after_save ]

    initializer "Ayl::Railtie.extend" do
      # Want the ayl_send/opts at the instance level
      ActiveRecord::Base.send :include, Extensions
      # Want the instance-level stuff there.
      ActiveRecord::Base.send :include, InstanceExtensions
      # Want the ayl_send/opts at the class level as well
      ActiveRecord::Base.send :extend, Extensions
    end

    initializer "Ayl::Railtie.hooks" do

      class << ActiveRecord::Base

        # Add each of the hooks to ActiveRecord::Base
        HOOKS.each do | hook |
          method_code = <<-EOF
            def ayl_#{hook}(*args, &block)
              add_ayl_hook(#{hook.inspect}, *args, &block)
            end
          EOF
          class_eval(method_code, __FILE__, __LINE__ - 1)
        end

        def add_ayl_hook(hook, *args, &block)
          if args && args.first.is_a?(Symbol)
            method = args.shift
            ayl_hooks(*args)[hook] << lambda{|o| o.send(method)}
          else
            ayl_hooks(*args)[hook] << block
          end
        end

        def ayl_hooks(*args)
          @ayn_hooks ||= Hash.new do |hash, hook|
            # Remember: this block is invoked only once for each
            # access of a key that has not been used before.
            
            # Define the name of a method that the standard hook
            # method will call when the standard hook fires
            ahook = "_ayl_#{hook}".to_sym
            
            # This is for the producer's benefit
            # So, this is the equivalent of performing the following
            # in the ActiveRecord class:
            # 
            #   after_create { |o| ayl_send(:_ayl_after_create, o)
            #
            # What this means is that the block will be executed after
            # the model has been save/created.
            #
            # So, the self.class target for the ayl_send is because we
            # need to call the ayl_send method at the singleton level.
            #
            send(hook, *args) { |o| self.class.ayl_send(ahook, o) }

            # This is for the worker's benefit
            #
            # This defines the instance method
            method_code = <<-EOF
              def #{ahook}(o)
                _run_ayl_hooks(#{hook.inspect}, o)
              end
            EOF
            instance_eval(method_code, __FILE__, __LINE__ - 1)

            hash[hook] = []
          end
        end

        def _run_ayl_hooks(hook, o)
          ayl_hooks[hook].each { |b| b.call(o) }
        end

      end
      
    end

  end

end
