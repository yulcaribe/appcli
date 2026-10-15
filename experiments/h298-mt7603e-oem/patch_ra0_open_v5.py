#!/usr/bin/env python3
"""H298 MT7603E V5: OEM TX queue layout + radio open trace markers.

The stock ZTE MainVirtualIF_open MIPS machine code dereferences dev+0x220
and manipulates tx->state at +0x50. The generic BSP inlined +0x08 instead.
The 2.4GHz H298 stock module confirms these offsets. This is deliberately
limited to rt_main_dev.c in the 2.4GHz experimental build.
"""
from pathlib import Path
import sys

def once(text, old, new):
    n = text.count(old)
    if n != 1:
        raise SystemExit("Unexpected upstream source (" + str(n) + "): " + old[:90])
    return text.replace(old, new, 1)

def patch(path):
    p=Path(path)
    s=p.read_text(encoding="latin-1")

    marker="int MainVirtualIF_close(IN struct net_device *net_dev)"
    helpers=r'''/*
 * H298 V5: TX queue offsets observed in ZTE MT7603E factory module.
 * Do not use the generic BSP netif_start/wake/stop_queue inlines here;
 * those assume the mismatched 0x08 state offset.
 */
static void h298_zte_tx_queue_state(struct net_device *dev, int stop)
{
    char *tx = *(char **)((char *)dev + 0x220);
    if (tx == NULL) {
        printk(KERN_ERR "H298V5: queue pointer NULL, wanted stop=%d\n", stop);
        return;
    }
    if (stop)
        set_bit(0, (unsigned long *)(tx + 0x50));
    else
        clear_bit(0, (unsigned long *)(tx + 0x50));
}
'''
    s=once(s,marker,helpers+"\n"+marker)
    s=once(s,"netif_stop_queue(net_dev);","h298_zte_tx_queue_state(net_dev, 1);")
    s=once(s,"netif_start_queue(net_dev);","h298_zte_tx_queue_state(net_dev, 0);")
    s=once(s,"netif_wake_queue(net_dev);","h298_zte_tx_queue_state(net_dev, 0);")
    s=once(s,"int MainVirtualIF_open(struct net_device *net_dev)\n{\n\tVOID *pAd = NULL;",
           'int MainVirtualIF_open(struct net_device *net_dev)\n{\n\tVOID *pAd = NULL;\n\tprintk(KERN_ERR "H298V5: MainVirtualIF_open enter\\n");')
    s=once(s,"if (VIRTUAL_IF_UP(pAd) != 0)","printk(KERN_ERR \"H298V5: Main before VIRTUAL_IF_UP\\n\");\n\tif (VIRTUAL_IF_UP(pAd) != 0)")
    s=once(s,"\tRT_MOD_INC_USE_COUNT();\n\n\th298_zte_tx_queue_state(net_dev, 0);",
       '\tprintk(KERN_ERR "H298V5: Main after VIRTUAL_IF_UP\\n");\n\tRT_MOD_INC_USE_COUNT();\n\n\th298_zte_tx_queue_state(net_dev, 0);')
    s=once(s,"\tnetif_carrier_on(net_dev);\n\th298_zte_tx_queue_state(net_dev, 0);",
       '\tprintk(KERN_ERR "H298V5: after queue start, before carrier\\n");\n\tnetif_carrier_on(net_dev);\n\th298_zte_tx_queue_state(net_dev, 0);\n\tprintk(KERN_ERR "H298V5: Main open completed\\n");')

    # Only modify the one rt28xx_open function, no change to probe/other bands.
    start=s.index("int rt28xx_open(VOID *dev)")
    end=s.index("\nPNET_DEV RtmpPhyNetDevInit", start)
    block=s[start:end]
    before_after=[
        ("\tRTMP_DRIVER_MCU_SLEEP_CLEAR(pAd);",
         '\tprintk(KERN_ERR "H298V5: rt28xx_open adapter=%p\\n", pAd);\n\tRTMP_DRIVER_MCU_SLEEP_CLEAR(pAd);'),
        ("\tRtmpOSIRQRequest(net_dev);",
         '\tprintk(KERN_ERR "H298V5: before IRQ request\\n");\n\tRtmpOSIRQRequest(net_dev);\n\tprintk(KERN_ERR "H298V5: after IRQ request\\n");'),
        ("\tRTMP_DRIVER_IRQ_INIT(pAd);",
         '\tprintk(KERN_ERR "H298V5: before IRQ init\\n");\n\tRTMP_DRIVER_IRQ_INIT(pAd);\n\tprintk(KERN_ERR "H298V5: after IRQ init\\n");'),
        ("\tif (rt28xx_init(pAd, mac, hostname) == FALSE)",
         '\tprintk(KERN_ERR "H298V5: before rt28xx_init\\n");\n\tif (rt28xx_init(pAd, mac, hostname) == FALSE)'),
        ("\n#ifdef MBSS_SUPPORT",
         '\n\tprintk(KERN_ERR "H298V5: after rt28xx_init\\n");\n#ifdef MBSS_SUPPORT'),
        ("\tRT28xx_ApCli_Init(pAd, net_dev);",
         '\tprintk(KERN_ERR "H298V5: before APCLI init\\n");\n\tRT28xx_ApCli_Init(pAd, net_dev);\n\tprintk(KERN_ERR "H298V5: after APCLI init\\n");'),
        ("\tRTMPDrvOpen(pAd);",
         '\tprintk(KERN_ERR "H298V5: before RTMPDrvOpen\\n");\n\tRTMPDrvOpen(pAd);\n\tprintk(KERN_ERR "H298V5: after RTMPDrvOpen\\n");')
    ]
    for original,new in before_after:
        block=once(block,original,new)
    s=s[:start]+block+s[end:]
    p.write_text(s,encoding="latin-1")
    print("V5: patched OEM TX queue +0x50 and open-path trace checkpoints:",p)

if __name__=="__main__":
    if len(sys.argv)!=2:
        raise SystemExit("usage: patch_ra0_open_v5.py path/to/MT7603/os/linux/rt_main_dev.c")
    patch(sys.argv[1])
