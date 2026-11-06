//TempleOS-Tailscale net stack - public types & constants (ADR-0006).
 //Types only: no code, no globals. Client tasks include this header and talk
 //to the net task with PostMsg; all net state lives in exactly one context
 //(the task that #include'd /Kernel/Net/MakeNet) because HolyC glbls are
 //per-task copies. See /docs/net-config.md for config & key storage.

#define NET_DEVS_NUM	4
#define NET_NAME_LEN	16
#define ETH_ADDR_LEN	6
#define ETH_FRAME_MIN	60
#define ETH_FRAME_MAX	1518

//Device types: one driver per class (ADR-0004). NDT_NONE marks an empty slot.
#define NDT_NONE	0
#define NDT_NE2000	1 //QEMU "pcnet" - Phase 1 target

//CNetDev.flags bits.
#define NETf_UP		0
#define NETf_PROMISC	1
#define NETf_LOOPBACK	2

//Message codes: upstream uses MSG_ 0-12 (KernelA.HH); the net stack reserves
 //48-55 so masks can be combined with UI messages in one ScanMsg.
#define NET_MSG_XMIT		48 //arg1=frame ptr, arg2=len
#define NET_MSG_RX		49 //arg1=nd index, arg2=len
#define NET_MSG_DEV_ADD		50 //arg1=CNetDev *nd
#define NET_MSG_DEV_DEL		51 //arg1=CNetDev *nd
#define NET_MSG_SET_CFG		52 //arg1=ip, arg2=netmask (gateway Phase 2)
#define NET_MSG_GET_STATUS	53

public class CNetDev
{
  I64	type;	//NDT_????
  I64	flags;	//NETf_????
  U8	name[NET_NAME_LEN];
  U8	mac_addr[ETH_ADDR_LEN];
  I64	io_base;	//Driver-specific: PIO port or MMIO phys addr
  Bool (*fp_init)(CNetDev *nd);
  I64 (*fp_xmit)(CNetDev *nd,U8 *frame,I64 len);
  I64 (*fp_rx_poll)(CNetDev *nd,U8 *frame,I64 max_len);
};

public class CNetGlbls
{
  CNetDev	nd[NET_DEVS_NUM];
  U32	cfg_ip;
  U32	cfg_netmask;
  U32	cfg_gateway;
  I64	xmit_cnt;
  I64	rx_cnt;
};

public extern CNetGlbls net;
public extern CTask *net_task;
public extern Bool NetStart();
public extern U0 NetXmit(U8 *frame,I64 len);
