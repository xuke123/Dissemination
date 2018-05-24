interface DataInfo{
    command void getLocalDatainfo(datainfo_t *pload);
    command void  rcvRemoteDatainfo(uint8_t nodeId,datainfo_t *pload);
}
