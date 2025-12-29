// Runtime Rive Input Patcher - Inject inputs without Rive Editor
// Compile: Add to CMakeLists.txt with rive-cpp dependency

#include <cstdint>
#include <cstring>
#include <vector>
#include <fstream>

// Minimal Rive binary format constants
// .riv files use a custom binary format - we patch the state machine block
namespace RiveFormat {
    constexpr uint8_t HEADER_MAGIC[] = {'R', 'I', 'V', 'E'};
    constexpr uint8_t TYPE_NUMBER_INPUT = 56;  // NumberInput type ID
    constexpr uint8_t TYPE_BOOL_INPUT = 57;    // BoolInput type ID
    constexpr uint8_t TYPE_TRIGGER_INPUT = 58; // TriggerInput type ID
}

// Input type enum matching Dart side
enum InputType {
    INPUT_NUMBER = 0,
    INPUT_BOOL = 1,
    INPUT_TRIGGER = 2
};

// Write a varint to buffer (Rive uses variable-length integers)
size_t writeVarint(std::vector<uint8_t>& buffer, uint64_t value) {
    size_t written = 0;
    while (value > 0x7F) {
        buffer.push_back((value & 0x7F) | 0x80);
        value >>= 7;
        written++;
    }
    buffer.push_back(value & 0x7F);
    return written + 1;
}

// Write a string with length prefix
void writeString(std::vector<uint8_t>& buffer, const char* str) {
    size_t len = strlen(str);
    writeVarint(buffer, len);
    for (size_t i = 0; i < len; i++) {
        buffer.push_back(str[i]);
    }
}

// Create an input definition block
std::vector<uint8_t> createInputBlock(const char* name, InputType type, double minVal, double maxVal, double defaultVal) {
    std::vector<uint8_t> block;

    // Type ID
    uint8_t typeId;
    switch (type) {
        case INPUT_NUMBER: typeId = RiveFormat::TYPE_NUMBER_INPUT; break;
        case INPUT_BOOL: typeId = RiveFormat::TYPE_BOOL_INPUT; break;
        case INPUT_TRIGGER: typeId = RiveFormat::TYPE_TRIGGER_INPUT; break;
        default: typeId = RiveFormat::TYPE_NUMBER_INPUT;
    }
    block.push_back(typeId);

    // Name property (property key 4 = name)
    block.push_back(4);
    writeString(block, name);

    // For number inputs, add min/max/default
    if (type == INPUT_NUMBER) {
        // Default value (property key 140)
        block.push_back(140);
        // Write double as 8 bytes little-endian
        union { double d; uint8_t bytes[8]; } converter;
        converter.d = defaultVal;
        for (int i = 0; i < 8; i++) {
            block.push_back(converter.bytes[i]);
        }
    }

    // End of object marker
    block.push_back(0);

    return block;
}

extern "C" {

// Patch a .riv file to add an input
// Returns: 1 on success, 0 on failure
// Note: This modifies the file in-place
__attribute__((visibility("default")))
int patch_rive_input(
    const char* riv_path,
    const char* input_name,
    int type,
    double min_val,
    double max_val
) {
    // Read original file
    std::ifstream file(riv_path, std::ios::binary | std::ios::ate);
    if (!file.is_open()) return 0;

    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);

    std::vector<uint8_t> buffer(size);
    if (!file.read(reinterpret_cast<char*>(buffer.data()), size)) {
        return 0;
    }
    file.close();

    // Verify RIVE header
    if (size < 4 || memcmp(buffer.data(), RiveFormat::HEADER_MAGIC, 4) != 0) {
        return 0;
    }

    // Create input block
    auto inputBlock = createInputBlock(
        input_name,
        static_cast<InputType>(type),
        min_val,
        max_val,
        min_val  // default = min
    );

    // Find state machine section and inject input
    // For now, append to end of file (simplified approach)
    // A full implementation would parse the TOC and insert at correct offset

    // Write patched file
    std::ofstream outFile(riv_path, std::ios::binary);
    if (!outFile.is_open()) return 0;

    outFile.write(reinterpret_cast<const char*>(buffer.data()), buffer.size());
    outFile.write(reinterpret_cast<const char*>(inputBlock.data()), inputBlock.size());
    outFile.close();

    return 1;
}

// In-memory patch - returns new buffer size
// More useful for Flutter since we don't want to modify asset files
__attribute__((visibility("default")))
int patch_rive_input_memory(
    const uint8_t* input_data,
    int input_size,
    uint8_t* output_data,
    int output_max_size,
    const char* input_name,
    int type,
    double min_val,
    double max_val
) {
    if (input_size < 4) return -1;

    // Verify RIVE header
    if (memcmp(input_data, RiveFormat::HEADER_MAGIC, 4) != 0) {
        return -1;
    }

    // Create input block
    auto inputBlock = createInputBlock(
        input_name,
        static_cast<InputType>(type),
        min_val,
        max_val,
        min_val
    );

    int totalSize = input_size + inputBlock.size();
    if (totalSize > output_max_size) {
        return -1;  // Buffer too small
    }

    // Copy original + append input
    memcpy(output_data, input_data, input_size);
    memcpy(output_data + input_size, inputBlock.data(), inputBlock.size());

    return totalSize;
}

// Initialize Dart API (required for Flutter FFI)
__attribute__((visibility("default")))
void init_dart_api(void* data) {
    // Dart_InitializeApiDL(data);  // Uncomment when linking with dart_api_dl
}

}
