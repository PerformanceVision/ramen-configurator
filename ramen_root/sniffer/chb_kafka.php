-- vim: ft=sql expandtab
<? include 'chb_v30.php' ?>

PARAMETERS
  kafka_broker_list DEFAULTS TO "localhost:9092",
  kafka_max_msg_size DEFAULTS TO "1000000";

<?
foreach ($PROTOCOLS as $protocol) {
$content_path = get_content_path($protocol);
$content = file_get_contents("$content_path");
$ramen_function_name = get_ramen_function_name($protocol);
echo <<<EOT
DEFINE LAZY '{$ramen_function_name}_ext' AS
  READ FROM
    KAFKA TOPIC "pvx.chb.{$protocol["sniffer"]}"
    WITH OPTIONS
      "metadata.broker.list" = kafka_broker_list,
      "max.partition.fetch.bytes" = kafka_max_msg_size
    AS ROWBINARY (
      $content
  )
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6;\n
EOT;
}
?>

<? include 'adapt_chb_types.ramen' ?>
