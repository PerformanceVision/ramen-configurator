-- vim: ft=sql expandtab
<? include 'csv_v30.php' ?>

PARAMETERS
  files_prefix DEFAULTS TO "/srv/nova/ramen/*.*.",
  files_compressed DEFAULTS TO false,
  files_delete DEFAULTS TO true;

DEFINE LAZY tcp AS
  READ FROM
    FILES files_prefix || "tcp_v30.*csv" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$tcp?>;

DEFINE LAZY udp AS
  READ FROM
    FILES files_prefix || "udp_v30.*csv" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$udp?>;

DEFINE LAZY icmp AS
  READ FROM
    FILES files_prefix || "icmp_v30.*csv" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$icmp?>;

DEFINE LAZY 'other-ip' AS
  READ FROM
    FILES files_prefix || "other_ip_v30.*csv" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$otherip?>;

DEFINE LAZY 'non-ip' AS
  READ FROM
    FILES files_prefix || "non_ip_v30.*csv" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$nonip?>;

DEFINE LAZY dns AS
  READ FROM
    FILES files_prefix || "dns_v30.*csv" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$dns?>;

DEFINE LAZY http AS
  READ FROM
    FILES files_prefix || "http_v30.*csv" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$http?>;

DEFINE LAZY citrix_channels AS
  READ FROM
    FILES files_prefix || "citrix_channels_v30.*csv" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$citrix_channels?>;

DEFINE LAZY citrix AS
  READ FROM
    FILES files_prefix || "citrix_v30.*csv" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$citrix?>;

DEFINE LAZY smb AS
  READ FROM
    FILES files_prefix || "smb_v30.*csv" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$smb?>;

DEFINE LAZY sql AS
  READ FROM
    FILES files_prefix || "sql_v30.*csv" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$sql?>;

DEFINE LAZY voip AS
  READ FROM
    FILES files_prefix || "voip_v30.*csv" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$voip?>;

DEFINE LAZY tls AS
  READ FROM
    FILES files_prefix || "tls_v30.*csv" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$tls?>;
