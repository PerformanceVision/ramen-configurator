<?
$citrix = "AS CSV
      SEPARATOR \"\\t\"
      NULL \"\\\\N\"
      NO QUOTES
      ESCAPE WITH \"\\\\\"
    (poller string,                     -- 1
     capture_begin u64,
     capture_end u64,
     pkt_source_kind_client u8?,
     pkt_source_name_client string?,
     pkt_source_kind_server u8?,
     pkt_source_name_server string?,
     vlan_client u32?,
     vlan_server u32?,
     mac_client u64?,
     mac_server u64?,
     zone_client u32,                   -- 10
     zone_server u32,
     ip4_client u32?,
     ip6_client string?,
     ip4_server u32?,
     ip6_server string?,
     port_client u16,
     port_server u16,
     application u32,
     protostack string?,
     connection_uuid string?,           -- 20
     channel_id u8?,
     channel u8?,
     pdus_client u32 {pdus},
     pdus_server u32 {pdus},
     num_compressed_client u32,
     num_compressed_server u32,
     payloads_client u32 {bytes},
     payloads_server u32 {bytes},
     rt_count_server u32 {},
     rt_sum_server u64 {microseconds},  -- 30
     rt_square_sum_server u128 {microseconds^2},
     dtt_count_client u32 {},
     dtt_sum_client u64 {microseconds},
     dtt_square_sum_client u128 {microseconds^2},
     dtt_count_server u32 {},
     dtt_sum_server u64 {microseconds},
     dtt_square_sum_server u128 {microseconds^2},
     username string?,
     domain string?,
     citrix_application string?)        -- 40
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$citrix_chanless = "AS CSV
      SEPARATOR \"\\t\"
      NULL \"\\\\N\"
      NO QUOTES
      ESCAPE WITH \"\\\\\"
    (poller string,                     -- 1
     capture_begin u64,
     capture_end u64,
     pkt_source_kind_client u8?,
     pkt_source_name_client string?,
     pkt_source_kind_server u8?,
     pkt_source_name_server string?,
     vlan_client u32?,
     vlan_server u32?,
     mac_client u64?,
     mac_server u64?,
     zone_client u32,                   -- 10
     zone_server u32,
     ip4_client u32?,
     ip6_client string?,
     ip4_server u32?,
     ip6_server string?,
     port_client u16,
     port_server u16,
     application u32,
     protostack string?,
     connection_uuid string?,           -- 20
     module_name string?,
     encrypt_type u8,
     pdus_client u32,
     pdus_server u32,
     pdus_cgp_client u32,
     pdus_cgp_server u32,
     num_keep_alives_client u32,
     num_keep_alives_server u32,
     payloads_client u32 {bytes},
     payloads_server u32 {bytes},       -- 30
     rt_count_server u32 {},
     rt_sum_server u64 {microseconds},
     rt_square_sum_server u128 {microseconds^2},
     dtt_count_client u32 {},
     dtt_sum_client u64 {microseconds},
     dtt_square_sum_client u128 {microseconds^2},
     dtt_count_server u32 {},
     dtt_sum_server u64 {microseconds},
     dtt_square_sum_server u128 {microseconds^2},
     login_time_count u32 {},
     login_time_sum u64 {microseconds},
     login_time_square_sum u128 {microseconds^2},-- 40
     launch_time_count u32 {},
     launch_time_sum u64 {microseconds},
     launch_time_square_sum u128 {microseconds^2},
     num_aborts u32 {},
     num_timeouts u32 {},
     username string?,
     domain string?,
     citrix_application string?)
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$dns = "AS CSV
      SEPARATOR \"\\t\"
      NULL \"\\\\N\"
      NO QUOTES
      ESCAPE WITH \"\\\\\"
    (poller string,                     -- 1
     capture_begin u64,
     capture_end u64,
     pkt_source_kind_client u8?,
     pkt_source_name_client string?,
     pkt_source_kind_server u8?,
     pkt_source_name_server string?,
     vlan_client u32?,
     vlan_server u32?,
     mac_client u64?,
     mac_server u64?,
     zone_client u32,                   -- 10
     zone_server u32,
     ip4_client u32?,
     ip6_client string?,
     ip4_server u32?,
     ip6_server string?,
     application u32,
     protostack string?,
     _hardcoded_one_facepalm u8,
     query_name string,
     query_type u16,
     query_class u16,
     error_code u8,
     error_count u32 {},                -- 20
     answer_type u16,
     answer_class u16,
     capture_file string?,
     connection_uuid string?,
     traffic_bytes_client u64 {bytes},
     traffic_bytes_server u64 {bytes},
     traffic_packets_client u32 {},
     traffic_packets_server u32 {},
     rt_count_server u32 {},
     rt_sum_server u64 {microseconds},       -- 30
     rt_square_sum_server u128 {microseconds^2})
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$http = "AS CSV
      SEPARATOR \"\\t\"
      NULL \"\\\\N\"
      NO QUOTES
      ESCAPE WITH \"\\\\\"
    (poller string,                     -- 1
     capture_begin u64,
     capture_end u64,
     pkt_source_kind_client u8?,
     pkt_source_name_client string?,
     pkt_source_kind_server u8?,
     pkt_source_name_server string?,
     vlan_client u32?,
     vlan_server u32?,
     mac_client u64?,
     mac_server u64?,
     zone_client u32,                   -- 10
     zone_server u32,
     ip4_client u32?,
     ip6_client string?,
     ip4_server u32?,
     ip6_server string?,
     port_client u16,
     port_server u16,
     connection_uuid string?,
     id string,
     parent_id string,                  -- 20
     referrer_id string?,
     deep_inspect bool,
     contributed bool,
     timeouted bool,
     host string?,
     user_agent string?,
     url string,
     server string?,
     compressed bool,
     chunked_encoding bool,             -- 30
     ajax bool,
     ip4_orig_client u32?,
     ip6_orig_client string?,
     page_count u32 {},  -- 0 or 1 iff a page
     _hardcoded_one_facepalm bool,
     query_begin u64 {microseconds},
     query_end u64 {microseconds},
     query_method u8,
     query_headers u32 {bytes},
     query_payload u32 {bytes},         -- 40
     query_pkts u32,
     query_content string?,
     query_content_length u32? {bytes},
     query_content_length_count u32 {},
     query_mime_type string?,
     resp_begin u64? {microseconds},
     resp_end u64? {microseconds},
     resp_code u32?,
     resp_headers u32 {bytes},
     resp_payload u32 {bytes},          -- 50
     resp_pkts u32,
     resp_content string?,
     resp_content_length u32? {bytes},
     resp_content_length_count u32 {},
     resp_mime_type string?,
     tot_volume_query u32? {bytes},
     tot_volume_response u32? {bytes},
     tot_count u32 {}, -- aka page_hit_count
     tot_errors u16 {},
     tot_timeouts u16 {},       -- 60
     tot_begin u64 {microseconds},
     tot_end u64 {microseconds},
     tot_load_time u64 {microseconds},
     tot_load_time_squared u128 {microseconds^2},
     rt_count_server u32 {},
     rt_sum_server u64 {microseconds},
     rt_square_sum_server u128 {microseconds^2},
     dtt_sum_client u64 {microseconds},
     dtt_square_sum_client u128 {microseconds^2},
     dtt_sum_server u64 {microseconds}, -- 70
     dtt_square_sum_server u128 {microseconds^2},
     application u32)
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$icmp = "AS CSV
      SEPARATOR \"\\t\"
      NULL \"\\\\N\"
      NO QUOTES
      ESCAPE WITH \"\\\\\"
    (poller string,                     -- 1
     capture_begin u64,
     capture_end u64,
     pkt_source_kind_client u8?,
     pkt_source_name_client string?,
     pkt_source_kind_server u8?,
     pkt_source_name_server string?,
     vlan_client u32?,
     vlan_server u32?,
     mac_client u64?,
     mac_server u64?,
     zone_client u32,                   -- 10
     zone_server u32,
     ip4_client u32?,
     ip6_client string?,
     ip4_server u32?,
     ip6_server string?,
     ip4_external u32?,
     ip6_external string?,
     diffserv_client u8,
     diffserv_server u8,
     mtu_client u32? {bytes},           -- 20
     mtu_server u32? {bytes},
     application u32,
     protostack string?,
     traffic_bytes_client u64 {bytes},
     traffic_bytes_server u64 {bytes},
     traffic_packets_client u32,
     traffic_packets_server u32,
     icmp_type u8,
     icmp_code u8,
     error_ip4_client u32?,             -- 30
     error_ip6_client string?,
     error_ip4_server u32?,
     error_ip6_server string?,
     error_port_client u16?,
     error_port_server u16?,
     error_ip_proto u8?,
     error_zone_client u32?,
     error_zone_server u32?)
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$nonip = "AS CSV
      SEPARATOR \"\\t\"
      NULL \"\\\\N\"
      NO QUOTES
      ESCAPE WITH \"\\\\\"
    (poller string,                     -- 1
     capture_begin u64,
     capture_end u64,
     pkt_source_kind_client u8?,
     pkt_source_name_client string?,
     pkt_source_kind_server u8?,
     pkt_source_name_server string?,
     vlan_client u32?,
     vlan_server u32?,
     mac_client u64?,
     mac_server u64?,
     zone_client u32,                   -- 10
     zone_server u32,
     mtu_client u32? {bytes},
     mtu_server u32? {bytes},
     eth_type u16,
     application u32,
     protostack string?,
     traffic_bytes_client u64 {bytes},
     traffic_bytes_server u64 {bytes},
     traffic_packets_client u32,
     traffic_packets_server u32)        -- 20
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$otherip = "AS CSV
      SEPARATOR \"\\t\"
      NULL \"\\\\N\"
      NO QUOTES
      ESCAPE WITH \"\\\\\"
    (poller string,                     -- 1
     capture_begin u64,
     capture_end u64,
     pkt_source_kind_client u8?,
     pkt_source_name_client string?,
     pkt_source_kind_server u8?,
     pkt_source_name_server string?,
     vlan_client u32?,
     vlan_server u32?,
     mac_client u64?,
     mac_server u64?,
     zone_client u32,                   -- 10
     zone_server u32,
     ip4_client u32?,
     ip6_client string?,
     ip4_server u32?,
     ip6_server string?,
     diffserv_client u8,
     diffserv_server u8,
     mtu_client u32? {bytes},
     mtu_server u32? {bytes},
     ip_protocol u8,                    -- 20
     application u32,
     protostack string?,
     traffic_bytes_client u64 {bytes},
     traffic_bytes_server u64 {bytes},
     traffic_packets_client u32,
     traffic_packets_server u32)
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$smb = "AS CSV
      SEPARATOR \"\\t\"
      NULL \"\\\\N\"
      NO QUOTES
      ESCAPE WITH \"\\\\\"
    (poller string,                     -- 1
     capture_begin u64,
     capture_end u64,
     pkt_source_kind_client u8?,
     pkt_source_name_client string?,
     pkt_source_kind_server u8?,
     pkt_source_name_server string?,
     vlan_client u32?,
     vlan_server u32?,
     mac_client u64?,
     mac_server u64?,
     zone_client u32,                   -- 10
     zone_server u32,
     ip4_client u32?,
     ip6_client string?,
     ip4_server u32?,
     ip6_server string?,
     port_client u16,
     port_server u16,
     version u32,
     protostack string?,
     user string?,                      -- 20
     domain string?,
     file_id u128?,
     path string?,
     tree_id u32?,
     tree string?,
     status u32?,
     command u32,
     subcommand u32?,
     timeouted bool,
     errors u32,                     -- 30
     warnings u32,
     queries u32,
     connection_uuid string?,
     query_begin u64,
     query_end u64,
     query_payload u32 {bytes},
     query_pkts u32,
     resp_begin u64?,
     resp_end u64?,
     resp_payload u32 {bytes},          -- 40
     resp_pkts u32,
     meta_read_bytes u32 {bytes},
     meta_write_bytes u32 {bytes},
     query_write_bytes u32 {bytes},
     resp_read_bytes u32 {bytes},
     resp_write_bytes u32 {bytes},
     rt_count_server u32 {},
     rt_sum_server u64 {microseconds},
     rt_square_sum_server u128 {microseconds^2},
     dtt_count_client u32 {},              -- 50
     dtt_sum_client u64 {microseconds},
     dtt_square_sum_client u128 {microseconds^2},
     dtt_count_server u32 {},
     dtt_sum_server u64 {microseconds},
     dtt_square_sum_server u128 {microseconds^2},
     application u32)
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$sql = "AS CSV
      SEPARATOR \"\\t\"
      NULL \"\\\\N\"
      NO QUOTES
      ESCAPE WITH \"\\\\\"
    (poller string,                     -- 1
     capture_begin u64,
     capture_end u64,
     pkt_source_kind_client u8?,
     pkt_source_name_client string?,
     pkt_source_kind_server u8?,
     pkt_source_name_server string?,
     vlan_client u32?,
     vlan_server u32?,
     mac_client u64?,
     mac_server u64?,
     zone_client u32,                   -- 10
     zone_server u32,
     ip4_client u32?,
     ip6_client string?,
     ip4_server u32?,
     ip6_server string?,
     port_client u16,
     port_server u16,
     query string,
     timeouted bool,
     protostack string?,                -- 20
     user string?,
     dbname string?,
     error_sql_status string?,
     error_code string?,
     error_msg string?,
     is_error bool,
     _hardcoded_one_facepalm bool,
     command u32?,
     connection_uuid string?,
     query_begin u64,                -- 30
     query_end u64,
     query_payload u32 {bytes},
     query_pkts u32,
     resp_begin u64?,
     resp_end u64?,
     resp_payload u32 {bytes},
     resp_pkts u32,
     rt_count_server u32 {},
     rt_sum_server u64 {microseconds},
     rt_square_sum_server u128 {microseconds^2},-- 40
     dtt_count_client u32 {},
     dtt_sum_client u64 {microseconds},
     dtt_square_sum_client u128 {microseconds^2},
     dtt_count_server u32 {},
     dtt_sum_server u64 {microseconds},
     dtt_square_sum_server u128 {microseconds^2},
     application u32)
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$tcp = "AS CSV
      SEPARATOR \"\\t\"
      NULL \"\\\\N\"
      NO QUOTES
      ESCAPE WITH \"\\\\\"
    (poller string,                     -- 1
     capture_begin u64,
     capture_end u64,
     pkt_source_kind_client u8?,
     pkt_source_name_client string?,
     pkt_source_kind_server u8?,
     pkt_source_name_server string?,
     vlan_client u32?,
     vlan_server u32?,
     mac_client u64?,
     mac_server u64?,
     zone_client u32,                   -- 10
     zone_server u32,
     ip4_client u32?,
     ip6_client string?,
     ip4_server u32?,
     ip6_server string?,
     ip4_external u32?,
     ip6_external string?,
     port_client u16,
     port_server u16,
     diffserv_client u8,                -- 20
     diffserv_server u8,
     os_client u8?,
     os_server u8?,
     mtu_client u32? {bytes},
     mtu_server u32? {bytes},
     captured_pcap string?,
     application u32,
     protostack string?,
     uuid string?,
     traffic_bytes_client u64 {bytes},  -- 30
     traffic_bytes_server u64 {bytes},
     traffic_packets_client u32,
     traffic_packets_server u32,
     payload_bytes_client u64 {bytes},
     payload_bytes_server u64 {bytes},
     payload_packets_client u32,
     payload_packets_server u32,
     retrans_traffic_bytes_client u64? {bytes},
     retrans_traffic_bytes_server u64? {bytes},
     retrans_payload_bytes_client u64? {bytes}, -- 40
     retrans_payload_bytes_server u64? {bytes},
     syn_count_client u32? {},
     fin_count_client u32? {},
     fin_count_server u32? {},
     rst_count_client u32? {},
     rst_count_server u32? {},
     timeout_count u32 {},
     close_count u32? {},
     dupack_count_client u32? {},
     dupack_count_server u32? {},-- 50
     zero_window_count_client u32? {},
     zero_window_count_server u32? {},
     -- Some counts can be null although the sums cannot ...
     ct_count u32? {},
     ct_sum u64 {microseconds},
     ct_square_sum u128 {microseconds^2},
     rt_count_server u32? {},
     rt_sum_server u64 {microseconds},
     rt_square_sum_server u128 {microseconds^2},
     rtt_count_client u32? {},
     rtt_sum_client u64 {microseconds}, -- 60
     rtt_square_sum_client u128 {microseconds^2},
     rtt_count_server u32? {},
     rtt_sum_server u64 {microseconds},
     rtt_square_sum_server u128 {microseconds^2},
     rd_count_client u32? {},
     rd_sum_client u64 {microseconds},
     rd_square_sum_client u128 {microseconds^2},
     rd_count_server u32? {},
     rd_sum_server u64 {microseconds},
     rd_square_sum_server u128 {microseconds^2},-- 70
     dtt_count_client u32? {},
     dtt_sum_client u64 {microseconds},
     dtt_square_sum_client u128 {microseconds^2},
     dtt_count_server u32? {},
     dtt_sum_server u64 {microseconds},
     dtt_square_sum_server u128 {microseconds^2},
     dcerpc_uuid string?)
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$tls = "AS CSV
      SEPARATOR \"\\t\"
      NULL \"\\\\N\"
      NO QUOTES
      ESCAPE WITH \"\\\\\"
    (poller string,                     -- 1
     capture_begin u64,
     capture_end u64,
     pkt_source_kind_client u8?,
     pkt_source_name_client string?,
     pkt_source_kind_server u8?,
     pkt_source_name_server string?,
     vlan_client u32?,
     vlan_server u32?,
     mac_client u64?,
     mac_server u64?,
     zone_client u32,                   -- 10
     zone_server u32,
     ip4_client u32?,
     ip6_client string?,
     ip4_server u32?,
     ip6_server string?,
     port_client u16,
     port_server u16,
     application u32,
     protostack string?,
     connection_uuid string?,           -- 20
     cipher_suite u32?,
     client_common_name string?,
     server_common_name string?,
     server_name string?,
     client_not_after u64? {seconds(rel)},
     server_not_after u64? {seconds(rel)},
     resumed u32, -- actually a bool
     decrypted u32, -- actually a bool
     version u32,
     client_signature string?,          -- 30
     server_signature string?,
     client_serial_number string?,
     server_serial_number string?,
     client_type u32?,
     server_type u32?,
     client_bits u32?,
     server_bits u32?,
     meta_client u32 {pdus},
     meta_server u32 {pdus},
     data_client u32,
     data_server u32,
     alert_types u32,                   -- 40
     alert_errors u32,
     traffic_bytes_client u64 {bytes},
     traffic_bytes_server u64 {bytes},
     payload_bytes_client u64 {bytes},
     payload_bytes_server u64 {bytes},
     dtt_count_client u32 {},
     dtt_sum_client u64 {microseconds},
     dtt_square_sum_client u128 {microseconds^2},
     dtt_count_server u32 {},
     dtt_sum_server u64 {microseconds}, -- 50
     dtt_square_sum_server u128 {microseconds^2},
     rt_count_server u32 {},
     rt_sum_server u64 {microseconds},
     rt_square_sum_server u128 {microseconds^2},
     ct_count u32? {},
     ct_sum u64 {microseconds},
     ct_square_sum u128 {microseconds^2})
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$udp = "AS CSV
       SEPARATOR \"\\t\"
       NULL \"\\\\N\"
       NO QUOTES
       ESCAPE WITH \"\\\\\"
    (poller string,                     -- 1
     capture_begin u64,
     capture_end u64,
     pkt_source_kind_client u8?,
     pkt_source_name_client string?,
     pkt_source_kind_server u8?,
     pkt_source_name_server string?,
     vlan_client u32?,
     vlan_server u32?,
     mac_client u64?,
     mac_server u64?,
     zone_client u32,                   -- 10
     zone_server u32,
     ip4_client u32?,
     ip6_client string?,
     ip4_server u32?,
     ip6_server string?,
     ip4_external u32?,
     ip6_external string?,
     port_client u16,
     port_server u16,
     diffserv_client u8,                -- 20
     diffserv_server u8,
     mtu_client u32? {bytes},
     mtu_server u32? {bytes},
     application u32,
     protostack string?,
     traffic_bytes_client u64 {bytes},
     traffic_bytes_server u64 {bytes},
     traffic_packets_client u32,
     traffic_packets_server u32,
     payload_bytes_client u64 {bytes},   -- 30
     payload_bytes_server u64 {bytes},
     dcerpc_uuid string?)
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$voip = "AS CSV
      SEPARATOR \"\\t\"
      NULL \"\\\\N\"
      NO QUOTES
      ESCAPE WITH \"\\\\\"
    (poller string,                     -- 1
     capture_begin u64,
     capture_end u64,
     pkt_source_kind_client u8?,
     pkt_source_name_client string?,
     pkt_source_kind_server u8?,
     pkt_source_name_server string?,
     vlan_client u32?,
     vlan_server u32?,
     mac_client u64?,
     mac_server u64?,
     zone_client u32,                   -- 10
     zone_server u32,
     ip4_client u32?,
     ip6_client string?,
     ip4_server u32?,
     ip6_server string?,
     port_client u16,
     port_server u16,
     capture_file string?,
     application u32,
     protostack string?,                -- 20
     connection_uuid string?,
     ip_protocol u8,
     had_voice bool,
     call_direction_is_out bool?,
     last_call_state u8,
     is_starting bool,
     is_finished bool,
     _hardcoded_0 bool,
     last_error u32,
     call_id string,                    -- 30
     rtp_duration u64?,
     id_caller string,
     caller_mac u64,
     ip4_caller u32?,
     ip6_caller string?,
     zone_caller u32,
     caller_codec string?,
     id_callee string,
     callee_mac u64,
     ip4_callee u32?,                   -- 40
     ip6_callee string?,
     zone_callee u32,
     callee_codec string?,
     sign_bytes_client u32 {bytes},
     sign_bytes_server u32 {bytes},
     sign_count_client u32 {},
     sign_count_server u32 {},
     sign_payload_client u32 {bytes},
     sign_payload_server u32 {bytes},
     -- v29 specs say these are client/server but junkie seems to do the right
     -- thing here, that is: callee/caller:
     rtp_rtcp_bytes_caller u32 {bytes}, -- 50
     rtp_rtcp_bytes_callee u32 {bytes},
     rtp_rtcp_count_caller u32 {},
     rtp_rtcp_count_callee u32 {},
     rtp_rtcp_payload_caller u32 {bytes},
     rtp_rtcp_payload_callee u32 {bytes},
     rt_count_server u32 {},
     rt_sum_server u64 {microseconds},
     rt_square_sum_server u128 {microseconds^2},
     jitter_count_caller u32 {},
     jitter_sum_caller u64 {microseconds},-- 60
     jitter_square_sum_caller u128 {microseconds^2},
     jitter_count_callee u32 {},
     jitter_sum_callee u64 {microseconds},
     jitter_square_sum_callee u128 {microseconds^2},
     rtt_count_caller u32 {},
     rtt_sum_caller u64 {microseconds},
     rtt_square_sum_caller u128 {microseconds^2},
     rtt_count_callee u32 {},
     rtt_sum_callee u64 {microseconds},
     rtt_square_sum_callee u128 {microseconds^2},-- 70
     loss_callee2caller_alt_count u32 {},
     loss_caller2callee_alt_count u32 {},
     sign_rtt_count_client u32 {},
     sign_rtt_sum_client u64 {microseconds},
     sign_rtt_square_sum_client u128 {microseconds^2},
     sign_rtt_count_server u32 {},
     sign_rtt_sum_server u64 {microseconds},
     sign_rtt_square_sum_server u128 {microseconds^2},
     sign_rd_count_client u32 {},
     sign_rd_sum_client u64 {microseconds},-- 80
     sign_rd_square_sum_client u128 {microseconds^2},
     sign_rd_count_server u32 {},
     sign_rd_sum_server u64 {microseconds},
     sign_rd_square_sum_server u128 {microseconds^2})
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";
?>
