#!/usr/bin/env python3

import json
import paramiko
import os
import sys
import argparse
from paramiko.ssh_exception import SSHException, AuthenticationException
from concurrent.futures import ThreadPoolExecutor

def ssh_get_hostname(ip, username, private_key_path, timeout):
  client = paramiko.SSHClient()
  client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

  try:
    if not private_key_path:
      private_key_path = os.path.expanduser('~/.ssh/id_rsa')

    pkey = paramiko.RSAKey.from_private_key_file(private_key_path)

    client.connect(ip, username=username, pkey=pkey, timeout=timeout)

    stdin, stdout, stderr = client.exec_command('hostname')
    hostname = stdout.read().decode().strip()
    client.close()
    return hostname, None
  except AuthenticationException:
    return None, 'Authentication failed'
  except SSHException as e:
    return None, f'SSH error: {str(e)}'
  except Exception as e:
    return None, f'Error: {str(e)}'

def probe(entry, timeout, default_private_key_path):
  ip = entry.get('ip')
  if not ip:
    return ip, 'N/A', 'Invalid entry'

  print(f'Connecting to {ip}')
  username = entry.get('username', os.getlogin())
  private_key_path = entry.get('private_key', default_private_key_path)
  hostname, error = ssh_get_hostname(ip, username, private_key_path, timeout)

  if hostname:
    print(f'Success for IP {ip} ({hostname})')
    return ip, hostname, 'Success'
  else:
    print(f'Error for IP {ip} ({error})')
    return ip, '', error



def generate_report(entries, timeout, default_private_key_path):
  ret = {}

  print()
  with ThreadPoolExecutor() as executor:
    results = list(executor.map(lambda entry : probe(entry, timeout, default_private_key_path), entries))

  print()

  print(f'{"IP Address":<15} {"Hostname":<10} {"Status":<70}')
  print('=' * 97)
  for ip, hostname, status in results:
    if hostname and status == 'Success':
      ret[hostname] = { 'ip' : ip, 'up' : True }
    print(f'{ip:<15} {hostname:<10} {status:<70}')
  print()

  return ret;

def load_json(path):
  with open(path, 'r') as f:
    return json.load(f)

def main():
  parser = argparse.ArgumentParser(
    description="Probe hosts through SSH."
  )

  parser.add_argument('-f', '--file',    type = str,              help = 'Path to JSON file containing IPs and credentials.')
  parser.add_argument('-i', '--ip',      type = str, nargs = '+', help = 'List of IPs to query.')
  parser.add_argument('-t', '--timeout', type = int, default = 2, help = 'Connection timeout in seconds (default: 2).')
  parser.add_argument('-r', '--read',    type = str,              help = 'Path to read definition JSON file.')
  parser.add_argument('-w', '--write',   type = str,              help = 'Path to write definition JSON file.')
  parser.add_argument('-k', '--keyfile', type = str,              help = 'Default private key file.')

  args = parser.parse_args()

  entries = []

  if args.file:
    entries.extend(load_ips_from_json(args.file))

  read = None
  if args.read:
    print(f'Read definitions from {args.read}')
    read = load_json(args.read)
    for hostname, entry in read.items():
      entries.append(entry)

  if args.ip:
    for ip in args.ip:
      entries.append({ 'ip' : ip.strip() })

  if not entries and not read:
    parser.print_help()
    sys.exit(1)

  if args.keyfile:
    default_private_key_path = args.keyfile
  else:
    default_private_key_path = None
  defs = generate_report(entries, args.timeout, default_private_key_path)


  if args.write:
    if read:
      up_ips = set()

      for hostname, entry in defs.items():
        up_ips.add(entry['ip'])

      for hostname, entry in read.items():
        if hostname in defs:
          continue
        if entry['ip'] in up_ips:
          continue
        entry['up'] = False
        defs[hostname] = entry

    print(f'Write definitions to {args.write}')
    with open(args.write, 'w') as f:
      json.dump(defs, f, indent=2)

if __name__ == "__main__":
    main()
