
#include "Dissemination.h"
module BeaconProcessorP
{
    provides{
        interface DissLocalWakeup;
    }
    uses {
        interface WakeupTime;
        interface NetBeaconPiggyback;
        interface DissInfo;
        interface DataInfo;
        interface TLPPacket;
    }
    uses {
        interface AMPacket;
    }
    uses{
        interface DissPhaseControl;//分发数据的阶段控制
    }
}

implementation{
    enum{
       S_INIT, //初始化状态，
       S_DISS,//分发状态，
       S_STOPPED,//结束分发状态
    };
    tlp_message_t tlp;	
    uint8_t state=S_INIT;
     event message_t* NetBeaconPiggyback.receive(message_t* msg, void* payload, uint16_t len){
             diss_beacon_t* beaconPayload;
             uint8_t nodeId;
             uint8_t payloadLen;

             beaconPayload = call TLPPacket.detachPayload(payload + ((beacon_t*)payload)->length, &payloadLen, DISS_ID);
            
             nodeId = call AMPacket.source(msg);

             call DissInfo.updateRemoteDissinfo(nodeId, &(beaconPayload->dissinfo));//更新分发树信息

             if(beaconPayload->datainfo.pageNum!=INVALID_PAGE||state==S_INIT)//判断是可以分发数据吗，从邻节点和自身两方面考虑
                 call DataInfo.rcvRemoteDatainfo(nodeId,&(beaconPayload->datainfo));
             return msg;
     }

     event void WakeupTime.localWakeup() {
        diss_beacon_t* payload = (diss_beacon_t*) call TLPPacket.getPayload(&tlp, sizeof(diss_beacon_t));
         call  DissInfo.getLocalDissinfo(&(payload->dissinfo));
         if(state==S_DISS){
            call DataInfo.getLocalDatainfo(&(payload->datainfo));
         }
         //不同时间段Beacon的payload长度不同
         if(state==S_INIT)
             call NetBeaconPiggyback.set(&tlp, sizeof(diss_beacon_t), DISS_ID);
         else
             call NetBeaconPiggyback.set(&tlp, sizeof(diss_beacon_t)+PKTS_PER_PAGE/8, DISS_ID);

         signal DissLocalWakeup.wakeup();
     }
//分发协议的三个状态
    event error_t DissPhaseControl.startInitDone()
    {
        state=S_INIT;
        return SUCCESS;
    }
    event error_t DissPhaseControl.startDissDone()
    {
        state=S_DISS;
        return SUCCESS;
    }
    event error_t DissPhaseControl.stopDone()
    {
        state=S_STOPPED;
        return SUCCESS;
    }
}