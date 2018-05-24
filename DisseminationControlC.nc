configuration DisseminationControlC{
    provides{
        interface DissPhaseControl;
    }
}
implementation{
    components DisseminationControlP;
    DissPhaseControl=DisseminationControlP;

   components MacC;//直接使用初始化的时间长度
   DisseminationControlP.SplitControl->MacC;

   components MainC;
   DisseminationControlP.Boot -> MainC;
}