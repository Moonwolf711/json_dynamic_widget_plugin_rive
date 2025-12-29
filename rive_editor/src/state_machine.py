# State Machine models
from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any
from enum import IntEnum

class InputType(IntEnum):
    NUMBER = 56   # StateMachineNumber type ID
    TRIGGER = 58  # StateMachineTrigger type ID
    BOOL = 59     # StateMachineBool type ID

@dataclass
class StateMachineInput:
    id: int
    name: str
    input_type: InputType
    value: Any = None  # Default value

@dataclass
class BlendAnimation:
    animation_id: int
    value: float  # Blend position

@dataclass
class BlendState1D:
    id: int
    name: str
    input_id: int  # Which input drives this blend
    animations: List[BlendAnimation] = field(default_factory=list)

@dataclass  
class AnimationState:
    id: int
    name: str
    animation_id: int

@dataclass
class StateTransition:
    id: int
    from_state_id: int
    to_state_id: int
    conditions: List[Dict] = field(default_factory=list)

@dataclass
class StateMachineLayer:
    id: int
    name: str = ""
    states: List[Any] = field(default_factory=list)
    transitions: List[StateTransition] = field(default_factory=list)
    entry_state_id: int = -1
    any_state_id: int = -1

@dataclass
class StateMachine:
    id: int
    name: str
    inputs: List[StateMachineInput] = field(default_factory=list)
    layers: List[StateMachineLayer] = field(default_factory=list)
    
    def get_input_by_name(self, name: str) -> Optional[StateMachineInput]:
        for inp in self.inputs:
            if inp.name == name:
                return inp
        return None
    
    def get_input_index(self, name: str) -> int:
        for i, inp in enumerate(self.inputs):
            if inp.name == name:
                return i
        return -1
