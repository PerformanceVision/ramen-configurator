-- vim: ft=sql expandtab
<? include 'chb_v30.php' ?>

PARAMETERS
  kafka_broker_list DEFAULTS TO "localhost:9092";

DEFINE LAZY tcp_ext AS
  READ FROM
    KAFKA TOPIC "pvx.tcp"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$tcp?>;

DEFINE LAZY udp_ext AS
  READ FROM
    KAFKA TOPIC "pvx.udp"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$udp?>;

DEFINE LAZY icmp_ext AS
  READ FROM
    KAFKA TOPIC "pvx.icmp"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$icmp?>;

DEFINE LAZY 'other-ip_ext' AS
  READ FROM
    KAFKA TOPIC "pvx.other_ip"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$otherip?>;


DEFINE LAZY 'non-ip_ext' AS
  READ FROM
    KAFKA TOPIC "pvx.non_ip"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$nonip?>;

DEFINE LAZY dns_ext AS
  READ FROM
    KAFKA TOPIC "pvx.dns"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$dns?>;

DEFINE LAZY http_ext AS
  READ FROM
    KAFKA TOPIC "pvx.http"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$http?>;

DEFINE LAZY citrix_channels_ext AS
  READ FROM
    KAFKA TOPIC "pvx.citrix_channels"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$citrix_channels?>;

DEFINE LAZY citrix_ext AS
  READ FROM
    KAFKA TOPIC "pvx.citrix"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$citrix?>;

DEFINE LAZY smb_ext AS
  READ FROM
    KAFKA TOPIC "pvx.smb"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$smb?>;

DEFINE LAZY sql_ext AS
  READ FROM
    KAFKA TOPIC "pvx.sql"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$sql?>;

DEFINE LAZY voip_ext AS
  READ FROM
    KAFKA TOPIC "pvx.voip"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$voip?>;

DEFINE LAZY tls_ext AS
  READ FROM
    KAFKA TOPIC "pvx.tls"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$tls?>;

<? include 'adapt_chb_types.ramen' ?>
