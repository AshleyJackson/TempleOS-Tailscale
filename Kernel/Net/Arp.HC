//ARP (RFC 826) - ADR-0006 Phase 2. Interface stub only; no code yet.
 //Include via /Kernel/Net/MakeNet, not directly.

#define ARP_HTYPE_ETH	1 //Hardware type: Ethernet
#define ARP_PTYPE_IP4	0x0800 //Protocol type: IPv4
#define ARP_OP_REQUEST	1
#define ARP_OP_REPLY	2

Bool ArpResolve(U32 ip_addr,U8 *_mac)
{//TODO(Phase 2): broadcast a request, cache the reply in an ARP table.
 //Returns FALSE until implemented.
  return FALSE;
}
