# This is going to be the main namespace for your project
require 'orocos'
include Orocos

# Provides a class that has methods to
#  - start deployments
#  - configure a task
#  - start a task
#  - feed data to a /base/VectorXd Port
#  - read data from a /base/VectorXd Port
#  - connect ports
#  - stop a task
#  - clean up a task
#  - stop deployments
module OropyBridge

    # Server class to run and feed orocos
    class OrocosRbServer

        # Runs a deplyoment very much like:
        #
        #   Orocos.run deployments, default_deplyoments do
        #    ...
        #   end
        #
        # It does nothing in the block but waits for a stop condition.
        #
        def initialize(deployments, default_deplyoments)
            if !Orocos.initialized?
                Orocos.initialize
            end

            @deployments = deployments
            @default_deployments = default_deployments

            @tasks = Hash.new # store name => task mapping
            @deploy_thread = nil
            @writers = Hash.new # stores writers
            @readers = Hase.new # stores readers
        end

        # deploys the deployments set with initialize
        def deploy

            @stop_deployments = false

            @deploy_thread = Thread.new do
                Orocos.run @deployments, @default_deployments do
                    while !@stop_deployments
                        sleep 0.1
                    end
                end
            end

            Orocos.name_service.names.each do |name|
                @tasks[name] = Orocos.TaskContext.get name
            end

        end

        # stops the deployments
        def stop_deployments
            @stop_deployments = true
            @deploy_thread.join
            @tasks = Hash.new
            @deploy_thread = nil
            @writers = Hash.new
            @readers = Hase.new
        end

        #  set properties of a task given by the hash called config_hash
        def apply_config(task, config_hash)
            config = TaskConfiguration.new(@tasks[task].model)
            config.add("default", config_hash)
            config.apply(@tasks[task], "default")
        end

        # same as task.configure in ruby run scripts
        def configure(task)
            @tasks[task].configure
        end

        # same as task.start in ruby run scripts
        def start(task)
            @tasks[task].start
        end

        # Does it like
        #
        #   writer = task.port.writer
        #   writer.write(data)
        #
        # data has to be an array of numerical values
        def write_vector(task, port, data)
            if !@writers([task,port])
                @writers([task,port]) = task.port(port).writer
            end
            @writers([task,port]).write data
        end

        # Does it like
        #
        #   reader = task.port.reader
        #   reader.read(data)
        #
        def read_vector(task, port, new_data=false)
            if !@readers([task,port])
                @readers([task,port]) = task.port(port).reader
            end
            if new_data
                @readers([task,port]).read_new
            else
                @readers([task,port]).read
            end
        end

        # connect ports
        def connect(from_task, from_port, to_task, to_port)
            @tasks[from_task].port(from_port).connect_to @tasks[from_task].port(to_port)
        end

        # same as task.stop in ruby run scripts
        def stop(task)
            @tasks[task].stop
        end

        # same as task.cleanup in ruby run scripts
        def cleanup(task)
            @tasks[task].cleanup
        end

    end

end
