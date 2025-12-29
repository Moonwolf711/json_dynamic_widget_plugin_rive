# Binary reader for .riv files
import struct
from io import BytesIO

class BinaryReader:
    def __init__(self, data: bytes):
        self.stream = BytesIO(data)
        self.data = data
        
    @property
    def position(self) -> int:
        return self.stream.tell()
    
    @position.setter
    def position(self, pos: int):
        self.stream.seek(pos)
        
    def read_byte(self) -> int:
        b = self.stream.read(1)
        if not b:
            raise EOFError("End of stream")
        return b[0]
    
    def read_bytes(self, count: int) -> bytes:
        return self.stream.read(count)
    
    def read_uint32(self) -> int:
        return struct.unpack('<I', self.stream.read(4))[0]
    
    def read_float(self) -> float:
        return struct.unpack('<f', self.stream.read(4))[0]
    
    def read_varuint(self) -> int:
        """Read variable-length unsigned integer (LEB128)"""
        result = 0
        shift = 0
        while True:
            byte = self.read_byte()
            result |= (byte & 0x7F) << shift
            if (byte & 0x80) == 0:
                break
            shift += 7
        return result
    
    def read_string(self) -> str:
        """Read length-prefixed UTF-8 string"""
        length = self.read_varuint()
        if length == 0:
            return ""
        data = self.read_bytes(length)
        return data.decode('utf-8')
    
    def remaining(self) -> int:
        pos = self.stream.tell()
        self.stream.seek(0, 2)
        end = self.stream.tell()
        self.stream.seek(pos)
        return end - pos


class BinaryWriter:
    def __init__(self):
        self.stream = BytesIO()
        
    def write_byte(self, value: int):
        self.stream.write(bytes([value & 0xFF]))
        
    def write_bytes(self, data: bytes):
        self.stream.write(data)
        
    def write_uint32(self, value: int):
        self.stream.write(struct.pack('<I', value))
        
    def write_float(self, value: float):
        self.stream.write(struct.pack('<f', value))
        
    def write_varuint(self, value: int):
        """Write variable-length unsigned integer (LEB128)"""
        while True:
            byte = value & 0x7F
            value >>= 7
            if value != 0:
                byte |= 0x80
            self.stream.write(bytes([byte]))
            if value == 0:
                break
                
    def write_string(self, value: str):
        """Write length-prefixed UTF-8 string"""
        data = value.encode('utf-8')
        self.write_varuint(len(data))
        self.stream.write(data)
        
    def get_bytes(self) -> bytes:
        return self.stream.getvalue()
