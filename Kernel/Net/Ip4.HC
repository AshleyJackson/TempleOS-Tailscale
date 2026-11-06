//IPv4 - ADR-0006 Phase 2. Interface stub only; no code yet.
 //Include via /Kernel/Net/MakeNet, not directly.

#define IP_VER_IHL_DFT	0x45 //Version 4, IHL 5 words
#define IP_PROTO_ICMP	1
#define IP_PROTO_UDP	17

Bool Ip4Send(U32 dst_ip,U8 proto,U8 *payload,I64 len)
{//TODO(Phase 2): build header + checksum, resolve MAC via ArpResolve,
 //hand the frame to L2. Returns FALSE until implemented.
  return FALSE;
}
