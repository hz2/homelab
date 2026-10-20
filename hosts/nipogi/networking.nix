{ ... }:

let
  nic = "enp1s0";
in
{
  networking.useDHCP = false;
  networking.firewall.enable = false;

  networking.vlans = {
    vlan10 = { id = 10; interface = nic; };
    vlan20 = { id = 20; interface = nic; };
    vlan30 = { id = 30; interface = nic; };
  };

  networking.interfaces = {
    # dhcp on base nic until switch vlan trunk is configured; remove once vlan10 takes over
    ${nic}.useDHCP = true;
    # vlan10 static ip disabled until switch trunk is set up (conflicts with enp1s0 dhcp on same subnet)
    # vlan10.ipv4.addresses = [{ address = "192.168.1.20"; prefixLength = 24; }];
    vlan20.ipv4.addresses = [{ address = "10.0.20.1";   prefixLength = 24; }];
    vlan30.ipv4.addresses = [{ address = "10.0.30.1";   prefixLength = 24; }];
  };

  # use enp1s0 until switch trunk is configured and vlan10 takes over
  networking.defaultGateway = { address = "192.168.1.1"; interface = nic; };
  networking.nameservers = [ "192.168.1.1" ];

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      interface = [ "vlan20" "vlan30" ];
      "bind-interfaces" = true;
      "dhcp-range" = [
        "10.0.20.100,10.0.20.200,255.255.255.0,86400"
        "10.0.30.100,10.0.30.200,255.255.255.0,86400"
      ];
      "dhcp-host" = [ "b8:a4:4f:33:46:06,10.0.30.10,axis" ];
      server = [ "192.168.1.1" ];
      "no-resolv" = true;
    };
  };

  networking.nftables = {
    enable = true;
    ruleset = ''
      table inet filter {
        chain input {
          type filter hook input priority filter; policy drop;

          ct state { established, related } accept
          ct state invalid drop
          iifname "lo" accept
          ip protocol icmp accept
          ip6 nexthdr icmpv6 accept

          iifname { "${nic}", "vlan10" } tcp dport 22 accept

          iifname { "vlan20", "vlan30" } udp dport { 53, 67 } accept
          iifname { "vlan20", "vlan30" } tcp dport 53 accept

          iifname { "${nic}", "vlan10", "vlan20" } tcp dport 1883 accept
          iifname { "vlan10", "vlan20" } tcp dport { 4222, 7422 } accept

          iifname { "${nic}", "vlan10" } tcp dport 8086 accept
          iifname { "${nic}", "vlan10" } tcp dport { 9000, 9001 } accept
          iifname { "${nic}", "vlan10" } tcp dport 18083 accept

          iifname { "${nic}", "vlan10" } tcp dport { 5000, 8554, 8555 } accept
          iifname { "${nic}", "vlan10" } udp dport 8555 accept

          # grpc services: sensor-api, camera-api
          iifname { "${nic}", "vlan10" } tcp dport { 50051, 50052 } accept

          # caddy reverse proxy (https with tls internal)
          iifname { "${nic}", "vlan10" } tcp dport { 80, 443 } accept
        }

        chain forward {
          type filter hook forward priority filter; policy drop;
          ct state { established, related } accept
          iifname { "vlan20", "vlan30" } oifname "${nic}" accept
        }

        chain output {
          type filter hook output priority filter; policy accept;
        }
      }

      table ip nat {
        chain postrouting {
          type nat hook postrouting priority srcnat;
          oifname "${nic}" masquerade
        }
      }
    '';
  };
}
