#!/usr/bin/env python3
"""MT7603E-only H298 net_device ABI reverse engineering experiment V3.

Offsets below were observed in the *original* ZTE MT7603E module's
RtmpOSNetDevAttach and RtmpOSNetDevCreate MIPS disassembly; they are not
a substitute for the full OEM patched include/linux/netdevice.h layout.
Do not use this on other routers or as a generic fix.
"""
from pathlib import Path
import sys

def exactly_once(src, before, after):
    n=src.count(before)
    if n!=1:
        raise SystemExit("Expected once ("+str(n)+"): "+before[:85])
    return src.replace(before,after,1)

def port(path):
    p=Path(path)
    s=p.read_text(encoding="latin-1")
    anchor="void RtmpOSNetDevDetach(PNET_DEV pNetDev)\n{"
    extra="""/* H298 V3: offsets recovered from genuine ZTE MT7603E MIPS binary.
 * CAUTION: this is an experimental staged ABI patch, NOT a complete
 * replacement for ZTE's kernel header or OEM net_device implementation.
 * Native header layout netdev_ops=0xcc, dev_addr=0x160, ethtool_ops=0xd0.
 * OEM binary accesses      netdev_ops=0x134, dev_addr=0x1d0,
 *                          ethtool_ops=0x138 and _tx at 0x220.
 */
#define H298_ZTE_OPS(dev) (*(const struct net_device_ops **)((char *)(dev) + 0x134))
#define H298_ZTE_ETHTOOL(dev) (*(const struct ethtool_ops **)((char *)(dev) + 0x138))
#define H298_ZTE_DEV_ADDR(dev) (*(unsigned char **)((char *)(dev) + 0x1d0))
static void h298_zte_stop_queue(struct net_device *dev)
{
    /* OEM netif_stop_queue's netdev_queue.state is at +0x50.
     * Generic GCC10 kernel header uses +0x08 and unguarded access.
     * The authentic ZTE kernel checks a NULL _tx and warns instead.
     */
    void *tx = *(void **)((char *)dev + 0x220);
    if (!tx) {
        printk(KERN_WARNING "H298 V3: netdev _tx missing, skip queue stop\\n");
        return;
    }
    set_bit(0, (unsigned long *)((char *)tx + 0x50));
}

"""
    s=exactly_once(s,anchor,extra+anchor)
    expected=4
    actual=s.count("pNetDev->netdev_ops")
    if actual!=expected:
        raise SystemExit("Netdev ops references unexpected: %s != %s"%(actual,expected))
    s=s.replace("pNetDev->netdev_ops","H298_ZTE_OPS(pNetDev)")
    s=exactly_once(s,"pNetDev->ethtool_ops = &RALINK_Ethtool_Ops;",
                      "H298_ZTE_ETHTOOL(pNetDev) = &RALINK_Ethtool_Ops;")
    s=exactly_once(s,"NdisMoveMemory(pNetDev->dev_addr, &pDevOpHook->devAddr[0],",
                      "NdisMoveMemory(H298_ZTE_DEV_ADDR(pNetDev), &pDevOpHook->devAddr[0],")
    s=exactly_once(s,"netif_stop_queue(pNetDev);","h298_zte_stop_queue(pNetDev);")
    p.write_text(s,encoding="latin-1")
    print("Patched H298 netdev_ops(0x134), ethtool(0x138), dev_addr(0x1d0), _tx(0x220), state(+0x50):",p)

if __name__=="__main__":
    if len(sys.argv)!=2:
        raise SystemExit("usage: patch_netdev_abi_v3.py <path/to/MT7603E/os/linux/rt_linux.c>")
    port(sys.argv[1])
