require 'msgpack'
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
        if value.kind_of?(Types::Base::Time)
            value.to_f
        elsif value.kind_of?(Typelib::CompoundType)
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

    # Provides the methods to run and feed orocos tasks
    class OrocosRb

        attr_reader :tasks

        # Runs a deplyoment very much like:
        #
        #   Orocos.run deployments do
        #    ...
        #   end
        #
        # It does nothing in the block but waits for a stop condition.
        #
        def initialize
            if !Orocos.initialized?
                Orocos.initialize
            end

            @tasks = Hash.new # store name => task mapping
            @deploy_thread = nil
            @writers = Hash.new # stores writers
            @readers = Hash.new # stores readers
        end

        def set_log_all; @log_all = true; end

        def set_no_log; @log_all = false; end

        # deploys the deployments set with initialize
        def deploy(*deployments)

            @deployments = deployments

            @stop_deployments = false

            running = false

            @deploy_thread = Thread.new do
                Orocos.run *@deployments do
                    if @log_all
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
            nil
        end

        # same as task.configure in ruby run scripts
        def configure(task)
            @tasks[task].configure
        end

        # same as task.start in ruby run scripts
        def start(task)
            @tasks[task].start
        end

        # call an operation
        def operation(task, operation_name, arguments)
            @tasks[task].operation(operation_name).callop(*arguments)
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
        def read(task, portname, new_data=true)
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

        # waits for x seconds
        def sleep(seconds)
            Kernel.sleep(seconds)
        end

    end

    # calls methods of a class requested from an io using msgpack messages
    class Caller

        attr_reader :writer
        attr_reader :unpacker
        attr_reader :handler
        attr_reader :verbose
        attr_reader :batch_mode

        def initialize(read_io, write_io, handler, verbose=false, batch_mode=false)
            @writer = write_io
            @unpacker = MessagePack::Unpacker.new(read_io)
            @handler = handler
            @verbose = verbose
            @batch_mode = batch_mode
            @cmd_list = []
        end

        # process messages
        def process
            begin
                if batch_mode
                    process_batch
                else
                    process_direct
                end
            rescue EOFError => e
                false
            end
        end


        # process messages incomming and execute the commands directly
        # returns false if EOF file reached - the connection was closed
        def process_direct
            unpacker.each do |cmd|
                execute_cmd cmd
            end
            true
        end

        # collect the command and reply
        def process_batch
            unpacker.each do |cmd|
                if cmd[0] == "run"
                    @cmd_list.each { |c| execute_cmd c }
                    @cmd_list.clear
                else
                    @cmd_list << cmd
                end
                msg = cmd.to_msgpack
                writer.write(msg).flush
            end
        end
        
        # execute a command and return the answer
        def execute_cmd(cmd)
            begin
                STDERR.puts "ruby side received cmd #{cmd}" if verbose
                reply = @handler.method(cmd[0]).call(*cmd[1])
                msg = [cmd[0],reply].to_msgpack
                STDERR.puts "ruby replies #{reply}" if verbose
            rescue NameError => e
                msg = ["NameError",[e.inspect,e.to_s,e.backtrace]].to_msgpack
            rescue ArgumentError => e
                msg = ["ArgumentError",[e.inspect,e.to_s,e.backtrace]].to_msgpack
            rescue Exception => e
                msg = ["OtherError",[e.inspect,e.to_s,e.backtrace]].to_msgpack
            end
            writer.write(msg)
            writer.flush
        end
    end

end
