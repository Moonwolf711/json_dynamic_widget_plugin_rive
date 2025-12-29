# Rive Type IDs from rive-runtime/dev/defs/animation/*.json
# These are the official coreObjectKey values from Rive runtime source

class TypeID:
    # Core
    ARTBOARD = 1
    NODE = 2
    SHAPE = 3

    # Animation
    ANIMATION = 31
    LINEAR_ANIMATION = 31
    KEYED_OBJECT = 25
    KEYED_PROPERTY = 26
    KEYFRAME = 29
    KEYFRAME_DOUBLE = 30

    # State Machine (corrected from official defs)
    STATE_MACHINE = 53
    STATE_MACHINE_INPUT = 55      # Abstract base class
    STATE_MACHINE_NUMBER = 56     # Number input
    STATE_MACHINE_LAYER = 57      # Layer containing states
    STATE_MACHINE_TRIGGER = 58    # Trigger input
    STATE_MACHINE_BOOL = 59       # Boolean input

    # States (corrected from official defs)
    ANIMATION_STATE = 61
    ANY_STATE = 62
    ENTRY_STATE = 63
    EXIT_STATE = 64
    STATE_TRANSITION = 65

    # Blend States (corrected from official defs)
    BLEND_STATE = 72
    BLEND_STATE_DIRECT = 73
    BLEND_ANIMATION = 74
    BLEND_ANIMATION_1D = 75
    BLEND_ANIMATION_DIRECT = 77
    BLEND_STATE_TRANSITION = 78
    BLEND_STATE_1D = 527          # Note: This one has a high ID

    # Transitions
    TRANSITION_CONDITION = 68
    TRANSITION_TRIGGER_CONDITION = 69
    TRANSITION_NUMBER_CONDITION = 70
    TRANSITION_BOOL_CONDITION = 71

class PropertyKey:
    # Common (from component.json)
    DEPENDENT_IDS = 3
    NAME = 4                  # Generic Component name (NOT for state machine inputs!)
    PARENT_ID = 5
    CHILD_ORDER = 6
    FLAGS = 130

    # StateMachine's own name property key (type 53)
    STATE_MACHINE_NAME = 55   # StateMachine (type 53) name property

    # State Machine Component Name (CRITICAL: Different from generic NAME!)
    # StateMachineComponent and all subclasses (Number, Bool, Trigger) use 138
    SM_COMPONENT_NAME = 138   # StateMachineComponent.namePropertyKey

    # State Machine Layer (type 57 uses this for name)
    SM_LAYER_NAME = 138       # Same as SM_COMPONENT_NAME (inheritance)

    # State Machine
    INPUT_ID = 129            # Links blend state to input
    ANIMATION_ID = 88
    STATE_ID = 131
    EDITING_LAYER_ID = 142

    # Input Values (DIFFERENT for each type!)
    NUMBER_VALUE = 140        # StateMachineNumber value property
    BOOL_VALUE = 141          # StateMachineBool value property
    PLAYBACK_VALUE = 232      # Runtime playback value (editor only)
    PUBLIC = 402              # Whether input is exposed to parent artboards

    # Transition conditions
    INPUT_ID_CONDITION = 130
    OP = 132                  # Comparison operator
    COMPARATOR_VALUE = 133
