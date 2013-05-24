try:
    import msgpack
except ImportError, e:
    print "\x1b[31;1mInstall msgpack for python manually:"
    print "   [apt-get install python-pip]"
    print "    pip install --user msgpack-python\x1b[0m"
    raise e
import time
import socket
import subprocess
from sys import stderr

class OrocosRb:
    ''' Provides all the methods to interact with orogen tasks.'''

    def __init__(self, cmd_forwarder):
        ''' Initialization.

            Args:
                cmd_forwarder: A class with a *process* method that takes a msg and
                    forwards it to the serving entity and returns the reply.
        '''
        self.cmder = cmd_forwarder

    def deploy(self, deployments):
        ''' Deploy tasks.

            Args:
                deployments: The deployments that contain the tasks. Takes deployment names
                    , default deplyoments and options.

            >>> .deploy(["deplyomentA", "deploymentB", { "default::Task" : "taskC", "valgrind" : True }]

            Returns:
                The list of tasks started with the deployments.
        '''
        msg = ["deploy",[deployments]]
        return self.cmder.process(msg)

    def stop_deployments(self):
        ''' Stop all deployments. Also stops the ruby deployment thread.'''
        msg = ["stop_deployments",[]]
        return self.cmder.process(msg)

    def apply_config(self, task, config):
        ''' Applies a configuration to a task. 

            Args:
                task: The task to apply the configuration to.
                config: A dictionary with the properies of the task as keys.
                    Only properties meant to be set need to be inside the dictionary.
        '''
        msg = ["apply_config",[task,config]]
        return self.cmder.process(msg)

    def configure(self, task):
        ''' Configure a *task* (like task.configure).'''
        msg = ["configure",[task]]
        return self.cmder.process(msg)

    def start(self, task): 
        ''' Start a *task* (like task.start).'''
        msg = ["start",[task]]
        return self.cmder.process(msg)

    def operation(self, task, operation, *args):
        ''' Call an operation of a task.

            Args:
                task: Name of the task which has the operation.
                operation: Name of the operation.
                *args: Argument list.
            
            Returns:
                The return value of the operation.
        '''
        msg = ["operation",[task,operation,args]]
        return self.cmder.process(msg)

    def write(self, task, portname, data):
        ''' Write data to a port.

            Args:
                task: Name of the task that has the port.
                portname: Name of the port.
                data: Data to write to the port. A dictionary that matches the 
                    structure of the porttpye.
        '''
        msg = ["write",[task,portname,data]]
        return self.cmder.process(msg)
    
    def write_vector(self, task, portname, data):
        ''' Writes a vector to a port of type base::VectorXd.'''
        msg = ["write_vector",[task,portname,data]]
        return self.cmder.process(msg)
    
    def read(self, task, portname, new_data=False):
        ''' Read data from a port.
            
            Args:
                task: Name of the task that has the port.
                portname: Name of the port.
                new_data: If True read only new data.

            Returns:
                The data from the port or None if there were no data.
        '''
        msg = ["read",[task,portname,new_data]]
        return self.cmder.process(msg)

    def read_vector(self, task, portname, new_data=False):
        msg = ["read_vector",[task,portname,new_data]]
        return self.cmder.process(msg)

    def connect(self, from_task, from_port, to_task, to_port):
        ''' Connect two ports (not tested). 
            
            like from_task.from_port.connect_to to_task.to_port
        '''
        msg = ["connect",[from_task, from_port, to_task, to_port]]
        return self.cmder.process(msg)

    def stop(self,task):
        '''Stops a task (like task.stop).'''
        msg = ["stop",[task]]
        return self.cmder.process(msg)

    def cleanup(self, task):
        '''Cleans up a task (like task.cleanup).'''
        msg = ["cleanup",[task]]
        return self.cmder.process(msg)


class Forwarder:
    ''' Forward the command message from the class OrocosRb to another entity that
        executes the commands.
    '''

    def __init__(self, reader, writer=None):
        ''' Initialization.

            Args:
                reader: The replies are expected on that line.
                writer: The commands are wirten to this stream.
        '''
        self.reader = reader
        if writer:
            self.writer = writer
        else:
            self.writer = reader
        
    def process_incoming(self, timeout_s = None):
        ''' Process incoming message from the reader. Uses msgpack to unpack
            the messages.

            Returns:
                The reply.
        '''
        unpacker = msgpack.Unpacker()
        start = time.clock()
        while True: #not timeout_s or time.clock() - start < timeout_s:
            data = self.reader.read(1)
            if not data:
                print >> stderr, "no data"
                break
            unpacker.feed(data)
            for o in unpacker:
                return o
        return None

    def process(self, msg):
        ''' Send messages and wait for the reply.

            Args:
                msg: The command message to forward.

            Returns:
                The reply or None if an error occured.
        '''
        self.writer.write(msgpack.packb(msg))
        reply = self.process_incoming()

        if not reply:
            raise Exception("Something went wrong (no message or timeout)!")
        elif reply[0] == msg[0]:
            return reply[1]
        elif reply[0][-5:] == "Error":
            err_data = reply[1]
            print "\x1b[31;1mError:%s, %s\x1b[0m"%(err_data[0],err_data[1])
            for l in err_data[2]:
                print l
            print
            return None


class Client(OrocosRb):
    ''' The client to connect to the ruby server to access orocor.rb. '''

    def __init__(self, ruby_cmd="oropy_server"):
        ''' Initializing the client.

            Start the ruby orocos serving side, connect to it and accept commands.
            Commands the class OrocosRb.

            Args:
                ruby_cmd: the command to run the ruby server.

            A ruby script is started in another process. Both process are connected by a
            pipe. The data serialization is done with msgpack.
        '''
        slave = subprocess.Popen(ruby_cmd,stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=None)
        self.cmder = Forwarder(slave.stdout, slave.stdin)
