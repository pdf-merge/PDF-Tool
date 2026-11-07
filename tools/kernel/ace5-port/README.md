# Port WLAN AWDL: OPAirDrop 6.6.118 → OnePlus Ace 5 6.1.141

Đây là **first-pass textual rebase** của lớp driver WLAN trong OPAirDrop (SM8750,
kernel 6.6.118) lên cây WLAN chính thức của Ace 5
(`oneplus/sm8650_b_16.0.0_ace_5`). Mục đích là tạo điểm xuất phát có thể build thử,
không phải một bản chạy được.

## Nguồn

| Thành phần | Commit / nhánh |
| --- | --- |
| OPAirDrop overlay | `Weverses/OPAirDrop` @ `main` (clone 2026-10-27), `kernel/driver/` 44 file |
| Ace 5 WLAN (đích) | `OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8650` @ `453d8875`, nhánh `oneplus/sm8650_b_16.0.0_ace_5` |
| Ace 5 kernel | `OnePlusOSS/android_kernel_oneplus_sm8650` @ `d763ed47`, Makefile 6.1.141 |
| SM8750 6.6 base | `OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8750` @ nhánh `oneplus/sm8750_b_16.0.0_oneplus_13` |

Cây đích dùng cho merge: `ace5-modules/vendor/qcom/opensource/wlan` (sparse clone).

## Kết quả merge

`git merge-file` với base = file stock 6.6, ours = file Ace 5 6.1, theirs = file overlay:

| Loại | Số file |
| --- | ---: |
| File mới hoàn toàn (header + `wlan_hdd_wondertap.c`) | 18 |
| Merge sạch | 18 |
| Merge có conflict | 6 (tổng 15 hunk) |

6 file conflict đã được resolve trong `resolved/`; bản gốc còn marker vẫn giữ
trong `conflicted/` để đối chiếu. Xem `RESOLUTIONS.md` để biết từng hunk, các
chỗ merge "sạch" nhưng dùng API 6.6, và danh sách API còn phải port trước khi
bật PAS. File conflict lớn nhất là `dp_rx_mon_dest_1.0.c` (8 hunk) do 6.6
chuyển từ `mon_pdev` sang `mon_mac` (multi-MAC monitor); trên 6.1 phải giữ
`mon_pdev`.

## Cấu trúc

```
port/
├── new/          # 18 file mới, copy nguyên vào cây nguồn
├── clean/        # 18 file đã merge sạch
├── resolved/     # 6 file conflict đã resolve, sẵn sàng copy
├── conflicted/   # 6 file gốc còn marker <<<<<<<, chỉ để đối chiếu
├── patches/      # 0001-stage2a-enums-buildchain-6.1.patch
├── manifest.tsv  # overlay key -> path đích -> trạng thái
├── CONFLICTS.md  # chi tiết 15 hunk + gợi ý
├── RESOLUTIONS.md# cách resolve từng hunk + API 6.6 còn thiếu
└── apply.sh      # áp patch 0001 + copy new/ + clean/ + resolved/
```

## Cách dùng

```sh
# 1. Backup cây nguồn trước
cp -a /mnt/opairshare-sm8650/opairshare/vendor/qcom/opensource/wlan \
      /mnt/opairshare-sm8650/opairshare/vendor/qcom/opensource/wlan.bak

# 2. Áp patch enums/Kbuild + copy 42 file (new + clean + resolved)
./apply.sh /mnt/opairshare-sm8650/opairshare --force

# 3. Build feature OFF trước (CONFIG_DRIVER_PASSTHRU_MODE=n)
#    Mục tiêu: Wi-Fi thường vẫn chạy, không lỗi link.
```

`apply.sh` kiểm tra `git apply --check` trước khi áp patch; nếu patch đã áp
(`QDF_PASSTHRU_MODE` có trong `qdf_types.h`) thì bỏ qua bước patch và chỉ copy
file. Không có bước resolve tự động nào khác.

## Chưa có trong gói này

Phần này **chưa đủ để bật PAS/Wonder**. Trạng thái các patch tích hợp của OPAirDrop:

| Patch | Nội dung | Trạng thái cho 6.1 |
| --- | --- | --- |
| `0003-stage2a-qdf-enums-policy-buildchain.patch` | `QDF_PASSTHRU_MODE`, `wlan_op_mode_passthru`, `WMI_VDEV_TYPE_WIFI_PASSTHRU`, `PM_PASSTHRU_MODE`, Kconfig/Kbuild | **Đã rebase** thành `patches/0001-stage2a-enums-buildchain-6.1.patch`; `git apply --check` pass trên `453d8875`. Hunk `oplus_local_modules.bzl` bị bỏ vì chỉ có target canoe/sun. |
| `0005-stage2b-pld-cnss2-wonder.patch` | PLD/CNSS2 cho Wonder | Chưa port. Phụ thuộc cây `vendor/oplus/kernel/wifi`, không có trong repo WLAN. |
| `0006-stage3-hdd-ops-lifecycle-ddk.patch` | HDD ops/lifecycle | Chưa port. Hunk `wlan_hdd_main.c` lệch; rebase theo 6.1. |
| `0007-session-dp-and-hardware-guards.patch` | session/DP/hardware guard | Chưa port. Nhiều hunk lệch; ưu tiên sau khi WLAN module build được. |
| `0004-mac80211-rate-control-for-wonder.patch` | rate control cho Wonder | Chưa port. Đường dẫn config `sun_perf.config`; phải tạo biến thể `pineapple`. |

Các API 6.6 còn thiếu (chỉ chặn khi bật `CONFIG_DRIVER_PASSTHRU_MODE=y`) được
liệt kê đầy đủ trong [`RESOLUTIONS.md`](RESOLUTIONS.md) mục 3 — gồm
`sme_create_pe_session`, `wlan_vdev_mgr_set_param_bssid`,
`CDP_VDEV_SET_PASSTHRU_FREQ`, `ucfg_dp_passthrough_register_txrx_ops`,
`hdd_monitor_ctx`, `qdf_nbuf_set_mac_header`, `hal_rx_tlv_get_user_rssi`,
`dp_htt_rxdma_ring_wmask_cfg`.

Ngoài ra cần:
- `wonder/` (18 file) và `provider/` (4 file) từ OPAirDrop, cùng Bazel target/provider.
- Đăng ký `wlan_hdd_wondertap.o` trong `Kbuild` khi `CONFIG_DRIVER_PASSTHRU_MODE=y`
  (patch 0001 đã thêm hook, nhưng file nguồn Wonder chưa có trong gói này).
- Chèn `#include "wma_opairshare_pas_mgmt.h"` vào `wma_data.c` (feature-ON), như
  `tools/coex-build-na20.py` của OPAirDrop làm cho 6.6; nếu không, các hàm
  `opairshare_pas_mgmt_*` / `opairshare_pas_ba_rx` không có translation unit nào
  định nghĩa và module link thiếu symbol. Xem `RESOLUTIONS.md` mục 3.1.
- Chọn đúng target `pineapple_gki_kiwi-v2_modules_dist` (xem `../ci/`).

## Cảnh báo

- Chưa build, chưa load, chưa test trên máy. Merge sạch chỉ có nghĩa là patch văn bản
  áp được, không bảo đảm API 6.6 có mặt trong 6.1.
- Không flash `Image` của artifact baseline; WildKernels đã báo kernel Ace 5 COS 16
  build từ source OnePlus không boot.
- Trước khi port tiếp, phải có `qca_cld3_kiwi_v2.ko` build từ chính cây 6.1 và so
  vermagic/CRC với module stock trên máy.
