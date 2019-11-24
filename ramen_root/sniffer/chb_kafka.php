-- vim: ft=sql expandtab
<? include 'chb_v30.php' ?>

PARAMETERS
  kafka_broker_list DEFAULTS TO "localhost:9092",
  kafka_max_msg_size DEFAULTS TO "1000000";

DEFINE LAZY tcp_ext AS
  READ FROM
    KAFKA TOPIC "pvx.chb.tcp"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$tcp?>;

DEFINE LAZY udp_ext AS
  READ FROM
    KAFKA TOPIC "pvx.chb.udp"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$udp?>;

DEFINE LAZY icmp_ext AS
  READ FROM
    KAFKA TOPIC "pvx.chb.icmp"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$icmp?>;

DEFINE LAZY 'other-ip_ext' AS
  READ FROM
    KAFKA TOPIC "pvx.chb.other_ip"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$otherip?>;


DEFINE LAZY 'non-ip_ext' AS
  READ FROM
    KAFKA TOPIC "pvx.chb.non_ip"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$nonip?>;

DEFINE LAZY dns_ext AS
  READ FROM
    KAFKA TOPIC "pvx.chb.dns"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$dns?>;

DEFINE LAZY http_ext AS
  READ FROM
    KAFKA TOPIC "pvx.chb.http"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$http?>;

DEFINE LAZY citrix_channels_ext AS
  READ FROM
    KAFKA TOPIC "pvx.chb.citrix_channels"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$citrix_channels?>;

DEFINE LAZY citrix_ext AS
  READ FROM
    KAFKA TOPIC "pvx.chb.citrix"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$citrix?>;

DEFINE LAZY smb_ext AS
  READ FROM
    KAFKA TOPIC "pvx.chb.smb"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$smb?>;

DEFINE LAZY sql_ext AS
  READ FROM
    KAFKA TOPIC "pvx.chb.databases"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$sql?>;

DEFINE LAZY voip_ext AS
  READ FROM
    KAFKA TOPIC "pvx.chb.voip"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$voip?>;

DEFINE LAZY tls_ext AS
  READ FROM
    KAFKA TOPIC "pvx.chb.tls"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$tls?>;

<? include 'adapt_chb_types.ramen' ?>
