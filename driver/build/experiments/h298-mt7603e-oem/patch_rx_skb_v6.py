#!/usr/bin/env python3
"""H298 MT7603E V6: restore OEM RX skb allocator and ZTE skb field offsets.

Real H298 V5 Oops:
  r4k_dma_cache_inv, BadVA=0x20, via dma_map_single
  RTMP_AllocateRxPacketBuffer+0x74/0xf4 -> RTMPInitTxRxRingMemory.
Disassembly (stock vs V5):
  skb->data: +0xb8 vs +0xc8
  skb->tail: +0xc4 vs +0xd4
  stock calls __alloc_skb(length+32, GFP_ATOMIC, 0, -1), not
  vendor skbmgr_alloc_skb4k shim (dev_alloc_skb(4096)).

Only patches RX skb allocation function in MT7603E/os/linux/rt_rbus_pci_util.c.
Does NOT fix all skb/adapter layout incompatibilities; H298 only.
"""
from pathlib import Path
import sys

def apply(path):
    p=Path(path)
    s=p.read_text(encoding="latin-1")
    marker="PNDIS_PACKET RTMP_AllocateRxPacketBuffer("
    stop="\n\n/*\n * invaild or writeback cache"
    if s.count(marker)!=1 or s.count(stop)!=1:
        raise SystemExit("Expected unique RTMP_AllocateRxPacketBuffer region")
    start=s.index(marker)
    end=s.index(stop,start)
    original=s[start:end]
    for expected in ["skbmgr_dev_alloc_skb4k()", "pkt->data", "PCI_MAP_SINGLE_DEV"]:
        if expected not in original:
            raise SystemExit("Expected donor RX allocation marker missing: "+expected)
    replacement=r'''PNDIS_PACKET RTMP_AllocateRxPacketBuffer(
    IN VOID *pReserved,
    IN VOID *pPciDev,
    IN ULONG Length,
    IN BOOLEAN Cached,
    OUT VOID **VirtualAddress,
    OUT PNDIS_PHYSICAL_ADDRESS phy_addr)
{
    struct sk_buff *pkt;
    unsigned char **oem_data;
    unsigned char **oem_tail;
    static int h298_rx_logged;

    /* ZTE original MIPS code calls __alloc_skb(Length + 0x20,
     * GFP_ATOMIC, 0, -1), then advances data and tail by 0x20.
     * Do not use skbmgr_dev_alloc_skb4k() here: the donor macro and
     * compatibility shim were built against non-OEM sk_buff headers.
     */
    pkt = __alloc_skb(Length + 0x20, GFP_ATOMIC, 0, -1);
    if (!pkt) {
        printk(KERN_ERR "H298V6: RX skb alloc failed len=%lu\n", Length);
        *VirtualAddress = NULL;
        *phy_addr = (NDIS_PHYSICAL_ADDRESS)0;
        return NULL;
    }

    /* Verified from factory ZTE MT7603E RTMP_AllocateRxPacketBuffer:
     * skb->data at +0xb8, skb->tail at +0xc4 (32-bit MIPS).
     * The donor's generic BSP wrongly assumes +0xc8/+0xd4.
     */
    oem_data = (unsigned char **)((char *)pkt + 0xb8);
    oem_tail = (unsigned char **)((char *)pkt + 0xc4);
    if (!*oem_data || !*oem_tail) {
        printk(KERN_ERR "H298V6: NULL OEM skb pointers skb=%p data=%p tail=%p\n",
               pkt, *oem_data, *oem_tail);
        dev_kfree_skb_any(pkt);
        *VirtualAddress = NULL;
        *phy_addr = (NDIS_PHYSICAL_ADDRESS)0;
        return NULL;
    }

    *oem_data += 0x20;
    *oem_tail += 0x20;
    *VirtualAddress = (PVOID)*oem_data;

    if (!h298_rx_logged) {
        printk(KERN_ERR "H298V6: RX DMA skb=%p data=%p tail=%p length=%lu\n",
               pkt, *oem_data, *oem_tail, Length);
        h298_rx_logged = 1;
    }
    *phy_addr = PCI_MAP_SINGLE_DEV(pPciDev, *VirtualAddress, Length,
                                    -1, RTMP_PCI_DMA_FROMDEVICE);
    return (PNDIS_PACKET)pkt;
}'''
    s=s[:start]+replacement+s[end:]
    p.write_text(s,encoding="latin-1")
    print("H298 V6 RX allocator restored to OEM __alloc_skb and 0xb8/0xc4 offsets")

if __name__=="__main__":
    if len(sys.argv)!=2:
        raise SystemExit("usage: patch_rx_skb_v6.py <MT7603E/os/linux/rt_rbus_pci_util.c>")
    apply(sys.argv[1])
