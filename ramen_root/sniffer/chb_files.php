-- vim: ft=sql expandtab
<? include "chb_v30.php" ?>

PARAMETERS
  files_prefix DEFAULTS TO "/srv/nova/ramen/*.*.",
  files_compressed DEFAULTS TO false,
  files_delete DEFAULTS TO true;

DEFINE LAZY tcp_ext AS
  READ FROM
    FILES files_prefix || "tcp_v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$tcp?>;

DEFINE LAZY udp_ext AS
  READ FROM
    FILES files_prefix || "udp_v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$udp?>;

DEFINE LAZY icmp_ext AS
  READ FROM
    FILES files_prefix || "icmp_v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$icmp?>;

DEFINE LAZY 'other-ip_ext' AS
  READ FROM
    FILES files_prefix || "other_ip_v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$otherip?>;

DEFINE LAZY 'non-ip_ext' AS
  READ FROM
    FILES files_prefix || "non_ip_v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$nonip?>;

DEFINE LAZY dns_ext AS
  READ FROM
    FILES files_prefix || "dns_v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$dns?>;

DEFINE LAZY http_ext AS
  READ FROM
    FILES files_prefix || "http_v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$http?>;

DEFINE LAZY citrix_channels_ext AS
  READ FROM
    FILES files_prefix || "citrix_channels_v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$citrix_channels?>;

DEFINE LAZY citrix_ext AS
  READ FROM
    FILES files_prefix || "citrix_v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$citrix?>;

DEFINE LAZY smb_ext AS
  READ FROM
    FILES files_prefix || "smb_v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$smb?>;

DEFINE LAZY sql_ext AS
  READ FROM
    FILES files_prefix || "databases_v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$sql?>;

DEFINE LAZY voip_ext AS
  READ FROM
    FILES files_prefix || "voip_v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$voip?>;

DEFINE LAZY tls_ext AS
  READ FROM
    FILES files_prefix || "tls_v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$tls?>;

<? include 'adapt_chb_types.ramen' ?>
