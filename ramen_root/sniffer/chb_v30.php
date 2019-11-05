<?
$citrix_channels = "AS ROWBINARY (
    ".file_get_contents('ramen_root/sniffer/citrix_channels.txt')."
  )
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$citrix = "AS ROWBINARY (
    ".file_get_contents('ramen_root/sniffer/citrix.txt')."
  )
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$dns = "AS ROWBINARY (
    ".file_get_contents('ramen_root/sniffer/dns.txt')."
  )
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$http = "AS ROWBINARY (
    ".file_get_contents('ramen_root/sniffer/http.txt')."
  )
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$icmp = "AS ROWBINARY (
    ".file_get_contents('ramen_root/sniffer/icmp.txt')."
  )
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$nonip = "AS ROWBINARY (
    ".file_get_contents('ramen_root/sniffer/non_ip.txt')."
  )
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$otherip = "AS ROWBINARY (
    ".file_get_contents('ramen_root/sniffer/other_ip.txt')."
  )
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$smb = "AS ROWBINARY (
    ".file_get_contents('ramen_root/sniffer/smb.txt')."
  )
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$sql = "AS ROWBINARY (
    ".file_get_contents('ramen_root/sniffer/databases.txt')."
  )
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$tcp = "AS ROWBINARY (
    ".file_get_contents('ramen_root/sniffer/tcp.txt')."
  )
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$tls = "AS ROWBINARY (
    ".file_get_contents('ramen_root/sniffer/tls.txt')."
  )
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$udp = "AS ROWBINARY (
    ".file_get_contents('ramen_root/sniffer/udp.txt')."
    )
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";

$voip = "AS ROWBINARY (
    ".file_get_contents('ramen_root/sniffer/voip.txt')."
  )
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6";
?>
