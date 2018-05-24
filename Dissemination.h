#ifndef __DISSEMINATION_H__
#define __DISSEMINATION_H__

#include "DissInfoManager.h"
#include "DisseminationState.h"

enum{
   DISS_ID=12,
   PKT_PAYLOAD_SIZE=20,//单个数据包20个字节
   INVALID_PAGE=255,
   PKTS_PER_PAGE=48,
   PAGES_MAX_NUM=5,
};
//-----------
typedef struct{
    dissinfo_t dissinfo;
    datainfo_t datainfo;
}diss_beacon_t;

typedef struct{
    uint8_t dest;
    uint8_t pageNum;
    uint8_t pktNum;
    uint8_t data[PKT_PAYLOAD_SIZE];
}norm_data_t;

typedef struct{
    uint8_t dest;
    uint8_t pageNum;
    uint8_t pktNum;
    uint8_t data[PKT_PAYLOAD_SIZE];
    uint32_t pauseTime;
}data_with_pausetime_t;
//用来标识数据包类型
enum{
    NORM_DATA,
    PAUSE,
};
//滑动窗口变化
enum{
    OVERHEAR_WINSIZE=3,//侦听窗口的大小
};
//状态超时切换时间
enum{
   RXCONNECTING2STOP=10,
   IDLE2STOP=20,
   TXCONNECTING2STOP=20,
   WAITQACK=10,
   RX2STOP=10,
};
//最大重传次数
enum{
    MAXRETRANS=3,
};
#endif