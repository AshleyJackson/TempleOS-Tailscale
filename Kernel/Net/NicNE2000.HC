//NE2000/clone NIC driver - QEMU "pcnet" (ADR-0006 Phase 1 target).
 //Phase 0: register map + interface stubs only; no I/O yet.
 //Polled PIO per ADR-0004 (no DMA, no PCI interrupts) - same idiom as the
 //ATA disk driver. Include via /Kernel/Net/MakeNet, not directly.

//NE2000 page 0 register offsets (NE2000 datasheet; cf Linux ne.c).
#define NE_CLDA	0x00 //Current Location Pointer (low byte; high at +1)
#define NE_PSR	0x02 //Page Select Register (bits 7-4=page, 3=start, 2=stop)
#define NE_ISR	0x03 //Interrupt Status Register
#define NE_PAR	0x04 //Physical Address Registers 0-5 (MAC addr)
#define NE_TSR	0x0a //Transmit Status Register
#define NE_CSR	0x0b //Configuration Register Select
#define NE_BCR	0x0c //Bus Control Register
#define NE_TCR	0x0d //Transmit Command Register
#define NE_RCR	0x0e //Receive Command Register
#define NE_DCR	0x0f //Data Configuration Register

//ISR bits.
#define NE_ISR_RX	0x01 //Receive complete
#define NE_ISR_TX	0x02 //Transmit complete
#define NE_ISR_OVR	0x04 //RBR overrun
#define NE_ISR_RST	0x80 //Reset complete

//TSR bits.
#define NE_TSR_ABR	0x02 //Aborted
#define NE_TSR_ACK	0x10 //Frame ack'd (clear to send next)

//RCR bits.
#define NE_RCR_RA	0x01 //Receive all (promiscuous)
#define NE_RCR_LOOP	0x10 //Loopback

Bool NicNE2000Init(CNetDev *nd)
{//TODO(Phase 1): reset via CSR, read MAC from PAR into nd->mac_addr,
 //set RCR/DCR, start. Returns FALSE until implemented.
  return FALSE;
}

I64 NicNE2000Xmit(CNetDev *nd,U8 *frame,I64 len)
{//TODO(Phase 1): poll TSR.ACK, select page 3 via PSR, write frame at CLDA,
 //issue TCR start. Returns -1 until implemented.
  return -1;
}

I64 NicNE2000RxPoll(CNetDev *nd,U8 *frame,I64 max_len)
{//TODO(Phase 1): poll ISR.RX, read frame from RBR via CLDA page 1.
 //Returns frame len or 0 until implemented.
  return 0;
}
