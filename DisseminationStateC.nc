#include "Dissemination.h"
#include "StorageVolumes.h"

configuration DisseminationStateC{
    provides{
        interface DataInfo;
    }
}
implementation{
    components DisseminationStateP;

   // DissPhaseControl = DisseminationStateP;
    DataInfo=DisseminationStateP;

    components DisseminationControlC;
    DisseminationStateP.DissPhaseControl->DisseminationControlC;
    
    components DissInfoManagerC;
    DisseminationStateP.RemoteWakeup->DissInfoManagerC;
    DisseminationStateP.RemotePriority->DissInfoManagerC;
    DisseminationStateP.DissInfo->DissInfoManagerC;

    components BeaconProcessorC;
    DisseminationStateP.DissLocalWakeup->BeaconProcessorC;

    components new AMSenderC(DISS_ID) as Sender;
    DisseminationStateP.Send->Sender;
    
    components new AMReceiverC(DISS_ID) as Receiver;
    DisseminationStateP.Receive->Receiver;  

    components new TimerMilliC() as ForceStater;
    DisseminationStateP.ForceState->ForceStater;
    DisseminationStateP.NeighborPage->DissInfoManagerC;

    components  CC2420CsmaC;
    DisseminationStateP.CcaControl-> CC2420CsmaC.CcaControl[DISS_ID];

    components LocalTimeMilliC as ltimer;
    DisseminationStateP.localtime-> ltimer;

    components BeaconListenerC;
    DisseminationStateP.BeaconSnoop-> BeaconListenerC;

    components BitVecUtilsC;
    DisseminationStateP.BitVecUtils -> BitVecUtilsC;

    components new BlockStorageC(VOLUME_BLOCKTEST);
    DisseminationStateP.BlockRead->BlockStorageC;
    DisseminationStateP.BlockWrite->BlockStorageC;

    components ListenArbitrationC;
    DisseminationStateP.ListenRemote->ListenArbitrationC ;

    components CC2420PacketC;
    DisseminationStateP.CC2420Packet->CC2420PacketC;
    
    components ActiveMessageC;
    DisseminationStateP.Packet->ActiveMessageC;
    DisseminationStateP.AMPacket->ActiveMessageC;

    components SerialPrintfC;
}