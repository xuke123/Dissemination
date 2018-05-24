#include "Dissemination.h"
#include "BitVecUtils.h"

#include <stdint.h>
#include <stdlib.h>
#include "printf.h"

module DisseminationStateP
{
   provides{
        interface DataInfo;
   }

   uses{
       interface DissPhaseControl;
       interface RemoteWakeup;
       interface RemotePriority; 
       interface DissInfo;

       interface DissLocalWakeup;
       interface AMSend as Send;
	   interface Receive as Receive;

       interface Timer<TMilli> as ForceState;//节点状态切换

       interface NeighborPage;//这只邻节点的page
       
       interface CcaControl;//是否使用CCA；

       interface LocalTime<TMilli> as localtime;

       interface AsyncReceive as BeaconSnoop; //关于快速ACk的信息处理

       //读写Flash的操作
       interface BitVecUtils;
       interface BlockRead;
       interface BlockWrite;

       interface ListenRemote; //这个节点主要负责主要的侦听开启的关系功能
       interface CC2420Packet;//发送数据包的功率控制 setPower(messsage* ,1)
       interface Packet;
       interface AMPacket;

   }
}
implementation{
    enum{
        S_STOPPED,
        S_RX_CONNECTING,
        S_RX,
        S_IDLE,
        S_TX_CONNECTING,
        S_TX,
    };
   
    
    uint8_t state=S_STOPPED;

    bool useCca_=FALSE;

    message_t dataMsg;
    //发送状态保存的信息
    struct{
      uint8_t nodeId;
      uint8_t ischild; //保证父节点竞争优先程度
      uint8_t pagenum;//
      uint8_t retrynum;//重传次数
      uint8_t dataSendPos;//数据发送到位置
      uint8_t serviceForRealiable;//当前正在工作在可靠服务的表吗？
      uint8_t reliable2transmission[PKTS_PER_PAGE/8];
      uint8_t unreliable2transmission [PKTS_PER_PAGE/8];
      uint32_t highpriorityWakeuptime;//高优先级节点唤醒时间
    }serviceinfo_tx_state;
 //serviceinfo_tx_state.serviceForRealiablereliable2transmission
    //接收状态节点保存的信息
    struct{
      uint8_t nodeId;
      uint32_t highpriorityWakeuptime;//高优先级节点唤醒时间
    }serviceinfo_rx_state;

    //接收数据缓冲队列
    void writeData();
	enum{
        QSIZE=5,
    };

	norm_data_t rxQueue[QSIZE];
	uint8_t  head, size;
    

   //主动侦听使用的窗口 
    struct{
        uint8_t workPageNum;
        uint8_t pktsToReceive[OVERHEAR_WINSIZE][PKTS_PER_PAGE/8];
    } myDataInfo;
   
   //myDataInfo.workPageNum
   //休眠前的节点动作
   void Go2S_STOP(){
       state=S_STOPPED;
       call ListenRemote.stopListen();//关闭远端侦听的状态接口
       //将接收或者发送状态的信息都清空！
       serviceinfo_tx_state.nodeId=INVALID_RVAL;
       serviceinfo_rx_state.nodeId=INVALID_RVAL;
   }
   //处理发送数据超时
   /*
   * 包含两部分处理：可靠传输向量：这部分需要处理重传；非可靠传输向量：不做任何处理
   */
    void dealDataTimeout(){
    // if(BITVEC_GET(serviceinfo_tx_state.reliable2transmission, serviceinfo_tx_state.dataSendPos)){
      if(serviceinfo_tx_state.serviceForRealiable){//如果当前在传输可靠变量
            if(serviceinfo_tx_state.retrynum<=MAXRETRANS){
                 serviceinfo_tx_state.retrynum++;
                 if(call Send.send(AM_BROADCAST_ADDR,&dataMsg,sizeof(dataMsg))!=SUCCESS){
                   printf("\r\n");  
                 }
            }else{
               Go2S_STOP();
            }
        }
    }
  //状态超时定时器
   event void ForceState.fired(){
       if(state==S_RX_CONNECTING||state==S_RX){
           Go2S_STOP();
       }else if(state==S_IDLE){
           Go2S_STOP();
       }else if(state==S_TX||state==S_TX_CONNECTING){
           dealDataTimeout();
       }else{
           Go2S_STOP();
       }
   }
//本地唤醒后，节点的动作
 event void DissLocalWakeup.wakeup(){
    if(state != S_TX && myDataInfo.workPageNum< PAGES_MAX_NUM){
          state=S_RX_CONNECTING;
    }

    call ForceState.startOneShot(RXCONNECTING2STOP);
 }
//邻节点唤醒动作
 event void RemoteWakeup.wakeup(uint8_t nodeId,uint32_t wakeuptime){
     if(state==S_STOPPED){
         state=S_IDLE;
         call ForceState.startOneShot(IDLE2STOP);
         call ListenRemote.startListen(100);
     }
 }
//这个只是简单计算flash的地址
uint32_t calDataFlashAddr(uint8_t pageNum,uint8_t pktNum){
      return pageNum*PKT_PAYLOAD_SIZE*PKTS_PER_PAGE + \
                                    pktNum*PKT_PAYLOAD_SIZE;
}
//必须仔细处理节点在读flash和写Flash上的问题，因为只要处理不当节点就有也可能不能连续发送数据
//再次尝试读数据norm_data_t *pload
void reReadData(norm_data_t *pload){
    static uint8_t tryNum=0;
    uint32_t addr=calDataFlashAddr(serviceinfo_tx_state.pagenum,serviceinfo_tx_state.dataSendPos);
    if(call BlockRead.read(addr,pload->data,PKT_PAYLOAD_SIZE)!=SUCCESS){
        if(tryNum>3){
            Go2S_STOP();
        }
        reReadData(pload);
    } else{
        tryNum=0;
    }
}
//再次尝试发送数据
void reSendData(){
    static uint8_t tryNum=0;
    if(call Send.send(AM_BROADCAST_ADDR,&dataMsg,sizeof(norm_data_t))!=SUCCESS){
        reSendData();
    }else{
         tryNum=0;
    }
}

void sendNextData(){//传输下一个数据包
        uint16_t tmp;
		norm_data_t *pload=(norm_data_t *)call Packet.getPayload(&dataMsg,sizeof(norm_data_t));

		pload->pageNum=serviceinfo_tx_state.pagenum;
        pload->dest=serviceinfo_tx_state.nodeId;

        if(serviceinfo_tx_state.serviceForRealiable){    
             BITVEC_CLEAR(serviceinfo_tx_state.reliable2transmission, serviceinfo_tx_state.dataSendPos);
             if(call BitVecUtils.indexOf(&tmp, serviceinfo_tx_state.dataSendPos,
                       serviceinfo_tx_state.reliable2transmission, PKTS_PER_PAGE) == SUCCESS ){
                 //计算flash的地址
                  uint32_t addr=calDataFlashAddr(pload->pageNum,tmp);
                  serviceinfo_tx_state.dataSendPos=tmp;
                  pload->pktNum=tmp;
                  if(call BlockRead.read(addr,pload->data,PKT_PAYLOAD_SIZE)!=SUCCESS){
                      reReadData(pload);//重复调用，这里有崩溃的隐患
                  }
             }else{
                serviceinfo_tx_state.serviceForRealiable=FALSE; 
                serviceinfo_tx_state.dataSendPos=0;
                call NeighborPage.set(serviceinfo_tx_state.nodeId,serviceinfo_tx_state.pagenum+1);
             }
        }
        //分开吧，可能非可靠传输还没有呢
        if(!(serviceinfo_tx_state.serviceForRealiable)){
             BITVEC_CLEAR(serviceinfo_tx_state.unreliable2transmission, serviceinfo_tx_state.dataSendPos);
             if(call BitVecUtils.indexOf(&tmp, serviceinfo_tx_state.dataSendPos,
                       serviceinfo_tx_state.unreliable2transmission, PKTS_PER_PAGE) == SUCCESS ){
                 //计算flash的地址
                  uint32_t addr=calDataFlashAddr(pload->pageNum,tmp);
                  if(call BlockRead.read(addr,pload->data,PKT_PAYLOAD_SIZE)!=SUCCESS){
                      reReadData(pload);//重复调用，这里有崩溃的隐患
                  }else{
                      pload->pktNum=tmp;
                      serviceinfo_tx_state.dataSendPos=tmp;
                  }
             }else{
                serviceinfo_tx_state.serviceForRealiable=TRUE; 
                serviceinfo_tx_state.dataSendPos=0;
                Go2S_STOP();//非可靠传输结束，转向休眠
             }  
		}
}

event void BlockRead.readDone(storage_addr_t x,void * buf,
    storage_len_t rlen,error_t result) __attribute__((noinline)){
        if(result==SUCCESS){
            if(call Send.send(AM_BROADCAST_ADDR,&dataMsg,sizeof(norm_data_t))!=SUCCESS){
                 reSendData();
            }
        }else{
           norm_data_t *pload=(norm_data_t *)call Packet.getPayload(&dataMsg,sizeof(norm_data_t));
           reReadData(pload); 
        }
    }
/*
* Send
*/

//  event void Send.sendDone(message_t *msg,error_t error){
//      if(state==S_TX_CONNECTING){
//         call ForceState.startOneShot(TXCONNECTING2STOP);
//      }else if(state==S_TX){
//         if(serviceinfo_tx_state.serviceForRealiable){//可靠传输那一部分
//              call ForceState.startOneShot(WAITQACK);
//         }else{//非可靠传输那一部分
//              sendNextData();
//         }
//      }
//  }
	event void Send.sendDone(message_t* msg, error_t error) {
        if(error!=SUCCESS){
            reSendData();
            return;
        }
        if(state==S_TX_CONNECTING){
            call ForceState.startOneShot(TXCONNECTING2STOP);
        }else if(state==S_TX){
            if(serviceinfo_tx_state.serviceForRealiable){ //可靠传输的等待5ms
               call ForceState.startOneShot(WAITQACK);//等待QACK的时间
            }else{//非可靠传输，直接传输下一个
               sendNextData();
            }
        }
		
	}
//窗口向前滑动一格,Page编号加一
   void slideOverhearWindow(){
       uint8_t rightBound;
       myDataInfo.workPageNum++;

       if(myDataInfo.workPageNum==PAGES_MAX_NUM) {
           printf("\r\n");
           return;
       }

      rightBound=myDataInfo.workPageNum+OVERHEAR_WINSIZE;
      if(rightBound < PAGES_MAX_NUM){
         uint8_t i=0;
         for(i=0;i<PKTS_PER_PAGE/8;i++){
             myDataInfo.pktsToReceive[rightBound % OVERHEAR_WINSIZE][i]=0XFF;//注意这是是循环数组
         }
      }
   }
event void BlockWrite.syncDone(error_t result){}
event void BlockWrite.eraseDone(error_t result){}
void writeData(){
       static uint8_t retryNum=0;
       uint16_t bpkts=rxQueue[head].pktNum;
	   uint8_t  bpagenum=rxQueue[head].pageNum;

       uint32_t addr=calDataFlashAddr(bpagenum,bpkts);
       if(call BlockWrite.write(addr,rxQueue[head].data,PKT_PAYLOAD_SIZE)!=SUCCESS){
             retryNum++;
             if(retryNum<3)
                 writeData();//不成功继续写
             else
                 Go2S_STOP();//这样的话就不进行挣扎了
       }else{
           retryNum=0;
       }
}
event void BlockWrite.writeDone(storage_addr_t x,void* buf, storage_len_t y,
error_t result){
        uint16_t bpkts;
		uint8_t bpagenum;
		uint16_t tmp;
        uint8_t pageIdx=bpagenum % OVERHEAR_WINSIZE;
		if (result != SUCCESS) {
			size=0;
            writeData();
			return;
		}
		bpkts=rxQueue[head].pktNum;
		bpagenum=rxQueue[head].pageNum;

		BITVEC_CLEAR(myDataInfo.pktsToReceive[pageIdx],bpkts);  
		head = (head + 1) % QSIZE;
		size--;
             
		if(call BitVecUtils.indexOf(&tmp,bpkts, myDataInfo.pktsToReceive[pageIdx], PKTS_PER_PAGE) != SUCCESS){  
			if(call BitVecUtils.indexOf(&tmp, 0, myDataInfo.pktsToReceive[pageIdx], PKTS_PER_PAGE) != SUCCESS){//如果整个page收全了
                        uint8_t i=0,j=0;
                        //找到第一个的没有完成的向量
                        for(i=0;i<OVERHEAR_WINSIZE;i++){
                            if(call BitVecUtils.indexOf(&tmp, 0, myDataInfo.pktsToReceive[i], PKTS_PER_PAGE) == SUCCESS){   
                                break;
                            }
                        }
                        //开始滑动窗口
                        for(j=0;j<i;j++){
                          slideOverhearWindow();  
                        }
              }
			call ForceState.stop();
			Go2S_STOP();
		}
		if(size){ 
             if(myDataInfo.workPageNum==PAGES_MAX_NUM) return;
                   writeData();//这个需要连续触发才对
        }
}


/*
*关于Receive 到数据
*/
event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
      uint8_t srcId=call AMPacket.source(msg);
      norm_data_t * normDataPload=(norm_data_t *)payload;

      uint8_t type; 

      if(len==sizeof(norm_data_t)) type=NORM_DATA;
      else type=PAUSE;

      if(state!=S_TX_CONNECTING)
        call ForceState.stop();

      if(type==PAUSE){
          data_with_pausetime_t *pload=(data_with_pausetime_t*)payload;

      }else{
           call NeighborPage.set(srcId,normDataPload->pageNum+1);//该节点page至少应该为+应该是全1的

           if(state==S_RX_CONNECTING){
               if(normDataPload->pageNum>=myDataInfo.workPageNum&&
                       normDataPload->pageNum<myDataInfo.workPageNum+OVERHEAR_WINSIZE){
                  state=S_RX;
                  call ForceState.startOneShot(RX2STOP);
               }else{
                   Go2S_STOP();
               }
           }else if(state==S_RX){
               if(normDataPload->pageNum>=myDataInfo.workPageNum&&
                       normDataPload->pageNum<myDataInfo.workPageNum+OVERHEAR_WINSIZE){
                  call ForceState.startOneShot(RX2STOP);
               }

           }else if(state==S_IDLE){
               if(normDataPload->pageNum>=myDataInfo.workPageNum&&
                       normDataPload->pageNum<myDataInfo.workPageNum+OVERHEAR_WINSIZE){
                  state=S_RX;
                  call ForceState.startOneShot(RX2STOP);
               }else{
                   Go2S_STOP();
               }
           }else if(state==S_TX_CONNECTING){
               if(normDataPload->dest!=serviceinfo_tx_state.nodeId){//如果当前节点不是服务节点
                   if(normDataPload->pageNum>=myDataInfo.workPageNum&&
                       normDataPload->pageNum<myDataInfo.workPageNum+OVERHEAR_WINSIZE){
                     state=S_RX;
                      call ForceState.startOneShot(RX2STOP);
                  }else{
                      Go2S_STOP();
                 }
               }
           }else{
              call ForceState.startOneShot(5);
           }
      }

      if(normDataPload->pageNum!= PAGES_MAX_NUM && 
            (normDataPload->pageNum>=myDataInfo.workPageNum&&normDataPload->pageNum<myDataInfo.workPageNum+OVERHEAR_WINSIZE)){
            if (BITVEC_GET(myDataInfo.pktsToReceive[normDataPload->pageNum], normDataPload->pktNum)&&size<QSIZE){//这里可以排除掉相同数据收到两次，所以是OK的
				memcpy(&rxQueue[head^size], normDataPload, sizeof(norm_data_t));
				if (++size == 1) {
					writeData();
				}
			}
      }

      return msg;
}
/*
* DataInfo
interface DataInfo{
    command void getLocalDatainfo(datainfo_t *pload);
    command void  rcvRemoteDatainfo(uint8_t nodeId,datainfo_t *pload);
}
*/
 command void DataInfo.getLocalDatainfo(datainfo_t *pload){
        uint8_t i=0;
        pload->pageNum=myDataInfo.workPageNum;
        for(i=0;i<PKTS_PER_PAGE/8;i++)
             pload->pktsvec[i]=myDataInfo.pktsToReceive[myDataInfo.workPageNum%OVERHEAR_WINSIZE][i];
 }


 void mergeUnreliable2transmission(uint8_t* pktvec){
    uint8_t* pvec= serviceinfo_tx_state.unreliable2transmission;
    uint8_t i=0;
    for(i=0;i<=PKTS_PER_PAGE/8;i++){
        *pvec|=(*pktvec);
    }
 }
//这个相当于收到邻节点Beacon
 command void DataInfo.rcvRemoteDatainfo(uint8_t nodeId,datainfo_t *pload){
      	uint8_t idx=0;
        uint8_t srcId=nodeId;//call AMPacket.source(msg);

        call NeighborPage.set(srcId,pload->pageNum);

        if(pload->pageNum==PAGES_MAX_NUM) return;//节点现在在工作或者就不需要传输数据给他的话

        if(call DissInfo.isRemoteExist(srcId)==FALSE) return ;//不是我的邻居节点就算了,节点本身不会服务于该节点的

		if(state==S_IDLE){ 
			call ForceState.stop();//应该在这里停止定时器才对         
			if(myDataInfo.workPageNum>pload->pageNum){//这个是可以发的
                norm_data_t *spload;
                uint32_t addr;
                serviceinfo_tx_state.nodeId=srcId;
				state=S_TX_CONNECTING;
				memcpy(serviceinfo_tx_state.reliable2transmission,pload->pktsvec,PKTS_PER_PAGE/8);
                
               serviceinfo_tx_state.pagenum=pload->pageNum;
               serviceinfo_tx_state.retrynum=0;
               if(call BitVecUtils.indexOf((uint16_t*)&(serviceinfo_tx_state.dataSendPos), 0,\
                       serviceinfo_tx_state.unreliable2transmission, PKTS_PER_PAGE) == SUCCESS ){
                 
                }
                serviceinfo_tx_state.serviceForRealiable=TRUE;
                serviceinfo_tx_state.highpriorityWakeuptime=UINT32_MAX;

				//组包发送
                spload=(norm_data_t *)call Packet.getPayload(&dataMsg,sizeof(norm_data_t));

	         	spload->dest=srcId;
                spload->pageNum=serviceinfo_tx_state.pagenum;
                spload->pktNum=serviceinfo_tx_state.dataSendPos;
                
                addr=calDataFlashAddr(spload->pageNum,spload->pktNum);
                if(call BlockRead.read(addr,spload->data,PKT_PAYLOAD_SIZE)!=SUCCESS){
                      reReadData(spload);//重复调用，这里有崩溃的隐患
                }
			}else if(myDataInfo.workPageNum <= pload->pageNum && 
                                pload->pageNum <= myDataInfo.workPageNum + OVERHEAR_WINSIZE){//这个page是可以来听听的
				state=S_RX;//进入侦听模式
				call ForceState.startOneShot(RX2STOP);
			}else{
				Go2S_STOP();
			}

		}else if(state==S_RX_CONNECTING){//节点当前在发Beacon，或者在等待对方回复的QACK---》不发送数据，直接等待结束就好

		}else if(state==S_RX){//这里应该考虑续命
             if(myDataInfo.workPageNum<=pload->pageNum && 
                          pload->pageNum<=myDataInfo.workPageNum + OVERHEAR_WINSIZE){
			  call ForceState.startOneShot(RX2STOP);
             } 
         }else if(state==S_TX){
                      if(pload->pageNum == myDataInfo.workPageNum ){
                           mergeUnreliable2transmission(pload->pktsvec);    
                }
         }
		//return;   
 }
 //这个相当于处理收到快速ACK
 event  async void BeaconSnoop.receive(message_t* msg,void* payload,uint8_t len){
	//	QAck *pload=(QAck*)payload;
		uint8_t dest=*(uint8_t*)payload;
		uint8_t srcId=call AMPacket.source(msg);

		if(state==S_STOPPED) return ;

	//	dbg("change","ack has receive for %u @s %u\r\n",dest,state);
		if(state==S_TX_CONNECTING){
            if(srcId!=serviceinfo_tx_state.nodeId){
                  state=S_RX;      
			      call ForceState.startOneShot(RX2STOP);  
                  return ;
            }
			if(dest==TOS_NODE_ID){
                call ForceState.stop();
				if(serviceinfo_tx_state.serviceForRealiable)
					sendNextData();
			}else{
                 if(call Send.cancel(&dataMsg)==SUCCESS){
                 }
			}
		}
		if(state==S_TX_CONNECTING||state==S_TX){
			if(dest==TOS_NODE_ID){
                if(state==S_TX_CONNECTING)
				    state=S_TX;                 
                    if(BITVEC_GET(serviceinfo_tx_state.reliable2transmission, serviceinfo_tx_state.dataSendPos)
                                     &&srcId==serviceinfo_tx_state.nodeId) {
					call ForceState.stop();
                    sendNextData();
				}
			}else if(state == S_TX){
				if(srcId==serviceinfo_tx_state.nodeId){
					 call ForceState.stop();
					 Go2S_STOP(); 
				}
			}

		}else if(state==S_RX){//节点现在还在侦听状态，这个貌似没啥用
		}
		return;
	}

/*
*DissPhaseControl;
*/
    event error_t DissPhaseControl.startInitDone(){  
        uint8_t i=0,j=0;
        state=S_STOPPED;
        if(TOS_NODE_ID == DISS_SINK_NODEID){
            myDataInfo.workPageNum=PAGES_MAX_NUM;
        }else{
            myDataInfo.workPageNum=0;
        }
       //将窗口内的数据更改一下
       for(i=0;i<OVERHEAR_WINSIZE;i++){
          for(j=0;j<PKTS_PER_PAGE/8;j++){
             myDataInfo.pktsToReceive[i][j]=0XFF;//应该是全1的
          }
       }
        return SUCCESS;
    }

    event error_t DissPhaseControl.startDissDone(){
        return SUCCESS;
    }
    event error_t DissPhaseControl.stopDone(){
        return SUCCESS;
    } 

   event void BlockRead.computeCrcDone(storage_addr_t x,storage_len_t y,uint16_t crc,error_t result){}

   async event bool CcaControl.getCca(message_t * msg, bool defaultCca)
   {return useCca_;}
	async event uint16_t CcaControl.getInitialBackoff(message_t * msg, uint16_t defaultbackoff)
    {return defaultbackoff;}
	async event uint16_t CcaControl.getCongestionBackoff(message_t * msg, uint16_t defaultBackoff)
    {return defaultBackoff;}
}