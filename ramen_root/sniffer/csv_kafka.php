-- vim: ft=sql expandtab
<? include "csv_v30.php" ?>

PARAMETERS
  kafka_broker_list DEFAULTS TO "localhost:9092";

DEFINE tcp AS
  READ FROM
    KAFKA TOPIC "pvx.tcp"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$tcp?>;

DEFINE udp AS
  READ FROM
    KAFKA TOPIC "pvx.udp"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$udp?>;

DEFINE icmp AS
  READ FROM
    KAFKA TOPIC "pvx.icmp"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$icmp?>;

DEFINE 'other-ip' AS
  READ FROM
    KAFKA TOPIC "pvx.other_ip"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$otherip?>;


DEFINE 'non-ip' AS
  READ FROM
    KAFKA TOPIC "pvx.non_ip"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$nonip?>;

DEFINE dns AS
  READ FROM
    KAFKA TOPIC "pvx.dns"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$dns?>;

DEFINE http AS
  READ FROM
    KAFKA TOPIC "pvx.http"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$http?>;

DEFINE citrix AS
  READ FROM
    KAFKA TOPIC "pvx.citrix"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$citrix?>;

DEFINE citrix_chanless AS
  READ FROM
    KAFKA TOPIC "pvx.citrix_channels"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$citrix_chanless?>;

DEFINE smb AS
  READ FROM
    KAFKA TOPIC "pvx.smb"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$smb?>;

DEFINE sql AS
  READ FROM
    KAFKA TOPIC "pvx.sql"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$sql?>;

DEFINE voip AS
  READ FROM
    KAFKA TOPIC "pvx.voip"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$voip?>;

DEFINE tls AS
  READ FROM
    KAFKA TOPIC "pvx.tls"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$tls?>;
