/*
* 邻节点信息
*/
interface NeighborPage{
    command error_t set(uint8_t nodeId,uint8_t pagenum);
    command uint8_t get(uint8_t nodeId);

}