#!/usr/bin/env python3
#
# Print results for an nmap ssh scan in a table format.
#

import sys
import xml.etree.ElementTree as ET
import socket
import ipaddress
import psutil

def get_local_ips_and_subnets():
  local_ips = set()
  subnets = set()
  for iface, addrs in psutil.net_if_addrs().items():
    for addr in addrs:
      if addr.family == socket.AF_INET:
        netmask = addr.netmask
        ip = addr.address
        local_ips.add(ip)
        network = ipaddress.ip_network(f'{ip}/{netmask}', strict=False)
        subnets.add(f'{str(iface)+":":<10} {network}')
  return local_ips, subnets

def parse_nmap_xml(file_obj, local_ips):
  tree = ET.parse(file_obj)
  root = tree.getroot()
  ips = set()

  print(f"{'L':<1} {'   IP Address':<15} {'   MAC Address':<17} {'Vendor':<30}")
  print("=" * 66)

  for host in root.findall('host'):
    ip = ''
    mac = ''
    vendor = ''
    local = ''

    address = host.find('address[@addrtype="ipv4"]')
    if address is not None:
      ip = address.get('addr', '')
      ips.add(ip)
      if ip in local_ips:
        local = '*'

      mac_element = host.find('address[@addrtype="mac"]')
      if mac_element is not None:
        mac = mac_element.get('addr', '')
        vendor = mac_element.get('vendor', '')

      if ip or mac:
        print(f'{local:<1} {ip:<15} {mac:<17} {vendor:<30}')

  print()
  print('All IP addresses:')
  print()
  print(f'  {" ".join(list(ips))}')
  print()

def usage(subnets):
    print('Usage:')
    print()
    print('  sudo nmap -sS -p 22 <SUBNET> -oX - > nmap-out.xml')
    print('  cat nmap_out.xml | ./prettyprint-nmap-xml.py')
    print()
    print('  Subnets:')
    for subnet in subnets:
      print(f'    {subnet}')
    print()

def main():
  local_ips, subnets = get_local_ips_and_subnets()

  if sys.stdin.isatty():
    usage(subnets)
    sys.exit(1)

  parse_nmap_xml(sys.stdin, local_ips)

if __name__ == '__main__':
  main()
