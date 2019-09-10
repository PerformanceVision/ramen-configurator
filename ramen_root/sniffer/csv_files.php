-- vim: ft=sql expandtab
<? include "csv_v30.php" ?>

PARAMETERS
  csv_prefix DEFAULTS TO "/srv/nova/ramen/*.*.",
  csv_compressed DEFAULTS TO false,
  csv_delete DEFAULTS TO true;

DEFINE tcp AS
  READ FROM
    FILES csv_prefix || "tcp_v29.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$tcp?>;

DEFINE udp AS
  READ FROM
    FILES csv_prefix || "udp_v29.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$udp?>;

DEFINE icmp AS
  READ FROM
    FILES csv_prefix || "icmp_v29.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$icmp?>;

DEFINE 'other-ip' AS
  READ FROM
    FILES csv_prefix || "other_ip_v29.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$otherip?>;

DEFINE 'non-ip' AS
  READ FROM
    FILES csv_prefix || "non_ip_v29.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$nonip?>;

DEFINE dns AS
  READ FROM
    FILES csv_prefix || "dns_v29.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$dns?>;

DEFINE http AS
  READ FROM
    FILES csv_prefix || "http_v29.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$http?>;

DEFINE citrix AS
  READ FROM
    FILES csv_prefix || "citrix_v29.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$citrix?>;

DEFINE citrix_chanless AS
  READ FROM
    FILES csv_prefix || "citrix_chanless_v29.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$citrix_chanless?>;

DEFINE smb AS
  READ FROM
    FILES csv_prefix || "smb_v29.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$smb?>;

DEFINE sql AS
  READ FROM
    FILES csv_prefix || "sql_v29.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$sql?>;

DEFINE voip AS
  READ FROM
    FILES csv_prefix || "voip_v29.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$voip?>;

DEFINE tls AS
  READ FROM
    FILES csv_prefix || "tls_v29.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$tls?>;
