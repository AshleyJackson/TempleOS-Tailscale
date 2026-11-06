//TempleOS-Tailscale net task (ADR-0006 Phase 0).
 //The single owner of all net state: #include'd once via MakeNet into one
 //context; client tasks include only Net.HH and talk to this task with
 //PostMsg. See /docs/net-config.md for config & key storage.

#include "Net.HH"

CNetGlbls	net;
CTask	*net_task=NULL;

U0 NetTask(U8 *data)
{//Dedicated net task: poll devices, pump messages, yield (ADR-0006).
 //Phase 0 has no devices yet - the loop just yields cleanly. That is the
 //Phase 0 exit test: "empty Net task boots and yields cleanly".
  I64 arg1,arg2,msg_code;
  Fs->win_inhibit=WIG_USER_TASK_DFT;
  while (TRUE) {
    //TODO(Phase 1): for each nd with NETf_UP, fp_rx_poll into a frame buf.
    msg_code=ScanMsg(&arg1,&arg2,~1);
    switch (msg_code) {
      case NET_MSG_XMIT:
        net.xmit_cnt++;
        //TODO(Phase 1): hand the frame to the default nd's fp_xmit.
        break;
      //TODO(Phase 2): NET_MSG_DEV_ADD/DEL, NET_MSG_SET_CFG, GET_STATUS.
    }
    Yield;
  }
}

Bool NetStart()
{//Spawn the net task once (idempotent). Call from a task whose parent chain
 //reaches Adam so all net state lives in one context.
  if (!net_task) {
    net_task=Spawn(&NetTask,NULL,"Net Task");
    return TRUE;
  } else
    return FALSE;
}

U0 NetXmit(U8 *frame,I64 len)
{//Post a frame to the net task (Phase 1: it sends via the default nd).
  PostMsg(net_task,NET_MSG_XMIT,(I64)frame,len);
}
