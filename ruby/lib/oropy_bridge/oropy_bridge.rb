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

    def self.type_to_ruby(value)
        if value.kind_of?(Typelib::CompoundType)
            result = Hash.new
            value.each_field do |field_name, field_value|
                result[field_name] = type_to_ruby(field_value)
            end
            result
        elsif value.kind_of?(Symbol)
            value.to_s
        elsif value.respond_to?(:to_str)
            value.to_str
        elsif value.kind_of?(Typelib::ArrayType) || value.kind_of?(Typelib::ContainerType)
            value.raw_each.map(&method(:type_to_ruby))
        elsif value == nil
            nil
        elsif value.respond_to?(:to_a)
            value.to_a.each do |v|
                type_to_ruby(v)
            end
        elsif value.kind_of?(Typelib::Type)
            Typelib.to_ruby(value)
        else
            value
        end
    end

    # Server class to run and feed orocos
    class OrocosRbServer

        attr_reader :tasks

        # Runs a deplyoment very much like:
        #
        #   Orocos.run deployments do
        #    ...
        #   end
        #
        # It does nothing in the block but waits for a stop condition.
        #
        def initialize(*deployments)
            if !Orocos.initialized?
                Orocos.initialize
            end

            @deployments = deployments

            @tasks = Hash.new # store name => task mapping
            @deploy_thread = nil
            @writers = Hash.new # stores writers
            @readers = Hash.new # stores readers
        end

        # deploys the deployments set with initialize
        def deploy(log_all=false)

            @stop_deployments = false

            running = false

            @deploy_thread = Thread.new do
                Orocos.run *@deployments do
                    if log_all
                        Orocos.log_all
                    end
                    running = true
                    while !@stop_deployments
                        sleep 0.1
                    end
                end
            end

            # to be sure to find all tasks
            while !running; end

            Orocos.name_service.each_task do |task|
                @tasks[task.name] = task
            end

        end

        # stops the deployments
        def stop_deployments
            @stop_deployments = true
            @deploy_thread.join
            @tasks = Hash.new
            @deploy_thread = nil
            @writers = Hash.new
            @readers = Hash.new
        end

        #  set properties of a task given by the hash called config_hash
        def apply_config(task, config_hash)
            config = Orocos::TaskConfigurations.new(@tasks[task].model)
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

        # this is special for type_to_vector components to create ports
        def addPort(task, port_config_hash)
            pc = Typelib.from_ruby(port_config_hash, Orocos.registry.get("/type_to_vector/PortConfig"))
            @tasks[task].addPort(pc)
        end

        # Does it like
        #
        #   writer = task.port.writer
        #   writer.write(data)
        #
        # data must be a hash matching the type structure
        def write(task, portname, data)
            if !@writers[[task,portname]]
                port = @tasks[task].port(portname)
                type = port.type_name
                @writers[[task,portname]] = [port.writer, Orocos.registry.get(type)]
            end
            data = Typelib.from_ruby(data,@writers[[task,portname]][1])
            @writers[[task,portname]][0].write data
        end

        # Meant to write to ports with type base::VectorXd.
        # Data has to be an array of numerical values.
        def write_vector(task, portname,data)
            write(task, portname, {'data' => data})
        end

        # Does it like
        #
        #   reader = task.port.reader
        #   data = reader.read
        #
        def read(task, portname, new_data=false)
            if !@readers[[task,portname]]
                port = @tasks[task].port(portname)
                type = port.type_name
                @readers[[task,portname]] = [port.reader, Orocos.registry.get(type)]
            end
            if new_data
                data = @readers[[task,portname]][0].read_new
            else
                data = @readers[[task,portname]][0].read
            end
            OropyBridge.type_to_ruby(data)
        end

        # Directly returns the content of the 'data' field.
        # That could be used in conjunction with base::VectorXd.
        def read_vector(task, portname, new_data=false)
            if data = read(task,portname,new_data)
                return data["data"]
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
