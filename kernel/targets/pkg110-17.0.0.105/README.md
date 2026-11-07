# PKG110 17.0.0.105 WLAN baseline

Read-only baseline captured from a OnePlus Ace 5 (`PKG110` / `OP5D2BL1`)
running `PKG110_17.0.0.105(CN01)`, SDK 37 and
`6.1.157-android14-11-o-g7cdd565ce1ed`.

The stock WLAN module is `qca_cld3_kiwi_v2.ko`; its exact vermagic is
`6.1.157-android14-11-o-g5c845492d444 SMP preempt mod_unload modversions aarch64`.

`stock/module-abi.json` contains modinfo, imported symbol CRCs and ELF metadata
for the stock WLAN, mac80211, cfg80211 and CNSS2 modules. The proprietary module
binaries are intentionally not committed. `config.gz`, `modules.dep` and
`modules.load` preserve the kernel configuration and module topology used for
build/audit decisions.

Stock SHA-256 values:

- `qca_cld3_kiwi_v2.ko`: `5a38444ca2bbcaddc2cdcef22e735213077c4c41138a65e6a27d67eb503b5576`
- `mac80211.ko`: `40d2fe2c58a9dc91b2949888aa1b193d2fb584c386700ff94a1d23e26d07107e`
- `cfg80211.ko`: `2c3e9e4d4d5711369738d9d96338cd1ca96b49926e4d3ffbbe0088de2727141d`
- `cnss2.ko`: `df0d3e5fb76f510e739135448376c03deb0338b57bc67328f70f756050d23275`

Do not deploy a rebuilt WLAN module unless its vermagic and imported CRC set
are compatible with this baseline.
