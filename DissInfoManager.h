#ifndef __DISSINFOMANAGER_H__
#define __DISSINFOMANAGER_H__
#include <stdint.h>
#include "Dissemination.h"
 enum{
       INVALID_RVAL=255,
    };

enum {
    DISS_NEIGHBOR_TABLE_SIZE=10,//邻节点表的大小
    DISS_SINK_NODEID=0,
    DISS_LINKQTHR=50,
};

typedef struct{
    uint8_t   level;//深度
    uint8_t   parent;//自身父节点，告诉父节点
    uint32_t  mEtd;//自己的ETD值
    uint32_t  dEtd;//最小延时树上下游叶子能得到的最大的ETD
}dissinfo_t;

typedef struct{
      uint8_t nodeId;
      uint8_t pagenum;
      uint8_t level;
      uint8_t  parent;//该节点是否为自己的关键路径上的子节点
      uint32_t mEtd;//该节点自己的ETD值
      uint32_t dEtd;//下游能得到的最大的ETD；
      uint8_t  linkQuality;//上层记录一个链路质量值
    //  uint32_t lastWakeupTime;//默认是有UINT32_MAX
}diss_neighbor_tab_t;

enum{
    EDD=1000,
    TREL=3,
    TRET=3,

};

#endif