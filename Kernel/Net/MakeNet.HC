//Include driver for the net stack (ADR-0006). Deliberately NOT in
 //Kernel.PRJ: the stack is JIT-loadable only, so iteration doesn't need a
 //kernel rebuild + boot sector re-patch. Load it into Adam at boot with:
 //  #include "/Kernel/Net/MakeNet"

#exe {Cd(__DIR__);};
#include "Net.HH"
#include "NetTask"
#include "NicNE2000"
#include "Arp"
#include "Ip4"
#include "Udp"
#exe {Cd("..");};
