-- vim: ft=sql expandtab
<? include "csv_v30.php" ?>

PARAMETERS
  csv_prefix DEFAULTS TO "/srv/nova/ramen/*.*.",
  csv_compressed DEFAULTS TO false,
  csv_delete DEFAULTS TO true;

DEFINE LAZY tcp AS
  READ FROM
    FILES csv_prefix || "tcp_v30.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$tcp?>;

DEFINE LAZY udp AS
  READ FROM
    FILES csv_prefix || "udp_v30.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$udp?>;

DEFINE LAZY icmp AS
  READ FROM
    FILES csv_prefix || "icmp_v30.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$icmp?>;

DEFINE LAZY 'other-ip' AS
  READ FROM
    FILES csv_prefix || "other_ip_v30.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$otherip?>;

DEFINE LAZY 'non-ip' AS
  READ FROM
    FILES csv_prefix || "non_ip_v30.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$nonip?>;

DEFINE LAZY dns AS
  READ FROM
    FILES csv_prefix || "dns_v30.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$dns?>;

DEFINE LAZY http AS
  READ FROM
    FILES csv_prefix || "http_v30.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$http?>;

DEFINE LAZY citrix AS
  READ FROM
    FILES csv_prefix || "citrix_v30.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$citrix?>;

DEFINE LAZY citrix_chanless AS
  READ FROM
    FILES csv_prefix || "citrix_chanless_v30.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$citrix_chanless?>;

DEFINE LAZY smb AS
  READ FROM
    FILES csv_prefix || "smb_v30.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$smb?>;

DEFINE LAZY sql AS
  READ FROM
    FILES csv_prefix || "sql_v30.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$sql?>;

DEFINE LAZY voip AS
  READ FROM
    FILES csv_prefix || "voip_v30.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$voip?>;

DEFINE LAZY tls AS
  READ FROM
    FILES csv_prefix || "tls_v30.*csv" || (IF csv_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF csv_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF csv_delete
    <?=$tls?>;
