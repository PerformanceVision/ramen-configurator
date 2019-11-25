<?
$PROTOCOLS = [
  ["sniffer" =>"tcp"],
  ["sniffer" =>"udp"],
  ["sniffer" =>"icmp"],
  ["sniffer" =>"other_ip", "ramen_function_name" => "other-ip"],
  ["sniffer" =>"non_ip", "ramen_function_name" => "non-ip"],
  ["sniffer" =>"dns"],
  ["sniffer" =>"http"],
  ["sniffer" =>"citrix_channels"],
  ["sniffer" =>"citrix"],
  ["sniffer" =>"smb"],
  ["sniffer" =>"databases", "ramen_function_name" => "sql"],
  ["sniffer" =>"voip"],
  ["sniffer" =>"tls"],
];

function get_ramen_function_name($protocol) {
  return $protocol["ramen_function_name"] ?: $protocol["sniffer"];
}

function get_content_path($protocol) {
  return "ramen_root/sniffer/{$protocol["sniffer"]}.txt";
}

?>
