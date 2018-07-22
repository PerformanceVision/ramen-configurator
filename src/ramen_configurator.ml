open Batteries
open RamenLog
open RamenHelpers

let rebase dataset_name name = dataset_name ^"/"^ name

let enc = Uri.pct_encode

(* Get the operations to import the dataset and do basic transformations.
 * Named streams belonging to this base program:
 * - ${dataset_name}/tcp, etc: Raw imported tuples straight from the CSV;
 * - ${dataset_name}/c2s tcp: The first of a pair of streams of traffic info
 *                            (source to dest rather than client to server);
 * - ${dataset_name}/s2c tcp: The second stream of traffic info;
 *
 * If you wish to process traffic info you must feed on both c2s and s2c.
 *)

let make_func name op =
  "DEFINE '"^ name ^"' AS "^ op ^";\n"

let program_of_funcs funcs =
  String.concat "\n" funcs

let rep sub by str = String.nreplace ~str ~sub ~by

let print_squoted oc = Printf.fprintf oc "'%s'"

(* Aggregating TCP metrics for alert discovery: *)
let tcp_traffic_func ?where dataset_name name dt =
  let dt_us = dt * 1_000_000 in
  let parents =
    List.map (rebase dataset_name) ["c2s tcp"; "s2c tcp"] |>
    IO.to_string (List.print ~first:"" ~last:"" ~sep:","
                    print_squoted) in
  let op =
    {|FROM $PARENTS$ SELECT
       (capture_begin // $DT_US$) * $DT$ AS start,
       min capture_begin, max capture_end,
       sum packets_src / $DT$ AS packets_per_secs,
       sum bytes_src / $DT$ AS bytes_per_secs,
       sum payload_src / $DT$ AS payload_per_secs,
       sum packets_with_payload_src / $DT$ AS packets_with_payload_per_secs,
       sum COALESCE(retrans_bytes_src, 0) / $DT$ AS retrans_bytes_per_secs,
       sum COALESCE(retrans_payload_src, 0) / $DT$ AS retrans_payload_per_secs,
       sum COALESCE(fins_src, 0) / $DT$ AS fins_per_secs,
       sum COALESCE(rsts_src, 0) / $DT$ AS rsts_per_secs,
       sum timeouts / $DT$ AS timeouts_per_secs,
       sum COALESCE(syns, 0) / $DT$ AS syns_per_secs,
       sum COALESCE(closes, 0) / $DT$ AS closes_per_secs,
       sum COALESCE(connections, 0) AS _sum_connections,
       _sum_connections / $DT$ AS connections_per_secs,
       sum COALESCE(dupacks_src, 0) / $DT$ AS dupacks_per_secs,
       sum COALESCE(zero_windows_src, 0) / $DT$ AS zero_windows_per_secs,
       sum COALESCE(rtt_count_src, 0) AS sum_rtt_count_src,
       sum rtt_sum_src AS _sum_rtt_sum_src,
       (_sum_rtt_sum_src / sum_rtt_count_src) / 1e6 AS rtt_avg,
       ((float(sum rtt_sum2_src) - float(_sum_rtt_sum_src)^2 / sum_rtt_count_src) /
           sum_rtt_count_src) / 1e12 AS rtt_var,
       sum COALESCE(rd_count_src, 0) AS sum_rd_count_src,
       sum rd_sum_src AS _sum_rd_sum_src,
       (_sum_rd_sum_src / sum_rd_count_src) / 1e6 AS rd_avg,
       ((float(sum rd_sum2_src) - float(_sum_rd_sum_src)^2 / sum_rd_count_src) /
           sum_rd_count_src) / 1e12 AS rd_var,
       sum COALESCE(dtt_count_src, 0) AS sum_dtt_count_src,
       sum dtt_sum_src AS _sum_dtt_sum_src,
       (_sum_dtt_sum_src / sum_dtt_count_src) / 1e6 AS dtt_avg,
       ((float(sum dtt_sum2_src) - float(_sum_dtt_sum_src)^2 / sum_dtt_count_src) /
           sum_dtt_count_src) / 1e12 AS dtt_var,
       sum connections_time AS _sum_connections_time,
       (_sum_connections_time / _sum_connections) / 1e6 AS connection_time_avg,
       ((float(sum connections_time2) - float(_sum_connections_time)^2 / _sum_connections) /
           _sum_connections) / 1e12 AS connection_time_var
     -- Exclude netflow traffic
     WHERE retrans_bytes_src IS NOT NULL AND
           retrans_payload_src IS NOT NULL AND
           syns IS NOT NULL AND
           fins_src IS NOT NULL AND
           rsts_src IS NOT NULL AND
           closes IS NOT NULL AND
           connections IS NOT NULL AND
           dupacks_src IS NOT NULL AND
           zero_windows_src IS NOT NULL AND
           rtt_count_src IS NOT NULL AND
           rd_count_src IS NOT NULL AND
           dtt_count_src IS NOT NULL
     GROUP BY capture_begin // $DT_US$
     COMMIT AFTER
       in.capture_begin > out.min_capture_begin + 2 * u64($DT_US$)
     EVENT STARTING AT start WITH DURATION $DT$s|} |>
    rep "$DT$" (string_of_int dt) |>
    rep "$DT_US$" (string_of_int dt_us) |>
    rep "$PARENTS$" parents
  in
  let op =
    match where with None -> op
                   | Some w -> op ^"\nWHERE "^ w in
  make_func name op

(* Anomaly Detection
 *
 * For any func which output interesting timeseries (interesting = that we hand
 * pick) we will add a func that compute all predictions we can compute for the
 * series. We will notify when x out of y predictions are "off". for perf
 * reasons we want the number of such funcs minimal, but as we have only one
 * possible notify per func we also can't have one func for different unrelated
 * things. A good trade-off is to have one func per BCN/BCA.
 * For each timeseries to predict, we also pass a list of other timeseries that
 * we think are good predictors. *)
let anomaly_detection_funcs avg_window from name timeseries alert_fields =
  assert (timeseries <> []) ;
  let stand_alone_predictors = [ "smooth(" ; "fit(5, " ; "5-ma(" ; "lag(" ]
  and multi_predictors = [ "fit_multi(5, " ] in
  let predictor_name = from ^": "^ name ^" predictions" in
  let predictor_func =
    let predictions =
      List.fold_left (fun fields (ts, condition, nullable, preds) ->
          let preds_str = String.concat ", " preds in
          (* Add first the timeseries itself: *)
          let fields = ts :: fields in
          (* Then the predictors: *)
          let i, fields =
            List.fold_left (fun (i, fields) predictor ->
                i+1,
                (Printf.sprintf "%s%s) AS pred_%d_%s" predictor ts i ts) :: fields
              ) (0, fields) stand_alone_predictors in
          let nb_preds, fields =
            if preds <> [] then
              List.fold_left (fun (i, fields) multi_predictor ->
                  i + 1,
                  (Printf.sprintf "%s%s, %s) AS pred_%d_%s"
                     multi_predictor ts preds_str i ts) :: fields
                ) (i, fields) multi_predictors
            else i, fields in
          (* Then the "abnormality" of this timeseries: *)
          let abnormality =
            let rec loop sum i =
              if i >= nb_preds then sum else
              let pred = "pred_"^ string_of_int i ^"_"^ ts in
              let abno = "abs("^ pred ^" - "^ ts ^") /\n     \
                            max(abs "^ pred ^", abs "^ ts ^")" in
              let abno = if nullable then "coalesce("^ abno ^", 0)"
                         else abno in
              loop (abno :: sum) (i + 1) in
            loop [] 0 in
          let abnormality =
            "("^ String.concat " +\n   " abnormality ^") / "^
            string_of_int nb_preds in
          let abnormality =
            match condition with
            | "" -> abnormality
            | cond ->
              "IF "^ cond ^" THEN "^ abnormality ^" ELSE 0" in
          let abnormality = abnormality ^" AS abnormality_"^ ts in
          abnormality :: fields
        ) [] timeseries
    in
    let op =
      Printf.sprintf
        "SELECT\n  \
           start,\n  \
           %s\n\
         FROM '%s'\n\
         EVENT STARTING AT start WITH DURATION %s"
        (String.concat ",\n  " (List.rev predictions))
        from
        avg_window in
    make_func predictor_name op in
  let anomaly_func =
    let conditions =
      List.fold_left (fun cond (ts, _condition, _nullable, _preds) ->
          ("abnormality_"^ ts ^" > 0.75") :: cond
        ) [] timeseries in
    let condition = String.concat " OR\n     " conditions in
    let alert_name = from ^" "^ name ^" looks abnormal" in
    let op =
      Printf.sprintf2
        {|FROM '%s'
          SELECT start,
          (%s) AS abnormality,
          5-ma float(abnormality) AS _recent_abnormality,
          hysteresis (_recent_abnormality, 3/5, 4/5) AS firing
          COMMIT,
            NOTIFY %S WITH
              "${firing}" AS firing,
              abs(_recent_abnormality - 3/5) AS certainty%a
            AND KEEP ALL
          AFTER firing != COALESCE(previous.firing, false)
          EVENT STARTING AT start|}
        predictor_name
        condition
        alert_name
        (List.print ~first:",\n" ~sep:",\n" ~last:"\n"
          (fun oc (n, v) -> Printf.fprintf oc "%S AS %s" v n))
          alert_fields in
    make_func (from ^": "^ name ^" anomalies") op in
  predictor_func, anomaly_func

let base_program dataset_name delete uncompress csv_glob =
  (* Outlines of CSV importers: *)
  let csv_import csv fields =
    "READ"^ (if delete then " AND DELETE" else "") ^
    " FILES \""^ (csv_glob |> rep "%" csv) ^"\""^
    (if uncompress then " PREPROCESS WITH \"lz4 -d -c\"" else "") ^
    " SEPARATOR \"\\t\" NULL \"<NULL>\" ("^ fields ^")"
  (* Helper to build dsr-dst view of clt-srv metrics, keeping only the fields
   * that are useful for traffic-related computations: *)
  and to_unidir csv non_cs_fields cs_fields ~src ~dst name =
    let cs_fields = cs_fields |>
      List.fold_left (fun s (field, alias) ->
        let alias = if alias <> "" then alias else field in
        s ^"    "^ field ^"_"^ src ^" AS "^ alias ^"_src, "
                 ^ field ^"_"^ dst ^" AS "^ alias ^"_dst,\n") ""
    in
    let op =
      "FROM '"^ csv ^"' SELECT\n"^
      cs_fields ^ non_cs_fields ^"\n"^
      "WHERE traffic_packets_"^ src ^" > 0\n"^
      "EVENT STARTING AT capture_begin * 1e-6 \
       AND STOPPING AT capture_end * 1e-6" in
    make_func name op in
  (* TCP CSV Importer: *)
  let tcp = csv_import "tcp" {|
      poller string,  -- 1
      capture_begin u64,
      capture_end u64,
      device_client u16?,
      device_server u16?,
      vlan_client u32?,
      vlan_server u32?,
      mac_client u64?,
      mac_server u64?,
      zone_client u32,  -- 10
      zone_server u32,
      ip4_client u32?,
      ip6_client i128?,
      ip4_server u32?,
      ip6_server i128?,
      ip4_external u32?,
      ip6_external i128?,
      port_client u16,
      port_server u16,
      diffserv_client u8,  -- 20
      diffserv_server u8,
      os_client u8?,
      os_server u8?,
      mtu_client u32?,
      mtu_server u32?,
      captured_pcap string?,
      application u32,
      protostack string?,
      uuid string?,
      traffic_bytes_client u64,  -- 30
      traffic_bytes_server u64,
      traffic_packets_client u32,
      traffic_packets_server u32,
      payload_bytes_client u64,
      payload_bytes_server u64,
      payload_packets_client u32,
      payload_packets_server u32,
      retrans_traffic_bytes_client u64?,
      retrans_traffic_bytes_server u64?,
      retrans_payload_bytes_client u64?,
      retrans_payload_bytes_server u64?,
      syn_count_client u32?,
      fin_count_client u32?,
      fin_count_server u32?,
      rst_count_client u32?,
      rst_count_server u32?,
      timeout_count u32,
      close_count u32?,
      dupack_count_client u32?,
      dupack_count_server u32?,
      zero_window_count_client u32?,
      zero_window_count_server u32?,
      -- Some counts can be null althgouh the sums cannot ...
      ct_count u32?,
      ct_sum u64,
      ct_square_sum u128,
      rt_count_server u32?,
      rt_sum_server u64,
      rt_square_sum_server u128,
      rtt_count_client u32?,
      rtt_sum_client u64,
      rtt_square_sum_client u128,
      rtt_count_server u32?,
      rtt_sum_server u64,
      rtt_square_sum_server u128,
      rd_count_client u32?,
      rd_sum_client u64,
      rd_square_sum_client u128,
      rd_count_server u32?,
      rd_sum_server u64,
      rd_square_sum_server u128,
      dtt_count_client u32?,
      dtt_sum_client u64,
      dtt_square_sum_client u128,
      dtt_count_server u32?,
      dtt_sum_server u64,
      dtt_square_sum_server u128,
      dcerpc_uuid string?|} |>
    make_func "tcp"
  and tcp_to_unidir = to_unidir "tcp" {|
    poller, capture_begin, capture_end,
    ip4_external, ip6_external,
    captured_pcap, application, protostack, uuid,
    timeout_count AS timeouts, close_count AS closes,
    ct_count AS connections, ct_sum AS connections_time,
    ct_square_sum AS connections_time2, syn_count_client AS syns,
    dcerpc_uuid|} [
    "device", "" ; "vlan", "" ; "mac", "" ; "zone", "" ; "ip4", "" ;
    "ip6", "" ; "port", "" ; "diffserv", "" ; "os", "" ; "mtu", "" ;
    "traffic_packets", "packets" ; "traffic_bytes", "bytes" ;
    "payload_bytes", "payload" ;
    "payload_packets", "packets_with_payload" ;
    "retrans_traffic_bytes", "retrans_bytes" ;
    "retrans_payload_bytes", "retrans_payload" ;
    "fin_count", "fins" ; "rst_count", "rsts" ;
    "dupack_count", "dupacks" ; "zero_window_count", "zero_windows" ;
    "rtt_count", "" ; "rtt_sum", "" ; "rtt_square_sum", "rtt_sum2" ;
    "rd_count", "" ; "rd_sum", "" ; "rd_square_sum", "rd_sum2" ;
    "dtt_count", "" ; "dtt_sum", "" ; "dtt_square_sum", "dtt_sum2" ]
  (* UDP CSV Importer: *)
  and udp = csv_import "udp" {|
      poller string,  -- 1
      capture_begin u64,
      capture_end u64,
      device_client u16?,
      device_server u16?,
      vlan_client u32?,
      vlan_server u32?,
      mac_client u64?,
      mac_server u64?,
      zone_client u32,  -- 10
      zone_server u32,
      ip4_client u32?,
      ip6_client i128?,
      ip4_server u32?,
      ip6_server i128?,
      ip4_external u32?,
      ip6_external i128?,
      port_client u16,
      port_server u16,
      diffserv_client u8,  -- 20
      diffserv_server u8,
      mtu_client u32?,
      mtu_server u32?,
      application u32,
      protostack string?,
      traffic_bytes_client u64,
      traffic_bytes_server u64,
      traffic_packets_client u32,
      traffic_packets_server u32,
      payload_bytes_client u64,  -- 30
      payload_bytes_server u64,
      dcerpc_uuid string?|} |>
    make_func "udp"
  and udp_to_unidir = to_unidir "udp" {|
    poller, capture_begin, capture_end,
    ip4_external, ip6_external,
    0u32n AS rtt_count_src, 0u64 AS rtt_sum_src,
    0u32 AS packets_with_payload_src, 0u32n AS rd_count_src,
    application, protostack,
    dcerpc_uuid|} [
    "device", "" ; "vlan", "" ; "mac", "" ; "zone", "" ; "ip4", "" ;
    "ip6", "" ; "port", "" ; "diffserv", "" ; "mtu", "" ;
    "traffic_packets", "packets" ; "traffic_bytes", "bytes" ;
    "payload_bytes", "payload" ]
  (* IP (non UDP/TCP) CSV Importer: *)
  and icmp = csv_import "icmp" {|
      poller string,
      capture_begin u64,
      capture_end u64,
      device_client u16?,
      device_server u16?,
      vlan_client u32?,
      vlan_server u32?,
      mac_client u64?,
      mac_server u64?,
      zone_client u32,
      zone_server u32,
      ip4_client u32?,
      ip6_client i128?,
      ip4_server u32?,
      ip6_server i128?,
      ip4_external u32?,
      ip6_external i128?,
      diffserv_client u8,
      diffserv_server u8,
      mtu_client u16?,
      mtu_server u16?,
      application u32,
      protostack string?,
      traffic_bytes_client u64,
      traffic_bytes_server u64,
      traffic_packets_client u32,
      traffic_packets_server u32,
      icmp_type u8,
      icmp_code u8,
      error_ip4_client u32?,
      error_ip6_client i128?,
      error_ip4_server u32?,
      error_ip6_server i128?,
      error_port_client u16?,
      error_port_server u16?,
      error_ip_proto u8?,
      error_zone_client u32?,
      error_zone_server u32?|} |>
    make_func "icmp"
  and icmp_to_unidir = to_unidir "icmp" {|
    poller, capture_begin, capture_end,
    ip4_external, ip6_external,
    0u32n AS rtt_count_src, 0u64 AS rtt_sum_src,
    0u32 AS packets_with_payload_src, 0u32n AS rd_count_src,
    application, protostack|} [
    "device", "" ; "vlan", "" ; "mac", "" ; "zone", "" ; "ip4", "" ;
    "ip6", "" ; "diffserv", "" ; "mtu", "" ;
    "traffic_packets", "packets" ; "traffic_bytes", "bytes" ]
  (* IP (non UDP/TCP) CSV Importer: *)
  and other_ip = csv_import "other_ip" {|
      poller string,
      capture_begin u64,
      capture_end u64,
      device_client u16?,
      device_server u16?,
      vlan_client u32?,
      vlan_server u32?,
      mac_client u64?,
      mac_server u64?,
      zone_client u32,
      zone_server u32,
      ip4_client u32?,
      ip6_client i128?,
      ip4_server u32?,
      ip6_server i128?,
      diffserv_client u8,
      diffserv_server u8,
      mtu_client u16?,
      mtu_server u16?,
      ip_protocol u8,
      application u32,
      protostack string?,
      traffic_bytes_client u64,
      traffic_bytes_server u64,
      traffic_packets_client u32,
      traffic_packets_server u32|} |>
    make_func "other-ip"
  and other_ip_to_unidir = to_unidir "other-ip" {|
    poller, capture_begin, capture_end,
    0u32n AS rtt_count_src, 0u64 AS rtt_sum_src,
    0u32 AS packets_with_payload_src, 0u32n AS rd_count_src,
    application, protostack|} [
    "device", "" ; "vlan", "" ; "mac", "" ; "zone", "" ; "ip4", "" ;
    "ip6", "" ; "diffserv", "" ; "mtu", "" ;
    "traffic_packets", "packets" ; "traffic_bytes", "bytes" ]
  (* non-IP CSV Importer: *)
  and non_ip = csv_import "non_ip" {|
      poller string,
      capture_begin u64,
      capture_end u64,
      device_client u16?,
      device_server u16?,
      vlan_client u32?,
      vlan_server u32?,
      mac_client u64?,
      mac_server u64?,
      zone_client u32,
      zone_server u32,
      mtu_client u16?,
      mtu_server u16?,
      eth_type u16,
      application u32,
      protostack string?,
      traffic_bytes_client u64,
      traffic_bytes_server u64,
      traffic_packets_client u32,
      traffic_packets_server u32|} |>
    make_func "non-ip"
  and non_ip_to_unidir = to_unidir "non-ip" {|
    poller, capture_begin, capture_end,
    0u32n AS rtt_count_src, 0u64 AS rtt_sum_src,
    0u32 AS packets_with_payload_src, 0u32n AS rd_count_src,
    application, protostack|} [
    "device", "" ; "vlan", "" ; "mac", "" ; "zone", "" ; "mtu", "" ;
    "traffic_packets", "packets" ; "traffic_bytes", "bytes" ]
  (* DNS CSV Importer: *)
  and dns = csv_import "dns" {|
      poller string,
      capture_begin u64,
      capture_end u64,
      device_client u16?,
      device_server u16?,
      vlan_client u32?,
      vlan_server u32?,
      mac_client u64?,
      mac_server u64?,
      zone_client u32,
      zone_server u32,
      ip4_client u32?,
      ip6_client i128?,
      ip4_server u32?,
      ip6_server i128?,
      query_name string,
      query_type u16,
      query_class u16,
      error_code u8,
      error_count u32,
      answer_type u16,
      answer_class u16,
      capture_file string?,
      connection_uuid string?,
      traffic_bytes_client u64,
      traffic_bytes_server u64,
      traffic_packets_client u32,
      traffic_packets_server u32,
      rt_count_server u32,
      rt_sum_server u64,
      rt_square_sum_server u128|} |>
    make_func "dns"
  (* HTTP CSV Importer: *)
  and http = csv_import "http" {|
      poller string,
      capture_begin u64,
      capture_end u64,
      device_client u16?,
      device_server u16?,
      vlan_client u32?,
      vlan_server u32?,
      mac_client u64?,
      mac_server u64?,
      zone_client u32, -- 10
      zone_server u32,
      ip4_client u32?,
      ip6_client i128?,
      ip4_server u32?,
      ip6_server i128?,
      port_client u16,
      port_server u16,
      connection_uuid string?,
      id string,
      parent_id string,  -- 20
      referrer_id string?,
      deep_inspect bool,
      contributed bool,
      timeouted bool,
      host string?,
      user_agent string?,
      url string,
      server string?,
      compressed bool,
      chunked_encoding bool,  -- 30
      ajax bool,
      ip4_orig_client u32?,
      ip6_orig_client i128?,
      page_count u32,
      hardcoded_one_facepalm bool,
      query_begin_ts u64,
      query_end_ts u64,
      query_method u8,
      query_headers u32,
      query_payload u32,  -- 40
      query_pkts u32,
      query_content string?,
      query_content_length u32?,
      query_content_length_count u32,
      query_mime_type string?,
      resp_begin_ts u64?,
      resp_end_ts u64?,
      resp_code u32?,
      resp_headers u32,
      resp_payload u32,  -- 50
      resp_pkts u32,
      resp_content string?,
      resp_content_length u32?,
      resp_content_length_count u32,
      resp_mime_type string?,
      tot_volume_query u32?,
      tot_volume_response u32?,
      tot_count u32,
      tot_errors u16,
      tot_timeouts u16,  -- 60
      tot_begin_ts u64,
      tot_end_ts u64,
      tot_load_time u64,
      tot_load_time_squared u128,
      rt_count_server u32,
      rt_sum_server u64,
      rt_square_sum_server u128,
      dtt_sum_client u64,
      dtt_square_sum_client u128,
      dtt_sum_server u64,  -- 70
      dtt_square_sum_server u128,
      application u32|} |>
    make_func "http"
  (* Citrix CSV Importer: *)
  and citrix = csv_import "citrix" {|
      poller string,
      capture_begin u64,
      capture_end u64,
      device_client u16?,
      device_server u16?,
      vlan_client u32?,
      vlan_server u32?,
      mac_client u64?,
      mac_server u64?,
      zone_client u32,
      zone_server u32,
      ip4_client u32?,
      ip6_client i128?,
      ip4_server u32?,
      ip6_server i128?,
      port_client u16,
      port_server u16,
      application u32,
      protostack string?,
      connection_uuid string?,
      channel_id u8?,
      channel u8?,
      pdus_client u32,
      pdus_server u32,
      nb_compressed_client u32,
      nb_compressed_server u32,
      payloads_client u32,
      payloads_server u32,
      rt_count_server u32,
      rt_sum_server u64,
      rt_square_sum_server u128,
      dtt_count_client u32,
      dtt_sum_client u64,
      dtt_square_sum_client u128,
      dtt_count_server u32,
      dtt_sum_server u64,
      dtt_square_sum_server u128,
      username string?,
      domain string?,
      citrix_application string?|} |>
    make_func "citrix"
  (* Citrix (without channel) CSV Importer: *)
  and citrix_chanless = csv_import "citrix_chanless" {|
      poller string,
      capture_begin u64,
      capture_end u64,
      device_client u16?,
      device_server u16?,
      vlan_client u32?,
      vlan_server u32?,
      mac_client u64?,
      mac_server u64?,
      zone_client u32,  -- 10
      zone_server u32,
      ip4_client u32?,
      ip6_client i128?,
      ip4_server u32?,
      ip6_server i128?,
      port_client u16,
      port_server u16,
      application u32,
      protostack string?,
      connection_uuid string?,  -- 20
      module_name string?,
      encrypt_type u8,
      pdus_client u32,
      pdus_server u32,
      pdus_cgp_client u32,
      pdus_cgp_server u32,
      nb_keep_alives_client u32,
      nb_keep_alives_server u32,
      payloads_client u32,
      payloads_server u32,  -- 30
      rt_count_server u32,
      rt_sum_server u64,
      rt_square_sum_server u128,
      dtt_count_client u32,
      dtt_sum_client u64,
      dtt_square_sum_client u128,
      dtt_count_server u32,
      dtt_sum_server u64,
      dtt_square_sum_server u128,
      login_time_count u32,
      login_time_sum u64,
      login_time_square_sum u128,  -- 40
      launch_time_count u32,
      launch_time_sum u64,
      launch_time_square_sum u128,
      nb_aborts u32,
      nb_timeouts u32,
      username string?,
      domain string?,
      citrix_application string?|} |>
    make_func "citrix_chanless"
  (* SMB CSV Importer: *)
  and smb = csv_import "smb" {|
      poller string,
      capture_begin u64,
      capture_end u64,
      device_client u16?,
      device_server u16?,
      vlan_client u32?,
      vlan_server u32?,
      mac_client u64?,
      mac_server u64?,
      zone_client u32,  -- 10
      zone_server u32,
      ip4_client u32?,
      ip6_client i128?,
      ip4_server u32?,
      ip6_server i128?,
      port_client u16,
      port_server u16,
      version u32,
      protostack string?,
      user string?,  -- 20
      domain string?,
      file_id u128?,
      path string?,
      tree_id u32?,
      tree string?,
      status u32?,
      command u32,
      subcommand u32?,
      timeouted bool,
      is_error bool,  -- 30
      is_warning bool,
      hardcoded_one_facepalm bool,
      connection_uuid string?,
      query_begin_ts u64,
      query_end_ts u64,
      query_payload u32,
      query_pkts u32,
      resp_begin_ts u64?,
      resp_end_ts u64?,
      resp_payload u32,  -- 40
      resp_pkts u32,
      meta_read_bytes u32,
      meta_write_bytes u32,
      query_write_bytes u32,
      resp_read_bytes u32,
      resp_write_bytes u32,
      rt_count_server u32,
      rt_sum_server u64,
      rt_square_sum_server u128,
      dtt_count_client u32,  -- 50
      dtt_sum_client u64,
      dtt_square_sum_client u128,
      dtt_count_server u32,
      dtt_sum_server u64,
      dtt_square_sum_server u128,
      application u32|} |>
    make_func "smb"
  (* SQL CSV Importer: *)
  and sql = csv_import "sql" {|
      poller string,
      capture_begin u64,
      capture_end u64,
      device_client u16?,
      device_server u16?,
      vlan_client u32?,
      vlan_server u32?,
      mac_client u64?,
      mac_server u64?,
      zone_client u32,  -- 10
      zone_server u32,
      ip4_client u32?,
      ip6_client i128?,
      ip4_server u32?,
      ip6_server i128?,
      port_client u16,
      port_server u16,
      query string,
      timeouted bool,
      protostack string?,  -- 20
      user string?,
      dbname string?,
      error_sql_status string?,
      error_code string?,
      error_msg string?,
      is_error bool,
      hardcoded_one_facepalm bool,
      command u32?,
      connection_uuid string?,
      query_begin_ts u64,  -- 30
      query_end_ts u64,
      query_payload u32,
      query_pkts u32,
      resp_begin_ts u64?,
      resp_end_ts u64?,
      resp_payload u32,
      resp_pkts u32,
      rt_count_server u32,
      rt_sum_server u64,
      rt_square_sum_server u128,  -- 40
      dtt_count_client u32,
      dtt_sum_client u64,
      dtt_square_sum_client u128,
      dtt_count_server u32,
      dtt_sum_server u64,
      dtt_square_sum_server u128,
      application u32|} |>
    make_func "sql"
  (* VoIP CSV Importer: *)
  and voip = csv_import "voip" {|
      poller string,
      capture_begin u64,
      capture_end u64,
      device_client u16?,
      device_server u16?,
      vlan_client u32?,
      vlan_server u32?,
      mac_client u64?,
      mac_server u64?,
      zone_client u32,  -- 10
      zone_server u32,
      ip4_client u32?,
      ip6_client i128?,
      ip4_server u32?,
      ip6_server i128?,
      port_client u16,
      port_server u16,
      capture_file string?,
      application u32,
      protostack string?,
      connection_uuid string?,
      ip_protocol u8,
      had_voice bool,
      call_direction_is_out bool?,
      last_call_state u8,
      is_starting bool,
      is_finished bool,
      hardcoded_0 bool,
      last_error u32,
      call_id string,
      rtp_duration u64?,
      id_caller string,
      caller_mac u64,
      ip4_caller u32?,
      ip6_caller i128?,
      zone_caller u32,
      caller_codec string?,
      id_callee string,
      callee_mac u64,
      ip4_callee u32?,
      ip6_callee i128?,
      zone_callee u32,
      callee_codec string?,
      sign_bytes_client u32,
      sign_bytes_server u32,
      sign_count_client u32,
      sign_count_server u32,
      sign_payload_client u32,
      sign_payload_server u32,
      rtp_rtcp_bytes_client u32,
      rtp_rtcp_bytes_server u32,
      rtp_rtcp_count_client u32,
      rtp_rtcp_count_server u32,
      rtp_rtcp_payload_client u32,
      rtp_rtcp_payload_server u32,
      rt_count_server u32,
      rt_sum_server u64,
      rt_square_sum_server u128,
      jitter_count_caller u32,
      jitter_sum_caller u64,
      jitter_square_sum_caller u128,
      jitter_count_callee u32,
      jitter_sum_callee u64,
      jitter_square_sum_callee u128,
      rtt_count_caller u32,
      rtt_sum_caller u64,
      rtt_square_sum_caller u128,
      rtt_count_callee u32,
      rtt_sum_callee u64,
      rtt_square_sum_callee u128,
      loss_callee2caller_alt_count u32,
      loss_caller2callee_alt_count u32,
      sign_rtt_count_client u32,
      sign_rtt_sum_client u64,
      sign_rtt_square_sum_client u128,
      sign_rtt_count_server u32,
      sign_rtt_sum_server u64,
      sign_rtt_square_sum_server u128,
      sign_rd_count_client u32,
      sign_rd_sum_client u64,
      sign_rd_square_sum_client u128,
      sign_rd_count_server u32,
      sign_rd_sum_server u64,
      sign_rd_square_sum_server u128|} |>
    make_func "voip"
  in
  dataset_name,
  program_of_funcs [
    tcp ;
    tcp_to_unidir ~src:"client" ~dst:"server" "c2s tcp" ;
    tcp_to_unidir ~src:"server" ~dst:"client" "s2c tcp" ;
    udp ;
    udp_to_unidir ~src:"client" ~dst:"server" "c2s udp" ;
    udp_to_unidir ~src:"server" ~dst:"client" "s2c udp" ;
    icmp ;
    icmp_to_unidir ~src:"client" ~dst:"server" "c2s icmp" ;
    icmp_to_unidir ~src:"server" ~dst:"client" "s2c icmp" ;
    other_ip ;
    other_ip_to_unidir ~src:"client" ~dst:"server" "c2s other-ip" ;
    other_ip_to_unidir ~src:"server" ~dst:"client" "s2c other-ip" ;
    non_ip ;
    non_ip_to_unidir ~src:"client" ~dst:"server" "c2s non-ip" ;
    non_ip_to_unidir ~src:"server" ~dst:"client" "s2c non-ip" ;
    dns ; http ; citrix ; citrix_chanless ; smb ; sql ; voip ]

(* Build the func infos corresponding to the BCN configuration *)
let program_of_bcns dataset_name =
  let open Conf_of_sqlite.BCN in
  let where =
    {|(source_name = "any" OR in.zone_src IN source) AND
      (dest_name = "any" OR in.zone_dst IN dest)|}
  and anom name timeseries =
    let alert_fields =
      [ "metric", name ;
        "desc", "anomaly detected" ;
        "bcn", "${param.id}" ] in
    let pred, anom =
      anomaly_detection_funcs "avg_window" "TCP minutely" name timeseries alert_fields in
    [ pred ; anom ]
  in
  let funcs = [
    {|
    PARAMETERS id DEFAULTS TO 0
      AND min_bps U32? DEFAULTS TO NULL
      AND max_bps U32? DEFAULTS TO NULL
      AND max_rtt FLOAT? DEFAULTS TO NULL
      AND max_rr FLOAT? DEFAULTS TO NULL
      AND min_for_relevance DEFAULTS TO 0 -- TODO
      AND avg_window DEFAULTS TO 360.0
      AND obs_window DEFAULTS TO 600.0
      AND perc DEFAULTS TO 90.0
      AND source U32[] DEFAULTS TO [0]
      AND source_name DEFAULTS TO "any"
      AND dest U32[] DEFAULTS TO [0]
      AND dest_name DEFAULTS TO "any";
    |} ;
    (* This operation differs from tcp_traffic_func:
     * - it adds zone_src and zone_dst names, which can be useful indeed;
     * - it lacks many of the TCP-only fields and so can apply to all
     *   traffic;
     * - it works for whatever avg_window not necessarily minutely. *)
    Printf.sprintf {|
      DEFINE 'avg traffic' AS
        FROM '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s'
        MERGE ON capture_begin TIMEOUT AFTER 2 SECONDS
        SELECT
          (capture_begin // u32(avg_window)) * u32(avg_window) AS start,
          min capture_begin, max capture_end,
          -- Traffic
          sum packets_src / avg_window AS packets_per_secs,
          sum bytes_src / avg_window AS bytes_per_secs,
          -- RTT (in seconds)
          sum COALESCE(rtt_count_src, 0) AS _sum_rtt_count_src,
          IF _sum_rtt_count_src = 0 THEN 0 ELSE
            (sum rtt_sum_src / _sum_rtt_count_src) / 1e6 AS avg_rtt,
          -- RD: percentage of retransmitted packets over packets with payload
          sum packets_with_payload_src AS _sum_packets_with_payload_src,
          IF _sum_packets_with_payload_src = 0 THEN 0 ELSE
            (sum COALESCE(rd_count_src, 0) / _sum_packets_with_payload_src) / 100 AS avg_rr,
          source_name AS zone_src, dest_name AS zone_dst
        WHERE
          %s
        GROUP BY capture_begin // u32(avg_window)
        COMMIT AFTER
          in.capture_begin > out.min_capture_begin + 2 * u64(avg_window)
        EVENT STARTING AT start WITH DURATION avg_window;
      |}
      (rebase dataset_name "c2s tcp") (rebase dataset_name "s2c tcp")
      (rebase dataset_name "c2s udp") (rebase dataset_name "s2c udp")
      (rebase dataset_name "c2s icmp") (rebase dataset_name "s2c icmp")
      (rebase dataset_name "c2s other-ip") (rebase dataset_name "s2c other-ip")
      (rebase dataset_name "c2s non-ip") (rebase dataset_name "s2c non-ip")
      where ;
    {|
      DEFINE percentiles AS
        -- Note: The event start at the end of the observation window and
        -- lasts for one avg window!
        FROM 'avg traffic' SELECT
          min start, max start,
          min min_capture_begin AS min_capture_begin,
          max max_capture_end AS max_capture_end,
          perc percentile bytes_per_secs AS bytes_per_secs,
          perc percentile avg_rtt AS rtt,
          perc percentile avg_rr AS rr,
          zone_src, zone_dst
        COMMIT AND SLIDE 1 AFTER
          group.#count >= round (obs_window / avg_window) OR
          in.start > out.max_start + 5
        EVENT STARTING AT max_capture_end * 1e-6
          WITH DURATION avg_window;
    |} ;
    {|
      DEFINE 'traffic too low' AS
        FROM percentiles
        SELECT
          max_start,
          COALESCE (
            hysteresis (bytes_per_secs, min_bps*1.1, min_bps),
            false) AS firing
        COMMIT,
          NOTIFY "Low traffic from ${param.source_name} to ${dest_name}" WITH
            "${firing}" AS firing,
            COALESCE(reldiff(bytes_per_secs, min_bps), 0) AS certainty,
            "The traffic from zone ${param.source_name} to ${param.dest_name} has sunk below the configured minimum of ${param.min_bps} for the last ${obs_window} seconds." AS desc,
            "${id}" AS bcn,
            "${bytes_per_secs}" AS values,
            "${min_bps}" AS thresholds
          AND KEEP ALL
        AFTER firing != COALESCE(previous.firing, false)
        EVENT STARTING AT max_start;
    |} ;
    {|
      DEFINE 'traffic too high' AS
        FROM percentiles
        SELECT
            max_start,
            COALESCE (
              hysteresis (bytes_per_secs, max_bps*0.9, max_bps),
              false) AS firing
        COMMIT,
          NOTIFY "High traffic from ${param.source_name} to ${param.dest_name}" WITH
            "${firing}" AS firing,
            COALESCE(reldiff(bytes_per_secs, max_bps), 0) AS certainty,
            "The traffic from zone ${source_name} to ${dest_name} has raised above the configured maximum of ${param.max_bps} for the last ${obs_window} seconds." AS desc,
            "${id}" AS bcn,
            "${bytes_per_secs}" AS values,
            "${max_bps}" AS thresholds
          AND KEEP ALL
        AFTER firing != COALESCE(previous.firing, false)
        EVENT STARTING AT max_start;
    |} ;
    {|
      DEFINE 'round-trip time' AS
        FROM percentiles
        SELECT
          max_start, rtt,
          COALESCE (
            hysteresis (rtt, max_rtt*0.9, max_rtt),
            false) AS firing
        COMMIT,
          NOTIFY "RTT too high from ${source_name} to ${dest_name}" WITH
            "${firing}" AS firing,
            COALESCE(reldiff(rtt, max_rtt), 0) AS certainty,
            "Traffic from zone ${source_name} to zone ${dest_name} has an average RTT of ${rtt}, greater than the configured maximum of ${max_rtt}s, for the last ${obs_window} seconds." AS desc,
            "${id}" AS bcn,
            "${rtt}" AS values,
            "${max_rtt}" AS thresholds
          AND KEEP ALL
        AFTER firing != COALESCE(previous.firing, false)
        EVENT STARTING AT max_start;
    |} ;
    {|
      DEFINE retransmissions AS
        FROM percentiles
        SELECT
          max_start, rr,
          COALESCE (
            hysteresis (rr, max_rr*0.9, max_rr),
            false) AS firing
        COMMIT,
          NOTIFY "Too many retransmissions from ${source_name} to ${dest_name}" WITH
            "${firing}" AS firing,
            COALESCE(reldiff(rr, max_rr), 0) AS certainty,
            "Traffic from zone ${source_name} to zone ${dest_name} has an average retransmission rate of ${rr}%%, greater than the configured maximum of ${max_rr}s, for the last ${obs_window} seconds." AS desc,
            "${id}" AS bcn,
            "${rr}" AS values,
            "${max_rr}" AS thresholds
          AND KEEP ALL
        AFTER firing != COALESCE(previous.firing, false)
        EVENT STARTING AT max_start;
    |} ;
    tcp_traffic_func ~where dataset_name "TCP minutely" 60
  ] @
  (* TODO: a volume anomaly for other protocols as well *)
  anom "volume"
    [ "packets_per_secs", "packets_per_secs > 10", false,
        [ "bytes_per_secs" ; "packets_with_payload_per_secs" ] ;
      "bytes_per_secs", "bytes_per_secs > 1000", false,
        [ "packets_per_secs" ; "payload_per_secs" ] ;
      "payload_per_secs", "payload_per_secs > 1000", false,
        [ "bytes_per_secs" ] ;
      "packets_with_payload_per_secs",
        "packets_with_payload_per_secs > 10", false,
        [ "packets_per_secs" ] ] @
  anom "retransmissions"
    [ "retrans_bytes_per_secs", "retrans_bytes_per_secs > 1000", false,
      [ "retrans_payload_per_secs" ] ;
      "dupacks_per_secs", "dupacks_per_secs > 1", false, [] ] @
  anom "connections"
    [ "fins_per_secs", "fins_per_secs > 1", false, [ "packets_per_secs" ] ;
      "rsts_per_secs", "rsts_per_secs > 1", false, [ "packets_per_secs" ] ;
      "syns_per_secs", "syns_per_secs > 1", false, [ "packets_per_secs" ] ;
      "connections_per_secs", "connections_per_secs > 1", false, [] ;
      "connection_time_avg", "connections_per_secs > 1", false, [] ] @
  anom "0-windows"
    [ "zero_windows_per_secs", "zero_windows_per_secs > 1", false, [] ] @
  anom "RTT" [ "rtt_avg", "sum_rtt_count_src > 10", false, [] ] @
  anom "RD" [ "rd_avg", "sum_rd_count_src > 10", false, [] ] @
  anom "DTT" [ "dtt_avg", "sum_dtt_count_src > 10", false, [] ]
  in
  rebase dataset_name "BCN",
  program_of_funcs funcs

(* Build the func infos corresponding to the BCA configuration *)
let program_of_bcas dataset_name =
  let program_name = rebase dataset_name "BCA" in
  let csv = rebase dataset_name "tcp" in
  let averages =
    {|FROM '$CSV$' SELECT
        -- Key
        (capture_begin * 0.000001 // u32(avg_window)) * u32(avg_window) AS start,
        -- Traffic
        sum traffic_bytes_client / avg_window AS c2s_bytes_per_secs,
        sum traffic_bytes_server / avg_window AS s2c_bytes_per_secs,
        sum traffic_packets_client / avg_window AS c2s_packets_per_secs,
        sum traffic_packets_server / avg_window AS s2c_packets_per_secs,
        -- Retransmissions
        sum COALESCE(retrans_traffic_bytes_client, 0) / avg_window
          AS c2s_retrans_bytes_per_secs,
        sum COALESCE(retrans_traffic_bytes_server, 0) / avg_window
          AS s2c_retrans_bytes_per_secs,
        -- TCP flags
        sum COALESCE(syn_count_client, 0) / avg_window AS c2s_syns_per_secs,
        sum COALESCE(fin_count_client, 0) / avg_window AS c2s_fins_per_secs,
        sum COALESCE(fin_count_server, 0) / avg_window AS s2c_fins_per_secs,
        sum COALESCE(rst_count_client, 0) / avg_window AS c2s_rsts_per_secs,
        sum COALESCE(rst_count_server, 0) / avg_window AS s2c_rsts_per_secs,
        sum COALESCE(close_count, 0) / avg_window AS close_per_secs,
        -- TCP issues
        sum COALESCE(dupack_count_client, 0) / avg_window AS c2s_dupacks_per_secs,
        sum COALESCE(dupack_count_server, 0) / avg_window AS s2c_dupacks_per_secs,
        sum COALESCE(zero_window_count_client, 0) / avg_window AS c2s_0wins_per_secs,
        sum COALESCE(zero_window_count_server, 0) / avg_window AS s2c_0wins_per_secs,
        -- Connection Time
        sum COALESCE(ct_count, 0) AS sum_ct_count,
        sum ct_sum AS _sum_ct_sum,
        sum_ct_count / avg_window AS ct_per_secs,
        IF sum_ct_count = 0 THEN 0 ELSE
          (_sum_ct_sum / sum_ct_count) / 1e6 AS ct_avg,
        IF sum_ct_count = 0 THEN 0 ELSE
          sqrt (((float(sum ct_square_sum) - (_sum_ct_sum)^2) /
                 sum_ct_count) / 1e12) AS ct_stddev,
        -- Server Response Time
        sum COALESCE(rt_count_server, 0) AS sum_rt_count_server,
        sum rt_sum_server AS _sum_rt_sum_server,
        sum_rt_count_server / avg_window AS srt_per_secs,
        IF sum_rt_count_server = 0 THEN 0 ELSE
          (_sum_rt_sum_server / sum_rt_count_server) / 1e6 AS srt_avg,
        IF sum_rt_count_server = 0 THEN 0 ELSE
          sqrt (((float(sum rt_square_sum_server) - (_sum_rt_sum_server)^2) /
                 sum_rt_count_server) / 1e12) AS srt_stddev,
        -- Round Trip Time CSC
        sum COALESCE(rtt_count_server, 0) AS sum_rtt_count_server,
        sum rtt_sum_server AS _sum_rtt_sum_server,
        sum_rtt_count_server / avg_window AS crtt_per_secs,
        IF sum_rtt_count_server = 0 THEN 0 ELSE
          (_sum_rtt_sum_server / sum_rtt_count_server) / 1e6 AS crtt_avg,
        IF sum_rtt_count_server = 0 THEN 0 ELSE
          sqrt (((float(sum rtt_square_sum_server) - (_sum_rtt_sum_server)^2) /
                 sum_rtt_count_server) / 1e12) AS crtt_stddev,
        -- Round Trip Time SCS
        sum COALESCE(rtt_count_client, 0) AS sum_rtt_count_client,
        sum rtt_sum_client AS _sum_rtt_sum_client,
        sum_rtt_count_client / avg_window AS srtt_per_secs,
        IF sum_rtt_count_client = 0 THEN 0 ELSE
          (_sum_rtt_sum_client / sum_rtt_count_client) / 1e6 AS srtt_avg,
        IF sum_rtt_count_client = 0 THEN 0 ELSE
          sqrt (((float(sum rtt_square_sum_client) - (_sum_rtt_sum_client)^2) /
                 sum_rtt_count_client) / 1e12) AS srtt_stddev,
        -- Retransmition Delay C2S
        sum COALESCE(rd_count_client, 0) AS sum_rd_count_client,
        sum rd_sum_client AS _sum_rd_sum_client,
        sum_rd_count_client / avg_window AS crd_per_secs,
        IF sum_rd_count_client = 0 THEN 0 ELSE
          (_sum_rd_sum_client / sum_rd_count_client) / 1e6 AS crd_avg,
        IF sum_rd_count_client = 0 THEN 0 ELSE
          sqrt (((float(sum rd_square_sum_client) - (_sum_rd_sum_client)^2) /
                 sum_rd_count_client) / 1e12) AS crd_stddev,
        -- Retransmition Delay S2C
        sum COALESCE(rd_count_server, 0) AS sum_rd_count_server,
        sum rd_sum_server AS _sum_rd_sum_server,
        sum_rd_count_server / avg_window AS srd_per_secs,
        IF sum_rd_count_server = 0 THEN 0 ELSE
          (_sum_rd_sum_server / sum_rd_count_server) / 1e6 AS srd_avg,
        IF sum_rd_count_server = 0 THEN 0 ELSE
          sqrt (((float(sum rd_square_sum_server) - (_sum_rd_sum_server)^2) /
                 sum_rd_count_server) / 1e12) AS srd_stddev,
        -- Data Transfer Time C2S
        sum COALESCE(dtt_count_client, 0) AS sum_dtt_count_client,
        sum dtt_sum_client AS _sum_dtt_sum_client,
        sum_dtt_count_client / avg_window AS cdtt_per_secs,
        IF sum_dtt_count_client = 0 THEN 0 ELSE
          (_sum_dtt_sum_client / sum_dtt_count_client) / 1e6 AS cdtt_avg,
        IF sum_dtt_count_client = 0 THEN 0 ELSE
          sqrt (((float(sum dtt_square_sum_client) - (_sum_dtt_sum_client)^2) /
                 sum_dtt_count_client) / 1e12) AS cdtt_stddev,
        -- Data Transfer Time S2C
        sum COALESCE(dtt_count_server, 0) AS sum_dtt_count_server,
        sum dtt_sum_server AS _sum_dtt_sum_server,
        sum_dtt_count_server / avg_window AS sdtt_per_secs,
        IF sum_dtt_count_server = 0 THEN 0 ELSE
          (_sum_dtt_sum_server / sum_dtt_count_server) / 1e6 AS sdtt_avg,
        IF sum_dtt_count_server = 0 THEN 0 ELSE
          sqrt (((float(sum dtt_square_sum_server) - (_sum_dtt_sum_server)^2) /
                 sum_dtt_count_server) / 1e12) AS sdtt_stddev
      WHERE application = service_id AND
            -- Exclude netflow
            retrans_traffic_bytes_client IS NOT NULL AND
            retrans_traffic_bytes_server IS NOT NULL AND
            syn_count_client IS NOT NULL AND
            fin_count_client IS NOT NULL AND
            fin_count_server IS NOT NULL AND
            rst_count_client IS NOT NULL AND
            rst_count_server IS NOT NULL AND
            close_count IS NOT NULL AND
            dupack_count_client IS NOT NULL AND
            dupack_count_server IS NOT NULL AND
            zero_window_count_client IS NOT NULL AND
            zero_window_count_server IS NOT NULL AND
            ct_count IS NOT NULL AND
            rt_count_server IS NOT NULL AND
            rtt_count_server IS NOT NULL AND
            rtt_count_client IS NOT NULL AND
            rd_count_client IS NOT NULL AND
            rd_count_server IS NOT NULL AND
            dtt_count_client IS NOT NULL AND
            dtt_count_server IS NOT NULL
      GROUP BY capture_begin * 0.000001 // u32(avg_window)
      COMMIT AFTER
        in.capture_begin * 0.000001 > out.start + 2 * avg_window
      EVENT STARTING AT start WITH DURATION avg_window|} |>
    rep "$CSV$" csv in
  let percentiles =
    (* Note: The event start at the end of the observation window and lasts
     * for one avg window! *)
    (* EURT = RTTs + SRT + DTTs (DTT server to client being optional) *)
    (* FIXME: sum of percentiles rather than percentiles of avg *)
    Printf.sprintf
      {|FROM averages SELECT
         min start, max start,
         srtt_avg, crtt_avg, srt_avg, cdtt_avg, sdtt_avg,
         perc percentile (
          srtt_avg + crtt_avg + srt_avg + cdtt_avg + sdtt_avg) AS eurt
       COMMIT AND SLIDE 1 AFTER
         group.#count >= i32(obs_window / avg_window) OR
         in.start > out.max_start + 5
       EVENT STARTING AT max_start WITH DURATION obs_window|}
  in
  let eurt_too_high =
    Printf.sprintf
      {|SELECT
          max_start,
          hysteresis (eurt, max_eurt - max_eurt/10, max_eurt) AS firing
        FROM percentiles
        COMMIT,
          NOTIFY "EURT to ${param.name} is too large" WITH
            "${firing}" AS firing,
            reldiff(eurt, max_eurt) AS certainty,
            "The average end user response time to application ${param.name} has raised above the configured maximum of ${param.max_eurt}s for the last ${param.obs_window} seconds." AS desc,
            "${param.id}" AS bca,
            "${param.service_id}" AS service_id,
            "${eurt}" AS values,
            "${param.max_eurt}" AS thresholds
          AND KEEP ALL
        AFTER firing != COALESCE(previous.firing, false)
        EVENT STARTING AT max_start|} in
  let anom name timeseries funcs =
    let alert_fields =
      [ "metric", name ;
        "desc", "anomaly detected" ;
        "bca", "${param.id}" ] in
    let pred, anom =
      anomaly_detection_funcs "avg_window" "averages" name timeseries alert_fields in
    pred :: anom :: funcs in
  let funcs =
    anom "volume"
      [ "c2s_bytes_per_secs", "c2s_bytes_per_secs > 1000", false, [] ;
        "s2c_bytes_per_secs", "s2c_bytes_per_secs > 1000", false, [] ;
        "c2s_packets_per_secs", "c2s_packets_per_secs > 10", false, [] ;
        "s2c_packets_per_secs", "s2c_packets_per_secs > 10", false, [] ] [] |>
    anom "retransmissions"
      [ "c2s_retrans_bytes_per_secs", "c2s_retrans_bytes_per_secs > 1000", false, [] ;
        "s2c_retrans_bytes_per_secs", "s2c_retrans_bytes_per_secs > 1000", false, [] ;
        "c2s_dupacks_per_secs", "c2s_dupacks_per_secs > 10", false, [] ;
        "s2c_dupacks_per_secs", "s2c_dupacks_per_secs > 10", false, [] ] |>
    anom "connections"
      [ "c2s_syns_per_secs", "c2s_syns_per_secs > 1", false, [] ;
        "s2c_rsts_per_secs", "s2c_rsts_per_secs > 1", false, [] ;
        "close_per_secs", "close_per_secs > 1", false, [] ;
        "ct_avg", "sum_ct_count > 10", false, [] ] |>
    anom "0-windows"
      [ "c2s_0wins_per_secs", "c2s_0wins_per_secs > 1", false, [] ;
        "s2c_0wins_per_secs", "s2c_0wins_per_secs > 1", false, [] ] |>
    anom "SRT" [ "srt_avg", "sum_rt_count_server > 10", false, [] ] |>
    anom "RTT"
      [ "crtt_avg", "sum_rtt_count_server > 10", false, [] ;
        "srtt_avg", "sum_rtt_count_client > 10", false, [] ] |>
    anom "RD"
      [ "crd_avg", "sum_rd_count_client > 10", false, [] ;
        "srd_avg", "sum_rd_count_server > 10", false, [] ] |>
    anom "DTT"
      [ "cdtt_avg", "sum_dtt_count_client > 10", false, [] ;
        "sdtt_avg", "sum_dtt_count_server > 10", false, [] ]
  in
  let funcs =
    "PARAMETERS id DEFAULTS TO 0\n\
     \tAND service_id DEFAULTS TO 0\n\
     \tAND name DEFAULTS TO \"\"\n\
     \tAND max_eurt DEFAULTS TO 0.0\n\
     \tAND avg_window DEFAULTS TO 360.0\n\
     \tAND obs_window DEFAULTS TO 600.0\n\
     \tAND perc DEFAULTS TO 90.0\n\
     \tAND min_handshake_count DEFAULTS TO 0;\n" ::
    make_func "averages" averages ::
    make_func "percentiles" percentiles ::
    make_func "EURT too high" eurt_too_high ::
    List.rev funcs in
  program_name, program_of_funcs funcs

let get_config_from_db db =
  Conf_of_sqlite.get_config db

let sec_program dataset_name =
  let program_name = rebase dataset_name "Security" in
  let rebase_list csvs =
    List.map (fun p -> "'"^ rebase dataset_name p ^"'") csvs |>
    String.join "," in
  let ddos avg_win rem_win =
    let op_new_peers =
      let avg_win_us = avg_win * 1_000_000 in
      {|FROM $CSVS$
        MERGE ON capture_begin TIMEOUT AFTER 2 SECONDS
        SELECT
         (capture_begin // $AVG_WIN_US$) * $AVG_WIN$ AS start,
         min capture_begin, max capture_end,
         -- Traffic (of any kind) we haven't seen in the last $REM_WIN$ secs.
         -- Increase the estimate of *not* remembering since we ask for 10% of
         -- false positives.
         sum (1.1 * float(not remember (
                0.1, -- 10% of false positives
                capture_begin // 1_000_000, $REM_WIN$,
                coalesce (ip4_client, ip6_client, 0),
                coalesce (ip4_server, ip6_server, 0)))) /
           $AVG_WIN$
           AS nb_new_cnxs_per_secs,
         -- Clients we haven't seen in the last $REM_WIN$ secs.
         sum (1.1 * float(not remember (
                0.1,
                capture_begin // 1_000_000, $REM_WIN$,
                coalesce (ip4_client, ip6_client, 0)))) /
            $AVG_WIN$
            AS nb_new_clients_per_secs
       GROUP BY capture_begin // $AVG_WIN_US$
       COMMIT AFTER
         in.capture_begin > out.min_capture_begin + 2 * u64($AVG_WIN_US$)
       EVENT STARTING AT start WITH DURATION $AVG_WIN$s|} |>
      rep "$AVG_WIN_US$" (string_of_int avg_win_us) |>
      rep "$AVG_WIN$" (string_of_int avg_win) |>
      rep "$REM_WIN$" (string_of_int rem_win) |>
      rep "$CSVS$" (rebase_list ["tcp" ; "udp" ; "icmp" ; "other-ip"]) in
    let global_new_peers =
      make_func "new peers" op_new_peers in
    let pred_func, anom_func =
      anomaly_detection_funcs
        ((string_of_int avg_win)^"s") "new peers" "DDoS"
        [ "nb_new_cnxs_per_secs", "nb_new_cnxs_per_secs > 1", false, [] ;
          "nb_new_clients_per_secs", "nb_new_clients_per_secs > 1", false, [] ]
        [ "desc", "possible DDoS" ] in
    [ global_new_peers ; pred_func ; anom_func ]
  and port_scan_detector top_n obs_win =
    make_func "top_port_scans"
      ({|FROM $CSVS$
         MERGE ON capture_begin TIMEOUT AFTER 2 SECONDS
         WHEN
           NOT remember globally (
             0.1, capture_begin / 1_000_000, $WIN$,
             -- We do not take into account IP proto, so a ping on a TCP port
             -- grants you a free ping on the same UDP port.
             coalesce (ip4_client, ip6_client, 0),
             coalesce (ip4_server, ip6_server, 0),
             port_server) AND
           IS coalesce (ip4_client, ip6_client, 0),
              coalesce (ip4_server, ip6_server, 0) IN TOP $TOP_N$
         SELECT min (capture_begin / 1_000_000) AS start,
                max (capture_end / 1_000_000) AS end,
                coalesce (ip4_client, ip6_client, 0) as client,
                coalesce (ip4_server, ip6_server, 0) as server,
                sum 1 as port_count
         GROUP BY coalesce (ip4_client, ip6_client, 0),
                  coalesce (ip4_server, ip6_server, 0)
         COMMIT BEFORE end - start > $WIN$|} |>
       rep "$WIN$" (string_of_int obs_win) |>
       rep "$TOP_N$" (string_of_int top_n) |>
       rep "$CSVS$" (rebase_list ["tcp" ; "udp"]))
  and port_scan_alert max_ports =
    make_func "port_scan_alert"
      ({|FROM top_port_scans
         WHEN port_count > $MAX_PORTS$
         NOTIFY "Port-Scan from ${client} to ${server}" WITH
           reldiff(port_count, $MAX_PORTS$) AS certainty,
           "${client} has probed at least ${port_count} ports of ${server} from ${start} to ${end}'" AS desc,
           "${client},${server}" AS ips,
           "${port_count}" AS values,
           "$MAX_PORTS$" AS thresholds|} |>
       rep "$MAX_PORTS$" (string_of_int max_ports))
  and ip_scan_detector top_n obs_win =
    make_func "top_ip_scans"
      ({|FROM $CSVS$
         MERGE ON capture_begin TIMEOUT AFTER 2 SECONDS
         WHEN
           NOT remember globally (
             0.1, capture_begin / 1_000_000, $WIN$,
             -- An IP scanner could use varying proto/port to detect host
             -- presence so we just care about src and dst here:
             coalesce (ip4_client, ip6_client, 0),
             coalesce (ip4_server, ip6_server, 0)) AND
           IS coalesce (ip4_client, ip6_client, 0) IN TOP $TOP_N$
         SELECT min (capture_begin / 1_000_000) AS start,
                max (capture_end / 1_000_000) AS end,
                coalesce (ip4_client, ip6_client, 0) as client,
                sum 1 as ip_count
         GROUP BY coalesce (ip4_client, ip6_client, 0)
         COMMIT BEFORE end - start > $WIN$|} |>
       rep "$WIN$" (string_of_int obs_win) |>
       rep "$TOP_N$" (string_of_int top_n) |>
       rep "$CSVS$" (rebase_list ["tcp" ; "udp" ; "icmp" ; "other-ip"]))
  and ip_scan_alert max_ips =
    make_func "ip_scan_alert"
      ({|FROM top_ip_scans
         WHEN ip_count > $MAX_IPS$
         NOTIFY "IP-Scan from ${client}" WITH
           reldiff(ip_count, $MAX_IPS$) AS certainty,
           "${client}" AS ips,
           "${ip_count}" AS values,
           "$MAX_IPS$" AS thresholds|} |>
       rep "$MAX_IPS$" (string_of_int max_ips))
  in
  program_name,
  program_of_funcs (
    ddos 100 3600 @
    (* one top every hour, as scans can be performed slowly *)
    [ port_scan_detector 100 3600 ; port_scan_alert 30 ;
      ip_scan_detector 100 3600 ; ip_scan_alert 100 ])

(* Daemon *)

let write_program root_dir (program_name, program_code) =
  let fname = root_dir ^"/"^ program_name ^".ramen" in
  mkdir_all ~is_file:true fname ;
  File.with_file_out ~mode:[`create;`trunc;`text] fname (fun oc ->
    Printf.fprintf oc "%s\n" program_code) ;
  fname

let compile_program ramen_cmd root_dir bundle_dir fname =
  let cmd =
    Printf.sprintf2 "%s compile --root=%S --bundle-dir=%S %s"
      ramen_cmd root_dir bundle_dir (shell_quote fname) in
  if 0 = Sys.command cmd then (
    !logger.debug "Compiled %s" fname ;
    (* Now Ramen with autoreload should pick it up *)
    true
  ) else (
    !logger.error "Failed to compile program %s with %S" fname cmd ;
    false
  )

let run_program ramen_cmd root_dir persist_dir fname params =
  let cmd =
    Printf.sprintf2 "%s run --persist-dir %s %a %s"
      ramen_cmd
      (shell_quote persist_dir)
      (List.print ~first:"" ~last:"" ~sep:" " (fun oc (n, v) ->
        Printf.fprintf oc "-p %s" (shell_quote (n ^"="^ v)))) params
      (shell_quote fname) in
  !logger.info "Running: %s" cmd ;
  if 0 = Sys.command cmd then
    !logger.debug "Run %s" fname
  else
    !logger.error "Failed to run program %s with %S" fname cmd

let compile_file ramen_cmd root_dir bundle_dir persist_dir fname params =
  assert (params <> []) ;
  if compile_program ramen_cmd root_dir bundle_dir fname then (
    let bin_name = Filename.(remove_extension fname) ^".x" in
    List.iter (fun params ->
      !logger.info "Running program %s with parameters %a"
        bin_name (List.print (Tuple2.print String.print String.print)) params ;
      run_program ramen_cmd root_dir persist_dir bin_name params
    ) params)

let compile_code ramen_cmd root_dir bundle_dir persist_dir program params =
  let fname = write_program root_dir program in
  compile_file ramen_cmd root_dir bundle_dir persist_dir fname params

let start debug monitor ramen_cmd root_dir bundle_dir persist_dir db_name
          dataset_name delete uncompress csv_glob with_extra with_base
          with_bcns with_bcas with_sec =
  logger := make_logger debug ;
  let open Conf_of_sqlite in
  let db = get_db db_name in
  let update () =
    List.iter (fun extra ->
      let root_dir = Filename.dirname extra in
      compile_file ramen_cmd root_dir bundle_dir persist_dir extra [[]]
    ) with_extra ;
    if with_base then (
      let prog =
        base_program dataset_name delete uncompress csv_glob in
      compile_code ramen_cmd root_dir bundle_dir persist_dir prog [[]]) ;
    if with_bcns > 0 || with_bcas > 0 then (
      let bcns, bcas = get_config_from_db db in
      let bcns = List.take with_bcns bcns
      and bcas = List.take with_bcas bcas in
      if bcns <> [] then (
        let or_null f = function
          | None -> "NULL"
          | Some v -> f v in
        let params =
          List.map (fun bcn ->
            BCN.[
              "id", string_of_int bcn.id ;
              "min_bps", or_null string_of_int bcn.min_bps ;
              "max_bps", or_null string_of_int bcn.max_bps ;
              "max_rtt", or_null string_of_float bcn.max_rtt ;
              "max_rr", or_null string_of_float bcn.max_rr ;
              "avg_window", string_of_float bcn.avg_window ;
              "obs_window", string_of_float bcn.obs_window ;
              "perc", string_of_float bcn.percentile ;
              "min_for_relevance", string_of_int bcn.min_for_relevance ;
              "source", IO.to_string (vector_print Int.print) bcn.source ;
              "source_name", dquote bcn.source_name ;
              "dest", IO.to_string (vector_print Int.print) bcn.dest ;
              "dest_name", dquote bcn.dest_name
            ] |>
            (* Empty vectors are prohibited for now, so just remove them
             * and let the code deal with the default value (which is non
             * empty but unused in that actual case) *)
            List.filter ((<>) "[]" % snd)
          ) bcns in
        let prog = program_of_bcns dataset_name in
        compile_code ramen_cmd root_dir bundle_dir persist_dir prog params
      ) ;
      if bcas <> [] then (
        let params =
          List.map (fun bca ->
            BCA.[
              "id", string_of_int bca.id ;
              "service_id", string_of_int bca.service_id ;
              "name", dquote bca.name ;
              "max_eurt", string_of_float bca.max_eurt ;
              "avg_window", string_of_float bca.avg_window ;
              "obs_window", string_of_float bca.obs_window ;
              "perc", string_of_float bca.percentile ;
              "min_handshake_count", string_of_int bca.min_srt_count
            ]
          ) bcas in
        let prog = program_of_bcas dataset_name in
        compile_code ramen_cmd root_dir bundle_dir persist_dir prog params
      )
    ) ;
    if with_sec then (
      (* Several bad behavior detectors, regrouped in a "Security" program. *)
      let prog = sec_program dataset_name in
      compile_code ramen_cmd root_dir bundle_dir persist_dir prog [[]])
  in
  update () ;
  if monitor then
    while true do
      check_config_changed db ;
      if must_reload db then (
        !logger.info "Must reload configuration" ;
        update ()
      ) else (
        Unix.sleep 1
      )
    done

(* Args *)

open Cmdliner

let debug =
  Arg.(value (flag (info ~doc:"increase verbosity" ["d"; "debug"])))

let monitor =
  Arg.(value (flag (info ~doc:"keep running and update conf when DB changes"
                           ["m"; "monitor"])))

let ramen_cmd =
  let i = Arg.info ~doc:"Command line to run ramen"
                   [ "ramen" ] in
  Arg.(value (opt string "ramen" i))

let db_name =
  let i = Arg.info ~doc:"Path of the SQLite file"
                   [ "db" ] in
  Arg.(required (opt (some string) None i))

let dataset_name =
  let i = Arg.info ~doc:"Name identifying this data set. Will be used to \
                         prefix any created programs"
                   [ "name" ; "dataset" ; "dataset-name" ] in
  Arg.(required (opt (some string) None i))

let root_dir =
  let env = Term.env_info "RAMEN_ROOT" in
  let i = Arg.info ~doc:"Path of root of ramen configuration tree"
                   ~env [ "root" ] in
  Arg.(value (opt string "." i))

let bundle_dir =
  let env = Term.env_info "RAMEN_BUNDLE_DIR" in
  let i = Arg.info ~doc:"Path of ramen runtime libraries"
                   ~env [ "bundle-dir" ] in
  Arg.(value (opt string "." i))

let persist_dir =
  let env = Term.env_info "RAMEN_PERSIST_DIR" in
  let i = Arg.info ~doc:"Path where ramen stores its state"
                   ~env [ "persist-dir" ] in
  Arg.(value (opt string "/tmp/ramen" i))

let delete_opt =
  let i = Arg.info ~doc:"Delete CSV files once injected"
                   [ "delete" ] in
  Arg.(value (flag i))

let uncompress_opt =
  let i = Arg.info ~doc:"CSV are compressed with lz4"
                   [ "uncompress" ; "uncompress-csv" ] in
  Arg.(value (flag i))

let csv_glob =
  let i = Arg.info ~doc:"File glob for the CSV files, where % will be \
                         replaced by the CSV type (\"tcp\", \"udp\"...)"
                   [ "csv" ] in
  Arg.(required (opt (some string) None i))

let with_extra =
  let i = Arg.info ~doc:"Also compile (and run) this additional configuration \
                         file"
                   [ "with-extra" ; "extra" ] in
  Arg.(value (opt_all string [] i))

let with_base =
  let i = Arg.info ~doc:"Output the base program with CSV input and first \
                         operations"
                   [ "with-base" ; "base" ] in
  Arg.(value (flag i))

let with_bcns =
  let i = Arg.info ~doc:"Also output the program with BCN configuration"
                   [ "with-bcns" ; "with-bcn" ; "bcns" ; "bcn" ] in
  Arg.(value (opt ~vopt:10 int 0 i))

let with_bcas =
  let i = Arg.info ~doc:"Also output the program with BCA configuration"
                   [ "with-bcas" ; "with-bca" ; "bcas" ; "bca" ] in
  Arg.(value (opt ~vopt:10 int 0 i))

let with_security =
  let i = Arg.info ~doc:"Also output the program with DDoS detection"
                   [ "with-security" ; "security" ;
                     (* old *) "with-ddos" ; "with-dos" ; "ddos" ; "dos" ] in
  Arg.(value (flag i))

let start_cmd =
  Term.(
    (const start
      $ debug
      $ monitor
      $ ramen_cmd
      $ root_dir
      $ bundle_dir
      $ persist_dir
      $ db_name
      $ dataset_name
      $ delete_opt
      $ uncompress_opt
      $ csv_glob
      $ with_extra
      $ with_base
      $ with_bcns
      $ with_bcas
      $ with_security),
    info "ramen_configurator")

let () =
  Term.eval start_cmd |> Term.exit
