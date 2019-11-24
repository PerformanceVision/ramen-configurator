-- vim: ft=sql expandtab
<? include 'csv_v30.php' ?>

PARAMETERS
  kafka_broker_list DEFAULTS TO "localhost:9092",
  kafka_max_msg_size DEFAULTS TO "1000000";

DEFINE LAZY tcp AS
  READ FROM
    KAFKA TOPIC "pvx.csv.tcp"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$tcp?>;

DEFINE LAZY udp AS
  READ FROM
    KAFKA TOPIC "pvx.csv.udp"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$udp?>;

DEFINE LAZY icmp AS
  READ FROM
    KAFKA TOPIC "pvx.csv.icmp"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$icmp?>;

DEFINE LAZY 'other-ip' AS
  READ FROM
    KAFKA TOPIC "pvx.csv.other_ip"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$otherip?>;


DEFINE LAZY 'non-ip' AS
  READ FROM
    KAFKA TOPIC "pvx.csv.non_ip"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$nonip?>;

DEFINE LAZY dns AS
  READ FROM
    KAFKA TOPIC "pvx.csv.dns"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$dns?>;

DEFINE LAZY http AS
  READ FROM
    KAFKA TOPIC "pvx.csv.http"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$http?>;

DEFINE LAZY citrix_channels AS
  READ FROM
    KAFKA TOPIC "pvx.csv.citrix_channels"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$citrix?>;

DEFINE LAZY citrix AS
  READ FROM
    KAFKA TOPIC "pvx.csv.citrix"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$citrix?>;

DEFINE LAZY smb AS
  READ FROM
    KAFKA TOPIC "pvx.csv.smb"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$smb?>;

DEFINE LAZY sql AS
  READ FROM
    KAFKA TOPIC "pvx.csv.sql"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$sql?>;

DEFINE LAZY voip AS
  READ FROM
    KAFKA TOPIC "pvx.csv.voip"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$voip?>;

DEFINE LAZY tls AS
  READ FROM
    KAFKA TOPIC "pvx.csv.tls"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    <?=$tls?>;
