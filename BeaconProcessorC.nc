configuration BeaconProcessorC{
    provides{
        interface DissLocalWakeup;
    }
}
implementation{
    components BeaconProcessorP ;
    components WakeupTimeC;
    components DissInfoManagerC;
    components NetBeaconPiggybackC;
    components DisseminationStateC;

    DissLocalWakeup=BeaconProcessorP;

    BeaconProcessorP.WakeupTime->WakeupTimeC;
    BeaconProcessorP.NetBeaconPiggyback->NetBeaconPiggybackC;
    BeaconProcessorP.TLPPacket->NetBeaconPiggybackC;

    BeaconProcessorP.DissInfo->DissInfoManagerC;
    BeaconProcessorP.DataInfo->DisseminationStateC;

    components ActiveMessageC;
    BeaconProcessorP.AMPacket->ActiveMessageC;

    components DisseminationControlC;
    BeaconProcessorP.DissPhaseControl->DisseminationControlC;

}