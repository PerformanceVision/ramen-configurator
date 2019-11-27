<?
$LAYERS = [
  "tcp" => "tcp",
  "udp" => "udp",
  "icmp" =>"icmp",
  "other_ip" => "other-ip",
  "non_ip" => "non-ip",
  "dns" => "dns",
  "http" => "http",
  "citrix_channels" => "citrix_channels",
  "citrix" => "citrix",
  "smb" => "smb",
  "databases" => "sql",
  "voip" => "voip",
  "tls" => "tls",
];

function get_content_path($layer) {
  return "ramen_root/sniffer/{$layer}.txt";
}
?>
