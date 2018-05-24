configuration DissInfoManagerC{
    provides{
        interface DissInfo;
   //     interface SplitControl as DissInfoSplitControl;
        interface RemotePriority;
        interface RemoteWakeup;
        interface NeighborPage;
    }
}
implementation{
    components DissInfoManagerP;
    components WakeupTimeC;
    components NeighborDiscoveryC;

    DissInfo=DissInfoManagerP;
 //   DissInfoSplitControl=DissInfoManagerP;
    RemotePriority=DissInfoManagerP;
    RemoteWakeup=DissInfoManagerP;
    NeighborPage=DissInfoManagerP;

    DissInfoManagerP.WakeupTime->WakeupTimeC;
    DissInfoManagerP.LinkEstimate->NeighborDiscoveryC;

   components new TimerMilliC() as NeighborWakeupTimer;
   DissInfoManagerP.NeighborWakeupTimer->NeighborWakeupTimer;

   components DisseminationControlC;
   DissInfoManagerP.DissPhaseControl->DisseminationControlC;
}