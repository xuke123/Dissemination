interface RemotePriority{
    command uint32_t getHighpriorityNode(uint8_t nodeId);
    command uint8_t isChild(uint8_t nodeId);
}
