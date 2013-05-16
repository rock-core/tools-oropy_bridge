import msgpack
import time
from subprocess import Popen

class OrocosRb:

    def __init__(self, cmd_forwarder):
        self.cmder = cmd_forwarder

    def deploy(self, deployments, options):
        msg = ["deploy",[args,kwargs]]
        return self.cmder.process(msg)

    def stop_deployments(self):
       msg = ["stop_deployments",[]]
       return self.cmder.process(msg)

    def apply_config(self, task, config):
       msg = ["apply_config",[task,config]]
       return self.cmder.process(msg)

    def configure(self, task):
       msg = ["configure",[task]]
       return self.cmder.process(msg)

    def start(self, task): 
        msg = ["start",[task]]
        return self.cmder.process(msg)

    def operation(self, task, operation, *args):
        msg = ["operation",[task,operation,args]]
        return self.cmder.process(msg)

    def write(self, task, portname, data):
        msg = ["write",[task,portname,data]]
        return self.cmder.process(msg)
    
    def write_vector(self, task, portname, data):
        msg = ["write_vector",[task,portname,data]]
        return self.cmder.process(msg)
    
    def read(self, task, portname, new_data=False):
        msg = ["read",[task,portname,new_data]]
        return self.cmder.process(msg)

    def read_vector(self, task, portname, new_data=False):
        msg = ["read_vector",[task,portname,new_data]]
        return self.cmder.process(msg)

    def connect(self, from_task, from_port, to_task, to_port):
        msg = ["connect",[from_task, from_port, to_task, to_port]]
        return self.cmder.process(msg)

    def stop(self,task):
        msg = ["stop",[task]]
        return self.cmder.process(msg)

    def cleanup(self, task):
        msg = ["cleanup",[task]]
        return self.cmder.process(msg)


class Forwarder:

    def __init__(self, reader, writer=None):
        self.reader = reader
        if writer:
            self.writer = writer
        else:
            self.writer = reader
        
    def process_incoming(self, timeout_s = None):
        unpacker = msgpack.Unpacker()
        start = time.clock()
        while not timeout_s or time.clock() - start < timeout_s:
            data = self.reader.read(1)
            if not data:
                break
            unpacker.feed(data)
            for o in unpacker:
                return o
        return None

    def process(self, msg):
        self.writer.write(msgpack.packb(msg))
        cmd = msg[0]
        
        reply = process_incoming()

        if not reply:
            raise Exception("Something went wrong (no message or timeout)!")
        elif reply[0] == cmd:
            return reply[1]
        elif reply[0][-5:] == "Error":
            print "Error"


class Client(OrocsRb):
    ''' The client to connect to the ruby server to access orocor.rb. '''

    def __init__(self, host="localhost", port=50051, ruby_cmd=None):
        ''' Initializing the client.
            Connects to host and port. If ruby_cmd is given start the
            process itself. 
        '''
        if ruby_cmd:
            Popen(ruby_cmd)
        self.__socket = socket.socket.AF_INET, socket.SOCK_STREAM)
        self.__socket.connect((host,port))
        self.__fwder = Forwarder(self.socket.makefile("rwb"))
        super(self.__fwder)

    def quit():
        self.__socket.close()



        


