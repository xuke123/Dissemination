#COMPONENT=DisseminationControlC
COMPONENT=DisseminationStateC

PFLAGS += -I/opt/tinyos-2.1.2/wustl/upma/lib/macs/RbMac
#/opt/tinyos-2.1.2/wustl/upma/lib/macs/RbMac
PFLAGS += -I/opt/tinyos-2.1.2/tos/lib/printf
PFLAGS += -I/opt/tinyos-2.1.2/wustl/upma/apps/NetworkLayer2
PFLAGS += -I/opt/tinyos-2.1.2/wustl/upma/interfaces

PFLAGS += -DLOW_POWER_PROBING
#PFLAGS += -DQS_ACK
PFLAGS += -DRbMac
PFLAGS += -DDEBUG_GCC
UPMA_MAC = RbMac

include $(UPMA_DIR)/Makefile.include
include $(MAKERULES)

#include /opt/tinyos-2.1.2/wustl/upma/apps/NetworkLayer2/Makefile
