#include "DissInfoManager.h"
#include <string.h>

module DissInfoManagerP
{
    provides{
        interface DissInfo;
     //   interface SplitControl as DissInfoSplitControl;
        interface RemoteWakeup;
        interface RemotePriority;
        interface NeighborPage;//设置邻居节点page的接收情况
    }
    uses {
        interface WakeupTime;
        interface LinkEstimate;
        interface Timer<TMilli> as NeighborWakeupTimer;
        interface DissPhaseControl;   
    }
}

implementation{
    enum{
        S_INIT,
        S_DISS,
        S_STOPPED,
    };
    
    uint8_t state=S_STOPPED;

    dissinfo_t  myDissInfo;
    diss_neighbor_tab_t dissneighborTable[DISS_NEIGHBOR_TABLE_SIZE];

    void initNeighborTable(){
        uint8_t i=0;
        for(i=0;i<DISS_NEIGHBOR_TABLE_SIZE;i++){
            dissneighborTable[i].nodeId=INVALID_RVAL;
        }
    }

    uint8_t findNeighborIdx(uint8_t nodeId){
        uint8_t i=0;
        for(i=0;i< DISS_NEIGHBOR_TABLE_SIZE;i++){
            if(dissneighborTable[i].nodeId==nodeId)
                 return i;
        }
        return INVALID_RVAL;
    }

    uint8_t findEmptyNeighborIdx(){
        uint8_t i=0;
        for(i=0;i< DISS_NEIGHBOR_TABLE_SIZE;i++){
            if(dissneighborTable[i].nodeId==INVALID_RVAL)
                 return i;
        }
        return INVALID_RVAL;
    }
     command error_t NeighborPage.set(uint8_t nodeId,uint8_t pagenum){
          uint8_t nodeIdx=findNeighborIdx(nodeId);
          if(nodeIdx==INVALID_RVAL)
              return FAIL;
           dissneighborTable[nodeIdx].pagenum=pagenum;
           return SUCCESS;
    }
    command uint8_t NeighborPage.get(uint8_t nodeId){
          uint8_t nodeIdx=findNeighborIdx(nodeId);
          if(nodeIdx==INVALID_RVAL)
              return INVALID_RVAL;
          else
             return  dissneighborTable[nodeIdx].pagenum;
    }

    command  void DissInfo.getLocalDissinfo(dissinfo_t * pload){
          memcpy(pload,&myDissInfo,sizeof(myDissInfo));
    }
     command uint8_t DissInfo.isRemoteExist(uint8_t nodeId){
          uint8_t nodeIdx=findNeighborIdx(nodeId);
          if(nodeIdx==INVALID_RVAL)
              return FALSE;
          else
             return  TRUE;
     }

    

    command error_t DissInfo.updateRemoteDissinfo(uint8_t nodeId, dissinfo_t * pload){
          //先查询底层的链路质量更新一下吧
          uint8_t linkQuality;
          uint8_t nodeIdx=0;
          uint8_t midx=0;
          uint8_t minlevel=myDissInfo.level;
          uint8_t i;

          nodeIdx=findNeighborIdx(nodeId);
          if(nodeIdx==INVALID_RVAL){
              nodeIdx=findEmptyNeighborIdx();
              if(nodeIdx==INVALID_RVAL) return FAIL;
          }
          
          dissneighborTable[nodeIdx].level=pload->level;
          dissneighborTable[nodeIdx].parent=pload->parent;
          dissneighborTable[nodeIdx].mEtd=pload->mEtd;
          dissneighborTable[nodeIdx].dEtd=pload->dEtd;
          dissneighborTable[nodeIdx].linkQuality=
                           call LinkEstimate.getInQuality(nodeId);//更新链路质量
          
        for(midx=0;midx<DISS_NEIGHBOR_TABLE_SIZE;midx++){
			if(dissneighborTable[midx].nodeId==INVALID_RVAL|| 
                   dissneighborTable[midx].linkQuality<=DISS_LINKQTHR) continue;
			minlevel=minlevel<dissneighborTable[midx].level?
                               minlevel:dissneighborTable[midx].level;
	   	} 
        myDissInfo.level=minlevel+1;
        if(pload->level==UINT8_MAX||dissneighborTable[nodeIdx].linkQuality<DISS_LINKQTHR) return SUCCESS;
    //上级节点处理--------------------------------------------------------------------------
        if(pload->level==0||myDissInfo.level==pload->level+1){
			
            //刷新当前父节点是否有效
			if(myDissInfo.parent!=INVALID_RVAL){ 
				i=findNeighborIdx(myDissInfo.parent);
				if(i==INVALID_RVAL||dissneighborTable[i].linkQuality<=DISS_LINKQTHR||dissneighborTable[i].level>=myDissInfo.level) 
					myDissInfo.parent=INVALID_RVAL;
			}
            //刷新父节点和ETD
			if(myDissInfo.parent!=INVALID_RVAL){
				if(pload->mEtd!=UINT32_MAX&&dissneighborTable[nodeIdx].linkQuality>DISS_LINKQTHR){
					uint32_t tmp;
					tmp=pload->mEtd +EDD+(100.0/dissneighborTable[nodeIdx].linkQuality-1)*1000 +PKTS_PER_PAGE*TREL+\
					    (100.0/dissneighborTable[nodeIdx].linkQuality-1)*PKTS_PER_PAGE*TRET;
					if(tmp<myDissInfo.mEtd){
                         myDissInfo.mEtd=tmp;myDissInfo.parent=nodeId;
                    };
				}
			}else{
				if(pload->mEtd!=UINT32_MAX&&dissneighborTable[nodeIdx].linkQuality>DISS_LINKQTHR){
					myDissInfo.parent=nodeId;
					myDissInfo.mEtd=pload->mEtd + EDD+(100.0/dissneighborTable[nodeIdx].linkQuality-1)*1000 +PKTS_PER_PAGE*TREL+\
					     (100.0/dissneighborTable[nodeIdx].linkQuality-1)*PKTS_PER_PAGE*TRET;
				}
			}
        //下级节点处理-----------------------------------------------------------------------------------
		}else if(myDissInfo.level==pload->level-1){//下级节点主要更新dEtd;
			//uint8_t i=0;
			uint32_t mdEtd=0;

			for(i=0;i<DISS_NEIGHBOR_TABLE_SIZE;i++){
				if(dissneighborTable[i].nodeId==INVALID_RVAL||dissneighborTable[i].linkQuality<=DISS_LINKQTHR) continue;
				if(dissneighborTable[i].parent==TOS_NODE_ID){
					if(dissneighborTable[i].dEtd!=UINT32_MAX){
						mdEtd=(mdEtd>dissneighborTable[i].dEtd)?mdEtd:dissneighborTable[i].dEtd;
					}
				}
			}
			if(myDissInfo.dEtd==0) myDissInfo.dEtd= myDissInfo.mEtd;
			else myDissInfo.dEtd=mdEtd;
        //同级节点处理---------------------------------------------------------------------------------------
		}else if(myDissInfo.level==pload->level){
		}
       
       //判断是否有下级节点
	     for(i=0;i<DISS_NEIGHBOR_TABLE_SIZE;i++){
				if(dissneighborTable[i].nodeId==INVALID_RVAL||dissneighborTable[i].linkQuality<=DISS_LINKQTHR) continue;
				if(dissneighborTable[i].level>myDissInfo.level)//存在下级节点
					break;
		 }
		if(i==DISS_NEIGHBOR_TABLE_SIZE) myDissInfo.dEtd=myDissInfo.mEtd;//没有下级节点
        //强制刷新的父节点
		if(TOS_NODE_ID==DISS_SINK_NODEID){
			myDissInfo.level=0;
			myDissInfo.mEtd=0;
		}
    }

   /*这个函数怎么写，得好好想想
   */
    event void NeighborWakeupTimer.fired(){
        uint32_t wakeuptime=call WakeupTime.remoteNearestWakeupTime();
        uint8_t nodeId=call WakeupTime.remoteNearestWakeupNode();
        signal RemoteWakeup.wakeup(nodeId,wakeuptime);
    }

    //要不就这样做，每次获得底层节点唤醒
    
    //获得最近唤醒的高优先级节点时间
    //这里怎么处理
    //
    command uint32_t RemotePriority.getHighpriorityNode(uint8_t nodeId){
		uint8_t idx=findNeighborIdx(nodeId);
		uint32_t minTime=UINT32_MAX;//计算一个离节点最近的节点
		//uint32_t upperTime=call localtime.get()+Duration;
        uint8_t neigdEtd,neigpagenum ,myparent,neigischild;
        uint8_t i;

		if(idx==INVALID_RVAL) return UINT32_MAX;
	//	mlevel=dissneighborTable[idx].level;
		neigdEtd=dissneighborTable[idx].dEtd;
		neigpagenum=dissneighborTable[idx].pagenum;
		//  neigmEtd=dissneighborTable[idx].mEtd;
		myparent=myDissInfo.parent;
        if(dissneighborTable[idx].parent==TOS_NODE_ID)
		    neigischild=TRUE;

		for(i=0;i< DISS_NEIGHBOR_TABLE_SIZE;i++){

			if(dissneighborTable[i].nodeId==INVALID_RVAL||dissneighborTable[i].linkQuality<=DISS_LINKQTHR) continue;

			if(dissneighborTable[i].pagenum >=PAGES_MAX_NUM) continue;//完成节点不做任何切换
			if(neigischild){

					if(dissneighborTable[i].dEtd>neigdEtd){
						if(dissneighborTable[i].dEtd-neigdEtd>800&&dissneighborTable[i].pagenum< neigpagenum){
							uint32_t nextWakeDura=call WakeupTime.getRemoteNextWakeupTime(dissneighborTable[i].nodeId);
							minTime=minTime<nextWakeDura?minTime:nextWakeDura; 
						}
					} 

			}else{
				if(neigischild&&dissneighborTable[i].pagenum< neigpagenum){
					uint32_t nextWakeDura=call WakeupTime.getRemoteNextWakeupTime(dissneighborTable[i].nodeId);;
					minTime=minTime<nextWakeDura?minTime:nextWakeDura;  
				}
			}
		}

		if(minTime!=UINT32_MAX){

		}
		return minTime;
    }
    command uint8_t RemotePriority.isChild(uint8_t nodeId){
         uint8_t idx=0;
         idx=findNeighborIdx(nodeId);
         if(idx==INVALID_RVAL) return FALSE;
         else return dissneighborTable[idx].parent==TOS_NODE_ID;
    }
   

    event error_t DissPhaseControl.startInitDone(){
        if(state!=S_STOPPED){
            printf("call DissPhaseControl.startInitDone() but state!=S_STOPPED\r\n");
            return FAIL;
        }
        state=S_INIT;
     
        if(TOS_NODE_ID==DISS_SINK_NODEID){
             myDissInfo.level=0;
             myDissInfo.mEtd=0;  
        }else{
             myDissInfo.level=UINT8_MAX;
             myDissInfo.mEtd=UINT32_MAX; 
        }
        myDissInfo.parent=INVALID_RVAL;
        myDissInfo.dEtd= myDissInfo.mEtd;

        initNeighborTable();
        return SUCCESS;
    }

    event error_t DissPhaseControl.startDissDone(){
        state=S_DISS;
        return SUCCESS;
    }
    event error_t DissPhaseControl.stopDone(){
        state=S_STOPPED;
        return SUCCESS;
    }
    //这个没用
    event void WakeupTime.localWakeup(){
    }
}
