//Phase 0 exit test for ADR-0006: "empty Net task boots and yields cleanly".
 //Run from a user terminal:
 //  #include "/Demo/Net/NetSelfTest"
 //(The net task is a child of the including task and dies with it; to make
 //it persist, load /Kernel/Net/MakeNet into Adam at boot instead.)

#include "/Kernel/Net/MakeNet"

U0 NetSelfTest()
{
  I64 i,old_cnt;
  U8 frame[ETH_FRAME_MIN];
  if (!net_task) {
    if (!NetStart()) {
      "FAIL: Spawn failed\n";
      return;
    }
  }
  Sleep(500); //Let the net task run a few poll/yield iterations.
  if (!TaskValidate(net_task)) {
    "FAIL: net task died\n";
    return;
  }
  old_cnt=net.xmit_cnt;
  for (i=0;i<ETH_FRAME_MIN;i++)
    frame[i]=i;
  NetXmit(frame,ETH_FRAME_MIN);
  Sleep(500); //Let the net task process the message.
  if (net.xmit_cnt!=old_cnt+1) {
    "FAIL: xmit_cnt did not increment\n";
    return;
  }
  "PASS: Net task boots, yields and processes messages\n";
}

NetSelfTest;
