//UDP (RFC 768) - ADR-0006 Phase 2. Interface stub only; no code yet.
 //Include via /Kernel/Net/MakeNet, not directly.

#define UDP_PORT_WG	51820 //WireGuard default port

Bool UdpSend(U32 dst_ip,U16 dst_port,U8 *payload,I64 len)
{//TODO(Phase 2): build UDP header + checksum, call Ip4Send.
 //Returns FALSE until implemented.
  return FALSE;
}
