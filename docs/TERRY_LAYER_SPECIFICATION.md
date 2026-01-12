# Terry Character Layer Specification

## Overview

This document defines the layer structure, rendering order, and asset specifications for Terry the Australian Alien character in the WFL Viewer application.

## Character Reference

Terry is a bright green alien with:
- Black bandana with white paisley pattern
- Black sunglasses with dark lenses
- Black dreadlocks
- Cream/off-white patterned button-up shirt with gray swirls
- Dark gray pants
- Brown cowboy boots
- Gold rope chain necklace

---

## Layer Hierarchy (Top to Bottom Rendering)

```
Terry_[View]
├── Head (bandana + glasses + dreads)      [renderOrder: 10] FRONT
├── Necklace (gold chain)                  [renderOrder: 9]
├── Right_Arm_Upper                        [renderOrder: 8]
├── Right_Arm_Lower (forearm + hand)       [renderOrder: 7]
├── Left_Arm_Upper                         [renderOrder: 6]
├── Left_Arm_Lower (forearm + hand)        [renderOrder: 5]
├── Torso (shirt)                          [renderOrder: 4]
├── Right_Leg_Upper                        [renderOrder: 3]
├── Right_Leg_Lower (+ boot)               [renderOrder: 2]
├── Left_Leg_Upper                         [renderOrder: 1]
└── Left_Leg_Lower (+ boot)                [renderOrder: 0]  BACK
```

---

## Color Reference

| Part | Hex Code | RGB | Description |
|------|----------|-----|-------------|
| Skin | `#7ED321` | (126, 211, 33) | Bright green alien skin |
| Bandana | `#1A1A1A` | (26, 26, 26) | Black base |
| Bandana Pattern | `#FFFFFF` | (255, 255, 255) | White paisley |
| Sunglasses Frame | `#1A1A1A` | (26, 26, 26) | Black frames |
| Sunglasses Lens | `#2D2D2D` | (45, 45, 45) | Dark gray lenses |
| Dreads | `#1A1A1A` | (26, 26, 26) | Black hair |
| Shirt | `#E8E4D4` | (232, 228, 212) | Cream/off-white |
| Shirt Pattern | `#9E9E9E` | (158, 158, 158) | Gray swirls |
| Shirt Buttons | `#8B6914` | (139, 105, 20) | Brown buttons |
| Pants | `#2D2D2D` | (45, 45, 45) | Dark gray |
| Pants Highlight | `#3D3D3D` | (61, 61, 61) | Lighter gray folds |
| Boots | `#8B6914` | (139, 105, 20) | Brown leather |
| Boots Sole | `#4A3608` | (74, 54, 8) | Dark brown |
| Necklace | `#D4AF37` | (212, 175, 55) | Gold chain |

---

## Layer Specifications

### 1. Head (renderOrder: 10)
**File:** `head.png`
**Included Parts:** Face, Bandana, Sunglasses, Dreads

| Property | Value |
|----------|-------|
| Size | 400x500px (recommended) |
| Anchor Point | Center bottom (neck connection) |
| Overlap | Extend neck 20px into torso area |

**Details:**
- Green alien face with smooth curves
- Black bandana tied at back with white paisley pattern
- Large black sunglasses covering eye area
- Black dreadlocks flowing down sides and back

---

### 2. Necklace (renderOrder: 9)
**File:** `necklace.png`
**Included Parts:** Gold rope chain

| Property | Value |
|----------|-------|
| Size | 200x150px (recommended) |
| Anchor Point | Center top (neck) |
| Overlap | Sits on top of shirt collar |

**Details:**
- Gold rope-style chain
- Drapes over collar area
- Can be toggled visible/hidden

---

### 3. Right Arm Upper (renderOrder: 8)
**File:** `right_arm_upper.png`
**Included Parts:** Right bicep, shirt sleeve

| Property | Value |
|----------|-------|
| Size | 150x200px (recommended) |
| Anchor Point | Top (shoulder joint) |
| Overlap | Extend 15px into torso at shoulder |

**Details:**
- Cream patterned shirt sleeve
- Green skin visible at cuff overlap

---

### 4. Right Arm Lower (renderOrder: 7)
**File:** `right_arm_lower.png`
**Included Parts:** Right forearm, hand, lower sleeve

| Property | Value |
|----------|-------|
| Size | 150x250px (recommended) |
| Anchor Point | Top (elbow joint) |
| Overlap | Extend 15px into upper arm at elbow |

**Details:**
- Shirt sleeve continuing from upper arm
- Green forearm visible below rolled sleeve
- Green hand with fingers

---

### 5. Left Arm Upper (renderOrder: 6)
**File:** `left_arm_upper.png`
**Included Parts:** Left bicep, shirt sleeve

| Property | Value |
|----------|-------|
| Size | 150x200px (recommended) |
| Anchor Point | Top (shoulder joint) |
| Overlap | Extend 15px into torso at shoulder |

**Details:**
- Mirror of right arm upper
- Cream patterned shirt sleeve

---

### 6. Left Arm Lower (renderOrder: 5)
**File:** `left_arm_lower.png`
**Included Parts:** Left forearm, hand, lower sleeve

| Property | Value |
|----------|-------|
| Size | 150x250px (recommended) |
| Anchor Point | Top (elbow joint) |
| Overlap | Extend 15px into upper arm at elbow |

**Details:**
- Mirror of right arm lower
- Green hand visible

---

### 7. Torso (renderOrder: 4)
**File:** `torso.png`
**Included Parts:** Chest, abdomen, shirt, buttons

| Property | Value |
|----------|-------|
| Size | 350x400px (recommended) |
| Anchor Point | Center (spine base) |
| Overlap | Extend neck area 20px up, hip area 20px down |

**Details:**
- Cream button-up shirt with gray swirl pattern
- Brown buttons down center
- Collar at top
- Shirt tucked or untucked at bottom

---

### 8. Right Leg Upper (renderOrder: 3)
**File:** `right_leg_upper.png`
**Included Parts:** Right thigh with pants

| Property | Value |
|----------|-------|
| Size | 150x250px (recommended) |
| Anchor Point | Top (hip joint) |
| Overlap | Extend 15px into torso at hip |

**Details:**
- Dark gray pants
- Subtle fold highlights

---

### 9. Right Leg Lower (renderOrder: 2)
**File:** `right_leg_lower.png`
**Included Parts:** Right shin, calf, boot

| Property | Value |
|----------|-------|
| Size | 150x300px (recommended) |
| Anchor Point | Top (knee joint) |
| Overlap | Extend 15px into upper leg at knee |

**Details:**
- Dark gray pants continuing from upper leg
- Brown cowboy boot with darker sole
- Boot stitching details

---

### 10. Left Leg Upper (renderOrder: 1)
**File:** `left_leg_upper.png`
**Included Parts:** Left thigh with pants

| Property | Value |
|----------|-------|
| Size | 150x250px (recommended) |
| Anchor Point | Top (hip joint) |
| Overlap | Extend 15px into torso at hip |

**Details:**
- Mirror of right leg upper
- Dark gray pants

---

### 11. Left Leg Lower (renderOrder: 0)
**File:** `left_leg_lower.png`
**Included Parts:** Left shin, calf, boot

| Property | Value |
|----------|-------|
| Size | 150x300px (recommended) |
| Anchor Point | Top (knee joint) |
| Overlap | Extend 15px into upper leg at knee |

**Details:**
- Mirror of right leg lower
- Brown cowboy boot

---

## Asset Creation Guidelines

### Step 1: Set Up Document
- Create document at 2048x2048px for full character
- Each layer should be exportable as individual PNG
- Use transparent background

### Step 2: Create Layer Groups
```
Terry_Front/
├── Head_Group/
│   ├── face
│   ├── bandana
│   ├── sunglasses
│   └── dreads
├── Necklace_Group/
│   └── chain
├── Right_Arm_Upper_Group/
│   ├── bicep_skin
│   └── sleeve
... (continue for all layers)
```

### Step 3: Trace Each Part
- Use Pen Tool for clean vector paths
- Match the colors from the color reference table above
- **IMPORTANT:** Extend each part slightly (15-20px) into connecting parts for overlap/masking
- This overlap ensures no gaps appear during animation

### Step 4: Export Layers
Export each layer group as individual PNG to:
```
assets/characters/terry/layers/front/
├── head.png
├── necklace.png
├── right_arm_upper.png
├── right_arm_lower.png
├── left_arm_upper.png
├── left_arm_lower.png
├── torso.png
├── right_leg_upper.png
├── right_leg_lower.png
├── left_leg_upper.png
└── left_leg_lower.png
```

---

## Joint Connection Points

| Joint ID | Name | Position (normalized) | Connects |
|----------|------|----------------------|----------|
| `spine_base` | Spine Base | (0.5, 0.55) | Torso to legs |
| `neck` | Neck | (0.5, 0.25) | Torso to head |
| `left_shoulder` | Left Shoulder | (0.25, 0.30) | Torso to left arm |
| `left_elbow` | Left Elbow | (0.10, 0.35) | Upper to lower arm |
| `right_shoulder` | Right Shoulder | (0.75, 0.30) | Torso to right arm |
| `right_elbow` | Right Elbow | (0.90, 0.35) | Upper to lower arm |
| `left_hip` | Left Hip | (0.40, 0.55) | Torso to left leg |
| `left_knee` | Left Knee | (0.35, 0.75) | Upper to lower leg |
| `right_hip` | Right Hip | (0.60, 0.55) | Torso to right leg |
| `right_knee` | Right Knee | (0.65, 0.75) | Upper to lower leg |

---

## Variant Compatibility Matrix

| Part | Standard | No Necklace | Casual |
|------|----------|-------------|--------|
| Head | YES | YES | YES |
| Necklace | YES | NO | YES |
| Right Arm Upper | YES | YES | YES |
| Right Arm Lower | YES | YES | YES |
| Left Arm Upper | YES | YES | YES |
| Left Arm Lower | YES | YES | YES |
| Torso | YES | YES | YES* |
| Right Leg Upper | YES | YES | YES |
| Right Leg Lower | YES | YES | YES |
| Left Leg Upper | YES | YES | YES |
| Left Leg Lower | YES | YES | YES |

*Casual variant uses alternate torso asset (`torso_casual.png`)

---

## File Naming Convention

```
{character}_{view}_{part}_{variant}.png

Examples:
terry_front_head.png
terry_front_torso.png
terry_front_torso_casual.png
terry_threequarter_head.png
```

---

## Rive Integration Notes

For Rive animation integration:
1. Import all layer PNGs as separate images
2. Set up bones at joint positions defined above
3. Parent each layer to appropriate bone
4. Configure mesh deformation for smooth bending
5. Create state machine with inputs for:
   - `isTalking` (bool)
   - `lipShape` (number 0-8)
   - `focusX` (number -1 to 1)
   - `emotion` (number for reaction states)
