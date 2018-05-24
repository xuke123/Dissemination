module DisseminationControlP
{
    provides{
       interface  DissPhaseControl;
    }
    uses {
        interface Boot;
        interface SplitControl; 
    }
}

implementation{
    event void Boot.booted() {
        signal DissPhaseControl.startInitDone();//告知其他组件进入初始化状态
    }
    event void SplitControl.startDone(error_t err) { 
        signal DissPhaseControl.startDissDone();//告知其他组件进入分发状态 
    }
    event void SplitControl.stopDone(error_t error) {
	}
}
