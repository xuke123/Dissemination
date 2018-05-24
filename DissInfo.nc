interface DissInfo{
      command  void getLocalDissinfo(dissinfo_t * pload);
      command error_t updateRemoteDissinfo(uint8_t nodeId, dissinfo_t * pload);
      command uint8_t isRemoteExist(uint8_t nodeId);//判断分发邻节点表中节点是否存在
}
