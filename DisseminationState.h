#ifndef __DISSEMINATIONSTATE_H__
#define __DISSEMINATIONSTATE_H__

typedef struct{
    uint8_t   pageNum;//
    uint8_t   pktsvec[];//该字段长度取决于pageNum是否有效
}datainfo_t;
#endif