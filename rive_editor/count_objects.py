#!/usr/bin/env python3
"""
Count objects in a Rive file to find CockpitSM's object ID.
Object IDs are assigned sequentially starting from 1 for each core object.
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent / 'src'))

from src.binary_io import BinaryReader
from src.type_ids import TypeID

# Property type definitions (from Rive ToC)
# Type 0 = bool, 1 = uint, 2 = float, 3 = string, 4 = color (uint32), 5 = bytes
PROPERTY_TYPES = {}


def read_rive_header(reader: BinaryReader):
    """Read Rive file header and return property ToC"""
    fingerprint = reader.read_bytes(4)
    if fingerprint != b'RIVE':
        raise ValueError(f"Invalid Rive file, got {fingerprint}")

    major = reader.read_varuint()
    minor = reader.read_varuint()
    file_id = reader.read_varuint()
    print(f"Rive v{major}.{minor}, file_id={file_id}")

    # Read property Table of Contents
    # Maps property key -> type (0=bool, 1=uint, 2=float, 3=string, etc)
    property_toc = {}
    while True:
        key = reader.read_varuint()
        if key == 0:
            break
        prop_type = reader.read_varuint()
        property_toc[key] = prop_type

    print(f"Property ToC has {len(property_toc)} entries")
    return property_toc


def get_property_size(reader: BinaryReader, prop_type: int) -> int:
    """Skip over a property value based on its type"""
    if prop_type == 0:  # bool
        reader.read_byte()
    elif prop_type == 1:  # uint (varint)
        reader.read_varuint()
    elif prop_type == 2:  # float
        reader.read_bytes(4)
    elif prop_type == 3:  # string
        length = reader.read_varuint()
        reader.read_bytes(length)
    elif prop_type == 4:  # color (uint32)
        reader.read_bytes(4)
    elif prop_type == 5:  # bytes
        length = reader.read_varuint()
        reader.read_bytes(length)
    else:
        # Unknown type - try varint
        reader.read_varuint()


def count_objects_to_state_machine(filepath: str, target_name: str = 'CockpitSM'):
    """Count all objects until we find the target state machine"""

    with open(filepath, 'rb') as f:
        data = f.read()

    reader = BinaryReader(data)
    property_toc = read_rive_header(reader)

    object_count = 0
    state_machine_id = None
    state_machine_end_pos = None

    while reader.remaining() > 0:
        start_pos = reader.position

        try:
            type_id = reader.read_varuint()
        except EOFError:
            break

        if type_id == 0:
            # End of objects? Or invalid
            continue

        object_count += 1

        # Read all properties for this object
        object_name = None
        while True:
            if reader.remaining() == 0:
                break

            prop_key = reader.read_varuint()
            if prop_key == 0:
                # End of properties for this object
                break

            # Get property type from ToC
            prop_type = property_toc.get(prop_key)

            if prop_type is None:
                print(f"  WARNING: Unknown property key {prop_key} at 0x{reader.position:x}")
                # Try to skip as varint
                try:
                    reader.read_varuint()
                except:
                    break
                continue

            # Check if this is a name property (key 4)
            if prop_key == 4 and prop_type == 3:  # NAME = 4, string type
                length = reader.read_varuint()
                name_bytes = reader.read_bytes(length)
                object_name = name_bytes.decode('utf-8', errors='replace')
            else:
                get_property_size(reader, prop_type)

        end_pos = reader.position

        # Check if this is our target state machine
        if type_id == TypeID.STATE_MACHINE and object_name == target_name:
            state_machine_id = object_count
            state_machine_end_pos = end_pos
            print(f"\nFOUND {target_name}!")
            print(f"  Object ID: {object_count}")
            print(f"  Position: 0x{start_pos:x} - 0x{end_pos:x}")

            # Don't break - we want to see what comes after
            # Continue for a few more objects to see the structure
            for _ in range(10):
                if reader.remaining() == 0:
                    break
                obj_start = reader.position
                try:
                    next_type = reader.read_varuint()
                    if next_type == 0:
                        continue
                except:
                    break

                next_name = None
                while True:
                    if reader.remaining() == 0:
                        break
                    pk = reader.read_varuint()
                    if pk == 0:
                        break
                    pt = property_toc.get(pk)
                    if pt is None:
                        try:
                            reader.read_varuint()
                        except:
                            break
                        continue
                    if pk == 4 and pt == 3:
                        ln = reader.read_varuint()
                        next_name = reader.read_bytes(ln).decode('utf-8', errors='replace')
                    else:
                        get_property_size(reader, pt)

                print(f"  Next object: type={next_type}, name={next_name}")

            break

        # Progress indicator every 10000 objects
        if object_count % 10000 == 0:
            print(f"  Processed {object_count} objects...")

    print(f"\nTotal objects processed: {object_count}")

    if state_machine_id:
        print(f"\n{target_name} is object ID: {state_machine_id}")
        print(f"Insertion point after SM: 0x{state_machine_end_pos:x}")
        return state_machine_id, state_machine_end_pos
    else:
        print(f"\n{target_name} NOT FOUND")
        return None, None


if __name__ == '__main__':
    filepath = "/mnt/c/Users/Owner/OneDrive/Desktop/wooking for love logo pack/WFL_PROJECT/wfl.riv"
    count_objects_to_state_machine(filepath)
