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

    def __init__(self, cmd_forwarder):
        self.cmder = cmd_forwarder

    def deploy(self, deployments):
        msg = ["deploy",[deployments]]
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

    def __init__(self, ruby_cmd):
        ''' Initializing the client.
            Connects to host and port. If ruby_cmd is given start the
            process itself. 
        '''
        slave = subprocess.Popen(ruby_cmd,stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=None)
        self.cmder = Forwarder(slave.stdout, slave.stdin)
