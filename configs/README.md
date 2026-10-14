# H298A firmware kernel configuration

The original ZTE Linux 2.6.36 kernel configuration was recovered from
`/etc/autokernelconf` inside the router's `ram_flash` backup.

Expected uploaded path:
`configs/h298a-zte-20220613.config`

Expected SHA-256:
`bb15933b81a28d722abb979ce14957069a8bb6a1dfe621bafa9060e23dfcb85d`

Source timestamp: 2022-06-13 23:44:47.
Runtime `/proc/version`: GCC 4.3.4, kernel 2.6.36, compiled 2022-06-13 23:49:50 CST.

Source file uses '@' as a comment prefix; the exported Kconfig-compatible
file replaces leading '@' with '#'. This contains build settings, not
the complete ZTE kernel source or its private header patches.

**Only upload a file exported from your own backup.** A matching Kconfig
does NOT make the candidate module safe to load, and build verification
will continue blocking known ABI mismatches.
