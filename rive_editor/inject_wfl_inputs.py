#!/usr/bin/env python3
"""
Inject missing state machine inputs into wfl.riv CockpitSM

The wfl.riv file has a CockpitSM state machine but NO inputs defined.
This script injects the required inputs:
- mouthState (Number, 0-8 for lip shapes)
- headTurn (Number, -45 to 45 degrees)
- eyeState (Number, 0-4 for eye positions)
- roastTone (Number, 0-3 for expression intensity)
- isTalking (Bool, triggers animation loops)
"""

import sys
import os
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent / 'src'))

from src.binary_io import BinaryReader, BinaryWriter
from src.state_machine import StateMachineInput, InputType
from src.type_ids import TypeID, PropertyKey


class StateMachineWriter:
    """Creates binary representations of state machine inputs"""

    @staticmethod
    def write_number_input(name: str, default_value: float = 0.0, parent_id: int = None) -> bytes:
        """Write a StateMachineNumber input with optional parentId"""
        writer = BinaryWriter()

        # Type ID (varint)
        writer.write_varuint(TypeID.STATE_MACHINE_NUMBER)

        # Parent ID property (links input to state machine)
        if parent_id is not None:
            writer.write_varuint(PropertyKey.PARENT_ID)
            writer.write_varuint(parent_id)

        # Name property - CRITICAL: Use SM_COMPONENT_NAME (138) NOT generic NAME (4)
        writer.write_varuint(PropertyKey.SM_COMPONENT_NAME)
        writer.write_string(name)

        # Value property (default value) - NUMBER uses key 140
        writer.write_varuint(PropertyKey.NUMBER_VALUE)
        writer.write_float(default_value)

        # End of properties
        writer.write_varuint(0)

        return writer.get_bytes()

    @staticmethod
    def write_bool_input(name: str, default_value: bool = False, parent_id: int = None) -> bytes:
        """Write a StateMachineBool input with optional parentId"""
        writer = BinaryWriter()

        # Type ID (varint)
        writer.write_varuint(TypeID.STATE_MACHINE_BOOL)

        # Parent ID property (links input to state machine)
        if parent_id is not None:
            writer.write_varuint(PropertyKey.PARENT_ID)
            writer.write_varuint(parent_id)

        # Name property - CRITICAL: Use SM_COMPONENT_NAME (138) NOT generic NAME (4)
        writer.write_varuint(PropertyKey.SM_COMPONENT_NAME)
        writer.write_string(name)

        # Value property (default value) - BOOL uses key 141
        writer.write_varuint(PropertyKey.BOOL_VALUE)
        writer.write_byte(1 if default_value else 0)

        # End of properties
        writer.write_varuint(0)

        return writer.get_bytes()

    @staticmethod
    def write_trigger_input(name: str, parent_id: int = None) -> bytes:
        """Write a StateMachineTrigger input with optional parentId"""
        writer = BinaryWriter()

        # Type ID (varint)
        writer.write_varuint(TypeID.STATE_MACHINE_TRIGGER)

        # Parent ID property (links input to state machine)
        if parent_id is not None:
            writer.write_varuint(PropertyKey.PARENT_ID)
            writer.write_varuint(parent_id)

        # Name property - CRITICAL: Use SM_COMPONENT_NAME (138) NOT generic NAME (4)
        writer.write_varuint(PropertyKey.SM_COMPONENT_NAME)
        writer.write_string(name)

        # End of properties
        writer.write_varuint(0)

        return writer.get_bytes()


def find_cockpit_sm(data: bytes) -> int:
    """Find the offset after CockpitSM state machine properties"""
    reader = BinaryReader(data)

    # Skip RIVE header
    fingerprint = reader.read_bytes(4)
    if fingerprint != b'RIVE':
        raise ValueError("Invalid Rive file")

    # Skip version and file ID
    major = reader.read_varuint()
    minor = reader.read_varuint()
    file_id = reader.read_varuint()
    print(f"Rive file v{major}.{minor}, file_id={file_id}")

    # Skip property ToC
    while True:
        key = reader.read_varuint()
        if key == 0:
            break

    # Read type bits (4 bytes at a time for each 16 properties)
    # This is simplified - proper implementation needs to count keys

    # Search for "CockpitSM" string in the data
    cockpit_sm = b'CockpitSM'
    idx = data.find(cockpit_sm)

    if idx == -1:
        raise ValueError("CockpitSM not found in file")

    print(f"Found 'CockpitSM' at offset 0x{idx:x}")

    # The StateMachine object starts a few bytes before the name
    # Format: [Type ID=53][Property Key=4 (name)][String length][CockpitSM][null]

    # Work backwards to find the start
    search_start = max(0, idx - 20)

    for offset in range(idx - 1, search_start, -1):
        # Check if this byte is type ID 53 (StateMachine)
        if data[offset] == TypeID.STATE_MACHINE:
            # Verify next byte is property key 55 (StateMachine's name property)
            if offset + 1 < len(data) and data[offset + 1] == PropertyKey.STATE_MACHINE_NAME:
                print(f"StateMachine starts at 0x{offset:x}")

                # Now find end of properties (terminator 0)
                pos = idx + len(cockpit_sm)

                # Skip any remaining properties
                reader = BinaryReader(data[pos:])
                while True:
                    if reader.remaining() == 0:
                        break
                    prop_key = reader.read_varuint()
                    if prop_key == 0:
                        # Found terminator
                        insertion_point = pos + reader.position
                        print(f"Insertion point at 0x{insertion_point:x}")
                        return insertion_point

                    # Skip property value based on type
                    # This is simplified - real implementation needs ToC
                    print(f"  Skipping property {prop_key}")

                    # Try to determine value type and skip it
                    next_byte = reader.read_byte()
                    if next_byte < 128:
                        # Small value, likely a flag
                        continue
                    else:
                        # Might be a string or larger value
                        reader.position -= 1
                        try:
                            val = reader.read_varuint()
                        except:
                            break

    # Fallback: return position right after CockpitSM string + null
    return idx + len(cockpit_sm) + 1


def find_state_machine_id(data: bytes, sm_name: str) -> int:
    """Find the object ID of a state machine by name.

    In Rive files, objects are assigned sequential IDs starting from 1.
    We count StateMachine (53) objects until we find the one with matching name.
    """
    # For now, use a simple heuristic: CockpitSM is typically ID 1 or 2
    # A proper implementation would parse all objects and track IDs

    # Count state machines before CockpitSM
    sm_name_bytes = sm_name.encode('utf-8')
    idx = data.find(sm_name_bytes)

    if idx == -1:
        return 1  # Default to 1

    # Count how many StateMachine (53) type IDs appear before this one
    count = 0
    for i in range(idx):
        if data[i] == TypeID.STATE_MACHINE:
            # Verify it's actually a StateMachine by checking next byte is property key 55
            if i + 1 < len(data) and data[i + 1] == PropertyKey.STATE_MACHINE_NAME:
                count += 1

    # Object IDs start at 1 in Rive
    object_id = count if count > 0 else 1
    print(f"Found {sm_name} as object ID: {object_id}")
    return object_id


def inject_inputs(input_file: str, output_file: str):
    """Inject inputs into wfl.riv"""

    print(f"Reading {input_file}...")
    with open(input_file, 'rb') as f:
        data = bytearray(f.read())

    print(f"Original size: {len(data)} bytes")

    # Find CockpitSM object ID for parentId property
    cockpit_sm_id = find_state_machine_id(bytes(data), 'CockpitSM')

    # Find CockpitSM insertion point
    try:
        insertion_point = find_cockpit_sm(bytes(data))
    except Exception as e:
        print(f"Error finding CockpitSM: {e}")

        # Manual fallback based on binary analysis
        cockpit_sm_offset = data.find(b'CockpitSM')
        if cockpit_sm_offset != -1:
            # Skip past string and null terminator
            insertion_point = cockpit_sm_offset + len(b'CockpitSM') + 1
            print(f"Using fallback insertion point: 0x{insertion_point:x}")
        else:
            raise ValueError("Cannot find CockpitSM in file")

    # Create the inputs to inject
    # NOTE: In Rive format, parent-child relationships are implicit based on object order
    # Objects appearing immediately after a container object are its children
    # We do NOT set parentId as it would require knowing the exact runtime object ID
    # which is assigned based on ALL objects in the file, not just state machines
    inputs_to_add = []

    # Number inputs (no parentId - rely on implicit ordering)
    inputs_to_add.append(('mouthState', StateMachineWriter.write_number_input('mouthState', 0.0)))
    inputs_to_add.append(('headTurn', StateMachineWriter.write_number_input('headTurn', 0.0)))
    inputs_to_add.append(('eyeState', StateMachineWriter.write_number_input('eyeState', 0.0)))
    inputs_to_add.append(('roastTone', StateMachineWriter.write_number_input('roastTone', 0.0)))

    # Bool input
    inputs_to_add.append(('isTalking', StateMachineWriter.write_bool_input('isTalking', False)))

    # Combine all input bytes
    all_inputs = b''
    for name, input_bytes in inputs_to_add:
        print(f"  Adding input '{name}': {len(input_bytes)} bytes")
        print(f"    Hex: {input_bytes.hex()}")
        all_inputs += input_bytes

    print(f"Total input data: {len(all_inputs)} bytes")

    # Insert at the insertion point
    new_data = bytes(data[:insertion_point]) + all_inputs + bytes(data[insertion_point:])

    print(f"New size: {len(new_data)} bytes")
    print(f"Size increase: {len(new_data) - len(data)} bytes")

    # Write output
    with open(output_file, 'wb') as f:
        f.write(new_data)

    print(f"Written to {output_file}")

    # Verify the inputs are in the file
    print("\nVerifying injected inputs...")
    for name, _ in inputs_to_add:
        if name.encode('utf-8') in new_data:
            idx = new_data.find(name.encode('utf-8'))
            print(f"  {name}: found at 0x{idx:x}")
        else:
            print(f"  {name}: NOT FOUND - injection may have failed")


if __name__ == '__main__':
    wfl_path = r"C:\Users\Owner\OneDrive\Desktop\wooking for love logo pack\WFL_PROJECT\wfl.riv"
    output_path = r"C:\Users\Owner\OneDrive\Desktop\wooking for love logo pack\WFL_PROJECT\wfl_with_inputs.riv"

    # Use Linux path format for WSL
    wfl_path_linux = "/mnt/c/Users/Owner/OneDrive/Desktop/wooking for love logo pack/WFL_PROJECT/wfl.riv"
    output_path_linux = "/mnt/c/Users/Owner/OneDrive/Desktop/wooking for love logo pack/WFL_PROJECT/wfl_with_inputs.riv"

    if os.path.exists(wfl_path_linux):
        inject_inputs(wfl_path_linux, output_path_linux)
    elif os.path.exists(wfl_path):
        inject_inputs(wfl_path, output_path)
    else:
        print(f"File not found: {wfl_path}")
        print("Please provide the path to wfl.riv as an argument")
