# Rive file parser
from typing import List, Dict, Tuple, Optional
from .binary_io import BinaryReader
from .type_ids import TypeID, PropertyKey
from .state_machine import (
    StateMachine, StateMachineInput, StateMachineLayer,
    BlendState1D, BlendAnimation, AnimationState, StateTransition, InputType
)

FINGERPRINT = b'RIVE'

class RiveHeader:
    def __init__(self):
        self.major_version = 0
        self.minor_version = 0
        self.file_id = 0
        self.property_toc: Dict[int, int] = {}

class RiveObject:
    def __init__(self, type_id: int, offset: int):
        self.type_id = type_id
        self.offset = offset  # Position in file
        self.properties: Dict[int, any] = {}
        self.raw_bytes: bytes = b''

class RiveFile:
    def __init__(self, path: str):
        self.path = path
        self.header = RiveHeader()
        self.objects: List[RiveObject] = []
        self.state_machines: List[StateMachine] = []
        self.artboards: List[RiveObject] = []
        self.animations: List[RiveObject] = []
        self._raw_data: bytes = b''
        
    def parse(self):
        with open(self.path, 'rb') as f:
            self._raw_data = f.read()
        
        reader = BinaryReader(self._raw_data)
        
        # Read fingerprint
        fp = reader.read_bytes(4)
        if fp != FINGERPRINT:
            raise ValueError(f"Invalid Rive file: expected RIVE, got {fp}")
        
        # Read header
        self.header.major_version = reader.read_varuint()
        self.header.minor_version = reader.read_varuint()
        self.header.file_id = reader.read_varuint()
        
        print(f"Rive v{self.header.major_version}.{self.header.minor_version}")
        
        # Read property ToC
        property_keys = []
        while True:
            key = reader.read_varuint()
            if key == 0:
                break
            property_keys.append(key)
        
        # Read property type bits
        current_int = 0
        current_bit = 8
        for key in property_keys:
            if current_bit == 8:
                current_int = reader.read_uint32()
                current_bit = 0
            field_index = (current_int >> current_bit) & 3
            self.header.property_toc[key] = field_index
            current_bit += 2
        
        # Read objects
        while reader.remaining() > 0:
            try:
                obj = self._read_object(reader)
                if obj:
                    self.objects.append(obj)
            except EOFError:
                break
        
        # Build state machines
        self._build_state_machines()
        
        return self
