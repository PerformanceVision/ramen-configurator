-- vim: ft=sql expandtab
<? include "csv_v30.php" ?>

PARAMETERS
  kafka_broker_list DEFAULTS TO "localhost:9092";

DEFINE LAZY tcp AS
  READ FROM
    KAFKA TOPIC "pvx.tcp"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$tcp?>;

DEFINE LAZY udp AS
  READ FROM
    KAFKA TOPIC "pvx.udp"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$udp?>;

DEFINE LAZY icmp AS
  READ FROM
    KAFKA TOPIC "pvx.icmp"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$icmp?>;

DEFINE LAZY 'other-ip' AS
  READ FROM
    KAFKA TOPIC "pvx.other_ip"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$otherip?>;


DEFINE LAZY 'non-ip' AS
  READ FROM
    KAFKA TOPIC "pvx.non_ip"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$nonip?>;

DEFINE LAZY dns AS
  READ FROM
    KAFKA TOPIC "pvx.dns"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$dns?>;

DEFINE LAZY http AS
  READ FROM
    KAFKA TOPIC "pvx.http"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$http?>;

DEFINE LAZY citrix AS
  READ FROM
    KAFKA TOPIC "pvx.citrix_channels"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$citrix?>;

DEFINE LAZY citrix_chanless AS
  READ FROM
    KAFKA TOPIC "pvx.citrix"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$citrix_chanless?>;

DEFINE LAZY smb AS
  READ FROM
    KAFKA TOPIC "pvx.smb"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$smb?>;

DEFINE LAZY sql AS
  READ FROM
    KAFKA TOPIC "pvx.sql"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$sql?>;

DEFINE LAZY voip AS
  READ FROM
    KAFKA TOPIC "pvx.voip"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$voip?>;

DEFINE LAZY tls AS
  READ FROM
    KAFKA TOPIC "pvx.tls"
    WITH OPTIONS "metadata.broker.list" = kafka_broker_list
    <?=$tls?>;
