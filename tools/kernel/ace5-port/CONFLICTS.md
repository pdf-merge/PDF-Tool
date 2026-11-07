# Conflicts — first-pass rebase 6.6.118 → Ace 5 6.1.141

> **Trạng thái:** 6 file dưới đây **đã được resolve** trong `resolved/`; tài liệu
> này giữ nguyên 15 hunk gốc để đối chiếu. Xem `RESOLUTIONS.md` để biết cách
> resolve và các API 6.6 còn thiếu.

Sinh tự động bằng `git merge-file` (base = stock 6.6, ours = Ace 5 6.1, theirs = OPAirDrop overlay).
Các file dưới đây còn marker `<<<<<<<`; phải resolve trước khi build.

## `kernel/driver/target_if_vdev_mgr_rx_ops.c` — 2 conflict

- Path: `vendor/qcom/opensource/wlan/qca-wifi-host-cmn/target_if/mlme/vdev_mgr/src/target_if_vdev_mgr_rx_ops.c`
- Gợi ý: 6.1 đã có `START_RESPONSE_BIT`/`RESTART_RESPONSE_BIT` và `wlan_objmgr_get_vdev_by_id_from_psoc()`. Hunk 1 chỉ cần thêm include + forward declaration. Hunk 2: chèn block PAS routing trước `if (vdev_start_resp.resp_type == WMI_HOST_VDEV_RESTART_RESP_EVENT)`, giữ nguyên cách gọi 6.1.

```diff
<<<<<<< ace5-modules/vendor/qcom/opensource/wlan/qca-wifi-host-cmn/target_if/mlme/vdev_mgr/src/target_if_vdev_mgr_rx_ops.c
=======
#include <target_if_psoc_timer_tx_ops.h>
#ifdef DRIVER_PASSTHRU_MODE
void opairshare_pas_rx_vdev_event(struct wlan_objmgr_psoc *psoc, uint8_t id, bool deleted);
#endif
>>>>>>> OPAirDrop/kernel/driver/target_if_vdev_mgr_rx_ops.c
```

```diff
<<<<<<< ace5-modules/vendor/qcom/opensource/wlan/qca-wifi-host-cmn/target_if/mlme/vdev_mgr/src/target_if_vdev_mgr_rx_ops.c
	if (vdev_start_resp.resp_type == WMI_HOST_VDEV_RESTART_RESP_EVENT)
=======
	vdev = wlan_objmgr_get_vdev_by_id_from_psoc(psoc, vdev_id,
						    WLAN_VDEV_TARGET_IF_ID);
	if (!vdev) {
		mlme_err("Null Vdev");
		return -EINVAL;
	}

	mode = wlan_vdev_mlme_get_opmode(vdev);
	wlan_objmgr_vdev_release_ref(vdev, WLAN_VDEV_TARGET_IF_ID);

#ifdef DRIVER_PASSTHRU_MODE
	if (mode == QDF_PASSTHRU_MODE) {
		bool start_pending = qdf_atomic_test_bit(START_RESPONSE_BIT,
						      &vdev_rsp->rsp_status);
		bool restart_pending = qdf_atomic_test_bit(RESTART_RESPONSE_BIT,
						        &vdev_rsp->rsp_status);
		uint32_t raw_type = vdev_start_resp.resp_type;

		/* PAS/NDI firmware classification differs on live channel changes.
		 * Match only a sole pending command; keep real firmware status.
		 */
		if (start_pending != restart_pending &&
		    (raw_type == WMI_HOST_VDEV_START_RESP_EVENT ||
		     raw_type == WMI_HOST_VDEV_RESTART_RESP_EVENT))
			vdev_start_resp.resp_type = restart_pending ?
				WMI_HOST_VDEV_RESTART_RESP_EVENT :
				WMI_HOST_VDEV_START_RESP_EVENT;
		mlme_info("OPAIRSHAREPASRSP: vdev=%u raw=%u routed=%u status=%u start_pending=%u restart_pending=%u",
			  vdev_id, raw_type, vdev_start_resp.resp_type,
			  vdev_start_resp.status, start_pending, restart_pending);
	}
#endif
	if (vdev_start_resp.resp_type == WMI_HOST_VDEV_RESTART_RESP_EVENT) {
>>>>>>> OPAirDrop/kernel/driver/target_if_vdev_mgr_rx_ops.c
```

## `kernel/driver/wma_dev_if.c` — 2 conflict

- Path: `vendor/qcom/opensource/wlan/qcacld-3.0/core/wma/src/wma_dev_if.c`
- Gợi ý: 6.1 dùng `wma_find_remove_req_msgtype(wma, vdev_id, req_type)` (không có tham số `peer_mac`). Giữ call 6.1, chỉ thêm đoạn `opairshare_awdl_target_delete_reply()` phía trước. Hunk `wma_set_and_update_mac_id()` là hàm 6.6 mới; có thể bỏ qua nếu 6.1 chưa có, hoặc backport riêng.

```diff
<<<<<<< ace5-modules/vendor/qcom/opensource/wlan/qcacld-3.0/core/wma/src/wma_dev_if.c
=======
/**
 * wma_set_and_update_mac_id() - set and update mac_id for vdev_id
 * @wma: WMA context
 * @mac_ctx: mac context
 * @vdev_mlme: vdev mlme obj
 * @rsp: vdev start response
 * @dp_soc: data patch soc handle
 * mac_id: mac id
 *
 * Return: None
 */
static void
wma_set_and_update_mac_id(tp_wma_handle wma, struct mac_context *mac_ctx,
			  struct vdev_mlme_obj *vdev_mlme,
			  struct vdev_start_response *rsp,
			  void *dp_soc, uint32_t mac_id)
{
	if (mac_id >= MAX_MAC) {
		wma_err("Invalid mac_id %d", mac_id);
		QDF_ASSERT(0);
		return;
	}

	wlan_mlme_set_vdev_mac_id(wma->pdev, rsp->vdev_id, mac_id);

	if (wlan_vdev_mlme_is_mlo_ap(vdev_mlme->vdev) ||
	    wma->interfaces[rsp->vdev_id].type ==
	    WMI_VDEV_TYPE_MONITOR ||
	    opairshare_pas_ndi_peer(wma->interfaces[rsp->vdev_id].vdev,
			      wma->interfaces[rsp->vdev_id].type))
		cdp_update_mac_id(dp_soc, rsp->vdev_id, mac_id);
	if (opairshare_pas_ndi_peer(wma->interfaces[rsp->vdev_id].vdev,
			      wma->interfaces[rsp->vdev_id].type))
		pr_err("OPAIRSHARENDIMAC: vdev=%u fw_mac=%u host_mac=%u\n",
		       rsp->vdev_id, rsp->mac_id, mac_id);

	if (wma_is_vdev_in_ap_mode(wma, rsp->vdev_id)) {
		wma_dcs_clear_vdev_starting(mac_ctx, rsp->vdev_id);
		wma_dcs_wlan_interference_mitigation_enable(mac_ctx,
							    mac_id,
							    rsp);
	}
}

>>>>>>> OPAirDrop/kernel/driver/wma_dev_if.c
```

```diff
<<<<<<< ace5-modules/vendor/qcom/opensource/wlan/qcacld-3.0/core/wma/src/wma_dev_if.c
	req_msg = wma_find_remove_req_msgtype(wma, event->vdev_id,
					WMA_DELETE_STA_REQ);
=======

#ifdef DRIVER_PASSTHRU_MODE
	if (opairshare_awdl_target_delete_reply(event->vdev_id, macaddr))
		return 0;
#endif
	qdf_mem_copy(peer_mac.bytes, macaddr, QDF_MAC_ADDR_SIZE);

	req_msg = wma_find_remove_req_msgtype(wma, event->vdev_id, &peer_mac,
					      WMA_DELETE_STA_REQ);
>>>>>>> OPAirDrop/kernel/driver/wma_dev_if.c
```

## `kernel/driver/wlan_hdd_tx_rx.c` — 1 conflict

- Path: `vendor/qcom/opensource/wlan/qcacld-3.0/core/hdd/src/wlan_hdd_tx_rx.c`
- Gợi ý: 6.1 dùng `sme_create_mon_session()`; 6.6 đổi sang `sme_create_pe_session()`. Giữ `sme_create_mon_session()` của 6.1.

```diff
<<<<<<< ace5-modules/vendor/qcom/opensource/wlan/qcacld-3.0/core/hdd/src/wlan_hdd_tx_rx.c
	qdf_status = sme_create_mon_session(hdd_ctx->mac_handle,
					    adapter->mac_addr.bytes,
					    adapter->deflink->vdev_id);
=======
	qdf_status = sme_create_pe_session(hdd_ctx->mac_handle,
					   sta_desc.peer_addr.bytes,
					   link_info->vdev_id,
					   QDF_MONITOR_MODE);
>>>>>>> OPAirDrop/kernel/driver/wlan_hdd_tx_rx.c
```

## `kernel/driver/wlan_policy_mgr_api.h` — 1 conflict

- Path: `vendor/qcom/opensource/wlan/qcacld-3.0/components/cmn_services/policy_mgr/inc/wlan_policy_mgr_api.h`
- Gợi ý: Chỉ là block prototype mới; thêm toàn bộ block `#ifdef DRIVER_PASSTHRU_MODE` vào sau prototype 6.1, không thay prototype cũ.

```diff
<<<<<<< ace5-modules/vendor/qcom/opensource/wlan/qcacld-3.0/components/cmn_services/policy_mgr/inc/wlan_policy_mgr_api.h
bool policy_mgr_is_given_freq_5g_low(struct wlan_objmgr_psoc *psoc,
				     qdf_freq_t given_freq);
=======
bool
policy_mgr_is_conc_sap_ready_for_mcc_to_scc_trans(
	struct wlan_objmgr_psoc *psoc);

#ifdef DRIVER_PASSTHRU_MODE
bool policy_mgr_opairshare_sta_coexist_enabled(void);
bool policy_mgr_opairshare_sta_pcl_override(struct wlan_objmgr_psoc *psoc,
				     enum policy_mgr_con_mode mode);
bool policy_mgr_opairshare_sta_freq_allowed(struct wlan_objmgr_psoc *psoc,
				     enum policy_mgr_con_mode mode,
				     uint32_t freq);
/**
 * policy_mgr_is_chan_change_allowed_for_passthru() - check if channel change
 *  is allowed for passthru vdev
 * @psoc: psoc pointer
 * @vdev_id: vdev id
 * @freq: channel frequency
 * @bw: bandwidth
 *
 * Return: true if allowed else false
 */
bool
policy_mgr_is_chan_change_allowed_for_passthru(struct wlan_objmgr_psoc *psoc,
					       uint8_t vdev_id, uint32_t freq,
					       enum hw_mode_bandwidth bw);
#endif
>>>>>>> OPAirDrop/kernel/driver/wlan_policy_mgr_api.h
```

## `kernel/driver/wlan_policy_mgr_get_set_utils.c` — 1 conflict

- Path: `vendor/qcom/opensource/wlan/qcacld-3.0/components/cmn_services/policy_mgr/src/wlan_policy_mgr_get_set_utils.c`
- Gợi ý: Hai phía là hai hàm khác nhau (6.1 `policy_mgr_is_sap_go_allowed_with_ll_sap()` và overlay `policy_mgr_allow_passthru_concurrency()`). Giữ cả hai: chèn hàm PAS + include vào trước/sau hàm 6.1.

```diff
<<<<<<< ace5-modules/vendor/qcom/opensource/wlan/qcacld-3.0/components/cmn_services/policy_mgr/src/wlan_policy_mgr_get_set_utils.c
static bool policy_mgr_is_sap_go_allowed_with_ll_sap(
					struct wlan_objmgr_psoc *psoc,
					qdf_freq_t freq,
					enum policy_mgr_con_mode mode)
{
	/**
	 * Scenario: When ll SAP(whose profile is set as gaming or
	 * lossless audio) is present on 5GHz channel and SAP/GO
	 * is trying to come up.
	 * Validate the ch_freq of SAP/GO for both DBS and SBS case
	 */
	if ((mode == PM_SAP_MODE || mode == PM_P2P_GO_MODE) &&
	    !policy_mgr_is_ll_sap_concurrency_valid(psoc, freq, mode))
		return false;

	return true;
}
=======
#ifdef DRIVER_PASSTHRU_MODE
#include "wlan_policy_mgr_opairshare_sta_coexist.h"
static bool
policy_mgr_allow_passthru_concurrency(struct wlan_objmgr_psoc *psoc,
				      enum policy_mgr_con_mode mode,
				      uint32_t ch_freq,
				      struct policy_mgr_pcl_list *pcl)
{
	uint32_t list[MAX_NUMBER_OF_CONC_CONNECTIONS];
	uint32_t conn_count;
	uint32_t i;

	conn_count =
		policy_mgr_mode_specific_connection_count(psoc,
							  PM_PASSTHRU_MODE,
							  list);

	if (mode != PM_PASSTHRU_MODE && !conn_count)
		return true;

	if (policy_mgr_opairshare_sta_coexist_enabled() &&
	    ((mode == PM_STA_MODE && conn_count) ||
	     (mode == PM_PASSTHRU_MODE &&
	      policy_mgr_mode_specific_connection_count(psoc, PM_STA_MODE, NULL))))
		return policy_mgr_opairshare_sta_freq_allowed(psoc, mode, ch_freq);

	if (mode == PM_PASSTHRU_MODE) {
		if (!pcl || !pcl->pcl_len)
			return true;

		for (i = 0; i < pcl->pcl_len; i++) {
			if (pcl->pcl_list[i] == ch_freq) {
				policy_mgr_debug("Passthrough mode allowed on %dMhz",
						 ch_freq);
				return true;
			}
		}

		policy_mgr_debug("Passthrough mode not allowed on %dMhz",
				 ch_freq);
		return false;
	}

	/*
	 * This would only happen for DBS hw as we would reject inital
	 * STA connection in case of non-DBS hw.
	 */
	if (mode == PM_STA_MODE &&
	    policy_mgr_2_freq_same_mac_in_dbs(psoc,
					      pm_conc_connection_list[list[0]].freq,
					      ch_freq)) {
		policy_mgr_debug("STA CSA to %dMHz not allowed", ch_freq);
		return false;
	}

	return true;
}
#else
static inline bool
policy_mgr_allow_passthru_concurrency(struct wlan_objmgr_psoc *psoc,
				      enum policy_mgr_con_mode mode,
... (truncated)
```

## `kernel/driver/dp_rx_mon_dest_1.0.c` — 8 conflict

- Path: `vendor/qcom/opensource/wlan/qca-wifi-host-cmn/dp/wifi3.0/monitor/1.0/dp_rx_mon_dest_1.0.c`
- Gợi ý: 6.1 dùng `mon_pdev`; 6.6 dùng `mon_mac` (multi-MAC). Thay `mon_mac` bằng `mon_pdev` trong các đoạn port, bỏ `dp_get_mon_mac()` nếu 6.1 không có, và thêm các macro `OPAIRSHARE_AUDIT()`. Đây là conflict lớn nhất (8 hunk).

```diff
<<<<<<< ace5-modules/vendor/qcom/opensource/wlan/qca-wifi-host-cmn/dp/wifi3.0/monitor/1.0/dp_rx_mon_dest_1.0.c
	rs = &mon_pdev->rx_mon_recv_status;
=======
	OPAIRSHARE_AUDIT(pop);
	rs = &mon_mac->rx_mon_recv_status;
>>>>>>> OPAirDrop/kernel/driver/dp_rx_mon_dest_1.0.c
```

```diff
<<<<<<< ace5-modules/vendor/qcom/opensource/wlan/qca-wifi-host-cmn/dp/wifi3.0/monitor/1.0/dp_rx_mon_dest_1.0.c
			mon_pdev->rx_mon_stats.dest_mpdu_drop++;
=======
			OPAIRSHARE_AUDIT(rxdma_drop);
			mon_mac->rx_mon_stats.dest_mpdu_drop++;
>>>>>>> OPAirDrop/kernel/driver/dp_rx_mon_dest_1.0.c
```

```diff
<<<<<<< ace5-modules/vendor/qcom/opensource/wlan/qca-wifi-host-cmn/dp/wifi3.0/monitor/1.0/dp_rx_mon_dest_1.0.c
			mon_pdev->rx_mon_stats.dup_mon_linkdesc_cnt++;
=======
			OPAIRSHARE_AUDIT(dup_link);
			mon_mac->rx_mon_stats.dup_mon_linkdesc_cnt++;
>>>>>>> OPAirDrop/kernel/driver/dp_rx_mon_dest_1.0.c
```

```diff
<<<<<<< ace5-modules/vendor/qcom/opensource/wlan/qca-wifi-host-cmn/dp/wifi3.0/monitor/1.0/dp_rx_mon_dest_1.0.c
				mon_pdev->rx_mon_stats.dup_mon_buf_cnt++;
				mon_pdev->mon_last_linkdesc_paddr =
=======
				OPAIRSHARE_AUDIT(dup_buffer);
				mon_mac->rx_mon_stats.dup_mon_buf_cnt++;
				mon_mac->mon_last_linkdesc_paddr =
>>>>>>> OPAirDrop/kernel/driver/dp_rx_mon_dest_1.0.c
```

```diff
<<<<<<< ace5-modules/vendor/qcom/opensource/wlan/qca-wifi-host-cmn/dp/wifi3.0/monitor/1.0/dp_rx_mon_dest_1.0.c
	if (mon_pdev->mon_chan_band == REG_BAND_UNKNOWN)
=======
	pr_err_ratelimited("OPAIRSHARERX: mon-dst mpdu mac=%u band=%u\n", mac_id,
	       mon_mac->mon_chan_band);

	if (mon_mac->mon_chan_band == REG_BAND_UNKNOWN)
>>>>>>> OPAirDrop/kernel/driver/dp_rx_mon_dest_1.0.c
```

```diff
<<<<<<< ace5-modules/vendor/qcom/opensource/wlan/qca-wifi-host-cmn/dp/wifi3.0/monitor/1.0/dp_rx_mon_dest_1.0.c
=======
	mon_mac = dp_get_mon_mac(pdev, mac_id);
	atomic64_inc(&opairshare_rx_dst_calls);
>>>>>>> OPAirDrop/kernel/driver/dp_rx_mon_dest_1.0.c
```

```diff
<<<<<<< ace5-modules/vendor/qcom/opensource/wlan/qca-wifi-host-cmn/dp/wifi3.0/monitor/1.0/dp_rx_mon_dest_1.0.c
				mon_pdev->ppdu_info.com_info.ppdu_id, ppdu_id);
=======
				mon_mac->ppdu_info.com_info.ppdu_id, ppdu_id);
			OPAIRSHARE_AUDIT(stuck);
>>>>>>> OPAirDrop/kernel/driver/dp_rx_mon_dest_1.0.c
```

```diff
<<<<<<< ace5-modules/vendor/qcom/opensource/wlan/qca-wifi-host-cmn/dp/wifi3.0/monitor/1.0/dp_rx_mon_dest_1.0.c
		if (ppdu_id != mon_pdev->ppdu_info.com_info.ppdu_id) {
=======
		if (ppdu_id != mon_mac->ppdu_info.com_info.ppdu_id) {
			OPAIRSHARE_AUDIT(ppdu_break);
>>>>>>> OPAirDrop/kernel/driver/dp_rx_mon_dest_1.0.c
```
