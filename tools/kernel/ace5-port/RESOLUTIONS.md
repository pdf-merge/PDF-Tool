# Resolutions — 6 file conflict + 6.6-only API cleanup

Ngày 2026-10-27. Đây là bản resolved của 6 file conflict trong `conflicted/`,
cộng với các chỗ merge "sạch" nhưng vẫn dùng API 6.6 không có trên Ace 5 6.1.
Tất cả là **textual**, chưa build.

## 1. Sáu file conflict

| File | Hunk | Cách resolve |
| --- | ---: | --- |
| `target_if_vdev_mgr_rx_ops.c` | 2 | Thêm include `target_if_psoc_timer_tx_ops.h` + forward decl; thêm block PAS response routing, đặt trong `#ifdef DRIVER_PASSTHRU_MODE`, khai báo `vdev`/`mode` cũng trong ifdef. Bỏ `target_if_release_vdev_cmd_rt_lock()` vì 6.1 không có runtime-PM lock cho vdev (hàm này chỉ có từ 6.6); giữ `target_if_wake_lock_timeout_release(START_WAKELOCK)`. |
| `wma_dev_if.c` | 2 | Bỏ hẳn `wma_set_and_update_mac_id()` (6.6-only: 6.1 không có `wlan_mlme_set_vdev_mac_id()`/`cdp_update_mac_id()`). Giữ nguyên cách gán `iface->mac_id` của 6.1. Hunk peer-delete: giữ block `opairshare_awdl_target_delete_reply()` rồi gọi `wma_find_remove_req_msgtype(wma, vdev_id, WMA_DELETE_STA_REQ)` 3 tham số của 6.1 (bỏ `peer_mac`). |
| `wlan_hdd_tx_rx.c` | 1 | Giữ `sme_create_mon_session()` của 6.1; 6.1 không có `sme_create_pe_session()`. Đây là refactor 6.6, không phải thay đổi AWDL. |
| `wlan_policy_mgr_api.h` | 1 | Giữ prototype `policy_mgr_is_given_freq_5g_low()` của 6.1; thêm block prototype PAS (`policy_mgr_opairshare_*`, `policy_mgr_is_chan_change_allowed_for_passthru`) trong `#ifdef DRIVER_PASSTHRU_MODE`. Bỏ prototype `policy_mgr_is_conc_sap_ready_for_mcc_to_scc_trans` vì 6.1 không dùng. |
| `wlan_policy_mgr_get_set_utils.c` | 1 | Giữ cả hai hàm: `policy_mgr_is_sap_go_allowed_with_ll_sap()` của 6.1 và `policy_mgr_allow_passthru_concurrency()` + fallback `#else` của overlay. Include `wlan_policy_mgr_opairshare_sta_coexist.h` nằm trong block `#ifdef`. |
| `dp_rx_mon_dest_1.0.c` | 8 | 6.1 chỉ có single-MAC monitor: đổi toàn bộ `mon_mac->` thành `mon_pdev->`, bỏ `mon_mac = dp_get_mon_mac(pdev, mac_id)`, giữ các `OPAIRSHARE_AUDIT()`. `pr_err` dùng `mac_id` (tham số có sẵn của `dp_rx_mon_mpdu_pop()`). |

Các file resolved nằm trong `resolved/`, giữ nguyên đường dẫn đích. `conflicted/`
được giữ làm bản gốc để đối chiếu.

## 2. Sửa thêm ngoài 6 conflict

Đây là các chỗ `git merge-file` báo "sạch" nhưng thực tế dùng API 6.6:

| File | Vấn đề | Sửa |
| --- | --- | --- |
| `dp_mon_filter.c` | `struct dp_mon_mac *mon = dp_get_mon_mac(pdev, 0)` — 6.6 multi-MAC monitor; 6.1 không có `dp_mon_mac`/`dp_get_mon_mac` | Dùng `struct dp_mon_pdev *mon = pdev->monitor_pdev;` (6.1 đã có `mon_pdev->mvdev`). Hai chỗ: `dp_mon_ht2_rx_ring_cfg()` và `opairshare_coexist_rx_probe()`. |
| `dp_opairshare_rx_audit.h` | Khai báo `extern opairshare_awdl_target_vdev_match()` nhưng hàm thật nằm trong header WMA chỉ được build khi bật PAS → module link lỗi cả khi feature OFF | Khi `DRIVER_PASSTHRU_MODE` tắt, dùng `static inline` trả `false`; khi bật vẫn dùng extern. |
| `wlan_hdd_tx_rx.c` (resolved) | Include `wlan_hdd_opairshare_pas_pause.h` vô điều kiện | Header chỉ có macro + prototype trong `#ifdef`, an toàn. |

`patches/0001-stage2a-enums-buildchain-6.1.patch` là bản rebase của
`0003-stage2a-qdf-enums-policy-buildchain.patch`:

- `WMI_VDEV_TYPE_WIFI_PASSTHRU = 0x9` trong `fw-api/fw/wmi_unified.h`
- `wlan_op_mode_passthru` trong `cdp_txrx_cmn_struct.h`
- `QDF_PASSTHRU_MODE` + string trong `qdf_types.[ch]`
- `PM_PASSTHRU_MODE`, `PM_PASSTHRU_24_1x1_2x2`, `PM_PASSTHRU_5_1x1_2x2`
  trong `wlan_policy_mgr_public_struct.h`
- `CONFIG_DRIVER_PASSTHRU_MODE` / `CONFIG_WONDER_SUPPORT` trong `Kconfig`,
  `Kbuild`, `config_to_feature.h`
- `wlan_hdd_wondertap.o` chỉ được thêm khi cả hai config bật

Patch đã được `git apply --check` trên đúng commit `453d8875`. Phần
`oplus_local_modules.bzl` của patch gốc **không** được đưa vào: nó sửa target
`wonder` cho canoe/sun, chưa có target tương đương cho kiwi-v2.

## 3. API 6.6 còn thiếu — chỉ chặn build khi bật PAS/Wonder

Các mục dưới đây nằm trong file mới (`wlan_hdd_wondertap.c`, các header WMA)
hoặc trong block `#ifdef DRIVER_PASSTHRU_MODE`, nên **không** chặn build
feature-OFF. Phải xử lý trước khi bật `CONFIG_DRIVER_PASSTHRU_MODE=y`:

| API 6.6 | Dùng ở | Hướng xử lý |
| --- | --- | --- |
| `sme_create_pe_session()` / `sme_delete_pe_session()` | `wlan_hdd_wondertap.c` | 6.1 chỉ có `sme_create_mon_session()`/`sme_delete_mon_session()`. Hoặc backport pe-session API từ 6.6, hoặc dùng monitor session cho wondertap. |
| `wlan_vdev_mgr_set_param_bssid()` | `wlan_hdd_wondertap.c` | 6.1 dùng `wlan_vdev_mgr_set_param()`/`vdev_mgr_set_param`; cần wrapper tương đương. |
| `RSO_PASSTHRU_SET_CHANNEL` | `wlan_hdd_wondertap.c` | Thêm giá trị vào enum roaming state của 6.1 (hoặc bỏ lời gọi nếu chỉ là diagnostic). |
| `WIFI_POWER_EVENT_WAKELOCK_PASSTHRU` | `wlan_hdd_wondertap.c` | Thêm vào enum `wifi_power_event` của 6.1. |
| `CDP_VDEV_SET_PASSTHRU_FREQ` | `wlan_hdd_wondertap.c` | Thêm vào enum `cdp_vdev_param` + xử lý trong DP. |
| `QDF_WONDERTAP_FILTER_TYPE_FRAME` | `wlan_hdd_wondertap.c` | Thêm enum filter của Wonder (patch 0006). |
| `ucfg_dp_passthrough_register_txrx_ops()` | `wlan_hdd_wondertap.c` | API mới của 6.6; cần thêm vào UCFG/DP hoặc đăng ký trực tiếp qua `cdp_*`. |
| `hdd_monitor_ctx` / `WLAN_HDD_GET_MONITOR_CTX_PTR` | `wlan_hdd_opairshare_aux_rx.h` | 6.1 dùng `hdd_ctx->monitor_ctx`/adapter monitor; cần đổi macro. Header này chưa được include ở đâu. |
| `qdf_nbuf_set_mac_header()` | `wlan_dp_txrx.c` | 6.6 QDF wrapper; thay bằng `skb_set_mac_header(nbuf, 0)` (feature-on). |
| `hal_rx_tlv_get_user_rssi()` | `dp_rx.c` | 6.6 HAL helper; cần implement từ `HAL_RX_MSDU_START_RSSI_GET`/`hal_rx_tlv_get_rssi` cho kiwi. |
| `dp_htt_rxdma_ring_wmask_cfg()` | `dp_mon_filter.c` | 6.6 helper; thay bằng gán `rx_msdu_end_wmask`/`rx_mpdu_start_wmask` từ HAL (như `dp_rxdma_ring_wmask_cfg_be()` của 6.1). |
| `target_if_release_vdev_cmd_rt_lock()` | đã bỏ | 6.1 không có vdev runtime-PM lock. |

### 3.1. Thiếu "dây nối" cho feature-ON (không phải API)

`wma_opairshare_pas_mgmt.h` định nghĩa `opairshare_pas_mgmt_xmit/start/pause/
resume/stop` nhưng **không translation unit nào include header này**. Trong
OPAirDrop 6.6, `tools/coex-build-na20.py` chèn
`#include "wma_opairshare_pas_mgmt.h"` vào `wma_data.c`; bản port 6.1 chưa có
bước tương đương. Hệ quả: feature-ON sẽ link thiếu `opairshare_pas_mgmt_*`,
`opairshare_pas_ba_rx` (định nghĩa trong `wma_opairshare_awdl_ba.h`) và
`opairshare_pas_trace_wmi/fw` (định nghĩa trong `wma_opairshare_awdl_trace.h`).

Hướng xử lý: thêm vào `wma_data.c` (hoặc một .c WMA duy nhất) block:

```c
#ifdef DRIVER_PASSTHRU_MODE
#include "wma_opairshare_pas_mgmt.h"
#endif
```

rồi build feature-ON để kiểm tra thứ tự include. Việc này chưa làm vì chưa có
compiler; ghi lại để không quên trước bước 3 của mục 4.

### 3.2. Đã kiểm tra feature-OFF (textual)

Đã quét các file `clean/` + `resolved/`: các tham chiếu tới hàm chỉ tồn tại khi
bật PAS đều nằm trong `#ifdef DRIVER_PASSTHRU_MODE`:

| File | Symbol | Guard |
| --- | --- | --- |
| `wlan_hdd_tx_rx.c` | `opairshare_pas_mgmt_*` | `#if defined(DRIVER_PASSTHRU_MODE)` |
| `target_if_vdev_mgr_tx_ops.c` | `opairshare_passthru_diag_flags` | `#ifdef DRIVER_PASSTHRU_MODE` |
| `target_if_vdev_mgr_rx_ops.c` | `opairshare_pas_rx_vdev_event` | `#ifdef DRIVER_PASSTHRU_MODE` |
| `target_if_p2p.c` | `opairshare_awdl_rx_filter_reply` | `#ifdef DRIVER_PASSTHRU_MODE` |
| `dp_mon_filter.c` | `opairshare_aux_monitor_*`, `opairshare_coexist_rx_probe` | `#ifdef DRIVER_PASSTHRU_MODE` |
| `dp_peer.c` | `opairshare_awdl_target_map/unmap` | `#ifdef DRIVER_PASSTHRU_MODE`; `match` có fallback `false` |
| `dp_rx.c` / `dp_be_rx.c` / `dp_rx_err.c` | `opairshare_pas_rx_diag_take`, `opairshare_pas_raw_admit`, `opairshare_pas_native_rx_*` | `#ifdef DRIVER_PASSTHRU_MODE` |
| `wlan_policy_mgr_pcl.c`, `wlan_hdd_scan.c` | `policy_mgr_opairshare_*` | `#ifdef DRIVER_PASSTHRU_MODE` |
| `wlan_hdd_wondertap.c` | toàn bộ file | chỉ vào `HDD_OBJS` khi `CONFIG_DRIVER_PASSTHRU_MODE=y` **và** `CONFIG_WONDER_SUPPORT=y` |
| `wlan_hdd_opairshare_aux_rx.h` | `hdd_monitor_ctx` | `#if defined(DRIVER_PASSTHRU_MODE) && defined(FEATURE_MONITOR_MODE_SUPPORT)`; header chưa được include |

Riêng `dp_opairshare_rx_audit.h` có fallback `static inline ... { return false; }`
cho `opairshare_awdl_target_vdev_match` khi feature tắt. Đây vẫn là kiểm tra
textual, không thay thế build feature-OFF trong CI.

Các API `policy_mgr_opairshare_*` không thiếu: chúng được định nghĩa trong
`new/.../wlan_policy_mgr_opairshare_sta_coexist.h` (chỉ include khi bật PAS).
`WMI_VDEV_TYPE_WIFI_PASSTHRU`, `QDF_PASSTHRU_MODE`, `PM_PASSTHRU_MODE` do
patch 0001 thêm.

## 4. Thứ tự build đề xuất

1. **Stock WLAN baseline** — workflow `../ci/` chỉ build module gốc, không overlay.
   Xác nhận `qca_cld3_kiwi_v2.ko` + vermagic trước.
2. **Overlay feature OFF** — `apply.sh` (patch 0001 + 42 file), build với
   `CONFIG_DRIVER_PASSTHRU_MODE=n`. Mục tiêu: Wi-Fi thường vẫn chạy, không lỗi
   link do các symbol mới. CI có bước tuỳ chọn
   `ci/sm8650-build-wlan-overlay.sh` để làm việc này sau khi artifact stock đã
   upload.
3. **Feature ON, chưa dùng** — bật `DRIVER_PASSTHRU_MODE=y`, `WONDER_SUPPORT=n`,
   xử lý các API trong bảng trên; build lại.
4. **PAS/NDI session** — bật wondertap, chạy CREATE/START/UP/STOP/DELETE trên máy.
5. **RAW TX / monitor RX / Wonder** — theo thứ tự trong `../REPORT.md`.

## 5. Giới hạn

- Chưa có compiler/Bazel trong workspace này; mọi thay đổi mới được kiểm tra
  bằng `git apply --check`, grep symbol và đối chiếu source 6.1.
- `apply.sh` chỉ là copy file; không tự resolve thêm conflict nào.
- Không flash `Image` baseline: kernel Ace 5 COS 16 build từ source OnePlus
  hiện không boot (WildKernels).
