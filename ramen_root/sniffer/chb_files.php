-- vim: ft=sql expandtab
<? include "chb_v30.php" ?>

PARAMETERS
  files_prefix DEFAULTS TO "/srv/nova/ramen/*.*.",
  files_compressed DEFAULTS TO false,
  files_delete DEFAULTS TO true;

DEFINE LAZY tcp_ext AS
  READ FROM
    FILES files_prefix || "tcp_*v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$tcp?>;

DEFINE LAZY udp_ext AS
  READ FROM
    FILES files_prefix || "udp_*v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$udp?>;

DEFINE LAZY icmp_ext AS
  READ FROM
    FILES files_prefix || "icmp_*v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$icmp?>;

DEFINE LAZY 'other-ip_ext' AS
  READ FROM
    FILES files_prefix || "other_ip_*v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$otherip?>;

DEFINE LAZY 'non-ip_ext' AS
  READ FROM
    FILES files_prefix || "non_ip_*v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$nonip?>;

DEFINE LAZY dns_ext AS
  READ FROM
    FILES files_prefix || "dns_*v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$dns?>;

DEFINE LAZY http_ext AS
  READ FROM
    FILES files_prefix || "http_*v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$http?>;

DEFINE LAZY citrix_channels_ext AS
  READ FROM
    FILES files_prefix || "citrix_channels_*v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$citrix_channels?>;

DEFINE LAZY citrix_ext AS
  READ FROM
    FILES files_prefix || "citrix_*v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$citrix?>;

DEFINE LAZY smb_ext AS
  READ FROM
    FILES files_prefix || "smb_*v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$smb?>;

DEFINE LAZY sql_ext AS
  READ FROM
    FILES files_prefix || "databases_*v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$sql?>;

DEFINE LAZY voip_ext AS
  READ FROM
    FILES files_prefix || "voip_*v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$voip?>;

DEFINE LAZY tls_ext AS
  READ FROM
    FILES files_prefix || "tls_*v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    <?=$tls?>;

<? include 'adapt_chb_types.ramen' ?>
